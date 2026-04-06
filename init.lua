-- init.lua
-- Entry point. Responsible for:
--   1. Loading feature flags
--   2. Initializing the environment (core state providers)
--   3. Registering modules (order matters for dependency validation)
--   4. Handing plugin specs to lazy

-- Initialize core state providers before any module loads
require("lib.state")._register_core_providers()

-- Load base vim options (no plugin dependencies)
require("base")

-- Register modules in dependency order.
-- This is the explicit manifest: add new module files here.
-- The module system validates the graph; this ordering is a hint
-- but topological sort handles final load order.
local module_files = {
  "modules.interface",
  "modules.navigation",
  -- "modules.project",
  -- "modules.version_control",
  -- "modules.system",
  -- "modules.execution",
  -- "modules.language",
}

for _, mod in ipairs(module_files) do
  local feature = require(mod) -- module.register() is called as a side effect
  _ = feature -- suppress unused warning
end

-- Validate the dependency graph before handing off to lazy
local module_lib    = require("lib.module")
local valid, errors = module_lib.validate()
if not valid then
  for _, err in ipairs(errors) do
    vim.notify(err, vim.log.levels.ERROR)
  end
end

-- Collect all plugin specs from enabled modules and initialize lazy
local lazy_path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazy_path) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazy_path,
  })
end
vim.opt.rtp:prepend(lazy_path)

require("lazy").setup(module_lib.collect_plugin_specs(), {
  defaults = {
    lazy = true,
  },
  checker = {
    enabled = true,
  },
  change_detection = {
    enabled = true,
    notify = true,
  },
  -- Manages lua plugins
  rocks = { hererocks = true },
})

-- Wire up introspection commands after everything is loaded
vim.api.nvim_create_user_command("ConfigStatus", function(opts)
  local handlers = {
    modules      = function() require("lib.module").status() end,
    state        = function() require("lib.state").status() end,
    articulation = function() require("lib.articulation").status() end,
    display      = function() require("lib.display").status() end,
    capabilities = function() require("lib.capabilities").status() end,
  }

  local target = opts.args
  if target == "" then
    for _, handler in pairs(handlers) do handler() end
  elseif handlers[target] then
    handlers[target]()
  else
    vim.notify("Unknown target: " .. target, vim.log.levels.WARN)
  end
end, {
  nargs = "?",
  complete = function()
    return { "modules", "state", "articulation", "display", "capabilities" }
  end,
  desc = "Inspect environment state",
})
