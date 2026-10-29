-- Live rooms: who streams, who watches, chat and WebRTC signalling.
-- Everything here lives in memory; only start/end summaries reach the database.

SnitchStreams = {}

local streams = {}
local memberships = {}
local starting = {}
local stream_count = 0
local message_sequence = 0

local chat_limiter = SnitchUtil.NewLimiter(Config.Chat.MessagesPerMinute, 60)
local signal_limiter = SnitchUtil.NewLimiter(600, 60)
local thumbnail_limiter = SnitchUtil.NewLimiter(6, 60)

local THUMBNAIL_PREFIX = 'data:image/jpeg;base64,'
local THUMBNAIL_MAX_BYTES = 80000
local SDP_MAX_BYTES = 20000

local categories = {}
for _, category in ipairs(Config.Streams.Categories) do
    categories[category.id] = true
end

local function public_stream(stream)
    return {
        id = stream.id,
        title = stream.title,
        category = stream.category,
        streamer = stream.streamer,
        viewers = stream.viewerCount,
        uptime = os.time() - stream.startedAt,
        paused = stream.paused,
        thumbnailVersion = stream.thumbnailVersion,
    }
end

local function earnings(stream)
    return {
        gross = stream.gross,
        net = stream.net,
        donations = stream.donationCount,
    }
end

local function for_each_member(stream, callback)
    callback(stream.hostSource, 'host')
    for viewer in pairs(stream.viewers) do
        callback(viewer, 'viewer')
    end
end

local function push_message(stream, message)
    message_sequence = message_sequence + 1
    message.id = message_sequence
    message.time = os.time()

    local history = stream.history
    history[#history + 1] = message
    if #history > Config.Chat.HistorySize then
        table.remove(history, 1)
    end
    stream.outbox[#stream.outbox + 1] = message
end

local function remove_viewer(stream, viewer, reason)
    if not stream.viewers[viewer] then
        return
    end
    stream.viewers[viewer] = nil
    stream.viewerCount = stream.viewerCount - 1
    stream.stateDirty = true
    memberships[viewer] = nil
    TriggerClientEvent('snitch:rtc:peer-left', stream.hostSource, stream.id, viewer)
    if reason then
        TriggerClientEvent('snitch:room:left', viewer, stream.id, reason)
    end
end

local function end_stream(stream, reason)
    if stream.ended then
        return
    end
    stream.ended = true
    streams[stream.id] = nil
    stream_count = stream_count - 1

    for viewer in pairs(stream.viewers) do
        memberships[viewer] = nil
        TriggerClientEvent('snitch:room:ended', viewer, stream.id, reason)
    end
    stream.viewers = {}
    memberships[stream.hostSource] = nil

    TriggerClientEvent('snitch:host:ended', stream.hostSource, stream.id, reason, {
        duration = os.time() - stream.startedAt,
        peakViewers = stream.peakViewers,
        uniqueViewers = stream.uniqueViewerCount,
        gross = stream.gross,
        net = stream.net,
        donations = stream.donationCount,
    })

    MySQL.update(
        'UPDATE `snitch_streams` SET `ended_at` = CURRENT_TIMESTAMP, `peak_viewers` = ?, `unique_viewers` = ? WHERE `id` = ?',
        { stream.peakViewers, stream.uniqueViewerCount, stream.id }
    )
    SnitchUtil.Log('info', 'Stream %s by @%s ended (%s).', stream.id, stream.streamer.username, reason)
end

function SnitchStreams.Get(stream_id)
    return streams[stream_id]
end

function SnitchStreams.GetMembership(source)
    return memberships[source]
end

---Leaves whatever stream the player is in; ends it if they are the host.
function SnitchStreams.LeaveAll(source, reason)
    local membership = memberships[source]
    if not membership then
        return
    end
    local stream = streams[membership.streamId]
    if not stream then
        memberships[source] = nil
        return
    end
    if membership.role == 'host' then
        end_stream(stream, reason)
    else
        remove_viewer(stream, source)
    end
end

function SnitchStreams.EndForAccount(account_id, reason)
    for _, stream in pairs(streams) do
        if stream.accountId == account_id then
            end_stream(stream, reason)
        end
    end
end

---Books a donation on the live room and tells everyone in it.
function SnitchStreams.RecordDonation(stream, donor, split, message)
    stream.gross = stream.gross + split.gross
    stream.net = stream.net + split.net
    stream.donationCount = stream.donationCount + 1
    push_message(stream, {
        kind = 'donation',
        user = donor,
        amount = split.gross,
        text = message,
    })
    TriggerClientEvent('snitch:host:earnings', stream.hostSource, stream.id, earnings(stream))
end

local function require_account(source)
    local account, error_code = SnitchAccounts.GetForSource(source)
    if not account then
        return nil, SnitchUtil.Fail(error_code)
    end
    return account
end

SnitchRpc.Register('app:bootstrap', nil, function(source)
    local account, error_code = SnitchAccounts.GetForSource(source)
    if not account and error_code ~= 'not_logged_in' then
        return SnitchUtil.Fail(error_code)
    end

    local live = false
    local membership = memberships[source]
    if membership and membership.role == 'host' then
        local stream = streams[membership.streamId]
        if stream then
            live = {
                stream = public_stream(stream),
                earnings = earnings(stream),
                history = stream.history,
            }
        end
    end

    local donations = Config.Donations
    return SnitchUtil.Ok({
        loggedIn = account ~= nil,
        live = live,
        config = {
            categories = Config.Streams.Categories,
            titleMaxLength = Config.Streams.TitleMaxLength,
            chatMaxLength = Config.Chat.MaxLength,
            maxViewers = Config.Streams.MaxViewersPerStream,
            pauseTimeoutSeconds = Config.Streams.PauseTimeoutSeconds,
            donations = {
                minimum = donations.Minimum,
                maximum = donations.Maximum,
                presets = donations.Presets,
                messageMaxLength = donations.MessageMaxLength,
                feePercent = donations.PlatformFeePercent,
                taxPercent = donations.TaxPercent,
                taxBase = donations.TaxBase,
            },
            accounts = {
                usernameMinLength = Config.Accounts.UsernameMinLength,
                usernameMaxLength = Config.Accounts.UsernameMaxLength,
                passwordMinLength = Config.Accounts.PasswordMinLength,
            },
        },
    })
end)

SnitchRpc.Register('streams:list', { perMinute = 30 }, function()
    local list = {}
    for _, stream in pairs(streams) do
        list[#list + 1] = public_stream(stream)
    end
    table.sort(list, function(a, b)
        if a.viewers ~= b.viewers then
            return a.viewers > b.viewers
        end
        return a.id > b.id
    end)
    return SnitchUtil.Ok({ streams = list })
end)

SnitchRpc.Register('streams:thumbnail', { perMinute = 120, latent = true }, function(_, payload)
    local stream = type(payload) == 'table' and streams[payload.id]
    if not stream or not stream.thumbnail then
        return SnitchUtil.Fail('not_found')
    end
    return SnitchUtil.Ok({
        id = stream.id,
        version = stream.thumbnailVersion,
        image = stream.thumbnail,
    })
end)

SnitchRpc.Register('stream:start', { perMinute = 6 }, function(source, payload)
    local account, failure = require_account(source)
    if not account then
        return failure
    end
    if type(payload) ~= 'table' then
        return SnitchUtil.Fail('invalid_request')
    end
    if starting[source] then
        return SnitchUtil.Fail('busy')
    end
    local membership = memberships[source]
    if membership and membership.role == 'host' then
        return SnitchUtil.Fail('already_live')
    end
    for _, stream in pairs(streams) do
        if stream.accountId == account.id then
            return SnitchUtil.Fail('already_live_elsewhere')
        end
    end
    if stream_count >= Config.Streams.MaxLiveStreams then
        return SnitchUtil.Fail('too_many_streams')
    end

    local title = SnitchUtil.CleanText(payload.title, Config.Streams.TitleMaxLength)
    if not title then
        return SnitchUtil.Fail('invalid_title')
    end
    if not categories[payload.category] then
        return SnitchUtil.Fail('invalid_category')
    end

    starting[source] = true
    local success, stream_id = pcall(MySQL.insert.await,
        'INSERT INTO `snitch_streams` (`account_id`, `title`, `category`) VALUES (?, ?, ?)',
        { account.id, title, payload.category }
    )
    starting[source] = nil
    if not success or not stream_id then
        return SnitchUtil.Fail('server_error')
    end
    if not GetPlayerName(source) then
        -- The player left while the row was being written.
        MySQL.update('UPDATE `snitch_streams` SET `ended_at` = CURRENT_TIMESTAMP WHERE `id` = ?', { stream_id })
        return SnitchUtil.Fail('player_unavailable')
    end

    SnitchStreams.LeaveAll(source)
    local stream = {
        id = stream_id,
        accountId = account.id,
        streamer = SnitchAccounts.PublicProfile(account),
        hostSource = source,
        title = title,
        category = payload.category,
        startedAt = os.time(),
        viewers = {},
        viewerCount = 0,
        peakViewers = 0,
        uniqueViewers = {},
        uniqueViewerCount = 0,
        paused = false,
        pausedAt = 0,
        gross = 0,
        net = 0,
        donationCount = 0,
        history = {},
        outbox = {},
        stateDirty = false,
        thumbnail = nil,
        thumbnailVersion = 0,
    }
    streams[stream_id] = stream
    stream_count = stream_count + 1
    memberships[source] = { streamId = stream_id, role = 'host' }
    SnitchUtil.Log('info', 'Stream %s started by @%s.', stream_id, account.username)

    return SnitchUtil.Ok({
        stream = public_stream(stream),
        video = Config.Streams.Video,
        voiceMode = Config.Voice.Mode,
        iceServers = Config.Realtime.IceServers,
        thumbnailIntervalSeconds = Config.Streams.ThumbnailIntervalSeconds,
    })
end)

SnitchRpc.Register('stream:end', nil, function(source)
    local membership = memberships[source]
    if not membership or membership.role ~= 'host' then
        return SnitchUtil.Fail('not_live')
    end
    local stream = streams[membership.streamId]
    if stream then
        end_stream(stream, 'ended')
    end
    return SnitchUtil.Ok({})
end)

SnitchRpc.Register('stream:pause', { perMinute = 30 }, function(source, payload)
    local membership = memberships[source]
    local stream = membership and membership.role == 'host' and streams[membership.streamId]
    if not stream then
        return SnitchUtil.Fail('not_live')
    end
    local paused = type(payload) == 'table' and payload.paused == true
    if stream.paused ~= paused then
        stream.paused = paused
        stream.pausedAt = os.time()
        stream.stateDirty = true
    end
    return SnitchUtil.Ok({ paused = paused, timeoutSeconds = Config.Streams.PauseTimeoutSeconds })
end)

SnitchRpc.Register('stream:join', { perMinute = 20 }, function(source, payload)
    local account, failure = require_account(source)
    if not account then
        return failure
    end
    local stream = type(payload) == 'table' and streams[payload.streamId]
    if not stream then
        return SnitchUtil.Fail('stream_not_found')
    end
    if stream.accountId == account.id or stream.hostSource == source then
        return SnitchUtil.Fail('own_stream')
    end

    local membership = memberships[source]
    if membership and membership.role == 'host' then
        return SnitchUtil.Fail('you_are_live')
    end
    if not (membership and membership.streamId == stream.id) then
        if stream.viewerCount >= Config.Streams.MaxViewersPerStream then
            return SnitchUtil.Fail('stream_full')
        end
        SnitchStreams.LeaveAll(source)
        stream.viewers[source] = account.id
        stream.viewerCount = stream.viewerCount + 1
        stream.peakViewers = math.max(stream.peakViewers, stream.viewerCount)
        if not stream.uniqueViewers[account.id] then
            stream.uniqueViewers[account.id] = true
            stream.uniqueViewerCount = stream.uniqueViewerCount + 1
        end
        stream.stateDirty = true
        memberships[source] = { streamId = stream.id, role = 'viewer' }
    end

    return SnitchUtil.Ok({
        stream = public_stream(stream),
        history = stream.history,
        iceServers = Config.Realtime.IceServers,
    })
end)

SnitchRpc.Register('stream:leave', nil, function(source)
    local membership = memberships[source]
    if membership and membership.role == 'viewer' then
        SnitchStreams.LeaveAll(source)
    end
    return SnitchUtil.Ok({})
end)

SnitchRpc.Register('chat:send', nil, function(source, payload)
    local membership = memberships[source]
    local stream = membership and type(payload) == 'table'
        and membership.streamId == payload.streamId
        and streams[membership.streamId]
    if not stream then
        return SnitchUtil.Fail('not_in_stream')
    end
    local account, failure = require_account(source)
    if not account then
        return failure
    end
    local text, text_error = SnitchUtil.CleanText(payload.text, Config.Chat.MaxLength)
    if not text then
        return SnitchUtil.Fail(text_error)
    end
    if not chat_limiter.Allow(source) then
        return SnitchUtil.Fail('rate_limited')
    end

    local user = SnitchAccounts.PublicProfile(account)
    user.role = membership.role
    push_message(stream, { kind = 'chat', user = user, text = text })
    return SnitchUtil.Ok({})
end)

local function sanitize_signal(payload)
    if type(payload) ~= 'table' then
        return nil
    end
    if payload.kind == 'offer' or payload.kind == 'answer' then
        if type(payload.sdp) ~= 'string' or #payload.sdp > SDP_MAX_BYTES then
            return nil
        end
        return { kind = payload.kind, sdp = payload.sdp }
    end
    if payload.kind == 'candidate' then
        local candidate = payload.candidate
        if type(candidate) ~= 'table' or type(candidate.candidate) ~= 'string' or #candidate.candidate > 1024 then
            return nil
        end
        return {
            kind = 'candidate',
            candidate = {
                candidate = candidate.candidate,
                sdpMid = type(candidate.sdpMid) == 'string' and candidate.sdpMid:sub(1, 64) or nil,
                sdpMLineIndex = SnitchUtil.IsInteger(candidate.sdpMLineIndex) and candidate.sdpMLineIndex or nil,
            },
        }
    end
    return nil
end

RegisterNetEvent('snitch:rtc:signal', function(stream_id, target, payload)
    local source = source
    if not signal_limiter.Allow(source) then
        return
    end
    local membership = memberships[source]
    local stream = membership and membership.streamId == stream_id and streams[stream_id]
    if not stream then
        return
    end
    local signal = sanitize_signal(payload)
    if not signal then
        return
    end

    if membership.role == 'host' then
        -- Ids that passed through JSON can arrive as floats (3.0); player ids must be integers.
        local viewer = math.tointeger(target)
        if viewer and stream.viewers[viewer] then
            TriggerClientEvent('snitch:rtc:signal', viewer, stream.id, source, signal)
        end
    else
        TriggerClientEvent('snitch:rtc:signal', stream.hostSource, stream.id, source, signal)
    end
end)

RegisterNetEvent('snitch:stream:thumbnail', function(image)
    local source = source
    local membership = memberships[source]
    local stream = membership and membership.role == 'host' and streams[membership.streamId]
    if not stream or not thumbnail_limiter.Allow(source) then
        return
    end
    if type(image) ~= 'string' or #image > THUMBNAIL_MAX_BYTES
        or image:sub(1, #THUMBNAIL_PREFIX) ~= THUMBNAIL_PREFIX
        or image:find('[^%w%+/=]', #THUMBNAIL_PREFIX + 1)
    then
        return
    end
    stream.thumbnail = image
    stream.thumbnailVersion = stream.thumbnailVersion + 1
end)

-- Chat goes out in small batches; room state (viewers, pause) every two seconds.
CreateThread(function()
    local last_state_update = 0
    while true do
        if stream_count == 0 then
            Wait(1000)
        else
            Wait(Config.Chat.FlushIntervalMs)
            for _, stream in pairs(streams) do
                if #stream.outbox > 0 then
                    local batch = stream.outbox
                    stream.outbox = {}
                    for_each_member(stream, function(member)
                        TriggerClientEvent('snitch:room:chat', member, stream.id, batch)
                    end)
                end
            end

            local now = GetGameTimer()
            if now - last_state_update >= 2000 then
                last_state_update = now
                local seconds = os.time()
                for _, stream in pairs(streams) do
                    if stream.paused and seconds - stream.pausedAt >= Config.Streams.PauseTimeoutSeconds then
                        end_stream(stream, 'pause_timeout')
                    elseif stream.stateDirty then
                        stream.stateDirty = false
                        local state = {
                            viewers = stream.viewerCount,
                            paused = stream.paused,
                        }
                        for_each_member(stream, function(member)
                            TriggerClientEvent('snitch:room:state', member, stream.id, state)
                        end)
                    end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local source = source
    SnitchStreams.LeaveAll(source, 'host_left')
    starting[source] = nil
    chat_limiter.Clear(source)
    signal_limiter.Clear(source)
end)

AddEventHandler('onResourceStop', function(resource_name)
    if resource_name ~= GetCurrentResourceName() then
        return
    end
    for _, stream in pairs(streams) do
        end_stream(stream, 'server_restart')
    end
end)
