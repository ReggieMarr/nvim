-- tests/spec/articulation_spec.lua
-- Unit tests for lib/articulation.lua

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

print '\n=== lib/articulation ==='

local art = require 'lib.articulation'

-- Track keymap set calls in tests
local keymap_calls = {}
local orig_keymap_set = vim.keymap.set
vim.keymap.set = function(mode, lhs, rhs, opts)
  table.insert(keymap_calls, { mode = mode, lhs = lhs, opts = opts })
  -- Do NOT actually set keymaps (they'd persist across tests)
end

it('register() stores the action', function()
  keymap_calls = {}
  art.register {
    id       = 'test.action_store',
    handler  = function() end,
    desc     = 'Test store action',
    module   = 'test_module',
    bindings = { { lhs = '<leader>za' } },
  }
  assert(art._actions['test.action_store'] ~= nil, 'action should be stored')
  eq(art._actions['test.action_store'].module, 'test_module', 'module attribution')
  eq(art._actions['test.action_store'].desc, 'Test store action', 'description')
end)

it('register() calls vim.keymap.set for each binding', function()
  keymap_calls = {}
  art.register {
    id       = 'test.keymap_call',
    handler  = function() end,
    desc     = 'Test keymap call',
    module   = 'test_module',
    bindings = { { lhs = '<leader>zb', mode = 'n' } },
  }
  assert(#keymap_calls >= 1, 'expected at least one keymap.set call')
  local found = false
  for _, call in ipairs(keymap_calls) do
    if call.lhs == '<leader>zb' then found = true; break end
  end
  assert(found, 'keymap.set should have been called with <leader>zb')
end)

it('register() handles multi-mode bindings', function()
  keymap_calls = {}
  art.register {
    id       = 'test.multi_mode',
    handler  = function() end,
    desc     = 'Multi-mode action',
    module   = 'test_module',
    bindings = { { lhs = 'ih', mode = { 'o', 'x' } } },
  }
  assert(#keymap_calls >= 1, 'expected keymap.set call for multi-mode binding')
  -- The mode passed to vim.keymap.set should be the table { 'o', 'x' }
  local call = keymap_calls[#keymap_calls]
  assert(type(call.mode) == 'table', 'mode should be a table for multi-mode bindings')
end)

it('register() validates required fields', function()
  -- Missing handler
  local ok1 = pcall(art.register, {
    id       = 'test.bad1',
    desc     = 'bad',
    module   = 'mod',
    bindings = { { lhs = 'x' } },
  })
  assert(not ok1, 'should reject spec missing handler')

  -- Missing desc
  local ok2 = pcall(art.register, {
    id       = 'test.bad2',
    handler  = function() end,
    module   = 'mod',
    bindings = { { lhs = 'x' } },
  })
  assert(not ok2, 'should reject spec missing desc')
end)

it('get_actions() returns all registered actions as sorted list', function()
  -- Register a couple more
  art.register {
    id = 'test.get_a1', handler = function() end, desc = 'A1',
    module = 'mod_a', bindings = { { lhs = '<leader>z1' } },
  }
  art.register {
    id = 'test.get_a2', handler = function() end, desc = 'A2',
    module = 'mod_a', bindings = { { lhs = '<leader>z2' } },
  }
  local actions = art.get_actions()
  assert(type(actions) == 'table', 'expected table')
  assert(#actions >= 2, 'expected at least 2 actions')
  -- Should be sorted by id
  for i = 2, #actions do
    assert(actions[i-1].id <= actions[i].id, 'actions should be sorted by id')
  end
end)

it('get_actions() filters by module', function()
  art.register {
    id = 'filter_test.action', handler = function() end, desc = 'filter test',
    module = 'unique_filter_module_xyz', bindings = { { lhs = '<leader>zz' } },
  }
  local actions = art.get_actions { module = 'unique_filter_module_xyz' }
  assert(#actions >= 1, 'expected at least one matching action')
  for _, a in ipairs(actions) do
    eq(a.module, 'unique_filter_module_xyz', 'all returned actions should match filter')
  end
end)

-- Restore keymap.set
vim.keymap.set = orig_keymap_set

-- Summary
io.write(string.format('\n  %d passed, %d failed\n', pass, fail))
if fail > 0 then vim.cmd 'cq 1' end
