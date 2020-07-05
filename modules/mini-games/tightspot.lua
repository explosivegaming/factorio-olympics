local Mini_games = require "expcore.Mini_games"
local Token = require "utils.token"
local task = require "utils.task"
local Global = require "utils.global" --Used to prevent desynicing.
local Gui = require "expcore.gui"
local config = require "config.mini_games.tight_spot"
local Store = require "expcore.store" --- @dep expcore.store
local Roles = require "expcore.roles" --- @dep expcore.roles

local walls = {}
local save = {tiles = {}, entities = {}}
local game_gui
local variables = {}
local centers = {}
local markets = {}
local entities = {}
local started = {}
local chests = {}
local islands = {}
local left_players = {}

--- Table of all item prices
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

--- Stores player balances
local balances = Store.register(function(player)
    return player.name
end)

--- Register all the global variables
Global.register({
    centers      = centers,
    markets      = markets,
    entities     = entities,
    started      = started,
    chests       = chests,
    islands      = islands,
    walls        = walls,
    variables    = variables,
    save         = save,
    left_players = left_players
},function(tbl)
    centers      = tbl.centers
    markets      = tbl.markets
    entities     = tbl.entities
    started      = tbl.started
    chests       = tbl.chests
    islands      = tbl.islands
    walls        = tbl.walls
    variables    = tbl.variables
    save         = tbl.save
    left_players = tbl.left_players
end)

--- Internal, Used to clear tables of all values
local function reset_table(table)
    for i, _ in pairs(table) do
        table[i] = nil
    end
end

--- Internal, Reset all global tables
local function reset_globals()
    reset_table(centers)
    reset_table(markets)
    reset_table(entities)
    reset_table(started)
    reset_table(chests)
    reset_table(variables)
    reset_table(left_players)
    reset_table(save)
    save.tiles = {}
    save.entities = {}
end

--- Remove all placed items from an area
local function clean_up(area)
    local left_overs = variables["surface"].find_entities_filtered{
        area = area,
        name = {"market", "steel-chest"},
        invert = true
    }
    for _, entity in ipairs(left_overs) do
        entity.destroy()
    end
end

local abs = math.abs
--- Calculate the price of land by finding the distance from the centre
local function land_price(player, position)
    local dx = position.x - centers[player.name].x
    local dy = position.y - centers[player.name].y
    return abs(dx) + abs(dy) + variables.level.starting_land_prize
end

local floor = math.floor
local str_format = string.format
--- Convert seconds into minutes and seconds clock format
local function SecondsToClock(seconds)
    seconds = tonumber(seconds)

    if seconds <= 0 then
        return "00:00"
    else
        local mins = str_format("%02.f", floor(seconds / 60))
        local secs = str_format("%02.f", floor(seconds - mins * 60))
        return mins .. ":" .. secs
    end
end

--- Change a players balance
local function change_balance(player, amount)
    if amount > 0 then
        player.insert{ name = "coin", count = amount }
    elseif amount < 0 then
        local available = player.get_item_count("coin")
        amount = amount * -1
        if available > amount then
            player.remove_item{ name = "coin", count = amount }
        else
            local Debt = 5000 - amount
            player.insert {name = "coin", count = Debt}
            player.print("Borrowed 5000 coins to pay for the land")

            local Main_gui = Gui.get_left_element(player, game_gui)
            local gui_table = Main_gui.container["Money"].table
            gui_table["Debt"].caption = tostring(tonumber(gui_table["Debt"].caption) + 5000)
        end
    end
    Store.set(balances, player, player.get_item_count("coin"))
end

--- Save the starting island so it can be cloned for new players
local function level_save()
    -- Save all the tiles from the template
    local level = variables.level
    local tiles = save["tiles"]
    for x = level.area[1][1], level.area[2][1] do
        for y = level.area[1][2], level.area[2][2] do
            local tile = variables["surface"].get_tile(x, y)
            tiles[#tiles + 1] = {
                name = tile.name,
                position = tile.position
            }
        end
    end

    -- Save all the entities from the template
    save.entities = variables["surface"].find_entities_filtered{ area = level.area }
    for i, entity in ipairs(save.entities) do
        local name = entity.name
        if name ~= "character" then
            save.entities[i] = {name, entity.position, entity.force, entity.minable}
        else
            if i == #save.entities then
                save.entities[i] = nil
            else
                local ent = save.entities[#save.entities]
                save.entities[i] = {ent.name, ent.position, ent.force, ent.minable}
                save.entities[#save.entities] = nil
            end
        end
    end
end

--- Clones the template island and teleports the player to it
local function setup_player_island(player, at_player)
    -- Put the player into god mod
    local character = player.character
    player.set_controller{ type = defines.controllers.god }
    player.force.manual_mining_speed_modifier = 1000
    if character and character.valid then
        character.destroy()
    end

    -- Give the player the starting amount of coins
    local level = variables.level
    Store.set(balances, player, variables.difficulty)
    player.insert{ name = "coin", count = variables.difficulty }

    -- Show the main gui for the game
    local Main_gui = Gui.get_left_element(player, game_gui)
    Gui.toggle_left_element(player, game_gui, true)

    -- Set up the captions on the first gui table
    local gui_table_one = Main_gui.container["Money"].table
    gui_table_one["Balance"].caption = variables.difficulty
    gui_table_one["Time"].caption = SecondsToClock(level.time / 60)

    -- Set up the captions on the second gui table
    local gui_table_two = Main_gui.container["Objectives"].table
    gui_table_two["objective"].caption = level.objective
    gui_table_two["prices"].caption = level.demand.price

    -- Find the area for the players island
    local player_offset = at_player * 500
    local level_area = level.area
    local area = {
        {level_area[1][1] + player_offset, level_area[1][2]},
        {level_area[2][1] + player_offset, level_area[2][2]}
    }
    islands[player.name] = area
    clean_up(area)

    -- Set all the tiles for the players island
    local tiles = {}
    for i, tile in ipairs(save["tiles"]) do
        tiles[i] = {
            name = tile.name,
            position = {
              x = tile.position.x + player_offset,
              y = tile.position.y
            }
        }
    end
    variables["surface"].set_tiles(tiles)

    -- Create all the entities on the players island
    for i, entity in ipairs(save.entities) do
        local name = entity[1]
        local position = {x = entity[2].x + player_offset, y = entity[2].y}
        local force = entity[3]
        local minable = entity[4]
        local ent = variables["surface"].create_entity{ name = name, position = position, force = force }
        if name == "market" then
            markets[#markets + 1] = position
        elseif name == "steel-chest" then
            chests[#chests + 1] = {ent, player.name}
        end
        ent.minable = minable
    end

    -- Find the center for the players island
    centers[player.name] = {
        x = level.center.x + player_offset,
        y = level.center.y
    }

    -- Find all the walls on the island
    local wall_data = {}
    variables.walls[player.name] = wall_data
    local walls_found = variables["surface"].find_entities_filtered{ name = "stone-wall", area = area }
    for i, wall in ipairs(walls_found) do
        local p = wall.position
        wall_data[p.x .. "," .. p.y] = true
    end

    -- Teleport the player to their island
    player.teleport(centers[player.name], level.surface)
end

--- Called by mine game module to start this minigame
local function start(args)
    variables["level"] = {}
    variables["surface"] = {}
    variables["walls"] = {}

    -- Setup all level related variables
    local level_index = args[1]
    variables.level = config[level_index]
    variables.difficulty = variables.level.money[args[2]]
    variables.loan_price = variables.level.loan_prices[args[2]]
    variables["surface"] = game.surfaces[variables.level["surface"]]

    -- Save the template and clone it for all existing players
    if not save["tiles"][1] then level_save() end
    for i, player in ipairs(game.connected_players) do
        setup_player_island(player, i - 1)
    end

    -- Set up the allowed items for the force
    local force = game.players[1].force
    force.disable_all_prototypes()
    local recipe_list = force.recipes
    for index, item in pairs(variables.level.recipes) do
        recipe_list[item].enabled = true
    end

    -- Set up the markets
    for i, pos in ipairs(markets) do
        local market = variables["surface"].find_entity("market", pos)
        market.clear_market_items()
        for _, item in ipairs(variables.level.items) do
            market.add_market_item{price = {{"coin", tightspot_prices[item]}}, offer = {type = "give-item", item = item}}
        end
    end
    variables.tick = game.tick
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
local message_format = '%s: %s with %d points'
local colors =  {
    ["1st"] = { 255, 215, 0   },
    ["2nd"] = { 192, 192, 192 },
    ["3rd"] = { 205, 127, 50  },
    default = { 128, 128, 128 }
}

--- Function called by mini game module to stop this game
local function stop()
    game.speed = 1
    started[1] = false

    -- Reset all players and their guis
    for i, player in ipairs(game.connected_players) do
        player.set_controller{ type = defines.controllers.god }
        player.create_character()

        local Main_gui = Gui.get_left_element(player, game_gui)
        Gui.toggle_left_element(player, game_gui, false)

        local table = Main_gui.container["slider"].table
        table.visible = false
    end

    -- Remove all placed entities
    local area = variables.level.area
    clean_up(area)

    -- Remake all entities from the template
    for i, entity in ipairs(save.entities) do
        local name = entity[1]
        local position = entity[2]
        local force = entity[3]
        local minable = entity[4]
        local ent = variables["surface"].create_entity {name = name, position = position, force = force}
        ent.minable = minable
    end

    -- Get all player scores and sort them in order
    local scores = {}
    for name in pairs(centers) do
        scores[#scores + 1] = {Store.get(balances, name), name}
    end

    table.sort(scores, function(a, b)
        return a[1] > b[1]
    end)

    -- Print the player scores
    for i, score in ipairs(scores) do
        local money = score[1]
        local player_name = score[2]
        local place = Nth(i)
        local colour = colors[place] or colors.default
        game.print(message_format:format(place, player_name, money), colour)
    end

    -- Reset the global values
    reset_globals()
end

--- Triggered when an entity is placed
local function placed_entity(event)
    local entity = event.created_entity
    local position = entity.position
    local player = game.players[event.player_index]
    if entity.type ~= "wall" then
        -- If its not a wall then disable it to stop it doing anything
        entities[entity.name] = entity.name
        entity.active = false
    else
        -- If it is a wall test if the player was the one who removed this wall
        if not variables.walls[player.name][position.x .. "," .. position.y] then
            player.print("You cant resell this land.")
            player.insert{ name = entity.name, count = 1 }
            entity.destroy()
        else
            local price = land_price(player, position)
            change_balance(player, price)
            player.surface.create_entity{
                name = "flying-text",
                position = position,
                text = "+" .. price,
                color = {g = 1}
            }
        end
    end
end

--- Used to replace wall after they have been mined
local replace_wall = Token.register(function(args)
    variables["surface"].create_entity(args[1])
    args[2].remove_item{name = args[1].name, count = 1}
end)

--- Triggered when an entity is mined
local function mined(event)
    local entity = event.entity
    if entity.type ~= "wall" then return end
    local position = entity.position
    local player = game.players[event.player_index]
    if not variables.walls[player.name][position.x .. "," .. position.y] then
        -- If the player was not the one to place it then replace it
        task.set_timeout_in_ticks(
            1, replace_wall,
            {{name = entity.name, position = position, force = entity.force}, player}
        )
        player.print("How did you get here. (Ps if not command uses tell and admin of this.)")
    else
        -- Otherwise give the player money
        local price = land_price(player, position)
        change_balance(player, price * -1)
        player.surface.create_entity {
            name = "flying-text",
            position = position,
            text = "-" .. price,
            color = {r = 1}
        }
    end
end

--- When the timer runs out make all entities active
local function start_production()
    game.print("Time is up.")

    -- Get the name of every player placed entity
    local all_names = {"pipe"}
    for i, name in pairs(entities) do
        all_names[i] = name
    end

    -- Make all the entities active
    local all = variables["surface"].find_entities_filtered{name = all_names}
    for i, entity in ipairs(all) do
        entity.active = true
    end

    -- Put all players into spectator
    for i, player in ipairs(game.connected_players) do
        player.set_controller{ type = defines.controllers.spectator }

        -- Update the players gui to show points and debt
        local Main_gui = Gui.get_left_element(player, game_gui)
        local table = Main_gui.container["Money"].table
        local Debt = tonumber(table["Debt"].caption) / 5000 -- amount of loans taken
        Debt = Debt * variables.loan_price --Each loan will cost variables.loan_prices points
        Store.set(balances, player, Debt * -1)
        table["Debt"].caption = "0"
        table["Time"].caption = SecondsToClock(variables.level.play_time / 60)

        -- Show speed controller if the player is allowed to use it
        if Roles.player_allowed(player, "gui/tightspot_speed") then
            table = Main_gui.container["slider"].table
            table.visible = true
        end
    end

    -- Clear all chests
    for i, chest in ipairs(chests) do
        local ent = chest[1]
        local inv = ent.get_inventory(defines.inventory.chest)
        inv.clear()
    end

end

--- Check the contents of all chests to check for produced items
local function check_chest()
    if not started[1] then return end
    for i, chest in ipairs(chests) do
        local ent = chest[1]
        local inv = ent.get_inventory(defines.inventory.chest)
        local count = inv.get_item_count(variables.level.demand.item)
        local price = count * variables.level.demand.price
        if price ~= 0 then
            local player = game.players[chest[2]]
            local balance = Store.get(balances, player)
            local result = balance + price
            player.surface.create_entity {
                name = "flying-text",
                position = ent.position,
                text = "+" .. price,
                color = {g = 1}
            }
            Store.set(balances, player, result)
        end
        inv.clear()
    end
end

--- Update and check the timer
local function timer()
    local time

    -- Find the correct time and check if its 0
    if started[1] then
        time = SecondsToClock((variables.level.play_time - (game.tick - variables.tick)) / 60)
        if time == "00:00" then
            Mini_games.stop_game()
        end
    else
        time = SecondsToClock((variables.level.time - (game.tick - variables.tick)) / 60)
        if time == "00:00" then
            started[1] = true
            variables.tick = game.tick
            start_production()
        end
    end

    -- Update the timer for all players
    for i, player in ipairs(game.connected_players) do
        local Main_gui = Gui.get_left_element(player, game_gui)
        local table = Main_gui.container["Money"].table
        table["Time"].caption = time
    end
end

--- Triggered when the player uses the market
local function market(event)
    local player = game.players[event.player_index]
    Store.set(balances, player, player.get_item_count("coin"))
end

--- AABB logic for if a position is in a box
local function insideBox(box, pos)
    local x1 = box[1][1]
    local y1 = box[1][2]
    local x2 = box[2][1]
    local y2 = box[2][2]

    local px = pos.x
    local py = pos.y
    return px >= x1 and px <= x2 and py >= y1 and py <= y2
end

--- Triggered when the player moves
local function player_move(event)
    -- Check the player is still on the game surface
    local player = game.players[event.player_index]
    if player.surface.name ~= variables.level.surface then return end

    -- Check if the player is a contestant
    local center = centers[player.name]
    if not center then return end

    -- If the player leaves their island teleport them back
    local pos = player.position
    local area = islands[player.name]
    if not insideBox(area, pos) then
        player.teleport(center, variables.level.surface)
    end
end

--- Triggered when a player leaves the game
local function on_player_left_game(event)
    local player = game.players[event.player_index]
    local inv = player.get_inventory(defines.inventory.god_main)
    local all_items = inv.get_contents()
    left_players[player.name] = all_items

    -- Teleport the player to nauvis
    player.set_controller {type = defines.controllers.god}
    player.create_character()
    player.teleport({-35, 55}, "nauvis")

    -- Hide the game gui
    local Main_gui = Gui.get_left_element(player, game_gui)
    Gui.toggle_left_element(player, game_gui, false)

    local table = Main_gui.container["slider"].table
    table.visible = false
end

--- Triggered when a player joins the game
local function player_join(event)
    local player = game.players[event.player_index]
    player.character.destroy()
    local items = left_players[player.name]
    local center = centers[player.name]
    if items and not started[1] then
        player.teleport(center, variables.level.surface)
        player.set_controller {type = defines.controllers.god}
        Gui.toggle_left_element(player, game_gui, true)
        for item, amount in pairs(items) do
            player.insert {name = item, count = amount}
        end
    else
        player.set_controller{ type = defines.controllers.spectator }
        player.teleport(variables.level.center, variables.level.surface)
    end
end

--- When the players balance changes update the gui
Store.watch(balances, function(value, key, _)
    local player = game.players[key]
    local Main_gui = Gui.get_left_element(player, game_gui)
    local table = Main_gui.container["Money"].table
    table["Balance"].caption = value
end)

--- Used to change the game speed using a slider
local speed_slider =
Gui.element {
    type = "slider",
    minimum_value = 1,
    maximum_value = 64,
    value = 4,
    value_step = 1
}
:on_value_changed(function(_, element, _)
    if Mini_games.get_running_game() == "Tight_spot" then
        game.speed = element.slider_value
    end
end)

--- Creates a pair of labels containing a name and a data value
local label_pair =
Gui.element(function(_, parent, name, caption1, caption2)
    parent.add {
        type = "label",
        caption = caption1
    }
    parent.add {
        type = "label",
        caption = caption2,
        name = name
    }
end)

--- The main game gui
game_gui =
Gui.element(function(event_trigger, parent)
    local container = Gui.container(parent, event_trigger, 200)
    Gui.header(container, "Tight spot", "The Tight money manual.", true)

    -- Scroll table used to contain the speed slider
    local scroll_table_slider = Gui.scroll_table(container, 250, 2, "slider")
    scroll_table_slider.add {
        type = "label",
        caption = "Speed:",
        style = "heading_1_label"
    }
    speed_slider(scroll_table_slider)
    scroll_table_slider.visible = false

    -- A the title for the first scroll
    local title1 =
    container.add {
        type = "label",
        caption = "Money:",
        style = "heading_1_label"
    }
    title1.style.left_padding = 7

    -- Set the style for the first scroll table
    local scroll_table_labels = Gui.scroll_table(container, 250, 2, "Money")
    local scroll_table_labels_style = scroll_table_labels.style
    scroll_table_labels_style.top_cell_padding = 3
    scroll_table_labels_style.bottom_cell_padding = 3
    scroll_table_labels_style.left_cell_padding = 7

    -- A the title for the second scroll
    local title2 =
        container.add {
        type = "label",
        caption = "Objective:",
        style = "heading_1_label"
    }
    title2.style.left_padding = 7

    -- Set the style for the second scroll table
    local scroll_table2 = Gui.scroll_table(container, 250, 2, "Objectives")
    local scroll_table2_style = scroll_table2.style
    scroll_table2_style.top_cell_padding = 3
    scroll_table2_style.bottom_cell_padding = 3
    scroll_table2_style.left_cell_padding = 7

    -- Populate the two scroll tables
    label_pair(scroll_table_labels, "Balance",   "Balance: ", "0")
    label_pair(scroll_table_labels, "Debt",      "Debt: ",    "0")
    label_pair(scroll_table_labels, "Time",      "Time: ",    "10:00")
    label_pair(scroll_table2,       "objective", "Type:",     "Iron gear")
    label_pair(scroll_table2,       "prices",    "Price: ",   "15")

    -- Container return
    return container.parent
end)
:add_to_left_flow(false)

--- Add a toolbar button to toggle the main gui
Gui.left_toolbar_button("item/coin", "money", game_gui, function(_)
    return Mini_games.get_running_game() == "Tight_spot"
end)

--- Drop down used to select a level
local dropdown_for_level =
    Gui.element {
    type = "drop-down",
    items = {"level-1", "level-2"},
    selected_index = 1
}:style {
    width = 87
}

--- Drop down used to select a difficulty
local dropdown_for_difficulty =
    Gui.element {
    type = "drop-down",
    items = {"easy", "normal", "hard"},
    selected_index = 1
}:style {
    width = 87
}

--- The gui used to start the game
local main_gui =
Gui.element(function(_, parent)
    local main_flow = parent.add {type = "flow", name = "Tight_flow"}
    dropdown_for_level(main_flow)
    dropdown_for_difficulty(main_flow)
end)

--- Used to read data from the start gui
local function gui_callback(parent)
    local flow = parent["Tight_flow"]
    local args = {}

    local level_dropdown = flow[dropdown_for_level.name]
    local level_config = level_dropdown.selected_index
    args[1] = level_config

    local difficulty_dropdown = flow[dropdown_for_difficulty.name]
    local difficulty_set = difficulty_dropdown.get_item(difficulty_dropdown.selected_index)
    args[2] = difficulty_set

    return args
end

--- Register the mini game to the mini game module
local tight = Mini_games.new_game("Tight_spot")
tight:add_map("nauvis", 0, 0)
tight:set_start_function(start)
tight:set_stop_function(stop)
tight:add_option(2)

tight:add_event(defines.events.on_built_entity, placed_entity)
tight:add_event(defines.events.on_market_item_purchased, market)
tight:add_event(defines.events.on_player_mined_entity, mined)
tight:add_event(defines.events.on_player_changed_position, player_move)
tight:add_event(defines.events.on_pre_player_left_game, on_player_left_game)
tight:add_event(defines.events.on_player_joined_game, player_join)
tight:add_on_nth_tick(100, check_chest)
tight:add_on_nth_tick(60, timer)

tight:set_gui_callback(gui_callback)
tight:set_gui_element(main_gui)