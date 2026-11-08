fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'mundstock; PowerMoves RP contributors'
description 'PM Education - shared institutional enrollment and examination foundation'
version '0.2.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client/main.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/questions.lua',
    'server/server.lua',
    'server/catalog.lua'
}

dependencies {
    'qb-core',
    'qb-banking',
    'qb-target',
    'ox_lib',
    'oxmysql'
}
