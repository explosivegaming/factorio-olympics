local Mini_games = require "expcore.Mini_games"
local Global = require "utils.global" --Used to prevent desynicing.
local Gui = require "expcore.gui._require"
local config = require "config.mini_games.tight_spot"
local tight = Mini_games.new_game("Tight_spot")
local walls
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


local function player_join_game(player)
    local character = player.character
    player.set_controller {type = defines.controllers.god}
    if character then
        character.destroy()
    end
    local playerforce = player.force
    playerforce.manual_mining_speed_modifier = 1000

end

local function start(args)
    local level_index = args[1]
    local level = config[level_index]
    local diffuclty = args[2]

    for i, player in ipairs(game.connected_players) do
        player_join_game(player)
    end

    local surface = game.surfaces[level["surface"]]
    walls = surface.find_entities_filtered {name = "stone-wall"}

    local market = game.get_entity_by_tag("market")
    market.clear_market_items()
    for i,item in ipairs(level.items) do
        local offer = {price = {{"coin", tightspot_prices[item]}}, offer = {type = "give-item", item = item}}
        market.add_market_item(offer)
    end


end

local function placed_entety(event)
    local entity = event.created_entity
    if not entity.name == "stone-wall" then
        entity.active = false
    else
        --land stuffs
    end
end

--gui

local dorpdown_for_level = 
Gui.element{
    type = 'drop-down',
    items = {"level-1","level-2"},
    selected_index = 1
}
:style{
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

    local dorpdown_for_level = flow[dorpdown_for_level.name]
    local level = dorpdown_for_level.selected_index
    game.print(level)
    args[1] = level
    local dorpdown_for_difficulty = flow[dorpdown_for_difficulty.name]
    local diffuclty = dorpdown_for_difficulty.get_item(dorpdown_for_difficulty.selected_index)
    args[2] = diffuclty

    return args
end
tight:add_event(defines.events.on_built_entity, placed_entety)
tight:add_map("tigth_spot", 0, 0)
tight:add_start_function(start)
tight:add_gui_callback(gui_callback)
tight:add_gui_element(maingui)
tight:add_option(2)

--[[
Todo 
game tight_spot 
    make compatble with the already present levels (found in C:\Program Files (x86)\Steam\steamapps\common\Factorio\data\base\campaigns\tight-spot\)
mini_game module
    make docs
    add multi server 
        decide what module to use 
        make server communicate
        foward players
    allow for easier use (not nessary)
belt maddnes
    create shood be camtable with already present levels 
race game 
    fix bug where if players crash at the same position the spawn inside each other
    dont allow players to take fuel out of other cars
]]