require("__cargo-ships__/constants")
local collision_mask_util = require("__core__/lualib/collision-mask-util")

data.raw.tile["landfill"].check_collision_with_entities = true

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
local loading_pump = data.raw["pump"]["ship-loading-pump"]
local loading_pump_collision_mask = loading_pump.collision_mask
loading_pump_collision_mask.layers["pump"] = true
loading_pump.collision_mask = loading_pump_collision_mask


local unloading_pump = data.raw["pump"]["ship-unloading-pump"]
local unloading_pump_collision_mask = unloading_pump.collision_mask
unloading_pump_collision_mask.layers["pump"] = true
unloading_pump.collision_mask = unloading_pump_collision_mask


for _, character in pairs(data.raw.character) do
  local collision_mask = collision_mask_util.get_mask(character)
  if collision_mask.layers["player"] then
    collision_mask.layers["pump"] = true
    character.collision_mask = collision_mask
  end
end


-- Factorio 2.1 requires rolling stock and its next_upgrade target to share the same connection_distance.
for _, stock_type in pairs({ "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon" }) do
  if data.raw[stock_type] then
    for _, name in pairs({ "boat", "boat_engine", "cargo_ship", "cargo_ship_engine", "oil_tanker" }) do
      if data.raw[stock_type][name] then
        data.raw[stock_type][name].next_upgrade = nil
      end
    end
  end
end
