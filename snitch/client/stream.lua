-- Streaming state on this client: hosting (camera, engine page) and watching.

SnitchStream = {}

local live = nil
local watching = nil
local starting = false
local engine_requests = {}
local engine_sequence = 0

local function fail(error_code)
    return { ok = false, error = error_code }
end

local function engine(message)
    SendNUIMessage(message)
end

---Sends a command to the engine page and waits for its reply.
local function request_engine(message, timeout_ms)
    engine_sequence = engine_sequence + 1
    local request_id = engine_sequence
    local result = promise.new()
    engine_requests[request_id] = result
    message.requestId = request_id
    engine(message)
    SetTimeout(timeout_ms or 15000, function()
        local waiting = engine_requests[request_id]
        if waiting then
            engine_requests[request_id] = nil
            waiting:resolve(fail('engine_timeout'))
        end
    end)
    return Citizen.Await(result)
end

function SnitchStream.ResolveEngineRequest(request_id, response)
    local waiting = engine_requests[request_id]
    if waiting then
        engine_requests[request_id] = nil
        waiting:resolve(response)
    end
end

local function start_voice_gate()
    local mode = live.voiceMode
    if mode ~= 'talking' then
        engine({ type = 'talking', talking = mode == 'always' })
        return
    end
    local stream_id = live.streamId
    CreateThread(function()
        local talking = nil
        while live and live.streamId == stream_id do
            local now_talking = NetworkIsPlayerTalking(PlayerId()) and true or false
            if now_talking ~= talking then
                talking = now_talking
                engine({ type = 'talking', talking = talking })
            end
            Wait(100)
        end
    end)
end

local function release_live(stream_id)
    if not live or live.streamId ~= stream_id then
        return false
    end
    live = nil
    engine({ type = 'stop' })
    exports.sky_phone:ReleaseCamera()
    return true
end

local function public_state()
    if not live then
        return false
    end
    return {
        streamId = live.streamId,
        paused = live.paused,
        muted = live.muted,
        front = live.front,
        audio = live.audio,
    }
end

local function set_paused(paused)
    live.paused = paused
    engine({ type = paused and 'pause' or 'resume' })
    SnitchRpc.Call('stream:pause', { paused = paused })
    SnitchPhone.Send({ type = 'live:state', state = public_state() })
end

function SnitchStream.GetState()
    return { live = public_state(), watching = watching or false }
end

function SnitchStream.Start(data)
    if live then
        return fail('already_live')
    end
    if starting then
        return fail('busy')
    end
    if type(data) ~= 'table' then
        return fail('invalid_request')
    end
    starting = true
    if watching then
        SnitchStream.Leave()
    end

    local front = data.front == true
    local camera_ok, camera_error = exports.sky_phone:EnableWalkableCamera(front)
    if not camera_ok then
        starting = false
        return fail(camera_error or 'camera_unavailable')
    end

    local response = SnitchRpc.Call('stream:start', { title = data.title, category = data.category })
    if not response.ok then
        exports.sky_phone:ReleaseCamera()
        starting = false
        return response
    end

    local info = response.data
    live = {
        streamId = info.stream.id,
        front = front,
        paused = false,
        muted = false,
        audio = false,
        voiceMode = info.voiceMode,
    }

    local engine_result = request_engine({
        type = 'start',
        streamId = info.stream.id,
        video = info.video,
        iceServers = info.iceServers,
        audio = info.voiceMode ~= 'off',
        thumbnailIntervalSeconds = info.thumbnailIntervalSeconds,
    })
    if not engine_result.ok then
        local stream_id = info.stream.id
        release_live(stream_id)
        SnitchRpc.Call('stream:end')
        starting = false
        return fail(engine_result.error or 'engine_failed')
    end

    live.audio = engine_result.audio == true
    start_voice_gate()
    starting = false

    -- The phone may have been closed while the stream was starting.
    local camera = exports.sky_phone:GetCameraState()
    if not (camera and camera.active) then
        set_paused(true)
    end
    return {
        ok = true,
        data = {
            stream = info.stream,
            state = public_state(),
            earnings = { gross = 0, net = 0, donations = 0 },
        },
    }
end

function SnitchStream.End()
    if not live then
        return { ok = true }
    end
    release_live(live.streamId)
    return SnitchRpc.Call('stream:end')
end

function SnitchStream.Resume()
    if not live then
        return fail('not_live')
    end
    if not live.paused then
        return { ok = true, data = public_state() }
    end
    local camera_ok, camera_error = exports.sky_phone:EnableWalkableCamera(live.front)
    if not camera_ok then
        return fail(camera_error or 'camera_unavailable')
    end
    set_paused(false)
    return { ok = true, data = public_state() }
end

function SnitchStream.SetFront(front)
    if not live then
        return fail('not_live')
    end
    front = front == true
    if not live.paused then
        local success, error_code = exports.sky_phone:SetSelfieCamera(front)
        if not success then
            return fail(error_code or 'camera_unavailable')
        end
    end
    live.front = front
    return { ok = true, data = public_state() }
end

function SnitchStream.SetMuted(muted)
    if not live then
        return fail('not_live')
    end
    live.muted = muted == true
    engine({ type = 'mute', muted = live.muted })
    return { ok = true, data = public_state() }
end

function SnitchStream.SendHostSignal(target, signal)
    local viewer = math.tointeger(tonumber(target))
    if live and viewer then
        TriggerServerEvent('snitch:rtc:signal', live.streamId, viewer, signal)
    end
end

function SnitchStream.SendThumbnail(image)
    if live and not live.paused then
        TriggerLatentServerEvent('snitch:stream:thumbnail', 25000, image)
    end
end

function SnitchStream.Join(stream_id)
    if live then
        return fail('you_are_live')
    end
    local response = SnitchRpc.Call('stream:join', { streamId = stream_id })
    if response.ok then
        watching = stream_id
    end
    return response
end

function SnitchStream.Leave()
    if not watching then
        return { ok = true }
    end
    watching = nil
    return SnitchRpc.Call('stream:leave')
end

function SnitchStream.SendViewerSignal(stream_id, signal)
    if watching and watching == stream_id then
        TriggerServerEvent('snitch:rtc:signal', stream_id, nil, signal)
    end
end

function SnitchStream.OnAppClosed()
    if watching then
        CreateThread(SnitchStream.Leave)
    end
end

-- Closing the phone turns its camera off. The stream must not show the
-- player from behind, so it pauses until the camera is back.
AddEventHandler('sky_phone:client:cameraActiveChanged', function(active)
    if live and not active and not live.paused then
        set_paused(true)
        if not SnitchPhone.Open then
            SnitchPhone.Notify(SnitchPhone.Text('stream_paused'))
        end
    end
end)

RegisterNetEvent('snitch:rtc:signal', function(stream_id, from, signal)
    if live and live.streamId == stream_id then
        engine({ type = 'signal', from = from, signal = signal })
    elseif watching == stream_id then
        SnitchPhone.Send({ type = 'rtc:signal', streamId = stream_id, signal = signal })
    end
end)

RegisterNetEvent('snitch:rtc:peer-left', function(stream_id, viewer)
    if live and live.streamId == stream_id then
        engine({ type = 'peer-left', viewer = viewer })
    end
end)

RegisterNetEvent('snitch:room:chat', function(stream_id, messages)
    SnitchPhone.Send({ type = 'chat', streamId = stream_id, messages = messages })
    if live and live.streamId == stream_id and not SnitchPhone.Open then
        for index = 1, #messages do
            local message = messages[index]
            if message.kind == 'donation' then
                SnitchPhone.Notify(SnitchPhone.Text('donation', message.user.username, message.amount))
            end
        end
    end
end)

RegisterNetEvent('snitch:room:state', function(stream_id, state)
    SnitchPhone.Send({ type = 'room:state', streamId = stream_id, state = state })
end)

local function viewer_removed(stream_id, reason)
    if watching == stream_id then
        watching = nil
    end
    SnitchPhone.Send({ type = 'room:ended', streamId = stream_id, reason = reason })
end

RegisterNetEvent('snitch:room:ended', viewer_removed)
RegisterNetEvent('snitch:room:left', viewer_removed)

RegisterNetEvent('snitch:host:earnings', function(stream_id, earnings)
    SnitchPhone.Send({ type = 'live:earnings', streamId = stream_id, earnings = earnings })
end)

RegisterNetEvent('snitch:host:ended', function(stream_id, reason, summary)
    release_live(stream_id)
    if not SnitchPhone.Send({ type = 'live:ended', streamId = stream_id, reason = reason, summary = summary }) then
        SnitchPhone.Notify(SnitchPhone.Text('stream_ended'))
    end
end)

AddEventHandler('onResourceStop', function(resource_name)
    if resource_name == GetCurrentResourceName() and live then
        exports.sky_phone:ReleaseCamera()
    end
end)
