-- Settings to enable Floating Poles on Space Age planets  
if mods["space-age"] then
  data:extend{
    {
      type = "bool-setting",
      name = "floating_pole_fulgora",
      setting_type = "startup",
      default_value = false,
      order = "a-ab"
    },
    {
      type = "bool-setting",
      name = "floating_pole_aquilo",
      setting_type = "startup",
      default_value = false,
      order = "a-ac"
    },
  }
end
