return {
    {
        surface = "tigth_spot_lv:1", --Name of the surface.
        level_number = 1, --Must be 1 higher then the last one.
        time =  5 * 60 * 60, -- The time in tick 1 sec is 60 ticks.
        play_time =  10 * 60 * 60, -- The time that the game plays when the player cant take action.
        objective = "Iron gear", -- Non data.raw objective.
        money = { --The different tiers of money you get at the start.
            easy = 10000,
            normal = 5000,
            hard = 3500,
        },
        loan_prices = { -- how much a 5k loan will cost in points
            easy = 100,
            normal = 150,
            hard = 200,
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
        surface = "tight_spot_lv:2", --Name of the surface.
        time =  5 * 60 * 60, -- The time in tick 1 sec is 60 ticks.
        play_time =  10 * 60 * 60, -- The time that the game plays when the player cant take action.
        objective = "Green Circuit", -- Non data.raw objective.
        money = { --The different tiers of money you get at the start.
            easy = 10000,
            normal = 5000,
            hard = 3500,
        },
        loan_prices = { -- how much a 5k loan will cost in points
            easy = 100,
            normal = 150,
            hard = 200,
        },
        center = {x = 0, y = 0}, --The center of the main island
        starting_land_prize = 10, --Minal cost of land.
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
