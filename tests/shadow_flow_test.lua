-- Runs the Shadow server scripts against fake FiveM, ESX, oxmysql and Sky Phone.
-- Run from the repository root: lua5.4 tests/shadow_flow_test.lua

local threads, net_handlers, event_handlers, client_events = {}, {}, {}, {}

local function run(fn, ...)
    local co = coroutine.create(fn)
    local ok, err = coroutine.resume(co, ...)
    if not ok then error(err, 0) end
    if coroutine.status(co) == 'suspended' then threads[#threads + 1] = co end
end

function GetCurrentResourceName() return 'shadow' end
function CreateThread(fn) run(fn) end
function Wait() coroutine.yield() end
function SetTimeout() end
local timer = 0
function GetGameTimer() timer = timer + 20000; return timer end
function GetResourceState() return 'started' end
function RegisterNetEvent(name, handler) if handler then net_handlers[name] = handler end end
function AddEventHandler(name, handler)
    event_handlers[name] = event_handlers[name] or {}
    table.insert(event_handlers[name], handler)
end
function TriggerClientEvent(name, target, ...) client_events[#client_events + 1] = { name = name, target = target, args = { ... } } end
TriggerLatentClientEvent = function(name, target, _, ...) TriggerClientEvent(name, target, ...) end

local vec_meta = {
    __sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, getmetatable(a)) end,
    __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end,
}
function vector3(x, y, z) return setmetatable({ x = x, y = y, z = z }, vec_meta) end

promise = {}
promise.__index = promise
function promise.new() return setmetatable({ done = false }, promise) end
function promise:resolve(value) self.done = true; self.value = value end
Citizen = { Await = function(p) while not p.done do coroutine.yield() end return p.value end }

local positions, players, imei_for = {}, {}, {}
function GetPlayerPed(src) return src end
function GetEntityCoords(ped) return positions[ped] end

local ESX = { GetPlayerFromId = function(src) return players[src] end }
exports = {
    es_extended = { getSharedObject = function() return ESX end },
    sky_phone = { GetOnlineDeviceBySource = function(_, src) return { imei = imei_for[src] } end },
    shadow = {
        hashPin = function(_, pin, callback) callback('h:' .. pin) end,
        verifyPin = function(_, pin, encoded, callback) callback(encoded == 'h:' .. pin) end,
    },
}

-- Fake oxmysql for the queries Shadow uses
local devices, messages, dthreads = {}, {}, {}
local next_message, next_thread = 0, 0
local function has(sql, text) return sql:find(text, 1, true) ~= nil end
local function copy(row) local out = {} for k, v in pairs(row) do out[k] = v end return out end

local function query(sql, p)
    p = p or {}
    if has(sql, 'CREATE TABLE') then return {} end
    if has(sql, 'DELETE FROM `shadow_devices`') then devices[p[1]] = nil; return {} end
    if has(sql, 'GROUP BY `channel`') then
        local stats = {}
        for _, m in ipairs(messages) do
            if m.channel and m.created_at > p[1] then
                local s = stats[m.channel] or { channel = m.channel, count = 0, last_at = 0 }
                s.count = s.count + 1; s.last_at = math.max(s.last_at, m.created_at); stats[m.channel] = s
            end
        end
        local rows = {} for _, s in pairs(stats) do rows[#rows + 1] = s end
        return rows
    end
    if has(sql, 'WHERE `channel` = ?') then
        local rows = {}
        for _, m in ipairs(messages) do if m.channel == p[1] and m.id > p[2] then rows[#rows + 1] = copy(m) end end
        return rows
    end
    if has(sql, 'WHERE `thread_id` = ?') then
        local rows = {}
        for _, m in ipairs(messages) do if m.thread_id == p[1] and m.id > p[2] then rows[#rows + 1] = copy(m) end end
        return rows
    end
    if has(sql, 'FROM `shadow_threads` t') then
        local rows = {}
        for _, t in pairs(dthreads) do
            if t.imei_a == p[1] or t.imei_b == p[1] then
                local row = copy(t)
                for _, m in ipairs(messages) do if m.thread_id == t.id then row.last_body = m.body end end
                rows[#rows + 1] = row
            end
        end
        return rows
    end
    error('unhandled query: ' .. sql)
end

local function single(sql, p)
    if has(sql, 'FROM `shadow_devices` WHERE `imei`') then return devices[p[1]] and copy(devices[p[1]]) end
    if has(sql, 'FROM `shadow_messages` WHERE `id` = ?') then
        for _, m in ipairs(messages) do if m.id == p[1] and m.channel then return copy(m) end end
        return nil
    end
    if has(sql, 'FROM `shadow_threads` WHERE `id`') then return dthreads[p[1]] and copy(dthreads[p[1]]) end
    error('unhandled single: ' .. sql)
end

local function scalar(sql, p)
    if has(sql, 'LOWER(`alias`)') then
        for imei, d in pairs(devices) do if d.alias:lower() == p[1]:lower() and imei ~= p[2] then return 1 end end
        return nil
    end
    if has(sql, 'SELECT `id` FROM `shadow_threads`') then
        for _, t in pairs(dthreads) do
            if (t.imei_a == p[1] and t.imei_b == p[2]) or (t.imei_a == p[3] and t.imei_b == p[4]) then return t.id end
        end
        return nil
    end
    error('unhandled scalar: ' .. sql)
end

local function insert(sql, p)
    if has(sql, 'INSERT INTO `shadow_devices`') then
        devices[p[1]] = { imei = p[1], alias = p[2], owner_identifier = p[3], pin_hash = nil,
            failed_attempts = 0, locks_in_row = 0, locked_until = 0, alias_changed_at = 0 }
        return 1
    end
    if has(sql, 'INSERT INTO `shadow_threads`') then
        next_thread = next_thread + 1
        dthreads[next_thread] = { id = next_thread, imei_a = p[1], imei_b = p[2], alias_a = p[3], alias_b = p[4], topic = p[5], last_at = p[6] }
        return next_thread
    end
    if has(sql, '(`channel`, `is_ad`') then
        next_message = next_message + 1
        messages[#messages + 1] = { id = next_message, channel = p[1], is_ad = p[2], imei = p[3], alias = p[4], author_identifier = p[5], body = p[6], created_at = p[7] }
        return next_message
    end
    if has(sql, '(`thread_id`, `imei`') then
        next_message = next_message + 1
        messages[#messages + 1] = { id = next_message, thread_id = p[1], is_ad = 0, imei = p[2], alias = p[3], author_identifier = p[4], body = p[5], created_at = p[6] }
        return next_message
    end
    error('unhandled insert: ' .. sql)
end

local function update(sql, p)
    if has(sql, 'SET `failed_attempts` = 0, `locks_in_row` = 0') then
        devices[p[1]].failed_attempts = 0; devices[p[1]].locks_in_row = 0; return 1
    end
    if has(sql, 'SET `failed_attempts` = ? WHERE') then devices[p[2]].failed_attempts = p[1]; return 1 end
    if has(sql, 'SET `failed_attempts` = 0, `locks_in_row` = ?, `locked_until` = ?') then
        devices[p[3]].failed_attempts = 0; devices[p[3]].locks_in_row = p[1]; devices[p[3]].locked_until = p[2]; return 1
    end
    if has(sql, 'SET `pin_hash` = NULL') then devices[p[1]].pin_hash = nil; return 1 end
    if has(sql, 'SET `pin_hash` = ?') then devices[p[2]].pin_hash = p[1]; return 1 end
    if has(sql, 'SET `alias` = ?') then devices[p[3]].alias = p[1]; devices[p[3]].alias_changed_at = p[2]; return 1 end
    if has(sql, 'UPDATE `shadow_threads` SET `last_at`') then dthreads[p[2]].last_at = p[1]; return 1 end
    error('unhandled update: ' .. sql)
end

MySQL = {
    ready = function(callback) run(callback) end,
    query = setmetatable({ await = query }, { __call = function(_, s, p) return query(s, p) end }),
    single = { await = single },
    scalar = { await = scalar },
    insert = { await = insert },
    update = { await = update },
}

for _, file in ipairs({ 'config.lua', 'server/util.lua', 'server/rpc.lua', 'server/database.lua', 'server/main.lua' }) do
    dofile('shadow/' .. file)
end

local passed = 0
local function check(name, condition, detail)
    if not condition then error(('FAILED: %s (%s)'):format(name, tostring(detail)), 2) end
    passed = passed + 1
    print('ok - ' .. name)
end

local request = 0
local function call(src, name, payload)
    request = request + 1
    client_events = {}
    _G.source = src
    run(net_handlers['shadow:rpc:request'], request, name, payload)
    for _, event in ipairs(client_events) do
        if event.name == 'shadow:rpc:response' and event.args[1] == request then return event.args[2] end
    end
    error('no response for ' .. name)
end

local spot = Config.UnlockPoints[1].coords
players[1] = { identifier = 'char:crook', job = { name = 'unemployed', grade = 0 } }
players[2] = { identifier = 'char:dealer', job = { name = 'unemployed', grade = 0 } }
players[3] = { identifier = 'char:cop', job = { name = 'police', grade = 2 } }
imei_for[1], imei_for[2], imei_for[3] = 'IMEI-A', 'IMEI-B', 'IMEI-COP'
positions[1], positions[2], positions[3] = vector3(0, 0, 0), spot, vector3(0, 0, 0)

check('database ready', ShadowDatabase.Ready)
check('not installed by default', call(1, 'status').data.installed == false)
check('cannot read without the app', call(1, 'channels:list').error == 'not_installed')
check('install away from a spot is refused', call(1, 'install').error == 'not_here')

positions[1] = spot
check('install at the hidden spot', call(1, 'install').ok)
check('installed and open without PIN', call(1, 'status').data.unlocked == true)
check('second phone installs', call(2, 'install').ok)

check('alias can be chosen', call(1, 'alias:set', { alias = 'Der Fahrer' }).data.alias == 'Der Fahrer')
check('alias change has a cooldown', call(1, 'alias:set', { alias = 'Anders' }).error == 'alias_cooldown')
check('aliases are unique', call(2, 'alias:set', { alias = 'der fahrer' }).error == 'alias_taken')

check('post an offer', call(2, 'channel:post', { channel = 'jobs', body = 'Suche Fahrer', ad = true }).ok)
check('unknown channel refused', call(2, 'channel:post', { channel = 'nope', body = 'x' }).error == 'invalid_channel')
local feed = call(1, 'channel:read', { channel = 'jobs' })
check('feed shows the offer without identity', feed.ok and #feed.data.messages == 1
    and feed.data.messages[1].isAd and feed.data.messages[1].author_identifier == nil and not feed.data.messages[1].mine)
check('channel list shows activity', call(1, 'channels:list').data.channels[2].count == 1)

local opened = call(1, 'thread:open', { messageId = feed.data.messages[1].id })
check('reply privately opens a thread', opened.ok, opened.error)
check('same pair reuses the thread', call(1, 'thread:open', { messageId = feed.data.messages[1].id }).data.threadId == opened.data.threadId)
check('cannot reply to own post', call(2, 'thread:open', { messageId = feed.data.messages[1].id }).error == 'own_message')
check('send private message', call(1, 'thread:send', { threadId = opened.data.threadId, body = 'Bin dabei' }).ok)
local dealer_threads = call(2, 'threads:list')
check('other side sees the thread under the alias', dealer_threads.data.threads[1].alias == 'Der Fahrer'
    and dealer_threads.data.threads[1].lastBody == 'Bin dabei')
check('outsider cannot read thread', call(3, 'thread:read', { threadId = opened.data.threadId }).error == 'no_phone'
    or call(3, 'thread:read', { threadId = opened.data.threadId }).error == 'not_installed')

check('set PIN', call(1, 'pin:set', { pin = '4711' }).data.hasPin == true)
check('PIN length enforced', call(1, 'pin:set', { pin = '12' }).error == 'invalid_pin')
call(1, 'lock')
check('locked after closing', call(1, 'channels:list').error == 'locked')
local wrong = call(1, 'pin:verify', { pin = '0000' })
check('wrong PIN counts down', wrong.error == 'wrong_pin' and wrong.remaining == 4)
check('right PIN unlocks', call(1, 'pin:verify', { pin = '4711' }).ok and call(1, 'channels:list').ok)

-- Phone is seized: the officer now holds IMEI-A
call(1, 'lock')
imei_for[3] = 'IMEI-A'
check('officer sees locked app', call(3, 'status').data.unlocked == false and call(3, 'status').data.foreignPhone == true)
check('owner cannot use police extraction', call(1, 'extract:start').error == 'not_police')
check('extraction starts', call(3, 'extract:start').data.seconds == Config.Police.CrackSeconds)
check('extraction needs time', call(3, 'extract:finish').error == 'not_ready')
local real_time = os.time
os.time = function() return real_time() + Config.Police.CrackSeconds + 1 end
check('extraction finishes', call(3, 'extract:finish').ok)
os.time = real_time
check('police reads private messages', call(3, 'thread:read', { threadId = opened.data.threadId }).data.messages[1].body == 'Bin dabei')
check('police cannot write', call(3, 'thread:send', { threadId = opened.data.threadId, body = 'x' }).error == 'locked')

-- Wrong PINs: lock, and wipe after repeated locks
for round = 1, Config.Security.WipeAfterLocks do
    devices['IMEI-A'].locked_until = 0
    local last
    for _ = 1, Config.Security.MaxAttempts do last = call(1, 'pin:verify', { pin = '9999' }) end
    if round < Config.Security.WipeAfterLocks then
        check('locked after too many wrong PINs (' .. round .. ')', last.error == 'pin_locked')
        check('locked phone refuses even the right PIN', call(1, 'pin:verify', { pin = '4711' }).error == 'pin_locked')
    else
        check('app wipes itself after repeated locks', last.error == 'wiped' and devices['IMEI-A'] == nil)
    end
end
check('wiped phone no longer has the app', call(1, 'status').data.installed == false)

print(('\n%d checks passed'):format(passed))
