local collision_mask_util = require("__core__/lualib/collision-mask-util")

-- Ensure no collision with FISH when Space Exploration is installed
data.raw["mining-drill"]["oil_rig"].collision_mask.layers.space_tile = nil

-- Make oil rig depend on Tanker research if present
if data.raw.technology["tank_ship"] then
  table.insert(data.raw.technology["deep_sea_oil_extraction"].prerequisites, "tank_ship")
end

-----------------------------
---- DEEP OIL GENERATION ----
-----------------------------

-- Add new "water_resource" collision layer to all the tiles that have "ground_tile"
local count = 0
for name, tile in pairs(data.raw.tile) do
  local collision_mask = tile.collision_mask
  if collision_mask.layers["ground_tile"] then
    --log("Adding collision layer 'water_resource' to tile '"..name.."'")
    collision_mask.layers["water_resource"] = true
    count = count + 1
  end
end
if count > 0 then
  log("Added collision layer 'water_resource' to "..tostring(count).." ground tiles.")
end

-- Add new "water_resource" collision layer to all non-deep water tiles if "Offshore oil on Deep Water only" is enabled
count = 0
if settings.startup["no_shallow_oil"].value then
  for _, name in pairs({"water", "water-green", "water-shallow", "water-mud"}) do
    if data.raw.tile[name] then
      local collision_mask = data.raw.tile[name].collision_mask
      --log("Adding collision layer 'water_resource' to tile '"..name.."'")
      collision_mask.layers["water_resource"] = true
      count = count + 1
    end
  end
end
if count > 0 then
  log("Added collision layer 'water_resource' to "..tostring(count).." shallow water tiles.")
end

-- Make sure the oil rig can mine deep oil:
data.raw["mining-drill"]["oil_rig"].resource_categories = {data.raw.resource["offshore-oil"].category}

if settings.startup["oil_rigs_require_external_power"].value ~= "enabled" then
  -- Make sure the oil rig can burn crude-oil
  data.raw.fluid["crude-oil"].fuel_value = data.raw.fluid["crude-oil"].fuel_value or "20MJ"
end

-- Make offshore-oil match crude-oil infinite setting (Krastorio2 compat)
data.raw.resource["offshore-oil"].infinite = data.raw.resource["crude-oil"].infinite
data.raw.resource["offshore-oil"].minimum = data.raw.resource["crude-oil"].minimum
data.raw.resource["offshore-oil"].normal = data.raw.resource["crude-oil"].normal
data.raw.resource["offshore-oil"].map_color = data.raw.resource["crude-oil"].map_color
