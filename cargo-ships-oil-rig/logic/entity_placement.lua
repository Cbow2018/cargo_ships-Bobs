local math2d = require("math2d")
local player_mine_entity_undo = require("__Robot256Lib__/script/player_mine_entity_undo")

local function cancelPlacement(entity, player, robot)
  if not storage.ship_engines[entity.name] then
    if player and player.valid then
      local refund_item = entity.prototype.items_to_place_this[1]
      refund_item.quality = entity.quality
      player.insert(refund_item)
      if storage.ship_bodies[entity.name] then
        player.create_local_flying_text{text={"cargo-ship-message.error-ship-no-space", entity.localised_name}, create_at_cursor=true}
      else
        player.create_local_flying_text{text={"cargo-ship-message.error-train-on-waterway", entity.localised_name}, create_at_cursor=true}
      end
    elseif robot and robot.valid then
      -- Give the robot back the thing
      local refund_item = entity.prototype.items_to_place_this[1]
      refund_item.quality = entity.quality
      robot.get_inventory(defines.inventory.robot_cargo).insert(refund_item)
      if storage.ship_bodies[entity.name] then
        game.print{"cargo-ship-message.error-ship-no-space", entity.localised_name}
      else
        game.print{"cargo-ship-message.error-train-on-waterway", entity.localised_name}
      end
    else
      game.print{"cargo-ship-message.error-canceled", entity.localised_name}
    end
  end
  log("cancelPlacement destroying "..tostring(entity))
  entity.destroy()
end


-- checks placement of rolling stock, and returns the placed entities to the player if necessary
function processPlacementQueue()
  -- Now check placement of ships from the last tick
  --if #storage.check_placement_queue > 0 then
  --  log(tostring(game.tick)..": checking placement "..tostring(#storage.check_placement_queue).." entities")
  --end
  for _, entry in pairs(storage.check_placement_queue) do
    local entity = entry.entity
    local engine = entry.engine
    local player = entry.player
    local robot = entry.robot
    local undo_index = entry.undo_index
    
    --log("checking "..tostring(entity).." "..tostring(entity.unit_number))

    if entity and entity.valid then
      -- oil_rig part ghosts, make sure there is an oil_rig ghost attached to them
      if entity.type == "entity-ghost" then
        HandleOilRigPartGhost(entity)
      
      -- oil_rig deconstruction orders, add to previous undo item
      elseif entity.name == "oil_rig" and entity.to_be_deconstructed() then
        local undo_item = player and player.undo_redo_stack.get_undo_item_count() > 0 and player.undo_redo_stack.get_undo_item(1)
        if undo_item and undo_item[1] and undo_item[1].type == "removed-entity" and undo_item[1].target.name == "oil_rig" then
          --game.print("Marking "..tostring(entity).." subentities for deconstruction")
          local data = storage.oil_rigs and storage.oil_rigs[entity.unit_number]
          if data then
            data.pole.order_deconstruction(player and player.force or entity.force, player, 1)
            data.tank.order_deconstruction(player and player.force or entity.force, player, 1)
          end
        end
      end
    end
  end
  storage.check_placement_queue = {}
  RegisterPlacementOnTick()
end


function RegisterPlacementOnTick()
  if storage.check_placement_queue and next(storage.check_placement_queue) then
    script.on_event(defines.events.on_tick, processPlacementQueue)
  else
    script.on_event(defines.events.on_tick, nil)
  end
end
