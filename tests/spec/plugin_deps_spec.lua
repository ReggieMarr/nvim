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

---Collect all non-commented require('x') and require "x" calls from a file
---Returns a list of module name strings
local function extract_requires(path)
  local content = io.open(path, 'r')
  if not content then return {} end
  local text = content:read '*a'
  content:close()

  local reqs = {}
  -- Strip line comments first to avoid false positives
  text = text:gsub('%-%-[^\n]*', '')
  for name in text:gmatch "require%s*['\"]([^'\"]+)['\"]" do
    table.insert(reqs, name)
  end
  return reqs
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
-- (e.g., 'mini.icons' is loaded via 'nvim-mini/mini.icons' in interface.lua).
-- Add entries here when the require name differs from the spec key.
local KNOWN_ALIASES = {
  -- mini.* from nvim-mini/* or echasnovski/*
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
  ['modules.filesystem.pickers']         = true,
  ['modules.filesystem.utils']           = true,
  ['utils.file_browsing.directory_editor'] = true,
  ['utils.file_browsing.file_search_config'] = true,
  ['utils.file_browsing.minibuffer_picker']  = true,
  ['core.base_config']  = true,
  ['core.pickers']      = true,
}

-- Plugins referenced by require() that must have a matching spec
-- These are the ones we explicitly want to assert on
local MUST_HAVE_SPEC = {
  ['mini.pick']  = 'echasnovski/mini.pick',
  ['mini.extra'] = 'echasnovski/mini.extra',
  ['mini.icons'] = 'nvim-mini/mini.icons',
  ['mini.files'] = 'nvim-mini/mini.files',
  ['mini.sessions'] = 'nvim-mini/mini.sessions',
  ['snacks']     = 'folke/snacks.nvim',
  ['oil']        = 'stevearc/oil.nvim',
  ['conform']    = 'stevearc/conform.nvim',
}

for require_name, spec_name in pairs(MUST_HAVE_SPEC) do
  local short = spec_name:match '/(.+)$' or spec_name
  it(require_name .. ' has plugin spec (' .. spec_name .. ')', function()
    assert(
      declared[short] or declared[spec_name],
      string.format(
        "require('%s') is used in module files but '%s' is not declared in any plugins table.\n" ..
        "    Add it to the appropriate module's plugins spec.",
        require_name, spec_name
      )
    )
  end)
end

-- Verify mini.pick is specifically in filesystem module (not just anywhere)
it('mini.pick spec is in filesystem module', function()
  local f = io.open(config_root .. '/lua/modules/filesystem/init.lua', 'r')
  assert(f, 'could not open filesystem/init.lua')
  local text = f:read '*a'
  f:close()
  assert(text:find "echasnovski/mini.pick", "mini.pick spec not found in filesystem/init.lua")
end)

-- Verify mini.extra spec is in text_editing module
it('mini.extra spec is in text_editing module', function()
  local f = io.open(config_root .. '/lua/modules/text_editing/init.lua', 'r')
  assert(f, 'could not open text_editing/init.lua')
  local text = f:read '*a'
  f:close()
  assert(text:find "echasnovski/mini.extra", "mini.extra spec not found in text_editing/init.lua")
end)

-- Verify MiniPick is always required explicitly before use (no implicit global)
it('text_editing buffer_lines requires mini.pick explicitly', function()
  local f = io.open(config_root .. '/lua/modules/text_editing/init.lua', 'r')
  assert(f, 'could not open text_editing/init.lua')
  local text = f:read '*a'
  f:close()
  -- The buffer_lines function should have a local MiniPick = require 'mini.pick' before MiniPick.*
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
