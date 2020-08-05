local Mini_games = require 'expcore.Mini_games'
local Global     = require 'utils.global' --Used to prevent desyncing.
local Gui        = require 'expcore.gui._require'

local targets    = {}
local lookups    = {}
local primitives = {}
local progress   = {}
local surfaces   = {}
local forces     = {}

local goals = require 'config.mini_games.speedrun'
for index, goal in ipairs(goals) do
    local lookup = {}
    lookups[index] = lookup
    targets[index] = goal.name

    local ctn = goal.rockets or 0
    for _, key in ipairs{'research', 'items', 'entities'} do
        local value = goal[key]
        if value then
            ctn = ctn + #value
            for _, name in ipairs(value) do lookup[key..'/'..name] = true end
        end
    end

    goal.total = ctn
end

Global.register({
    primitives = primitives,
    progress   = progress,
    surfaces   = surfaces,
    forces     = forces
}, function(tbl)
    primitives = tbl.primitives
    progress   = tbl.progress
    surfaces   = tbl.surfaces
    forces     = tbl.forces
end)

----- Local Variables ----

local starting_items = {
    {name = 'iron-gear-wheel', count = 8},
    {name = 'iron-plate', count = 16}
}

----- Local Functions -----

--- Internal, Used to clear tables of all values
local function reset_table(table)
    for k in pairs(table) do
        table[k] = nil
    end
end

--- Internal, Reset all global tables
local function reset_globals()
    reset_table(primitives)
    reset_table(progress)
    reset_table(surfaces)
    reset_table(surfaces)
end

----- Game Init and Start -----

--- First function called by the mini game core to prepare for the start of a game
local function init(args)
    local target = tonumber(args[1])
    if not target or target < 1 or target > #targets then Mini_games.error_in_game('Target index out of range') end
    primitives.target = target
    primitives.lookup = lookups[target]

    local team_count = tonumber(args[2])
    if not team_count or team_count < 1 then Mini_games.error_in_game('Team count is invalid') end
    primitives.team_count = team_count

    -- Create a surface for each team with the same seed and settings
    local seed, indicators = math.random(9999999999), goals[target]
    for i = 1, team_count do
        local name = 'SpeedrunTeam'..i
        forces[name] = game.create_force(name)
        forces[name].share_chart = true
        surfaces[name] = game.create_surface(name, { seed=seed })
        surfaces[name].request_to_generate_chunks({0, 0}, 5)
        progress[name] = { 0, indicators.total, table.deep_copy(indicators) }
    end
end

--- Called once enough participants are present to start the game and map generation is done
local function start()
    local force = game.forces.player
    for _, surface in pairs(surfaces) do
        force.chart(surface, {{x = 64, y = 64}, {x = -64, y = -64}})
    end
end

----- Game Stop and Close -----

--- Called to stop the game and return the results to be saved
local function stop()
    local scores, ctn = {}, 0
    -- Get all the data needed to write results
    for name, team_progress in pairs(progress) do
        ctn = ctn + 1
        local names = {}
        for index, player in ipairs(forces[name].players) do names[index] = player.name end
        scores[ctn] = { name, team_progress[1], names }
    end

    -- Sort by team progress
    table.sort(scores, function(a, b)
        return a[2] > b[2]
    end)

    -- Format the results table
    local results = {}
    for index, team in ipairs(scores) do
        results[index] = { place = index, score = team[2], players = team[3] }
    end

    return results
end

--- Final function called by the mini game core in order to clean up
local function close()
    for _, surface in pairs(surfaces) do
        game.delete_surface(surface)
    end

    reset_globals()
end

----- Player Events -----

--- Trigger when a participant is added to the game
-- Adds the player to the team with lowest player count
local function on_player_added(event)
    local player = game.players[event.player_index]
    local min_force, min_ctn = nil, 0
    for _, force in pairs(forces) do
        local player_ctn = #force.players
        if not min_force or min_ctn > player_ctn then
            min_force, min_ctn = force, player_ctn
        end
    end

    player.force = min_force
end

--- Trigger when a participant is removed from the game
-- Removes the player from the team arrays
local function on_player_removed(event)
    local player = game.players[event.player_index]
    player.force = game.forces.player
end

--- Trigger when a participant joins the game
local function on_player_joined(event)
    local player = game.players[event.player_index]

    if Mini_games.get_current_state() == 'Starting' then
        local surface = surfaces[player.force.name]

        -- Teleport the player to the new surface
        if player.character then player.character.destroy() end
        local pos = surface.find_non_colliding_position('character', {0, 0}, 50, 1)
        player.set_controller{ type = defines.controllers.god }
        player.teleport(pos, surface)
        player.create_character()

        -- Set permission group and give starting items
        game.permissions.get_group('Default').add_player(player)
        for _, item in pairs(starting_items) do
            player.insert(item)
        end

    end

end

----- Events -----

--- Used to update guis and end the game
local function update_progress(force, data)
    -- todo update player guis
    game.print(string.format('%s %d/%d', force.name, data[1], data[2]))
    if data[1] == data[2] then Mini_games.stop_game() end
end

--- Checks if an indicator has already been used
local function check_indicator(force, key, value)
    local data = progress[force.name]
    local indicators = data[3][key]
    for index, next_value in ipairs(indicators) do
        if next_value == value then
            local last = #indicators
            indicators[index] = indicators[last]
            indicators[last] = nil
            data[1] = data[1] + 1
            return update_progress(force, data)
        end
    end
end

--- Triggered when a research is completed
local function on_research_completed(event)
    local research = event.research.name
    if not primitives.lookup['research/'..research] then return end

    local force = event.research.force
    check_indicator(force, 'research', research)
end

--- Triggered when an entity is placed
local function on_entity_placed(event)
    local entity = event.created_entity.name
    if not primitives.lookup['entities/'..entity] then return end

    local force = event.created_entity.force
    check_indicator(force, 'entities', entity)
end

--- Triggered when an item is crafted
local function on_item_crafted(event)
    local item = event.item_stack.prototype.name
    if not primitives.lookup['items/'..item] then return end

    local force = game.players[event.player_index].force
    check_indicator(force, 'items', item)
end

--- Triggered when an item is dropped, backup method to trigger if item was not hand crafted
-- todo look into using production stats as an alternative
local function on_item_dropped(event)
    local item = event.entity.stack.name
    if not primitives.lookup['items/'..item] then return end

    local force = game.players[event.player_index].force
    check_indicator(force, 'items', item)
end

--- Triggered when a rocket is launched
local function on_rocket_launched(event)
    local force = event.rocket_silo.force
    local data = progress[force.name]
    local rockets = data[3].rockets
    if rockets and rockets > 0 then
        data[3].rockets = rockets - 1
        data[1] = data[1] + 1
        update_progress(force, data)
    end
end

----- Gui Elements -----

--- Used to select what type of fuel to use
-- @element fuel_dropdown
local target_dropdown =
Gui.element{
    type = 'drop-down',
    items = targets,
    selected_index = 4,
    tooltip = 'Target'
}

--- Used to select the number of laps to complete
-- @element text_field_for_laps
local team_count_textfield =
Gui.element{
    type = 'textfield',
    text = '2',
    numeric = true,
    tooltip = 'Team Count'
}
:style{
  width = 25
}

--- Main gui used to start the game
-- @element main_gui
local main_gui =
Gui.element(function(_,parent)
    target_dropdown(parent)
    team_count_textfield(parent)
end)

--- Used to read the data from the gui
local function gui_callback(parent)
    local args = {}

    local dropdown = parent[target_dropdown.name]
    args[1] = dropdown.selected_index

    local required_laps = parent[team_count_textfield.name].text
    args[2] = required_laps

    return args
end

--- Register the mini game to the mini game module
local Speedrun = Mini_games.new_game('Speedrun')
Speedrun:set_core_events(init, start, stop, close)
Speedrun:set_gui(main_gui, gui_callback)
Speedrun:add_option(2) -- how many options are needed with /start

Speedrun:add_event(Mini_games.events.on_participant_added, on_player_added)
Speedrun:add_event(Mini_games.events.on_participant_joined, on_player_joined)
Speedrun:add_event(Mini_games.events.on_participant_removed, on_player_removed)

Speedrun:add_event(defines.events.on_research_finished, on_research_completed)
Speedrun:add_event(defines.events.on_built_entity, on_entity_placed)
Speedrun:add_event(defines.events.on_robot_built_entity, on_entity_placed)
Speedrun:add_event(defines.events.on_player_crafted_item, on_item_crafted)
Speedrun:add_event(defines.events.on_player_dropped_item, on_item_dropped)
Speedrun:add_event(defines.events.on_rocket_launched, on_rocket_launched)