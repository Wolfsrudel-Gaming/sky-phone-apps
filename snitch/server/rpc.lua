SnitchRpc = {}

local handlers = {}
local global_limiter = SnitchUtil.NewLimiter(240, 60)

---Registers a request handler. The handler receives (source, payload) and
---returns SnitchUtil.Ok(...) or SnitchUtil.Fail(...).
---@param name string
---@param options { perMinute?: integer, latent?: boolean }|nil
---@param handler fun(source: integer, payload: any): table
function SnitchRpc.Register(name, options, handler)
    options = options or {}
    handlers[name] = {
        handler = handler,
        latent = options.latent == true,
        limiter = options.perMinute and SnitchUtil.NewLimiter(options.perMinute, 60) or nil,
    }
end

local function respond(source, request_id, result, latent)
    if latent then
        TriggerLatentClientEvent('snitch:rpc:response', source, 50000, request_id, result)
    else
        TriggerClientEvent('snitch:rpc:response', source, request_id, result)
    end
end

RegisterNetEvent('snitch:rpc:request', function(request_id, name, payload)
    local source = source
    if not SnitchUtil.IsInteger(request_id) or type(name) ~= 'string' then
        return
    end

    local entry = handlers[name]
    if not entry then
        respond(source, request_id, SnitchUtil.Fail('unknown_request'))
        return
    end
    if not global_limiter.Allow(source) or (entry.limiter and not entry.limiter.Allow(source)) then
        respond(source, request_id, SnitchUtil.Fail('rate_limited'))
        return
    end
    if not SnitchDatabase.Ready then
        respond(source, request_id, SnitchUtil.Fail('not_ready'))
        return
    end

    local success, result = pcall(entry.handler, source, payload)
    if not success then
        SnitchUtil.Log('error', 'Request %s from %s failed: %s', name, source, tostring(result))
        result = SnitchUtil.Fail('server_error')
    elseif type(result) ~= 'table' then
        result = SnitchUtil.Fail('server_error')
    end
    respond(source, request_id, result, entry.latent)
end)

AddEventHandler('playerDropped', function()
    global_limiter.Clear(source)
end)
