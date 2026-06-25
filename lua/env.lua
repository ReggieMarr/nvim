-- lua/env.lua
-- The development environment object.
-- Modules interact with the editor through this interface, not directly
-- through vim APIs or plugin APIs. This is the single import for module files.
--
-- Surfaces:
--   env.state        — observable editor state (providers feed structured data)
--   env.module       — module system (register, dependencies, setup lifecycle)
--   env.capabilities — runtime extension registry (picker, notifier, etc.)
--   env.display      — display contribution registry (statusline, signs, vtext)
--   env.articulation — action registry (buffer-local keymaps with attribution)
--
-- env.use(slot)      — shorthand for env.capabilities.get(slot)

local M = {}

---State observation surface.
---Modules register providers that feed structured data into the environment.
M.state = require 'lib.state'

---Module system.
---Modules declare themselves, their dependencies, and their plugin specs here.
M.module = require 'lib.module'

---Capability extension registry.
---Modules extend named capability slots (e.g. 'picker', 'notifier') with methods.
---env.use('picker').files() calls the registered picker implementation.
M.capabilities = require 'lib.capabilities'

---Display contribution registry.
---Modules register what they add to the visible editor surface.
M.display = require 'lib.display'

---Action registry.
---Modules register named actions with keybindings and descriptions.
---Unlike global vim.keymap.set calls, articulation.register also sets the keymap.
M.articulation = require 'lib.articulation'

---Get the merged capability object for a named slot.
---Shorthand for env.capabilities.get(slot).
---For the 'picker' slot this returns vim.ui.picker directly.
---@param slot string
---@return table
function M.use(slot)
  return require('lib.capabilities').get(slot)
end

---Check whether a named module is loaded and active.
---@param module_name string
---@return boolean
function M.module_active(module_name)
  return require('lib.module').available(module_name)
end

---Check whether any module in a domain is active.
---Useful for cross-domain conditional logic in statusline, display conditions,
---and action preconditions.
---@param domain string
---@return boolean
function M.domain_active(domain)
  return require('lib.module').domain_active(domain)
end

return M
