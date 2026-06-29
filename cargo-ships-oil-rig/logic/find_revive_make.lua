
-- args = {name, surface, position, radius?, force, quality?, player?, undo_index?, verbose?}
local function find_revive_make(args)
  args.quality = args.quality or prototypes.quality["normal"]
  args.radius = args.radius or 1
  
  -- Look for matching entity in the area
  local entity = args.surface.find_entities_filtered{name=args.name, position=args.position, radius=args.radius, limit = 1}[1]
  if entity then
    if args.verbose then log("Found existing "..args.name.." entity "..tostring(entity).." ("..entity.quality.name..")") end
  else
    -- Look for matching ghost in the area to revive
    local ghost = args.surface.find_entities_filtered{ghost_name=args.name, position=args.position, radius=args.radius, limit = 1}[1]
    if ghost then
      local dummy1,dummy2
      dummy1,entity,dummy2 = ghost.silent_revive()
      if args.verbose and entity then log("Revived existing ghost "..args.name.." entity "..tostring(entity).." ("..entity.quality.name..")") end
    end
  end
  
  -- Correct the entity position, rotation, and quality if needed
  if entity and entity.valid then
    -- Teleport to correct location
    if entity.position.x ~= args.position.x or entity.position.y ~= args.position.y then
      entity.teleport(args.position)
      if args.verbose and entity then log("Teleported existing "..args.name.." entity "..tostring(entity).." ("..entity.quality.name..")") end
    end
    
    -- Undo rotation and flipping
    entity.direction = defines.direction.north
    entity.mirroring = false
  
    -- Fast-upgrade the entity if it is the wrong quality
    if entity.quality ~= args.quality then
      entity = args.surface.create_entity{
            name=args.name,
            position=args.position,
            force=args.force,
            quality=args.quality,
            player=args.player,
            undo_index=args.undo_index,
            create_build_effect_smoke=false,
            fast_replace=true
      }
      if args.verbose and entity then log("Upgraded "..args.name.." entity "..tostring(entity).." ("..entity.quality.name..")") end
    end
  end
  
  -- Make a new entity if none of that worked
  if not entity or not entity.valid then
    entity = args.surface.create_entity{
          name=args.name,
          position=args.position,
          force=args.force,
          quality=args.quality,
          player=args.player,
          undo_index=args.undo_index,
          create_build_effect_smoke=false
    }
    if args.verbose then log("Created new "..args.name.." entity "..tostring(entity).." ("..entity.quality.name..")") end
  end
  return entity
end

return find_revive_make
