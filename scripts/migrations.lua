local table = require("__flib__.table")
require("scripts.storage_init")

return {
  ["1.0.4"] = function()
    log("Running 1.0.4 migration")

    -- delayed_chat_message became a table
    if storage.delayed_chat_message == nil then
      storage.delayed_chat_messages = {}
    else
      storage.delayed_chat_messages = { storage.delayed_chat_message }
      storage.delayed_chat_message = nil
    end

    -- GUI changed and new outer_table global was added
    for _, player in pairs(game.players) do
      player.gui.screen.clear()
      initialize_player(player)
    end
  end,

  ["1.0.7"] = function()
    log("Running 1.0.7 migration")
    -- 1.0.4 migration contained an error that would affect multiplayer games
    -- Recreate it for all players
    for _, player in pairs(game.players) do
      player.gui.screen.clear()
      initialize_player(player)
    end
  end,

  ["1.0.9"] = function()
    log("Running 1.0.9 migration")
    for force_name, storage_force in pairs(storage.forces) do
      local affected = false
      for _, milestone in pairs(storage_force.complete_milestones) do
        if milestone.type == "technology" and milestone.completion_tick ==
            nil then
          affected = true
          milestone.lower_bound_tick = 0
          milestone.completion_tick = game.tick
        end
      end

      if affected then
        local force = game.forces[force_name]
        force.print(
          "[img=milestones_main_icon_white] If you see this message, you were affected by a Milestones bug which lost the completion time of your [font=default-large-bold]technology[/font] milestones.")
        force.print(
          "The issue is now fixed but you will need to re-enter your lost times in the Milestones window.")
        refresh_gui_for_force(force)
      end
    end
  end,

  ["1.0.10"] = function()
    log("Running 1.0.10 migration")
    -- Editing settings would cause storage.loaded_milestones to share objects with storage.forces[].*
    -- This could cause storage.loaded_milestones to gain completion_tick fields, later messing with initialize_force code
    storage.loaded_milestones = table.deep_copy(storage.loaded_milestones)
    for _, milestone in pairs(storage.loaded_milestones) do
      milestone.completion_tick = nil
      milestone.lower_bound_tick = nil
    end
    for _, storage_force in pairs(storage.forces) do
      for _, milestone in pairs(storage_force.incomplete_milestones) do
        milestone.completion_tick = nil
        milestone.lower_bound_tick = nil
      end
    end
  end,

  ["1.2.1"] = function()
    log("Running 1.2.1 migration")
    -- Table reference error could have introduced completion times in storage.loaded_milestones during merge_new_milestones
    storage.loaded_milestones = table.deep_copy(storage.loaded_milestones)
    for _, milestone in pairs(storage.loaded_milestones) do
      milestone.completion_tick = nil
      milestone.lower_bound_tick = nil
    end
  end,

  ["1.3.0"] = function()
    log("Running 1.3.0 migration")
    for force_name, storage_force in pairs(storage.forces) do
      -- Add new milestones_by_group field, but just put all existing milestones in the Other group
      storage_force.milestones_by_group = { ["Other"] = {} }
      for i, milestone in pairs(storage_force.complete_milestones) do
        milestone.sort_index = i
        milestone.group = "Other"
        table.insert(storage_force.milestones_by_group["Other"], milestone)
      end
      for i, milestone in pairs(storage_force.incomplete_milestones) do
        milestone.sort_index = i
        milestone.group = "Other"
        table.insert(storage_force.milestones_by_group["Other"], milestone)
      end

      -- Update old estimations with new more accurate estimations
      local force = game.forces[force_name]
      local item_stats = force.item_production_statistics
      local fluid_stats = force.fluid_production_statistics
      local kill_stats = force.kill_count_statistics
      for _, milestone in pairs(storage_force.complete_milestones) do
        if is_valid_milestone(milestone) and milestone.lower_bound_tick ~= nil then
          local new_lower_bound, new_upper_bound = find_completion_tick_bounds(milestone, item_stats, fluid_stats,
            kill_stats)
          log("Old tick bounds for " ..
          milestone.name .. " : " .. milestone.lower_bound_tick .. " - " .. milestone.completion_tick)
          log("New tick bounds for " .. milestone.name .. " : " .. new_lower_bound .. " - " .. new_upper_bound)
          milestone.lower_bound_tick = math.max(milestone.lower_bound_tick, new_lower_bound)
          milestone.completion_tick = math.min(milestone.completion_tick, new_upper_bound)
        end
      end
    end
  end,

  ["1.3.8"] = function()
    log("Running 1.3.8 migration")
    initialize_alias_table()
  end,

  ["1.3.10"] = function()
    log("Running 1.3.10 migration")
    -- inner frame GUI changes, we must recreate GUIs
    for _, player in pairs(game.players) do
      if storage.players[player.index] then
        reinitialize_player(player.index)
      end
    end
  end,

  ["1.3.14"] = function()
    log("Running 1.3.14 migration")
    -- Caching some calculations for optimisation
    storage.milestones_check_frequency_setting = settings.global["milestones_check_frequency"].value
    for force_name, storage_force in pairs(storage.forces) do
      local force = game.forces[force_name]
      storage_force.item_stats = force.item_production_statistics
      storage_force.fluid_stats = force.fluid_production_statistics
      storage_force.kill_stats = force.kill_count_statistics
    end
  end,

  ["1.3.20"] = function()
    log("Running 1.3.20 migration")
    -- Recalculate the sort_index of infinite milestones (first is n, second is n.0001, third is n.0002, etc.)
    for force_name, force in pairs(game.forces) do
      if storage.forces[force_name] ~= nil then
        merge_new_milestones(force_name, storage.loaded_milestones)
        backfill_completion_times(force)
      end
    end
  end,

  ["1.4.0"] = function()
    log("Running 1.4.0 migration")
    for force_name, force in pairs(game.forces) do
      if storage.forces[force_name] ~= nil then
        local storage_force = storage.forces[force_name]
        storage_force.item_stats = {}
        storage_force.fluid_stats = {}
        storage_force.kill_stats = {}
        add_flow_statistics_to_storage_force(force)
      end
    end
  end,

  ["1.4.1"] = function()
    log("Running 1.4.1 migration")
    for force_name, storage_force in pairs(storage.forces) do
      local force = game.forces[force_name]
      if force then
        storage_force.item_stats = {}
        storage_force.fluid_stats = {}
        storage_force.kill_stats = {}
        add_flow_statistics_to_storage_force(force)
        backfill_completion_times(force)
      end
    end
  end
}
