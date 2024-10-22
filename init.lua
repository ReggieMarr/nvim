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
  },

  { import = "plugins" },
}, lazy_config)

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "nvchad.autocmds"

require 'myinit'

vim.schedule(function()
  require "mappings"
end)

-- -- TODO put these in their own plugin file
-- require("telescope").load_extension "file_browser"
-- require('telescope').load_extension "git_grep"
-- -- require("telescope").load_extension "projects"
--
-- vim.keymap.set('n', '<leader>ff', ':Telescope file_browser<CR>', { noremap = true, silent = true, desc = "Find files (current dir)" })
-- vim.keymap.set('n', '<leader><leader>', ':Telescope file_browser<CR>', { noremap = true, silent = true, desc = "Find files (current dir)" })
--
-- local function on_project_open()
--   vim.defer_fn(function()
--     require("configs.nav").file_browser()
--   end, 100)
-- end
--
-- vim.api.nvim_create_autocmd("User", {
--   pattern = { "SessionLoadPost" },
--   group = augroup,
--   desc = "Open file browser when a project is loaded",
--   callback = function()
--     on_project_open()
--   end,
-- })
--
-- require "sniprun"
--
-- local overseer = require("overseer")
-- -- Add a custom template for run.sh scripts
-- overseer.register_template({
--   name = "run.sh task",
--   detect = {
--     filename = "run.sh",
--   },
--   builder = function(params)
--     -- Parse the run.sh file to extract available tasks
--     local tasks = {}
--     for line in io.lines(params.filename) do
--       local task = line:match('^%s*"([^"]+)"%)') -- Adjust this regex based on your script structure
--       if task then
--         table.insert(tasks, task)
--       end
--     end
--
--     -- Create a task for each detected command
--     return tasks:map(function(task)
--       return {
--         name = "run.sh: " .. task,
--         cmd = { "./run.sh", task },
--         components = { "default" },
--       }
--     end)
--   end,
-- })
--
-- vim.o.errorformat = vim.o.errorformat .. [[,%f:%l:%c: %t%*[^:]: %m]]
