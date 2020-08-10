local Mini_games   = require 'expcore.Mini_games'
local Global       = require 'utils.global'

local config = require("config")
local map_sets = require("map_sets")
local map_scripts = require("map_scripts")
local mod_gui = require("mod-gui")
local util = require("util")

local offsets =
{
  {-1, -1},
  {0, -1},
  {1, -1},
  {1, 0},
  {1, 1},
  {0, 1},
  {-1, 1},
  {-1, 0},
}

local area_radius = 3
local gap = 2

local game_state =
{
  in_round = 1,
  intermission = 2
}

local script_data =
{
  online_players = {},
  winners = {},
  points = {},
  recent_points = {},
  chests = {},
  input_chests = {},
  round_number = 0,
  recent_round_number = 0,
  game_state = game_state.intermission,
  number_of_teams = #offsets
}

Global.register(script_data, function(tbl)
  script_data = tbl
end)

----- Util Functions -----

local function time_left()
  return game.tick - script_data.round_timer_value
end

local function lighten(c)
  return {r = 1 - (1 - c.r) * 0.5, g = 1 - (1 - c.g) * 0.5, b = 1 - (1 - c.b) * 0.5, a = 1}
end

local function get_spawn_coordinate(n)
  return offsets[n]
end

local function format_time(ticks)
  local raw_seconds = ticks / 60
  local minutes = math.floor(raw_seconds/60)
  local seconds = math.floor(raw_seconds - 60*minutes)
  return string.format("%d:%02d", minutes, seconds)
end

local function shuffle_table(t)
  local count = 2
  local math = math
  local player = game.connected_players[math.random(#game.connected_players)]
  if player then
    count = (math.random(1 + string.len(player.name) + math.ceil(math.abs(player.position.x + player.position.y))) % 16) + 1
  end
  for k = 1, count do
    local iterations = #t
    for i = iterations, 2, -1 do
      local j = math.random(i)
      t[i], t[j] = t[j], t[i]
    end
  end
end

local function spairs(t, order)
  local keys = {}
  for k in pairs(t) do keys[#keys+1] = k end
  if order then
    table.sort(keys, function(a, b) return order(t, a, b) end)
  else
    table.sort(keys)
  end

  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], t[keys[i]]
    end
  end
end

local function select_from_probability_table(probability_table)
  local roll_max = 0
  for _, item in pairs(probability_table) do
    roll_max = roll_max + item.probability
  end

  local roll_value = math.random(0, roll_max - 1)
  for _, item in pairs(probability_table) do
    roll_value = roll_value - item.probability
    if (roll_value < 0) then
      return item.value
    end
  end
end

----- Game Start -----

local chest_offset = {0, 2}
local function make_starting_chests()

  local items = script_data.starting_inventories[script_data.round_inventory]
  if not items then return end

  local item_prototypes = game.item_prototypes

  local surface = game.surfaces[1]

  for _, team in pairs (script_data.force_list) do

    local force = game.forces[team.name]
    local position = force.get_spawn_position(surface)
    position.x = position.x + chest_offset[1]
    position.y = position.y + chest_offset[2]

    local chest_position = surface.find_non_colliding_position("steel-chest", position, 16, 1)

    if position then
      local chest = surface.create_entity{name = "steel-chest", position = chest_position, force = force}
      for _, item in pairs (items) do
        if item_prototypes[item.name] then
          chest.insert(item)
        end
      end
    end

  end

end

local function generate_production_task()

  local number_of_items = math.random(script_data.max_count_of_production_tasks)
  local max_count = math.ceil(math.random(5) / number_of_items)
  local min_count = script_data.challenge_type == "shopping_list" and 3 or 1
  if script_data.challenge_type == "shopping_list" then max_count = (max_count * 2) + 3 end
  local items_to_choose = script_data.item_list
  shuffle_table(items_to_choose)
  local task_items = {}
  script_data.round_input = nil
  for k = 1, number_of_items do
    local item = items_to_choose[k]
    if item.input then
      if not script_data.round_input then
        script_data.round_input = item.input
      else
        break
      end
    end
    task_items[k] = {}
    task_items[k].name = item.name
    task_items[k].count = math.random(min_count, max_count) * script_data.item_list[k].count
    task_items[k].remaining = script_data.challenge_type == "shopping_list" and task_items[k].count or nil
  end
  script_data.task_items = task_items
  script_data.progress = {}
  for j, force in pairs (game.forces) do
    script_data.progress[force.name] = {}
    for k, item in pairs (script_data.task_items) do
      script_data.progress[force.name][item.name] = 0
    end
  end

end

local function fill_input_chests()
  if not script_data.input_chests then return end
  if not script_data.round_input then return end
  if not game.item_prototypes[script_data.round_input] then game.print("BAD INPUT ITEM") return end
  for k, chest in pairs (script_data.input_chests) do
    if chest.valid then
      chest.clear_items_inside()
      chest.insert{name = script_data.round_input, count = 10000}
    else
      table.remove(script_data.input_chests, k)
    end
  end
end

local function chart_all()
  for k, force in pairs (game.forces) do
    force.chart_all()
  end
end

local function select_inventory() return select_from_probability_table(script_data.inventory_probabilities) end

local function select_equipment() return select_from_probability_table(script_data.equipment_probabilities) end

local function select_challenge_type() return select_from_probability_table(script_data.challange_type_probabilities) end

local function start_challenge()

  script_data.game_state = game_state.in_round

  script_data.winners = {}
  script_data.round_number = script_data.round_number + 1

  if script_data.recent_round_number == script_data.recent_round_count then
    script_data.recent_round_number = 0
    script_data.recent_points = {}
    game.reset_time_played()
  end

  script_data.recent_round_number = script_data.recent_round_number + 1
  script_data.round_timer_value = game.tick
  script_data.winners = {}
  script_data.force_points = {}

  script_data.round_inventory = select_inventory()
  script_data.round_equipment = select_equipment()
  script_data.challenge_type = select_challenge_type()

  make_starting_chests()

  generate_production_task()
  fill_input_chests()

  chart_all()
  game.play_sound{path = "utility/research_completed"}

end

----- Game Init -----

local function setup_unlocks(force)
  if not force.valid then return end
  force.research_all_technologies()
  local disallowed_map = {}
  for k, name in pairs (script_data.disabled_items) do
    disallowed_map[name] = true
  end
  for recipe_name, recipe in pairs (force.recipes) do
    if disallowed_map[recipe_name] then
      recipe.enabled = false
    end
  end
end

local function create_teams()
  for k, force_data in pairs(script_data.force_list) do
    if not game.forces[force_data.name] then
      local force = game.create_force(force_data.name)
      setup_unlocks(force)
      force.disable_research()
      force.set_ammo_damage_modifier("bullet", -1)
      force.set_ammo_damage_modifier("flamethrower", -1)
      force.set_ammo_damage_modifier("capsule", -1)
      force.set_ammo_damage_modifier("cannon-shell", -1)
      force.set_ammo_damage_modifier("grenade", -1)
      force.set_ammo_damage_modifier("electric", -1)
      force.worker_robots_speed_modifier = 3
    end
  end
  for k, force in pairs (game.forces) do
    for j, friend in pairs (game.forces) do
      if force.name ~= friend.name then
        force.set_cease_fire(friend, true)
        force.set_friend(friend, true)
      end
    end
  end
end

----- Team Selection -----

local function set_character(player, force)
  if not player.connected then return end
  if not force.valid then return end
  if player.character then player.character.destroy() end
  player.force = force
  local character = player.surface.create_entity{name = "character", position = player.surface.find_non_colliding_position("character", player.force.get_spawn_position(player.surface), 10, 2), force = force}
  player.set_controller{type = defines.controllers.character, character = character}
end

local function give_equipment(player)
  if not player.connected then return end
  if not player.character then return end
  if not script_data.round_equipment then return end

  if script_data.round_equipment == "small" then
    player.insert{name = "power-armor", count = 1}
    local p_armor = player.get_inventory(5)[1].grid
    p_armor.put({name = "fusion-reactor-equipment"})
    p_armor.put({name = "exoskeleton-equipment"})
    p_armor.put({name = "personal-roboport-mk2-equipment"})
    player.insert{name="construction-robot", count = 25}
    return
  end
end

local function set_player(player, team, print)
  local character = player.character
  player.character = nil
  player.associate_character(character)
  character.color = player.color
  character.walking_state = {walking = false}
  local force = game.forces[team.name]
  set_character(player, force)
  give_equipment(player)
  player.color = team.color
  if print then
    game.print({"joined-team", player.name, {"color."..team.name}})
  end
end

-- luacheck:ignore 211/check_color_areas
local function check_color_areas(print)

  local surface = game.surfaces[1]
  for _, team in pairs (script_data.force_list) do
    for _, character in pairs (surface.find_entities_filtered{area = {}--[[get_team_pad_area(k)]], type = "character"}) do
      if character.player then

        character.player.color = team.color
        character.player.chat_color = lighten(team.color)

        if script_data.game_state == game_state.in_round then
          set_player(character.player, team, print)
          --update_gui()
        end

      end
    end

  end
end

----- Gui Updates -----

local function update_winners_list(player)
  local gui = mod_gui.get_frame_flow(player)
  local frame = gui.winners_frame
  if not script_data.winners then return end
  if #script_data.winners == 0 then
    if frame then frame.destroy() end
    return
  end

  if not script_data.end_round_tick then
    if frame then frame.destroy() end
    return
  end

  if not script_data.force_points then return end

  if not frame then
    frame = gui.add{type = "frame", name = "winners_frame", caption = {"winner-end-round", format_time(script_data.end_round_tick - game.tick)}, direction = "vertical"}
    local winners_table = frame.add{type = "table", name = "winners_table", column_count = 5}
    winners_table.style.column_alignments[4] = "right"
    winners_table.style.column_alignments[5] = "right"
    winners_table.style.horizontal_spacing = 8
    for k, caption in pairs ({"", "name", "members", "time", "points"}) do
      local label = winners_table.add{type = "label", caption = {caption}}
      label.style.font = "default-bold"
    end
  end

  for k, force in pairs(script_data.winners) do
    if k > 5 then break end
    if not script_data.force_points[force.name] then break end
    if not gui.winners_frame.winners_table[force.name] then

      local winners_table = gui.winners_frame.winners_table
      local place = winners_table.add{type = "label", caption = "#"..k}
      place.style.font = "default-semibold"
      place.style.font_color = {r = 1, g = 1, b = 0.2}
      local this = winners_table.add{type = "label", name = force.name, caption = {"", {"color."..force.name}, " ", {"team"}}}
      local color = {r = 0.8, g = 0.8, b = 0.8, a = 0.8}

      for i, check_force in pairs (script_data.force_list) do
        if force.name == check_force.name then
          color = lighten(check_force.color)
          break
        end
      end

      this.style.font_color = color
      local caption = ""
      local count = 0
      for j, next_player in pairs(force.connected_players) do
        count = count + 1
        if count == 1 then
          caption = caption..next_player.name
        else
          caption = caption..", "..next_player.name
        end
      end
      local players_label = winners_table.add{type = "label", caption = caption}
      players_label.style.single_line = false
      players_label.style.maximal_width = 300
      winners_table.add{type = "label", caption = format_time(time_left())}
      winners_table.add{type = "label", caption = script_data.force_points[force.name]}
    end
  end
end

local function update_task_table(player)
  local gui = mod_gui.get_frame_flow(player)
  local frame = gui.task_frame

  if not frame then return end
  frame.clear()

  frame.caption = {"round", script_data.recent_round_number, script_data.recent_round_count}
  local task = script_data.challenge_type
  if script_data.start_round_tick ~= nil then
    frame.add{type = "label", caption = {"round-starting-soon", format_time(script_data.start_round_tick - game.tick)}}
    return
  end
  frame.add{type = "label", caption = {task}, style = "caption_label"}
  frame.add{type = "label", name = "round_timer", caption = {"elapsed-time", format_time(time_left())}}

  local inner = frame.add{type = "frame", style = "inside_deep_frame"}
  inner.style.left_padding = 8
  inner.style.top_padding = 8
  inner.style.right_padding = 8
  inner.style.bottom_padding = 8

  local spectating = player.force.name == "player"

  local task_table = inner.add{type = "table", column_count = spectating and 2 or 3}

  task_table.draw_horizontal_line_after_headers = true
  task_table.draw_vertical_lines = true

  task_table.style.horizontal_spacing = 8
  task_table.style.vertical_spacing = 8
  task_table.style.column_alignments[2] = "right"
  task_table.style.column_alignments[3] = "right"

  local headers
  local table_string

  if task == "production" then
    headers = {"item-name", "current", "goal"}
    table_string = "count"
  elseif task == "shopping_list" then
    headers = {"item-name", "current", "remaining"}
    table_string = "remaining"
  else
    error("Unknown task type: "..task)
  end

  if spectating then
    table.remove(headers, 2)
  end

  for k, caption in pairs (headers) do
    local label = task_table.add{type = "label", caption = {caption}}
    label.style.font = "default-bold"
  end

  local progress = script_data.progress[player.force.name]
  if not progress then error("force progress is nil: "..player.force.name) end
  local items = game.item_prototypes
  for k, item in pairs (script_data.task_items) do
    local label = task_table.add{type = "label", caption = items[item.name].localised_name}
    label.style.font = "default-semibold"
    if not spectating then
      task_table.add{type = "label", caption = util.format_number(progress[item.name])}
    end
    task_table.add{type = "label", caption = util.format_number(item[table_string])}
  end
end

local function update_end_timer(player)
  if not player.connected then return end
  if not script_data.end_round_tick then return end
  local gui = mod_gui.get_frame_flow(player)
  if not gui.winners_frame then return end
  gui.winners_frame.caption = {"winner-end-round", format_time(script_data.end_round_tick - game.tick)}
end

local function update_player_gui(player)
  update_end_timer(player)
  update_task_table(player)
  update_winners_list(player)
end

local function update_gui()
  for k, player in pairs(game.connected_players) do
    update_player_gui(player)
  end
end

----- Check Victory -----

local function update_player_tags()
  local count = 1
  local players = game.players
  for name in spairs(script_data.points, function(t, a, b) return t[b] < t[a] end) do
    local player = players[name]
    if player then
      player.tag = "[#"..count.."]"
    end
    count = count + 1
  end
end

local function give_force_players_points(force, points)
  if not force.valid then return end
  if points <= 0 then return end
  if not script_data.force_points then script_data.force_points = {} end

  if not script_data.force_points[force.name] then
    script_data.force_points[force.name] = points
  else
    script_data.force_points[force.name] = script_data.force_points[force.name] + points
  end

  for k, player in pairs (force.players) do
    if not script_data.points[player.name] then
      script_data.points[player.name] = points
    else
      script_data.points[player.name] = script_data.points[player.name] + points
    end

    if not script_data.recent_points[player.name] then
      script_data.recent_points[player.name] = points
    else
      script_data.recent_points[player.name] = script_data.recent_points[player.name] + points
    end
  end
  update_player_tags()
end

local function team_finished(force)
  if not force.valid then return end
  if not script_data.progress then return end
  if not script_data.progress[force.name] then return end

  table.insert(script_data.winners, force)
  local points = script_data.points_per_win

  for j, winning_force in pairs (script_data.winners) do
    if winning_force == force then
      points = math.floor(points/j)
      break
    end
  end

  if #script_data.winners == 1 then
    script_data.end_round_tick = game.tick + script_data.time_before_round_end
  end

  give_force_players_points(force, points)
  for k, player in pairs(game.players) do
    if player.force ~= force then
      player.print({"finished-task", {"color."..force.name}})
      player.play_sound({path = "utility/game_lost"})
    else
      player.print({"your-team-win", script_data.force_points[force.name]})
      player.play_sound({path = "utility/game_won"})
    end
  end
end

local function calculate_force_points(force,item, points)
  if points <= 0 then return end
  if not script_data.progress then return end
  if not script_data.progress[force.name] then return end
  if not script_data.progress[force.name][item.name] then return end
  if not item.count then return end
  if script_data.progress[force.name][item.name] <= 0 then return end
  local count = script_data.progress[force.name][item.name]
  local total = item.count
  local awarded_points = math.floor((count/total)*points)
  give_force_players_points(force, awarded_points)
end

local function shopping_task_finished()
  local total_points = script_data.points_per_win * script_data.number_of_teams
  local points_per_task = total_points/(#script_data.task_items)
  for k, item in pairs (script_data.task_items) do
    for j, force in pairs (game.forces) do
      calculate_force_points(force, item, points_per_task)
    end
  end

  for name, points in spairs(script_data.force_points, function(t, a, b) return t[b] < t[a] end) do
    if points > 0 then
      table.insert(script_data.winners, game.forces[name])
    end
  end
  script_data.end_round_tick = game.tick + 1
  for k, player in pairs (game.players) do
    update_winners_list(player)
  end
end

local function check_victory(force)
  if not script_data.challenge_type then return end
  if not force.valid then return end
  if not script_data.winners then return end

  for k, winners in pairs (script_data.winners) do
    if force == winners then
      return
    end
  end

  local challenge_type = script_data.challenge_type

  if challenge_type == "production" then
    local finished_tasks = 0
    for k, item in pairs (script_data.task_items) do
      if script_data.progress[force.name][item.name] >= item.count then
        finished_tasks = finished_tasks +1
      end
    end
    if finished_tasks >= #script_data.task_items then
      team_finished(force)
    end
    return
  end

  if challenge_type == "shopping_list" then
    if script_data.winners[1] then return end
    local finished_tasks = 0
    for k, item in pairs (script_data.task_items) do
      if item.remaining == 0 then
        finished_tasks = finished_tasks +1
      end
    end
    if finished_tasks >= #script_data.task_items then
      shopping_task_finished()
    end
    return
  end
end

----- Check Chests -----

local function check_chests_production(chest)
  if not script_data.task_items then return end
  for k, item in pairs (script_data.task_items) do
    local count = chest.get_item_count(item.name)
    if count + script_data.progress[chest.force.name][item.name] > item.count then
      count = item.count - script_data.progress[chest.force.name][item.name]
    end
    if count > 0 then
      chest.remove_item({name = item.name, count = count})
      script_data.progress[chest.force.name][item.name] = script_data.progress[chest.force.name][item.name] + count
    end
  end
end

local function check_chests_shopping_list(chest)
  if not script_data.task_items then return end
  for k, item in pairs (script_data.task_items) do
    local count = chest.get_item_count(item.name)
    if count > item.remaining then
      count = item.remaining
    end
    if count > 0 then
      chest.remove_item({name = item.name, count = count})
      script_data.progress[chest.force.name][item.name] = script_data.progress[chest.force.name][item.name] + count
      item.remaining = item.remaining - count
    end
  end
end

local function check_chests()
  if not script_data.chests then return end

  local task = script_data.challenge_type
  if not task then return end

  local update_chest

  if task == "production" then
    update_chest = check_chests_production
  elseif task == "shopping_list" then
    update_chest = check_chests_shopping_list
  else
    error("Unknown challenge type: "..task)
  end

  for k, chest in pairs (script_data.chests) do
    if not chest.valid then
      script_data.chests[k] = nil
    else
      update_chest(chest)
    end
  end
  for k, force in pairs (game.forces) do
    check_victory(force)
  end
end

----- Round Start and End -----

local function get_team_pad_position(index)
  local offset = offsets[index]
  local origin =
  {
    offset[1] * ((area_radius * 2) + gap),
    offset[2] * ((area_radius * 2) + gap)
  }
  return origin
end

local function set_spectator(player)
  if not player.connected then return end

  local character = player.character
  if character then
    character.destroy()
  end

  player.set_controller{type = defines.controllers.god}
  player.force = "player"

  local characters = player.get_associated_characters()
  if characters[1] then
    player.character = characters[1]
  else
    player.teleport(player.force.get_spawn_position(game.surfaces[1]))
    player.create_character()
  end

end

local function check_end_of_round()
  if game.tick ~= script_data.end_round_tick then return end

  script_data.game_state = game_state.intermission

  check_chests()

  script_data.end_round_tick = nil
  script_data.start_round_tick = game.tick + script_data.time_between_rounds
  script_data.chests = nil
  script_data.input_chests = nil
  script_data.task_items = nil
  script_data.progress = nil
  script_data.challenge_type = nil

  for k, team in pairs (script_data.force_list) do
    local force = game.forces[team.name]
    force.set_spawn_position(get_team_pad_position(k), game.surfaces[1])
  end

  for k, player in pairs(game.players) do
    set_spectator(player)
    update_player_gui(player)
    local gui = mod_gui.get_frame_flow(player)
    if gui.winners_frame then
      gui.winners_frame.caption = {"round-winners"}
    end
  end

  game.print({"next-round-soon", (script_data.time_between_rounds / 60)})
  game.play_sound{path = "utility/research_completed"}

end

local function check_start_round()
  if game.tick ~= script_data.start_round_tick then return end
  script_data.start_round_tick = nil
  start_challenge()
  for k, player in pairs(game.players) do
    update_player_gui(player)
  end
end

----- Map Gen -----

local function set_areas(i)
  if not script_data.previous_map_size then
    script_data.previous_map_size = 5
  else
    script_data.previous_map_size = map_sets[script_data.current_map_index].map_set_size
  end
  script_data.previous_map_index = script_data.current_map_index
  script_data.current_map_index = i
  if not map_sets[i] then return end

  script_data.clear_areas_tick = game.tick + script_data.number_of_teams + 1
end

local function check_start_set_areas()
  if not script_data.start_round_tick then return end
  --Calculates when to start settings the areas
  if script_data.start_round_tick - ((2 * script_data.number_of_teams) + 1 + ((script_data.number_of_teams) * script_data.ticks_to_generate_entities)) == game.tick then
    set_areas(math.random(#map_sets))
  end
end

local function check_start_setting_entities()
  --Start setting the entities
  if not script_data.set_entities_tick then return end
  local entities = map_sets[script_data.current_map_index].map_set_entities
  local distance = map_sets[script_data.current_map_index].map_set_size
  local index = math.ceil((script_data.set_entities_tick - game.tick)/script_data.ticks_to_generate_entities)
  if index == 0 then
    script_data.set_entities_tick = nil
    return
  end
  local listed = script_data.force_list[index]
  if not listed then return end

  local grid_position = get_spawn_coordinate(index)
  local force = game.forces[listed.name]
  local offset_x = grid_position[1] * (distance*2 + script_data.distance_between_areas)
  local offset_y = grid_position[2] * (distance*2 + script_data.distance_between_areas)
  map_scripts.recreate_entities(entities, offset_x, offset_y, force, script_data.ticks_to_generate_entities, script_data)
end

local function check_set_areas()
  if not script_data.set_areas_tick then return end
  local set = map_sets[script_data.current_map_index]
  local distance = set.map_set_size
  local index = script_data.set_areas_tick - game.tick

  if index == 0 then
    script_data.set_areas_tick = nil
    script_data.set_entities_tick = game.tick + (script_data.number_of_teams * script_data.ticks_to_generate_entities)
    return
  end
  local listed = script_data.force_list[index]
  if not listed then return end

  local grid_position = get_spawn_coordinate(index)
  local force = game.forces[listed.name]

  if not force then
    game.print(listed.name.." is not a valid force")
    return
  end

  if not force.valid then return end
  local offset_x = grid_position[1] * (distance * 2 + script_data.distance_between_areas)
  local offset_y = grid_position[2] * (distance * 2 + script_data.distance_between_areas)
  map_scripts.create_tiles(set.map_set_size, set.map_set_tiles, offset_x, offset_y, false, script_data.distance_between_areas)
  force.set_spawn_position({offset_x, offset_y}, game.surfaces[1])
  force.rechart()
end

local function check_clear_areas()
  if not script_data.clear_areas_tick then return end
  if not script_data.previous_map_index then
    script_data.previous_map_index = 1
  end
  local set = map_sets[script_data.previous_map_index]
  local distance = set.map_set_size
  local index = script_data.clear_areas_tick - game.tick
  if index == 0 then
    script_data.clear_areas_tick = nil
    script_data.set_areas_tick = game.tick + script_data.number_of_teams
    return
  end
  local grid_position = get_spawn_coordinate(index)
  local offset_x = grid_position[1] * (distance * 2 + script_data.distance_between_areas)
  local offset_y = grid_position[2] * (distance * 2 + script_data.distance_between_areas)
  map_scripts.clear_tiles(set.map_set_size, offset_x, offset_y, script_data.distance_between_areas)
end

----- Events -----

local function create_task_frame(player)
  local gui = mod_gui.get_frame_flow(player)
  local frame = gui.task_frame
  if frame then
    frame.destroy()
  end
  gui.add{name = "task_frame", type = "frame", direction = "vertical", caption = {"round", script_data.recent_round_number, script_data.recent_round_count}}
  update_task_table(player)
end

local function is_in_area(entity, force)
  local origin = force.get_spawn_position(entity.surface)
  local position = entity.position
  local max_distance = map_sets[script_data.current_map_index].map_set_size
  if origin.x + max_distance < position.x or
  origin.x - max_distance > position.x or
  origin.y + max_distance < position.y or
  origin.y - max_distance > position.y then
    return false
  end
  return true
end

local on_player_created = function(event)
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end

  set_spectator(player)
  create_task_frame(player)
  update_player_gui(player)
  update_player_tags()
  player.spectator = true
end

--[[local on_player_joined_game = function(event)
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end

  set_spectator(player)
  update_player_gui(player)
  update_player_tags()
end]]

local on_pre_player_left_game = function(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end

  if script_data.game_state == game_state.in_round then
    -- We are in a round, kill his character so he doesn't leave with all the machines.
    local character = player.character
    player.character = nil
    if character then
      if player.force == "player" then
        character.destroy()
      else
        character.die()
        local corpse = player.surface.find_entities_filtered{type = "character-corpse", position = player.position}[1]
        if corpse then
          corpse.character_corpse_player_index = player.index
        end
      end
    end
    for k, next_character in pairs (player.get_associated_characters()) do
      next_character.destroy()
    end
    set_spectator(player)
  end

end

local on_tick = function()
  check_end_of_round()
  check_clear_areas()
  check_set_areas()
  check_start_setting_entities()
  check_start_set_areas()
  check_start_round()
end

local on_built_entity = function(event)
  local entity = event.created_entity
  if not (entity and entity.valid) then return end
  local force = entity.force
  if not is_in_area(entity, force) then
    entity.destroy()
  end
end

local on_marked_for_deconstruction = function(event)
  local player = game.players[event.player_index]
  local entity = event.entity
  if not (player and player.valid and entity and entity.valid) then return end
  local force = player.force
  if not is_in_area(entity, force) then
    entity.cancel_deconstruction(force)
  end
end

local team_production = Mini_games.new_game('Production Challenge')
team_production:add_event(defines.events.on_player_created, on_player_created)
team_production:add_event(defines.events.on_pre_player_left_game, on_pre_player_left_game)
team_production:add_event(defines.events.on_tick, on_tick)
team_production:add_event(defines.events.on_built_entity, on_built_entity)
team_production:add_event(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)

team_production:add_nth_tick(301, chart_all)
team_production:add_nth_tick(29, check_chests)
team_production:add_nth_tick(997, fill_input_chests)
team_production:add_nth_tick(60, update_gui)

local chunk_size = 10
team_production.on_init = function()

  local surface = game.surfaces[1]
  local settings = surface.map_gen_settings
  settings.width = chunk_size * 32 * 2
  settings.height = chunk_size * 32 * 2
  surface.map_gen_settings = settings

  for x = -chunk_size, chunk_size do
    for y = -chunk_size, chunk_size do
      surface.set_chunk_generated_status({x, y}, defines.chunk_generated_status.entities)
    end
  end

  global.team_production = global.team_production or script_data
  config.setup_config(script_data)
  create_teams()

  script_data.points = {}
  script_data.recent_points = {}
  update_gui()

  game.surfaces[1].always_day = true
  game.map_settings.pollution.enabled = false

  game.forces.player.disable_research()
  for k, recipe in pairs (game.forces.player.recipes) do
    recipe.enabled = false
  end

end