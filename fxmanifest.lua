fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'm-carrental'
title 'CityRentals'
description 'Immersive vehicle rentals with NPC delivery. Works with lb-phone and sd-phone.'
author 'CityRentals'
version '1.1.0'

dependencies {
    'oxmysql',
    'ox_lib'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/phone.lua',
    'shared/locale.lua',
    'locales/*.lua',
    'shared/bridge.lua',
    'bridge/framework/*.lua',
}

client_scripts {
    'bridge/vehiclekeys/*.lua',
    'client/delivery.lua',
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

files {
    'ui/**/*'
}

ui_page 'ui/nui.html'
