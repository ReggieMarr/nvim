-- lua/modules/agents.lua
-- AI coding agent module: terminal-based integration for pi and claude code.
--
-- Provides persistent, togglable terminal sessions for each agent so you
-- can flip between your editor and an agent conversation without losing
-- state.  Agents are launched inside snacks.terminal which handles:
--   - auto-insert mode on focus
--   - window chrome (border, title)
--   - lifecycle (the terminal persists across toggles)
--
-- pi  uses personal tokens (already configured in the shell environment).
-- claude code uses the corporate Anthropic account.
--
-- Keybindings follow the Doom "SPC o" (open) convention:
--   SPC a a  — toggle last-used agent
--   SPC a p  — toggle pi
--   SPC a c  — toggle claude code
--   SPC a t  — toggle a plain terminal
--   SPC a s  — send visual selection to the active agent
--
-- Domain: agents

local env = require 'env'

return env.module.register {
  name = 'agents',
  domain = 'agents',
  depends_on = { 'interface' },
  optional_deps = {},

  plugins = {},

  setup = function()
    local snacks = require 'snacks'

    -- Enable snacks.terminal now that we need it
    snacks.config.terminal = { enabled = true }

    -- ── Agent definitions ───────────────────────────────────────────
    -- Each agent is a table with:
    --   cmd       — shell command to launch
    --   cwd_fn    — function returning the working directory (default: project root or cwd)
    --   env       — optional extra environment variables
    --   available — function returning whether the binary exists

    --- Resolve project root: workspace state > git root > cwd
    local function project_root()
      local root = env.state.get 'workspace.root'
      if root then return root end
      local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
      if vim.v.shell_error == 0 and git_root and git_root ~= '' then return git_root end
      return vim.fn.getcwd()
    end

    local agents = {
      pi = {
        cmd       = 'pi',
        cwd_fn    = project_root,
        available = function() return vim.fn.executable('pi') == 1 end,
      },
      claude = {
        cmd       = 'claude',
        cwd_fn    = project_root,
        available = function() return vim.fn.executable('claude') == 1 end,
      },
      terminal = {
        cmd       = vim.o.shell,
        cwd_fn    = project_root,
        available = function() return true end,
      },
    }

    -- Track last-used agent for quick toggle
    local last_agent = nil

    -- ── Terminal cache ──────────────────────────────────────────────
    -- Snacks.terminal uses the cmd string as a key for persistence.
    -- Calling toggle() with the same cmd re-opens the existing session.

    --- Open or toggle an agent terminal.
    ---@param name string  Key into the agents table
    local function toggle_agent(name)
      local agent = agents[name]
      if not agent then
        vim.notify('agents: unknown agent "' .. name .. '"', vim.log.levels.ERROR)
        return
      end
      if not agent.available() then
        vim.notify(
          string.format('agents: "%s" is not installed (command: %s)', name, agent.cmd),
          vim.log.levels.ERROR
        )
        return
      end

      last_agent = name

      local cwd = agent.cwd_fn and agent.cwd_fn() or vim.fn.getcwd()

      snacks.terminal.toggle(agent.cmd, {
        cwd = cwd,
        env = agent.env,
        interactive = true,
        win = {
          position = 'float',
          border   = 'rounded',
          title    = ' ' .. name .. ' ',
          title_pos = 'center',
          width    = 0.85,
          height   = 0.85,
        },
      })
    end

    --- Send visual selection text to the currently visible agent terminal.
    local function send_selection_to_agent()
      -- Get visual selection
      local start_pos = vim.fn.getpos("'<")
      local end_pos   = vim.fn.getpos("'>")
      local lines = vim.fn.getregion(start_pos, end_pos, { type = vim.fn.visualmode() })
      if not lines or #lines == 0 then
        vim.notify('agents: no selection', vim.log.levels.WARN)
        return
      end
      local text = table.concat(lines, '\n')

      -- Find the agent terminal buffer
      local target_agent = last_agent or 'pi'
      local agent = agents[target_agent]
      if not agent then return end

      -- Look for an existing terminal buffer running this agent
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buftype == 'terminal' then
          local buf_name = vim.api.nvim_buf_get_name(buf)
          if buf_name:find(agent.cmd, 1, true) then
            -- Found it — send the text
            local chan = vim.bo[buf].channel
            if chan and chan > 0 then
              vim.fn.chansend(chan, text .. '\n')
              vim.notify(string.format('Sent %d lines to %s', #lines, target_agent), vim.log.levels.INFO)
              return
            end
          end
        end
      end

      vim.notify(
        string.format('agents: no active %s terminal found — open one first with <leader>a%s',
          target_agent, target_agent:sub(1, 1)),
        vim.log.levels.WARN
      )
    end

    -- ── Keymaps ─────────────────────────────────────────────────────

    vim.keymap.set('n', '<leader>ap', function() toggle_agent('pi') end,
      { desc = 'agent.pi', silent = true })

    vim.keymap.set('n', '<leader>ac', function() toggle_agent('claude') end,
      { desc = 'agent.claude_code', silent = true })

    vim.keymap.set('n', '<leader>at', function() toggle_agent('terminal') end,
      { desc = 'agent.terminal', silent = true })

    vim.keymap.set('n', '<leader>aa', function()
      toggle_agent(last_agent or 'pi')
    end, { desc = 'agent.toggle_last', silent = true })

    vim.keymap.set('v', '<leader>as', function()
      -- Exit visual mode first so '< and '> marks are set
      vim.cmd 'normal! '
      send_selection_to_agent()
    end, { desc = 'agent.send_selection', silent = true })

    -- Global toggle with C-` (terminal muscle memory)
    vim.keymap.set({ 'n', 't' }, '<C-`>', function()
      toggle_agent(last_agent or 'terminal')
    end, { desc = 'agent.toggle', silent = true })

    -- Terminal mode: easy escape back to normal mode
    vim.keymap.set('t', '<C-\\><C-n>', '<C-\\><C-n>', { desc = 'terminal.escape' })
    vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'terminal.escape' })

    -- ── Display registration ────────────────────────────────────────
    env.display.register {
      id     = 'agents.terminal',
      kind   = 'float',
      module = 'agents',
      desc   = 'Floating terminal for AI coding agents (pi, claude code)',
    }
  end,
}
