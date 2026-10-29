SnitchRpc = {}

local pending = {}
local sequence = 0

---Sends a request to the server and waits for its answer.
---@return { ok: boolean, data?: any, error?: string }
function SnitchRpc.Call(name, payload, timeout_ms)
    sequence = sequence + 1
    local request_id = sequence
    local result = promise.new()
    pending[request_id] = result

    TriggerServerEvent('snitch:rpc:request', request_id, name, payload)
    SetTimeout(timeout_ms or 15000, function()
        local waiting = pending[request_id]
        if waiting then
            pending[request_id] = nil
            waiting:resolve({ ok = false, error = 'timeout' })
        end
    end)
    return Citizen.Await(result)
end

RegisterNetEvent('snitch:rpc:response', function(request_id, response)
    local waiting = pending[request_id]
    if not waiting then
        return
    end
    pending[request_id] = nil
    waiting:resolve(type(response) == 'table' and response or { ok = false, error = 'invalid_response' })
end)
