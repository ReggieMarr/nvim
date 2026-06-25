-- tests/spec/capabilities_spec.lua
-- Unit tests for lib/capabilities.lua

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

local function has_key(t, k)
  assert(t[k] ~= nil, string.format("expected key '%s' in table", k))
end

print '\n=== lib/capabilities ==='

local caps = require 'lib.capabilities'

-- Reset state between tests by using a fresh-ish table
-- (we share state across tests since this module uses module-level tables)

it('extend() registers methods in the slot', function()
  caps.extend('test_slot', { foo = function() return 'foo' end }, 'test_module')
  local entries = caps._entries['test_slot']
  assert(entries ~= nil, 'expected entries for test_slot')
  assert(#entries >= 1, 'expected at least one entry')
  eq(entries[#entries].method, 'foo', 'method name')
  eq(entries[#entries].module, 'test_module', 'module attribution')
end)

it('get() returns the merged object for a slot', function()
  caps.extend('test_slot2', {
    alpha = function() return 1 end,
    beta  = function() return 2 end,
  }, 'mod_a')
  local obj = caps.get 'test_slot2'
  assert(type(obj) == 'table', 'expected table from get()')
  assert(type(obj.alpha) == 'function', 'expected alpha to be a function')
  assert(type(obj.beta)  == 'function', 'expected beta to be a function')
end)

it('later extend() shadows earlier registration for same method', function()
  caps.extend('shadow_test', { fn = function() return 'first' end  }, 'mod_a')
  caps.extend('shadow_test', { fn = function() return 'second' end }, 'mod_b')
  local obj = caps.get 'shadow_test'
  eq(obj.fn(), 'second', 'last write wins')
end)

it('get() on unknown slot returns empty table (not nil)', function()
  local obj = caps.get 'definitely_not_registered_abc123'
  assert(type(obj) == 'table', 'expected empty table for unknown slot')
end)

it('slots() returns list of registered slot names', function()
  caps.extend('slots_test_slot', { x = function() end }, 'mod')
  local slots = caps.slots()
  assert(type(slots) == 'table', 'slots() should return a table')
  local found = false
  for _, s in ipairs(slots) do
    if s == 'slots_test_slot' then found = true; break end
  end
  assert(found, 'slots_test_slot should appear in slots()')
end)

it('extend() for picker slot also updates vim.ui.picker', function()
  -- Ensure vim.ui.picker exists (it does in the real init, here we mock it)
  vim.ui = vim.ui or {}
  vim.ui.picker = vim.ui.picker or {}

  caps.extend('picker', { test_picker_fn = function() return 'picker!' end }, 'test')
  assert(type(vim.ui.picker.test_picker_fn) == 'function',
    'picker method should be mirrored into vim.ui.picker')
  eq(vim.ui.picker.test_picker_fn(), 'picker!', 'method should be callable via vim.ui.picker')
end)

it('get() for picker slot returns vim.ui.picker', function()
  vim.ui = vim.ui or {}
  vim.ui.picker = vim.ui.picker or {}
  vim.ui.picker._marker = 'canonical'

  local obj = caps.get 'picker'
  eq(obj._marker, 'canonical', 'picker slot should return vim.ui.picker')
end)

-- Summary
io.write(string.format('\n  %d passed, %d failed\n', pass, fail))
if fail > 0 then vim.cmd 'cq 1' end
