
local surfaces = {
    ['Space_Race'] = require 'modules.mini-games.space_race.map_gen.map'
}

local gen = require('utils.map_gen.generate')
gen.init{ surfaces = surfaces }
gen.register()
