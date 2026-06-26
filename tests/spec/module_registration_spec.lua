-- tests/spec/module_registration_spec.lua
-- Validates that all module files are well-formed and register correctly
-- with the module system. Does NOT load plugins or run setup() — only
-- exercises the registration and dependency DAG.

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

local function eq(a, b, label)
  local msg = label and (label .. ': ') or ''
  assert(a == b, msg .. string.format('expected %s, got %s', vim.inspect(b), vim.inspect(a)))
end

print '\n=== module registration ==='

local mod = require 'lib.module'

-- ── All expected modules ────────────────────────────────────────────────

local EXPECTED_MODULES = {
  'modules.interface',
  'modules.introspection',
  'modules.filesystem',
  'modules.text_editing',
  'modules.version_control',
  'modules.workspace',
  'modules.orgmode',
  'modules.agents',
  'modules.terminal',
  'modules.review',
  'modules.debugging',
}

-- ── Each module file can be required without error ───────────────────────

for _, mod_path in ipairs(EXPECTED_MODULES) do
  it(mod_path .. ' can be required', function()
    local m = require(mod_path)
    assert(type(m) == 'table', 'module did not return a table')
  end)
end

-- ── Each module has required fields ─────────────────────────────────────

for _, mod_path in ipairs(EXPECTED_MODULES) do
  it(mod_path .. ' has name field', function()
    local m = require(mod_path)
    assert(type(m.name) == 'string' and m.name ~= '', 'missing or empty name')
  end)

  it(mod_path .. ' has domain field', function()
    local m = require(mod_path)
    assert(type(m.domain) == 'string' and m.domain ~= '', 'missing or empty domain')
  end)

  it(mod_path .. ' has setup function', function()
    local m = require(mod_path)
    assert(type(m.setup) == 'function', 'setup must be a function')
  end)

  it(mod_path .. ' has plugins table', function()
    local m = require(mod_path)
    assert(type(m.plugins) == 'table', 'plugins must be a table')
  end)
end

-- ── Dependency references are valid ─────────────────────────────────────

local all_names = {}
for _, mod_path in ipairs(EXPECTED_MODULES) do
  local m = require(mod_path)
  all_names[m.name] = true
end

for _, mod_path in ipairs(EXPECTED_MODULES) do
  local m = require(mod_path)
  if m.depends_on then
    for _, dep in ipairs(m.depends_on) do
      it(m.name .. ' dependency "' .. dep .. '" exists', function()
        assert(all_names[dep],
          string.format('%s depends on "%s" which is not a registered module', m.name, dep))
      end)
    end
  end
  if m.optional_deps then
    for _, dep in ipairs(m.optional_deps) do
      it(m.name .. ' optional dep "' .. dep .. '" exists', function()
        assert(all_names[dep],
          string.format('%s has optional dep "%s" which is not a registered module', m.name, dep))
      end)
    end
  end
end

-- ── No duplicate module names ───────────────────────────────────────────

it('all module names are unique', function()
  local seen = {}
  for _, mod_path in ipairs(EXPECTED_MODULES) do
    local m = require(mod_path)
    assert(not seen[m.name], 'duplicate module name: ' .. m.name)
    seen[m.name] = true
  end
end)

-- ── Module count matches init.lua manifest ──────────────────────────────

it('expected module count matches (' .. #EXPECTED_MODULES .. ')', function()
  -- Read init.lua and count module entries
  local f = io.open(vim.fn.stdpath 'config' .. '/init.lua', 'r')
  assert(f, 'could not open init.lua')
  local text = f:read '*a'
  f:close()
  local count = 0
  for _ in text:gmatch "'modules%." do
    count = count + 1
  end
  -- Subtract commented-out modules
  local commented = 0
  for _ in text:gmatch "%-%-[^\n]*'modules%." do
    commented = commented + 1
  end
  local active = count - commented
  eq(active, #EXPECTED_MODULES, 'init.lua active module count')
end)

-- Summary
io.write(string.format('\n  %d passed, %d failed\n', pass, fail))
if fail > 0 then vim.cmd 'cq 1' end
