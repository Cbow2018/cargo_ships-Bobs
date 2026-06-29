local math2d = require("math2d")
local find_revive_make = require("__cargo-ships-oil-rig__/logic/find_revive_make")
local pole_offset = {0,0.1}
-----------------------------------------------------------------------------------------------------------
-- Migrating from cargo-ships to cargo-ships-oil-rig, need to rebuild the global table from scratch
-- Also make sure all the sub-entities are in the right place

storage.oil_rigs = storage.oil_rigs or {}

for _, surface in pairs(game.surfaces) do
  for _, entity in pairs(surface.find_entities_filtered{name="oil_rig"}) do
    if not storage.oil_rigs[entity.unit_number] then
      local logname = tostring(entity.unit_number).." "..tostring(entity).." ("..entity.quality.name..")"
      log("Registering oil_rig "..logname)
      local force = entity.force
      local position = entity.position
      local quality = entity.quality
      local radius = 3 -- wider search area to make sure we get everything
      
      -- Search for existing entities, even if they might not be in the right place
      entity =      find_revive_make{ name = "oil_rig",
                                      quality = quality,
                                      force = force,
                                      surface = surface,
                                      position = position,
                                      radius = radius,
                                      create_build_effect_smoke = false,
                                      verbose = true
                                    }
      
      local power = find_revive_make{ name = "or_power_electric",
                                      quality = quality,
                                      force = force,
                                      surface = surface,
                                      position = position,
                                      radius = radius,
                                      create_build_effect_smoke = false,
                                      verbose = true
                                    }
      
      local radar = find_revive_make{ name = "or_radar",
                                      quality = quality,
                                      force = force,
                                      surface = surface,
                                      position = position,
                                      radius = radius,
                                      create_build_effect_smoke = false,
                                      verbose = true
                                    }

      -- Only make a reactor if it's on a surface that needs heating
      local reactor
      local need_reactor = false
      if prototypes.entity["or_reactor"] and (surface.planet and surface.planet.prototype.entities_require_heating) then
        need_reactor = true
        reactor = find_revive_make{   name = "or_reactor",
                                      quality = quality,
                                      force = force,
                                      surface = surface,
                                      position = position,
                                      radius = radius,
                                      create_build_effect_smoke = false,
                                      verbose = true
                                  }
      end
      
      local pole =  find_revive_make{ name = "or_pole",
                                      quality = quality,
                                      force = force,
                                      surface = surface,
                                      position = math2d.position.add(position,pole_offset),
                                      radius = radius,
                                      create_build_effect_smoke = false,
                                      verbose = true
                                  }
      
      local tank =  find_revive_make{ name = "or_tank",
                                      quality = quality,
                                      force = force,
                                      surface = surface,
                                      position = position,
                                      radius = radius,
                                      create_build_effect_smoke = false,
                                      verbose = true
                                  }
      
      
      if not (entity and power and pole and radar and tank) then
        log("Could not create all oil rig components. Oil rig "..logname.." will be deleted.")
        if tank and tank.valid then tank.destroy() end
        if radar and radar.valid then radar.destroy() end
        if pole and pole.valid then pole.destroy() end
        if power and power.valid then power.destroy() end
        if entity and entity.valid then entity.destroy() end
      else
        -- Wiggle the Oil Rig to get or_pole to draw on top after the migration. This is magic.
        entity.rotate{reverse=false}
        entity.rotate{reverse=true}
        -- Make components invincible
        power.destructible = false
        pole.destructible = false
        radar.destructible = false
        tank.destructible = false
        -- Link pumpjack and generator to tank
        entity.add_fluid_box_linked_connection(1, tank, 1)
        power.add_fluid_box_linked_connection(1, tank, 2)
        -- Prime the energy generator with some oil
        power.insert_fluid{name="crude-oil", amount=power.get_fluid_capacity(1)}
        -- Register for destruction event
        script.register_on_object_destroyed(entity)
        storage.oil_rigs[entity.unit_number] = {
          surface = surface,
          position = position,
          entity = entity,
          pole = pole,
          radar = radar,
          power = power,
          tank = tank
        }
        log("Finished registering oil_rig "..tostring(entity))
      end
    end
  end
end
