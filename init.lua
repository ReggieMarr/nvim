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

-- TODO put these in their own plugin file
require("telescope").load_extension "file_browser"
-- require("telescope").load_extension "projects"

vim.keymap.set('n', '<leader>ff', ':Telescope file_browser<CR>', { noremap = true, silent = true, desc = "Find files (current dir)" })
vim.keymap.set('n', '<leader><leader>', ':Telescope file_browser<CR>', { noremap = true, silent = true, desc = "Find files (current dir)" })

local fb_actions = require "telescope".extensions.file_browser.actions
local actions = require "telescope.actions"

require('telescope').setup {
  extensions = {
    file_browser = {
      mappings = {
        ["i"] = {
          ["<C-f>"] = function(prompt_bufnr)
            local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
            local fb = require("telescope").extensions.file_browser
            local path
            if current_picker.finder.files then
              -- We're in file browser mode
              path = current_picker.finder.path
            else
              -- We're in folder browser mode
              local selection = require("telescope.actions.state").get_selected_entry()
              path = selection and selection.Path:absolute() or current_picker.finder.path
            end
            fb.file_browser({ cwd = path })
          end,
          ["<C-s>"] = function(prompt_bufnr)
            local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
            local path
            if current_picker.finder.files then
              -- We're in file browser mode
              path = current_picker.finder.path
            else
              -- We're in folder browser mode
              local selection = require("telescope.actions.state").get_selected_entry()
              path = selection and selection.Path:absolute() or current_picker.finder.path
            end
            require("telescope.builtin").live_grep({ cwd = path })
          end,
        },
        ["n"] = {
          ["f"] = function(prompt_bufnr)
            local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
            local fb = require("telescope").extensions.file_browser
            local path
            if current_picker.finder.files then
              -- We're in file browser mode
              path = current_picker.finder.path
            else
              -- We're in folder browser mode
              local selection = require("telescope.actions.state").get_selected_entry()
              path = selection and selection.Path:absolute() or current_picker.finder.path
            end
            fb.file_browser({ cwd = path })
          end,
          ["s"] = function(prompt_bufnr)
            local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
            local path
            if current_picker.finder.files then
              -- We're in file browser mode
              path = current_picker.finder.path
            else
              -- We're in folder browser mode
              local selection = require("telescope.actions.state").get_selected_entry()
              path = selection and selection.Path:absolute() or current_picker.finder.path
            end
            require("telescope.builtin").live_grep({ cwd = path })
          end,
          ["h"] = fb_actions.goto_parent_dir,
          ["l"] = function(prompt_bufnr)
            local selection = require("telescope.actions.state").get_selected_entry()
            if selection then
              if selection.Path:is_dir() then
                fb_actions.open_dir(prompt_bufnr, nil, selection.Path:absolute())
              else
                actions.select_default(prompt_bufnr)
              end
            end
          end,
        },
      },
    }
  }
}
