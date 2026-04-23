-- lua/env.lua
-- The development environment object.
-- Modules interact with the editor through this interface, not directly
-- through vim APIs or plugin APIs. This is the single import for module files.
--
-- Current implementation: thin facade over lib/ files.
-- Each surface will deepen independently as needed.

local M = {}

---State observation surface.
---Modules register providers that feed structured data into the environment.
M.state = require 'lib.state'

---Module system.
---Modules declare themselves, their dependencies, and their plugin specs here.
M.module = require 'lib.module'

---Check whether a named module is loaded and active.
---@param module_name string
---@return boolean
function M.module_active(module_name) return require('lib.module').available(module_name) end

---Check whether any module in a domain is active.
---Useful for cross-domain conditional logic in statusline,
---display conditions, and action preconditions.
---@param domain string
---@return boolean
function M.domain_active(domain) return require('lib.module').domain_active(domain) end

return M
