local M = {}
local overseer = require "overseer"

-- Utility functions for debugging
M.debug_utils = {
  print_task_info = function(task, label)
    print("\n=== " .. label .. " ===")
    print("Task ID:", task.id)
    print("Buffer:", task:get_bufnr())
    print("Strategy:", vim.inspect(task.strategy))
    print("Components:", vim.inspect(task.components))
    print("Status:", task.status)
  end,

  print_window_info = function(win_id)
    print "\n=== Window Info ==="
    print("Window ID:", win_id)
    print("Buffer:", vim.api.nvim_win_get_buf(win_id))
    print("Config:", vim.inspect(vim.api.nvim_win_get_config(win_id)))
    print("Valid:", vim.api.nvim_win_is_valid(win_id))
  end,

  print_buffer_info = function(bufnr)
    print "\n=== Buffer Info ==="
    print("Buffer:", bufnr)
    print("Valid:", vim.api.nvim_buf_is_valid(bufnr))
    print("Listed:", vim.api.nvim_buf_get_option(bufnr, "buflisted"))
    print("Type:", vim.api.nvim_buf_get_option(bufnr, "buftype"))
    print("Hidden:", vim.api.nvim_buf_get_option(bufnr, "bufhidden"))
  end,
}

-- Test Categories
M.tests = {
  terminal = {
    basic_terminal = {
      name = "Basic Terminal Test",
      func = function()
        overseer.run_template({
          strategy = { "terminal" },
        }, function(task)
          if task then
            M.debug_utils.print_task_info(task, "Basic Terminal Task")
          end
        end)
      end,
    },
    persistent_terminal = {
      name = "Persistent Terminal Test",
      func = function()
        overseer.run_template({
          strategy = { "terminal" },
          components = {
            { "default", remove = { "on_complete_dispose" } },
            {
              "open_output",
              direction = "vertical",
              on_start = "always",
            },
          },
        }, function(task)
          if task then
            M.debug_utils.print_task_info(task, "Persistent Terminal Task")
            local bufnr = task:get_bufnr()
            if bufnr then
              M.debug_utils.print_buffer_info(bufnr)
              vim.api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
              vim.api.nvim_buf_set_option(bufnr, "buflisted", true)
            end
          end
        end)
      end,
    },
    toggleterm = {
      name = "ToggleTerm Test",
      func = function()
        overseer.run_template({
          strategy = {
            "toggleterm",
            direction = "vertical",
            open_on_start = true,
            close_on_exit = false,
            quit_on_exit = "never",
          },
        }, function(task)
          if task then
            M.debug_utils.print_task_info(task, "ToggleTerm Task")
          end
        end)
      end,
    },
    shell_command = {
      name = "Shell Command Test",
      func = function()
        overseer.run_template({
          cmd = { "bash" },
          strategy = { "terminal" },
          components = {
            { "default", remove = { "on_complete_dispose" } },
          },
        }, function(task)
          if task then
            M.debug_utils.print_task_info(task, "Shell Command Task")
          end
        end)
      end,
    },
  },
  window = {
    force_window = {
      name = "Force Window Creation",
      func = function()
        overseer.run_template({
          strategy = { "terminal" },
        }, function(task)
          if task then
            vim.cmd "vsplit"
            local win = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(win, task:get_bufnr())
            M.debug_utils.print_window_info(win)
          end
        end)
      end,
    },
    output_window = {
      name = "Output Window Test",
      func = function()
        overseer.run_template({}, function(task)
          if task then
            task:open_output "vertical"
            for _, win in ipairs(vim.api.nvim_list_wins()) do
              M.debug_utils.print_window_info(win)
            end
          end
        end)
      end,
    },
    persistent_window = {
      name = "Persistent Window Test",
      func = function()
        overseer.run_template({
          strategy = {
            "toggleterm",
            direction = "vertical",
            open_on_start = true,
            close_on_exit = false,
            quit_on_exit = "never",
            hidden = false,
          },
        }, function(task)
          if task then
            vim.schedule(function()
              local bufnr = task:get_bufnr()
              if bufnr then
                vim.cmd "vsplit"
                local win = vim.api.nvim_get_current_win()
                vim.api.nvim_win_set_buf(win, bufnr)
                vim.api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
                vim.api.nvim_buf_set_option(bufnr, "buflisted", true)
                M.debug_utils.print_window_info(win)
                M.debug_utils.print_buffer_info(bufnr)
              end
            end)
          end
        end)
      end,
    },
  },
  component = {
    no_dispose = {
      name = "No Dispose Component Test",
      func = function()
        overseer.run_template({
          components = {
            { "default", remove = { "on_complete_dispose" } },
            { "open_output", direction = "vertical", on_start = "always" },
          },
        }, function(task)
          if task then
            M.debug_utils.print_task_info(task, "No Dispose Task")
          end
        end)
      end,
    },
    output_quickfix = {
      name = "Output Quickfix Component Test",
      func = function()
        overseer.run_template({
          components = {
            { "on_output_quickfix", open = true },
            { "open_output", direction = "vertical", on_start = "always" },
          },
        }, function(task)
          if task then
            M.debug_utils.print_task_info(task, "Quickfix Task")
          end
        end)
      end,
    },
    focus_window = {
      name = "Focus Window Component Test",
      func = function()
        overseer.run_template({
          components = {
            {
              "open_output",
              direction = "vertical",
              on_start = "always",
              focus = true,
            },
          },
        }, function(task)
          if task then
            vim.schedule(function()
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_buf(win) == task:get_bufnr() then
                  vim.api.nvim_set_current_win(win)
                  vim.cmd "startinsert"
                  break
                end
              end
            end)
          end
        end)
      end,
    },
    multiple_components = {
      name = "Multiple Components Test",
      func = function()
        overseer.run_template({
          params = {
            components = {
              { "default", remove = { "on_complete_dispose" } },
              { "on_output_quickfix", open = true },
              {
                "open_output",
                direction = "vertical",
                on_start = "always",
                focus = true,
              },
            },
          },
        }, function(task)
          if task then
            M.debug_utils.print_task_info(task, "Multiple Components Task")
          end
        end)
      end,
    },
    reliable_opening = {
      name = "Multiple Components Test with manual window opening",
      func = function()
        overseer.run_template({}, function(task)
          if task then
            -- Add components after task creation
            -- task:add_component { "on_output_quickfix", open = true }
            task:add_component {
              "open_output",
              direction = "vertical",
              on_start = "always",
              focus = true,
            }
            -- Remove unwanted components
            task:remove_component "on_complete_dispose"
          end
        end)
      end,
    },
  },
}

-- Function to run a specific test
function M.run_test(category, test_name)
  if M.tests[category] and M.tests[category][test_name] then
    M.tests[category][test_name].func()
  else
    print("Test not found:", category, test_name)
  end
end

-- Function to get all tests as a flat list for Telescope
function M.get_test_list()
  local tests = {}
  for category, category_tests in pairs(M.tests) do
    for test_name, test_info in pairs(category_tests) do
      table.insert(tests, {
        category = category,
        name = test_name,
        display = string.format("%s: %s", category, test_info.name),
      })
    end
  end
  return tests
end

-- Telescope picker for tests
function M.show_test_picker()
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  pickers
    .new({}, {
      prompt_title = "Overseer Debug Tests",
      finder = finders.new_table {
        results = M.get_test_list(),
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.display,
            ordinal = entry.display,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          M.run_test(selection.value.category, selection.value.name)
        end)
        return true
      end,
    })
    :find()
end

-- Create a user command for easy access
vim.api.nvim_create_user_command("OverseerDebug", function()
  M.show_test_picker()
end, {})

return M
