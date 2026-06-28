----------------------------------------------
------ MOD-DATA FOR SHIP DEFINITION API ------
----------------------------------------------

data:extend{

  -- Create the built-in ships
  {
    type = "mod-data",
    name = "cargo_ship",                          -- mod-data `name` can be anything
    data_type = "cargo-ships.ship-definition",    -- mod-data `data_type` must be "cargo-ships.ship-definition"
    data = {                                      -- mod-data `data` contains the parameters for exactly one type of ship
      name = "cargo_ship",                        -- `data.name` = name of the ship body entity (type=wagon)
      engine = "cargo_ship_engine",               -- `data.engine` = name of the ship engine entity (type=locomotive)
      engine_scale = 1,                           -- `data.engine_scale` = sets the distance from the center of the wagon to where
                                                  --    the locomotive should be created as a fraction of the normal Cargo Ship distance.
                                                  --    Only used if engine_offset is not defined.
      engine_at_front = false,                    -- `data.engine_at_front` = false when the engine is at the back of the ship
    }
  },
  {
    type = "mod-data",
    name = "oil_tanker",
    data_type = "cargo-ships.ship-definition",
    data = {
      name = "oil_tanker",
      engine = "cargo_ship_engine",
      engine_scale = 1,
      engine_at_front = false,
    }
  },
  {
    type = "mod-data",
    name = "boat",
    data_type = "cargo-ships.ship-definition",
    data = {
      name = "boat",
      engine = "boat_engine",
      engine_scale = 0.3,
      engine_at_front = true,
    }
  },
  
  -- Create the built-in indep-boat (car) entity that can be converted to a ship when placed on waterways
  {
    type = "mod-data",
    name = "indep-boat",                          -- mod-data `name` can be anything
    data_type = "cargo-ships.boat-definition",    -- mod-data `data_type` must be "cargo-ships.boat-definition"
    data = {                                      -- mod-data `data` contains the parameters for exactly one type of boat
      name = "indep-boat",                        -- `data.name` = name of the boat entity (type=car)
      rail_version = "boat",                      -- `data.rail_version` = name of the ship entity (type=wagon) created when this car entity
                                                  --    is placed on waterways.
    }
  },
}
