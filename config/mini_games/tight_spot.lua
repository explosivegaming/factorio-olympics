return {
    {
        surface = "tigth_spot", --Name of the surface.
        level_number = 1, --Must be 1 higher then the last one.
        time =   6 * 60, -- The time in tick 1 sec is 60 ticks.
        play_time = 6 * 60, -- The time that the game plays when the player cant take action.
        objective = "Iron gear", -- Non data.raw objective.
        money = { --The different tiers of money.
            easy = 10000,
            normal = 5000,
            hard = 3500,
        },
        center = {x = 0, y = 0}, --The center of the main island
        starting_land_prize = 10, --Minal cost of land.
        area = {{-25,-25},{26,26}}, --The area the main island is in.
        recipes = { --All recpies that can be used.
            "iron-plate",
            "copper-plate",
            "iron-gear-wheel",
        },
        items = { --All market item from data.raw
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
            item = "iron-gear-wheel", -- Data.raw objective
            price = 10 --The prices of the objective.
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
            item = "electronic-circuit",
            price = 15   
        }
    }
}
