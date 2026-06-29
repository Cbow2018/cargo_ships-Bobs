local is_oil_rig_part = util.list_to_map{"or_pole","or_tank"}

function FixPipette(event)
  -- Pipetting engine, rail boat, or waterway doesn't work
  local player = game.players[event.player_index]
  local cursor = player.cursor_stack
  local selected = player.selected
  local item = event.item
  --game.print("pipetted "..item.name)
  local newItemWithQuality
  if is_oil_rig_part[item.name] then
    --cursor.clear()
    if selected then
      local oil_rig = selected.surface.find_entities_filtered{name="oil_rig", position=selected.position, radius = 0.5, limit=1}[1]
      if oil_rig then
        -- Pipette the oil rig instead
        player.pipette(oil_rig.prototype, oil_rig.quality, true)
      end
    end
  end
end
