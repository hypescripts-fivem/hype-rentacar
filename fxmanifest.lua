fx_version 'cerulean'
game {'gta5'}

author 'vezironi'
description 'Hype Rent a Car is a vehicle rental script for FiveM servers. Players pick a vehicle at the rental office, choose how long they want to rent it and pay with cash or bank. Rentals are stored in the database and expire automatically.'

scriptname 'hype-rentacar'
version '1.0.0'

dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/*.lua',
    'shared/*.lua',
    'frameworks/main.lua',
    'modules/main.lua',
}

client_scripts {
    'frameworks/**/cl-main.lua',
    'modules/notify/cl-main.lua',
    'modules/target/**/cl-*.lua',
    'modules/fuel/cl-main.lua',
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'frameworks/**/sv-main.lua',
    'modules/inventory/sv-main.lua',
    'modules/notify/sv-main.lua',
    'modules/vehiclekeys/sv-main.lua',
    'modules/fuel/sv-main.lua',
    'server/*.lua',
}

escrow_ignore {
    'config/*.lua',
    'shared/*.lua',
    'frameworks/**/*.lua',
    'frameworks/main.lua',
    'modules/**/**.lua',
    'modules/main.lua',
    'client/*.lua',
    'server/*.lua',
}

files {
    'web/build/*.*',
    'web/build/**/*.*',
    'locales/*.json',
}

ui_page 'web/build/index.html'

lua54 'yes'
use_experimental_fxv2_oal 'yes'
