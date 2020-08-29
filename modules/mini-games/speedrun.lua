local Mini_games   = require 'expcore.Mini_games'
local Global       = require 'utils.global'
local Gui          = require 'expcore.gui._require'
local Token        = require 'utils.token'
local Task         = require 'utils.task'
local TeamSelector = require 'modules.gui.mini_game_team_selector'

local targets    = {}
local lookups    = {}
local primitives = {}
local progress   = {}
local surfaces   = {}
local forces     = {}
local scores     = {}

local goals = require 'config.mini_games.speedrun'
for index, goal in ipairs(goals) do
    local lookup = {}
    lookups[index] = lookup
    targets[index] = goal.name

    local ctn = 0

    lookup.rockets = goal.rockets and goal.rockets > 0
    if goal.rockets then ctn = ctn + goal.rockets end

    lookup.satellites = goal.satellites and goal.satellites > 0
    if goal.satellites then ctn = ctn + goal.satellites end

    for _, key in ipairs{'research', 'items', 'entities'} do
        local value = goal[key]
        if value then
            ctn = ctn + #value
            lookup[key] = true
            for _, name in ipairs(value) do lookup[key..'/'..name] = true end
        end
    end

    goal.total = ctn
end

Global.register({
    primitives = primitives,
    progress   = progress,
    surfaces   = surfaces,
    forces     = forces,
    scores     = scores
}, function(tbl)
    primitives = tbl.primitives
    progress   = tbl.progress
    surfaces   = tbl.surfaces
    forces     = tbl.forces
    scores     = tbl.scores
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
    reset_table(forces)
    reset_table(scores)
end

----- Map Gen -----

local function ready_condition()
    local ctn = 0
    for _ in pairs(surfaces) do ctn = ctn + 1 end
    return ctn == primitives.team_count
end

local surface_generator = Token.register(function(remaining)
    local last = #remaining
    local next_surface = remaining[last]
    if not next_surface then return false end
    remaining[last] = nil

    local surface = game.create_surface(next_surface, { seed=remaining.seed })
    surface.request_to_generate_chunks({0, 0}, 5)
    surfaces[next_surface] = surface

    return true
end)

----- Game Init and Start -----

--- First function called by the mini game core to prepare for the start of a game
local team_entry, timer_container
local function init(args)
    local target = tonumber(args[1])
    if not target or target < 1 or target > #targets then Mini_games.error_in_game('Target index out of range') end
    primitives.target = target
    primitives.lookup = lookups[target]

    local team_count = tonumber(args[2])
    if not team_count or team_count < 1 then Mini_games.error_in_game('Team count is invalid') end
    primitives.team_count = team_count

    local map_seed = tonumber(args[3])
    if type(args[3]) == 'string' and args[3]:lower() == 'random' then
        map_seed = math.random(4294967295)
    end
    if not map_seed or map_seed < 0 or map_seed > 4294967295 then Mini_games.error_in_game('Map seed is invalid') end

    -- Create a surface for each team with the same seed and settings
    local remaining, indicators = { seed = map_seed }, goals[target]
    for i = 1, team_count do
        local name = 'Team '..i
        remaining[i] = name
        forces[name] = game.create_force(name)
        progress[name] = { 0, indicators.total, table.deep_copy(indicators) }
    end

    Task.queue_task(surface_generator, remaining, team_count)
end

--- Called once enough participants are present to start the game and map generation is done
local function start()
    -- Chart the start area for all teams
    local removed = {}
    for name, force in pairs(forces) do
        if #force.players > 0 then
            force.share_chart = true
            force.chart(surfaces[name], {{x = 80, y = 80}, {x = -80, y = -80}})
        else
            primitives.team_count = primitives.team_count - 1
            game.merge_forces(force, game.forces.player)
            game.delete_surface(surfaces[name])
            removed[name] = true
        end
    end

    -- Remove references to invalid forces
    for name in pairs(removed) do
        progress[name] = nil
        surfaces[name] = nil
        forces[name] = nil
    end

    -- Added all the teams to the progress table
    local tooltip = goals[primitives.target].goal
    for _, player in pairs(game.players) do
        Gui.toggle_left_element(player, timer_container, true)
        local container = Gui.get_left_element(player, timer_container)
        local progress_table = container.progress_table
        container.timer.tooltip = tooltip
        for name in pairs(forces) do team_entry(progress_table, name) end
    end
end

----- Game Stop and Close -----

local result_time_options = { hours = true, minutes = true, seconds = true, long = true, string = true }
--- Called to stop the game and return the results to be saved
local function stop()

    -- Format the results table
    local results, names = {}, {}
    for _, team in ipairs(scores) do
        local score = team[2]
        local last = #results
        local up_result = results[last]
        if up_result and up_result.score == score then
            names[last] = names[last]..', '..team[1]
            local players = up_result.players
            local offset = #players
            for index, player in ipairs(team[3]) do
                players[offset+index] = player
            end
        else
            names[last+1] = team[1]
            results[last+1] = { place = last+1, score = score, players = team[3] }
        end
    end

    Mini_games.print_results(results, { time_seconds = result_time_options, names = names })
    return results
end

--- Final function called by the mini game core in order to clean up
local function close()
    -- Remove the surfaces
    for _, surface in pairs(surfaces) do
        game.delete_surface(surface)
    end

    -- Remove the forces
    for _, force in pairs(forces) do
        game.merge_forces(force, game.forces.player)
    end

    -- Clear and hide the gui for all players
    for _, player in pairs(game.players) do
        Gui.toggle_left_element(player, timer_container, false)
        local container = Gui.get_left_element(player, timer_container)
        container.progress_table.clear()
    end

    reset_globals()
end

----- Player Events -----

--- Move spectator to the start line when joining in
local function on_spectator_spawned(event)
    local player = game.players[event.player_index]
    local _, surface = next(surfaces)
    if surface then
        player.teleport({0,0}, surface)
    end
end

--- Trigger when a participant is removed from the game
-- Removes the player from the team arrays
local function on_player_removed(event)
    local player = game.players[event.player_index]
    player.force = game.forces.player
end

--- Trigger when a participant joins the game
local function on_player_created(event)
    local player = game.players[event.player_index]
    local surface = surfaces[player.force.name]

    -- Teleport the player to the new surface
    if player.character then player.character.destroy() end
    local pos = surface.find_non_colliding_position('character', {0, 0}, 50, 1)
    local character = surface.create_entity{ name = 'character', position = pos, force = player.force }
    player.teleport(pos, surface)
    player.character = character

    -- Give the starting starting items
    for _, item in pairs(starting_items) do
        player.insert(item)
    end
end

----- Events -----

--- Used to update guis and end the game
local function update_progress(force, data)
    local name = force.name
    local bar_name, bar_value = 'bar-'..name, data[1]/data[2]
    local bar_tooltip = {'', 'Last Completed: ', data[4] or 'None'}
    local label_name, label_value = 'label-'..name, math.floor(bar_value*100)..'%'
    local label_tooltip = 'Progress: '..data[1]..' / '..data[2]

    -- Update the progress gui for all players
    for _, player in pairs(game.players) do
        local container = Gui.get_left_element(player, timer_container)
        local progress_table = container.progress_table
        progress_table[bar_name].value = bar_value
        progress_table[bar_name].tooltip = bar_tooltip
        progress_table[label_name].caption = label_value
        progress_table[label_name].tooltip = label_tooltip
    end

    -- Check if the team has finished
    if data[1] == data[2] then
        local names, last = {}, #scores + 1
        local time = math.floor((game.tick - Mini_games.get_start_time())/60)
        for index, player in ipairs(forces[name].players) do
            Mini_games.remove_participant(player)
            names[index] = player.name
        end
        scores[last] = { name, time, names }
        -- Check if all teams are done
        if last == primitives.team_count then Mini_games.stop_game() end
    end
end

--- Checks if an indicator has already been used
local function check_indicator(force, key, clean, locale, value)
    local data = progress[force.name]
    local indicators = data[3][key]
    for index, next_value in ipairs(indicators) do
        if next_value == value then
            local last = #indicators
            indicators[index] = indicators[last]
            indicators[last] = nil
            data[1] = data[1] + 1
            data[4] = {'', clean, locale}
            return update_progress(force, data)
        end
    end
end

--- Triggered when a research is completed
local function on_research_completed(event)
    local research = event.research
    if not primitives.lookup['research/'..research.name] then return end

    local force = event.research.force
    check_indicator(force, 'research', 'Research - ', research.localised_name, research.name)
end

--- Triggered when an entity is placed
local function on_entity_placed(event)
    local entity = event.created_entity
    if not primitives.lookup['entities/'..entity.name] then return end

    local force = event.created_entity.force
    check_indicator(force, 'entities', 'Entity - ', entity.localised_name, entity.name)
end

--- Triggered when an item is crafted
local function on_item_crafted(event)
    local item = event.item_stack.prototype
    if not primitives.lookup['items/'..item.name] then return end

    local force = game.players[event.player_index].force
    check_indicator(force, 'items', 'Item - ', item.localised_name, item.name)
end

--- Triggered when a rocket is launched
local function on_rocket_launched(event)
    local force = event.rocket_silo.force
    local data = progress[force.name]

    local rockets = data[3].rockets
    if rockets and rockets > 0 then
        data[3].rockets = rockets - 1
        data[1] = data[1] + 1
        data[4] = {'', 'Space - ', {'entity-name.rocket'}}
        update_progress(force, data)
    end

    local satellites = data[3].satellites
    if satellites and satellites > 0 then
        local rocket = event.rocket
        if not rocket or not rocket.valid then return end
        local inventory = rocket.get_inventory(defines.inventory.rocket)
        local count = inventory.get_item_count('satellite')
        if count == 0 then return end
        if count > satellites then count = satellites end
        data[3].satellites = satellites - count
        data[1] = data[1] + count
        data[4] = {'', 'Space - ', {'item-name.satellite'}}
        update_progress(force, data)
    end

end

--- Used to check the item productions for each team
local function check_item_production()
    if not primitives.lookup['items'] then return end

    local prototypes = game.item_prototypes
    for _, force in pairs(forces) do
        local found = {}
        local data  = progress[force.name]
        local items = data[3].items
        local get_production = force.item_production_statistics.get_input_count
        -- Find if any required items have been crafted
        for index, item in ipairs(items) do
            if get_production(item) > 0 then
                data[1] = data[1] + 1
                data[4] = {'', 'Item - ', prototypes[item].localised_name}
                found[#found+1] = index
            end
        end
        -- Remove items from the list once they have been made
        if #found > 0 then
            local last_index = #items + 1
            for offset, index in ipairs(found) do
                local last = last_index - offset
                items[index] = items[last]
                items[last] = nil
            end
            update_progress(force, data)
        end
    end

end

--- Ran every tick to update the timer
local format_time = _C.format_time
local timer_options = { hours = true, minutes = true, seconds = true, milliseconds = true, time = true, div = 'time-format.simple-format-div-space' }
local function on_tick()
    local time = game.tick - Mini_games.get_start_time()
    local format = format_time(time, timer_options)
    for _, player in ipairs(game.connected_players) do
        local container = Gui.get_left_element(player, timer_container)
        container.timer.caption = format
    end
end

----- Gui Elements -----

--- Adds a team to the progress table
-- @element team_entry
team_entry =
Gui.element(function(event_trigger, parent, team_name)
    local data = progress[team_name]

    -- Flow to contain the label
    local flow = parent.add{
        type = 'flow',
        name = 'name-'..team_name,
        caption = team_name
    }

    -- Get the player names
    local names = {}
    for index, player in ipairs(forces[team_name].players) do names[index] = player.name end

    -- Add the team name label
    flow.add{
        type = 'label',
        name = event_trigger,
        caption = team_name,
        tooltip = table.concat(names, ',\n'),
        style = 'caption_label'
    }

    -- Add the progress bar
    parent.add{
        type = 'progressbar',
        name = 'bar-'..team_name,
        tooltip = 'Last Completed: None',
        value = data[1]/data[2],
    }.style.horizontally_stretchable = true

    -- Add the progress caption
    parent.add{
        type = 'label',
        name = 'label-'..team_name,
        caption = math.floor(data[1]/data[2]*100),
        tooltip = 'Progress: '..data[1]..' / '..data[2],
        style = 'caption_label'
    }

end)
:on_click(function(player, element)
    --if Mini_games.is_participant(player) then return end
    local surface = surfaces[element.parent.caption]
    player.teleport({0,0}, surface)
end)

--- Main container for the timer
-- @element timer_container
timer_container =
Gui.element(function(event_trigger, parent)
    -- Draw the main container
    local container = parent.add{
        type = 'frame',
        style = 'blurry_frame',
        name = event_trigger,
        direction = 'vertical'
    }

    -- Draw the main time label
    local label_style = container.add{
        type = 'label',
        name = 'timer',
        caption = '00 : 00 : 00.000',
        style = 'heading_1_label'
    }.style

    -- Center the label
    label_style.horizontal_align = 'center'
    label_style.width = 200

    -- Add a dividing bar
    Gui.bar(container, 200)

    -- Draw the progress table
    local progress_table = container.add{
        type = 'table',
        name = 'progress_table',
        column_count = 3
    }

    -- Set the style of the table
    local table_Style = progress_table.style
    table_Style.padding = {5,0,0,0}
    table_Style.cell_padding = 0
    table_Style.vertical_align = 'center'
    table_Style.horizontally_stretchable = true

    -- Add the teams if the game has started
    if Mini_games.get_current_state() == 'Stared' then
        for name in pairs(forces) do team_entry(progress_table, name) end
    end

    -- Return the main container
    return container
end)
:add_to_left_flow()

--- Button on the top flow used to toggle the player list container
-- @element toggle_left_element
Gui.left_toolbar_button('utility/clock', 'Speed Run Timer', timer_container, function()
    return Mini_games.get_running_game() == 'Speedrun'
end)

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

--- Used to select the seed for this game
-- @element map_seed_textfield
local map_seed_textfield =
Gui.element{
    type = 'textfield',
    text = '',
    numeric = true,
    tooltip = 'Map Seed - Blank for random'
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
    map_seed_textfield(parent)
end)

--- Used to read the data from the gui
local function gui_callback(parent)
    local args = {}

    local dropdown = parent[target_dropdown.name]
    args[1] = dropdown.selected_index

    local required_laps = parent[team_count_textfield.name].text
    args[2] = required_laps

    local map_seed = parent[map_seed_textfield.name].text
    if map_seed == '' then map_seed = math.random(4294967295) end
    args[3] = map_seed

    return args
end

--- Register the mini game to the mini game module
local Speedrun = Mini_games.new_game('Speedrun')
Speedrun:set_core_events(init, start, stop, close)
Speedrun:set_ready_condition(ready_condition)
Speedrun:set_participant_selector(TeamSelector.selector(function() return forces end), true)
Speedrun:set_gui(main_gui, gui_callback)
Speedrun:add_option(3) -- how many options are needed with /start

Speedrun:add_event(Mini_games.events.on_spectator_spawned, on_spectator_spawned)
Speedrun:add_event(Mini_games.events.on_participant_created, on_player_created)
Speedrun:add_event(Mini_games.events.on_participant_removed, on_player_removed)

Speedrun:add_event(defines.events.on_research_finished, on_research_completed)
Speedrun:add_event(defines.events.on_built_entity, on_entity_placed)
Speedrun:add_event(defines.events.on_robot_built_entity, on_entity_placed)
Speedrun:add_event(defines.events.on_player_crafted_item, on_item_crafted)
Speedrun:add_event(defines.events.on_rocket_launched, on_rocket_launched)
Speedrun:add_event(defines.events.on_tick, on_tick)
Speedrun:add_nth_tick(60, check_item_production)