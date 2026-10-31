ShadowRpc = {}

local handlers = {}
local global_limiter = ShadowUtil.NewLimiter(240, 60)

---Registers a request handler. The handler receives (source, payload) and
---returns ShadowUtil.Ok(...) or ShadowUtil.Fail(...).
---@param name string
---@param options { perMinute?: integer, latent?: boolean }|nil
---@param handler fun(source: integer, payload: any): table
function ShadowRpc.Register(name, options, handler)
    options = options or {}
    handlers[name] = {
        handler = handler,
        latent = options.latent == true,
        limiter = options.perMinute and ShadowUtil.NewLimiter(options.perMinute, 60) or nil,
    }
end

local function respond(source, request_id, result, latent)
    if latent then
        TriggerLatentClientEvent('shadow:rpc:response', source, 50000, request_id, result)
    else
        TriggerClientEvent('shadow:rpc:response', source, request_id, result)
    end
end

RegisterNetEvent('shadow:rpc:request', function(request_id, name, payload)
    local source = source
    if not ShadowUtil.IsInteger(request_id) or type(name) ~= 'string' then
        return
    end

    local entry = handlers[name]
    if not entry then
        respond(source, request_id, ShadowUtil.Fail('unknown_request'))
        return
    end
    if not global_limiter.Allow(source) or (entry.limiter and not entry.limiter.Allow(source)) then
        respond(source, request_id, ShadowUtil.Fail('rate_limited'))
        return
    end
    if not ShadowDatabase.Ready then
        respond(source, request_id, ShadowUtil.Fail('not_ready'))
        return
    end

    local success, result = pcall(entry.handler, source, payload)
    if not success then
        ShadowUtil.Log('error', 'Request %s from %s failed: %s', name, source, tostring(result))
        result = ShadowUtil.Fail('server_error')
    elseif type(result) ~= 'table' then
        result = ShadowUtil.Fail('server_error')
    end
    respond(source, request_id, result, entry.latent)
end)

AddEventHandler('playerDropped', function()
    global_limiter.Clear(source)
end)
