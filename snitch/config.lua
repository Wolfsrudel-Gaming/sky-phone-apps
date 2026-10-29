Config = {}

-- Clients download this file. Never put passwords, API keys or tokens here.

Config.Debug = false

-- Language of phone notifications sent by Snitch ('de' or 'en').
-- The app itself follows the phone's language setting.
Config.Locale = 'de'

Config.App = {
    Id = 'snitch', -- Sky Phone app id; keep it unless it collides with another app
    Name = 'Snitch',
    DefaultInstalled = false, -- false: players install Snitch from the Sky Phone App Store
    Removable = true,
}

Config.Accounts = {
    UsernameMinLength = 3,
    UsernameMaxLength = 20,
    PasswordMinLength = 8,
    PasswordMaxLength = 72,
    MaxAccountsPerCharacter = 3,
    LoginAttemptsPerMinute = 8,
}

Config.Streams = {
    MaxLiveStreams = 25,
    -- Peer-to-peer: the streamer uploads one copy per viewer, so upload and CPU
    -- grow with every viewer. Raise this only for streamers with fast uploads.
    MaxViewersPerStream = 5,
    TitleMaxLength = 80,
    -- The phone camera stops when the streamer closes the phone. The stream then
    -- shows a "be right back" screen and ends after this many seconds.
    PauseTimeoutSeconds = 180,
    ThumbnailIntervalSeconds = 60,
    Video = {
        Width = 960,
        Height = 540,
        Fps = 30,
        MaxBitrateKbps = 1500,
    },
    Categories = {
        { id = 'just_chatting', label = { de = 'Just Chatting', en = 'Just Chatting' } },
        { id = 'driving', label = { de = 'Autos & Fahren', en = 'Cars & Driving' } },
        { id = 'events', label = { de = 'Events', en = 'Events' } },
        { id = 'news', label = { de = 'News', en = 'News' } },
        { id = 'music', label = { de = 'Musik', en = 'Music' } },
        { id = 'business', label = { de = 'Business', en = 'Business' } },
        { id = 'irl', label = { de = 'IRL', en = 'IRL' } },
    },
}

Config.Chat = {
    MaxLength = 200,
    MessagesPerMinute = 20,
    HistorySize = 50, -- messages a new viewer sees when joining
    FlushIntervalMs = 250, -- chat is sent in small batches instead of one event per message
}

Config.Voice = {
    -- 'talking': the microphone is only sent while the player talks in game
    --            (works with pma-voice / Mumble). Keeps out-of-character talk out.
    -- 'always':  the microphone is always sent while live.
    -- 'off':     streams carry no audio.
    Mode = 'talking',
}

Config.Donations = {
    Minimum = 10,
    Maximum = 50000,
    CooldownSeconds = 5,
    MessageMaxLength = 120,
    Presets = { 50, 100, 500, 1000, 5000 },

    PlatformFeePercent = 50,
    TaxPercent = 15,
    -- 'afterFee': the tax is taken from the streamer's share (donation minus fee).
    -- 'gross':    the tax is taken from the full donation.
    TaxBase = 'afterFee',

    -- okokBanking society accounts. false = the money leaves the economy.
    PlatformAccount = false,
    StateAccount = 'government',

    -- Write entries into the okokBanking transaction history (okokBanking V2).
    BankTransactions = true,
}

Config.Realtime = {
    -- Public STUN server for peer-to-peer connections. No account required.
    IceServers = {
        { urls = { 'stun:stun.l.google.com:19302' } },
    },
}
