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

require "overseer_debug"

-- === Multiple Components Task ===
-- Task ID: 1
-- Buffer: 57
-- Strategy: {
--   bufnr = 57,
--   chan_id = 4,
--   name = "terminal",
--   <metatable> = {
--     __index = {
--       dispose = <function 1>,
--       get_bufnr = <function 2>,
--       new = <function 3>,
--       reset = <function 4>,
--       start = <function 5>,
--       stop = <function 6>
--     }
--   }
-- }
-- Components: { {
--     desc = "Display the run duration",
--     name = "display_duration",
--     on_complete = <function 1>,
--     on_reset = <function 2>,
--     on_start = <function 3>,
--     params = { "display_duration",
--       detail_level = 2
--     },
--     render = <function 4>,
--     serializable = true,
--     start_time = 1729798702
--   }, {
--     defer_update_lines = <function 5>,
--     desc = "Summarize task output in the task list",
--     lines = {},
--     name = "on_output_summarize",
--     on_output = <function 6>,
--     on_reset = <function 7>,
--     params = { "on_output_summarize",
--       max_lines = 4
--     },
--     render = <function 8>,
--     serializable = true
--   }, {
--     desc = "Sets final task status based on exit code",
--     name = "on_exit_set_status",
--     on_exit = <function 9>,
--     params = { "on_exit_set_status" },
--     serializable = true
--   }, {
--     desc = "vim.notify when task is completed",
--     name = "on_complete_notify",
--     notifier = {
--       system = "never",
--       <metatable> = {
--         __index = {
--           focused = true,
--           new = <function 10>,
--           notify = <function 11>
--         }
--       }
--     },
--     on_complete = <function 12>,
--     params = { "on_complete_notify",
--       on_change = false,
--       statuses = { "FAILURE", "SUCCESS" },
--       system = "never"
--     },
--     serializable = true
--   }, {
--     _del_autocmd = <function 13>,
--     _start_timer = <function 14>,
--     _stop_timer = <function 15>,
--     desc = "After task is completed, dispose it after a timeout",
--     name = "on_complete_dispose",
--     on_complete = <function 16>,
--     on_dispose = <function 17>,
--     on_reset = <function 18>,
--     params = { "on_complete_dispose",
--       require_view = { "SUCCESS", "FAILURE" },
--       statuses = { "SUCCESS", "FAILURE", "CANCELED" },
--       timeout = 300
--     },
--     serializable = true
--   } }
