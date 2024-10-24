-- Test 1: Check if the strategy is being set correctly
local overseer = require "overseer"
overseer.run_template({
  name = "make",
  strategy = "terminal", -- explicitly set terminal strategy
}, function(task)
  if task then
    -- Print the strategy type
    print("Strategy type:", vim.inspect(task.strategy))
    -- Print the buffer number if it exists
    print("Buffer number:", task.strategy.bufnr)
  end
end)

-- Test 2: Check if util.run_in_fullscreen_win is being called
local overseer = require "overseer"
local util = require "overseer.util"
-- Override the function temporarily for debugging
local old_run_in_fullscreen = util.run_in_fullscreen_win
util.run_in_fullscreen_win = function(bufnr, callback)
  print("Running in fullscreen with buffer:", bufnr)
  old_run_in_fullscreen(bufnr, callback)
end

-- Test 3: Check task configuration
overseer.run_template({
  name = "make",
  strategy = "terminal",
}, function(task)
  if task then
    print "Task configuration:"
    print("Command:", vim.inspect(task.cmd))
    print("CWD:", task.cwd)
    print("Environment:", vim.inspect(task.env))
  end
end)

local overseer = require "overseer"

-- Minimal setup with debug logging
overseer.setup {
  log = {
    {
      type = "echo",
      level = vim.log.levels.DEBUG,
    },
  },
  -- Use only built-in templates for testing
  templates = { "builtin" },
}

-- Test functions we can call
local function test_basic_template()
  overseer.run_template({}, function(task)
    if task then
      print("Task created with ID: " .. task.id)
      print("Buffer: " .. (task:get_bufnr() or "no buffer"))
      print("Strategy: " .. vim.inspect(task.strategy))
    else
      print "No task created"
    end
  end)
end

local function test_terminal_window()
  -- Create a buffer
  local buf = vim.api.nvim_create_buf(false, true)
  print("Created buffer: " .. buf)

  -- Try to open it in different ways
  -- Vertical split
  vim.cmd "vsplit"
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  print("Opened in vertical split: " .. win)

  -- Return the buffer for cleanup
  return buf
end

local function test_template_with_terminal()
  overseer.run_template({
    strategy = { "terminal" },
  }, function(task)
    if task then
      print "Task with terminal strategy:"
      print("ID: " .. task.id)
      print("Buffer: " .. (task:get_bufnr() or "no buffer"))
      if task.strategy.bufnr then
        print("Terminal buffer: " .. task.strategy.bufnr)
      end
      if task.strategy.chan_id then
        print("Terminal channel: " .. task.strategy.chan_id)
      end
    end
  end)
end

local function test_template_with_toggle_term()
  overseer.run_template({
    strategy = {
      "toggleterm",
      direction = "vertical",
      open_on_start = true,
    },
  }, function(task)
    print("Task with toggleterm: " .. vim.inspect(task))
  end)
end

-- Test with specific component
local function test_template_with_component()
  overseer.run_template({}, function(task)
    if task then
      task:add_component {
        "open_output",
        direction = "vertical",
        on_start = "always",
      }
    end
  end)
end

local function test_template_with_terminal_forced()
  overseer.run_template({
    strategy = { "terminal" },
  }, function(task)
    if task then
      print "Task with terminal strategy:"
      print("Buffer: " .. (task:get_bufnr() or "no buffer"))
      -- Force open the buffer in a split
      vim.cmd "vsplit"
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, task:get_bufnr())
    end
  end)
end

local function test_template_with_output()
  overseer.run_template({}, function(task)
    if task then
      -- Explicitly call open_output
      task:open_output "vertical"
      -- Check if the window was created
      local wins = vim.api.nvim_list_wins()
      print("Windows after open_output: " .. vim.inspect(wins))
    end
  end)
end

local function debug_window_info(wins)
  for _, win in ipairs(wins) do
    print(string.format("Window %d:", win))
    print("  Buffer: " .. vim.api.nvim_win_get_buf(win))
    print("  Config: " .. vim.inspect(vim.api.nvim_win_get_config(win)))
    -- Check if window is visible
    local visible = vim.api.nvim_win_is_valid(win)
    print("  Visible: " .. tostring(visible))
    -- Get window dimensions
    local width = vim.api.nvim_win_get_width(win)
    local height = vim.api.nvim_win_get_height(win)
    print(string.format("  Dimensions: %dx%d", width, height))
  end
end

local function test_template_with_output_debug()
  overseer.run_template({}, function(task)
    if task then
      print "Before open_output:"
      debug_window_info(vim.api.nvim_list_wins())

      task:open_output "vertical"

      print "\nAfter open_output:"
      debug_window_info(vim.api.nvim_list_wins())

      -- Try to force focus the new window
      local wins_after = vim.api.nvim_list_wins()
      local new_wins = {}
      for _, win in ipairs(wins_after) do
        if vim.api.nvim_win_get_buf(win) == task:get_bufnr() then
          vim.api.nvim_set_current_win(win)
          break
        end
      end
    end
  end)
end

local function test_template_with_output_focus()
  overseer.run_template({}, function(task)
    if task then
      task:open_output "vertical"

      -- Find our terminal window and force focus it
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == task:get_bufnr() then
          -- Force focus the window
          vim.api.nvim_set_current_win(win)
          -- Ensure we're in terminal mode
          vim.cmd "startinsert"
          break
        end
      end
    end
  end)
end

-- Also try with the terminal strategy explicitly
local function test_template_with_terminal_focus()
  overseer.run_template({
    strategy = {
      "terminal",
    },
  }, function(task)
    if task then
      -- Force the window to open and stay focused
      vim.cmd "vsplit"
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, task:get_bufnr())
      vim.cmd "startinsert"
    end
  end)
end

local function test_persistent_terminal()
  overseer.run_template({
    strategy = {
      "terminal",
    },
    components = {
      -- Prevent automatic disposal
      { "on_complete_dispose", timeout = false },
      -- Keep output visible
      { "on_output_quickfix", open = true },
      -- Open terminal immediately
      { "open_output", direction = "vertical", on_start = "always" },
    },
  }, function(task)
    if task then
      -- Ensure we're in terminal mode
      vim.schedule(function()
        vim.cmd "startinsert"
      end)
    end
  end)
end

local function test_toggleterm_persistent()
  overseer.run_template({
    strategy = {
      "toggleterm",
      direction = "vertical",
      open_on_start = true,
      close_on_exit = false,
      quit_on_exit = "never",
    },
    components = {
      { "on_complete_dispose", timeout = false },
    },
  }, function(task)
    if task then
      print("Task buffer: " .. task:get_bufnr())
    end
  end)
end

local function test_long_running_terminal()
  overseer.run_template({
    strategy = {
      "terminal",
    },
    cmd = { "top" }, -- or any other long-running command
    components = {
      { "on_complete_dispose", timeout = false },
      { "open_output", direction = "vertical", on_start = "always" },
    },
  }, function(task)
    if task then
      vim.schedule(function()
        vim.cmd "startinsert"
      end)
    end
  end)
end

local function test_persistent_window()
  overseer.run_template({
    strategy = {
      "toggleterm",
      direction = "vertical",
      open_on_start = true,
      close_on_exit = false,
      quit_on_exit = "never",
      hidden = false,
    },
    components = {
      -- Remove the dispose component entirely
      { "default", remove = { "on_complete_dispose" } },
      -- Add permanent output display
      {
        "open_output",
        direction = "vertical",
        on_start = "always",
        focus = true,
      },
    },
  }, function(task)
    if task then
      -- Force the window to stay open
      vim.schedule(function()
        local bufnr = task:get_bufnr()
        if bufnr then
          -- Create a permanent window
          vim.cmd "vsplit"
          local win = vim.api.nvim_get_current_win()
          vim.api.nvim_win_set_buf(win, bufnr)

          -- Set buffer options to prevent auto-close
          vim.api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
          vim.api.nvim_buf_set_option(bufnr, "buflisted", true)

          -- Enter terminal mode
          vim.cmd "startinsert"
        end
      end)
    end
  end)
end

-- Let's also try with a shell command that keeps the terminal open
local function test_shell_terminal()
  overseer.run_template({
    strategy = {
      "terminal",
    },
    cmd = { "bash" }, -- or "zsh" or whatever shell you use
    components = {
      { "default", remove = { "on_complete_dispose" } },
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
        local bufnr = task:get_bufnr()
        if bufnr then
          vim.cmd "vsplit"
          local win = vim.api.nvim_get_current_win()
          vim.api.nvim_win_set_buf(win, bufnr)
          vim.cmd "startinsert"
        end
      end)
    end
  end)
end

-- Make these available globally for testing
_G.test_overseer = {
  basic = test_basic_template, -- doesn't create window
  terminal = test_terminal_window, -- creates new window
  template_term = test_template_with_terminal, --doesn't create new window
  template_toggle = test_template_with_toggle_term, --doesnt creat new window
  template_component = test_template_with_component, --doesnt create new window
  template_forced = test_template_with_terminal_forced, --creates new window
  output = test_template_with_output, --doesnt create new window
  debug_window_info = debug_window_info, --fails
  output_debug = test_template_with_output_debug, --create new window
  output_focus = test_template_with_output_focus, --create new window
  terminal_persist = test_persistent_terminal, --doesn't create new window
  terminal_focus = test_template_with_terminal_focus, --create new window
  terminal_long_running = test_long_running_terminal, --doesn't create new window
  terminal_no_dispose = test_persistent_window, --create new window
  terminal_shell = test_shell_terminal, --create new window
}
