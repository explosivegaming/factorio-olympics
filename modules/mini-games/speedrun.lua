local Mini_games = require 'expcore.Mini_games'
local Global     = require 'utils.global' --Used to prevent desyncing.
local Gui        = require 'expcore.gui._require'

local targets    = {'Steel Axe', 'Getting on Track', 'Reduced', 'Standard', 'Marathon'}
local primitives = {}
local progress   = {}
local surfaces   = {}
local teams      = {}

Global.register({
    primitives = primitives,
    progress   = progress,
    surfaces   = surfaces,
    teams      = teams
}, function(tbl)
    primitives = tbl.primitives
    progress   = tbl.progress
    surfaces   = tbl.surfaces
    teams      = tbl.teams
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
end

----- Game Init and Start -----

--- First function called by the mini game core to prepare for the start of a game
local function init(args)
    local target = tonumber(args[1])
    if not target or target < 1 or target > #targets then Mini_games.error_in_game('Target index out of range') end
    primitives.target = target

    local team_count = tonumber(args[2])
    if not team_count or team_count < 1 then Mini_games.error_in_game('Team count is invalid') end
    primitives.team_count = team_count

    local seed = math.random(9999999999)
    -- Create a surface for each team with the same seed and settings
    for i = 1, team_count do
        local name = 'SpeedrunTeam'..i
        surfaces[name] = game.create_surface(name, { seed=seed })
        surfaces[name].request_to_generate_chunks({0, 0}, 5)
        progress[name] = 0
        teams[name] = {}
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
        for index, player in ipairs(teams[name]) do names[index] = player.name end
        scores[ctn] = { name, team_progress, names }
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
    local min_name, min_ctn = nil, 0
    for name, players in pairs(teams) do
        if not min_name or min_ctn > #players then
            min_name, min_ctn = name, #players
        end
    end

    teams[min_name][min_ctn+1] = player
end

--- Trigger when a participant is removed from the game
-- Removes the player from the team arrays
local function on_player_removed(event)
    local player_index = event.player_index
    for _, players in pairs(teams) do
        for index, player in ipairs(players) do
            if player.index == player_index then
                local len = #players
                players[index] = players[len]
                players[len] = nil
                return
            end
        end
    end
end

--- Trigger when a participant joins the game
local function on_player_joined(event)
    local player = game.players[event.player_index]

    if Mini_games.get_current_state() == 'Starting' then
        local surface -- Find the correct surface to teleport to
        for name, players in pairs(teams) do
            for index, next_player in ipairs(players) do
                if next_player.name == player.name then
                    surface = surfaces[name]
                end
            end
        end

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