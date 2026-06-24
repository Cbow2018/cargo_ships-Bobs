
-- Find all the legacy-straight-waterway entities that used to be bridge_crossing and make them minable
local count = 0
for _, surface in pairs(game.surfaces) do
  for _, entity in pairs(surface.find_entities_filtered{name="legacy-straight-waterway"}) do
    if not entity.minable_flag then
      count = count + 1
      entity.minable_flag = true
    end
  end
end
if count > 0 then
  log("Fixed "..tostring(count).." waterways that were unminable.")
end
