data:extend{
  {
    type = "int-setting",
    name = "oil_rig_capacity",
    setting_type = "startup",
    minimum_value = 1,
    default_value = 100,
    maximum_value = 500,
    order = "a-c"
  },
  {
    type = "string-setting",
    name = "oil_rigs_require_external_power",
    setting_type = "startup",
    default_value = "only-when-moduled",
    allowed_values = {
      "enabled",
      "only-when-moduled",
      "disabled",
    },
    order = "a-d"
  },
  {
    type = "bool-setting",
    name = "no_oil_for_oil_rig",
    setting_type = "startup",
    default_value = false,
    order = "a-e"
  },
  {
    type = "bool-setting",
    name = "no_shallow_oil",
    setting_type = "startup",
    default_value = false,
    order = "a-g"
  },
}
