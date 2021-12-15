fx_version 'bodacious'
game 'gta5'

author 'BR'
description 'A Full Featured FiveM Gang XP System'
repository 'https://github.com/BehnamRt/FiveM_GangXP'


server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'config.lua',
    'server/main.lua'
}

client_scripts {
    'config.lua',
    'client/main.lua'
}

dependencies {
    'essentialmode',
    'mysql-async'
}

ui_page 'ui/ui.html'

files {
    'ui/ui.html',
    'ui/fonts/ChaletComprimeCologneSixty.ttf',
    'ui/css/app.css',
    'ui/js/class.xpm.js',
    'ui/js/class.paginator.js',
    'ui/js/class.leaderboard.js',
    'ui/js/app.js'
}