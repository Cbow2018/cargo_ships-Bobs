
-- Apply Space Age power pole tile settings
if mods["space-age"] then
  if ((not settings.startup["floating_pole_fulgora"].value) or (not settings.startup["floating_pole_aquilo"].value)) then
    data:extend{
      {
        type = "collision-layer",
        name = "offshore_pole",
      },
    }
    if not settings.startup["floating_pole_fulgora"].value then
      data.raw.tile["oil-ocean-shallow"].collision_mask.layers.offshore_pole = true
      data.raw.tile["oil-ocean-deep"].collision_mask.layers.offshore_pole = true
    end
    
    if not settings.startup["floating_pole_aquilo"].value then
      data.raw.tile["ammoniacal-ocean"].collision_mask.layers.offshore_pole = true
      data.raw.tile["ammoniacal-ocean-2"].collision_mask.layers.offshore_pole = true
    end
    
    data.raw["electric-pole"]["floating-electric-pole"].tile_buildability_rules[1].colliding_tiles = {layers={offshore_pole=true}}
  end
end

-- Make floating poles in electromagnetics plant
if data.raw['recipe-category']['electromagnetics'] then
  data.raw.recipe["floating-electric-pole"].categories = {'crafting', 'electromagnetics'}
end

-- Make floating poles depend on Boat research if present
if data.raw.technology["water_transport"] then
  table.insert(data.raw.technology["oversea-energy-distribution"].prerequisites, "water_transport")
end
