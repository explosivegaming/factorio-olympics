local Mini_games = require "expcore.Mini_games"
local Token             = require "utils.token"
local task              = require "utils.task"
local Permission_Groups = require "expcore.permission_groups"
local Global            = require 'utils.global' --Used to prevent desyncing.
local interface         = require 'modules.commands.interface'
local Gui               = require 'expcore.gui._require'

local surface = {}
local gates = {}
local areas = {}
local player_progress = {}
local cars = {}
local dead_cars = {}
local variables = {}
local scores = {}
local laps = {}
local gate_boxes = {}
local start_players ={}

--- Register a new permission group for players not in cars
Permission_Groups.new_group('out_car')
:disallow_all()
:allow{
    'write_to_console'
}

--- Register a new debug interface to store all local variables
local debug_interface = {}
interface.add_interface_module('Race', debug_interface)

--- Register all global variables
Global.register({
    surface         = surface,
    gates           = gates,
    variables       = variables,
    areas           = areas,
    player_progress = player_progress,
    cars            = cars,
    dead_cars       = dead_cars,
    scores          = scores,
    laps            = laps,
    gate_boxes      = gate_boxes,
    start_players   = start_players
},function(tbl)
    surface         = tbl.surface
    gates           = tbl.gates
    variables       = tbl.variables
    areas           = tbl.areas
    player_progress = tbl.player_progress
    cars            = tbl.cars
    dead_cars       = tbl.dead_cars
    scores          = tbl.scores
    laps            = tbl.laps
    gate_boxes      = tbl.gate_boxes
    start_players   = tbl.start_players
    for k, v in pairs(tbl) do
        debug_interface[k] = v
    end
end)

--- Internal, Used to clear tables of all values
local function reset_table(table)
    for k in pairs(table) do
        table[k] = nil
    end
end

--- Internal, Reset all global tables
local function reset_globals()
    reset_table(surface)
    reset_table(variables)
    reset_table(player_progress)
    reset_table(cars)
    reset_table(dead_cars)
    reset_table(scores)
    reset_table(laps)
    reset_table(start_players)
end

--- Used to print the countdown and to fuel the cars when at 0
local race_count_down
race_count_down = Token.register(function()
    variables["count_down"] = variables["count_down"] - 1
    if variables["count_down"] ~= 0 then
        game.print(variables["count_down"], { 1, 0, 0 })
        task.set_timeout_in_ticks(60, race_count_down)
    else
        game.print("0 --> GO!", { 0, 1, 0 })
        for _, player_name in pairs(start_players) do
            local car = cars[player_name]
            car.get_fuel_inventory().insert{name = variables["fuel"], count = 100}
            scores[player_name].time = game.tick
        end
    end
end)

--- Pick a random player who is not in start_players
local function pick_player()
    local player = game.connected_players[math.random(#game.connected_players)]
    if not start_players[player.name] then
        return player
    else
        return pick_player()
    end
end

--- Get all the script areas, and get the gates in those areas
local function setup_areas()
    -- Get the areas that will trigger gates to open
    if not areas[1] then
        areas[1] = surface[1].get_script_areas("gate_1_box")[1].area
        areas[2] = surface[1].get_script_areas("gate_2_box")[1].area
        areas[3] = surface[1].get_script_areas("gate_3_box")[1].area
        areas[4] = surface[1].get_script_areas("gate_4_box")[1].area
    end

    -- Get the areas where gates are located
    if not gate_boxes[1] then
        gate_boxes[1] = surface[1].get_script_areas("gate_1")[1].area
        gate_boxes[2] = surface[1].get_script_areas("gate_2")[1].area
        gate_boxes[3] = surface[1].get_script_areas("gate_3")[1].area
        gate_boxes[4] = surface[1].get_script_areas("gate_4")[1].area
    end

    -- Cant correct spelling of finsish_line because it is the name of a script area
    variables["finish"] = surface[1].get_script_areas("finsish_line")[1].area

    -- Get all gates in the gate areas
    if not gates[1] then
        gates[1] = surface[1].find_entities_filtered{ area = gate_boxes[1], name = "gate" }
        gates[2] = surface[1].find_entities_filtered{ area = gate_boxes[2], name = "gate" }
        gates[3] = surface[1].find_entities_filtered{ area = gate_boxes[3], name = "gate" }
        gates[4] = surface[1].find_entities_filtered{ area = gate_boxes[4], name = "gate" }
    end
end

--- Function called by mini game module to start a race
local function start(args)
    surface[1] = game.surfaces["Race game"]
    variables["done_left"]  = 0
    variables["count_down"] = 4
    variables["done_right"] = 0
    variables["left"]       = true
    variables["fuel"]       = args[1]
    variables["laps"]       = tonumber(args[2])
    variables["player"]     = tonumber(args[3])
    variables["place"]      = 1
    variables["new_joins"]  = 0
    scores["finish_times"]  = {}

    -- Error if no lap count was given
    if not variables["laps"] then
        return Mini_games.error_in_game("No lap count given")
    end

    -- Error if an invalid fuel was given
    local prototype = game.item_prototypes[variables["fuel"]]
    if not prototype or not prototype.fuel_category then
        return Mini_games.error_in_game("No fuel with that name")
    end

    -- Check if all players should be selected
    local pick_all = false
    if variables["player"] >= #game.connected_players then
        variables["player"] =  #game.connected_players
        pick_all = true
    end

    -- Loop over as many players that are required
    for i = 1, variables["player"] do
        local player
        if pick_all then
            player = game.connected_players[i]
        else
            player = pick_player()
        end

        local name = player.name
        start_players[name] = name

        local pos
        if variables["left"] then
            pos = {-85, -126 + variables["done_left"] * 5}
            variables["done_left"] = variables["done_left"] + 1
            variables["left"] = false
        else
            pos = {-75, -126 + variables["done_right"] * 5}
            variables["done_right"] = variables["done_right"] + 1
            variables["left"] = true
        end

        local car = surface[1].create_entity{
            name = "car",
            position = pos,
            force = "player",
            direction = defines.direction.north
        }

        cars[name] = car
        scores[name] = {}
        car.operable = false
        car.set_driver(player)
        player_progress[name] = 1

    end

    -- Put all non racing players into spectator
    for i, player in ipairs(game.connected_players) do
        if not start_players[player.name] then
            player.character.destroy()
            variables["new_joins"] = variables["new_joins"] + 1
        end
    end

    -- Start the race
    local colour = { 57, 255, 20 }
    game.print("Race started!", colour)
    game.print("Racing in a car with "..variables["fuel"], colour)
    game.print("Laps: "..variables["laps"], colour)
    task.set_timeout_in_ticks(10, race_count_down)
    setup_areas()

end

--- Get the english suffix that follows a position number
--@author https://rosettacode.org/wiki/N%27th#Lua
local function getSuffix (n)
    local lastTwo, lastOne = n % 100, n % 10
    if lastTwo > 3 and lastTwo < 21 then return "th" end
    if lastOne == 1 then return "st" end
    if lastOne == 2 then return "nd" end
    if lastOne == 3 then return "rd" end
    return "th"
end

--- Get the position number with the suffix appended
local function Nth (n) return n..getSuffix(n) end

--- Colours used while printing positions in chat
local message_format = '%s: %s with %s seconds.'
local colors =  {
    ["1st"] = { 255, 215, 0   },
    ["2nd"] = { 192, 192, 192 },
    ["3rd"] = { 205, 127, 50  },
    default = { 128, 128, 128 }
}

--- Function called by mini game module to stop a race
local function stop()
    -- Remove all cars that were created
    for i, car in pairs(cars) do
        car.destroy()
    end

    -- Give all players a character if it was removed
    for i, player in ipairs(game.connected_players) do
        if not player.character then
            player.create_character()
        end
    end

    -- Print the place that each player came
    local airtable = {}
    for name, value in pairs(scores["finish_times"]) do
        local time = value[2]
        local place = Nth(value[1])
        local colour = colors[place] or colors.default
        if colour ~= colors.default then
            airtable[value[1] + (value[1]-1)] = name
            airtable[value[1] * 2] = math.round(time,2)
        end
        game.print(message_format:format(place, name, time), colour)
    end
    reset_globals()

    return Mini_games.update_airtable(airtable)
end

--- AABB logic for if a position is in a box
local function insideBox(box, pos)
    local x1 = box.left_top.x
    local y1 = box.left_top.y
    local x2 = box.right_bottom.x
    local y2 = box.right_bottom.y

    local px = pos.x
    local py = pos.y
    return px >= x1 and px <= x2 and py >= y1 and py <= y2
end

--- Triggered every time a player moves, used to open gates and check lap counts
local lap_format = '%s has completed a lap in %.4f seconds. Lap %d out of %d.'
local finish_format = '%s has completed all laps in %.4f seconds placing them %s.'
local function player_move(event)
    local player = game.players[event.player_index]
    if not start_players[player.name] then return end

    -- Increase progress by one and open gates
    local name = player.name
    local pos = player.position
    local progress = player_progress[name]
    for i, box in ipairs(areas) do
        if insideBox(box, pos) then
            if progress == i or progress - 1 == i then
                for _, gate in ipairs(gates[i]) do
                    gate.request_to_open(gate.force, 100)
                end
                if progress == i then
                    player_progress[name] = progress + 1
                end
                return
            end
        end
    end

    -- If the players progress wasnt increased, check if the player cheated
    if insideBox(gate_boxes[4], pos) then
        if progress < 5 then
            local car = cars[name]
            if car and car.valid then
                car.teleport{276,-406}
                car.orientation = 0.25
            else
                dead_cars[name].position = {276,-406}
                dead_cars[name].orientation = 0.25
            end
            player_progress[name] = 1
            player.print("[font=default-bold]YOU CAN'T TAKE A SHORTCUT, CHEATER![/font]")
            return
        end
    end

    -- If the players progress wasnt increased and they didnt cheat, check if they finished
    if insideBox(variables["finish"], pos) then
        if player_progress[name] == 5 then
            player_progress[name] = 1

            -- Add one to the players lap counter
            if laps[name] then
                laps[name] = laps[name] + 1
            else
                laps[name] = 1
            end

            -- Print the time taken to do the lap
            local lap_time = (game.tick - scores[name].time)/60
            game.print(lap_format:format(name, lap_time, laps[name], variables["laps"]))
            scores[name].time = game.tick

            -- Add the lap to the total
            if scores[name].total_time then
                scores[name].total_time = math.round(scores[name].total_time + lap_time, 4)
            else
                scores[name].total_time = math.round(lap_time, 4)
            end

            -- Check if a player has completed all laps
            if laps[name] >= variables["laps"] then
                cars[name].destroy()
                cars[name] = nil
                if player.character then
                    player.character.destroy()
                end

                -- Print and update finish times
                game.print(finish_format:format(name, scores[name].total_time, Nth(variables["place"])))
                scores["finish_times"][name] = { variables["place"], scores[name].total_time }
                variables["place"] = variables["place"] + 1

                -- If all players have finished then end the game
                if variables["place"] > #game.connected_players - variables["new_joins"] then
                    Mini_games.stop_game()
                end
            end
        end
    end
end

--- Make the car indestructible and cause all biters to flee
local function start_invincibility(car,name)
    car.destructible = false
    local biters = surface[1].find_enemy_units(dead_cars[name].position, 50, "player")
    for i, biter in ipairs(biters) do
        biter.set_command{ type = defines.command.flee, distraction = defines.distraction.by_anything, from = car }
    end
end

--- Make the car and player destructible again
local stop_invincibility = Token.register(function(name)
    dead_cars[name].car.destructible = true
    local player = dead_cars[name].player
    player.character.destructible = true
end)

--- Kill all biters in a close range to the player
local kill_biters = Token.register(function(name)
    local biters = surface[1].find_enemy_units(dead_cars[name].position, 3, "player")
    for i, biter in ipairs(biters) do
        biter.destroy()
    end
end)

--- Respawn the car for a player
local respawn_car
respawn_car = Token.register(function(name)
    local player = dead_cars[name].player
    local position = surface[1].find_non_colliding_position('car', dead_cars[name].position, 5, 0.5)
    if not position then
        return task.set_timeout_in_ticks(30, respawn_car, name)
    end

    local car = surface[1].create_entity {
        name = "car",
        direction = defines.direction.north,
        position = position,
        force = "player"
    }

    car.operable = false
    car.set_driver(player)
    car.orientation = dead_cars[name].orientation
    car.get_fuel_inventory().insert{ name = variables["fuel"], count = 100 }
    cars[name] = car

    Permission_Groups.set_player_group(player, dead_cars[name].group)
    start_invincibility(car, name)

    dead_cars[name].car = car
end)

--- Triggered when an entity is destroyed, used to respawn the car
local car_destroyed = function(event)
    local dead_car = event.entity
    if dead_car.name ~= "car" then return end

    -- Get the data for the car
    local player = dead_car.get_driver().player
    local name = player.name
    local dead_car_data = dead_cars[name]
    if not dead_car_data then
        dead_car_data = {}
        dead_cars[name] = dead_car_data
    end

    -- Update the data for the car
    dead_car_data.player = player
    dead_car_data.position = dead_car.position
    dead_car_data.orientation = dead_car.orientation
    dead_car_data.group = Permission_Groups.get_group_from_player(player).name

    -- Make player invincible for a short time, then respawn the car
    local offset = math.random(-30, 30)
    player.character.destructible = false
    Permission_Groups.set_player_group(player, "out_car")
    task.set_timeout_in_ticks(180+offset, respawn_car, name)
    task.set_timeout_in_ticks(190+offset, kill_biters, name)
    task.set_timeout_in_ticks(480+offset, stop_invincibility, name)

end

--- Triggered when a player enters or leaves a car, used to keep them in the car
local function back_in_car(event)
    local player = game.players[event.player_index]
    if not player.vehicle then
        local car = cars[player.name]
        if car then
            car.set_driver(player)
        end
    end
end

--- Triggered when a player joins the game, used to move the player to spectator
local function player_join(event)
    local player = game.players[event.player_index]
    player.teleport({-85, -126},"Race game")
    player.character.destroy()
    variables["new_joins"] = variables["new_joins"] + 1
end

--- Triggered when a player leaves the game, clears player data and moves them to nauvis
local function on_player_left_game(event)
    local player = game.players[event.player_index]

    -- Clear any stored data
    if not start_players[player.name] then
        variables["new_joins"] = variables["new_joins"] - 1
    else
        local name = player.name
        start_players[name] = nil
        scores[name] = nil
        player_progress[name] = nil
        player.character.destructible = true
    end

    -- Remake their character and teleport them
    if not player.character then
        player.create_character()
    end
    player.teleport({-35,55}, "nauvis")

    -- Destroy their car
    if cars[player.name] then
        cars[player.name].destroy()
    end

end

--- Used to select what type of fuel to use
-- @element fuel_dropdown
local fuel_dropdown =
Gui.element{
    type = 'drop-down',
    items = {"nuclear-fuel","wood","coal","solid-fuel","rocket-fuel"},
    selected_index = 1
}

--- Used to select the number of laps to complete
-- @element text_field_for_laps
local text_field_for_laps =
Gui.element{
    type = 'textfield',
    text = '1',
    numeric = true,
}
:style{
  width = 25
}

--- Used to select the number of players to compete
-- @element text_field_for_players
local text_field_for_players =
Gui.element{
    type = 'textfield',
    text = '1',
    numeric = true,
}
:style{
  width = 25
}

--- Main gui used to start the game
-- @element main_gui
local main_gui =
Gui.element(function(_,parent)
    local main_flow = parent.add{ type = 'flow', name = "Race_flow"}
    fuel_dropdown(main_flow)
    text_field_for_laps(main_flow)
    text_field_for_players(main_flow)
end)

--- Used to read the data from the gui
local function gui_callback(parent)
    local flow = parent["Race_flow"]
    local args = {}

    local dropdown = flow[fuel_dropdown.name]
    local fuel = dropdown.get_item(dropdown.selected_index)
    args[1] = fuel

    local required_laps = flow[text_field_for_laps.name].text
    args[2] = required_laps

    local players = flow[text_field_for_players.name].text
    args[3] = players

    return args
end

--- Register the mini game to the mini game module
local race = Mini_games.new_game("Race_game")
race:add_map("Race game", -80, -140)
race:set_start_function(start)
race:set_stop_function(stop)
race:add_option(3) -- how many options are needed with /start

race:add_event(defines.events.on_player_changed_position, player_move)
race:add_event(defines.events.on_entity_died, car_destroyed)
race:add_event(defines.events.on_player_driving_changed_state, back_in_car)
race:add_event(defines.events.on_player_joined_game, player_join)
race:add_event(defines.events.on_pre_player_left_game, on_player_left_game)

race:set_gui_element(main_gui)
race:set_gui_callback(gui_callback)