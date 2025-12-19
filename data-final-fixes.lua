require("__cargo-ships__/constants")
local collision_mask_util = require("__core__/lualib/collision-mask-util")

data.raw.tile["landfill"].check_collision_with_entities = true

-- Apply Space Age power pole tile settings
if settings.startup["floating_pole_enabled"].value and mods["space-age"] and 
  ((not settings.startup["floating_pole_fulgora"].value) or (not settings.startup["floating_pole_aquilo"].value)) then
  
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

-- Change inserters to not catch fish when waiting for ships
if settings.startup["no_catching_fish"].value then
  for _, inserter in pairs(data.raw.inserter) do
    inserter.use_easter_egg = false
  end
end

-- Krastorio2 fuel compatibility
if mods["Krastorio2"] then
  log("Updating boats and ships to use Krastorio2 kr-vehicle-fuel fuel category")
  data.raw.locomotive["cargo_ship_engine"].energy_source.fuel_categories = { "chemical", "kr-vehicle-fuel" }
  data.raw.locomotive["boat_engine"].energy_source.fuel_categories = { "kr-vehicle-fuel" }
  data.raw.car["indep-boat"].energy_source.fuel_categories = { "kr-vehicle-fuel" }
end

-- AAI/Space Exploration fuel compatibility
if mods["aai-industry"] then
  log("Updating boats and ships to use AAI Industry processed-chemcial fuel category")
  table.insert(data.raw.locomotive["cargo_ship_engine"].energy_source.fuel_categories, "processed-chemical")
  table.insert(data.raw.locomotive["boat_engine"].energy_source.fuel_categories, "processed-chemical")
  table.insert(data.raw.car["indep-boat"].energy_source.fuel_categories, "processed-chemical")
end

-- Ensure water rails don't collide with FISH when Space Exploration is installed
data.raw["straight-rail"]["straight-waterway"].collision_mask.layers.space_tile = nil
data.raw["half-diagonal-rail"]["half-diagonal-waterway"].collision_mask.layers.space_tile = nil
data.raw["curved-rail-a"]["curved-waterway-a"].collision_mask.layers.space_tile = nil
data.raw["curved-rail-b"]["curved-waterway-b"].collision_mask.layers.space_tile = nil
data.raw["legacy-straight-rail"]["legacy-straight-waterway"].collision_mask.layers.space_tile = nil
data.raw["legacy-curved-rail"]["legacy-curved-waterway"].collision_mask.layers.space_tile = nil


data.raw["rail-signal"]["buoy"].collision_mask.layers.space_tile = nil
data.raw["rail-chain-signal"]["chain_buoy"].collision_mask.layers.space_tile = nil
data.raw["rail-chain-signal"]["invisible-chain-signal"].collision_mask.layers.space_tile = nil

if data.raw["mining-drill"]["oil_rig"] then
  data.raw["mining-drill"]["oil_rig"].collision_mask.layers.space_tile = nil
end

-- Ensure player collides with pump
data:extend{
  {
    type = "collision-layer",
    name = "pump",
  },
}
local pump = data.raw["pump"]["pump"]
local pump_collision_mask = collision_mask_util.get_mask(pump)
pump_collision_mask.layers["pump"] = true
pump.collision_mask = pump_collision_mask
for _, character in pairs(data.raw.character) do
  local collision_mask = collision_mask_util.get_mask(character)
  if collision_mask.layers["player"] then
    collision_mask.layers["pump"] = true
    character.collision_mask = collision_mask
  end
end

-- Compatibility for pump upgrade mods
for _, other_pump in pairs(data.raw.pump) do
  if other_pump.fast_replaceable_group == pump.fast_replaceable_group then
    other_pump.collision_mask = table.deepcopy(pump.collision_mask)
  end
end

-----------------------------
---- DEEP OIL GENERATION ----
-----------------------------

if data.raw.resource["offshore-oil"] then
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
  
end
