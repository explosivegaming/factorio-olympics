--- Util Requires
local Global = require 'utils.global'
local Color = require 'utils.color_presets'
local MS = require 'utils.map_gen.minigame_surface'

--- Expcore Requires
local Mini_games = require "expcore.Mini_games"
local Gui = require 'expcore.gui'
local Commands = require 'expcore.commands'

--- Feature Requires
local Retailer = require 'modules.mini-games.space_race.retailer'
local Market_Items = require 'modules.mini-games.space_race.market_items'
local config = require 'config.mini_games.space_race'

--- Gui and map gen requires
local join_gui = require 'modules.mini-games.space_race.join_gui'
local cliff = require 'modules.mini-games.space_race.cliff_generator'
local market_events = require 'modules.mini-games.space_race.market_handler'
local uranium_gen = require('modules.mini-games.space_race.map_gen.uranium_island')
local safe_ore_gen_on_init = require('modules.mini-games.space_race.map_gen.safe_zone_ores').on_init
local wild_ore_gen_on_init = require('modules.mini-games.space_race.map_gen.wilderness_ores').on_init
local uranium_gen_events, uranium_gen_reset = uranium_gen.events, uranium_gen.reset

--- Local Variables
local player_kill_reward = config.player_kill_reward
local floor = math.floor
local Public = {}

local starting_items = {
    {name = 'iron-gear-wheel', count = 8},
    {name = 'iron-plate', count = 16}
}

local player_ports = {
    USA = {{x = -409, y = 0}, {x = -380, y = 0}},
    USSR = {{x = 409, y = 0}, {x = 380, y = 0}}
}

local researched_tech = {}
local disabled_research = config.disabled_research
local disabled_recipes = config.disabled_recipes

--- Global Variables
local primitives = {
    players_needed = 1,
    startup_timer = 30*3600,
    force_USA = nil,
    force_USSR = nil,
    won = nil
}

Global.register(primitives, function(tbl)
    primitives = tbl
end)

----- Game Init and Start -----

--- Remove disabled recipes from forces
function Public.remove_recipes()
    local USA_recipe = primitives.force_USA.recipes
    local USSR_recipe = primitives.force_USSR.recipes
    for _, recipe in pairs(disabled_recipes) do
        USA_recipe[recipe].enabled = false
        USSR_recipe[recipe].enabled = false
    end
end

--- Called before the game starts and before any players are added
local function on_init(args)
    Mini_games.set_participant_requirement(tonumber(args[1]))
    primitives.players_needed = tonumber(args[1])
    primitives.startup_timer = tonumber(args[2]) * 3600
    game.difficulty_settings.technology_price_multiplier = 0.5

    local force_USA = game.create_force(args[3] or 'United Factory Workers')
    local force_USSR = game.create_force(args[4] or 'Union of Factory Employees')

    local surface = MS.generate_surface('Space_Race')
    surface.min_brightness = 0;

    force_USSR.set_spawn_position({x = 409, y = 0}, surface)
    force_USA.set_spawn_position({x = -409, y = 0}, surface)

    force_USSR.laboratory_speed_modifier = 1
    force_USA.laboratory_speed_modifier = 1

    force_USSR.research_queue_enabled = true
    force_USA.research_queue_enabled = true

    surface.request_to_generate_chunks({400, 0}, 3)
    surface.request_to_generate_chunks({-400, 0}, 3)

    local market
    market = surface.create_entity {name = 'market', position = {x = 404, y = 0}, force = force_USSR}
    market.destructible = false

    Retailer.add_market('USSR_market', market)

    market = surface.create_entity {name = 'market', position = {x = -404, y = 0}, force = force_USA}
    market.destructible = false

    Retailer.add_market('USA_market', market)

    if table.size(Retailer.get_items('USSR_market')) == 0 then
        local items = table.deep_copy(Market_Items)
        for _, prototype in pairs(items) do
            local name = prototype.name
            prototype.price = (disabled_research[name] and disabled_research[name].player) and disabled_research[name].player * player_kill_reward or prototype.price
            local unlock_requires = disabled_research[name]
            if prototype.disabled and unlock_requires then
                if unlock_requires.invert then
                    prototype.disabled_reason = {'', 'Unlocks when ' .. unlock_requires.player .. ' players have been killed or\n' .. unlock_requires.entity .. ' entities have been destroyed'}
                else
                    prototype.disabled_reason = {'', 'To unlock kill ' .. unlock_requires.player .. ' players or\ndestroy ' .. unlock_requires.entity .. ' entities'}
                end
            end
            Retailer.set_item('USSR_market', prototype)
        end
    end

    if table.size(Retailer.get_items('USA_market')) == 0 then
        local items = table.deep_copy(Market_Items)
        for _, prototype in pairs(items) do
            local name = prototype.name
            prototype.price = (disabled_research[name] and disabled_research[name].player) and disabled_research[name].player * player_kill_reward or prototype.price
            local unlock_requires = disabled_research[name]
            if prototype.disabled and unlock_requires then
                if unlock_requires.invert then
                    prototype.disabled_reason = {'', 'Unlocks when ' .. unlock_requires.player .. ' players have been killed or\n ' .. unlock_requires.entity .. ' entities have been destroyed'}
                else
                    prototype.disabled_reason = {'', 'To unlock kill ' .. unlock_requires.player .. ' players or\n destroy ' .. unlock_requires.entity .. ' entities'}
                end
            end
            Retailer.set_item('USA_market', prototype)
        end
    end

    --ensures that the spawn points are not water
    surface.set_tiles(
        {
            {name = 'stone-path', position = {x = 409.5, y = 0.5}},
            {name = 'stone-path', position = {x = 409.5, y = -0.5}},
            {name = 'stone-path', position = {x = 408.5, y = -0.5}},
            {name = 'stone-path', position = {x = 408.5, y = 0.5}},
            {name = 'stone-path', position = {x = -409.5, y = 0.5}},
            {name = 'stone-path', position = {x = -409.5, y = -0.5}},
            {name = 'stone-path', position = {x = -408.5, y = -0.5}},
            {name = 'stone-path', position = {x = -408.5, y = 0.5}}
        }
    )

    for force_side, ports in pairs(player_ports) do
        local force
        if force_side == 'USA' then
            force = force_USA
        elseif force_side == 'USSR' then
            force = force_USSR
        end
        for _, port in pairs(ports) do
            rendering.draw_text {text = {'', 'Use the /warp command to teleport across'}, surface = surface, target = port, color = Color.red, forces = {force}, alignment = 'center', scale = 0.75}
        end
    end

    local USA_tech = force_USA.technologies
    local USSR_tech = force_USSR.technologies
    for research, _ in pairs(disabled_research) do
        USA_tech[research].enabled = false
        USSR_tech[research].enabled = false
    end
    for research, _ in pairs(researched_tech) do
        USA_tech[research].researched = true
        USSR_tech[research].researched = true
    end

    primitives.force_USA = force_USA
    primitives.force_USSR = force_USSR

    Public.remove_recipes()
    safe_ore_gen_on_init()
    wild_ore_gen_on_init()
    if uranium_gen_events.on_init then
        uranium_gen_events.on_init()
    end
end

--- Show the join team gui when wanting to select participants
local function participant_selector(player, remove_selector)
    if remove_selector then
        Gui.destroy_if_valid(player.gui.center['Space-Race'])
        if Mini_games.get_current_state() == 'Loading' then
            Mini_games.show_waiting_screen(player)
        end
    else
        join_gui.show_gui{ player_index = player.index }
    end
end

--- When a player joins teleport them to there base, if start of game then give them a character
local get_teleport_location
local function on_player_joined(event)
    local player = game.players[event.player_index]

    if Mini_games.get_current_state() == 'Starting' then
        if player.character then player.character.destroy() end
        player.create_character()
        game.permissions.get_group('Default').add_player(player)
        for _, item in pairs(starting_items) do
            player.insert(item)
        end
    end

    player.teleport(get_teleport_location(player.force, true), MS.get_surface())
end

--- Tile map used to produce the two out of map walls
local tiles = {}

local out_of_map_x = 388
local out_of_map_height = 512
local ignored_height = 18
local insert = table.insert

for i = -out_of_map_height / 2, out_of_map_height / 2, 1 do
    if i < -ignored_height / 2 or i > ignored_height / 2 then
        insert(tiles, {name = 'out-of-map', position = {x = out_of_map_x + 1, y = i}})
        insert(tiles, {name = 'out-of-map', position = {x = -(out_of_map_x + 1), y = i}})
        insert(tiles, {name = 'out-of-map', position = {x = out_of_map_x - 1, y = i}})
        insert(tiles, {name = 'out-of-map', position = {x = -(out_of_map_x - 1), y = i}})
        insert(tiles, {name = 'out-of-map', position = {x = out_of_map_x, y = i}})
        insert(tiles, {name = 'out-of-map', position = {x = -(out_of_map_x), y = i}})
    end
end

--- Creates the walls, silo, and turret at a teams spawn
local function generate_structures()
    local surface = MS.get_surface()

    local force_USSR = primitives.force_USSR
    local force_USA = primitives.force_USA

    local silo
    silo = surface.create_entity {name = 'rocket-silo', position = {x = 388.5, y = -0.5}, force = force_USSR}
    silo.minable = false

    silo = surface.create_entity {name = 'rocket-silo', position = {x = -388.5, y = 0.5}, force = force_USA}
    silo.minable = false

    local wall
    wall = surface.create_entity {name = 'stone-wall', position = {x = 384.5, y = 18.5}, always_place = true, force = 'neutral'}
    wall.destructible = false
    wall.minable = false

    wall = surface.create_entity {name = 'stone-wall', position = {x = 384.5, y = -17.5}, always_place = true, force = 'neutral'}
    wall.destructible = false
    wall.minable = false

    wall = surface.create_entity {name = 'stone-wall', position = {x = -384.5, y = 18.5}, always_place = true, force = 'neutral'}
    wall.destructible = false
    wall.minable = false

    wall = surface.create_entity {name = 'stone-wall', position = {x = -384.5, y = -17.5}, always_place = true, force = 'neutral'}
    wall.destructible = false
    wall.minable = false

    local gun_turret
    gun_turret = surface.create_entity {name = 'gun-turret', position = {x = 383, y = 0}, force = force_USSR}
    gun_turret.insert({name = 'firearm-magazine', count = 200})

    gun_turret = surface.create_entity {name = 'gun-turret', position = {x = -383, y = 0}, force = force_USA}
    gun_turret.insert({name = 'firearm-magazine', count = 200})
end

--- Used to start the game after the map has been generated and teams assigned
local function start()
    game.forces.enemy.evolution_factor = 0

    local surface = MS.get_surface()
    primitives.force_USA.chart(surface, {{x = -380, y = 64}, {x = -420, y = -64}})
    primitives.force_USSR.chart(surface, {{x = 380, y = 64}, {x = 420, y = -64}})

    cliff.generate_cliffs(surface)
    surface.set_tiles(tiles)
    generate_structures()
end

----- Pre Game Start -----

--- Check that a tile is valid and is the correct type
local function check_tile_type(surface, x, y, name)
    local tile = surface.get_tile{x, y}
    return tile.valid and tile.name == name
end

--- Check if the map generation is done, ran once per second until generation is done
local function ready_condition()
    local surface = MS.get_surface()
    return check_tile_type(surface, 388.5, 0,  'landfill')   and check_tile_type(surface, -388, 0,  'landfill')
       and check_tile_type(surface, 388,   60, 'out-of-map') and check_tile_type(surface, -388, 60, 'out-of-map')
       and check_tile_type(surface, 479,   0,  'water')      and check_tile_type(surface, -479, 0,  'water')
end

--- Make a player join team usa
function Public.join_usa(player)
    local force_USA = primitives.force_USA

    local force = player.force
    if force == force_USA then
        player.print('[color=red]Failed to join [/color][color=yellow]'..force_USA.name..',[/color][color=red] you are already part of this team![/color]')
        return false
    end

    if player.character then
        local empty_inventory =
        player.get_inventory(defines.inventory.character_main).is_empty() and
        player.get_inventory(defines.inventory.character_trash).is_empty() and
        player.get_inventory(defines.inventory.character_ammo).is_empty() and
        player.get_inventory(defines.inventory.character_armor).is_empty() and
        player.get_inventory(defines.inventory.character_guns).is_empty() and
        player.crafting_queue_size == 0
        if not empty_inventory then
            player.print('[color=red]Failed to join [/color][color=yellow]'..force_USA.name..',[/color][color=red] you need an empty inventory![/color]')
            return false
        end
    end

    player.force = force_USA
    player.print('[color=green]You have joined '..force_USA.name..'![/color]')
    Mini_games.show_waiting_screen(player)
    Mini_games.add_participant(player)
    Public.update_gui()
    return true
end

--- Make a player join team ussr
function Public.join_ussr(player)
    local force_USSR = primitives.force_USSR

    local force = player.force
    if force == force_USSR then
        player.print('[color=red]Failed to join [/color][color=yellow]'..force_USSR.name..',[/color][color=red] you are already part of this team![/color]')
        return false
    end

    if player.character then
        local empty_inventory =
        player.get_inventory(defines.inventory.character_main).is_empty() and
        player.get_inventory(defines.inventory.character_trash).is_empty() and
        player.get_inventory(defines.inventory.character_ammo).is_empty() and
        player.get_inventory(defines.inventory.character_armor).is_empty() and
        player.get_inventory(defines.inventory.character_guns).is_empty() and
        player.crafting_queue_size == 0
        if not empty_inventory then
            player.print('[color=red]Failed to join [/color][color=yellow]'..force_USSR.name..',[/color][color=red] you need an empty inventory![/color]')
            return false
        end
    end

    player.force = force_USSR
    player.print('[color=green]You have joined '..force_USSR.name..'![/color]')
    Mini_games.show_waiting_screen(player)
    Mini_games.add_participant(player)
    Public.update_gui()
    return true
end

----- Game Stop -----

--- Used to stop a game
local function stop()
    local won, player_names = primitives.won, {}
    for index, player in ipairs(game.connected_players) do
        local gui = player.gui.center['Space-Race']
        Gui.destroy_if_valid(gui)
        if player.force.name == won then
            player_names[index] = player.name
        end
    end

    return Mini_games.format_airtable{primitives.won, player_names}
end

--- Used to stop a game and reset all variables, called by mini game manager
local function on_close()
    game.merge_forces(primitives.force_USA, game.forces.player)
    game.merge_forces(primitives.force_USSR, game.forces.player)
    MS.remove_surface('Space_Race')

    primitives.force_USA = nil
    primitives.force_USSR = nil
    primitives.won = nil

    uranium_gen_reset()

    for i, player in ipairs(game.players) do
        Gui.destroy_if_valid(player.gui.center['Space-Race'])
    end
end

--- Used to print a force won, and stop the game
local function victory(force)
    primitives.won = force
    game.print('Congratulations to ' .. force.name .. '. You have gained factory dominance!')
    Mini_games.stop_game()
end

--- Used to print a force lost, and stop the game
function Public.lost(force)
    local force_USA = primitives.force_USA
    if force == force_USA then
        victory(primitives.force_USSR)
    else
        victory(force_USA)
    end
end

----- Warp Command -----

--- Check if a player is allowed to teleport
local function allow_teleport(force, position)
    if force == primitives.force_USA and position.x > 0 then
        return false
    elseif force == primitives.force_USSR and position.x < 0 then
        return false
    end
    return math.abs(position.x) > 377 and math.abs(position.x) < 410 and position.y > -10 and position.y < 10
end

--- Get the teleport location for a force, either in the pvp zone or in the sage zone
function get_teleport_location(force, to_safe_zone)
    local port_number = to_safe_zone and 1 or 2
    local position
    if force == primitives.force_USA then
        position = player_ports.USA[port_number]
    elseif force == primitives.force_USSR then
        position = player_ports.USSR[port_number]
    else
        position = {0, 0}
    end
    local non_colliding_pos = MS.get_surface().find_non_colliding_position('character', position, 6, 1)
    position = non_colliding_pos and non_colliding_pos or position
    return position
end

--- Command used to teleport from pvp to safe and vise versa
Commands.new_command('warp', 'Use to switch between PVP and Safe-zone in Space Race')
:register(function(player)
    local character = player.character
    if not character or not character.valid then
        player.print('[color=yellow]Could not warp, you are not part of a team yet![/color]')
        return Commands.error
    end

    local tick = game.tick - Mini_games.get_start_time()
    if tick < primitives.startup_timer then
        local time_left = primitives.startup_timer - tick
        if time_left > 60 then
            local minutes = (time_left / 3600)
            minutes = minutes - minutes % 1
            time_left = time_left - (minutes * 3600)
            local seconds = (time_left / 60)
            seconds = seconds - seconds % 1
            time_left = minutes .. ' minutes and ' .. seconds .. ' seconds left'
        else
            local seconds = (time_left - (time_left % 60)) / 60
            time_left = seconds .. ' seconds left'
        end
        player.print('[color=yellow]Could not warp, in setup phase![/color] [color=red]' .. time_left .. '[/color]')
        return Commands.error
    end

    local position = character.position
    local force = player.force
    if allow_teleport(force, position) then
        if math.abs(position.x) < 388.5 then
            player.teleport(get_teleport_location(force, true))
        else
            player.teleport(get_teleport_location(force, false))
        end
    else
        player.print('[color=yellow]Could not warp, you are too far from rocket silo![/color]')
        return Commands.error
    end

end)

----- Public Variables -----

--- Get the force that has won
function Public.get_won()
    return primitives.won
end

--- Get an array of the teams
function Public.get_teams()
    return {primitives.force_USA, primitives.force_USSR}
end

----- Events -----

--- Triggered when a rocket is launch, causes that team to win
local function on_rocket_launched(event)
    victory(event.rocket_silo.force)
end

--- Triggered when a entity is built, certain entities will be moved to neutral force, while others are printed to chat
local function on_built_entity(event)
    local entity = event.created_entity

    if not entity or not entity.valid then
        return
    end

    local name = entity.name

    if config.neutral_entities[name] then
        entity.force = 'neutral'
        return
    end

    if config.warning_on_built[name] then
        local position = entity.position
        game.print({'', '[gps=' .. floor(position.x) .. ', ' .. floor(position.y) .. '] [color=yellow]Warning! ', {'entity-name.' .. name}, ' has been deployed![/color]'})
    end
end

--- Called once per second, will update a players movement speed based on their health
local function check_damaged_players()
    for k, player in pairs (Mini_games.get_participants()) do
        if player.character and player.character.health ~= nil then
            local health_missing = 1 - math.ceil(player.character.health) / (250 + player.character.character_health_bonus)
            if health_missing > 0 then
	            local current_modifier = 0
				local hurt_speed_percent = 80
				local reduction = 1 - hurt_speed_percent / 100
				player.character_running_speed_modifier = (1 - health_missing * reduction) * (current_modifier + 1) - 1
			end
		end
	end
end

----- Gui and Registering -----

--- Update the gui for all players
function Public.update_gui()
    for _, player in ipairs(game.connected_players) do
        local gui = player.gui.center['Space-Race']
        if gui and player.force.name == 'player' then
            -- todo make an update function
            join_gui.show_gui{player_index = player.index}
        elseif gui then
            Gui.destroy_if_valid(gui)
        end
    end
end

--- Added a remote interface
remote.add_interface('space-race', Public)

--- Text entry for the number of players who will play
local text_field_for_players =
Gui.element{
    type = 'textfield',
    tooltip = 'Player Count',
    text  = "1",
    numeric = true,
}
:style{
  width = 50
}

--- Text entry for the start up time for the teams
local text_field_for_startup =
Gui.element{
    type = 'textfield',
    tooltip = 'Peace Time Duration (minutes)',
    text = tostring(30),
    numeric = true,
}
:style{
  width = 50
}

--- Text entry for the usa team name
local text_field_for_usa_name =
Gui.element{
    type = 'textfield',
    tooltip = 'Team One Name',
    text = 'United Factory Workers',
}
:style{
  width = 50
}

--- Text entry for the ussr team name
local text_field_for_ussr_name =
Gui.element{
    type = 'textfield',
    tooltip = 'Team Two Name',
    text = 'Union of Factory Employees',
}
:style{
  width = 50
}

--- Main gui for starting the game
local main_gui =
Gui.element(function(_, parent)
    text_field_for_players(parent)
    text_field_for_startup(parent)
    text_field_for_usa_name(parent)
    text_field_for_ussr_name(parent)
end)

--- Used to read args from the gui
local function gui_callback(parent)
    local args = {}

    args[1] = tonumber(parent[text_field_for_players.name].text)
    args[2] = tonumber(parent[text_field_for_startup.name].text)
    args[3] = parent[text_field_for_usa_name.name].text
    args[4] = parent[text_field_for_ussr_name.name].text

    return args
end

--- Register the game to the mini game module
local space_race = Mini_games.new_game("Space_Race")
space_race:set_core_events(on_init, start, stop, on_close)
space_race:add_surface('Space_Race', 'modules.mini-games.space_race.map_gen.map')
space_race:set_ready_condition(ready_condition)
space_race:set_participant_selector(participant_selector, true)
space_race:set_gui(main_gui, gui_callback)
space_race:add_option(4)

space_race:add_event(Mini_games.events.on_participant_joined, on_player_joined)

space_race:add_event(defines.events.on_rocket_launched, on_rocket_launched)
space_race:add_event(defines.events.on_built_entity, on_built_entity)
space_race:add_event(defines.events.on_entity_died, market_events.on_entity_died)
space_race:add_event(defines.events.on_player_died, market_events.on_player_died)
space_race:add_event(defines.events.on_research_finished, market_events.on_research_finished)
space_race:add_event(Retailer.events.on_market_purchase, market_events.on_market_purchase)
space_race:add_nth_tick(20, check_damaged_players)
if uranium_gen_events.on_nth_tick then
    space_race:add_nth_tick(600, uranium_gen_events.on_nth_tick)
end

space_race:add_command('warp')