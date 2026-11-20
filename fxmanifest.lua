fx_version 'cerulean'
game 'gta5'

name 'at-lib'
description 'AT Library - Dialogue, Mission, Timer, Progress, TextUI, GangZone and minigames (NUI)'
version '1.2.0'
lua54 'yes'

ui_page 'web/build/index.html'

files {
    'modules/minigames/*.lua',
    'web/build/index.html',
    'web/build/**/*',
    'web/world/*',
}

dependency 'ox_lib'

shared_script '@ox_lib/init.lua'

client_scripts {
    'init.lua',
    'modules/dialogue/client.lua',
    'modules/missionstatus/client.lua',
    'modules/missioncard/client.lua',
    'modules/timer/client.lua',
    'modules/progress/client.lua',
    'modules/textui/client.lua',
    'modules/gangzone/client.lua',
    'modules/minigames/client.lua',
    'modules/worldui/client.lua',
    'modules/worldcard/client.lua',
}

server_scripts {
    'modules/minigames/server.lua',
}
