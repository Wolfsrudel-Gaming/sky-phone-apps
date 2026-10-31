fx_version 'cerulean'
game 'gta5'
lua54 'yes'
node_version '22'

name 'shadow'
author 'Wolfsrudel Gaming'
description 'Shadow - anonymous underground board for Sky Phone'
version '0.1.0'

shared_script 'config.lua'

client_scripts {
    'client/rpc.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/pin.js',
    'server/util.lua',
    'server/rpc.lua',
    'server/database.lua',
    'server/main.lua',
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
