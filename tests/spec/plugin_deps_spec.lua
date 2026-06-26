-- tests/spec/plugin_deps_spec.lua
-- Verifies that every live require('x') call in module files has a corresponding
-- plugin spec declared in one of the modules.
--
-- This catches the class of bug where a plugin is removed from the spec but
-- its require() call is still in a setup() body — the error only surfaces at
-- runtime when the keymap is first triggered.

local pass, fail = 0, 0

local function it(name, fn)
  local ok, err = pcall(fn)
  if ok then
    pass = pass + 1
    io.write('  \27[32m✓\27[0m ' .. name .. '\n')
  else
    fail = fail + 1
    io.write('  \27[31m✗ FAIL\27[0m ' .. name .. '\n')
    io.write('    ' .. tostring(err) .. '\n')
  end
end

print '\n=== plugin dependency coverage ==='

local config_root = vim.fn.stdpath 'config'

-- ── Helpers ──────────────────────────────────────────────────────────────

---Returns all .lua files under a directory (recursive)
local function lua_files(dir)
  local result = {}
  local handle = vim.loop.fs_opendir(dir, nil, 100)
  if not handle then return result end
  while true do
    local entries = vim.loop.fs_readdir(handle)
    if not entries then break end
    for _, e in ipairs(entries) do
      local full = dir .. '/' .. e.name
      if e.type == 'directory' and e.name ~= 'backup' then
        local sub = lua_files(full)
        for _, f in ipairs(sub) do table.insert(result, f) end
      elseif e.type == 'file' and e.name:match '%.lua$' then
        table.insert(result, full)
      end
    end
  end
  vim.loop.fs_closedir(handle)
  return result
end

---Collect all plugin spec keys from module files.
---Returns a set: plugin_short_name → true
local function collect_declared_plugins()
  local declared = {}
  local module_dir = config_root .. '/lua/modules'
  local files = lua_files(module_dir)
  for _, f in ipairs(files) do
    local handle = io.open(f, 'r')
    if handle then
      local text = handle:read '*a'
      handle:close()
      -- Strip comments
      text = text:gsub('%-%-[^\n]*', '')
      -- Match plugin spec keys: ['author/plugin.name'] = { ... }
      for full in text:gmatch "%['([^']+)'%]%s*=" do
        -- key part after slash (or full key if no slash)
        local short = full:match '/(.+)$' or full
        declared[short] = true
        declared[full] = true   -- also index by full name
      end
    end
  end
  return declared
end

-- ── Tests ─────────────────────────────────────────────────────────────────

local declared = collect_declared_plugins()

-- Plugins that are intentionally provided by a meta-package or known alias
-- Add entries here when the require name differs from the spec key.
local KNOWN_ALIASES = {
  -- mini.* from nvim-mini/* or nvim-mini/*
  ['mini.files']    = true,
  ['mini.icons']    = true,
  ['mini.sessions'] = true,
  ['mini.pick']     = true,
  ['mini.extra']    = true,
  -- stdlib / nvim builtins
  ['vim']           = true,
  ['vim.lsp']       = true,
  ['vim.treesitter'] = true,
  -- project-local libs (not lazy plugins)
  ['lib.state']     = true,
  ['lib.module']    = true,
  ['lib.capabilities'] = true,
  ['lib.display']   = true,
  ['lib.articulation'] = true,
  ['env']           = true,
  -- modules (loaded by the module system, not lazy)
  ['modules.text_editing.languages']     = true,
  ['modules.text_editing.languages.lua'] = true,
  ['modules.text_editing.languages.python'] = true,
  ['modules.text_editing.languages.c']   = true,
  ['modules.text_editing.lsp']             = true,
  ['modules.text_editing.pickers']         = true,
  ['modules.filesystem.pickers']         = true,
  ['modules.filesystem.utils']           = true,
  ['utils.file_browsing.directory_editor'] = true,
  ['utils.file_browsing.file_search_config'] = true,
  ['utils.file_browsing.minibuffer_picker']  = true,
  ['core.base_config']  = true,
  ['core.pickers']      = true,
}

-- ── Exhaustive plugin spec assertions ────────────────────────────────────
-- Every plugin we require() must have a spec declared somewhere.
-- Grouped by module for clarity.

local MUST_HAVE_SPEC = {
  -- interface module
  { require_name = 'snacks',     spec = 'folke/snacks.nvim' },
  { require_name = 'oil',        spec = 'stevearc/oil.nvim' },
  { require_name = 'which-key',  spec = 'folke/which-key.nvim' },
  { require_name = 'lualine',    spec = 'nvim-lualine/lualine.nvim' },
  { require_name = 'tokyonight', spec = 'folke/tokyonight.nvim' },

  -- filesystem module
  { require_name = 'mini.pick',     spec = 'nvim-mini/mini.pick' },
  { require_name = 'mini.extra',    spec = 'nvim-mini/mini.extra' },
  { require_name = 'mini.files',    spec = 'nvim-mini/mini.files' },
  { require_name = 'mini.icons',    spec = 'nvim-mini/mini.icons' },
  { require_name = 'mini.sessions', spec = 'nvim-mini/mini.sessions' },

  -- text_editing module
  { require_name = 'conform',        spec = 'stevearc/conform.nvim' },
  { require_name = 'blink.cmp',      spec = 'saghen/blink.cmp' },
  { require_name = 'mason',          spec = 'mason-org/mason.nvim' },
  { require_name = 'mason-lspconfig', spec = 'mason-org/mason-lspconfig.nvim' },
  { require_name = 'mason-tool-installer', spec = 'WhoIsSethDaniel/mason-tool-installer.nvim' },
  { require_name = 'nvim-treesitter', spec = 'nvim-treesitter/nvim-treesitter' },
  { require_name = 'treesitter-context', spec = 'nvim-treesitter/nvim-treesitter-context' },

  -- version_control module
  { require_name = 'neogit',    spec = 'NeogitOrg/neogit' },
  { require_name = 'gitsigns',  spec = 'lewis6991/gitsigns.nvim' },

  -- orgmode module
  { require_name = 'orgmode',      spec = 'nvim-orgmode/orgmode' },
  { require_name = 'org-bullets',   spec = 'nvim-orgmode/org-bullets.nvim' },
  { require_name = 'headlines',     spec = 'lukas-reineke/headlines.nvim' },

  -- terminal module
  { require_name = 'overseer',  spec = 'stevearc/overseer.nvim' },

  -- debugging module
  { require_name = 'dap',                   spec = 'mfussenegger/nvim-dap' },
  { require_name = 'dapui',                  spec = 'rcarriga/nvim-dap-ui' },
  { require_name = 'dap-python',             spec = 'mfussenegger/nvim-dap-python' },
  { require_name = 'nvim-dap-virtual-text',  spec = 'theHamsta/nvim-dap-virtual-text' },
}

for _, entry in ipairs(MUST_HAVE_SPEC) do
  local short = entry.spec:match '/(.+)$' or entry.spec
  it(entry.require_name .. ' has plugin spec (' .. entry.spec .. ')', function()
    assert(
      declared[short] or declared[entry.spec],
      string.format(
        "require('%s') is used in module files but '%s' is not declared in any plugins table.\n" ..
        "    Add it to the appropriate module's plugins spec.",
        entry.require_name, entry.spec
      )
    )
  end)
end

-- ── Module-specific location assertions ──────────────────────────────────
-- Ensure plugins are declared in the correct module (not just anywhere).

local MODULE_LOCATION_CHECKS = {
  { file = 'filesystem/init.lua',     plugin = 'nvim-mini/mini.pick', label = 'mini.pick in filesystem' },
  { file = 'text_editing/init.lua',   plugin = 'nvim-mini/mini.extra', label = 'mini.extra in text_editing' },
  { file = 'version_control.lua',     plugin = 'NeogitOrg/neogit', label = 'neogit in version_control' },
  { file = 'version_control.lua',     plugin = 'lewis6991/gitsigns.nvim', label = 'gitsigns in version_control' },
  { file = 'orgmode.lua',             plugin = 'nvim-orgmode/orgmode', label = 'orgmode in orgmode module' },
  { file = 'orgmode.lua',             plugin = 'nvim-orgmode/org-bullets.nvim', label = 'org-bullets in orgmode module' },
  { file = 'orgmode.lua',             plugin = 'lukas-reineke/headlines.nvim', label = 'headlines in orgmode module' },
  { file = 'terminal.lua',            plugin = 'stevearc/overseer.nvim', label = 'overseer in terminal module' },
  { file = 'debugging.lua',           plugin = 'mfussenegger/nvim-dap', label = 'nvim-dap in debugging module' },
  { file = 'debugging.lua',           plugin = 'rcarriga/nvim-dap-ui', label = 'nvim-dap-ui in debugging module' },
  { file = 'debugging.lua',           plugin = 'mfussenegger/nvim-dap-python', label = 'nvim-dap-python in debugging module' },
  { file = 'interface.lua',           plugin = 'folke/snacks.nvim', label = 'snacks in interface module' },
  { file = 'interface.lua',           plugin = 'stevearc/oil.nvim', label = 'oil in interface module' },
  { file = 'interface.lua',           plugin = 'folke/which-key.nvim', label = 'which-key in interface module' },
}

for _, check in ipairs(MODULE_LOCATION_CHECKS) do
  it(check.label, function()
    local f = io.open(config_root .. '/lua/modules/' .. check.file, 'r')
    assert(f, 'could not open modules/' .. check.file)
    local text = f:read '*a'
    f:close()
    assert(text:find(check.plugin, 1, true),
      check.plugin .. ' not found in modules/' .. check.file)
  end)
end

-- ── Specific require-before-use assertions ───────────────────────────────

-- Verify MiniPick is always required explicitly before use (no implicit global)
it('text_editing buffer_lines requires mini.pick explicitly', function()
  local f = io.open(config_root .. '/lua/modules/text_editing/init.lua', 'r')
  assert(f, 'could not open text_editing/init.lua')
  local text = f:read '*a'
  f:close()
  local fn_body = text:match "vim%.ui%.picker%.buffer_lines%s*=%s*function(.-)end"
  assert(fn_body, 'could not find buffer_lines function body')
  assert(
    fn_body:find "require 'mini.pick'",
    "buffer_lines should explicitly require 'mini.pick' (not rely on global)"
  )
end)

-- Summary
io.write(string.format('\n  %d passed, %d failed\n', pass, fail))
if fail > 0 then vim.cmd 'cq 1' end
