-- Registers Snitch with Sky Phone and talks to the app inside the phone.

SnitchPhone = { Open = false }

local APP_ID = Config.App.Id

local TEXTS = {
    de = {
        stream_ended = 'Dein Stream wurde beendet.',
        stream_paused = 'Kamera aus - dein Stream ist pausiert.',
        donation = '@%s hat %s $ gespendet',
    },
    en = {
        stream_ended = 'Your stream has ended.',
        stream_paused = 'Camera off - your stream is paused.',
        donation = '@%s donated $%s',
    },
}

function SnitchPhone.Text(key, ...)
    local texts = TEXTS[Config.Locale] or TEXTS.en
    return texts[key]:format(...)
end

local function definition()
    return {
        id = APP_ID,
        name = Config.App.Name,
        description = {
            de = 'Livestreams aus der Stadt: zuschauen, mitchatten und Streamer mit Spenden unterstuetzen.',
            en = 'Livestreams from the city: watch, chat and support streamers with donations.',
        },
        developer = 'Wolfsrudel Gaming',
        category = 'social',
        ui = 'web/app.html',
        icon = 'web/icon.svg',
        iconBackground = '#141218',
        bridgeMode = 'sky',
        permissions = { 'locale.read', 'notifications', 'theme.read' },
        orientation = 'portrait',
        defaultInstalled = Config.App.DefaultInstalled,
        removable = Config.App.Removable,
        onOpen = function()
            SnitchPhone.Open = true
        end,
        onClose = function()
            SnitchPhone.Open = false
            SnitchPhone.SetTyping(false)
            SnitchStream.OnAppClosed()
        end,
    }
end

local function register()
    if GetResourceState('sky_phone') ~= 'started' then
        return
    end
    local success, error_code = exports.sky_phone:AddCustomApp(definition())
    if not success and error_code == 'duplicate_app_id' then
        success, error_code = exports.sky_phone:UpdateCustomApp(definition())
    end
    if not success then
        print(('[snitch] Could not register with Sky Phone: %s'):format(tostring(error_code)))
    end
end

-- Sky Phone forgets custom apps when it restarts; register again when it is back.
AddEventHandler('sky_phone:client:apiReady', register)

CreateThread(function()
    while GetResourceState('sky_phone') == 'starting' do
        Wait(250)
    end
    register()
end)

---Pushes a message to the open app. Fails quietly while the app is closed.
function SnitchPhone.Send(message)
    if not SnitchPhone.Open then
        return false
    end
    return exports.sky_phone:SendCustomAppMessage(APP_ID, message) == true
end

function SnitchPhone.Notify(text)
    exports.sky_phone:SendCustomAppNotification(APP_ID, {
        title = Config.App.Name,
        text = text,
    })
end

---While typing, game input is blocked; afterwards Sky Phone's own setting applies again.
function SnitchPhone.SetTyping(typing)
    if typing then
        exports.sky_phone:SetPhoneGameInputEnabled(false)
    else
        exports.sky_phone:SetPhoneGameInputEnabled(nil)
    end
end
