-- Look for ghost waterways, and register their obstacles if any

local waterway_names = {
  "straight-waterway",
  "half-diagonal-waterway",
  "curved-waterway-a",
  "curved-waterway-b",
  "legacy-straight-waterway",
  "legacy-curved-waterway"
}

for _,surface in pairs(game.surfaces) do
  local ghosts = surface.find_entities_filtered{ghost_name = waterway_names}
  if #ghosts > 0 then
    log("Waterway ghost migration found "..tostring(#ghosts).." ghosts on surface "..surface.name)
    local revived = 0
    local not_revived = 0
    local registered = 0
    for _,entity in pairs(ghosts) do
      -- Attempt to revive the waterway ghost
      -- If this fails, then it is waiting for a tile to be deconstructed under it.
      -- A robot will come later and revive it after the tiles are removed (no item required)
      if not entity.silent_revive{raise_revive = true} then
        not_revived = not_revived + 1
        -- Waterway could not be revived, add to list to revive later
        -- look for colliding entities and tile deconstruction markers
        local found_entities = surface.find_entities_filtered{area=entity.bounding_box, to_be_deconstructed=true}
        storage.waterway_ghosts = storage.waterway_ghosts or {}
        for i,e in pairs(found_entities) do
          script.register_on_object_destroyed(e)
          registered = registered + 1
          local e_num = e.unit_number or 0
          storage.waterway_ghosts[e_num] = storage.waterway_ghosts[e_num] or {}
          table.insert(storage.waterway_ghosts[e_num], entity)
        end
      else
        revived = revived + 1
      end
    end
    log(string.format("Revived %d ghosts, %d ghosts remain, registered %d entities to be deconstructed.", revived, not_revived, registered))
  end
end
