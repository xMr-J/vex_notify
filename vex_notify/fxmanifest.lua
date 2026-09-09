fx_version 'cerulean'
game 'rdr3'

author 'VEX'
description 'VEX notification, alert, choice, progress, and world-space UI engine for RedM.'
version '0.1.0'

ui_page 'ui/index.html'

shared_scripts {
    'config.lua',
    'shared/sh_types.lua'
}

server_scripts {
    'server/sv_main.lua',
    'server/sv_choice.lua',
    'server/sv_progress.lua'
}

client_scripts {
    'client/cl_screen.lua',
    'client/cl_choice.lua',
    'client/cl_world.lua'
}

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js'
}

dependencies {
    'vex_core',
    'vex_callback'
}