local math2d = require("math2d")
local find_revive_make = require("__cargo-ships-oil-rig__/logic/find_revive_make")

local pole_offset = {0,0.1}

function UnlockOilProcessing(force)
  if force.technologies["oil-processing"] then
    force.technologies["oil-processing"].researched = true
  end
end

function CreateOilRig(entity, player, robot)
  local surface = entity.surface
  local force = entity.force
  local position = entity.position
  local quality = entity.quality
  
  log("Creating oil rig "..tostring(entity).." ("..entity.quality.name..")")
  
  -- Fix the orientation of the oil_rig when we create it, since blueprint might be rotated
  entity.mirroring = false
  entity.direction = defines.direction.north
  
  -- Fast-replace existing entities, revive ghosts, or create new component entities as required
  
  
  local power = find_revive_make{ name = "or_power_electric",
                                  quality = quality,
                                  surface = surface,
                                  position = position,
                                  force = force,
                                  create_build_effect_smoke = false
                                }
  
  local radar = find_revive_make{ name = "or_radar",
                                  quality = quality,
                                  surface = surface,
                                  position = position,
                                  force = force,
                                  create_build_effect_smoke = false
                                }

  -- Only make a reactor if it's on a surface that needs heating
  local reactor
  local need_reactor = false
  if prototypes.entity["or_reactor"] and (surface.planet and surface.planet.prototype.entities_require_heating) then
    need_reactor = true
    reactor = find_revive_make{ name = "or_reactor",
                                  quality = quality,
                                  surface = surface,
                                  position = position,
                                  force = force,
                                  create_build_effect_smoke = false
                                }
  end
  
  local pole =  find_revive_make{ name = "or_pole",
                                  quality = quality,
                                  surface = surface,
                                  position = math2d.position.add(position,pole_offset),
                                  force = force,
                                  create_build_effect_smoke = false
                                }

  local tank =  find_revive_make{ name = "or_tank",
                                  quality = quality,
                                  surface = surface,
                                  position = position,
                                  force = force,
                                  create_build_effect_smoke = false
                                }
  
  -- If there was a problem, cancel the construction
  if not (power and pole and radar and tank and (reactor or not need_reactor)) then
    --game.print("Could not create all oil rig components.")
    if player then
      player.mine_entity(entity, true)
      player.create_local_flying_text{text={"cargo-ship-message.error-place-on-water", entity.localised_name}, create_at_cursor=true}
    elseif robot then
      entity.mine{inventory=robot.get_inventory(defines.inventory.robot_cargo), force=true, raise_destroyed=false, ignore_minable=true}
      game.print{"cargo-ship-message.error-place-on-water", entity.localised_name}
    end
    entity.destroy()
    if pole then pole.destroy() end
    if tank then tank.destroy() end
    if power then power.destroy() end
    if radar then radar.destroy() end
    if reactor then reactor.destroy() end
    return nil
  end
  
  -- Make components invincible
  power.destructible = false
  pole.destructible = false
  radar.destructible = false
  tank.destructible = false
  if reactor then reactor.destructible = false end
  -- Link pumpjack and generator to tank
  entity.add_fluid_box_linked_connection(1, tank, 1)
  power.add_fluid_box_linked_connection(1, tank, 2)
  -- Prime the energy generator with some oil
  power.insert_fluid{name="crude-oil", amount=power.get_fluid_capacity(1)}
  local entry = {
      surface = surface,
      position = position,
      entity = entity,
      pole = pole,
      radar = radar,
      power = power,
      tank = tank,
      reactor = reactor
    }
  storage.oil_rigs[entity.unit_number] = entry
  script.register_on_object_destroyed(entity)

  UnlockOilProcessing(force)
  return entry
end

-- Destroy the oil_rig sub-entities.
-- If player is given, add the pole and tank to their undo stack.
-- If a ghost oil_rig was created, let's make ghosts of or_tank and or_pole
function DestroyOilRig(unit_number, player, undo_index)
  if storage.oil_rigs and storage.oil_rigs[unit_number] then
    local data = storage.oil_rigs[unit_number]
    log("Destroying oil_rig "..tostring(unit_number).." at "..util.positiontostr(data.position))
    if data.pole and data.pole.valid then
      data.pole.destroy{player=player, undo_index=undo_index}
    end
    if data.tank and data.tank.valid then
      data.tank.destroy{player=player, undo_index=undo_index}
    end
    if data.radar and data.radar.valid then
      data.radar.destroy()
    end
    if data.power and data.power.valid then
      data.power.destroy()
    end
    if data.reactor and data.reactor.valid then
      data.reactor.destroy()
    end
    storage.oil_rigs[unit_number] = nil
    return true
  end
end

function HandleOilRigPartGhost(ghost)
  local position = ghost.position
  local rigpos = {math.floor(ghost.position.x*2)/2, math.floor(ghost.position.y*2)/2}
  if storage.recent_oil_rig and storage.recent_oil_rig.valid and storage.recent_oil_rig.position.x == rigpos.x and storage.recent_oil_rig.position.y == rigpos.y then
    -- Last function call was for the same oil_rig, we're good
    return
  end
  local rig = ghost.surface.find_entity("oil_rig", rigpos)
  if rig and rig.valid then
    -- Store this rig reference to use next time
    storage.recent_oil_rig = rig
    return
  end
  rig = ghost.surface.find_entities_filtered{ghost_name = "oil_rig", position = rigpos}[1]
  if rig and rig.valid then
    -- Store this rig reference to use next time
    storage.recent_oil_rig = rig
    return
  end
  -- No matching recent oil rig and none found, delete ghost
  game.print("Destroying Unmatched Oil Rig Part Ghost "..tostring(ghost))
  ghost.destroy()
  storage.recent_oil_rig = nil
end

-- Add missing reactors to any oil rigs on heating-required surfaces
-- Used in on_configuration_changed since this could change with mods being installed I guess
-- Don't bother to remove existing reactors just because planet no longer requires heating
function MigrateOilRigReactors()
  if prototypes.entity["or_reactor"] then
    if storage.oil_rigs then
      --log(serpent.block(storage.oil_rigs))
      for unit_number, rig_data in pairs(storage.oil_rigs) do
        local surface = rig_data.surface
        if surface.planet and surface.planet.prototype.entities_require_heating and not rig_data.reactor then
          rig_data.reactor = find_revive_make{ name = "or_reactor",
                                  quality = rig_data.entity.quality,
                                  surface = surface,
                                  position = rig_data.position,
                                  force = rig_data.entity.force,
                                  create_build_effect_smoke = false
                                }
          log("Added Oil Rig Reactor to oil rig on surface "..surface.name.." at "..util.positiontostr(rig_data.position))
        end
      end
      --log(serpent.block(storage.oil_rigs))
    end
  else
    -- No more heating, remove dead references to reactors that don't exist
    if storage.oil_rigs then
      --log(serpent.block(storage.oil_rigs))
      for unit_number, rig_data in pairs(storage.oil_rigs) do
        rig_data.reactor = nil
        log("Removed reactor reference from oil rig")
      end
      --log(serpent.block(storage.oil_rigs))
    end
  end
end

