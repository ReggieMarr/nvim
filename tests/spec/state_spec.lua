-- tests/spec/state_spec.lua
-- Unit tests for lib/state.lua

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

print '\n=== lib/state ==='

local state = require 'lib.state'

it('register_provider() accepts a valid spec', function()
  local registered = false
  state.register_provider {
    id      = 'test.counter',
    events  = { 'BufEnter' },
    collect = function()
      registered = true
      return 42
    end,
    desc = 'Test counter provider',
  }
  -- Provider should have been collected immediately on registration
  eq(state.get 'test.counter', 42, 'initial collection on register')
end)

it('_update() sets a value directly', function()
  state._update('test.direct_value', 'hello')
  eq(state.get 'test.direct_value', 'hello', '_update should set the value')
end)

it('get() returns nil for unknown key', function()
  local val = state.get 'nonexistent.key.xyz'
  assert(val == nil, 'expected nil for unknown key')
end)

it('register_provider() with duplicate id emits warning but overwrites', function()
  -- First registration
  state.register_provider {
    id      = 'test.duplicate',
    events  = { 'BufEnter' },
    collect = function() return 'first' end,
  }
  -- Second registration (should warn but work)
  state.register_provider {
    id      = 'test.duplicate',
    events  = { 'BufEnter' },
    collect = function() return 'second' end,
  }
  -- After second registration, the new provider's collect should have run
  eq(state.get 'test.duplicate', 'second', 'second registration should overwrite')
end)

it('register_provider() validates required fields', function()
  -- Missing id
  local ok1 = pcall(state.register_provider, {
    events  = { 'BufEnter' },
    collect = function() end,
  })
  assert(not ok1, 'should reject spec missing id')

  -- Missing events
  local ok2 = pcall(state.register_provider, {
    id      = 'test.bad',
    collect = function() end,
  })
  assert(not ok2, 'should reject spec missing events')

  -- Missing collect
  local ok3 = pcall(state.register_provider, {
    id     = 'test.bad',
    events = { 'BufEnter' },
  })
  assert(not ok3, 'should reject spec missing collect')
end)

it('provider error is caught and does not propagate', function()
  state.register_provider {
    id      = 'test.error_provider',
    events  = { 'BufEnter' },
    collect = function() error('intentional test error') end,
    desc    = 'Always errors — tests pcall wrapper',
  }
  -- Should not throw; value stays nil (or previous)
  -- The pcall wrapper should have caught the error
  local val = state.get 'test.error_provider'
  -- value may be nil or a previously set value — the key point is no exception was raised
  assert(true, 'no exception raised by erroring provider')
end)

it('get() with no argument returns full store table', function()
  state._update('test.full_store_marker', 'marker_value')
  local full = state.get()
  assert(type(full) == 'table', 'get() with no args returns table')
  eq(full['test.full_store_marker'], 'marker_value', 'full store contains set values')
end)

-- Summary
io.write(string.format('\n  %d passed, %d failed\n', pass, fail))
if fail > 0 then vim.cmd 'cq 1' end
