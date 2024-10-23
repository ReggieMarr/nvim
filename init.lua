vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
    keys = {
      {
        "<leader>hp",
        "<cmd> Telescope lazy<CR>",
        desc = "Surf Plugins",
      },
    },
    dependencies = {
      { "nvim-telescope/telescope.nvim" },
      { "tsakirist/telescope-lazy.nvim" },
      opts = {
        extensions = {
          lazy = {
            -- Optional theme (the extension doesn't set a default theme)
            theme = "ivy",
            -- Whether or not to show the icon in the first column
            show_icon = true,
            -- Mappings for the actions
            mappings = {
              open_in_browser = "<C-o>",
              open_in_file_browser = "<M-b>",
              open_in_find_files = "<C-f>",
              open_in_live_grep = "<C-g>",
              open_plugins_picker = "<C-b>", -- Works only after having called first another action
              open_lazy_root_find_files = "<C-r>f",
              open_lazy_root_live_grep = "<C-r>g",
            },
            -- Other telescope configuration options
          },
        },
      },
    },
  },
  { import = "plugins" },
}, lazy_config)

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "nvchad.autocmds"

require "myinit"

vim.schedule(function()
  require "mappings"
end)

-- TODO put these in their own plugin file
vim.keymap.set(
  "n",
  "<leader>ff",
  ":Telescope file_browser<CR>",
  { noremap = true, silent = true, desc = "Find files (current dir)" }
)

-- Function to find project root
local function find_project_root()
  -- Get current buffer's directory
  local buf_dir = vim.fn.expand "%:p:h"
  -- Try git root from buffer's directory
  local git_cmd = string.format("cd %s && git rev-parse --show-toplevel", vim.fn.shellescape(buf_dir))
  local git_dir = vim.fn.system(git_cmd):gsub("\n", "")
  if vim.v.shell_error == 0 and git_dir ~= "" then
    -- vim.notify("Using git root: " .. git_dir, vim.log.levels.INFO)
    return git_dir
  end

  -- Try to use LSP workspace root
  local active_clients = vim.lsp.get_active_clients { bufnr = 0 }
  if #active_clients > 0 then
    local workspace = active_clients[1].config.root_dir
    if workspace then
      -- vim.notify("Using LSP workspace root: " .. workspace, vim.log.levels.INFO)
      return workspace
    end
  end
  -- Fallback to current buffer's directory
  vim.notify("Falling back to current directory: " .. buf_dir, vim.log.levels.WARN)
  return buf_dir
end

local function check_ready()
  -- Get current buffer number
  local bufnr = vim.api.nvim_get_current_buf()
  -- Check if it's a real file buffer
  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  local is_real_file = buf_name ~= "" and vim.fn.filereadable(buf_name) == 1
  -- Check if Vim is fully started
  local vim_ready = vim.v.vim_did_enter == 1
  vim.notify(
    string.format(
      "Check ready status: is_real_file=%s, vim_ready=%s, buf_name=%s",
      tostring(is_real_file),
      tostring(vim_ready),
      buf_name
    ),
    vim.log.levels.DEBUG
  )
  return is_real_file and vim_ready
end

local function find_default_file(root_dir)
  -- List of file patterns to check, in priority order
  local patterns = {
    "README.org",
    "README.md",
    "README.*",
    ".*%.org",
    ".*%.md",
    ".*%.txt",
  }

  for _, pattern in ipairs(patterns) do
    -- Use vim.fn.glob() to find files matching the pattern
    local matches = vim.fn.glob(root_dir .. "/" .. pattern, false, true)
    if #matches > 0 then
      -- For README.* and general patterns, we might get multiple matches
      -- Get the first match as absolute path
      return matches[1]
    end
  end
  -- vim.notify("No default file found", vim.log.levels.DEBUG)
  return nil
end

local function open_file_browser(root)
  local default_file = find_default_file(root)
  local opts = {
    path = root,
    select_buffer = false,
    attach_mappings = function(prompt_bufnr, map)
      if default_file then
        vim.schedule(function()
          local action_state = require "telescope.actions.state"
          local current_picker = action_state.get_current_picker(prompt_bufnr)
          local finder = current_picker.finder
          require("telescope._extensions.file_browser.utils").selection_callback(current_picker, default_file)
          current_picker:refresh(finder, { reset_prompt = true, multi = current_picker._multi })
        end)
      end
      -- Return true to keep default mappings
      return true
    end,
  }

  require("telescope").extensions.file_browser.file_browser(opts)
end

-- Update your existing callbacks to use this function:
local function load_new_project()
  local timeout = 2000 -- 2 seconds in milliseconds
  local start_time = vim.loop.now()

  local function check_condition()
    if check_ready() then
      local root = find_project_root()
      open_file_browser(root)
    elseif (vim.loop.now() - start_time) < timeout then
      vim.defer_fn(check_condition, 50)
    else
      vim.notify("Timed out waiting for project to be ready", vim.log.levels.ERROR)
    end
  end

  vim.schedule(check_condition)
end

-- Create augroup
local augroup = vim.api.nvim_create_augroup("ProjectFileBrowser", { clear = true })

-- Create a flag to track if we've already opened the file browser
local browser_opened = false

-- Set up autocmd for session load
vim.api.nvim_create_autocmd("SessionLoadPost", {
  group = augroup,
  desc = "Open file browser when session is loaded",
  callback = function()
    if not browser_opened then
      browser_opened = true
      load_new_project()
      -- reset after we openend it
      browser_opened = false
    end
  end,
})

-- Keybinding for manual trigger remains the same
vim.keymap.set("n", "<leader><leader>", function()
  local root = find_project_root()
  require("telescope").extensions.file_browser.file_browser {
    path = root,
    select_buffer = true,
  }
end, { noremap = true, silent = true, desc = "Find files (project root)" })
