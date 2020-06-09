local Mini_games    = require "expcore.Mini_games"
local Token         = require "utils.token"
local task          = require "utils.task"
local Global        = require "utils.global" --Used to prevent desynicing.
local Gui           = require "expcore.gui._require"
local config        = require "config.mini_games.tight_spot"
local tight         = Mini_games.new_game("Tight_spot")
local Store         = require 'expcore.store' --- @dep expcore.store
local Roles         = require "expcore.roles" --- @dep expcore.roles
local balances      = Store.register(function(player) return player.name end)
local walls = {}
local save = {}
save["tiles"] = {}
save["entity"] = {}
local game_gui
local variables = {}
local centers = {}
local markets = {}
local entities = {}
local started = {}
local chests = {}
local islands = {}
local left_players = {}

local tightspot_prices = {
    ["coal"] = 5,
    ["transport-belt"] = 5,
    ["underground-belt"] = 20,
    ["fast-transport-belt"] = 50,
    ["fast-underground-belt"] = 200,
    ["splitter"] = 25,
    ["fast-splitter"] = 50,
    ["burner-inserter"] = 10,
    ["inserter"] = 10,
    ["long-handed-inserter"] = 15,
    ["fast-inserter"] = 20,
    ["filter-inserter"] = 35,
    ["red-wire"] = 2,
    ["green-wire"] = 2,
    ["wooden-chest"] = 5,
    ["iron-chest"] = 10,
    ["stone-furnace"] = 10,
    ["steel-furnace"] = 50,
    ["electric-furnace"] = 70,
    ["offshore-pump"] = 10,
    ["pipe"] = 5,
    ["pipe-to-ground"] = 20,
    ["boiler"] = 15,
    ["steam-engine"] = 50,
    ["small-electric-pole"] = 10,
    ["medium-electric-pole"] = 50,
    ["big-electric-pole"] = 100,
    ["substation"] = 150,
    ["assembling-machine-1"] = 30,
    ["assembling-machine-2"] = 50,
    ["assembling-machine-3"] = 100,
    ["electric-mining-drill"] = 50,
    ["burner-mining-drill"] = 10,
    ["pumpjack"] = 50,
    ["oil-refinery"] = 100,
    ["chemical-plant"] = 50,
    ["storage-tank"] = 40,
    ["pump"] = 20,
    ["logistic-robot"] = 150,
    ["logistic-chest-passive-provider"] = 50,
    ["logistic-chest-requester"] = 50
}

Global.register({
    centers     = centers,
    markets     = markets,
    entities    = entities,
    started     = started,
    chests      = chests,
    islands     = islands,
    walls       = walls,
    variables   = variables,
    save        = save,
    left_players= left_players,
},function(tbl)
    centers     = tbl.centers
    markets     = tbl.markets
    entities    = tbl.entities
    started     = tbl.started
    chests      = tbl.chests
    islands     = tbl.islands
    walls       = tbl.walls
    variables   = tbl.variables
    save        = tbl.save
    left_players= tbl.left_players
end)


local function land_price(player, position)
    return math.abs(position.x - centers[player.name].x) + math.abs(position.y - centers[player.name].y) + variables.level.starting_land_prize
end

local function SecondsToClock(seconds)
    seconds = tonumber(seconds)

    if seconds <= 0 then
        return "00:00";
    else
        local mins = string.format("%02.f", math.floor(seconds/60));
        local secs = string.format("%02.f", math.floor(seconds  - mins *60));
        return mins..":"..secs
    end
end

local function change_balance(player,amount)
    Store.update(balances,player,function()
        if amount < 0 then
            local available = player.get_item_count("coin")
            amount = amount * -1
            if available < amount then
                local Debt =  5000 - amount + available
                player.insert{name = "coin", count = Debt }
                player.print("Borrowed 5000 coins to pay for the land")
                local Main_gui = Gui.get_left_element(player, game_gui)
                local table = Main_gui.container["Money"].table
                table["Debt"].caption = tostring(tonumber(table["Debt"].caption) + 5000)
            else
                player.remove_item {name = "coin", count = amount}
            end
        else
            if amount ~= 0 then
                player.insert{name = "coin", count = amount}
            end
        end
        return player.get_item_count("coin")
    end)
end

local function player_join_game(player,at_player)
    --coins and random stuffs
    local level = variables.level
    Store.set(balances,player,variables.diffuclty)
    local character = player.character
    player.set_controller {type = defines.controllers.god}
    if character then
        character.destroy()
    end
    local playerforce = player.force
    playerforce.manual_mining_speed_modifier = 1000
    player.insert {name = "coin", count = variables.diffuclty}

    --gui

    local Main_gui = Gui.get_left_element(player, game_gui)
    Gui.toggle_left_element(player,  Main_gui, true)
    local table = Main_gui.container["Money"].table
    table["Balance"].caption = variables.diffuclty
    table["Time"].caption = SecondsToClock(level.time/60)

    table = Main_gui.container["Objectives"].table
    table["Objective"].caption = level.objective
    table["prices"].caption = level.demand.price

    --island
    local area = {}
    area[1] = {}
    area[2] = {}
    area[1][1] = level.area[1][1]
    area[1][2] = level.area[1][2]
    area[2][1] = level.area[2][1]
    area[2][2] = level.area[2][2]
    area[1][1] = area[1][1] +  at_player * 500
    area[2][1] = area[2][1] +  at_player * 500
    islands[player.name] = area
    local left_overs = variables["surface"].find_entities_filtered {area= area}
    for i, ent in ipairs(left_overs) do
        if ent.name ~= "market" and ent.name ~= "steel-chest" then
            ent.destroy()
        end
    end
    local tiles = {}
    for i,tile in ipairs(save["tiles"]) do
        tiles[i] = tile
        tiles[i].position.x = tiles[i].position.x +  at_player * 500
    end
    variables["surface"].set_tiles(tiles)
    for i, entity in ipairs(save["entity"]) do
        local name = entity[1]
        local position = {}
        position.x = entity[2].x
        position.y = entity[2].y
        local force = entity[3]
        local minable = entity[4]
        position.x = position.x + at_player * 500
        if name == "market" then
            markets[#markets + 1] = position
        end
        --[[
        if name == "steel-chest" then
            chests[#chests+1] = {entity,player.name}
        end
        ]]
        local ent = variables["surface"].create_entity{name = name , position = position , force = force }
        if name == "steel-chest" then
            chests[#chests+1] = {ent,player.name}
        end
        ent.minable = minable
    end
    centers[player.name] = {}
    centers[player.name].x = level.center.x
    centers[player.name].y = level.center.y
    centers[player.name].x =  centers[player.name].x + at_player * 500
    variables.walls[player.name] = {}
    local wal = variables["surface"].find_entities_filtered {name = "stone-wall", area= area}
    for i,wall in ipairs(wal) do
        local p = wall.position
        variables.walls[player.name][p.x..','..p.y] = true
    end
    local center = centers[player.name]
    player.teleport({center.x,center.y},level.surface)
    game.print("tp")
end


local function level_save()
    local level = variables.level
    for x=level.area[1][1],level.area[2][1] do
        for y = level.area[1][2],level.area[2][2] do
            local tile = variables["surface"].get_tile(x,y)
            local table = {
                name = tile.name,
                position = tile.position
            }
            save["tiles"][#save["tiles"]+1] = table
        end
    end

    save["entity"] = variables["surface"].find_entities_filtered {area = level.area}
    for i, entity in ipairs(save["entity"]) do
        local name = entity.name
        if name ~= "character" then
            if name == "steel-chest" then
                chests[#chests+1] = {entity,game.connected_players[1].name}
            end
            local position = entity.position
            local force = entity.force
            local minbale =  entity.minable
            local table = {name,position,force,minbale}
            if name == "market" then
                markets[#markets + 1] = position
            end
            save["entity"][i] = table
        else
            if i == #save["entity"] then
                save["entity"][i] = nil
            else
                name = save["entity"][#save["entity"]].name
                local position = save["entity"][#save["entity"]].position
                local force = save["entity"][i].force
                local minbale =  save["entity"][i].minable
                local table = {name,position,force,minbale}
                if name == "market" then
                    markets[#markets + 1] = position
                end
                if name == "steel-chest" then
                    chests[#chests+1] = {entity,game.connected_players[1].name}
                end
                save["entity"][i] = table
                save["entity"][#save["entity"]] = nil
            end
        end
    end

    variables.walls = variables["surface"].find_entities_filtered {name = "stone-wall", area= level.area}
    for i,wall in ipairs(variables.walls) do
        local p = wall.position
        variables.walls[p.x..','..p.y] = true
    end
end

local function market_setup()
    for i, pos in ipairs(markets)  do
        local market = variables["surface"].find_entity("market", pos)
        market.clear_market_items()
        for _, item in ipairs(variables.level.items) do
            local offer = {price = {{"coin", tightspot_prices[item]}}, offer = {type = "give-item", item = item}}
            market.add_market_item(offer)
        end
    end
end
local function start(args)
    variables["level"] = {}
    variables["surface"] = {}
    variables["walls"] = {}
    local level_index = args[1]
    variables.level = config[level_index]
    variables.diffuclty = variables.level.money[args[2]]
    variables.loan_price =  variables.level.loan_prices[args[2]]
    variables["surface"] = game.surfaces[variables.level["surface"]]
    if not save["tiles"][1] then
        level_save()
    end
    for i, player in ipairs(game.connected_players) do
        player_join_game(player,i-1)
    end
    local force = game.players[1].force
    force.disable_all_prototypes()
    local recipe_list = force.recipes
    for index, item in pairs(variables.level.recipes) do
        recipe_list[item].enabled = true
    end

    market_setup()
    variables.tick = game.tick
end


local function reset_table(table)
    for i, _ in pairs(table) do
        table[i] = nil
    end
end

local function getSuffix (n)
    local lastTwo, lastOne = n % 100, n % 10
    if lastTwo > 3 and lastTwo < 21 then return "th" end
    if lastOne == 1 then return "st" end
    if lastOne == 2 then return "nd" end
    if lastOne == 3 then return "rd" end
    return "th"
end

local function Nth (n) return n..getSuffix(n) end

local function stop()
    game.speed = 1
    for i,player in ipairs(game.connected_players) do
        player.set_controller {type = defines.controllers.god}
        player.create_character()
        --gui
        local Main_gui = Gui.get_left_element(player, game_gui)
        local table = Main_gui.container["slider"].table
        table.visible = false
        Gui.toggle_left_element(player,  Main_gui, false)
    end
    started[1] = false

    local area = variables.level.area
    area[1][1] = area[1][1]
    area[2][1] = area[2][1]
    local left_overs = variables["surface"].find_entities_filtered {area= area}
    for i, ent in ipairs(left_overs) do
        if ent.name ~= "market" and ent.name ~= "steel-chest" then
            ent.destroy()
        end
    end
    for i, entity in ipairs(save["entity"]) do
        local name = entity[1]
        local position = entity[2]
        local force = entity[3]
        local minable = entity[4]
        position.x = position.x
        entity[2].x = position.x
        local ent = variables["surface"].create_entity{name = name , position = position , force = force }
        ent.minable = minable
    end
    local players = {}
    for name,_ in pairs(centers) do
        players[#players+1] = name
    end
    local scores = {}
    for _,name in ipairs(players) do
        local player = game.players[name]
        scores[#scores+1] = {Store.get(balances,player),name}
    end
    local colors =  {
        ["1st"] = "[color=#FFD700]",
        ["2nd"] = "[color=#C0C0C0]",
        ["3rd"] = "[color=#cd7f32]"
    }
    table.sort(scores,function(a,b) return a[1] > b[1] end)
    for i, score in ipairs(scores) do
        local money = score[1]
        local player_name = score[2]
        local place = Nth(i)
        if colors[place] then
            game.print(colors[place]..place..": "..player_name.." with "..money.." points.[/color]")
        else
            game.print("[color=#808080]"..place..": "..player_name.." with "..money.." points.[/color]")
        end
    end
    reset_table(centers)
    reset_table(markets)
    reset_table(entities)
    reset_table(started)
    reset_table(chests)
    reset_table(variables)
    reset_table(left_players)
end

local function placed_entety(event)
    local entity = event.created_entity
    local position = entity.position
    local player = game.players[event.player_index]
    if entity.type ~= "wall" then
        entities[entity.name] = entity.name
        entity.active = false
    else
        if not variables.walls[player.name][position.x..','..position.y] then
            player.print("You cant resell this land.")
            player.insert{name = entity.name, count = 1}
            entity.destroy()
        else
            local price = land_price(player,position)
            change_balance(player,price)
            player.surface.create_entity {
                name = "flying-text",
                position = position,
                text = "+" .. price,
                color = {g = 1 }
            }
        end
    end
end
local token_for_replace_wall
local function mined(event)
    local entity = event.entity
    if entity.type == "wall" then
        local position = entity.position
        local player = game.players[event.player_index]
        if not variables.walls[player.name][position.x..','..position.y] then
            local force = entity.force
            task.set_timeout_in_ticks(1, token_for_replace_wall,{{name = entity.name , position = position , force = force},player.name})
            player.print("How did you get here.")
        else
            local price = land_price(player, position)
            player.surface.create_entity {
                name = "flying-text",
                position = position,
                text = "-" .. price,
                color = {r = 1}
            }
            change_balance(player,price*-1)
        end
    end
end
local function replace_wall(args)
    variables["surface"].create_entity(args[1])
    game.players[args[2]].remove_item{name = args[1].name,count = 1}
end

local function start_game()

    game.print("Time is up.")
    local all_names = {"pipe"}
    for i,name in pairs(entities) do
        all_names[i] = name
    end
    local all = variables["surface"].find_entities_filtered {name = all_names}
    for i,entity in ipairs(all) do
        entity.active = true
    end
    for i,player in ipairs(game.connected_players) do
        player.set_controller {type = defines.controllers.spectator}

        local Main_gui = Gui.get_left_element(player, game_gui)
        local table = Main_gui.container["Money"].table
        local Debt = tonumber(table["Debt"].caption)/5000 -- amount of loans taken
        Debt = Debt * variables.loan_price --Each loan will cost variables.loan_prices points
        Store.set(balances,player,Debt * -1)
        table["Debt"].caption = "0"
        table["Time"].caption = SecondsToClock(variables.level.play_time/60)

        if Roles.player_allowed(player, 'gui/tightspot_speed') then
            table = Main_gui.container["slider"].table
            table.visible = true
        end
    end
    for i, chest in ipairs(chests) do
        local ent = chest[1]
        local inv = ent.get_inventory(defines.inventory.chest)
        inv.clear()
    end

end

local function check_chest()
    if started[1] == true then
        for i, chest in ipairs(chests) do
            local ent = chest[1]
            local inv = ent.get_inventory(defines.inventory.chest)
            local count = inv.get_item_count(variables.level.demand.item)
            local price = count * variables.level.demand.price
            if price ~= 0 then
                local player = game.players[chest[2]]
                local balance = Store.get(balances,player)
                local result = balance + price
                player.surface.create_entity {
                    name = "flying-text",
                    position = ent.position,
                    text = "+" .. price,
                    color = {g = 1 }
                }
                Store.set(balances,player,result)
            end
            inv.clear()
        end
    end
end

local function timer()
    if started[1] ~= true then
        local time = variables.level.time
        time = SecondsToClock((time - (game.tick - variables.tick))/60)
        if time == "00:00" then
            started[1] = true
            variables.tick = game.tick
            start_game()
        else
            for i,player in ipairs(game.connected_players) do
                local Main_gui = Gui.get_left_element(player, game_gui)
                local table = Main_gui.container["Money"].table
                table["Time"].caption = time
            end
        end
    else
        local time = variables.level.play_time
        time = SecondsToClock((time - (game.tick - variables.tick))/60)
        if time == "00:00" then
            Mini_games.stop_game()
        end
        for i,player in ipairs(game.connected_players) do
            local Main_gui = Gui.get_left_element(player, game_gui)
            local table = Main_gui.container["Money"].table
            table["Time"].caption = time
        end
    end
end

token_for_replace_wall =  Token.register(replace_wall)
Store.watch(balances,function(value,key,_)
    local player = game.players[key]
    local Main_gui = Gui.get_left_element(player, game_gui)
    local table = Main_gui.container["Money"].table
    table["Balance"].caption = value
end)


local function market(event)
    local player = game.players[event.player_index]
    Store.set(balances,player,player.get_item_count("coin"))
end

local function insideBox(box, pos)
    local x1 = box[1][1]
    local y1 = box[1][2]
    local x2 = box[2][1]
    local y2 = box[2][2]

    local px = pos.x
    local py = pos.y
    return px >= x1 and px <= x2 and py >= y1 and py <= y2
end

local function player_move(event)
    local player = game.players[event.player_index]
    if player.surface.name == variables.level.surface then  --check if the player has not been tped away
        local center = centers[player.name]
        if center then
            local pos = player.position
            local area = islands[player.name]
            if not insideBox(area,pos) then
                player.teleport({center.x,center.y},variables.level.surface)
            end
        end
    end
end

local function on_player_left_game(event)
    local player = game.players[event.player_index]

    local inv = player.get_inventory(defines.inventory.god_main)
    local all_items = inv.get_contents()
    game.print(serpent.block(all_items))
    left_players[player.name] = all_items

    player.set_controller {type = defines.controllers.god}
    player.create_character()
    player.teleport({-35,55},"nauvis")
    --gui
    local Main_gui = Gui.get_left_element(player, game_gui)
    local table = Main_gui.container["slider"].table
    table.visible = false
    Gui.toggle_left_element(player,  Main_gui, false)
end

local function player_join(event)
    local player = game.players[event.player_index]
    player.character.destroy()
    local items = left_players[player.name]
    local center = centers[player.name]
    if items then
        player.teleport(center,variables.level.surface)
        if started[1] then
            player.set_controller {type = defines.controllers.spectator}
        else
            player.set_controller {type = defines.controllers.god}
            local Main_gui = Gui.get_left_element(player, game_gui)
            Gui.toggle_left_element(player,  Main_gui, true)
            for item,amount in pairs(items) do
                player.insert {name = item, count = amount}
            end
        end
    else
        player.set_controller {type = defines.controllers.spectator}
        player.teleport(variables.level.center,variables.level.surface)
    end


end

--gui
local speed_slider
local  function speed_change(player, _, _)
    local Main_gui = Gui.get_left_element(player, game_gui)
    local table = Main_gui.container["slider"].table
    game.speed = table[speed_slider.name].slider_value
end

--game gui

speed_slider =
Gui.element{
    type = "slider",
    minimum_value = 1,
    maximum_value  = 64,
    value = 4,
    value_step = 1,
}:on_value_changed(speed_change)
local label_func =
Gui.element(function(_,parent,name,style,caption)
    if name ~= nil then
        return parent.add {
            type = "label",
            caption = caption,
            style = style,
            name = name
        }
    else
        return parent.add {
            type = "label",
            caption = caption,
            style = style,
        }
    end
end)
game_gui =
Gui.element(function(event_trigger,parent)
    local container = Gui.container(parent,event_trigger,200)
    Gui.header(container,"Tight spot","The Tight money manual.",true)

    local scroll_table_slider = Gui.scroll_table(container,250,2,"slider")
    label_func(scroll_table_slider,nil,"heading_1_label","speed:")
    speed_slider(scroll_table_slider)
    scroll_table_slider.visible  = false

    local tilel1 = label_func(container,nil,"heading_1_label","Money:")
    tilel1.style.left_padding = 7

    local scroll_table_labels = Gui.scroll_table(container,250,2,"Money")
    local scroll_table_labels_style = scroll_table_labels.style
    scroll_table_labels_style.top_cell_padding = 3
    scroll_table_labels_style.bottom_cell_padding = 3
    scroll_table_labels_style.left_cell_padding  = 7

    local tilel2 = label_func(container,nil,"heading_1_label","Objective:")
    tilel2.style.left_padding = 7

    local scroll_table2 = Gui.scroll_table(container,250,2,"Objectives")
    local scroll_table2_style = scroll_table2.style
    scroll_table2_style.top_cell_padding = 3
    scroll_table2_style.bottom_cell_padding = 3
    scroll_table2_style.left_cell_padding  = 7

    label_func(scroll_table_labels,nil,"label","Balance: ")
    label_func(scroll_table_labels,"Balance","label","0")

    label_func(scroll_table_labels,nil,"label","Debt: ")
    label_func(scroll_table_labels,"Debt","label","0")

    label_func(scroll_table_labels,nil,"label","Time: ")
    label_func(scroll_table_labels,"Time","label","10:00")

    label_func(scroll_table2,nil,"label","Type:")
    label_func(scroll_table2,"Objective","label","Iron gear")

    label_func(scroll_table2,nil,"label","Price: ")
    label_func(scroll_table2,"prices","label","15")

    return container.parent
end)
:add_to_left_flow(false)
Gui.left_toolbar_button('item/coin','money',game_gui,function(_)  return Mini_games.Running_game() == "Tight_spot" end)


--start gui
local dorpdown_for_level =
    Gui.element {
    type = "drop-down",
    items = {"level-1", "level-2"},
    selected_index = 1
}:style {
    width = 87
}
local dorpdown_for_difficulty =
Gui.element{
    type = 'drop-down',
    items = {"easy","normal","hard"},
    selected_index = 1
}
:style{
    width = 87
}

local maingui =
    Gui.element(
    function(_, parent)
        local main_flow = parent.add {type = "flow", name = "Tight_flow"}
        dorpdown_for_level(main_flow)
        dorpdown_for_difficulty(main_flow)
    end
)


local function gui_callback(parent)
    local args = {}
    local flow = parent["Tight_flow"]

    local level_dropwdown = flow[dorpdown_for_level.name]
    local level_config = level_dropwdown.selected_index
    args[1] = level_config

    local difficulty_dropdown = flow[dorpdown_for_difficulty.name]
    local diffuclty_set = difficulty_dropdown.get_item(difficulty_dropdown.selected_index)
    args[2] = diffuclty_set

    return args
end
tight:add_event(defines.events.on_built_entity, placed_entety)
tight:add_event(defines.events.on_market_item_purchased, market)
tight:add_event(defines.events.on_player_mined_entity, mined)
tight:add_event(defines.events.on_player_changed_position, player_move)
tight:add_event(defines.events.on_pre_player_left_game, on_player_left_game)
tight:add_event(defines.events.on_player_joined_game, player_join)
tight:add_on_nth_tick(100, check_chest)
tight:add_on_nth_tick(60, timer)

tight:add_map("tigth_spot", 0, 0)
tight:set_start_function(start)
tight:set_gui_callback(gui_callback)
tight:set_gui_element(maingui)
tight:add_option(2)
tight:set_stop_function(stop)
