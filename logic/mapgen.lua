
-- Enable offshore oil generation if it has been added to a save
-- Make sure autoplace is enabled for entities before checking if offshore-oil is missing
function oil_generation_migration()
  if not prototypes.entity["offshore-oil"] then return end
  local map_gen_settings = game.planets.nauvis.surface.map_gen_settings
  if (map_gen_settings.autoplace_settings.entity and map_gen_settings.autoplace_settings.entity.settings and
      map_gen_settings.autoplace_settings.entity.settings["offshore-oil"] == nil) then
    map_gen_settings.autoplace_controls["offshore-oil"] = {}
    map_gen_settings.autoplace_settings.entity.settings["offshore-oil"] = {}
    game.planets.nauvis.surface.map_gen_settings = map_gen_settings
    game.planets.nauvis.surface.regenerate_entity("offshore-oil")
  else
    log("Entity autoplace settings are disabled for Nauvis, not adding offshore-oil")
  end
  if game.planets.aquilo and game.planets.aquilo.surface then
    local aquilo_map_gen_settings = game.planets.aquilo.surface.map_gen_settings
    if (aquilo_map_gen_settings.autoplace_settings.entity and aquilo_map_gen_settings.autoplace_settings.entity.settings and
        aquilo_map_gen_settings.autoplace_settings.entity.settings["offshore-oil"] == nil) then
      aquilo_map_gen_settings.autoplace_controls["aquilo_offshore_oil"] = {}
      aquilo_map_gen_settings.autoplace_settings.entity.settings["offshore-oil"] = {}
      game.planets.aquilo.surface.map_gen_settings = aquilo_map_gen_settings
      game.planets.aquilo.surface.regenerate_entity("offshore-oil")
    else
      log("Entity autoplace settings are disabled for Aquilo, not adding offshore-oil")
    end
  end
end

local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local usage_string_get = "Usage: /cargo-ships-get-oil-settings <planet>"
commands.add_command("cargo-ships-get-oil-settings", "Get oil settings\n" .. usage_string_get, function(command)
  if not command.parameter or (not game.planets[command.parameter] and not game.surfaces[command.parameter]) then
    game.print("Invalid planet specified.")
    game.print(usage_string_get)
    return
  end
  local surface = game.surfaces[command.parameter]
  local planet = game.planets[command.parameter]
  if not surface then
    if not planet.surface then
      game.print("Planet " .. planet.name .. " has not been generated yet")
      return
    end
    surface = planet.surface
  end
  if not prototypes.entity["offshore-oil"] then
    game.print("Offshore oil has been disabled in mod settings")
    -- Don't return as we may still want to see crude-oil settings
  end
  local crude_control_name = "crude-oil"
  local offshore_control_name = "offshore-oil"
  if planet and planet.name == "aquilo" then
    crude_control_name = "aquilo_crude_oil"
    offshore_control_name = "aquilo_offshore_oil"
  end
  local map_gen_settings = surface.map_gen_settings
  local crude_autoplace_controls = map_gen_settings.autoplace_controls[crude_control_name]
  game.print(command.parameter .. " crude-oil settings: " .. serpent.line(crude_autoplace_controls))
  local offshore_autoplace_controls = map_gen_settings.autoplace_controls[offshore_control_name]
  game.print(command.parameter .. " offshore-oil settings: " .. serpent.line(offshore_autoplace_controls))
end)

local usage_string = "Usage: /cargo-ships-set-oil-settings <planet> <offshore-oil/crude-oil> <default/off/{frequency=X,richness=Y,size=Z}>"
commands.add_command("cargo-ships-set-oil-settings", "Set oil configuration\n" .. usage_string, function(command)
  if not command.parameter then
    game.print(usage_string)
    return
  end
  local params = split(command.parameter, " ")
  if #params ~= 3 then
    game.print("Wrong number of parameters")
    game.print(usage_string)
    return
  end
  local planet_name = params[1]
  local resource_name = params[2]
  local settings_string = params[3]
  local surface = game.surfaces[planet_name]
  local planet = game.planets[planet_name]
  
  if not surface then
    if not planet then
      game.print("Planet " .. planet_name .. " does not exist")
      return
    end
    if not planet.surface then
      game.print("Planet " .. planet_name .. " has not been generated yet")
      return
    end
    surface = planet.surface
  end

  if resource_name == "offshore-oil" and not prototypes.entity["offshore-oil"] then
    game.print("Offshore oil has been disabled in mod settings")
    return
  end

  local control_name
  if resource_name == "crude-oil" then
    control_name = "crude-oil"
    if planet_name == "aquilo" then
      control_name = "aquilo_crude_oil"
    end
  elseif resource_name == "offshore-oil" then
    control_name = "offshore-oil"
    if planet_name == "aquilo" then
      control_name = "aquilo_offshore_oil"
    end
  else
    game.print("Unknown resource name: " .. resource_name)
    return
  end
  local map_gen_settings = surface.map_gen_settings

  if settings_string == "default" then
    map_gen_settings.autoplace_controls[control_name] = {}
    map_gen_settings.autoplace_settings.entity.settings[resource_name] = {}
  elseif settings_string == "off" then
    map_gen_settings.autoplace_controls[control_name] = {frequency = 1, size = 0, richness = 1}
    map_gen_settings.autoplace_settings.entity.settings[resource_name] = {}
  else
    if not settings_string:match("^{.*}$") then
      game.print("Error parsing settings: " .. settings_string)
      game.print(usage_string)
      return
    end
    local ok, res = serpent.load(settings_string)
    if not ok then
      game.print("Error parsing settings: " .. settings_string)
      game.print(usage_string)
      return
    end
    if  (res.frequency==nil or res.size==nil or res.richness==nil) then
      game.print("Missing settings table parameters: " .. settings_string)
      game.print(usage_string)
      return
    end

    map_gen_settings.autoplace_controls[control_name] = res
    map_gen_settings.autoplace_settings.entity.settings[resource_name] = {}
  end
  surface.map_gen_settings = map_gen_settings
  --[[local entities = planet.surface.find_entities_filtered{type="resource", name=resource_name}
  for _, entity in pairs(entities) do
    entity.destroy()
  end]]

  -- Doesn't delete entities, doesn't create entities if they've already been autoplaced
  surface.regenerate_entity(resource_name)
  game.print("Set " .. planet_name .. " " .. resource_name .. " settings to " .. settings_string)
end)
