-- Shadow: an anonymous board that only exists on phones unlocked at a hidden spot.
-- Everything is tied to the phone (IMEI), not to the character: whoever holds the
-- phone and knows the PIN is that alias. Police can extract a seized phone.

local ESX = exports.es_extended:getSharedObject()
local Ok, Fail = ShadowUtil.Ok, ShadowUtil.Fail

local DEVICE_CACHE_MS = 10000
local device_cache = {}
local sessions = {}      -- source -> imei unlocked with the PIN (read and write)
local extractions = {}   -- source -> { imei, startedAt, done } (police, read only)
local channels = {}
for _, channel in ipairs(Config.Channels) do
    channels[channel.id] = true
end

local function now()
    return os.time()
end

local function identifier_of(source)
    local player = ESX.GetPlayerFromId(source)
    return player and player.identifier or nil
end

local function is_police(source)
    local player = ESX.GetPlayerFromId(source)
    local job = player and player.job
    local minimum = job and Config.Police.Jobs[job.name]
    return minimum ~= nil and (job.grade or 0) >= minimum
end

local function current_imei(source)
    local cached = device_cache[source]
    local timer = GetGameTimer()
    if cached and timer - cached.checked < DEVICE_CACHE_MS then
        return cached.imei
    end
    local success, identity = pcall(function()
        return exports.sky_phone:GetOnlineDeviceBySource(source)
    end)
    local imei = success and type(identity) == 'table' and type(identity.imei) == 'string' and identity.imei or nil
    device_cache[source] = { checked = timer, imei = imei }
    return imei
end

local function load_device(imei)
    return MySQL.single.await('SELECT * FROM `shadow_devices` WHERE `imei` = ?', { imei })
end

local function random_alias()
    local aliases = Config.Aliases
    return ('%s %s #%04d'):format(
        aliases.Adjectives[math.random(#aliases.Adjectives)],
        aliases.Nouns[math.random(#aliases.Nouns)],
        math.random(0, 9999)
    )
end

---Returns the phone's device row if the app may be used right now.
---@param write boolean true for actions; police extractions only allow reading.
local function require_access(source, write)
    local imei = current_imei(source)
    if not imei then
        return nil, Fail('no_phone')
    end
    local device = load_device(imei)
    if not device then
        return nil, Fail('not_installed')
    end
    if sessions[source] == imei or device.pin_hash == nil then
        sessions[source] = imei
        return device
    end
    local extraction = extractions[source]
    if not write and extraction and extraction.done and extraction.imei == imei then
        return device
    end
    return nil, Fail('locked')
end

local function message_payload(row, imei)
    return {
        id = row.id,
        alias = row.alias,
        body = row.body,
        isAd = row.is_ad == 1 or row.is_ad == true,
        createdAt = row.created_at,
        mine = row.imei == imei,
    }
end

local function clean_body(value)
    local body, error_code = ShadowUtil.CleanText(value, Config.Messages.MaxLength)
    return body, error_code
end

ShadowRpc.Register('status', { perMinute = 20 }, function(source)
    local imei = current_imei(source)
    local base = {
        police = is_police(source),
        config = {
            appName = Config.App.Name,
            channels = Config.Channels,
            pinLength = Config.Security.PinLength,
            aliasMode = Config.Aliases.Mode,
            aliasMinLength = Config.Aliases.MinLength,
            aliasMaxLength = Config.Aliases.MaxLength,
            messageMaxLength = Config.Messages.MaxLength,
            lifetimeHours = Config.Messages.LifetimeHours,
            crackSeconds = Config.Police.CrackSeconds,
        },
    }
    if not imei then
        base.installed = false
        return Ok(base)
    end
    local device = load_device(imei)
    base.installed = device ~= nil
    if not device then
        return Ok(base)
    end

    local identifier = identifier_of(source)
    local extraction = extractions[source]
    base.hasPin = device.pin_hash ~= nil
    base.unlocked = device.pin_hash == nil or sessions[source] == imei
    base.extracted = extraction ~= nil and extraction.done and extraction.imei == imei or false
    base.foreignPhone = device.owner_identifier ~= identifier
    base.lockedUntil = device.locked_until > now() and device.locked_until or 0
    base.alias = base.unlocked and device.alias or nil
    base.aliasChangeAt = base.unlocked
        and device.alias_changed_at + Config.Aliases.ChangeCooldownHours * 3600 or nil
    return Ok(base)
end)

-- Installation at a hidden spot. The server checks the player's real position.
ShadowRpc.Register('install', { perMinute = 4 }, function(source)
    local imei = current_imei(source)
    if not imei then
        return Fail('no_phone')
    end
    local position = GetEntityCoords(GetPlayerPed(source))
    local near = false
    for _, point in ipairs(Config.UnlockPoints) do
        if #(position - point.coords) <= point.radius + 2.0 then
            near = true
            break
        end
    end
    if not near then
        ShadowUtil.Log('warn', 'Player %s tried to install Shadow away from an unlock spot.', source)
        return Fail('not_here')
    end
    if load_device(imei) then
        return Ok({ alreadyInstalled = true })
    end
    local identifier = identifier_of(source)
    if not identifier then
        return Fail('player_unavailable')
    end
    MySQL.insert.await(
        'INSERT INTO `shadow_devices` (`imei`, `alias`, `owner_identifier`) VALUES (?, ?, ?)',
        { imei, random_alias(), identifier }
    )
    sessions[source] = imei
    ShadowUtil.Log('info', 'Shadow installed on phone %s by %s.', imei, identifier)
    return Ok({ alreadyInstalled = false })
end)

ShadowRpc.Register('pin:verify', { perMinute = 20 }, function(source, payload)
    local imei = current_imei(source)
    local device = imei and load_device(imei)
    if not device then
        return Fail('not_installed')
    end
    if not device.pin_hash then
        sessions[source] = imei
        return Ok({})
    end
    if device.locked_until > now() then
        return Fail('pin_locked')
    end
    local pin = type(payload) == 'table' and payload.pin
    local valid = type(pin) == 'string' and ShadowUtil.AwaitJs('verifyPin', 5000, pin, device.pin_hash) == true
    if valid then
        MySQL.update.await(
            'UPDATE `shadow_devices` SET `failed_attempts` = 0, `locks_in_row` = 0 WHERE `imei` = ?',
            { imei }
        )
        sessions[source] = imei
        return Ok({})
    end

    local failed = device.failed_attempts + 1
    if failed < Config.Security.MaxAttempts then
        MySQL.update.await('UPDATE `shadow_devices` SET `failed_attempts` = ? WHERE `imei` = ?', { failed, imei })
        return { ok = false, error = 'wrong_pin', remaining = Config.Security.MaxAttempts - failed }
    end

    local locks = device.locks_in_row + 1
    local wipe_after = Config.Security.WipeAfterLocks
    if wipe_after > 0 and locks >= wipe_after then
        MySQL.query.await('DELETE FROM `shadow_devices` WHERE `imei` = ?', { imei })
        ShadowUtil.Log('info', 'Shadow wiped itself from phone %s after too many wrong PINs.', imei)
        return Fail('wiped')
    end
    MySQL.update.await(
        'UPDATE `shadow_devices` SET `failed_attempts` = 0, `locks_in_row` = ?, `locked_until` = ? WHERE `imei` = ?',
        { locks, now() + Config.Security.LockMinutes * 60, imei }
    )
    return Fail('pin_locked')
end)

ShadowRpc.Register('pin:set', { perMinute = 6 }, function(source, payload)
    local device, failure = require_access(source, true)
    if not device then
        return failure
    end
    local pin = type(payload) == 'table' and payload.pin
    if pin == false then
        MySQL.update.await('UPDATE `shadow_devices` SET `pin_hash` = NULL WHERE `imei` = ?', { device.imei })
        return Ok({ hasPin = false })
    end
    if type(pin) ~= 'string' or #pin ~= Config.Security.PinLength or not pin:match('^%d+$') then
        return Fail('invalid_pin')
    end
    local hash = ShadowUtil.AwaitJs('hashPin', 5000, pin)
    if type(hash) ~= 'string' then
        return Fail('server_error')
    end
    MySQL.update.await('UPDATE `shadow_devices` SET `pin_hash` = ? WHERE `imei` = ?', { hash, device.imei })
    return Ok({ hasPin = true })
end)

ShadowRpc.Register('alias:set', { perMinute = 6 }, function(source, payload)
    local device, failure = require_access(source, true)
    if not device then
        return failure
    end
    local aliases = Config.Aliases
    if device.alias_changed_at + aliases.ChangeCooldownHours * 3600 > now() then
        return Fail('alias_cooldown')
    end
    local alias
    if aliases.Mode == 'random' then
        alias = random_alias()
    else
        alias = type(payload) == 'table' and ShadowUtil.CleanText(payload.alias, aliases.MaxLength)
        if not alias or utf8.len(alias) < aliases.MinLength or not alias:match('^[%w _%.%-#]+$') then
            return Fail('invalid_alias')
        end
        local taken = MySQL.scalar.await(
            'SELECT 1 FROM `shadow_devices` WHERE LOWER(`alias`) = LOWER(?) AND `imei` <> ? LIMIT 1',
            { alias, device.imei }
        )
        if taken then
            return Fail('alias_taken')
        end
    end
    MySQL.update.await(
        'UPDATE `shadow_devices` SET `alias` = ?, `alias_changed_at` = ? WHERE `imei` = ?',
        { alias, now(), device.imei }
    )
    return Ok({ alias = alias })
end)

ShadowRpc.Register('channels:list', { perMinute = 30 }, function(source)
    local device, failure = require_access(source, false)
    if not device then
        return failure
    end
    local rows = MySQL.query.await([[
        SELECT `channel`, COUNT(*) AS `count`, MAX(`created_at`) AS `last_at`
        FROM `shadow_messages` WHERE `channel` IS NOT NULL AND `created_at` > ?
        GROUP BY `channel`
    ]], { now() - 86400 }) or {}
    local activity = {}
    for _, row in ipairs(rows) do
        activity[row.channel] = { count = tonumber(row.count) or 0, lastAt = tonumber(row.last_at) or 0 }
    end
    local list = {}
    for _, channel in ipairs(Config.Channels) do
        local stats = activity[channel.id] or { count = 0, lastAt = 0 }
        list[#list + 1] = { id = channel.id, label = channel.label, count = stats.count, lastAt = stats.lastAt }
    end
    return Ok({ channels = list })
end)

ShadowRpc.Register('channel:read', { perMinute = 40 }, function(source, payload)
    local device, failure = require_access(source, false)
    if not device then
        return failure
    end
    local channel = type(payload) == 'table' and payload.channel
    if not channels[channel] then
        return Fail('invalid_channel')
    end
    local after = math.tointeger(tonumber(payload.after)) or 0
    local rows = MySQL.query.await([[
        SELECT * FROM (
            SELECT `id`, `alias`, `body`, `is_ad`, `imei`, `created_at` FROM `shadow_messages`
            WHERE `channel` = ? AND `id` > ? ORDER BY `id` DESC LIMIT ?
        ) recent ORDER BY `id` ASC
    ]], { channel, after, Config.Messages.ChannelPageSize }) or {}
    local messages = {}
    for index, row in ipairs(rows) do
        messages[index] = message_payload(row, device.imei)
    end
    return Ok({ messages = messages })
end)

ShadowRpc.Register('channel:post', { perMinute = Config.Messages.PostsPerMinute }, function(source, payload)
    local device, failure = require_access(source, true)
    if not device then
        return failure
    end
    local channel = type(payload) == 'table' and payload.channel
    if not channels[channel] then
        return Fail('invalid_channel')
    end
    local body, body_error = clean_body(payload.body)
    if not body then
        return Fail(body_error)
    end
    MySQL.insert.await([[
        INSERT INTO `shadow_messages` (`channel`, `is_ad`, `imei`, `alias`, `author_identifier`, `body`, `created_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { channel, payload.ad == true and 1 or 0, device.imei, device.alias, identifier_of(source) or '', body, now() })
    return Ok({})
end)

-- Private conversations start from a post: "reply privately".
ShadowRpc.Register('thread:open', { perMinute = 10 }, function(source, payload)
    local device, failure = require_access(source, true)
    if not device then
        return failure
    end
    local message_id = type(payload) == 'table' and math.tointeger(tonumber(payload.messageId))
    local origin = message_id and MySQL.single.await(
        'SELECT `imei`, `alias`, `body` FROM `shadow_messages` WHERE `id` = ? AND `channel` IS NOT NULL',
        { message_id }
    )
    if not origin then
        return Fail('message_gone')
    end
    if origin.imei == device.imei then
        return Fail('own_message')
    end
    local existing = MySQL.scalar.await([[
        SELECT `id` FROM `shadow_threads`
        WHERE (`imei_a` = ? AND `imei_b` = ?) OR (`imei_a` = ? AND `imei_b` = ?) LIMIT 1
    ]], { device.imei, origin.imei, origin.imei, device.imei })
    if existing then
        return Ok({ threadId = existing })
    end
    local thread_id = MySQL.insert.await([[
        INSERT INTO `shadow_threads` (`imei_a`, `imei_b`, `alias_a`, `alias_b`, `topic`, `last_at`)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { device.imei, origin.imei, device.alias, origin.alias, origin.body:sub(1, 120), now() })
    return Ok({ threadId = thread_id })
end)

local function load_thread(thread_id, imei)
    thread_id = math.tointeger(tonumber(thread_id))
    local thread = thread_id and MySQL.single.await('SELECT * FROM `shadow_threads` WHERE `id` = ?', { thread_id })
    if not thread or (thread.imei_a ~= imei and thread.imei_b ~= imei) then
        return nil
    end
    return thread
end

ShadowRpc.Register('threads:list', { perMinute = 30 }, function(source)
    local device, failure = require_access(source, false)
    if not device then
        return failure
    end
    local rows = MySQL.query.await([[
        SELECT t.*, (
            SELECT `body` FROM `shadow_messages` m WHERE m.`thread_id` = t.`id` ORDER BY m.`id` DESC LIMIT 1
        ) AS `last_body`
        FROM `shadow_threads` t WHERE t.`imei_a` = ? OR t.`imei_b` = ?
        ORDER BY t.`last_at` DESC LIMIT 50
    ]], { device.imei, device.imei }) or {}
    local threads = {}
    for index, row in ipairs(rows) do
        threads[index] = {
            id = row.id,
            alias = row.imei_a == device.imei and row.alias_b or row.alias_a,
            topic = row.topic,
            lastBody = row.last_body,
            lastAt = row.last_at,
        }
    end
    return Ok({ threads = threads })
end)

ShadowRpc.Register('thread:read', { perMinute = 60 }, function(source, payload)
    local device, failure = require_access(source, false)
    if not device then
        return failure
    end
    local thread = type(payload) == 'table' and load_thread(payload.threadId, device.imei)
    if not thread then
        return Fail('thread_gone')
    end
    local after = math.tointeger(tonumber(payload.after)) or 0
    local rows = MySQL.query.await([[
        SELECT `id`, `alias`, `body`, `is_ad`, `imei`, `created_at` FROM `shadow_messages`
        WHERE `thread_id` = ? AND `id` > ? ORDER BY `id` ASC LIMIT 200
    ]], { thread.id, after }) or {}
    local messages = {}
    for index, row in ipairs(rows) do
        messages[index] = message_payload(row, device.imei)
    end
    return Ok({
        thread = {
            id = thread.id,
            alias = thread.imei_a == device.imei and thread.alias_b or thread.alias_a,
            topic = thread.topic,
        },
        messages = messages,
    })
end)

ShadowRpc.Register('thread:send', { perMinute = Config.Messages.DirectPerMinute }, function(source, payload)
    local device, failure = require_access(source, true)
    if not device then
        return failure
    end
    local thread = type(payload) == 'table' and load_thread(payload.threadId, device.imei)
    if not thread then
        return Fail('thread_gone')
    end
    local body, body_error = clean_body(payload.body)
    if not body then
        return Fail(body_error)
    end
    local time = now()
    MySQL.insert.await([[
        INSERT INTO `shadow_messages` (`thread_id`, `imei`, `alias`, `author_identifier`, `body`, `created_at`)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { thread.id, device.imei, device.alias, identifier_of(source) or '', body, time })
    MySQL.update.await('UPDATE `shadow_threads` SET `last_at` = ? WHERE `id` = ?', { time, thread.id })
    return Ok({})
end)

-- Police: extracting a seized phone takes time and gives read-only access.
ShadowRpc.Register('extract:start', { perMinute = 4 }, function(source)
    if not is_police(source) then
        return Fail('not_police')
    end
    local imei = current_imei(source)
    local device = imei and load_device(imei)
    if not device then
        return Fail('not_installed')
    end
    if device.owner_identifier == identifier_of(source) then
        return Fail('own_phone')
    end
    extractions[source] = { imei = imei, startedAt = now(), done = false }
    ShadowUtil.Log('info', 'Officer %s started extracting Shadow from phone %s.', identifier_of(source), imei)
    return Ok({ seconds = Config.Police.CrackSeconds })
end)

ShadowRpc.Register('extract:finish', { perMinute = 10 }, function(source)
    local extraction = extractions[source]
    if not extraction or not is_police(source) then
        return Fail('not_started')
    end
    if extraction.imei ~= current_imei(source) then
        extractions[source] = nil
        return Fail('phone_changed')
    end
    if now() - extraction.startedAt < Config.Police.CrackSeconds then
        return Fail('not_ready')
    end
    extraction.done = true
    local device = load_device(extraction.imei)
    return Ok({ alias = device and device.alias or '' })
end)

-- The app locks again every time it is closed.
ShadowRpc.Register('lock', nil, function(source)
    sessions[source] = nil
    return Ok({})
end)

-- Everything older than LifetimeHours disappears.
CreateThread(function()
    while true do
        Wait(10 * 60 * 1000)
        if ShadowDatabase.Ready then
            local cutoff = now() - Config.Messages.LifetimeHours * 3600
            MySQL.query('DELETE FROM `shadow_messages` WHERE `created_at` < ?', { cutoff })
            MySQL.query('DELETE FROM `shadow_threads` WHERE `last_at` < ?', { cutoff })
        end
    end
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    extractions[source] = nil
    device_cache[source] = nil
end)
