-- lua/custom/plugins/nav.lua

return {
  name = 'custom-keymaps',
  dir = vim.fn.stdpath('config') .. '/lua/custom/keymaps',
  config = function()
    local keymaps = require('custom.keymaps')
    keymaps.setup()
  end,
  priority = 100,
  lazy = false,
}
