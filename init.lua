-- init.lua

-- Bootstrap lazy.nvim
local lazy_path = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazy_path) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazy_path,
  }
end
vim.opt.rtp:prepend(lazy_path)

-- Core state providers run before any module
require('lib.state')._register_core_providers()

-- Base vim options (no plugin deps)
require 'base'

-- Module manifest: this list is the only control surface.
-- Comment a line to disable that module entirely.
local module_files = {
  'modules.interface',
  'modules.filesystem',
  'modules.language',
  'modules.text_editing',
  'modules.version_control',
  -- "modules.project",
}

for _, mod in ipairs(module_files) do
  require(mod)
end

-- Validate dependency graph before handing off to lazy
local module_lib = require 'lib.module'
local valid, errors = module_lib.validate()
if not valid then
  for _, err in ipairs(errors) do
    vim.notify(err, vim.log.levels.ERROR)
  end
end

-- Collect merged plugin specs and initialize lazy
require('lazy').setup(module_lib.collect_plugin_specs(), {
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
  -- performance = {
  --   rtp = {
  --     disabled_plugins = {
  --       "gzip", "matchit", "matchparen",
  --       "netrwPlugin", "tarPlugin", "tohtml",
  --       "tutor", "zipPlugin",
  --     },
  --   },
  -- },
})

-- Run all module setup() functions in dependency order.
-- At this point lazy has loaded plugins so plugin APIs are available.
module_lib.run_setup()

-- Introspection commands
vim.api.nvim_create_user_command('ConfigStatus', function(opts)
  local handlers = {
    modules = function() require('lib.module').status() end,
    state = function() require('lib.state').status() end,
    articulation = function() require('lib.articulation').status() end,
    display = function() require('lib.display').status() end,
    capabilities = function() require('lib.capabilities').status() end,
  }

  local target = opts.args
  if target == '' then
    for _, h in pairs(handlers) do
      h()
    end
  elseif handlers[target] then
    handlers[target]()
  else
    vim.notify('Unknown target: ' .. target, vim.log.levels.WARN)
  end
end, {
  nargs = '?',
  complete = function() return { 'modules', 'state', 'articulation', 'display', 'capabilities' } end,
  desc = 'Inspect environment state',
})
