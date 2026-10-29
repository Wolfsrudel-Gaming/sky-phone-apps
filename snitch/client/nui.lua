-- NUI callbacks for the app inside Sky Phone and for the hidden engine page.
-- Every callback answers on every path.

local SERVER_REQUESTS = {
    ['app:bootstrap'] = true,
    ['auth:status'] = true,
    ['auth:register'] = true,
    ['auth:login'] = true,
    ['auth:logout'] = true,
    ['profile:update'] = true,
    ['streams:list'] = true,
    ['streams:thumbnail'] = true,
    ['chat:send'] = true,
    ['donate'] = true,
    ['earnings:summary'] = true,
}

local function payload_of(data)
    return type(data) == 'table' and data or {}
end

RegisterNUICallback('rpc', function(data, cb)
    data = payload_of(data)
    if not SERVER_REQUESTS[data.name] then
        cb({ ok = false, error = 'unknown_request' })
        return
    end
    cb(SnitchRpc.Call(data.name, data.payload))
end)

RegisterNUICallback('state', function(_, cb)
    cb({ ok = true, data = SnitchStream.GetState() })
end)

RegisterNUICallback('live:start', function(data, cb)
    cb(SnitchStream.Start(payload_of(data)))
end)

RegisterNUICallback('live:end', function(_, cb)
    cb(SnitchStream.End())
end)

RegisterNUICallback('live:resume', function(_, cb)
    cb(SnitchStream.Resume())
end)

RegisterNUICallback('live:camera', function(data, cb)
    cb(SnitchStream.SetFront(payload_of(data).front))
end)

RegisterNUICallback('live:mute', function(data, cb)
    cb(SnitchStream.SetMuted(payload_of(data).muted))
end)

RegisterNUICallback('watch:join', function(data, cb)
    cb(SnitchStream.Join(payload_of(data).streamId))
end)

RegisterNUICallback('watch:leave', function(_, cb)
    cb(SnitchStream.Leave())
end)

RegisterNUICallback('watch:signal', function(data, cb)
    data = payload_of(data)
    SnitchStream.SendViewerSignal(data.streamId, data.signal)
    cb({ ok = true })
end)

RegisterNUICallback('input:typing', function(data, cb)
    SnitchPhone.SetTyping(payload_of(data).typing == true)
    cb({ ok = true })
end)

-- Engine page

RegisterNUICallback('engine:reply', function(data, cb)
    data = payload_of(data)
    SnitchStream.ResolveEngineRequest(data.requestId, {
        ok = data.ok == true,
        error = data.error,
        audio = data.audio,
    })
    cb({ ok = true })
end)

RegisterNUICallback('engine:signal', function(data, cb)
    data = payload_of(data)
    SnitchStream.SendHostSignal(data.to, data.signal)
    cb({ ok = true })
end)

RegisterNUICallback('engine:thumbnail', function(data, cb)
    local image = payload_of(data).image
    if type(image) == 'string' then
        SnitchStream.SendThumbnail(image)
    end
    cb({ ok = true })
end)

RegisterNUICallback('engine:viewers', function(data, cb)
    SnitchPhone.Send({ type = 'live:connections', connected = payload_of(data).connected })
    cb({ ok = true })
end)
