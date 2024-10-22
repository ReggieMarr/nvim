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

require "sniprun"

-- TODO put these in their own plugin file
require('telescope').load_extension "git_grep"
require('telescope').load_extension "file_browser"
-- Function to find project root
local function find_project_root()
  -- TODO add this if we end up leveraging nvim-project
  -- local project = require("nvim-project")
  -- local project_root = project.get_project_root_path()
  -- if project_root then
  --   return project_root
  -- end
  --
  -- Fallback to LSP workspace root
  local active_clients = vim.lsp.get_active_clients()
  if #active_clients > 0 then
    local workspace = active_clients[1].config.root_dir
    if workspace then
      return workspace
    end
  end

  -- Fallback to git root
  local git_dir = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if vim.v.shell_error == 0 and git_dir then
    return git_dir
  end

  -- Fallback to current directory
  return vim.fn.expand("%:p:h")
end

vim.keymap.set('n', '<leader>ff', ':Telescope file_browser<CR>', { noremap = true, silent = true, desc = "Find files (current dir)" })
vim.keymap.set('n', '<leader><leader>', function()
  require("telescope").extensions.file_browser.file_browser({
    path = find_project_root(),
    select_buffer = true,
  })
end, { noremap = true, silent = true, desc = "Find files (project root)" })

-- local function on_project_open()
--   -- Increase the defer time to allow for session restore
--   require("telescope").extensions.file_browser.file_browser({
--     path = find_project_root(),
--     select_buffer = true,
--   })
-- end
local function on_project_open()
  vim.schedule(function()
    -- Check if LSP is ready
    local lsp_ready = #vim.lsp.get_active_clients() > 0
    -- Check if buffers are loaded
    local buffers_loaded = #vim.fn.getbufinfo({buflisted = 1}) > 0
    -- Check if project root is available
    local project_root = require("nvim-project").get_project_root_path()
    
    if buffers_loaded and project_root then
      require("telescope").extensions.file_browser.file_browser({
        path = find_project_root(),
        select_buffer = true,
      })
    end
  end)
end
-- vim.api.nvim_create_autocmd({"User", "VimEnter"}, {
--   pattern = {"NeovimProjectLoadPost"},
--   group = augroup,
--   desc = "Open file browser when a project is loaded",
--   callback = function()
--     vim.schedule(function()
--       if vim.v.vim_did_enter == 1 then
--         on_project_open()
--       end
--     end)
--   end,
-- })

local function check_ready()
  local buffers_loaded = #vim.fn.getbufinfo({buflisted = 1}) > 0
  local project_root = require("nvim-project").get_project_root_path()
  local vim_ready = vim.v.vim_did_enter == 1
  
  return buffers_loaded and project_root and vim_ready
end

vim.api.nvim_create_autocmd("User", {
  pattern = "NeovimProjectLoadPost",
  group = augroup,
  desc = "Open file browser when a project is loaded",
  callback = function()
    vim.schedule(function()
      if check_ready() then
        on_project_open()
      end
    end)
  end,
})
