fx_version 'cerulean'
game 'gta5'
lua54 'yes'
node_version '22'

name 'snitch'
author 'Wolfsrudel Gaming'
description 'Snitch - Livestreaming app for Sky Phone'
version '0.1.0'

-- Hidden full-screen page that captures the phone camera picture and the
-- microphone and sends the stream. The visible app runs inside Sky Phone.
ui_page 'web/engine.html'

shared_scripts {
    'config.lua',
    'shared/split.lua',
}

client_scripts {
    'client/rpc.lua',
    'client/phone.lua',
    'client/stream.lua',
    'client/nui.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/password.js',
    'server/util.lua',
    'server/rpc.lua',
    'server/database.lua',
    'server/bank.lua',
    'server/accounts.lua',
    'server/streams.lua',
    'server/donations.lua',
    'server/earnings.lua',
}

files {
    'web/*.html',
    'web/*.svg',
    'web/assets/*',
}

dependencies {
    'oxmysql',
    'es_extended',
    'sky_phone',
}
