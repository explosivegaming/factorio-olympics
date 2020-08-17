--- Each research, entity, or item will count once per entry towards the speed run progress
return {
    { --- Steel Axe
        goal = 'Complete the research for steel axe.',
        name = 'Steel Axe',
        research = {
            'steel-axe','steel-processing'
        },
        items = {
            'automation-science-pack','copper-plate','copper-ore','iron-gear-wheel',
            'iron-plate','iron-ore','electronic-circuit','copper-cable','transport-belt'
        },
        entities = {
            'steam-engine', 'lab'
        }
    },
    { --- Getting on Track
        goal = 'Craft and place a locomotive on rails.',
        name = 'Getting on Track',
        research = {
            'railway','logistics-2','logistics','logistic-science-pack','engine','steel-processing'
        },
        items = {
            'locomotive','automation-science-pack','logistic-science-pack','steel-plate','iron-plate',
            'iron-ore','electronic-circuit','copper-cable','copper-plate','copper-ore',
            'engine-unit','iron-gear-wheel','pipe','transport-belt','inserter'
        },
        entities = {
            'steam-engine', 'lab', 'assembling-machine-1', 'assembling-machine-2', 'locomotive'
        }
    },
    { --- Reduced
        goal = 'Craft one set of power armour MK2.',
        name = 'Reduced',
        research = {
            'power-armor-mk2','power-armor','modular-armor','heavy-armor','military',
            'steel-processing','advanced-electronics','plastics','oil-processing','fluid-handling',
            'automation-2','electronics','automation','logistic-science-pack','engine',
            'electric-engine','lubricant','advanced-oil-processing','chemical-science-pack','sulfur-processing',
            'advanced-electronics-2','military-4','military-3','military-science-pack','military-2',
            'stone-walls','utility-science-pack','robotics','battery','low-density-structure',
            'advanced-material-processing','explosives','speed-module-2','speed-module','modules',
            'effectivity-module-2','effectivity-module'
        },
        items = {
            'power-armor-mk2','automation-science-pack','logistic-science-pack','chemical-science-pack','military-science-pack',
            'utility-science-pack','processing-unit','electronic-circuit','iron-plate','iron-ore',
            'copper-cable','copper-plate','copper-ore','advanced-circuit','plastic-bar',
            'coal','electric-engine-unit','engine-unit','steel-plate','iron-gear-wheel',
            'pipe','low-density-structure','speed-module-2','speed-module','effectivity-module-2',
            'effectivity-module','transport-belt','inserter','sulfur','piercing-rounds-magazine',
            'firearm-magazine','grenade','stone-wall','stone-brick','stone',
            'flying-robot-frame','battery'
        },
        entities = {
            'steam-engine', 'lab', 'assembling-machine-1', 'assembling-machine-2', 'pumpjack', 'oil-refinery'
        }
    },
    { --- Standard
        goal = 'Launch one rocket from a silo, does not require a satellite.',
        name = 'Standard',
        rockets = 1,
        research = {
            'rocket-silo','concrete','advanced-material-processing','steel-processing','logistic-science-pack',
            'automation-2','electronics','automation','speed-module-3','speed-module-2',
            'speed-module','modules','advanced-electronics','plastics','oil-processing',
            'fluid-handling','engine','advanced-electronics-2','chemical-science-pack','sulfur-processing',
            'production-science-pack','productivity-module','advanced-material-processing-2','railway','logistics-2',
            'logistics','productivity-module-3','productivity-module-2','rocket-fuel','flammables',
            'advanced-oil-processing','rocket-control-unit','utility-science-pack','robotics','electric-engine',
            'lubricant','battery','low-density-structure'
        },
        items = {
            'rocket-silo','rocket-control-unit','low-density-structure','rocket-fuel','automation-science-pack',
            'logistic-science-pack','chemical-science-pack','production-science-pack','utility-science-pack','steel-plate',
            'iron-plate','iron-ore','processing-unit','electronic-circuit','copper-cable',
            'copper-plate','copper-ore','advanced-circuit','plastic-bar','coal',
            'electric-engine-unit','engine-unit','iron-gear-wheel','pipe','concrete',
            'stone-brick','stone','speed-module','solid-fuel','transport-belt',
            'inserter','sulfur','rail','iron-stick','electric-furnace',
            'productivity-module','flying-robot-frame','battery'
        },
        entities = {
            'steam-engine', 'lab', 'assembling-machine-1', 'assembling-machine-2', 'pumpjack', 'oil-refinery', 'rocket-silo'
        }
    },
    { --- Marathon
        goal = 'Launch ten rockets with satellites from a silo.',
        name = 'Marathon',
        satellites = 10,
        research = {
            'rocket-silo','concrete','advanced-material-processing','steel-processing','logistic-science-pack',
            'automation-2','electronics','automation','speed-module-3','speed-module-2',
            'speed-module','modules','advanced-electronics','plastics','oil-processing',
            'fluid-handling','engine','advanced-electronics-2','chemical-science-pack','sulfur-processing',
            'production-science-pack','productivity-module','advanced-material-processing-2','railway','logistics-2',
            'logistics','productivity-module-3','productivity-module-2','rocket-fuel','flammables',
            'advanced-oil-processing','rocket-control-unit','utility-science-pack','robotics','electric-engine',
            'lubricant','battery','low-density-structure'
        },
        items = {
            'satellite','rocket-silo','rocket-control-unit','low-density-structure','rocket-fuel',
            'automation-science-pack','logistic-science-pack','chemical-science-pack','production-science-pack','utility-science-pack',
            'processing-unit','electronic-circuit','iron-plate','iron-ore','copper-cable',
            'copper-plate','copper-ore','advanced-circuit','plastic-bar','coal',
            'solar-panel','steel-plate','accumulator','battery','radar',
            'iron-gear-wheel','electric-engine-unit','engine-unit','pipe','concrete',
            'stone-brick','stone','speed-module','solid-fuel','transport-belt',
            'inserter','sulfur','rail','iron-stick','electric-furnace',
            'productivity-module','flying-robot-frame'
        },
        entities = {
            'steam-engine', 'lab', 'assembling-machine-1', 'assembling-machine-2', 'pumpjack', 'oil-refinery', 'rocket-silo'
        }
    }
}