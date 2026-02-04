-- lua/custom/plugins/nav.lua

return {
  name = 'custom-nav',
  dir = vim.fn.stdpath('config') .. '/lua/custom/nav',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
    'nvim-telescope/telescope-file-browser.nvim',
    'davvid/telescope-git-grep.nvim',
    'ibhagwan/fzf-lua',
    'Shatur/neovim-session-manager',
    {
      'coffebar/neovim-project',
      opts = {
        projects = {
          '~/Projects/*',
          '~/.config/*',
        },
        picker = {
          type = 'telescope',
        },
      },
    },
  },
  config = function()
    local nav = require('custom.nav')
    nav.setup()
  end,
  priority = 100,
  lazy = false,
}
