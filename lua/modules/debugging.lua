-- lua/modules/debugging.lua
-- Debugging module: DAP integration via nvim-dap, nvim-dap-ui, and overseer.
--
-- Mirrors Doom's dap-mode workflow with SPC d prefix:
--   SPC d s — start debug session (pick a configuration)
--   SPC d c — continue
--   SPC d n — step over (next)
--   SPC d i — step into
--   SPC d o — step out
--   SPC d b b — toggle breakpoint
--   SPC d b c — conditional breakpoint
--   SPC d b l — log point
--   SPC d r — restart
--   SPC d l — REPL
--   SPC d e e — eval expression
--   SPC d e s — eval thing at cursor
--   SPC d C — cleanup/terminate all sessions
--   SPC d u — toggle DAP UI
--
-- Overseer.nvim provides task runner integration:
--   SPC d t — run task (overseer)
--   SPC d T — toggle task list
--
-- DAP plugins are lazily loaded — the first keypress or command triggers
-- the full setup (adapter registration, UI, Python configs).
--
-- Domain: debugging

local env = require 'env'

-- Deferred one-shot initialisation flag
local _dap_ready = false

--- Full DAP setup — called once on first use.
local function ensure_dap_ready()
  if _dap_ready then return end
  _dap_ready = true

  local dap = require 'dap'
  local dapui = require 'dapui'

  -- ── DAP UI ──────────────────────────────────────────────────────
  dapui.setup {
    icons = { expanded = '▾', collapsed = '▸', current_frame = '▸' },
    layouts = {
      {
        elements = {
          { id = 'scopes', size = 0.4 },
          { id = 'breakpoints', size = 0.15 },
          { id = 'stacks', size = 0.25 },
          { id = 'watches', size = 0.2 },
        },
        size = 40,
        position = 'left',
      },
      {
        elements = {
          { id = 'repl', size = 0.5 },
          { id = 'console', size = 0.5 },
        },
        size = 0.25,
        position = 'bottom',
      },
    },
    floating = { border = 'rounded' },
  }

  -- Virtual text for inline variable values
  require('nvim-dap-virtual-text').setup {
    enabled = true,
    commented = true,
  }

  -- Auto open/close DAP UI on session start/end
  dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
  dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
  dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end

  -- ── DAP signs ───────────────────────────────────────────────────
  vim.fn.sign_define('DapBreakpoint',          { text = '●', texthl = 'DapBreakpoint', linehl = '', numhl = '' })
  vim.fn.sign_define('DapBreakpointCondition', { text = '◆', texthl = 'DapBreakpointCondition', linehl = '', numhl = '' })
  vim.fn.sign_define('DapLogPoint',            { text = '◇', texthl = 'DapLogPoint', linehl = '', numhl = '' })
  vim.fn.sign_define('DapStopped',             { text = '▶', texthl = 'DapStopped', linehl = 'DapStoppedLine', numhl = '' })
  vim.fn.sign_define('DapBreakpointRejected',  { text = '✗', texthl = 'DapBreakpointRejected', linehl = '', numhl = '' })

  -- ── Python adapter (debugpy) ────────────────────────────────────
  -- Mirrors Doom's (setq dap-python-debugger 'debugpy)
  local function find_debugpy_python()
    -- Project venv (uv projects)
    local root = env.state.get 'workspace.root' or vim.fn.getcwd()
    local venv_debugpy = root .. '/.venv/bin/python'
    if vim.uv.fs_stat(venv_debugpy) then return venv_debugpy end

    -- Mason-installed debugpy
    local mason_debugpy = vim.fn.stdpath 'data' .. '/mason/packages/debugpy/venv/bin/python'
    if vim.uv.fs_stat(mason_debugpy) then return mason_debugpy end

    -- System fallback
    return 'python3'
  end

  require('dap-python').setup(find_debugpy_python())

  -- ── Python debug configurations ─────────────────────────────────
  -- Mirror Doom's dap-register-debug-template entries
  dap.configurations.python = dap.configurations.python or {}

  local python_configs = {
    {
      type = 'python',
      request = 'launch',
      name = 'Run file (buffer)',
      program = '${file}',
      console = 'integratedTerminal',
      justMyCode = false,
    },
    {
      type = 'python',
      request = 'launch',
      name = 'Run pytest (verbose)',
      module = 'pytest',
      args = { '-s', '-vv', '${file}' },
      console = 'integratedTerminal',
      justMyCode = false,
    },
    {
      type = 'python',
      request = 'launch',
      name = 'Run pytest (current function)',
      module = 'pytest',
      args = function()
        -- Detect the test function under cursor via treesitter
        local node = vim.treesitter.get_node()
        local func_name = nil
        while node do
          if node:type() == 'function_definition' then
            local name_node = node:field('name')[1]
            if name_node then func_name = vim.treesitter.get_node_text(name_node, 0) end
            break
          end
          node = node:parent()
        end
        if func_name then
          return { '-s', '-vv', '${file}::' .. func_name }
        end
        return { '-s', '-vv', '${file}' }
      end,
      console = 'integratedTerminal',
      justMyCode = false,
    },
    {
      type = 'python',
      request = 'launch',
      name = 'Run module (prompt)',
      module = function()
        return vim.fn.input('Module: ', '', 'file')
      end,
      console = 'integratedTerminal',
      justMyCode = false,
    },
    {
      type = 'python',
      request = 'attach',
      name = 'Attach to running process',
      connect = {
        host = '127.0.0.1',
        port = function()
          return tonumber(vim.fn.input('Port [5678]: ', '5678'))
        end,
      },
      pathMappings = {
        { localRoot = '${workspaceFolder}', remoteRoot = '.' },
      },
    },
  }

  for _, config in ipairs(python_configs) do
    table.insert(dap.configurations.python, config)
  end

  -- ── State listeners ─────────────────────────────────────────────
  dap.listeners.after.event_initialized['env_state'] = function()
    env.state._update('debug.active', true)
  end
  dap.listeners.after.event_terminated['env_state'] = function()
    env.state._update('debug.active', false)
  end
  dap.listeners.after.disconnect['env_state'] = function()
    env.state._update('debug.active', false)
  end
end

-- ── Module registration ───────────────────────────────────────────────

return env.module.register {
  name = 'debugging',
  domain = 'debugging',
  depends_on = { 'text_editing' },
  optional_deps = { 'workspace' },

  -- ── Plugin specs ──────────────────────────────────────────────────

  plugins = {
    -- nvim-dap: Debug Adapter Protocol client
    ['mfussenegger/nvim-dap'] = {
      dependencies = {
        'nvim-neotest/nvim-nio',
      },
      lazy = true,
    },

    -- nvim-dap-ui: UI panels (locals, watches, stacks, breakpoints, REPL, console)
    ['rcarriga/nvim-dap-ui'] = {
      dependencies = {
        'mfussenegger/nvim-dap',
        'nvim-neotest/nvim-nio',
      },
      lazy = true,
    },

    -- nvim-dap-python: Python debug adapter (debugpy) integration
    ['mfussenegger/nvim-dap-python'] = {
      dependencies = { 'mfussenegger/nvim-dap' },
      lazy = true,
    },

    -- nvim-dap-virtual-text: inline variable values during debugging
    ['theHamsta/nvim-dap-virtual-text'] = {
      dependencies = {
        'mfussenegger/nvim-dap',
        'nvim-treesitter/nvim-treesitter',
      },
      lazy = true,
    },

    -- NOTE: overseer.nvim is declared in modules/terminal.lua.
    -- DAP keymaps (SPC d t) call require('overseer') which triggers
    -- lazy-loading from the terminal module's spec.
  },

  -- ── Setup ─────────────────────────────────────────────────────────────
  -- Keymaps are registered eagerly (so which-key can discover them),
  -- but the actual DAP/UI initialisation is deferred to first use.

  setup = function()
    -- ── State provider ──────────────────────────────────────────────
    env.state.register_provider {
      id = 'debug.active',
      events = { 'User' },
      pattern = { 'DapStarted', 'DapTerminated' },
      collect = function()
        local ok, dap = pcall(require, 'dap')
        if not ok then return false end
        return dap.session() ~= nil
      end,
      desc = 'Whether a DAP debug session is active',
    }

    -- ── Keymaps (Doom SPC d prefix) ─────────────────────────────────
    local map = vim.keymap.set

    -- Helper: ensure DAP is ready then call fn
    local function D(fn)
      return function()
        ensure_dap_ready()
        fn()
      end
    end

    -- Session control
    map('n', '<leader>ds', D(function() require('dap').continue() end),  { desc = 'debug.start_continue', silent = true })
    map('n', '<leader>dc', D(function() require('dap').continue() end),  { desc = 'debug.continue', silent = true })
    map('n', '<leader>dn', D(function() require('dap').step_over() end), { desc = 'debug.step_over', silent = true })
    map('n', '<leader>di', D(function() require('dap').step_into() end), { desc = 'debug.step_into', silent = true })
    map('n', '<leader>do', D(function() require('dap').step_out() end),  { desc = 'debug.step_out', silent = true })
    map('n', '<leader>dr', D(function() require('dap').restart() end),   { desc = 'debug.restart', silent = true })
    map('n', '<leader>dl', D(function() require('dap').repl.open() end), { desc = 'debug.repl', silent = true })

    map('n', '<leader>dC', D(function()
      require('dap').terminate()
      require('dapui').close()
    end), { desc = 'debug.cleanup', silent = true })

    -- Run last/recent (mirrors Doom's ddr/ddl)
    map('n', '<leader>ddr', D(function() require('dap').run_last() end), { desc = 'debug.run_last', silent = true })

    -- Breakpoints (SPC d b prefix — mirrors Doom)
    map('n', '<leader>dbb', D(function() require('dap').toggle_breakpoint() end),
      { desc = 'debug.breakpoint_toggle', silent = true })
    map('n', '<leader>dbc', D(function()
      require('dap').set_breakpoint(vim.fn.input 'Condition: ')
    end), { desc = 'debug.breakpoint_condition', silent = true })
    map('n', '<leader>dbh', D(function()
      require('dap').set_breakpoint(nil, vim.fn.input 'Hit count: ')
    end), { desc = 'debug.breakpoint_hit_count', silent = true })
    map('n', '<leader>dbl', D(function()
      require('dap').set_breakpoint(nil, nil, vim.fn.input 'Log message: ')
    end), { desc = 'debug.breakpoint_log', silent = true })

    -- Eval (SPC d e prefix — mirrors Doom)
    map('n', '<leader>dee', D(function() require('dapui').eval(vim.fn.input 'Expression: ') end),
      { desc = 'debug.eval', silent = true })
    map('v', '<leader>dee', D(function() require('dapui').eval() end),
      { desc = 'debug.eval_visual', silent = true })
    map('n', '<leader>des', D(function() require('dapui').eval() end),
      { desc = 'debug.eval_at_cursor', silent = true })

    -- DAP UI toggle
    map('n', '<leader>du', D(function() require('dapui').toggle() end),
      { desc = 'debug.toggle_ui', silent = true })

    -- ── Overseer keymaps (SPC d t prefix) ───────────────────────────
    -- NOTE: main overseer keymaps live in terminal module (SPC t).
    -- These provide DAP-adjacent shortcuts under the SPC d prefix.
    map('n', '<leader>dt', function() require('overseer').run_template() end,
      { desc = 'debug.run_task', silent = true })
    map('n', '<leader>dT', function() require('overseer').toggle() end,
      { desc = 'debug.toggle_task_list', silent = true })
  end,
}
