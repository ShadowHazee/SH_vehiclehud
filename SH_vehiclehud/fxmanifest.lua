fx_version 'cerulean'
game 'gta5'

name 'SH_Vehiclehud'
description 'Vehicle HUD'
version '1.0.0'

dependencies {
  'es_extended'
}

client_scripts {
    'config.lua',
    'client.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
    'ui/sounds/SeatbeltAlertSound.mp3',
    'ui/sounds/SeatbeltOnSound.mp3',
    'ui/sounds/SeatbeltOffSound.mp3',
    'ui/sounds/IndicatorSound.mp3'
}
