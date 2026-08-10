fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'

author 'NODE7 Development Studios'
description 'Secure NODE7 player robbery integration requiring the target to have their hands up.'
version '1.2.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/preload.lua',
    'client/main.lua'
}

server_scripts {
    'server/preload.lua',
    'server/main.lua'
}

dependencies {
    'node7-core',
    'node7-inventory',
    'node7-radialmenu'
}
