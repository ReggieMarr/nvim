-- tests/spec/language_spec.lua
-- Validates that all language specs satisfy the LanguageSpec schema.
-- Tests the public query API on the languages module.
-- Runs without plugin dependencies (no mason, no LSP, no treesitter).

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

local function has(t, k, msg)
  assert(t[k] ~= nil, (msg or '') .. string.format(" — missing key '%s'", k))
end

print '\n=== language specs ==='

-- Load languages module (pure data, no plugin deps)
local langs = require 'modules.text_editing.languages'

-- ── Schema validation ────────────────────────────────────────────────────

-- Directly require each language spec to validate schema
local spec_modules = {
  'modules.text_editing.languages.lua',
  'modules.text_editing.languages.python',
  'modules.text_editing.languages.c',
}

for _, mod_name in ipairs(spec_modules) do
  local short = mod_name:match '%.(%w+)$'
  local ok, spec = pcall(require, mod_name)

  it(short .. ': module loads without error', function()
    assert(ok, tostring(spec))
  end)

  if ok then
    it(short .. ': has ft field', function()
      has(spec, 'ft', short)
      local ft = spec.ft
      assert(type(ft) == 'string' or type(ft) == 'table',
        'ft must be string or table, got ' .. type(ft))
    end)

    it(short .. ': lsp entries have required fields', function()
      for server, lsp_spec in pairs(spec.lsp or {}) do
        assert(type(server) == 'string',
          short .. ': lsp key must be a string, got ' .. type(server))
        assert(type(lsp_spec.install) == 'boolean',
          short .. '.' .. server .. ': install must be boolean')
        assert(type(lsp_spec.config) == 'table',
          short .. '.' .. server .. ': config must be a table')
      end
    end)

    it(short .. ': formatter entries have required fields', function()
      for i, fmt in ipairs(spec.formatters or {}) do
        assert(type(fmt.name) == 'string',
          string.format('%s.formatters[%d]: name must be a string', short, i))
        if fmt.mason_package ~= nil then
          assert(type(fmt.mason_package) == 'string' or fmt.mason_package == false,
            string.format('%s.formatters[%d]: mason_package must be string or false', short, i))
        end
      end
    end)

    it(short .. ': treesitter entries have parsers list', function()
      if spec.treesitter then
        assert(type(spec.treesitter.parsers) == 'table',
          short .. ': treesitter.parsers must be a table')
        for _, p in ipairs(spec.treesitter.parsers) do
          assert(type(p) == 'string', short .. ': parser names must be strings, got ' .. type(p))
        end
      end
    end)
  end
end

-- ── Public query API ─────────────────────────────────────────────────────

it('get_mason_lsp_packages() returns a list of strings', function()
  local pkgs = langs.get_mason_lsp_packages()
  assert(type(pkgs) == 'table', 'expected table')
  for _, p in ipairs(pkgs) do
    assert(type(p) == 'string', 'expected string, got ' .. type(p))
  end
end)

it('get_mason_tool_packages() returns deduplicated list of strings', function()
  local pkgs = langs.get_mason_tool_packages()
  assert(type(pkgs) == 'table', 'expected table')
  local seen = {}
  for _, p in ipairs(pkgs) do
    assert(type(p) == 'string', 'expected string')
    assert(not seen[p], 'duplicate package: ' .. p)
    seen[p] = true
  end
end)

it('get_treesitter_parsers() returns deduplicated list of strings', function()
  local parsers = langs.get_treesitter_parsers()
  assert(type(parsers) == 'table', 'expected table')
  local seen = {}
  for _, p in ipairs(parsers) do
    assert(type(p) == 'string', 'expected string')
    assert(not seen[p], 'duplicate parser: ' .. p)
    seen[p] = true
  end
end)

it('get_formatters_by_ft() returns table keyed by filetype', function()
  local by_ft = langs.get_formatters_by_ft()
  assert(type(by_ft) == 'table', 'expected table')
  for ft, formatters in pairs(by_ft) do
    assert(type(ft) == 'string', 'ft key must be string')
    assert(type(formatters) == 'table', 'formatter list must be table')
    for _, name in ipairs(formatters) do
      assert(type(name) == 'string', 'formatter name must be string')
    end
  end
end)

it('get_formatters_by_ft() includes c and cpp from c spec', function()
  local by_ft = langs.get_formatters_by_ft()
  assert(by_ft['c']   ~= nil, "missing 'c' in formatters_by_ft")
  assert(by_ft['cpp'] ~= nil, "missing 'cpp' in formatters_by_ft")
  -- clang-format should be the formatter for C
  local has_clang_format = false
  for _, name in ipairs(by_ft['c'] or {}) do
    if name == 'clang-format' then has_clang_format = true end
  end
  assert(has_clang_format, "clang-format should be in c formatters")
end)

it('get_conform_formatter_configs() returns table of config tables', function()
  local configs = langs.get_conform_formatter_configs()
  assert(type(configs) == 'table', 'expected table')
  for name, cfg in pairs(configs) do
    assert(type(name) == 'string', 'formatter name must be string')
    assert(type(cfg) == 'table', 'config must be table')
  end
end)

it('iter_lsp_servers() iterates over all server pairs', function()
  local count = 0
  for server, lsp in langs.iter_lsp_servers() do
    count = count + 1
    assert(type(server) == 'string', 'server name must be string')
    assert(type(lsp) == 'table', 'lsp spec must be table')
  end
  assert(count >= 3, 'expected at least 3 LSP servers (lua_ls, basedpyright, clangd), got ' .. count)
end)

it('universal_parsers is a non-empty table of strings', function()
  local up = langs.universal_parsers
  assert(type(up) == 'table', 'expected table')
  assert(#up > 0, 'expected non-empty universal parsers')
  for _, p in ipairs(up) do
    assert(type(p) == 'string', 'parser must be string, got ' .. type(p))
  end
end)

-- Summary
io.write(string.format('\n  %d passed, %d failed\n', pass, fail))
if fail > 0 then vim.cmd 'cq 1' end
