local Mini_games        = require "expcore.Mini_games"
local Token             = require "utils.token"
local task              = require "utils.task"
local Permission_Groups = require "expcore.permission_groups"
local Global            = require 'utils.global' --Used to prevent desynicing.
local interface         = require 'modules.commands.interface'
local surface = {}
local gates = {}
local areas = {}
local player_progress = {}
local cars = {}
local variables = {}
local race = Mini_games.new_game("Race_game")
local token_for_car
local scores = {}
local laps = {}
local gate_boxes = {}
local start_players ={}

local function setup_areas()
    if not areas[1] then
        areas[1] = surface[1].get_script_areas("gate_1_box")[1].area
        areas[2] = surface[1].get_script_areas("gate_2_box")[1].area
        areas[3] = surface[1].get_script_areas("gate_3_box")[1].area
        areas[4] = surface[1].get_script_areas("gate_4_box")[1].area
    end
    if not gate_boxes[1] then
        gate_boxes[1] = surface[1].get_script_areas("gate_1")[1].area
        gate_boxes[2] = surface[1].get_script_areas("gate_2")[1].area
        gate_boxes[3] = surface[1].get_script_areas("gate_3")[1].area
        gate_boxes[4] = surface[1].get_script_areas("gate_4")[1].area
    end

    variables["finsih"] = surface[1].get_script_areas("finsish_line")[1].area

    --gate
    if not gates[1] then
        gates[1] = surface[1].find_entities_filtered {area = gate_boxes[1], name = "gate"}
        gates[2] = surface[1].find_entities_filtered {area = gate_boxes[2], name = "gate"}
        gates[3] = surface[1].find_entities_filtered {area = gate_boxes[3], name = "gate"}
        gates[4] = surface[1].find_entities_filtered {area = gate_boxes[4], name = "gate"}
    end
end


Permission_Groups.new_group('out_car')
:disallow_all()
:allow{
    'write_to_console'
}


Global.register({
    surface = surface, --y
    gates = gates, --y
    variables = variables, --y
    areas = areas, --y
    player_progress = player_progress, --y
    cars = cars, --y
    scores = scores, --y
    laps = laps, --y 
    gate_boxes = gate_boxes, --y
    start_players = start_players --y
},function(tbl)
    surface = tbl.surface
    gates = tbl.gates
    variables = tbl.variables
    areas = tbl.areas
    player_progress = tbl.player_progress
    cars = tbl.cars
    scores = tbl.scores
    laps = tbl.laps
    gate_boxes = tbl.gate_boxes
    start_players = tbl.start_players
    
end)

local function reset_table(table)
    for i, value in pairs(table) do
        table[i] = nil
    end
end

local function resetall()
    reset_table(surface)
    reset_table(variables)
    reset_table(player_progress)
    reset_table(cars)
    reset_table(scores)
    reset_table(laps)
    reset_table(start_players)
end
local token_for_start 

local function race_count_down()
    
    variables["count_down"]  = variables["count_down"]  -1
    if  variables["count_down"] ~= 0 then
        game.print("[color=red]"..variables["count_down"].."[/color]")
    end
    if variables["count_down"] == 0 then
        game.print("[color=green]0 --> GO![/color]")
        for i,player_name in pairs(start_players) do
            local car = cars[player_name]
            car.get_fuel_inventory().insert({name = variables["fuel"], count = 100})   
            scores[player_name].time = game.tick
        end
    else
        task.set_timeout_in_ticks(60, token_for_start)
    end
end
token_for_start = Token.register(race_count_down)

local function pick_player()
    local player = game.connected_players[math.random(#game.connected_players)]
    if not start_players[player.name] then
        return player
    else 
        return  pick_player()
    end
end


local start = function(args)
    

    surface[1] = game.surfaces["Race game"]
    variables["done_left"] = 0
    variables["count_down"] = 4
    variables["done_right"] = 0
    variables["left"] = true
    variables["error_game"] = nil
    variables["fuel"] = args[1]
    variables["laps"] = tonumber(args[2])
    variables["player"] = tonumber(args[3])
    variables["place"] = 1
    variables["new_joins"] = 0
    scores["finshed_times"] = {}
    if not variables["laps"] then 
        variables["error_game"] = "No laps set"
    end
    if not game.item_prototypes[variables["fuel"]] then
        variables["error_game"] = "wrong fuel"
    end
    local pick_all = false
    if variables["player"] >= #game.connected_players then
        pick_all = true
        variables["player"] =  #game.connected_players
    end
    --for i, player in ipairs(game.connected_players) do
    for i=1,variables["player"] do
        local player 
        if pick_all then
            player = game.connected_players[i]
        else
            player = pick_player()
        end
        start_players[player.name] = player.name 
        local pos
        if (variables["left"]) then
            pos = {-85, -126 + variables["done_left"] * 5}
            variables["done_left"] = variables["done_left"] + 1
            variables["left"] = false
        else
            pos = {-75, -126 + variables["done_right"] * 5}
            variables["done_right"] = variables["done_right"] + 1
            variables["left"] = true
        end
        local car =
            surface[1].create_entity {
            name = "car",
            direction = defines.direction.north,
            position = pos,
            force = "player"
        }
        if not variables["error_game"] then
            car.set_driver(game.players[player.name])
            --car.get_fuel_inventory().insert({name = variables["fuel"], count = 100})
        end

        cars[player.name] = car
        local name = player.name
        scores[name] = {}
        player_progress[name] = 1

    end

    for i, player in ipairs(game.connected_players) do
        if not  start_players[player.name]  then
            local player = game.players[player.name]
            player.character.destroy()
            variables["new_joins"] = variables["new_joins"] + 1   
        end
    end
    local laps = variables["laps"]
    game.print("[color=#39ff14]Race started![/color]")
    game.print("[color=#39ff14]Racing in a car with "..variables["fuel"]..".[/color]")
    game.print("[color=#39ff14]Laps: "..laps..".[/color]")
    task.set_timeout_in_ticks(10, token_for_start)
    setup_areas()



    if variables["error_game"] then
        Mini_games.error_in_game(variables["error_game"])
    end


    
end
--@author https://rosettacode.org/wiki/N%27th#Lua
local function getSuffix (n)
    local lastTwo, lastOne = n % 100, n % 10
    if lastTwo > 3 and lastTwo < 21 then return "th" end
    if lastOne == 1 then return "st" end
    if lastOne == 2 then return "nd" end
    if lastOne == 3 then return "rd" end
    return "th"
end
 
local function Nth (n) return n..getSuffix(n) end

--@author tovernaar123
local stop = function()
    for i, car in pairs(cars) do
        car.destroy()
    end
    for i,player in ipairs(game.connected_players) do
        if not player.character then
            player.create_character()
        end 
    end
    local colors =  {
        ["1st"] = "[color=#FFD700]",
        ["2nd"] = "[color=#C0C0C0]",
        ["3rd"] = "[color=#cd7f32]"
    }
    for i, value in pairs(scores["finshed_times"]) do
        local place = value[1]
        local time = value[2]
        local place = Nth(place)
        if colors[place] then
            game.print(colors[place]..place..": "..i.." with "..time.." seconds.[/color]")
        else
            game.print("[color=#808080]"..place..": "..i.." with "..time.." seconds.[/color]")
        end
    end
    resetall()
end

local function insideBox(box, pos)
    local x1 = box.left_top.x
    local y1 = box.left_top.y
    local x2 = box.right_bottom.x
    local y2 = box.right_bottom.y

    local px = pos.x
    local py = pos.y
    return px >= x1 and px <= x2 and py >= y1 and py <= y2
end

local player_move = function(event)
    local player = game.players[event.player_index]
    if start_players[player.name] then
        local pos = player.position
        local name = player.name
        local found_match = false
        for i, box in ipairs(areas) do
            if insideBox(box, pos) then
                local progress = player_progress[name]
                if i ~= 5 then
                    if progress == i or progress - 1 == i then
                        found_match = true
                        for i, gate in ipairs(gates[i]) do
                            gate.request_to_open(gate.force, 100)
                        end
                        if progress == i and progress ~= 5 then
                            player_progress[name] = player_progress[name] + 1
                        end
                    end
                end
            end
            if not found_match then
                if insideBox(gate_boxes[4], pos) then
                    if player_progress[name] < 5 then 
                        local car = cars[name]
                        if car then
                            if car.valid then
                                car.teleport({276,-406})
                                car.orientation = 0.25
                                player_progress[name] = 1
                                player.print("[font=default-bold]YOU CAN'T TAKE A SHURTCUT, CHEATER![/font]")
                            end
                        else
                            variables["Dead_car"][name].position = {276,-406}
                            variables["Dead_car"][name].orientation = 0.25
                            player.print("[font=default-bold]YOU CAN'T TAKE A SHURTCUT, CHEATER![/font]")
                        end
                    end
                end
            end
        end
        if not found_match then
            if insideBox(variables["finsih"], pos) then
                if player_progress[name] then 
                    if player_progress[name] == 5 then
                        player_progress[name] = 1
                        if laps[name] then
                            laps[name] = laps[name] + 1
                        else
                            laps[name] = 1 
                        end
                        local finsihed = false
                        if laps[name] >= variables["laps"] then 
                            cars[name].destroy()
                            cars[name] = nil
                            if player.character then
                                player.character.destroy()
                            end
                            finsihed = true
                            local time = tostring(math.round((game.tick - scores[name].time)/60,4))
                            game.print(name.." Has lapped in: "..time.." seconds. Lap "..laps[name].."/"..variables["laps"]..".")
                            if  scores[name].totale_time then
                                scores[name].totale_time = math.round(scores[name].totale_time + (game.tick - scores[name].time)/60,4)
                            else
                                scores[name].totale_time = math.round((game.tick - scores[name].time)/60,4)
                            end
                            game.print(name.." Has finshed "..variables["laps"].." laps in "..scores[name].totale_time.." seconds".." placing them "..Nth(variables["place"])..".")
                            scores["finshed_times"][name] = {variables["place"],scores[name].totale_time}
                            variables["place"] = variables["place"] + 1
                            if scores["finshed"] then
                                scores["finshed"] =  scores["finshed"] + 1
                            else
                                scores["finshed"] = 1
                            end
                            if scores["finshed"] >= #game.connected_players - variables["new_joins"] then 
                                Mini_games.stop_game()
                            end
                        end
                        if not finsihed then
                            local time = tostring(math.round((game.tick - scores[name].time)/60,4))
                            if scores[name].totale_time then
                                scores[name].totale_time = scores[name].totale_time + (game.tick - scores[name].time)/60
                            else
                                scores[name].totale_time =  (game.tick - scores[name].time)/60
                            end
                            scores[name].time = game.tick
                            game.print(name.." Has lapped in: "..time.." seconds. Lap "..laps[name].."/"..variables["laps"]..".")
                        end
                    end
                else
                    game.print("error line 247 race.lua")
                end
            end
        end
    end
end

local stop_invins = function(name)
    variables["Dead_car"][name].car.destructible = true
    local player = variables["Dead_car"][name].player
    player.character.destructible = true 
end

local kill_biters = function(name)
    local biters = surface[1].find_enemy_units(variables["Dead_car"][name].position, 3, "player")
    for i, biter in ipairs(biters) do
        biter.destroy()
    end
end

local function invisabilty(car,name)
    car.destructible = false
    local biters = surface[1].find_enemy_units(variables["Dead_car"][name].position, 50, "player")
    for i, biter in ipairs(biters) do
        biter.set_command({type = defines.command.flee, distraction  = defines.distraction.by_anything, from = car})
    end
end

local token_for_stop_invins = Token.register(stop_invins)

local token_for_kill_biters = Token.register(kill_biters)


local respawn_car = function(name)
    local player = variables["Dead_car"][name].player
    local car =
        surface[1].create_entity {
        name = "car",
        direction = defines.direction.north,
        position = variables["Dead_car"][name].position,
        force = "player"
    }
    car.set_driver(player)
    car.orientation = variables["Dead_car"][name].orientation
    car.get_fuel_inventory().insert({name = variables["fuel"], count = 100})
    cars[name] = car

    Permission_Groups.set_player_group(player, variables["Dead_car"][name].group)
    invisabilty(car,name)

    variables["Dead_car"][name].car = car
end

token_for_car = Token.register(respawn_car)


local car_destroyed = function(event)
    local dead_car = event.entity
    if dead_car.name == "car" then
        local player = dead_car.get_driver().player
        local name = player.name
        if not variables["Dead_car"] then
            variables["Dead_car"] = {}
        end
        if not variables["Dead_car"][name] then
            variables["Dead_car"][name] = {}
        end
        variables["Dead_car"][name].player = player
        variables["Dead_car"][name].position = dead_car.position
        variables["Dead_car"][name].orientation = dead_car.orientation
        variables["Dead_car"][name].group = Permission_Groups.get_group_from_player(player).name
        player.character.destructible = false 
        Permission_Groups.set_player_group(player, "out_car")
        task.set_timeout_in_ticks(180, token_for_car,name)
        task.set_timeout_in_ticks(190, token_for_kill_biters,name)
        task.set_timeout_in_ticks(480, token_for_stop_invins,name)
    end
end

local player_invisabilty = function(event)
    local entity = event.entity
    if entity.player then
        entity.health = 1000
    end
end

local function back_in_car(event)
    local player = game.players[event.player_index]
    if not player.vehicle then
        local car = cars[player.name]
        if car then
            car.set_driver(player)
        end
    end
end

local function player_join(event)
    local player = game.players[event.player_index]
    player.teleport({-85, -126},"Race game")
    player.character.destroy()
    variables["new_joins"] = variables["new_joins"] + 1 

end


local function on_player_left_game(event)
    local player = game.players[event.player_index]
    if not start_players[player.name] then
        variables["new_joins"] = variables["new_joins"] - 1
    else
        local name = player.name 
        start_players[name] = nil
        scores[name] = nil
        player_progress[name] = nil
        player.character.destructible = true 

    end
    if not player.character then
        player.create_character()
    end 
    player.teleport({-35,55},"nauvis")
    if cars[player.name] then
        cars[player.name].destroy()
    end

end


race:add_map("Race game", -80, -140)
race:add_start_function(start)
race:add_stop_function(stop)
--race:add_event(defines.events.on_entity_damaged, player_invisabilty)
race:add_event(defines.events.on_player_changed_position, player_move)
race:add_event(defines.events.on_entity_died, car_destroyed)
race:add_event(defines.events.on_player_driving_changed_state, back_in_car)
race:add_event(defines.events.on_player_joined_game, player_join)
race:add_event(defines.events.on_pre_player_left_game, on_player_left_game)
race:add_option(3)



local function give_vars()
    return {
        surface=surface ,
        gates=gates,
        variables=variables,
        areas=areas,
        player_progress=player_progress,
        cars=cars,
        scores=scores,
        laps=laps,
        gate_boxes=gate_boxes,
        start_players=start_players 
    }
end

interface.add_interface_callback('Race',function(player) return give_vars() end)