-- Load all keymap modules
local M = {}

function M.setup()
  -- require('custom.keymaps.navigation').setup()
  require('custom.keymaps.editor').setup()
  require('custom.keymaps.files').setup()
  require('custom.keymaps.windows').setup()
  require('custom.keymaps.git').setup()
end

return M
