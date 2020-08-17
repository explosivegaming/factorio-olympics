return {
  ticks_to_generate_entities = 20,
  time_before_round_end = 60*60*2,
  points_per_win = 20,
  distance_between_areas = 10,

  inventory_probabilities =
  {
    {probability = 4, value = "small"},
    {probability = 12, value = "medium"},
    {probability = 8, value = "large"}
  },

  equipment_probabilities =
  {
    {probability = 6, value = "none"},
    {probability = 4, value = "small"}
  },

  challenge_type_probabilities =
  {
    {probability = 22, value = "production"},
    {probability = 14, value = "shopping_list"}
  },

  max_count_of_production_tasks = 3,

  -- With one tasks, the result amount is from 2*count up to 10*count
  -- With two tasks, the result amount is from 2*count up to 5*count
  -- With three tasks, the result amount is from 2*count up to 3*count
  item_list =
  {
    {name = "accumulator", count = 400, input = "battery"},
    {name = "accumulator", count = 50, input = "sulfur"},
    {name = "advanced-circuit", count = 400, input = "plastic-bar"},
    {name = "advanced-circuit", count = 150, input = "petroleum-gas-barrel"},
    {name = "arithmetic-combinator", count = 50},
    {name = "assembling-machine-1", count = 50},
    {name = "assembling-machine-2", count = 50},
    {name = "battery", count = 150, input = "sulfur"},
    {name = "big-electric-pole", count = 25},
    {name = "boiler", count = 100},
    {name = "burner-mining-drill", count = 100},
    {name = "car", count = 10},
    {name = "chemical-plant", count = 20},
    {name = "concrete", count = 500},
    {name = "copper-cable", count = 1000},
    {name = "copper-cable", count = 2000, input = "copper-plate"},
    {name = "copper-plate", count = 400},
    {name = "defender-capsule", count = 50},
    {name = "electric-furnace", count = 25, input = "advanced-circuit"},
    {name = "electric-mining-drill", count = 50},
    {name = "electronic-circuit", count = 150},
    {name = "empty-barrel", count = 150},
    {name = "engine-unit", count = 25},
    {name = "engine-unit", count = 50, input = "steel-plate"},
    {name = "explosives", count = 150, input = "sulfur"},
    {name = "fast-inserter", count = 150},
    {name = "fast-splitter", count = 25},
    {name = "fast-transport-belt", count = 100},
    {name = "fast-underground-belt", count = 25},
    {name = "filter-inserter", count = 50},
    {name = "firearm-magazine", count = 200},
    {name = "gate", count = 50},
    {name = "green-wire", count = 200},
    {name = "gun-turret", count = 25},
    {name = "heavy-armor", count = 10},
    {name = "iron-gear-wheel", count = 200},
    {name = "iron-plate", count = 400},
    {name = "iron-stick", count = 1000},
    {name = "lab", count = 50},
    {name = "landfill", count = 1500, input = "stone"},
    {name = "landfill", count = 50},
    {name = "light-armor", count = 50},
    {name = "locomotive", count = 2},
    {name = "long-handed-inserter", count = 150},
    {name = "medium-electric-pole", count = 100},
    {name = "piercing-rounds-magazine", count = 50},
    {name = "pipe", count = 300},
    {name = "plastic-bar", count = 300, input = "crude-oil-barrel"},
    {name = "pump", count = 150, input = "engine-unit"},
    {name = "radar", count = 50},
    {name = "rail-signal", count = 100},
    {name = "rail", count = 100},
    {name = "red-wire", count = 200},
    {name = "repair-pack", count = 250},
    {name = "roboport", count = 5, input = "advanced-circuit"},
    {name = "rocket-fuel", count = 100, input = "light-oil-barrel"},
    {name = "shotgun-shell", count = 200},
    {name = "small-lamp", count = 150},
    {name = "solar-panel", count = 25},
    {name = "stack-inserter", count = 50, input = "advanced-circuit"},
    {name = "stack-inserter", count = 30, input = "plastic-bar"},
    {name = "splitter", count = 50},
    {name = "steam-engine", count = 50},
    {name = "steel-chest", count = 25},
    {name = "steel-furnace", count = 25},
    {name = "steel-plate", count = 50},
    {name = "stone-brick", count = 200},
    {name = "stone-furnace", count = 100},
    {name = "stone-wall", count = 100},
    {name = "train-stop", count = 50},
    {name = "train-stop", count = 50},
    {name = "transport-belt", count = 250},
    {name = "water-barrel", count = 100}
  },

  offsets =
  {
    {-1, -1},
    {0, -1},
    {1, -1},
    {1, 0},
    {1, 1},
    {0, 1},
    {-1, 1},
    {-1, 0},
  },

  force_list =
  {
    { name = "orange" , color = { r = 0.869, g = 0.5  , b = 0.130, a = 0.5 }},
    { name = "purple" , color = { r = 0.485, g = 0.111, b = 0.659, a = 0.5 }},
    { name = "red"    , color = { r = 0.815, g = 0.024, b = 0.0  , a = 0.5 }},
    { name = "green"  , color = { r = 0.093, g = 0.768, b = 0.172, a = 0.5 }},
    { name = "blue"   , color = { r = 0.155, g = 0.540, b = 0.898, a = 0.5 }},
    { name = "yellow" , color = { r = 0.835, g = 0.666, b = 0.077, a = 0.5 }},
    { name = "pink"   , color = { r = 0.929, g = 0.386, b = 0.514, a = 0.5 }},
    { name = "cyan"   , color = { r = 0.275, g = 0.755, b = 0.712, a = 0.5 }}
  },

  starting_inventories =
  {
    ["small"] =
    {
      {name = "iron-plate", count = 20},
      {name = "copper-plate", count = 10},
      {name = "transport-belt", count=100},
      {name = "inserter", count=20},
      {name = "small-electric-pole", count=40},
      {name = "burner-mining-drill", count=16},
      {name = "stone-furnace", count=12},
      {name = "burner-inserter", count=30},
      {name = "assembling-machine-1", count=8},
      {name = "electric-mining-drill", count=2}
    },
    ["medium"] =
    {
      {name = "iron-plate", count = 50},
      {name = "iron-gear-wheel", count = 50},
      {name = "copper-plate", count = 50},
      {name = "electronic-circuit", count = 50},
      {name = "transport-belt", count = 150},
      {name = "inserter", count = 60},
      {name = "small-electric-pole", count=40},
      {name = "fast-inserter", count = 20},
      {name = "burner-inserter", count=50},
      {name = "burner-mining-drill", count=20},
      {name = "electric-mining-drill", count=8},
      {name = "stone-furnace", count=20},
      {name = "steel-furnace", count=8},
      {name = "speed-module-2", count = 8},
      {name = "assembling-machine-1", count=20},
      {name = "assembling-machine-2", count=8}
    },
    ["large"] =
    {
      {name = "iron-plate", count = 50},
      {name = "copper-plate", count = 50},
      {name = "iron-gear-wheel", count = 50},
      {name = "transport-belt", count = 250},
      {name = "inserter", count = 50},
      {name = "burner-inserter", count=50},
      {name = "small-electric-pole", count=50},
      {name = "burner-mining-drill", count=50},
      {name = "electric-mining-drill", count=20},
      {name = "stone-furnace", count=35},
      {name = "steel-furnace", count=20},
      {name = "electric-furnace", count=8},
      {name = "assembling-machine-1", count = 50},
      {name = "assembling-machine-2", count = 20},
      {name = "assembling-machine-3", count = 8},
      {name = "speed-module-3", count = 8},
      {name = "speed-module-2", count = 20},
      {name = "electronic-circuit", count = 50},
      {name = "fast-inserter", count = 30},
      {name = "medium-electric-pole", count = 30},
      {name = "substation", count = 8}
    }
  },

  disabled_items =
  {
    "submachine-gun",
    "pistol",
    "shotgun",
    "combat-shotgun",
    "rocket-launcher",
    "grenade",
    "land-mine",
    "poison-capsule",
    "slowdown-capsule",
    "flamethrower",
    "distractor-capsule",
    "destroyer-capsule",
    "rocket",
    "flamethrower-ammo",
    "laser-turret",
    "night-vision-equipment",
    "solar-panel-equipment",
    "energy-shield-equipment",
    "battery-equipment"
  }
}