-- tests/spec/debugging_spec.lua
-- Validates the debugging module's structure, plugin specs, keymaps,
-- and DAP configuration templates.
-- Runs headlessly — no plugins loaded, only exercises registration
-- and source-level invariants.

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

print '\n=== debugging module ==='

local config_root = vim.fn.stdpath 'config'

-- ── Module registration ─────────────────────────────────────────────────

it('debugging module can be required', function()
  local m = require 'modules.debugging'
  assert(type(m) == 'table', 'module did not return a table')
end)

it('has correct name and domain', function()
  local m = require 'modules.debugging'
  eq(m.name, 'debugging', 'name')
  eq(m.domain, 'debugging', 'domain')
end)

it('depends on text_editing', function()
  local m = require 'modules.debugging'
  local found = false
  for _, dep in ipairs(m.depends_on or {}) do
    if dep == 'text_editing' then found = true end
  end
  assert(found, 'debugging must depend on text_editing')
end)

it('has setup function', function()
  local m = require 'modules.debugging'
  assert(type(m.setup) == 'function', 'setup must be a function')
end)

-- ── Plugin specs ────────────────────────────────────────────────────────

it('declares nvim-dap plugin', function()
  local m = require 'modules.debugging'
  assert(m.plugins['mfussenegger/nvim-dap'] ~= nil, 'missing nvim-dap spec')
end)

it('declares nvim-dap-ui plugin', function()
  local m = require 'modules.debugging'
  assert(m.plugins['rcarriga/nvim-dap-ui'] ~= nil, 'missing nvim-dap-ui spec')
end)

it('declares nvim-dap-python plugin', function()
  local m = require 'modules.debugging'
  assert(m.plugins['mfussenegger/nvim-dap-python'] ~= nil, 'missing nvim-dap-python spec')
end)

it('declares nvim-dap-virtual-text plugin', function()
  local m = require 'modules.debugging'
  assert(m.plugins['theHamsta/nvim-dap-virtual-text'] ~= nil, 'missing nvim-dap-virtual-text spec')
end)

it('does NOT duplicate overseer spec (owned by terminal module)', function()
  local m = require 'modules.debugging'
  assert(m.plugins['stevearc/overseer.nvim'] == nil,
    'overseer.nvim should not be in debugging plugins — it belongs in terminal')
end)

-- ── Source-level DAP keymap assertions ───────────────────────────────────

local function read_file(path)
  local f = io.open(path, 'r')
  assert(f, 'could not open ' .. path)
  local text = f:read '*a'
  f:close()
  return text
end

local src = read_file(config_root .. '/lua/modules/debugging.lua')

-- All Doom SPC d keymaps should be present
local EXPECTED_KEYMAPS = {
  { lhs = '<leader>ds', desc = 'start/continue' },
  { lhs = '<leader>dc', desc = 'continue' },
  { lhs = '<leader>dn', desc = 'step over' },
  { lhs = '<leader>di', desc = 'step into' },
  { lhs = '<leader>do', desc = 'step out' },
  { lhs = '<leader>dr', desc = 'restart' },
  { lhs = '<leader>dl', desc = 'repl' },
  { lhs = '<leader>dC', desc = 'cleanup' },
  { lhs = '<leader>dbb', desc = 'breakpoint toggle' },
  { lhs = '<leader>dbc', desc = 'breakpoint condition' },
  { lhs = '<leader>dbl', desc = 'breakpoint log' },
  { lhs = '<leader>dee', desc = 'eval' },
  { lhs = '<leader>des', desc = 'eval at cursor' },
  { lhs = '<leader>du', desc = 'toggle UI' },
  { lhs = '<leader>dt', desc = 'run task' },
  { lhs = '<leader>dT', desc = 'toggle task list' },
}

for _, km in ipairs(EXPECTED_KEYMAPS) do
  it('SPC d keymap: ' .. km.lhs .. ' (' .. km.desc .. ')', function()
    assert(src:find(vim.pesc(km.lhs), 1, true),
      'missing keymap ' .. km.lhs .. ' in debugging.lua')
  end)
end

-- ── Python DAP configuration templates ──────────────────────────────────

local EXPECTED_TEMPLATES = {
  'Run file (buffer)',
  'Run pytest (verbose)',
  'Run pytest (current function)',
  'Run module (prompt)',
  'Attach to running process',
}

for _, name in ipairs(EXPECTED_TEMPLATES) do
  it('Python DAP template: ' .. name, function()
    assert(src:find(name, 1, true),
      'missing DAP template "' .. name .. '" in debugging.lua')
  end)
end

-- ── Ensure ensure_dap_ready is guarded by _dap_ready flag ───────────────

it('ensure_dap_ready uses _dap_ready guard', function()
  assert(src:find '_dap_ready', 'missing _dap_ready guard flag')
  assert(src:find 'if _dap_ready then return end', 'missing early return guard in ensure_dap_ready')
end)

-- ── Verify debugpy python resolution logic ──────────────────────────────

it('find_debugpy_python checks .venv first', function()
  assert(src:find '.venv/bin/python', 'should check project .venv first')
end)

it('find_debugpy_python checks mason second', function()
  assert(src:find 'mason/packages/debugpy', 'should check mason debugpy as fallback')
end)

-- Summary
io.write(string.format('\n  %d passed, %d failed\n', pass, fail))
if fail > 0 then vim.cmd 'cq 1' end
