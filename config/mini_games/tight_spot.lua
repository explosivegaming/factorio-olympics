return {
    {
        surface = "tight_spot",
        level_number = 1,
        show_rules = true,
        time = 10 * 60 * 60,
        money = 10000,
        required_balance = {
            easy = 1000,
            normal = 2000,
            hard = 3000
        },
        center = {x = 0, y = 0},
        starting_land_prize = 10,
        price_increase = 2,
        area = {{-40, -40}, {40, 40}},
        recipes = {
            "iron-plate",
            "copper-plate",
            "iron-gear-wheel"
        },
        items = {
            "coal",
            "transport-belt",
            "underground-belt",
            "burner-inserter",
            "inserter",
            "long-handed-inserter",
            "stone-furnace",
            "offshore-pump",
            "pipe",
            "boiler",
            "steam-engine",
            "small-electric-pole",
            "assembling-machine-1",
            "electric-mining-drill",
            "burner-mining-drill"
        },
        demand = {
            {
                item = "iron-gear-wheel",
                price = 10
            }
        }
    },
    {
        level_number = 2,
        time = 10 * 60 * 60,
        money = 10000,
        required_balance = {
            easy = 1000,
            normal = 2000,
            hard = 3000
        },
        center = {x = 0, y = 0},
        starting_land_prize = 10,
        price_increase = 2,
        area = {{-40, -40}, {40, 40}},
        recipes = {
            "iron-plate",
            "copper-plate",
            "copper-cable",
            "electronic-circuit"
        },
        items = {
            "coal",
            "transport-belt",
            "underground-belt",
            "fast-transport-belt",
            "fast-underground-belt",
            "splitter",
            "burner-inserter",
            "inserter",
            "long-handed-inserter",
            "fast-inserter",
            "filter-inserter",
            "stone-furnace",
            "offshore-pump",
            "pipe",
            "pipe-to-ground",
            "boiler",
            "steam-engine",
            "small-electric-pole",
            "assembling-machine-1",
            "electric-mining-drill",
            "burner-mining-drill"
        },
        demand = {
            {
                item = "electronic-circuit",
                price = 15
            }
        }
    }
}
