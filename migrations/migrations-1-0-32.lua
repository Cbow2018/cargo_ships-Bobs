-----------------------------------------------------------------------------------------------------------
-- oil_rigs: Check for any oil_rig entities that have been removed from the global table, and rebuild them.

local function find_teleport_make(name, surface, area, position, force)
  local entity
  local found = surface.find_entities_filtered{name=name, area=area}
  for _,e in pairs(found) do
    if e.position.x == position.x and e.position.y == position.y then
      entity = e
      log("Found existing "..name.." entity "..tostring(entity))
      break
    end
  end
  if not entity and found[1] then
    entity = found[1]
    log("Teleporting existing "..name.." entity "..tostring(entity))
    entity.teleport(position)
  end
  if not entity then
    entity = surface.create_entity{name=name, position=position, force=force, create_build_effect_smoke=false}
    log("Making new "..name.." entity "..tostring(entity))
  end
  return entity
end

if settings.startup["offshore_oil_enabled"].value then
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{name="oil_rig"}) do
      if not storage.oil_rigs[entity.unit_number] then
        log("Repairing oil_rig "..tostring(entity))
        -- Due to the object_id collision bug in 1.0.31 and prior, oil rig sub-entities may be deleted when
        -- e.g. a train with the same id as the oil_rig entity number is destroyed.
        -- Need to recreate the subentities and re-add it to the global table.
        local force = entity.force
        local position = entity.position
        local direction = defines.direction.north
        
        local area = offsetArea(entity.prototype.selection_box, position)
        
        -- Search for existing entities, and they might not be in the right place
        local power, pole, radar, tank
        
        entity = find_teleport_make("oil_rig", surface, area, position, force)
        
        -- Fluid burning generator, or_power_electric
        power = find_teleport_make("or_power_electric", surface, area, position, force)
        
        -- Electric pole, or_pole
        pole = find_teleport_make("or_pole", surface, area, position, force)
        
        -- Radar, or_radar
        radar = find_teleport_make("or_radar", surface, area, position, force)
        
        -- Storage tank, or_tank
        tank = find_teleport_make("or_tank", surface, area, position, force)
        
        if not (entity and power and pole and radar and tank) then
          log("Could not create all oil rig components. Oil rig "..tostring(entity).." will be deleted.")
          if tank and tank.valid then tank.destroy() end
          if radar and radar.valid then radar.destroy() end
          if pole and pole.valid then pole.destroy() end
          if power and power.valid then power.destroy() end
          if entity and entity.valid then entity.destroy() end
        else
          -- Make components invincible
          power.destructible = false
          pole.destructible = false
          radar.destructible = false
          tank.destructible = false
          -- Link pumpjack and generator to tank
          entity.fluidbox.add_linked_connection(1, tank, 1)
          power.fluidbox.add_linked_connection(1, tank, 2)
          -- Prime the energy generator with some oil
          power.insert_fluid{name="crude-oil", amount=power.fluidbox.get_capacity(1)}
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
          log("Finished repairing oil_rig "..tostring(entity))
        end
      end
    end
  end
end
