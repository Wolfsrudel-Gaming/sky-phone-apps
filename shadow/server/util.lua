ShadowUtil = {}

local RESOURCE = GetCurrentResourceName()

function ShadowUtil.Log(level, message, ...)
    if level == 'debug' and not Config.Debug then
        return
    end
    print(('[%s] [%s] %s'):format(RESOURCE, level, message:format(...)))
end

---Fixed-window rate limiter keyed by any value (usually the player source).
function ShadowUtil.NewLimiter(limit, window_seconds)
    local buckets = {}
    local limiter = {}

    function limiter.Allow(key)
        local now = os.time()
        local bucket = buckets[key]
        if not bucket or now - bucket.start >= window_seconds then
            bucket = { start = now, count = 0 }
            buckets[key] = bucket
        end
        if bucket.count >= limit then
            return false
        end
        bucket.count = bucket.count + 1
        return true
    end

    function limiter.Clear(key)
        buckets[key] = nil
    end

    return limiter
end

---Normalizes user text: valid UTF-8, no control characters, trimmed, length-limited.
---@return string|nil text, string|nil error_code
function ShadowUtil.CleanText(value, max_length, allow_empty)
    if type(value) ~= 'string' then
        return nil, 'invalid_text'
    end
    if not utf8.len(value) then
        return nil, 'invalid_text'
    end
    local text = value:gsub('%c', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    local length = utf8.len(text)
    if length == 0 and not allow_empty then
        return nil, 'empty_text'
    end
    if length > max_length then
        return nil, 'text_too_long'
    end
    return text
end

function ShadowUtil.IsInteger(value)
    return math.type(value) == 'integer'
        or (type(value) == 'number' and value == math.floor(value) and value == value)
end

---Calls a JavaScript export of this resource that reports its result through a callback.
function ShadowUtil.AwaitJs(export_name, timeout_ms, ...)
    local result = promise.new()
    local settled = false
    local args = { ... }
    args[#args + 1] = function(value)
        if settled then return end
        settled = true
        result:resolve(value)
    end
    SetTimeout(timeout_ms, function()
        if settled then return end
        settled = true
        result:resolve(nil)
    end)
    exports[RESOURCE][export_name](exports[RESOURCE], table.unpack(args))
    return Citizen.Await(result)
end

function ShadowUtil.Ok(data)
    return { ok = true, data = data }
end

function ShadowUtil.Fail(error_code)
    return { ok = false, error = error_code }
end
