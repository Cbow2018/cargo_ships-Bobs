local GRAPHICSPATH = "__cargo-ships-oil-rig__/graphics/"

data:extend{
  {
    type = "item",
    name = "oil_rig",
    icon = GRAPHICSPATH .. "icons/oil_rig.png",
    icon_size = 64,
    flags = {},
    subgroup = "extraction-machine",
    order = "b[fluids]-c[oil_rig]",
    place_result = "oil_rig",
    stack_size = 5,
  },
  {
    type = "item",
    name = "or_pole",
    icons = data.raw["electric-pole"].or_pole.icons,
    flags = {},
    subgroup = "extraction-machine",
    order = "b[fluids]-c[oil_rig]",
    place_result = "or_pole",
    stack_size = 5,
    hidden = true,
  },
  {
    type = "item",
    name = "or_tank",
    icons = data.raw["storage-tank"].or_tank.icons,
    flags = {},
    subgroup = "extraction-machine",
    order = "b[fluids]-c[oil_rig]",
    place_result = "or_tank",
    stack_size = 5,
    hidden = true,
  },
}
