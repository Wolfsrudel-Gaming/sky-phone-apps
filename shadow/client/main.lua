-- Shadow only exists on phones that were unlocked at a hidden spot. The app is
-- registered with Sky Phone while the phone in use has it, and removed otherwise.

local APP_ID = Config.App.Id
local STATUS_INTERVAL_MS = 20000

local TEXTS = {
    de = {
        hint = '~INPUT_CONTEXT~ Verbindung aufbauen',
        installing = 'Verbindung wird aufgebaut … %s',
        installed = 'Etwas Neues ist auf deinem Handy.',
        failed = 'Verbindung abgebrochen.',
        no_phone = 'Du brauchst ein Handy.',
    },
    en = {
        hint = '~INPUT_CONTEXT~ Connect',
        installing = 'Connecting … %s',
        installed = 'Something new is on your phone.',
        failed = 'Connection lost.',
        no_phone = 'You need a phone.',
    },
}

local function text(key, ...)
    return ((TEXTS[Config.Locale] or TEXTS.en)[key]):format(...)
end

local registered = false

local function definition()
    return {
        id = APP_ID,
        name = Config.App.Name,
        description = {
            de = 'Kein Name. Keine Spuren.',
            en = 'No names. No traces.',
        },
        developer = '???',
        category = 'utilities',
        ui = 'web/app.html',
        icon = 'web/icon.svg',
        iconBackground = '#050505',
        bridgeMode = 'sky',
        permissions = { 'locale.read', 'theme.read' },
        orientation = 'portrait',
        defaultInstalled = true,
        removable = false,
        onClose = function()
            exports.sky_phone:SetPhoneGameInputEnabled(nil)
            CreateThread(function()
                ShadowRpc.Call('lock')
            end)
        end,
    }
end

local function set_registered(installed)
    if GetResourceState('sky_phone') ~= 'started' then
        registered = false
        return
    end
    if installed and not registered then
        local success, error_code = exports.sky_phone:AddCustomApp(definition())
        if not success and error_code == 'duplicate_app_id' then
            success, error_code = exports.sky_phone:UpdateCustomApp(definition())
        end
        registered = success == true
        if not registered then
            print(('[shadow] Could not register with Sky Phone: %s'):format(tostring(error_code)))
        end
    elseif not installed and registered then
        exports.sky_phone:RemoveCustomApp(APP_ID)
        registered = false
    end
end

local function refresh()
    local response = ShadowRpc.Call('status')
    if response.ok then
        set_registered(response.data.installed == true)
    end
end

AddEventHandler('sky_phone:client:apiReady', function()
    registered = false
    CreateThread(refresh)
end)

-- Phones change hands; check which phone is in use now and then.
CreateThread(function()
    while GetResourceState('sky_phone') == 'starting' do
        Wait(500)
    end
    while true do
        refresh()
        Wait(STATUS_INTERVAL_MS)
    end
end)

local function help(message)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function notify(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function nearest_point(position)
    local best, best_distance = nil, math.huge
    for _, point in ipairs(Config.UnlockPoints) do
        local distance = #(position - point.coords)
        if distance < best_distance then
            best, best_distance = point, distance
        end
    end
    return best, best_distance
end

local function install(point)
    local ped = PlayerPedId()
    local deadline = GetGameTimer() + Config.UnlockSeconds * 1000
    while GetGameTimer() < deadline do
        if IsEntityDead(ped) or #(GetEntityCoords(ped) - point.coords) > point.radius + 0.5 then
            notify(text('failed'))
            return
        end
        help(text('installing', math.ceil((deadline - GetGameTimer()) / 1000)))
        Wait(0)
    end
    local response = ShadowRpc.Call('install')
    if not response.ok then
        notify(text(response.error == 'no_phone' and 'no_phone' or 'failed'))
        return
    end
    set_registered(true)
    notify(text('installed'))
end

-- Hidden spots: no marker, no blip. The loop sleeps unless a spot is close.
CreateThread(function()
    while true do
        local position = GetEntityCoords(PlayerPedId())
        local point, distance = nearest_point(position)
        if not point or distance > 30.0 then
            Wait(math.min(5000, 500 + math.floor(distance * 10)))
        elseif distance > point.radius then
            Wait(250)
        else
            help(text('hint'))
            if IsControlJustPressed(0, 38) then
                install(point)
                Wait(1000)
            end
            Wait(0)
        end
    end
end)

local SERVER_REQUESTS = {
    ['status'] = true,
    ['pin:verify'] = true,
    ['pin:set'] = true,
    ['alias:set'] = true,
    ['channels:list'] = true,
    ['channel:read'] = true,
    ['channel:post'] = true,
    ['thread:open'] = true,
    ['threads:list'] = true,
    ['thread:read'] = true,
    ['thread:send'] = true,
    ['extract:start'] = true,
    ['extract:finish'] = true,
    ['lock'] = true,
}

RegisterNUICallback('rpc', function(data, cb)
    if type(data) ~= 'table' or not SERVER_REQUESTS[data.name] then
        cb({ ok = false, error = 'unknown_request' })
        return
    end
    local response = ShadowRpc.Call(data.name, data.payload)
    if data.name == 'pin:verify' and response.error == 'wiped' then
        set_registered(false)
    end
    cb(response)
end)

RegisterNUICallback('input:typing', function(data, cb)
    if type(data) == 'table' and data.typing == true then
        exports.sky_phone:SetPhoneGameInputEnabled(false)
    else
        exports.sky_phone:SetPhoneGameInputEnabled(nil)
    end
    cb({ ok = true })
end)
