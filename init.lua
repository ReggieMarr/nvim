-- init.lua
-- Entry point. Defines features, bootstraps lazy, loads base config.
-- Nothing else belongs here.

-- ─── Feature Flags ───────────────────────────────────────────────────────────

local features = {
  -- UI chrome: statusline, colorscheme, notifications, icons
  interface = true,
  -- Fuzzy finding, picking, search - the consistency layer
  navigation = true,
  -- Treesitter, LSP, completion, formatting, diagnostics
  language = true,
  -- Git signs, blame, diff, conflict resolution
  version_control = true,
  -- Terminals, build runners, test runners
  execution = true,
  -- File system, OS integration
  system = true,
  -- External services: issue trackers, project management
  project = false,
}

-- Make features globally readable but not writable
-- Modules should never mutate this table
_G.features = setmetatable(features, {
  __newindex = function()
    error("[init] Feature flags are immutable after startup")
  end,
})

-- ─── Bootstrap Lazy ──────────────────────────────────────────────────────────

local lazy_path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazy_path) then
  vim.notify("[init] Cloning lazy.nvim...", vim.log.levels.INFO)
  vim.fn.system({
    "git", "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazy_path,
  })
end

vim.opt.rtp:prepend(lazy_path)

-- ─── Base Config ─────────────────────────────────────────────────────────────

-- Load options, global keymaps, autocmds before any plugins
-- base.lua has no plugin dependencies
require("base")

-- ─── Module Loading ───────────────────────────────────────────────────────────

local module = require("lib.module")

-- -- Register all modules regardless of feature flags
-- -- module.register() handles whether they're active
-- -- Order here is the fallback order if DAG resolution finds no constraints
-- local module_files = {
--   "modules.interface",
--   "modules.navigation",
--   "modules.language",
--   "modules.version_control",
--   "modules.execution",
--   "modules.system",
--   "modules.project",
-- }

-- for _, mod in ipairs(module_files) do
--   local ok, err = pcall(require, mod)
--   if not ok then
--     vim.notify(
--       string.format("[init] Failed to load module file '%s':\n%s", mod, err),
--       vim.log.levels.ERROR
--     )
--   end
-- end

-- -- Validate the module graph before handing off to lazy
-- -- Surfaces dependency errors before any plugins load
-- local valid, errors = module.validate()
-- if not valid then
--   for _, err in ipairs(errors) do
--     vim.notify(err, vim.log.levels.ERROR)
--   end
-- end

-- ─── Lazy Setup ──────────────────────────────────────────────────────────────

require("lazy").setup(module.collect_plugin_specs(), {
  -- Lazy options that are part of your platform, not plugin config
  change_detection = {
    notify = false,
  },
  performance = {
    rtp = {
      -- Disable built-ins you're replacing with plugins
      disabled_plugins = {
        "gzip",
        "netrw",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

-- ─── Introspection Commands ───────────────────────────────────────────────────

-- Defined here rather than in a module because they describe
-- the platform itself, not any particular feature

vim.api.nvim_create_user_command("ConfigStatus", function(opts)
  local targets = {
    modules      = function() require("lib.module").status() end,
    keys         = function() require("lib.keys").status() end,
    capabilities = function() require("lib.capabilities").status() end,
    agent        = function() require("lib.agent").status() end,
  }

  local target = opts.args

  if target == "" then
    for _, fn in pairs(targets) do fn() end
  elseif targets[target] then
    targets[target]()
  else
    vim.notify(
      string.format("[ConfigStatus] Unknown target '%s'", target),
      vim.log.levels.WARN
    )
  end
end, {
  nargs = "?",
  complete = function()
    return { "modules", "keys", "capabilities", "agent" }
  end,
  desc = "Inspect platform state",
})
