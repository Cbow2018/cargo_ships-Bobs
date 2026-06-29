require("util")
local math2d = require("math2d")
require("__cargo-ships__/logic/ship_api")
require("__cargo-ships__/logic/ship_placement")
require("__cargo-ships__/logic/rail_placement")
require("__cargo-ships__/logic/long_reach")
require("__cargo-ships__/logic/bridge_logic")
require("__cargo-ships__/logic/blueprint_logic")
require("__cargo-ships__/logic/ship_enter")
--require("__cargo-ships__/logic/crane_logic")

local save_restore = require("__Robot256Lib__/script/save_restore")


is_waterway = util.list_to_map{
  "waterway",
  "straight-waterway",
  "half-diagonal-waterway",
  "curved-waterway-a",
  "curved-waterway-b",
  "legacy-straight-waterway",
  "legacy-curved-waterway"
}

is_rail = util.list_to_map{
  "rail",
  "straight-rail",
  "half-diagonal-rail",
  "curved-rail-a",
  "curved-rail-b",
  "legacy-straight-rail",
  "legacy-curved-rail",
  "rail-ramp",
}


-- spawn additional invisible entities
local function OnEntityBuilt(event)

  local entity = event.entity or event.destination
  local surface = entity.surface
  local quality = entity.quality
  local force = entity.force
  local player = (event.player_index and game.players[event.player_index]) or nil

  --log("OnEntityBuilt Event happened:"..serpent.block(event))

  -- check ghost entities first
  if entity.name == "entity-ghost" then
    if is_waterway[entity.ghost_name] then
      -- Attempt to revive the waterway ghost
      -- If this fails, then it is waiting for a tile to be deconstructed under it.
      -- A robot will come later and revive it after the tiles are removed (no item required)
      if not entity.silent_revive{raise_revive = true} then
        -- Waterway could not be revived, add to list to revive later
        -- look for colliding entities and tile deconstruction markers
        local found_entities = entity.surface.find_entities_filtered{area=entity.bounding_box, to_be_deconstructed=true}
        storage.waterway_ghosts = storage.waterway_ghosts or {}
        for i,e in pairs(found_entities) do
          script.register_on_object_destroyed(e)
          local e_num = e.unit_number or 0
          storage.waterway_ghosts[e_num] = storage.waterway_ghosts[e_num] or {}
          table.insert(storage.waterway_ghosts[e_num], entity)
        end
      end
    elseif entity.ghost_name == "bridge_gate" then
      -- Replace with proper bridge_base ghost
      HandleBridgeGhost(entity)
    elseif entity.ghost_name == "or_tank" or entity.ghost_name == "or_pole" then
      -- Delete oil rig parts if placed without an oil_rig
      table.insert(storage.check_placement_queue, {entity=entity})
      RegisterPlacementOnTick()
    end

  elseif storage.boat_bodies[entity.name] then
    CheckBoatPlacement(entity, player)

  elseif (entity.type == "cargo-wagon" or entity.type == "fluid-wagon" or
          entity.type == "locomotive" or entity.type == "artillery-wagon") then
    local engine = nil
    if storage.ship_bodies[entity.name] then
      local ship_data = storage.ship_bodies[entity.name]
      if ship_data.engine then
        local engine_loc = localizeEngine(entity)
        --game.print("looking for engine ghost at "..util.positiontostr(engine_loc.pos).." pointing "..tostring(engine_loc.dir))
        -- see if there is an engine ghost from a blueprint behind us
        local ghost = surface.find_entities_filtered{ghost_name=ship_data.engine, position=engine_loc.pos, force=force, limit=1}[1]
        if ghost then
          --game.print("found ghost at "..util.positiontostr(ghost.position).." pointing "..tostring(ghost.orientation)..", reviving")
          local dummy
          dummy, engine = ghost.revive()
          -- If couldn't revive engine, destroy ghost
          if not engine then
            game.print("couldn't revive ghost at "..util.positiontostr(ghost.position))
            ghost.destroy()
          end
        end
        if not engine then
          --log("Creating "..ship_data.engine.." for "..entity.name.." at "..serpent.line(engine_loc.pos))
          engine = surface.create_entity{
            name = ship_data.engine,
            quality = quality,
            position = engine_loc.pos,
            direction = engine_loc.dir,
            force = force,
            create_build_effect_smoke = false,
          }
          -- Check if we just deleted an engine from fast-replacing a ship
          if engine and storage.fast_replace_cache and storage.fast_replace_cache[game.tick] then
            for index,cachedata in pairs(storage.fast_replace_cache[game.tick]) do
              if cachedata.name == ship_data.engine and 
                 cachedata.force == force and
                 math2d.position.distance_squared(cachedata.position, engine_loc.pos) < 0.5 and
                 cachedata.direction == engine_loc.dir then
                -- Cache is a match, restore parameters after creating the engine
                --log("Restoring cached burner and grid to fast-replaced "..tostring(engine))
                --log(serpent.block(cachedata))
                save_restore.restoreBurner(engine.burner, cachedata.burner)
                save_restore.restoreGrid(engine.grid, cachedata.grid)
                if cachedata.driver then
                  engine.set_driver(cachedata.driver)
                end
                if cachedata.insert_plan or cachedata.removal_plan then
                  engine.surface.create_entity{name="item-request-proxy", position=engine.position, force=engine.force, target=engine, modules=cachedata.insert_plan, removal_plan=cachedata.removal_plan}
                end
                break
              end
            end
          end
        end
      end
    end
    -- check placement in next tick after wagons connect
    table.insert(storage.check_placement_queue, {entity=entity, engine=engine, player=player, robot=event.robot})
    RegisterPlacementOnTick()
  
  -- create bridge
  elseif entity.name == "bridge_base" then
    CreateBridge(entity, player, event.robot)

  -- make waterway not collide with boats by replacing it with entity that does not have "ground-tile" in its collision mask
  elseif is_rail[entity.type] then
    CheckRailPlacement(entity, player, event.robot)

  --elseif entity.name == "crane" then
  --  OnCraneCreated(entity)
  end
end

local function OnMarkedForDeconstruction(event)
  local entity = event.entity
  if is_waterway[entity.name] then
    -- Instantly deconstruct waterways
    entity.destroy()
  elseif storage.ship_bodies[entity.name] or storage.ship_engines[entity.name] then
    -- If a ship or ship engine is marked for deconstruction, make sure its coupled pair is too
    -- But wait until the next tick after all undo/redo actions have been completed, if that's what caused this marking
    table.insert(storage.check_placement_queue, {entity=entity, player=game.players[event.player_index]})
    RegisterPlacementOnTick()
  end
end

local function OnCancelledDeconstruction(event)
  local entity = event.entity
  if storage.ship_bodies[entity.name] or storage.ship_engines[entity.name] then
    -- If a ship or ship engine is cancelled for deconstruction, make sure its coupled pair is too
    if entity.train then
      local otherstock
      -- Find attached engine or body
      otherstock = entity.get_connected_rolling_stock(defines.rail_direction.front) or 
                   entity.get_connected_rolling_stock(defines.rail_direction.back)
      if otherstock and otherstock.to_be_deconstructed() then
        -- Copy deconstruction order
        local player = event.player_index and game.players[event.player_index]
        local force = (player and player.force) or entity.force
        otherstock.cancel_deconstruction(force, player)
      end
    end
  end
end

local function OnGiveWaterway(event)
  local player = game.get_player(event.player_index)
  local cleared = player.clear_cursor()
  if cleared then
    player.cursor_ghost = {name="waterway"}
  end
end

-- delete invisible entities if master entity is destroyed
local function OnEntityDeleted(event)
  --log("entity deleted happened:"..serpent.block(event))
  local entity = event.entity
  if(entity and entity.valid) then
    if storage.ship_bodies[entity.name] then
      if entity.train then
        if entity.train.back_stock then
          if storage.ship_engines[entity.train.back_stock.name] then
            --log("Destroying back_stock "..tostring(entity.train.back_stock))
            entity.train.back_stock.destroy()
          end
        end
        if entity.train.front_stock then
          if storage.ship_engines[entity.train.front_stock.name] then
            --log("Destroying front_stock "..tostring(entity.train.front_stock))
            entity.train.front_stock.destroy()
          end
        end
      end

    elseif storage.ship_engines[entity.name] then
      if entity.train then
        if entity.train.front_stock then
          if storage.ship_bodies[entity.train.front_stock.name] then
            --log("Destroying front_stock "..tostring(entity.train.front_stock))
            entity.train.front_stock.destroy()
          end
        end
        if entity.train.back_stock then
          if storage.ship_bodies[entity.train.back_stock.name]  then
            --log("Destroying back_stock "..tostring(entity.train.back_stock))
            entity.train.back_stock.destroy()
          end
        end
      end
    
    end
  end
end



-- Create ship engine corpse when the ship body dies
local function OnEntityDied(event)
  --log("entity deleted happened:"..serpent.block(event))
  local entity = event.entity
  if(entity and entity.valid) then
    if storage.ship_bodies[entity.name] then
      if entity.train then
        if entity.train.back_stock then
          if storage.ship_engines[entity.train.back_stock.name] then
            --log("Destroying back_stock "..tostring(entity.train.back_stock))
            entity.train.back_stock.die(event.force, event.cause)
          end
        end
        if entity.train.front_stock then
          if storage.ship_engines[entity.train.front_stock.name] then
            --log("Destroying front_stock "..tostring(entity.train.front_stock))
            entity.train.front_stock.die(event.force, event.cause)
          end
        end
      end

    elseif storage.ship_engines[entity.name] then
      if entity.train then
        if entity.train.front_stock then
          if storage.ship_bodies[entity.train.front_stock.name] then
            --log("Destroying front_stock "..tostring(entity.train.front_stock))
            entity.train.front_stock.die(event.force, event.cause)
          end
        end
        if entity.train.back_stock then
          if storage.ship_bodies[entity.train.back_stock.name]  then
            --log("Destroying back_stock "..tostring(entity.train.back_stock))
            entity.train.back_stock.die(event.force, event.cause)
          end
        end
      end
    
    end
  end
end

-- Perform the destroyed action for this unit_number
-- Each method checks if it applies
function OnObjectDestroyed(event)
  -- on_object_destroyed can fire for non-entity targets 
  -- Without this check, useful_id may collide with an oil rig unit_number and trigger unintended destruction
  if event.type ~= defines.target_type.entity then return end

  local unit_number = event.useful_id
  -- Check if this entity makes space for a waterway ghost
  if storage.waterway_ghosts and storage.waterway_ghosts[unit_number] then
    -- try to revive all the waterways referenced in this list
    local keep_list = {}
    for _,wg in pairs(storage.waterway_ghosts[unit_number]) do
      if wg.valid then
        -- Try to revive this waterway ghost. If it fails, that's fine, we'll try again when a different colliding entity is destroyed.
        if not wg.silent_revive{raise_revive = true} then
          if unit_number == 0 then
            table.insert(keep_list, wg)
          end
        end
      end
    end
    if unit_number == 0 then
      -- tile proxies all have unit_number 0, keep any non-revived ghosts in that list, since we have to keep coming back to it
      storage.waterway_ghosts[unit_number] = keep_list
    else
      -- delete list for entity that doesn't exist anymore, regardless of what we did about it
      storage.waterway_ghosts[unit_number] = nil
    end
  end
  
  -- Bridges
  if HandleBridgeDestroyed(unit_number) then return end
end


-- Robots can try to mine it, but get sent away with something else if there is still cargo
local function OnRobotPreMined(event)
  --log("OnRobotPreMined happened:"..serpent.block(event))
  if(event.entity and event.entity.valid) then
    local entity = event.entity
    if storage.ship_bodies[entity.name] or storage.ship_engines[entity.name] then
      -- Find attached engine or body
      local otherstock = entity.get_connected_rolling_stock(defines.rail_direction.front) or 
                         entity.get_connected_rolling_stock(defines.rail_direction.back)
      if otherstock then
        local save_inventory
        -- Get the correct inventory from the attached engine or body
        -- Ignore engines with recover_fuel=false because they don't have fuel items to recover
        if storage.ship_engines[otherstock.name] and storage.ship_engines[otherstock.name].recover_fuel then
          save_inventory = otherstock.get_fuel_inventory()
        -- If not an engine, then it must be a body because we already checked it's one or the other
        elseif otherstock.type == "cargo-wagon" then
          save_inventory = otherstock.get_inventory(defines.inventory.cargo_wagon)
        elseif otherstock.type == "artillery-wagon" then
          save_inventory = otherstock.get_inventory(defines.inventory.artillery_wagon_ammo)
        end
        if save_inventory and not save_inventory.is_empty() then
          -- Give contents of inventory to robot
          local robotInventory = event.robot.get_inventory(defines.inventory.robot_cargo)
          local robotSize = 1 + event.robot.force.worker_robots_storage_bonus
          if robotInventory.is_empty() then
            -- Find something to give to the robot. Otherwise the robot remains empty when the event returns, and it will finish mining the entity
            for index=1, #save_inventory do
              local stack = save_inventory[index]
              if stack.valid_for_read then
                --game.print("Giving robot cargo stack: "..stack.name.." : "..stack.count)
                local inserted = robotInventory.insert{name=stack.name, quality=stack.quality, count=math.min(stack.count, robotSize)}
                save_inventory.remove{name=stack.name, quality=stack.quality, count=inserted}
                if not robotInventory.is_empty() then
                  break
                end
              end
            end
          end
        end
      end
    end
  end
end

-- Robot mining the actually ship/engine (after both are empty).
-- If one half of a ship is mined, also mine the other half into the same robot. Only one of them will be the actual item.
local function OnRobotMinedEntity(event)
  --log("OnRobotMined happened:"..serpent.block(event))
  --if event.robot then
    --log("Robot contents: "..serpent.block(event.robot.get_inventory(defines.inventory.robot_cargo).get_contents()))
  --end
  if event.entity and event.entity.valid then
    local entity = event.entity
    if storage.ship_bodies[entity.name] or storage.ship_engines[entity.name] then
      -- Find attached engine or body to mine
      local otherstock = entity.get_connected_rolling_stock(defines.rail_direction.front) or 
                         entity.get_connected_rolling_stock(defines.rail_direction.back)
      if otherstock then
        -- If the robot has an item which can be used to upgrade this ship entity, then this is an upgrade operation
        local do_cache = true
        -- 1. Check if the robot has anything in it
        local robot_stack = event.robot.get_inventory(defines.inventory.robot_cargo)[1]
        if not (robot_stack and robot_stack.valid_for_read and robot_stack.count > 0) then
          do_cache = false
        else
          -- Robot contains an item
          -- Check if item can place existing entity
          local can_place_entity_with_item = false
          for _,item in pairs(entity.prototype.items_to_place_this) do
            if item.name == robot_stack.name then
              can_place_entity_with_item = true
              break
            end
          end
          -- Check if item's placement default has the same fast-replace group as existing entity
          local original_group = event.entity.prototype.fast_replaceable_group
          local new_group = robot_stack.prototype.place_result and robot_stack.prototype.place_result.fast_replaceable_group
          local can_fast_replace_entity_with_item = (new_group and new_group == original_group)
          local new_entity_name = can_fast_replace_entity_with_item and robot_stack.prototype.place_result.name
          
          if not (can_place_entity_with_item or can_fast_replace_entity_with_item) then
            do_cache = false
          else
            -- Robot's item can place the existing entity
            -- Check that the new ship uses the same engine
            if can_place_entity_with_item or (new_entity_name and storage.ship_bodies[new_entity_name] and storage.ship_bodies[new_entity_name].engine == otherstock.name) then
              -- The new entity uses the same engine
              do_cache = true
            else
              do_cache = false
            end
          end
        end
        
        if do_cache then
          --log("OnRobotMinedEntity detected robot upgrading a ship. Caching data and destroying engine "..tostring(otherstock).." ("..otherstock.quality.name..").")
          
          -- Save this invisible locomotive to restore later if we need it in the same tick
          storage.fast_replace_cache = storage.fast_replace_cache or {}
          storage.fast_replace_cache[game.tick] = storage.fast_replace_cache[game.tick] or {}
          log("About to call saveItemRequestProxy")
          local insert_plan, removal_plan = save_restore.saveItemRequestProxy(otherstock)
          if insert_plan then log("Insert plan:"..serpent.block(insert_plan)) end
          if removal_plan then log("Removal plan:"..serpent.block(removal_plan)) end
          table.insert(storage.fast_replace_cache[game.tick], 
            {
              name = otherstock.name,
              quality = otherstock.quality.name,
              position = otherstock.position,
              orientation = otherstock.orientation,
              direction = orientation_to_direction(otherstock.orientation),
              force = otherstock.force,
              burner = save_restore.saveBurner(otherstock.burner),
              grid = save_restore.saveGrid(otherstock.grid),
              driver = otherstock.get_driver(),
              insert_plan = #insert_plan>0 and insert_plan or nil,
              removal_plan = #removal_plan>0 and removal_plan or nil,
            }
          )
          otherstock.set_driver(nil)
          otherstock.destroy()
          
        else
          --log("OnRobotMinedEntity did not cache engine "..tostring(otherstock).." ("..otherstock.quality.name.." because it was not compatible with robot's item="..robot_item)
          otherstock.mine{inventory=event.robot.get_inventory(defines.inventory.robot_cargo), force=true, raise_destroyed=false, ignore_minable=true}
        end
      end
    end
  end
end

-- When the player mines a ship or engine, also make the player mine the coupled entity
-- Unfortunately the API won't let us combine them into one undo action yet
local function OnPlayerMinedEntity(event)
  --log("OnPlayerMined happened:"..serpent.block(event))
  if event.buffer and event.buffer.valid then log("Event buffer: "..serpent.block(event.buffer.get_contents())) end
  --log("Player cursor: "..serpent.line(game.players[event.player_index].cursor_stack))
  local entity = event.entity
  local player = game.players[event.player_index]
  if entity and entity.valid then
    storage.currently_mining = storage.currently_mining or {}
    if not storage.currently_mining[entity.unit_number] then
      if storage.ship_bodies[entity.name] or storage.ship_engines[entity.name] then
        -- Find attached engine or body to mine
        local otherstock = entity.get_connected_rolling_stock(defines.rail_direction.front) or 
                           entity.get_connected_rolling_stock(defines.rail_direction.back)
        if otherstock then
          --storage.currently_mining[otherstock.unit_number] = entity
          
          -- If the player has an item which can be used to upgrade this ship entity, then this is an upgrade operation
          local do_cache = true
          -- 1. Check if the Cursor has anything in it
          local cursor_stack = player.cursor_stack
          if not (cursor_stack and cursor_stack.valid_for_read and cursor_stack.count > 0) then
            do_cache = false
          else
            -- Cursor contains an item
            -- Check if item can place existing entity
            local can_place_entity_with_item = false
            for _,item in pairs(entity.prototype.items_to_place_this) do
              if item.name == cursor_stack.name then
                can_place_entity_with_item = true
                break
              end
            end
            -- Check if item's placement default has the same fast-replace group as existing entity
            local original_group = event.entity.prototype.fast_replaceable_group
            local new_group = cursor_stack.prototype.place_result and cursor_stack.prototype.place_result.fast_replaceable_group
            local can_fast_replace_entity_with_item = (new_group and new_group == original_group)
            local new_entity_name = can_fast_replace_entity_with_item and cursor_stack.prototype.place_result.name
            
            if not (can_place_entity_with_item or can_fast_replace_entity_with_item) then
              do_cache = false
            else
              -- Cursor's item can place the existing entity
              -- Check that the new ship uses the same engine
              if can_place_entity_with_item or (new_entity_name and storage.ship_bodies[new_entity_name] and storage.ship_bodies[new_entity_name].engine == otherstock.name) then
                -- The new entity uses the same engine
                do_cache = true
              else
                do_cache = false
              end
            end
          end
          
          if do_cache then
            --log("OnPlayerMinedEntity detected player upgrading a ship. Caching data and destroying engine "..tostring(otherstock).." ("..otherstock.quality.name..").")
            
            -- Save this invisible locomotive to restore later if we need it in the same tick
            storage.fast_replace_cache = storage.fast_replace_cache or {}
            storage.fast_replace_cache[game.tick] = storage.fast_replace_cache[game.tick] or {}
            
            log("About to call saveItemRequestProxy")
            local insert_plan, removal_plan = save_restore.saveItemRequestProxy(otherstock)
            if insert_plan then log("Insert plan:"..serpent.block(insert_plan)) end
            if removal_plan then log("Removal plan:"..serpent.block(removal_plan)) end
          
            table.insert(storage.fast_replace_cache[game.tick], 
              {
                name = otherstock.name,
                quality = otherstock.quality.name,
                position = otherstock.position,
                orientation = otherstock.orientation,
                direction = orientation_to_direction(otherstock.orientation),
                force = otherstock.force,
                burner = save_restore.saveBurner(otherstock.burner),
                grid = save_restore.saveGrid(otherstock.grid),
                driver = otherstock.get_driver(),
                insert_plan = #insert_plan>0 and insert_plan or nil,
                removal_plan = #removal_plan>0 and removal_plan or nil,
              }
            )
            otherstock.set_driver(nil)
            otherstock.destroy()
            
          else
            -- Otherstock needs to be mined along with entity
            -- But the undo stack item won't be created until this event ends
            -- check placement in next tick after wagons connect
            table.insert(storage.check_placement_queue, {entity=otherstock, player=player, undo_index=1})
            RegisterPlacementOnTick()
          end
        end
      end
    else
      -- This mining operation was started by script, don't start another one and clear the flag
      storage.currently_mining[entity.unit_number] = nil
    end
  end
end

-- OnUndoApplied fires *after* all the actions have been completed
-- It tells you the actions that it UNdid.
-- E.g., a "built-entity" action in the undo actions means that entity was just marked for deconstruction now.
local function OnUndoApplied(event)
  local actions = event.actions
  local action = actions[1]
  --log("OnUndoApplied:"..serpent.block(actions))
  if #actions == 1 and action.type == "removed-entity" and storage.ship_engines[action.target.name] then
    -- Find the ghost at the action coordinates
    local surface = game.surfaces[action.surface_index]
    local found = surface and surface.find_entities_filtered{ghost_name=action.target.name, position=action.target.position, limit=1}
    
    if found and found[1] then
      found[1].destroy()
      log("Destroyed engine ghost from undo action")
    else
      --log("Couldn't find ghost engine from undo action")
    end
  end
end

-- Check if this undo created a lone ship engine ghost, because that's not allowed
local function OnRedoApplied(event)
  local actions = event.actions
  local action = actions[1]
  --log("OnRedoApplied:"..serpent.block(actions))
  if #actions == 1 and action.type == "removed-entity" and storage.ship_engines[action.target.name] then
    -- Find the ghost at the action coordinates
    local surface = game.surfaces[action.surface_index]
    local found = surface and surface.find_entities_filtered{ghost_name=action.target.name, position=action.target.position, limit=1}
    
    if found and found[1] then
      found[1].destroy()
      log("Destroyed engine ghost from redo action")
    else
      --log("Couldn't find ghost engine from redo action")
    end
  end
end

local function OnModSettingsChanged(event)
  if event.setting == "waterway_reach_increase" then
    storage.current_distance_bonus = settings.global["waterway_reach_increase"].value
    applyReachChanges()
  end
end

local function OnStackChanged(event)
  increaseReach(event)
end

-- Register conditional events based on mod settting
function init_events()
  -- entity created, check placement and create invisible elements
  local entity_filters = {
      {filter="ghost", ghost_name="bridge_gate"},
      {filter="ghost", ghost_name="straight-waterway"},
      {filter="ghost", ghost_name="half-diagonal-waterway"},
      {filter="ghost", ghost_name="curved-waterway-a"},
      {filter="ghost", ghost_name="curved-waterway-b"},
      {filter="ghost", ghost_name="legacy-straight-waterway"},
      {filter="ghost", ghost_name="legacy-curved-waterway"},
      {filter="name", name="bridge_base"},
      {filter="rolling-stock"},
      {filter="rail"}
    }
  if storage.boat_bodies then
    for name,_ in pairs(storage.boat_bodies) do
      table.insert(entity_filters, {filter="name", name=name})
    end
  end
  script.on_event(defines.events.on_built_entity, OnEntityBuilt, entity_filters)
  script.on_event(defines.events.on_robot_built_entity, OnEntityBuilt, entity_filters)
  script.on_event(defines.events.on_entity_cloned, OnEntityBuilt, entity_filters)
  script.on_event(defines.events.script_raised_built, OnEntityBuilt, entity_filters)
  script.on_event(defines.events.script_raised_revive, OnEntityBuilt, entity_filters)

  -- delete invisible bridge and ship elements
  local deleted_filters = {}
  if storage.ship_bodies then
    for name,_ in pairs(storage.ship_bodies) do
      table.insert(deleted_filters, {filter="name", name=name})
      table.insert(deleted_filters, {filter="ghost_name", name=name})
    end
  end
  if storage.ship_engines then
    for name,_ in pairs(storage.ship_engines) do
      table.insert(deleted_filters, {filter="name", name=name})
    end
  end
  script.on_event(defines.events.on_entity_died, OnEntityDied, deleted_filters)
  script.on_event(defines.events.script_raised_destroy, OnEntityDeleted, deleted_filters)
  
  -- Handle Bridge components
  script.on_event(defines.events.on_object_destroyed, OnObjectDestroyed)

  -- recover fuel from mined ships
  local mined_filters = {}
  if storage.ship_bodies then
    for name,_ in pairs(storage.ship_bodies) do
      table.insert(mined_filters, {filter="name", name=name})
    end
  end
  if storage.ship_engines then
    for name,_ in pairs(storage.ship_engines) do
      table.insert(mined_filters, {filter="name", name=name})
    end
  end
  script.on_event(defines.events.on_robot_pre_mined, OnRobotPreMined, mined_filters)
  script.on_event(defines.events.on_player_mined_entity, OnPlayerMinedEntity, mined_filters)
  script.on_event(defines.events.on_robot_mined_entity , OnRobotMinedEntity, mined_filters)
  
  script.on_event(defines.events.on_undo_applied, OnUndoApplied)
  script.on_event(defines.events.on_redo_applied, OnRedoApplied)
  
  local deconstructed_filters = {
    {filter="name", name="straight-waterway"},
    {filter="name", name="half-diagonal-waterway"},
    {filter="name", name="curved-waterway-a"},
    {filter="name", name="curved-waterway-b"},
    {filter="name", name="legacy-straight-waterway"},
    {filter="name", name="legacy-curved-waterway"},
  }
  if storage.ship_bodies then
    for name,_ in pairs(storage.ship_bodies) do
      table.insert(deconstructed_filters, {filter="name", name=name})
    end
  end
  if storage.ship_engines then
    for name,_ in pairs(storage.ship_engines) do
      table.insert(deconstructed_filters, {filter="name", name=name})
    end
  end
  script.on_event(defines.events.on_marked_for_deconstruction, OnMarkedForDeconstruction, deconstructed_filters)
  
  local cancel_decon_filters = {}
  if storage.ship_bodies then
    for name,_ in pairs(storage.ship_bodies) do
      table.insert(cancel_decon_filters, {filter="name", name=name})
    end
  end
  if storage.ship_engines then
    for name,_ in pairs(storage.ship_engines) do
      table.insert(cancel_decon_filters, {filter="name", name=name})
    end
  end
  script.on_event(defines.events.on_cancelled_deconstruction, OnCancelledDeconstruction, cancel_decon_filters)
  
  -- update ship placement
  RegisterPlacementOnTick()
  
  -- bridge queue
  RegisterBridgeNthTick()
  
  -- long reach
  script.on_event(defines.events.on_player_cursor_stack_changed, OnStackChanged)
  script.on_event(defines.events.on_pre_player_died, deadReach)

  -- pipette
  script.on_event(defines.events.on_player_pipette, FixPipette)
  
  -- bridge blueprint
  script.on_event({defines.events.on_player_setup_blueprint,
                   defines.events.on_player_configured_blueprint}, HandleBridgeBlueprint)
  

  -- rolling stock connection handling
  script.on_event(defines.events.on_train_created, OnTrainCreated)

  -- Mod setting change propagation
  script.on_event(defines.events.on_runtime_mod_setting_changed, OnModSettingsChanged)

  -- custom-input and shortcut button
  script.on_event({defines.events.on_lua_shortcut, "give-waterway"},
    function(event)
      if event.prototype_name and event.prototype_name ~= "give-waterway" then return end
      OnGiveWaterway(event)
    end
  )
  
  -- Compatibility with AAI Vehicles (Modify this whenever the list of boats changes)
  remote.remove_interface("aai-sci-burner")
  remote.add_interface("aai-sci-burner", {
    hauler_types = function(data)
      local types={}
      if storage.boat_bodies then
        for name,_ in pairs(storage.boat_bodies) do
          table.insert(types, name)
        end
      end
      return types
    end,
  })

end


local function init()
  -- Init storage variables
  storage.check_placement_queue = storage.check_placement_queue or {}
  storage.bridges = storage.bridges or {}
  storage.bridge_destroyed_queue = storage.bridge_destroyed_queue or {}
  storage.ship_pump_selected = nil -- Obsolete, delete for migration's sake
  storage.disable_this_tick = storage.disable_this_tick or {}
  storage.driving_state_locks = storage.driving_state_locks or {}
  storage.currently_mining = storage.currently_mining or {}

  init_ship_globals()  -- Init database of ship parameters

  -- Initialize or migrate long reach state
  storage.last_cursor_stack_name =
    ((type(storage.last_cursor_stack_name) == "table") and storage.last_cursor_stack_name)
      or {}
  storage.last_distance_bonus =
    ((type(storage.last_distance_bonus) == "number") and storage.last_distance_bonus)
      or settings.global["waterway_reach_increase"].value
  storage.current_distance_bonus = settings.global["waterway_reach_increase"].value

  -- Register conditional events
  init_events()
end

---- Register Default Events ----
-- init
script.on_load(function()
  init_events()
end)

script.on_init(function()
  init()
end)

script.on_configuration_changed(function(event)
  -- Migration validation checks
  if event.old_version then
    log("Cargo Ships migrating save file from Factorio "..event.old_version)
  end
  if event.mod_changes["cargo-ships"] then
    log("Cargo Ships migrating save file from Cargo Ships "..event.mod_changes["cargo-ships"].old_version)
  end
  
  local was_20 = event.old_version and string.find(event.old_version, "2.0")
  was_20 = (was_20 and was_20 == 1) or false
  local was_21 = event.old_version and string.find(event.old_version, "2.1")
  was_21 = (was_21 and was_21 == 1) or false
  
  if not (was_20 or was_21) then    -- Old map was saved before 2.0
    -- Reading a 1.1 or older save
    log(">>> CARGO SHIPS 1.1 MIGRATION WARNING TRIGGERED <<<")
    game.print({"cargo-ship-message.migration-11-warning"})
  end
  
  if not was_21 and (event.mod_changes["cargo-ships"] and event.mod_changes["cargo-ships"].old_version) and        -- Old map from before 2.1 had cargo ships, and
     not ((event.mod_changes["cargo-ships-oil-rig"] and event.mod_changes["cargo-ships-oil-rig"].new_version) and  -- One or both companion mods is not installed
          (event.mod_changes["cargo-ships-floating-electric-pole"] and event.mod_changes["cargo-ships-floating-electric-pole"].new_version)) then
    log(">>> CARGO SHIPS 2.0 MIGRATION WARNING TRIGGERED <<<")
    game.print({"cargo-ship-message.migration-21-warning"})
  end
  
  init()
  
end)

---@param train LuaTrain
function CopyLocoColor(train)
  local locos = train.locomotives.front_movers
  local loco = locos and locos[1]
  if not (loco and loco.valid) or loco.name ~= "boat_engine" then
    return
  end

  for _, wagon in pairs(train.cargo_wagons) do
    wagon.color = loco.color
  end
end

---@param event EventData.on_train_schedule_changed|EventData.on_train_changed_state 
function CopyLocoColorEvent(event)
  CopyLocoColor(event.train)
end

script.on_event(defines.events.on_train_schedule_changed, CopyLocoColorEvent)
script.on_event(defines.events.on_train_changed_state, CopyLocoColorEvent)
script.on_event(defines.events.on_gui_closed, function(event)
  local entity = event.entity
  if not (entity and entity.name == "boat_engine") then return end
  local train = entity.train
  if not train then return end

  CopyLocoColor(train)
end)

-- Console commands
commands.add_command("cargo-ships-dump", "Dump storage to log", function() log(serpent.block(storage)) end)

------------------------------------------------------------------------------------
--                    FIND LOCAL VARIABLES THAT ARE USED GLOBALLY                 --
--                              (Thanks to eradicator!)                           --
------------------------------------------------------------------------------------
setmetatable(_ENV,{
  __newindex=function (self,key,value) --locked_global_write
    error('\n\n[ER Global Lock] Forbidden global *write*:\n'
      .. serpent.line{key=key or '<nil>',value=value or '<nil>'}..'\n')
    end,
  __index   =function (self,key) --locked_global_read
    error('\n\n[ER Global Lock] Forbidden global *read*:\n'
      .. serpent.line{key=key or '<nil>'}..'\n')
    end ,
  })

