require("util")
require("__cargo-ships-oil-rig__/logic/entity_placement")
require("__cargo-ships-oil-rig__/logic/blueprint_logic")
require("__cargo-ships-oil-rig__/logic/oil_rig_logic")
require("__cargo-ships-oil-rig__/logic/mapgen")


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
    if entity.ghost_name == "or_tank" or entity.ghost_name == "or_pole" then
      -- Delete oil rig parts if placed without an oil_rig
      table.insert(storage.check_placement_queue, {entity=entity})
      RegisterPlacementOnTick()
    end

  -- add oilrig component entities
  elseif entity.name == "oil_rig" then
    CreateOilRig(entity, player, event.robot)

  end
end

local function OnMarkedForDeconstruction(event)
  local entity = event.entity
  if entity.name == "oil_rig" then
    -- Also mark or_tank and or_pole for deconstruction in the same undo item
    --game.print("Register oil rig deconstruction")
    table.insert(storage.check_placement_queue, {entity=entity, player=game.players[event.player_index]})
    RegisterPlacementOnTick()
  end
end

local function OnCancelledDeconstruction(event)
  local entity = event.entity
  
  if entity.name == "oil_rig" then
    -- If an oil rig part has deconstruction cancelled, cancel the companion entities as well
    local parts = entity.surface.find_entities_filtered{position=entity.position, name = {"or_tank", "or_pole"}, to_be_deconstructed = true}
    local player = event.player_index and game.players[event.player_index]
    local force = (player and player.force) or entity.force
    for _,part in pairs(parts) do
      part.cancel_deconstruction(force, player)
    end
  end
end

-- delete invisible entities if master entity is destroyed
local function OnEntityDeleted(event)
  --log("entity deleted happened:"..serpent.block(event))
  local entity = event.entity
  if(entity and entity.valid) then
    if entity.name == "entity-ghost" then
      if entity.ghost_name == "oil_rig" then
        -- Delete any or_tank or or_pole ghosts in the area
        DestroyOilRigGhost(entity)
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
  
  -- Oil Rigs
  local player, undo_index
  if storage.currently_mining[unit_number] then
    player = storage.currently_mining[unit_number].player
    undo_index = storage.currently_mining[unit_number].undo_index
    storage.currently_mining[unit_number] = nil
  end
  if DestroyOilRig(unit_number, player, undo_index) then
    --log("OnObjectDestroyed happened:"..serpent.block(event))
    return
  end
  
end


-- When the player mines a ship or engine, also make the player mine the coupled entity
local function OnPlayerMinedEntity(event)
  --log("OnPlayerMined happened:"..serpent.block(event))
  if event.buffer and event.buffer.valid then log("Event buffer: "..serpent.block(event.buffer.get_contents())) end
  --log("Player cursor: "..serpent.line(game.players[event.player_index].cursor_stack))
  local entity = event.entity
  local player = game.players[event.player_index]
  if entity and entity.valid then
    storage.currently_mining = storage.currently_mining or {}
    if not storage.currently_mining[entity.unit_number] then
      if entity.name == "oil_rig" then
        -- Save what player this oil_rig is being mined by so it can be added to their undo stack
        storage.currently_mining[entity.unit_number] = {player=player, undo_index=1}
      end
    else
      -- This mining operation was started by script, don't start another one and clear the flag
      storage.currently_mining[entity.unit_number] = nil
    end
  end
end


-- Register conditional events based on mod settting
function init_events()
  -- entity created, check placement and create invisible elements
  local entity_filters = {{filter="name", name="oil_rig"}}
  script.on_event(defines.events.on_built_entity, OnEntityBuilt, entity_filters)
  script.on_event(defines.events.on_robot_built_entity, OnEntityBuilt, entity_filters)
  script.on_event(defines.events.on_entity_cloned, OnEntityBuilt, entity_filters)
  script.on_event(defines.events.script_raised_built, OnEntityBuilt, entity_filters)
  script.on_event(defines.events.script_raised_revive, OnEntityBuilt, entity_filters)

  -- delete ghosts of invisible oil rig elements
  local deleted_filters = {{filter="ghost_name", name="oil_rig"}}
  script.on_event(defines.events.on_entity_died, OnEntityDeleted, deleted_filters)
  script.on_event(defines.events.script_raised_destroy, OnEntityDeleted, deleted_filters)
  
  -- Destroy Oil Rig components if it disappears
  script.on_event(defines.events.on_object_destroyed, OnObjectDestroyed)

  -- Add Oil Rig components to undo stack
  local mined_filters = {{filter="name", name="oil_rig"}}
  script.on_event(defines.events.on_player_mined_entity, OnPlayerMinedEntity, mined_filters)
  
  script.on_event(defines.events.on_marked_for_deconstruction, OnMarkedForDeconstruction, {{filter="name", name="oil_rig"}})
  script.on_event(defines.events.on_cancelled_deconstruction, OnCancelledDeconstruction, {{filter="name", name="oil_rig"}})
  
  -- update ship placement
  RegisterPlacementOnTick()
  
  -- pipette
  script.on_event(defines.events.on_player_pipette, FixPipette)
  
  -- Oil rig tank de-rotation
  script.on_event({defines.events.on_player_rotated_entity, defines.events.on_player_flipped_entity}, CorrectOilRigTankRotation)

end


local function init()
  -- Init storage variables
  storage.check_placement_queue = storage.check_placement_queue or {}
  storage.oil_rigs = storage.oil_rigs or {}
  storage.currently_mining = storage.currently_mining or {}

  -- Add Heating Reactors to Oil Rigs on Aquilo etc if necessary (in case a mod changed the heating flag or a surface condition)
  MigrateOilRigReactors()

  -- Enable offshore oil generation if it has been added to a save
  oil_generation_migration()

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
script.on_configuration_changed(function()
  init()
end)

-- Console commands
commands.add_command("cargo-ships-oil-rig-dump", "Dump cargo-ships-oil-rig-dump storage to log", function() log(serpent.block(storage)) end)

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

