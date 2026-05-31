fx_version "cerulean"
game "gta5"
lua54 'yes'

title "LB Phone - CityRentals"
description "Immersive vehicle rentals with NPC delivery for LB Phone."
author "CityRentals"
version "1.0.0"

dependencies {
    'lb-phone',
    'oxmysql',
    'ox_lib'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
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
    'ui/nui.html',
    'ui/index.html',
    'ui/script.js',
    'ui/styles.css',
    'ui/colors.css',
    'ui/frame.css',
    'ui/dev.js',
    'ui/assets/**/*'
}

ui_page 'ui/nui.html'
