local Mini_games   = require 'expcore.Mini_games'
local Global       = require 'utils.global'
local Gui          = require 'expcore.gui._require'
local TeamSelector = require 'modules.gui.mini_game_team_selector'

local config      = require("config.mini_games.team_production")
local map_sets    = require("modules.mini-games.team_production.map_sets")
local map_scripts = require("modules.mini-games.team_production.map_scripts")
local mod_gui     = require("mod-gui")
local util        = require("util")

config.teams = {}
for _, force_data in ipairs(config.force_list) do
  config.teams[force_data.name] = force_data
end

config.disallowed_map = {}
for _, name in ipairs(config.disabled_items) do
  config.disallowed_map[name] = true
end

local script_data =
{
  winners = {},
  points = {},
  output_chests = {},
  input_chests = {},
  task_items = {},
  progress = {},
  forces = {}
}

Global.register(script_data, function(tbl)
  script_data = tbl
end)

----- Util Functions -----

--- Internal, Used to clear tables of all values
local function reset_table(table)
  for k in pairs(table) do
      table[k] = nil
  end
end

--- Internal, Reset all global tables
local function reset_globals()
  reset_table(script_data.winners)
  reset_table(script_data.points)
  reset_table(script_data.output_chests)
  reset_table(script_data.input_chests)
  reset_table(script_data.task_items)
  reset_table(script_data.progress)
  reset_table(script_data.forces)
end

--- Returns the amount of time till the end of the round
local function time_left()
  return game.tick - Mini_games.get_start_time()
end

--- Returns a colour that is a bit lighter than the one given
local function lighten(c)
  return {r = 1 - (1 - c.r) * 0.5, g = 1 - (1 - c.g) * 0.5, b = 1 - (1 - c.b) * 0.5, a = 1}
end

--- Formats ticks into minutes and seconds
local function format_time(ticks)
  local raw_seconds = ticks / 60
  local minutes = math.floor(raw_seconds/60)
  local seconds = math.floor(raw_seconds - 60*minutes)
  return string.format("%d:%02d", minutes, seconds)
end

--- Shuffles a table based on random input from player name and position
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

--- Selects a random entry from a probability table
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

----- Gui Updates -----

--- Updates / Creates the winners list gui in the left flow
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

  if not script_data.points then return end

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
    if not script_data.points[force.name] then break end
    if not gui.winners_frame.winners_table[force.name] then

      local winners_table = gui.winners_frame.winners_table
      local place = winners_table.add{type = "label", caption = "#"..k}
      place.style.font = "default-semibold"
      place.style.font_color = {r = 1, g = 1, b = 0.2}
      local this = winners_table.add{type = "label", name = force.name, caption = {"", {"color."..force.name}, " ", {"team"}}}
      local color = {r = 0.8, g = 0.8, b = 0.8, a = 0.8}

      for i, check_force in pairs (config.force_list) do
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
      winners_table.add{type = "label", caption = script_data.points[force.name]}
    end
  end
end

local update_task_table
--- Main container for the task list
-- @element task_frame
local task_frame =
Gui.element(function(event_trigger, parent)
  local frame = parent.add{
    type = 'frame',
    name = event_trigger,
    direction = 'vertical'
  }

  local player = Gui.get_player_from_element(parent)
  update_task_table(player)

  return frame
end)
:add_to_left_flow()

--- Button on the top flow used to toggle the player list container
-- @element toggle_left_element
Gui.left_toolbar_button('utility/not_enough_repair_packs_icon', 'Production Task List', task_frame, function()
    return Mini_games.get_running_game() == 'Production Challenge'
end)

--- Updates the task table gui in left flow
function update_task_table(player)
  local frame = Gui.get_left_element(player, task_frame)
  frame.clear()

  local task = script_data.challenge_type
  if not task then return end
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

--- Updates the timer on the winner gui as the round is ending
local function update_end_timer(player)
  if not player.connected then return end
  if not script_data.end_round_tick then return end
  local gui = mod_gui.get_frame_flow(player)
  if not gui.winners_frame then return end
  gui.winners_frame.caption = {"winner-end-round", format_time(script_data.end_round_tick - game.tick)}
end

--- Updates all the guis for a player
local function update_player_gui(player)
  update_task_table(player)
  update_winners_list(player)
  update_end_timer(player)
end

--- Updates all guis for all players
local function update_gui()
  for k, player in pairs(game.connected_players) do
    update_player_gui(player)
  end
end

----- Game Init -----

--- Disables selected recipes for a force
local function disable_recipes(force)
  if not force.valid then return end
  force.research_all_technologies()
  for recipe_name, recipe in pairs (force.recipes) do
    if config.disallowed_map[recipe_name] then
      recipe.enabled = false
    end
  end
end

--- Create all the teams needed for the game
local function create_teams(limit)
  -- Create all the forces
  for k, force_data in pairs(config.force_list) do
    if k > limit then return end
    local force = game.create_force(force_data.name)
    disable_recipes(force)
    force.disable_research()
    force.set_ammo_damage_modifier("bullet", -1)
    force.set_ammo_damage_modifier("flamethrower", -1)
    force.set_ammo_damage_modifier("capsule", -1)
    force.set_ammo_damage_modifier("cannon-shell", -1)
    force.set_ammo_damage_modifier("grenade", -1)
    force.set_ammo_damage_modifier("electric", -1)
    force.worker_robots_speed_modifier = 3
    script_data.forces[k] = force
  end
  -- Set the forces to be friends and have cease fire
  for _, force in ipairs (script_data.forces) do
    for _, friend in ipairs (script_data.forces) do
      if force.name ~= friend.name then
        force.set_cease_fire(friend, true)
        force.set_friend(friend, true)
      end
    end
  end
end

local chunk_size = 10
--- First function called by mini game core in order to setup for the game starting
local function init(args)

  local team_count = tonumber(args[1])
  if not team_count or team_count < 1 then Mini_games.error_in_game('Team count is invalid') end
  script_data.number_of_teams = team_count
  create_teams(team_count)

  local surface = game.create_surface('Team Production')
  local settings = surface.map_gen_settings
  settings.width = chunk_size * 32 * 2
  settings.height = chunk_size * 32 * 2
  surface.map_gen_settings = settings
  script_data.surface = surface

  for x = -chunk_size, chunk_size do
    for y = -chunk_size, chunk_size do
      surface.set_chunk_generated_status({x, y}, defines.chunk_generated_status.entities)
    end
  end

  surface.always_day = true
  game.map_settings.pollution.enabled = false

  script_data.current_map_index = math.random(#map_sets)
  script_data.set_areas_tick = game.tick + script_data.number_of_teams

end

----- Game Start -----

local chest_offset = {0, 2}
--- Makes a chest to contain the starting items for a force
local function make_starting_chests()

  local items = config.starting_inventories[script_data.round_inventory]
  if not items then return end

  local item_prototypes = game.item_prototypes

  local surface = script_data.surface

  for _, force in ipairs (script_data.forces) do

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

--- Sets up the round_input, task_items and progress for this round
local function generate_production_task()

  local number_of_items = math.random(config.max_count_of_production_tasks)
  local max_count = math.ceil(math.random(5) / number_of_items)
  local min_count = script_data.challenge_type == "shopping_list" and 3 or 1
  if script_data.challenge_type == "shopping_list" then max_count = (max_count * 2) + 3 end
  local items_to_choose = table.deep_copy(config.item_list)
  shuffle_table(items_to_choose)

  local task_items = script_data.task_items
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
    task_items[k].count = math.random(min_count, max_count) * config.item_list[k].count
    task_items[k].remaining = script_data.challenge_type == "shopping_list" and task_items[k].count or nil
  end

  for j, force in pairs (game.forces) do
    script_data.progress[force.name] = {}
    for k, item in pairs (script_data.task_items) do
      script_data.progress[force.name][item.name] = 0
    end
  end

end

--- Fills the the input chests with the input item, ran on start and every 1000 ticks
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

--- Charts the whole map for a force, ran on start and every 300 ticks
local function chart_all()
  for k, force in pairs (game.forces) do
    force.chart_all()
  end
end

--- Used to select the starting conditions for this round
local function select_inventory() return select_from_probability_table(config.inventory_probabilities) end
local function select_equipment() return select_from_probability_table(config.equipment_probabilities) end
local function select_challenge_type() return select_from_probability_table(config.challenge_type_probabilities) end

--- Called by mini game core to start the game
local function start()

  script_data.round_inventory = select_inventory()
  script_data.round_equipment = select_equipment()
  script_data.challenge_type = select_challenge_type()

  make_starting_chests()
  generate_production_task()
  fill_input_chests()
  chart_all()

  for k, player in pairs(game.players) do
    Gui.toggle_left_element(player, task_frame, true)
    update_player_gui(player)
  end

end

----- Game Stop -----

--- Called to assign points to a force during a production challenge
local function production_finished(force)
  if not force.valid then return end
  if not script_data.progress then return end
  if not script_data.progress[force.name] then return end

  table.insert(script_data.winners, force)
  local points = config.points_per_win

  for j, winning_force in pairs (script_data.winners) do
    if winning_force == force then
      points = math.floor(points/j)
      break
    end
  end

  if #script_data.winners == 1 then
    script_data.end_round_tick = game.tick + config.time_before_round_end
  end

  script_data.points[force.name] = points
  for k, player in pairs(game.players) do
    if player.force ~= force then
      player.print({"finished-task", {"color."..force.name}})
      player.play_sound({path = "utility/game_lost"})
    else
      player.print({"your-team-win", script_data.points[force.name]})
      player.play_sound({path = "utility/game_won"})
    end
  end
end

--- Assigns points to a team based on the item that was made
local function calculate_force_points(force, item, points)
  if points <= 0 then return end
  if not script_data.progress then return end
  if not script_data.progress[force.name] then return end
  if not script_data.progress[force.name][item.name] then return end
  if not item.count then return end
  if script_data.progress[force.name][item.name] <= 0 then return end
  local count = script_data.progress[force.name][item.name]
  local total = item.count
  local awarded_points = math.floor((count/total)*points)
  script_data.points[force.name] = awarded_points
end

--- Called to assign points after a round of shopping list
local function shopping_list_finished()
  local total_points = config.points_per_win * script_data.number_of_teams
  local points_per_task = total_points/(#script_data.task_items)
  for k, item in pairs (script_data.task_items) do
    for j, force in pairs (game.forces) do
      calculate_force_points(force, item, points_per_task)
    end
  end
end

--- Checks if victory condition have been met for each force
local function check_victory(force)
  if not script_data.challenge_type then return end
  if not force.valid then return end

  local challenge_type = script_data.challenge_type
  if Mini_games.get_current_state() ~= 'Started' then return end
  if script_data.points[force.name] then return end

  if challenge_type == "production" then
    local finished_tasks = 0
    for k, item in pairs (script_data.task_items) do
      if script_data.progress[force.name][item.name] >= item.count then
        finished_tasks = finished_tasks +1
      end
    end
    if finished_tasks >= #script_data.task_items then
      production_finished(force)
      update_gui()
    end
    return
  end

  if challenge_type == "shopping_list" then
    local finished_tasks = 0
    for k, item in pairs (script_data.task_items) do
      if item.remaining == 0 then
        finished_tasks = finished_tasks +1
      end
    end
    if finished_tasks >= #script_data.task_items then
      Mini_games.stop_game()
      update_gui()
    end
    return
  end

end

--- Checks if the game is ready to end, used with production challenge
local function check_end_of_round()
  if game.tick ~= script_data.end_round_tick then return end
  Mini_games.stop_game()
end

--- Called by mini game core to stop a game and get the results
local function stop()
  local challenge_type = script_data.challenge_type
  if challenge_type == "shopping_list" then
    shopping_list_finished()
  end

  local scores, ctn = {}, 0
  -- Get all the data needed to write results
  for force_name, points in pairs(script_data.points) do
      ctn = ctn + 1
      local names = {}
      for index, player in ipairs(game.forces[force_name].players) do names[index] = player.name end
      scores[ctn] = { force_name, points, names }
  end

  -- Sort by team points
  table.sort(scores, function(a, b)
      return a[2] > b[2]
  end)

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

  Mini_games.print_results(results, { unit = 'points', names = names })
  return results
end

----- Game Close -----

--- Last function which is called by the mini game core to clean up after a game
local function close()
  game.delete_surface(script_data.surface)

  for _, force in ipairs (script_data.forces) do
    game.merge_forces(force, game.forces.player)
  end

  script_data.round_input = nil
  script_data.challenge_type = nil
  script_data.end_round_tick = nil

  for _, player in pairs(game.players) do
    local gui = mod_gui.get_frame_flow(player)
    Gui.destroy_if_valid(gui.winners_frame)
    Gui.toggle_left_element(player, task_frame, false)
  end

  reset_globals()
end

----- Check Chests -----

--- Checks the items in a chest using production rules
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

--- Checks the items in a chest using shopping list rules
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

--- Checks all chests for required items and then checks if forces have won
local function check_chests()
  if not script_data.output_chests then return end

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

  for k, chest in pairs (script_data.output_chests) do
    if not chest.valid then
      script_data.output_chests[k] = nil
    else
      update_chest(chest)
    end
  end
  for k, force in pairs (game.forces) do
    check_victory(force)
  end
end

----- Map Gen -----

--- Generates all the entities for the team play areas, started by setting script_data.set_entities_tick
local function check_start_setting_entities()
  if not script_data.set_entities_tick then return end
  local entities = map_sets[script_data.current_map_index].map_set_entities
  local distance = map_sets[script_data.current_map_index].map_set_size
  local index = math.ceil((script_data.set_entities_tick - game.tick)/config.ticks_to_generate_entities)

  if index == 0 then
    script_data.set_entities_tick = nil
    return
  end

  local listed = config.force_list[index]
  if not listed then return end

  local grid_position = config.offsets[index]
  local force = game.forces[listed.name]
  local offset_x = grid_position[1] * (distance*2 + config.distance_between_areas)
  local offset_y = grid_position[2] * (distance*2 + config.distance_between_areas)
  map_scripts.recreate_entities(entities, offset_x, offset_y, force, config.ticks_to_generate_entities, script_data)
end

--- Generates all the tiles for the team player areas, started by setting script_data.set_entities_tick
local function check_set_areas()
  if not script_data.set_areas_tick then return end
  local set = map_sets[script_data.current_map_index]
  local distance = set.map_set_size
  local index = script_data.set_areas_tick - game.tick

  if index == 0 then
    script_data.set_areas_tick = nil
    script_data.set_entities_tick = game.tick + (script_data.number_of_teams * config.ticks_to_generate_entities)
    return
  end

  local listed = config.force_list[index]
  if not listed then return end

  local grid_position = config.offsets[index]
  local force = game.forces[listed.name]

  if not force then
    game.print(listed.name.." is not a valid force")
    return
  end

  if not force.valid then return end
  local offset_x = grid_position[1] * (distance * 2 + config.distance_between_areas)
  local offset_y = grid_position[2] * (distance * 2 + config.distance_between_areas)
  map_scripts.create_tiles(set.map_set_size, set.map_set_tiles, offset_x, offset_y, script_data)
  force.set_spawn_position({offset_x, offset_y}, script_data.surface)
  force.rechart()
end

--- Checks when the map is generated, both tasks will set there tick checks to nil
local function ready_condition()
  -- required time: script_data.number_of_teams + (script_data.number_of_teams * config.ticks_to_generate_entities)
  return script_data.set_entities_tick == nil and script_data.set_areas_tick == nil
end

----- Player Events -----

--- Gives equipment to the player
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

--- Triggered when a participant is added to the game
local function on_player_added(event)
  local player = game.players[event.player_index]
  local force = player.force
  local team = config.teams[force.name]
  player.color = team.color
  player.chat_color = lighten(team.color)
end

--- Triggered when a participant joins the game
local function on_player_joined(event)
  local player = game.players[event.player_index]
  if Mini_games.get_current_state() == 'Starting' then
    local surface = script_data.surface

    -- Teleport the player to the new surface
    if player.character then player.character.destroy() end
    local pos = surface.find_non_colliding_position('character', player.force.get_spawn_position(surface), 10, 2)
    local character = surface.create_entity{ name = 'character', position = pos, force = player.force }
    player.teleport(pos, surface)
    player.character = character

    -- Set permission group and give starting items
    game.permissions.get_group('Default').add_player(player)
    give_equipment(player)
  end
end

--- Trigger when a participant is removed from the game
local function on_player_removed(event)
  local player = game.players[event.player_index]
  player.force = game.forces.player
end

----- Events -----

--- Checks if an entity is in a forces play area
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

--- Triggered before a player leaves the game
local on_pre_player_left_game = function(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end

  if Mini_games.get_current_state() == 'Started' and player.force ~= 'player' then
    -- We are in a round, kill his character so he doesn't leave with all the machines.
    local character = player.character

    if character then
      character.die()
      local corpse = player.surface.find_entities_filtered{type = "character-corpse", position = player.position}[1]
      if corpse then
        corpse.character_corpse_player_index = player.index
      end
    end

  end

end

--- Single on_tick event for map gen, might be possible to convert to tasks
local on_tick = function()
  check_set_areas()
  check_start_setting_entities()
  check_end_of_round()
end

--- Stops players building outside there play areas
local on_built_entity = function(event)
  local entity = event.created_entity
  if not (entity and entity.valid) then return end
  local force = entity.force
  if not is_in_area(entity, force) then
    entity.destroy()
  end
end

--- Stops players from deconstructing out side of there play area
local on_marked_for_deconstruction = function(event)
  local player = game.players[event.player_index]
  local entity = event.entity
  if not (player and player.valid and entity and entity.valid) then return end
  local force = player.force
  if not is_in_area(entity, force) then
    entity.cancel_deconstruction(force)
  end
end

----- Registration -----

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
  team_count_textfield(parent)
end)

--- Used to read the data from the gui
local function gui_callback(parent)
    local args = {}

    local team_count = parent[team_count_textfield.name].text
    args[1] = team_count

    return args
end

local team_production = Mini_games.new_game('Production Challenge')
team_production:set_core_events(init, start, stop, close)
team_production:set_ready_condition(ready_condition)
team_production:set_participant_selector(TeamSelector.selector(function() return script_data.forces end), true)
team_production:set_gui(main_gui, gui_callback)
team_production:add_option(1) -- how many options are needed with /start

team_production:add_event(Mini_games.events.on_participant_added, on_player_added)
team_production:add_event(Mini_games.events.on_participant_joined, on_player_joined)
team_production:add_event(Mini_games.events.on_participant_removed, on_player_removed)

team_production:add_event(defines.events.on_pre_player_left_game, on_pre_player_left_game)
team_production:add_event(defines.events.on_tick, on_tick)
team_production:add_event(defines.events.on_built_entity, on_built_entity)
team_production:add_event(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)

team_production:add_nth_tick(301, chart_all)
team_production:add_nth_tick(29, check_chests)
team_production:add_nth_tick(997, fill_input_chests)
team_production:add_nth_tick(60, update_gui)