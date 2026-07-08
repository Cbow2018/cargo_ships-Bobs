---@type data.TipsAndTricksItem
local tip = {
  name = "cargo-ships-tip-1",
  type = "tips-and-tricks-item",
  tag = "[item=waterway]",
  category = "cargo-ships",
  order = "a-[cargo-ships]-1",
  indent = 1,
  simulation = {
    mods = {"cargo-ships"},
    game_view_settings = {
      default_show_value = false,
      show_controller_gui = true,
      show_quickbar = true,
      update_entity_selection = true,
      show_tool_bar = false
    },
    init_file = "__cargo-ships__/prototypes/tips-and-tricks/tip-1.lua"
  }
}

local tip2 = {
  name = "cargo-ships-tip-2",
  type = "tips-and-tricks-item",
  tag = "[item=oil_tanker]",
  category = "cargo-ships",
  order = "a-[cargo-ships]-2",
  indent = 1,
  simulation = {
    mods = {"cargo-ships"},
    game_view_settings = {
      default_show_value = false,
      show_controller_gui = true,
      show_quickbar = true,
      update_entity_selection = true,
      show_tool_bar = false
    },
    init_file = "__cargo-ships__/prototypes/tips-and-tricks/tip-2.lua"
  }
}

local tip3 = {
  name = "cargo-ships-tip-3",
  type = "tips-and-tricks-item",
  tag = "[item=boat]",
  category = "cargo-ships",
  order = "a-[cargo-ships]-3",
  indent = 1,
  simulation = {
    mods = {"cargo-ships"},
    game_view_settings = {
      default_show_value = false,
      show_controller_gui = true,
      show_quickbar = true,
      update_entity_selection = true,
      show_tool_bar = false
    },
    init_file = "__cargo-ships__/prototypes/tips-and-tricks/tip-3.lua"
  }
}

data:extend{
  {
    type = "tips-and-tricks-item-category",
    name = "cargo-ships",
    order = "fa-[cargo-ships]",
  },
  {
    type = "tips-and-tricks-item",
    name = "cargo-ships",
    category = "cargo-ships",
    is_title = true,
    order = "a",
    image = "__cargo-ships-graphics__/assets/shortcut-tutorial.png"
  },
  tip,
  tip2,
  tip3
}