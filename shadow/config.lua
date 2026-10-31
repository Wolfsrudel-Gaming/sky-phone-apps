Config = {}

-- Clients download this file. The unlock spots are therefore readable by anyone
-- who digs through the client files; keep that in mind on public servers.

Config.Debug = false
Config.Locale = 'de' -- notifications and help texts ('de' or 'en')

Config.App = {
    Id = 'shadow',
    Name = 'Shadow',
    -- Illegal app: it only appears on a phone after that phone was unlocked at a
    -- hidden spot. Police can find it on seized phones.
    Illegal = true,
}

-- Hidden spots where a phone gets the app. No marker, no blip: players have to
-- hear about them in roleplay. Standing within Radius shows a help text.
Config.UnlockPoints = {
    { coords = vector3(1272.33, -1711.95, 54.77), radius = 1.5 }, -- garage roof, El Burro Heights
    { coords = vector3(-1153.52, -1517.36, 4.36), radius = 1.5 }, -- Vespucci canals
    { coords = vector3(1985.72, 3053.31, 47.21), radius = 1.5 },  -- Yellow Jack, Sandy Shores
}
Config.UnlockSeconds = 8 -- how long the player has to hold position while "installing"

Config.Security = {
    PinLength = 4,                -- 4 to 6 digits
    MaxAttempts = 5,
    LockMinutes = 10,             -- lock after MaxAttempts wrong PINs
    WipeAfterLocks = 3,           -- 3rd lock in a row wipes the app from the phone; 0 = never
}

Config.Aliases = {
    -- 'custom': players pick their own alias; 'random': generated from the lists below.
    Mode = 'custom',
    MinLength = 3,
    MaxLength = 20,
    ChangeCooldownHours = 24,
    Adjectives = { 'Grauer', 'Stiller', 'Kalter', 'Schneller', 'Dunkler', 'Blinder', 'Roter', 'Leiser' },
    Nouns = { 'Fuchs', 'Rabe', 'Geist', 'Wolf', 'Schatten', 'Kojote', 'Falke', 'Hai' },
}

Config.Channels = {
    { id = 'general', label = { de = 'Allgemein', en = 'General' } },
    { id = 'jobs', label = { de = 'Aufträge', en = 'Jobs' } },
    { id = 'weapons', label = { de = 'Waffen', en = 'Weapons' } },
    { id = 'goods', label = { de = 'Ware', en = 'Goods' } },
    { id = 'vehicles', label = { de = 'Fahrzeuge', en = 'Vehicles' } },
    { id = 'intel', label = { de = 'Infos', en = 'Intel' } },
}

Config.Messages = {
    MaxLength = 500,
    PostsPerMinute = 6,
    DirectPerMinute = 30,
    ChannelPageSize = 60,
    LifetimeHours = 72,           -- everything disappears after this
}

Config.Police = {
    Jobs = { police = 0, sheriff = 0 }, -- job = minimum grade
    -- Officers can extract a seized phone's Shadow data without the PIN.
    CrackSeconds = 60,
}
