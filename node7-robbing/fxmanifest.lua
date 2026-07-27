fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'

author 'NODE7 Development Studios'
description 'Secure player robbery integration for NODE7 Core, NODE7 Inventory, and NODE7 Radial Menu.'
version '1.1.1'

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
