---@diagnostic disable: undefined-global
require("__core__/lualib/story")

---@diagnostic disable-next-line: unknown-cast-variable
---@cast game LuaGameScript

game.simulation.active_quickbars = 1
local player = game.simulation.create_test_player{name = "Jurgy"}
player.character.teleport{0, 4}
player.force.research_all_technologies()

game.simulation.camera_player = player
game.simulation.camera_position = {0, 0.5}
game.simulation.camera_player_cursor_position = player.position
-- game.simulation.camera_zoom = 0.5

---@type LuaSurface
local surface = game.surfaces[1]

local water_tiles = {}
for x = -32, 30, 1 do
  for y = -10, 2, 1 do
    if y > 1 and (x >= -6 and x < 6) then
    else
      table.insert(water_tiles, {name = "water", position={x, y}})
    end
  end
end

surface.set_tiles(water_tiles, true)

local bp = "0eNqtmN2uoyAQx1+l4do2BcWP3uztvsOmMVSpJUfBILbbnPjui3p62rOrBybZpEmrZX78HWcGmHd0qnveaiENOrwjUSjZocOvd9SJSrJ6vCdZw9EB3Zjh+sbuaAiQkCX/jQ54CBYGKlHnhsk3rl+GkuEYIC6NMILPE0wX91z2zcmOPODgYd8ZzUR1MdvPGQPUqs5aKjlOY2lbkgXobr+tAlQKzYv5z2gU9BeYwMCJNzj8BBdMVyrvLqLNuayE5EvgeJfgNKFPPJfsVPO8VpXojCi6/HYR9rpRVyErdDizuuMBUlrYedmM2u+IBQjDm9mHonzxu+yLmjO9Pfe8njw/D7OjZC7k1VKUvs9mzyvr9s6w4s2yh+NgP/8+ZwRzIPV2IIWBQ29wDANjb3ACAmP/IE1hYP8gzYKFtFwgxrs0/j/xuSAC72GP5x9CGFY2sH8MYVjdwP5BhEMQ2T+IMCxT/YMIwzIV8PpgmQp4e89MbUW7VI/xbpYZ7eiwBABmpL+yzKVs/70ysncAXPaglPF/MEIcuhweJ6HDnjjsQdHvH0qEftG1NWpbadXLcgH6ovALF5MlcOwNjtbAi4JBq5R/spLU8YKo4wW5Ij/+3j4ErSKAfRx26EoculyBnzrsQeuB/3IQRg5dmUMXdSW0o9KEoOoOWEHDl+qutFll/Y2a9rrzb/RT3TalKDd31W/O9pCyafgPtDTX60KgNKtsotpd1MKcj/pEV7yRgbzhX6Ai14KAH3UpWVYWYV9AugIgvoBsBRD6AsaYWyRE3gS8QqDeBLJCiL0J4QoBVLoB++QItJ0BnC8iWFT7Vy8KqvaAMxwF7X8Ap04KOjFAzsmgBQLQwaCgLdNqz+Vo62px4WVff7R2alWoRhlxna7Dl/9HlLVUuvzoMn1fjwN0Y8LkhZLlpGQ2Mvd2lMyb1owy7Vwt0zz/uM3sBmo4Ts2Msd6r4m20l7Pcx6xq7HjY5zlNrY9w6mPNN62vz1qN3bBsBIxNFAt9NskCdOW6mzTTmGQ0IlGaJWkU2oT+A+y9W+o="

local load = false
local engine = nil

local pumps = {
  "ship-unloading-pump",
  "ship-loading-pump"
}
player.set_quick_bar_slot(1, 1, pumps[1])
player.set_quick_bar_slot(1, 2, pumps[2])
local pump = nil


local story_table =
{
  {
    {
      name = "start",
      init = function() end,
      condition = story_elapsed_check(0),
      action = function()
        if load then pump = pumps[2] else pump = pumps[1] end

        surface.create_entities_from_blueprint_string
        {
          string = bp,
          position = {-4, 1},
          force = player.force
        }

        player.insert({name=pump, count=6})

        if load then
          local tank = surface.find_entities_filtered{name = "storage-tank"}[1]
          tank.set_fluid(1, {name = "crude-oil", amount = 25000})
        else
          local tanker = surface.find_entities_filtered{name = "oil_tanker"}[1]
          tanker.set_fluid(1, {name = "crude-oil", amount = 25000})
        end
      end
    },
    {
      condition = story_elapsed_check(10),
    },
    {
      condition = function()
        local target = game.simulation.get_widget_position({type = "quickbar-slot", data = pump})
        ---@cast target -?
        return game.simulation.move_cursor({position = target})
      end
    },
    {
      condition = story_elapsed_check(0.25),
      action = function()
        game.simulation.control_press{control = "pipette", notify = false}

      end
    },
    {
      condition = function()
        return game.simulation.move_cursor({position = {-5.5, 2}})
      end
    },
    {
      condition = story_elapsed_check(0.25),
      action = function()
        game.simulation.control_press{control = "rotate", notify = false}
        game.simulation.control_press{control = "rotate", notify = false}
      end
    },
    {
      condition = story_elapsed_check(0.25),
      action = function()
        game.simulation.control_press{control = "build", notify = true}
      end
    },
    {
      condition = function()
        return game.simulation.move_cursor({position = {-3.5, 2}})
      end
    },
    {
      condition = story_elapsed_check(0.25),
      action = function()
        game.simulation.control_press{control = "build", notify = true}
      end
    },
    {
      condition = function()
        return game.simulation.move_cursor({position = {-1.5, 2}})
      end
    },
    {
      condition = story_elapsed_check(0.25),
      action = function()
        game.simulation.control_press{control = "build", notify = true}
      end
    },
    {
      condition = function()
        return game.simulation.move_cursor({position = {1.5, 2}})
      end
    },
    {
      condition = story_elapsed_check(0.25),
      action = function()
        game.simulation.control_press{control = "build", notify = true}
      end
    },
    {
      condition = function()
        return game.simulation.move_cursor({position = {3.5, 2}})
      end
    },
    {
      condition = story_elapsed_check(0.25),
      action = function()
        game.simulation.control_press{control = "build", notify = true}
      end
    },
    {
      condition = function()
        return game.simulation.move_cursor({position = {5.5, 2}})
      end
    },
    {
      condition = story_elapsed_check(0.25),
      action = function()
        game.simulation.control_press{control = "build", notify = true}
      end
    },
    {
      condition = story_elapsed_check(3),
      action = function()
        player.character.clear_items_inside()
        local engines = surface.find_entities_filtered{area = {{-15, -10}, {15, 10}}, name = "cargo_ship_engine"}
        if #engines == 0 then
          error("Cargo ship engine not found")
        end
        engine = engines[1]

        ---@cast engine -?
        for _, entity in pairs(engine.train.carriages) do
          entity.destroy()
        end
        for _, entity in pairs (surface.find_entities_filtered{}) do
          if entity.name ~= "character" then
            entity.destroy()
          end
        end
      end
    },
    {
      condition = story_elapsed_check(0),
      action = function()
        load = not load
        story_jump_to(storage.story, "start")
      end
    },
  }
}

tip_story_init(story_table)