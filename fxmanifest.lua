fx_version 'cerulean'
game 'gta5'
name 'crimson_taxi'
description 'crimson_taxi code by Thỏ (TxM)'
version '1.0.0'

ui_page 'html/meter.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client/main.lua'
server_script {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
    }

files {
    'html/meter.css',
    'html/meter.html',
    'html/meter.js',
    'html/reset.css',
    'html/g5-meter.png'
}

lua54 'yes'
