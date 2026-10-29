-- Runs the Snitch server scripts against fake FiveM, ESX, oxmysql, okokBanking
-- and Sky Phone APIs and plays through a full session.
-- Run from the repository root: lua5.4 tests/server_flow_test.lua

------------------------------------------------------------------------------
-- Fake FiveM runtime
------------------------------------------------------------------------------

local threads = {}
local net_handlers = {}
local event_handlers = {}
local client_events = {}

local function run(fn, ...)
    local co = coroutine.create(fn)
    local ok, err = coroutine.resume(co, ...)
    if not ok then error(err, 0) end
    if coroutine.status(co) == 'suspended' then threads[#threads + 1] = co end
end

local function tick(times)
    for _ = 1, times or 1 do
        local current = threads
        threads = {}
        for _, co in ipairs(current) do
            local ok, err = coroutine.resume(co)
            if not ok then error(err, 0) end
            if coroutine.status(co) == 'suspended' then threads[#threads + 1] = co end
        end
    end
end

function GetCurrentResourceName() return 'snitch' end
function CreateThread(fn) run(fn) end
function Wait() coroutine.yield() end
function SetTimeout() end
local timer = 0
function GetGameTimer() timer = timer + 1000; return timer end
function GetResourceState() return 'started' end

local online = {}
function GetPlayerName(src) return online[src] and ('Player' .. src) or nil end

function RegisterNetEvent(name, handler)
    if handler then net_handlers[name] = handler end
end

function AddEventHandler(name, handler)
    event_handlers[name] = event_handlers[name] or {}
    table.insert(event_handlers[name], handler)
end

function TriggerEvent(name, ...)
    for _, handler in ipairs(event_handlers[name] or {}) do run(handler, ...) end
end

function TriggerClientEvent(name, target, ...)
    client_events[#client_events + 1] = { name = name, target = target, args = { ... } }
end
TriggerLatentClientEvent = function(name, target, _, ...) TriggerClientEvent(name, target, ...) end

promise = {}
promise.__index = promise
function promise.new() return setmetatable({ done = false }, promise) end
function promise:resolve(value) self.done = true; self.value = value end
Citizen = {
    Await = function(p)
        while not p.done do coroutine.yield() end
        return p.value
    end,
}

------------------------------------------------------------------------------
-- Fake ESX, okokBanking, Sky Phone, password hashing
------------------------------------------------------------------------------

local players = {}
local society = {}
local bank_transactions = {}

local function make_player(src, identifier, money)
    local player = { source = src, identifier = identifier, money = money }
    function player.getName() return 'Char ' .. identifier end
    function player.getAccount(name) return name == 'bank' and { money = player.money } or nil end
    function player.removeAccountMoney(_, amount) player.money = player.money - amount end
    function player.addAccountMoney(_, amount) player.money = player.money + amount end
    players[src] = player
    online[src] = true
    return player
end

local ESX = {}
function ESX.GetPlayerFromId(src) return online[src] and players[src] or nil end
function ESX.GetPlayerFromIdentifier(identifier)
    for src, player in pairs(players) do
        if online[src] and player.identifier == identifier then return player end
    end
end
function ESX.GetExtendedPlayers()
    local list = {}
    for src, player in pairs(players) do if online[src] then list[#list + 1] = player end end
    return list
end

local imei_for = {}

exports = {
    es_extended = { getSharedObject = function() return ESX end },
    sky_phone = {
        GetOnlineDeviceBySource = function(_, src) return { imei = imei_for[src] } end,
    },
    okokBanking = {
        AddMoney = function(_, name, amount) society[name] = (society[name] or 0) + amount end,
        GetAccount = function(_, name) return name == 'government' and 0 or nil end,
        AddTransaction = function(_, identifier, data) bank_transactions[#bank_transactions + 1] = { identifier, data } end,
    },
    snitch = {
        hashPassword = function(_, password, callback) callback('hash:' .. password) end,
        verifyPassword = function(_, password, encoded, callback) callback(encoded == 'hash:' .. password) end,
    },
}

------------------------------------------------------------------------------
-- Fake oxmysql (only the queries Snitch uses)
------------------------------------------------------------------------------

local db = { accounts = {}, sessions = {}, streams = {}, donations = {} }
local ids = { accounts = 0, streams = 0, donations = 0 }

local function has(sql, text) return sql:find(text, 1, true) ~= nil end

local function query(sql, params)
    params = params or {}
    if has(sql, 'CREATE TABLE') or has(sql, 'WHERE `ended_at` IS NULL') then return {} end
    if has(sql, 'REPLACE INTO `snitch_sessions`') then db.sessions[params[1]] = params[2]; return {} end
    if has(sql, 'DELETE FROM `snitch_sessions` WHERE `account_id`') then
        for imei, account in pairs(db.sessions) do if account == params[1] then db.sessions[imei] = nil end end
        return {}
    end
    if has(sql, 'DELETE FROM `snitch_sessions` WHERE `imei`') then db.sessions[params[1]] = nil; return {} end
    if has(sql, 'SELECT `id`, `net` FROM `snitch_donations`') then
        local rows = {}
        for _, row in ipairs(db.donations) do
            if row.payout_identifier == params[1] and row.paid_out == 0 then rows[#rows + 1] = { id = row.id, net = row.net } end
        end
        return rows
    end
    if has(sql, 'FROM `snitch_streams` s') or has(sql, "DATE_FORMAT") or has(sql, 'JOIN `snitch_accounts` a') then return {} end
    error('unhandled query: ' .. sql)
end

local function single(sql, params)
    if has(sql, 'FROM `snitch_accounts` WHERE `id` = ?') then
        local row = db.accounts[params[1]]
        if not row then return nil end
        local copy = {}
        for key, value in pairs(row) do copy[key] = value end
        return copy
    end
    if has(sql, '`username_key` = ? AS `username_taken`') then
        for _, row in pairs(db.accounts) do
            if row.username_key == params[1] or row.email == params[2] then
                return { username_taken = row.username_key == params[1] and 1 or 0, email_taken = row.email == params[2] and 1 or 0 }
            end
        end
        return nil
    end
    if has(sql, 'WHERE `email` = ?') then
        for _, row in pairs(db.accounts) do
            if row.email == params[1] then return { id = row.id, password_hash = row.password_hash, banned = row.banned } end
        end
        return nil
    end
    if has(sql, 'COUNT(*) AS `donations`') then
        local totals = { donations = 0, gross = 0, fee = 0, tax = 0, net = 0, pending = 0 }
        for _, row in ipairs(db.donations) do
            if row.streamer_account_id == params[1] then
                totals.donations = totals.donations + 1
                for _, key in ipairs({ 'gross', 'fee', 'tax', 'net' }) do totals[key] = totals[key] + row[key] end
                if row.paid_out == 0 then totals.pending = totals.pending + row.net end
            end
        end
        for key, value in pairs(totals) do totals[key] = tostring(value) end -- drivers may return strings
        return totals
    end
    error('unhandled single: ' .. sql)
end

local function scalar(sql, params)
    if has(sql, 'SELECT `account_id` FROM `snitch_sessions`') then return db.sessions[params[1]] end
    if has(sql, 'COUNT(*) FROM `snitch_accounts`') then
        local count = 0
        for _, row in pairs(db.accounts) do if row.owner_identifier == params[1] then count = count + 1 end end
        return count
    end
    error('unhandled scalar: ' .. sql)
end

local function insert(sql, params)
    if has(sql, 'INSERT INTO `snitch_accounts`') then
        ids.accounts = ids.accounts + 1
        db.accounts[ids.accounts] = {
            id = ids.accounts, username = params[1], username_key = params[2], email = params[3],
            password_hash = params[4], owner_identifier = params[5], avatar_color = params[6],
            bio = '', banned = 0, created_at = os.time(),
        }
        return ids.accounts
    end
    if has(sql, 'INSERT INTO `snitch_streams`') then
        ids.streams = ids.streams + 1
        db.streams[ids.streams] = { id = ids.streams, account_id = params[1], title = params[2], category = params[3] }
        return ids.streams
    end
    if has(sql, 'INSERT INTO `snitch_donations`') then
        ids.donations = ids.donations + 1
        db.donations[#db.donations + 1] = {
            id = ids.donations, stream_id = params[1], streamer_account_id = params[2], donor_account_id = params[3],
            donor_identifier = params[4], payout_identifier = params[5], gross = params[6], fee = params[7],
            tax = params[8], net = params[9], message = params[10], paid_out = 0,
        }
        return ids.donations
    end
    error('unhandled insert: ' .. sql)
end

local function update(sql, params)
    if has(sql, 'SET `paid_out` = 1 WHERE `id` = ? AND `paid_out` = 0') then
        for _, row in ipairs(db.donations) do
            if row.id == params[1] and row.paid_out == 0 then row.paid_out = 1; return 1 end
        end
        return 0
    end
    if has(sql, 'SET `paid_out` = 1 WHERE `paid_out` = 0 AND `id` IN') then
        local wanted, count = {}, 0
        for _, id in ipairs(params) do wanted[id] = true end
        for _, row in ipairs(db.donations) do
            if wanted[row.id] and row.paid_out == 0 then row.paid_out = 1; count = count + 1 end
        end
        return count
    end
    if has(sql, 'SET `paid_out` = 0') then return 0 end
    if has(sql, 'UPDATE `snitch_streams` SET `ended_at`') then
        local row = db.streams[params[#params]]
        if row then row.ended = true; row.peak = params[1] end
        return 1
    end
    if has(sql, 'UPDATE `snitch_accounts` SET `avatar_color`') then
        db.accounts[params[3]].avatar_color = params[1]
        db.accounts[params[3]].bio = params[2]
        return 1
    end
    error('unhandled update: ' .. sql)
end

MySQL = {
    ready = function(callback) run(callback) end,
    query = setmetatable({ await = query }, { __call = function(_, sql, params) return query(sql, params) end }),
    single = { await = single },
    scalar = { await = scalar },
    insert = { await = insert },
    update = setmetatable({ await = update }, { __call = function(_, sql, params) return update(sql, params) end }),
}

------------------------------------------------------------------------------
-- Load the resource like fxmanifest.lua does
------------------------------------------------------------------------------

for _, file in ipairs({
    'config.lua', 'shared/split.lua', 'server/util.lua', 'server/rpc.lua', 'server/database.lua',
    'server/bank.lua', 'server/accounts.lua', 'server/streams.lua', 'server/donations.lua', 'server/earnings.lua',
}) do
    dofile('snitch/' .. file)
end

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local passed = 0
local function check(name, condition, detail)
    if not condition then error(('FAILED: %s %s'):format(name, detail and ('(' .. tostring(detail) .. ')') or ''), 2) end
    passed = passed + 1
    print('ok - ' .. name)
end

local request_id = 0
local function call(src, name, payload)
    request_id = request_id + 1
    local id = request_id
    client_events = {}
    _G.source = src
    run(net_handlers['snitch:rpc:request'], id, name, payload)
    for _, event in ipairs(client_events) do
        if event.name == 'snitch:rpc:response' and event.args[1] == id then return event.args[2] end
    end
    error('no response for ' .. name)
end

local function events_named(name)
    local found = {}
    for _, event in ipairs(client_events) do if event.name == name then found[#found + 1] = event end end
    return found
end

local function net(src, name, ...)
    client_events = {}
    _G.source = src
    run(net_handlers[name], ...)
end

------------------------------------------------------------------------------
-- Scenario
------------------------------------------------------------------------------

check('database ready', SnitchDatabase.Ready)

local streamer = make_player(1, 'char1:streamer', 10000)
local viewer = make_player(2, 'char1:viewer', 10000)
make_player(3, 'char1:friend', 500)
imei_for[1], imei_for[2], imei_for[3] = '350000000000001', '350000000000002', '350000000000003'

local bootstrap = call(2, 'app:bootstrap')
check('bootstrap works logged out', bootstrap.ok and bootstrap.data.loggedIn == false)

local registered = call(1, 'auth:register', { username = 'LS_Live', email = 'Live@iFruit.com', password = 'supersecret' })
check('streamer registers', registered.ok and registered.data.account.username == 'LS_Live', registered.error)
check('email stored lowercase', registered.data.account.email == 'live@ifruit.com')
check('streamer owns payouts', registered.data.account.isPayoutOwner == true)

check('username is unique (case-insensitive)',
    call(2, 'auth:register', { username = 'ls_live', email = 'x@ifruit.com', password = 'supersecret' }).error == 'username_taken')
check('invalid username rejected',
    call(2, 'auth:register', { username = 'a b', email = 'x@ifruit.com', password = 'supersecret' }).error == 'invalid_username')
check('short password rejected',
    call(2, 'auth:register', { username = 'viewer', email = 'x@ifruit.com', password = 'short' }).error == 'invalid_password')

local viewer_account = call(2, 'auth:register', { username = 'viewer', email = 'viewer@ifruit.com', password = 'supersecret' })
check('viewer registers', viewer_account.ok, viewer_account.error)

check('wrong password rejected',
    call(3, 'auth:login', { email = 'viewer@ifruit.com', password = 'wrong-password' }).error == 'invalid_credentials')
check('unknown email rejected',
    call(3, 'auth:login', { email = 'nobody@ifruit.com', password = 'whatever1' }).error == 'invalid_credentials')

local started = call(1, 'stream:start', { title = '  Nachtfahrt\nVinewood  ', category = 'driving' })
check('stream starts', started.ok, started.error)
local stream_id = started.data.stream.id
check('title is cleaned', started.data.stream.title == 'Nachtfahrt Vinewood', started.data.stream.title)
check('video config sent', started.data.video.Fps == 30)
check('second start rejected', call(1, 'stream:start', { title = 'x', category = 'driving' }).error == 'already_live')
check('logged-out player cannot go live', call(3, 'stream:start', { title = 'x', category = 'driving' }).error == 'not_logged_in')
check('invalid category rejected', call(2, 'stream:start', { title = 'x', category = 'nope' }).error == 'invalid_category')

local list = call(2, 'streams:list')
check('stream is listed', list.ok and #list.data.streams == 1 and list.data.streams[1].streamer.username == 'LS_Live')

check('host cannot watch own stream', call(1, 'stream:join', { streamId = stream_id }).error == 'own_stream')
local joined = call(2, 'stream:join', { streamId = stream_id + 0.0 })
check('viewer joins (float id from JSON)', joined.ok, joined.error)

local chat = call(2, 'chat:send', { streamId = stream_id, text = 'Hallo <b>Chat</b>' })
check('chat accepted', chat.ok, chat.error)
check('empty chat rejected', call(2, 'chat:send', { streamId = stream_id, text = '   ' }).error == 'empty_text')
client_events = {}
tick(3)
local batches = events_named('snitch:room:chat')
check('chat batch reaches host and viewer', #batches == 2, #batches)
check('chat text kept as text', batches[1].args[2][1].text == 'Hallo <b>Chat</b>')

net(2, 'snitch:rtc:signal', stream_id, nil, { kind = 'offer', sdp = 'v=0' })
local forwarded = events_named('snitch:rtc:signal')
check('viewer offer goes to host', #forwarded == 1 and forwarded[1].target == 1 and forwarded[1].args[2] == 2)
net(1, 'snitch:rtc:signal', stream_id, 2.0, { kind = 'answer', sdp = 'v=0', extra = 'dropped' })
forwarded = events_named('snitch:rtc:signal')
check('host answer goes to viewer with integer id', #forwarded == 1 and math.type(forwarded[1].target) == 'integer')
check('signal is sanitized', forwarded[1].args[3].extra == nil)
net(3, 'snitch:rtc:signal', stream_id, 1, { kind = 'offer', sdp = 'v=0' })
check('outsider cannot signal', #events_named('snitch:rtc:signal') == 0)

-- Donation while the account owner is online
local donation = call(2, 'donate', { streamId = stream_id, amount = 1000, message = 'Weiter so!' })
check('donation accepted', donation.ok, donation.error)
local host_earnings = events_named('snitch:host:earnings')
check('host sees live earnings', #host_earnings == 1 and host_earnings[1].target == 1
    and host_earnings[1].args[2].net == 425 and host_earnings[1].args[2].gross == 1000)
check('donation split 50 % fee, 15 % tax on the rest',
    donation.data.split.fee == 500 and donation.data.split.tax == 75 and donation.data.split.net == 425)
check('viewer charged', viewer.money == 9000, viewer.money)
check('streamer paid', streamer.money == 10425, streamer.money)
check('taxes booked to state account', society.government == 75, society.government)
check('platform fee leaves the economy', society['false'] == nil and next(society, 'government') == nil)
check('donation marked paid', db.donations[1].paid_out == 1)
check('bank history written', #bank_transactions >= 2)
check('cooldown applies', call(2, 'donate', { streamId = stream_id, amount = 100 }).error == 'cooldown')

-- Account owner goes offline, a friend streams with the same login on another phone
local ended = call(1, 'stream:end')
check('stream ends', ended.ok)
local summary = events_named('snitch:host:ended')
check('host gets summary', #summary == 1 and summary[1].args[3].net == 425 and summary[1].args[3].donations == 1)
check('viewer told stream ended', #events_named('snitch:room:ended') == 1)

online[1] = nil
local login = call(3, 'auth:login', { email = 'live@ifruit.com', password = 'supersecret' })
check('login on another phone', login.ok and login.data.account.isPayoutOwner == false, login.error)
local second = call(3, 'stream:start', { title = 'Zweiter Stream', category = 'irl' })
check('second stream starts', second.ok, second.error)
check('viewer joins second stream', call(2, 'stream:join', { streamId = second.data.stream.id }).ok)

-- Cooldown is 5 s; pretend it passed.
local saved_time = os.time
os.time = function() return saved_time() + 10 end
local pending = call(2, 'donate', { streamId = second.data.stream.id, amount = 200 })
os.time = saved_time
check('donation to offline owner accepted', pending.ok, pending.error)
check('friend does not receive the payout', players[3].money == 500, players[3].money)
check('payout stays pending', db.donations[2].paid_out == 0)
check('insufficient funds rejected',
    (function()
        os.time = function() return saved_time() + 20 end
        local result = call(2, 'donate', { streamId = second.data.stream.id, amount = 50000 })
        os.time = saved_time
        return result.error == 'insufficient_funds'
    end)())

local earnings = call(3, 'earnings:summary')
check('earnings summary', earnings.ok and earnings.data.totals.gross == 1200 and earnings.data.totals.pending == 85,
    earnings.ok and earnings.data.totals.pending or earnings.error)
check('earnings numbers are numbers', math.type(earnings.data.totals.net) ~= nil)

online[1] = true
TriggerEvent('esx:playerLoaded', 1, players[1])
check('owner paid on next login', streamer.money == 10425 + 85, streamer.money)
check('pending donation marked paid', db.donations[2].paid_out == 1)

-- Host leaves the city
_G.source = 3
client_events = {}
TriggerEvent('playerDropped', 'quit')
check('stream ends when host drops', #events_named('snitch:room:ended') == 1)
check('no streams left', #call(2, 'streams:list').data.streams == 0)

local logout = call(2, 'auth:logout', {})
check('logout', logout.ok)
check('logged out after logout', call(2, 'auth:status').data.account == false)

print(('\n%d checks passed'):format(passed))
