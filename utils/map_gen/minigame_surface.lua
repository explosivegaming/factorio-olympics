--[[
    --- This is a modified version of redmew_surface to allow multiple surfaces to be defined, and for surfaces to be re-generated
    Creates a custom surface for all redmew maps so that we can ignore all user input at time of world creation.

    Allows map makers to define the map gen settings, map settings, and difficulty settings in as much or as little details as they want.
    The aim is to make this a very easy process for map makers, while eliminating the need for some of the existing builder functions.
    For example by preventing ores from spawning we no longer need to manually scan for and remove ores.

    When you create a new map you're given many options. These options break into 3 categories which are not made explicitly
    clear in the game itself:
    map_gen_settings, map_settings, and difficulty_settings

    map_gen_settings: Only affect a given surface. These settings determine everything that surface is made of:
    ores, tiles, entities, boundaries, etc. It also contains a less obvious setting: peaceful_mode.

    map_settings: Are kind of a misnomer since they apply to the game at large. Contain settings for pollution, enemy_evolution, enemy_expansion,
    unit_group, steering, path_finder, and something called max_failed_behavior_count (shrug)
    lastly, difficulty_settings

    difficulty_settings: contains only recipe_difficulty, technology_difficulty (not used in vanilla), and technology_price_multiplier

    In the 16.51 version of factorio's Map Generator page difficulty_settings make up the "Recipes/Technology" section of the
    "Advanced settings" tab. map_settings make up the rest of that tab.
    map_gen_settings are detemined by everything in the remaining 3 tabs (Basic settings, Resource settings, Terrain settings)

    Unless fed arguments via the public functions, this module will simply clone nauvis, respecting all user settings.
    To pass settings to redmew_surface, each of the above-mentioned 3 settings components has a public function.
    set_map_gen_settings, set_map_settings, and set_difficulty_settings
    The functions all take a list of tables which contain settings. The tables then overwrite any existing user settings.
    Therefore, for any settings not explicitly set the user's settings persist.

    Tables of settings can be constructed manually or can be taken from the resource files by the same names (resources/map_gen_settings, etc.)

    Example: to select a 4x tech cost you would call:
    RS.set_difficulty_settings({difficulty_settings_presets.tech_x4})

    It should be noted that tables earlier in the list will be overwritten by tables later in the list.
    So in the following example the resulting tech cost would be 4, not 3.

    RS.set_difficulty_settings({difficulty_settings_presets.tech_x3, difficulty_settings_presets.tech_x4})

    To create a map with no ores, no enemies, no pollution, no enemy evolution, 3x tech costs, and sand set to high we would use the following:

    -- We require redmew_surface to access the public functions and assign the table Public to the RS variable to access them easily.
    local RS = require 'map_gen.shared.redmew_surface'
    -- We require the resources tables so that we don't have to write settings components by hand.
    local MGSP = require 'resources.map_gen_settings' -- map gen settings presets
    local DSP = require 'resources.difficulty_settings' -- difficulty settings presets
    local MSP = require 'resources.map_settings' -- map settings presets

    -- We create a custom table for the niche settings of wanting more sand
    local extra_sand = {
        autoplace_controls = {
            sand = {frequency = 'high', size = 'high'}
        }
    }

    RS.set_map_gen_settings({MGSP.enemy_none, MGSP.ore_none, MGSP.oil_none, extra_sand})
    RS.set_difficulty_settings({DSP.tech_x3})
    RS.set_map_settings({MSP.enemy_evolution_off, MSP.pollution_off})
]]
-- Dependencies
require 'util'
local Global = require 'utils.global'

-- Localized functions
local merge = util.merge
local format = string.format
local error_if_runtime = _C.error_if_runtime

-- Constants
local set_warn_message = 'set_%s has already been called for %s. Calling this twice can lead to unexpected settings overwrites.'

-- Local vars
local Public = { _prototype = {}, surfaces = {} }

-- Global vars
local primitives = {
    newest_surface = nil
}

Global.register(primitives, function(tbl)
    primitives = tbl
end)

-- Local functions

--- Add the tables inside components into the given data_table
local function combine_settings(components, data_table)
    local last = #data_table
    for i, v in pairs(components) do
        data_table[last+i] = v
    end
end

--- Sets up the difficulty settings
local function set_difficulty_settings(settings)
    local combined_difficulty_settings = merge(settings)
    for k, v in pairs(combined_difficulty_settings) do
        game.difficulty_settings[k] = v
    end
end

--- Sets up the map settings
local function set_map_settings(settings)
    local combined_map_settings = merge(settings)

    -- Iterating through individual tables because game.map_settings is read-only
    if combined_map_settings.pollution then
        for k, v in pairs(combined_map_settings.pollution) do
            game.map_settings.pollution[k] = v
        end
    end
    if combined_map_settings.enemy_evolution then
        for k, v in pairs(combined_map_settings.enemy_evolution) do
            game.map_settings.enemy_evolution[k] = v
        end
    end
    if combined_map_settings.enemy_expansion then
        for k, v in pairs(combined_map_settings.enemy_expansion) do
            game.map_settings.enemy_expansion[k] = v
        end
    end
    if combined_map_settings.unit_group then
        for k, v in pairs(combined_map_settings.unit_group) do
            game.map_settings.unit_group[k] = v
        end
    end
    if combined_map_settings.steering then
        if combined_map_settings.steering.default then
            for k, v in pairs(combined_map_settings.steering.default) do
                game.map_settings.steering.default[k] = v
            end
        end
        if combined_map_settings.steering.moving then
            for k, v in pairs(combined_map_settings.steering.moving) do
                game.map_settings.steering.moving[k] = v
            end
        end
    end
    if combined_map_settings.path_finder then
        for k, v in pairs(combined_map_settings.path_finder) do
            game.map_settings.path_finder[k] = v
        end
    end
    if combined_map_settings.max_failed_behavior_count then
        game.map_settings.max_failed_behavior_count = combined_map_settings.max_failed_behavior_count
    end
end

-- Public Functions

--- Creates a new surface with the settings provided by the map file and the player.
function Public._prototype:create_surface()
    local surface

    if self.set_map_gen_settings_called then
        -- Add the user's map gen settings as the first entry in the table
        local combined_map_gen = {game.surfaces.nauvis.map_gen_settings}
        -- Take the map's settings and add them into the table
        for i, v in pairs(self.map_gen_settings_components) do
            combined_map_gen[i+1] = v
        end
        surface = game.create_surface(self.surface_name, merge(combined_map_gen))
    else
        surface = game.create_surface(self.surface_name)
    end

    if self.set_difficulty_settings_called then
        set_difficulty_settings(self.difficulty_settings_components)
    end

    if self.set_map_settings_called then
        set_map_settings(self.map_settings_components)
    end

    primitives.newest_surface = surface
    surface.request_to_generate_chunks({0, 0}, 4)
    surface.force_generate_chunk_requests()
    if self.spawn_position then
        game.forces.player.set_spawn_position(self.spawn_position, surface)
    end

    return surface
end

--- Teleport the player to the redmew surface and if there is no suitable location, create an island
function Public._prototype:teleport_player(player, position)
    local surface = game.surfaces[self.surface_name]

    position = position or self.spawn_position or {x = 0, y = 0}
    local pos = surface.find_non_colliding_position('character', position, 50, 1)

    if pos and not self.first_player_position_check_override then -- we tp to that pos
        player.teleport(pos, surface)
    else
        -- if there's no position available within range or we override the position check:
        -- create an island and place the player at spawn_position
        local island_tile = self.island_tile or 'lab-white'
        local tile_table = {}
        local index = 1
        for x = -1, 1 do
            for y = -1, 1 do
                tile_table[index] = {name = island_tile, position = {position.x - x, position.y - y}}
                index = index + 1
            end
        end
        surface.set_tiles(tile_table)

        player.teleport(position, surface)
        self.first_player_position_check_override = nil
    end
end

--- Returns a new surface definition
-- This can only be called during the control stage, and the same goes for all the set functions for a surface
-- @param surface_name <string> the name of the surface that will be created with these settings
function Public.new(surface_name)
    error_if_runtime()

    local surface = setmetatable({
        surface_name = surface_name,

        set_difficulty_settings_called = false,
        set_map_gen_settings_called = false,
        set_map_settings_called = false,

        difficulty_settings_components = {},
        map_gen_settings_components = {},
        map_settings_components = {},

    }, { __index = Public._prototype })

    Public.surfaces[surface_name] = surface
    return surface
end

--- Generate a surface, this takes the name of the surface that will be made, this will also set the active surface
function Public.generate_surface(surface_name)
    local surface = Public.surfaces[surface_name]
    return surface:create_surface()
end

--- Remove a surface so that it can be regenerated later, this can not be done during the same tick as generate_surface
function Public.remove_surface(surface_name)
    game.delete_surface(surface_name)
end

--- Teleport a player to a given surface, this takes the name of the surface to spawn the player on
function Public.teleport_player(player, surface_name, position)
    local surface = Public.surfaces[surface_name]
    surface:teleport_player(player, position)
end

--- Set the currently active surface, this takes the name of the surface and sets it as the active one
function Public.set_surface(surface_name)
    primitives.newest_surface = game.surfaces[surface_name]
end

--- Get the currently active surface, this assumes the active one was the last one to be generated unless set other wise
function Public.get_surface()
    return primitives.newest_surface
end

--- Get the currently active surface name, this assumes the active one was the last one to be generated unless set other wise
function Public.get_surface_name()
    return primitives.newest_surface.name
end

--- Sets components to the difficulty_settings_components table
-- It is an error to call this twice as later calls will overwrite earlier ones if values overlap.
-- @param components <table> list of difficulty settings components (usually from resources.difficulty_settings)
function Public._prototype:set_difficulty_settings(components)
    error_if_runtime()
    if self.set_difficulty_settings_called then
        log(format(set_warn_message, 'difficulty_settings', self.surface_name))
    end
    combine_settings(components, self.difficulty_settings_components)
    self.set_difficulty_settings_called = true
end

--- Adds components to the map_gen_settings_components table
-- It is an error to call this twice as later calls will overwrite earlier ones if values overlap.
-- @param components <table> list of map gen components (usually from resources.map_gen_settings)
function Public._prototype:set_map_gen_settings(components)
    error_if_runtime()
    if self.set_map_gen_settings_called then
        log(format(set_warn_message, 'map_gen_settings', self.surface_name))
    end
    combine_settings(components, self.map_gen_settings_components)
    self.set_map_gen_settings_called = true
end

--- Adds components to the map_settings_components table
-- It is an error to call this twice as later calls will overwrite earlier ones if values overlap.
-- @param components <table> list of map setting components (usually from resources.map_settings)
function Public._prototype:set_map_settings(components)
    error_if_runtime()
    if self.set_map_settings_called then
        log(format(set_warn_message, 'map_settings', self.surface_name))
    end
    combine_settings(components, self.map_settings_components)
    self.set_map_settings_called = true
end

--- Allows maps to skip the collision check for the first player being teleported.
-- This is useful when a collision check at the spawn point is either invalid or puts the
-- player in a position that will get them killed by map generation (ex. diggy, tetris)
function Public._prototype:set_first_player_position_check_override(bool)
    error_if_runtime()
    self.first_player_position_check_override = bool
end

--- Allows maps to set a custom spawn position
-- @param position <table> with x and y keys ex.{x = 5.0, y = 5.0}
function Public._prototype:set_spawn_position(position)
    error_if_runtime()
    self.spawn_position = position
end

--- Allows maps to set the tile used for spawn islands
-- @param tile_name <string> name of the tile to create the island out of
function Public._prototype:set_spawn_island_tile(tile_name)
    error_if_runtime()
    self.island_tile = tile_name
end

--- Returns the LuaSurface that the map is created on.
-- Not safe to call outside of events.
function Public._prototype:get_surface()
    return game.surfaces[self.surface_name]
end

--- Returns the string name of the surface that the map is created on.
-- This can safely be called at any time.
function Public._prototype:get_surface_name()
    return self.surface_name
end

return Public