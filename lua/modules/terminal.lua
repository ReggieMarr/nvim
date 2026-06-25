-- lua/modules/terminal.lua
-- Terminal & task runner module.
--
-- Two concerns, one module:
--
-- 1. **Interactive terminals** (snacks.terminal)
--    DWIM toggle, named tools (lazygit), persistent sessions,
--    and all the terminal UX niceties (escape, window nav, scroll,
--    auto-kill, send-to-terminal).
--
-- 2. **Task runner** (overseer.nvim)
--    Auto-discovers tasks from Justfile, Makefile, Cargo.toml,
--    package.json, .vscode/tasks.json. Run, restart, list, and
--    pipe output to quickfix/diagnostics.
--
-- Keybindings:
--   ── Interactive terminals ──────────────────────
--   SPC o s  — DWIM terminal/shell (pick existing or open new)
--   SPC o S  — fresh terminal at project root
--   SPC g G  — lazygit (float)
--   M-`      — toggle last terminal in-place
--   C-`      — toggle last agent/terminal (float, from agents module)
--
--   ── Task runner (SPC t) ────────────────────────
--   SPC t t  — run task (picker: just/make/cargo/npm/etc)
--   SPC t r  — restart last task
--   SPC t l  — task list
--   SPC t o  — toggle task output
--   SPC t a  — run action on task
--   SPC t !  — run shell command as task
--   SPC t s  — toggle restart-on-save for last task
--   SPC t k  — stop running task
--   SPC t v  — send visual selection to terminal
--   SPC t L  — send current line to terminal
--
-- Domain: terminal

local env = require 'env'

return env.module.register {
  name = 'terminal',
  domain = 'terminal',
  depends_on = { 'interface' },
  optional_deps = { 'agents', 'workspace' },

  plugins = {
    ['stevearc/overseer.nvim'] = {
      opts = {
        -- Task list appears at the bottom — matches compilation buffer feel
        task_list = {
          direction = 'bottom',
          min_height = 8,
          max_height = { 20, 0.25 },
        },
        -- Build output goes to a terminal buffer (supports ANSI colors)
        output = {
          use_terminal = true,
          preserve_output = true,
        },
        -- Enable all built-in templates
        templates = {
          'builtin',
          'just',
          'make',
          'cargo',
          'npm',
          'tox',
          'mix',
          'rake',
          'deno',
          'vscode',
          'composer',
          'mage',
          'mise',
        },
      },
    },
  },

  setup = function()
    local snacks = require 'snacks'

    -- Ensure snacks.terminal is enabled
    snacks.config.terminal = { enabled = true }

    -- ════════════════════════════════════════════════════════════════
    -- UTILITIES
    -- ════════════════════════════════════════════════════════════════

    --- Resolve project root
    local function project_root()
      local root = env.state.get 'workspace.root'
      if root then return root end
      local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
      if vim.v.shell_error == 0 and git_root and git_root ~= '' then return git_root end
      return vim.fn.getcwd()
    end

    --- Track the "last" interactive terminal for M-` toggle
    local last_term_buf = nil

    --- Common terminal window options
    local function bottom_win(title)
      return {
        position = 'bottom',
        height   = 0.3,
        border   = 'top',
        title    = title and (' ' .. title .. ' ') or nil,
        title_pos = title and 'center' or nil,
      }
    end

    local function float_win(title, width, height)
      return {
        position  = 'float',
        border    = 'rounded',
        title     = title and (' ' .. title .. ' ') or nil,
        title_pos = title and 'center' or nil,
        width     = width or 0.85,
        height    = height or 0.85,
      }
    end

    -- ════════════════════════════════════════════════════════════════
    -- TERMINAL AUTOCMDS (UX niceties)
    -- ════════════════════════════════════════════════════════════════

    local augroup = vim.api.nvim_create_augroup('terminal_ux', { clear = true })

    -- Auto-enter insert mode when focusing a terminal buffer
    vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
      group    = augroup,
      pattern  = 'term://*',
      callback = function()
        if vim.bo.buftype == 'terminal' then
          vim.cmd 'startinsert'
        end
      end,
    })

    -- Clean up terminal appearance
    vim.api.nvim_create_autocmd('TermOpen', {
      group    = augroup,
      pattern  = '*',
      callback = function()
        vim.opt_local.number         = false
        vim.opt_local.relativenumber = false
        vim.opt_local.signcolumn     = 'no'
        vim.opt_local.foldcolumn     = '0'
        vim.opt_local.spell          = false
        vim.opt_local.statuscolumn   = ''
      end,
    })

    -- Auto-close terminal buffers on exit (mirrors vterm-kill-buffer-on-exit)
    vim.api.nvim_create_autocmd('TermClose', {
      group    = augroup,
      pattern  = 'term://*',
      callback = function(ev)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ev.buf) then
            local wins = vim.fn.win_findbuf(ev.buf)
            if #wins == 0 then
              vim.api.nvim_buf_delete(ev.buf, { force = true })
            end
          end
        end)
      end,
    })

    -- ════════════════════════════════════════════════════════════════
    -- TERMINAL KEYMAPS (apply to all terminal buffers)
    -- ════════════════════════════════════════════════════════════════

    vim.api.nvim_create_autocmd('TermOpen', {
      group    = augroup,
      pattern  = '*',
      callback = function()
        local buf = vim.api.nvim_get_current_buf()

        local function tmap(lhs, rhs, desc)
          vim.keymap.set('t', lhs, rhs, { buffer = buf, desc = desc, silent = true })
        end

        -- Escape to normal mode
        tmap('<Esc><Esc>', [[<C-\><C-n>]], 'terminal.normal_mode')

        -- Window navigation from terminal mode (mirrors Doom C-h/j/k/l)
        tmap('<C-h>', [[<C-\><C-n><C-w>h]], 'terminal.win_left')
        tmap('<C-j>', [[<C-\><C-n><C-w>j]], 'terminal.win_down')
        tmap('<C-k>', [[<C-\><C-n><C-w>k]], 'terminal.win_up')
        tmap('<C-l>', [[<C-\><C-n><C-w>l]], 'terminal.win_right')

        -- Scroll through terminal scrollback (mirrors vterm M-k/M-j)
        tmap('<M-k>', [[<C-\><C-n><C-u>]], 'terminal.scroll_up')
        tmap('<M-j>', [[<C-\><C-n><C-d>]], 'terminal.scroll_down')

        -- Track this as the last-used terminal
        last_term_buf = buf
      end,
    })

    -- ════════════════════════════════════════════════════════════════
    -- DWIM TERMINAL (mirrors Doom SPC o t)
    -- ════════════════════════════════════════════════════════════════

    --- Collect all terminal buffers, sorted: visible first, then hidden.
    local function collect_terminals()
      local current = vim.api.nvim_get_current_buf()
      local matches = {}
      local seen = {}

      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == 'terminal' and buf ~= current and not seen[buf] then
          seen[buf] = true
          table.insert(matches, { buf = buf, name = vim.api.nvim_buf_get_name(buf), visible = true })
        end
      end

      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf)
            and vim.bo[buf].buftype == 'terminal'
            and buf ~= current
            and not seen[buf]
        then
          seen[buf] = true
          table.insert(matches, { buf = buf, name = vim.api.nvim_buf_get_name(buf), visible = false })
        end
      end

      return matches
    end

    --- DWIM: if terminals exist -> pick one; otherwise open a new one.
    local function open_term_dwim()
      local matches = collect_terminals()

      if #matches == 0 then
        snacks.terminal.open(vim.o.shell, { cwd = project_root(), win = bottom_win() })
        return
      end

      if #matches == 1 then
        vim.api.nvim_set_current_buf(matches[1].buf)
        vim.cmd 'startinsert'
        return
      end

      vim.ui.select(matches, {
        prompt = 'Switch Terminal:',
        format_item = function(m)
          local indicator = m.visible and '  ' or '  '
          local name = vim.fn.fnamemodify(m.name, ':t')
          name = name:gsub('^term://', ''):gsub('//.*', '')
          if name == '' then name = '[terminal]' end
          return indicator .. name
        end,
      }, function(choice)
        if choice then
          vim.api.nvim_set_current_buf(choice.buf)
          vim.cmd 'startinsert'
        end
      end)
    end

    --- Open a fresh terminal at project root.
    local function open_term_new()
      snacks.terminal.open(vim.o.shell, { cwd = project_root(), win = bottom_win() })
    end

    -- ════════════════════════════════════════════════════════════════
    -- NAMED TOOL TERMINALS
    -- ════════════════════════════════════════════════════════════════

    local function toggle_lazygit()
      if vim.fn.executable 'lazygit' ~= 1 then
        vim.notify('lazygit is not installed', vim.log.levels.ERROR)
        return
      end
      snacks.terminal.toggle('lazygit', {
        cwd = project_root(),
        win = float_win('lazygit', 0.95, 0.92),
      })
    end

    -- ════════════════════════════════════════════════════════════════
    -- TOGGLE-IN-PLACE (M-` mirrors Doom SPC ' / C-`)
    -- ════════════════════════════════════════════════════════════════

    local function toggle_term_in_place()
      if vim.bo.buftype == 'terminal' then
        local alt = vim.fn.bufnr '#'
        if alt > 0 and vim.api.nvim_buf_is_valid(alt) and vim.bo[alt].buftype ~= 'terminal' then
          vim.api.nvim_set_current_buf(alt)
        else
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and vim.bo[buf].buftype ~= 'terminal' then
              vim.api.nvim_set_current_buf(buf)
              return
            end
          end
        end
      else
        if last_term_buf and vim.api.nvim_buf_is_valid(last_term_buf) and vim.bo[last_term_buf].buftype == 'terminal' then
          vim.api.nvim_set_current_buf(last_term_buf)
          vim.cmd 'startinsert'
        else
          snacks.terminal.toggle(vim.o.shell, { cwd = project_root(), win = bottom_win() })
        end
      end
    end

    -- ════════════════════════════════════════════════════════════════
    -- SEND TEXT TO TERMINAL
    -- ════════════════════════════════════════════════════════════════

    local function send_to_terminal(text)
      local target = last_term_buf
      if not (target and vim.api.nvim_buf_is_valid(target) and vim.bo[target].buftype == 'terminal') then
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].buftype == 'terminal' then
            target = buf
            break
          end
        end
      end

      if not target then
        vim.notify('No terminal buffer found — open one first', vim.log.levels.WARN)
        return
      end

      local chan = vim.bo[target].channel
      if chan and chan > 0 then
        vim.fn.chansend(chan, text .. '\n')
        local lines = select(2, text:gsub('\n', '\n')) + 1
        vim.notify(string.format('Sent %d line(s) to terminal', lines), vim.log.levels.INFO)
      else
        vim.notify('Terminal channel not available', vim.log.levels.ERROR)
      end
    end

    -- ════════════════════════════════════════════════════════════════
    -- OVERSEER SETUP (called once on first use)
    -- ════════════════════════════════════════════════════════════════

    local overseer_ready = false

    --- Registers :Make command and :OS abbreviation on first overseer use.
    local function ensure_overseer()
      if overseer_ready then return end
      overseer_ready = true

      local overseer = require 'overseer'

      -- :Make — async make (vim-dispatch style)
      vim.api.nvim_create_user_command('Make', function(params)
        local cmd, num_subs = vim.o.makeprg:gsub('%$%*', params.args)
        if num_subs == 0 then cmd = cmd .. ' ' .. params.args end
        overseer.new_task({
          cmd = vim.fn.expandcmd(cmd),
          cwd = project_root(),
          components = {
            { 'on_output_quickfix', open = not params.bang, open_height = 8, errorformat = vim.o.errorformat },
            'on_complete_notify',
            'default',
          },
        }):start()
      end, { desc = 'Async make (overseer)', nargs = '*', bang = true })

      -- :OS — shorthand for :OverseerShell
      vim.cmd.cnoreabbrev('OS', 'OverseerShell')
    end

    --- Wrap a function so overseer is loaded + setup before it runs.
    local function with_overseer(fn)
      return function()
        ensure_overseer()
        fn()
      end
    end

    -- ════════════════════════════════════════════════════════════════
    -- KEYMAPS
    -- ════════════════════════════════════════════════════════════════

    -- ── Interactive terminals ─────────────────────────────────────

    -- SPC o s - DWIM terminal/shell (Doom: SPC o t)
    vim.keymap.set('n', '<leader>os', open_term_dwim,
      { desc = 'terminal.dwim', silent = true })

    -- SPC o S - Fresh terminal at project root (Doom: SPC o T)
    vim.keymap.set('n', '<leader>oS', open_term_new,
      { desc = 'terminal.new', silent = true })

    -- SPC g G - Lazygit (float)
    vim.keymap.set('n', '<leader>gG', toggle_lazygit,
      { desc = 'git.lazygit', silent = true })

    -- M-` - Toggle terminal in place (Doom: SPC ' / C-`)
    vim.keymap.set({ 'n', 't' }, '<M-`>', toggle_term_in_place,
      { desc = 'terminal.toggle_in_place', silent = true })

    -- ── Send text to terminal ─────────────────────────────────────

    -- SPC t v - Send visual selection to terminal
    vim.keymap.set('v', '<leader>tv', function()
      local saved = vim.fn.getreg '"'
      local saved_type = vim.fn.getregtype '"'
      vim.cmd 'normal! y'
      local text = vim.fn.getreg '"'
      vim.fn.setreg('"', saved, saved_type)
      send_to_terminal(vim.trim(text))
    end, { desc = 'terminal.send_selection', silent = true })

    -- SPC t L - Send current line to terminal
    vim.keymap.set('n', '<leader>tL', function()
      send_to_terminal(vim.api.nvim_get_current_line())
    end, { desc = 'terminal.send_line', silent = true })

    -- ── Overseer task keymaps ─────────────────────────────────────

    -- SPC t t - Run task (picks from Justfile/Makefile/cargo/npm/etc)
    vim.keymap.set('n', '<leader>tt', with_overseer(function()
      require('overseer').run_task()
    end), { desc = 'tasks.run', silent = true })

    -- SPC t r - Restart last task
    vim.keymap.set('n', '<leader>tr', with_overseer(function()
      local overseer = require 'overseer'
      local tasks = overseer.list_tasks { recent_first = true }
      if vim.tbl_isempty(tasks) then
        vim.notify('No tasks to restart', vim.log.levels.WARN)
      else
        overseer.run_action(tasks[1], 'restart')
      end
    end), { desc = 'tasks.restart_last', silent = true })

    -- SPC t l - Task list (see all running/completed tasks)
    vim.keymap.set('n', '<leader>tl', with_overseer(function()
      require('overseer').toggle { direction = 'bottom' }
    end), { desc = 'tasks.list', silent = true })

    -- SPC t o - Toggle task output (most recent)
    vim.keymap.set('n', '<leader>to', with_overseer(function()
      local overseer = require 'overseer'
      local tasks = overseer.list_tasks { recent_first = true }
      if not vim.tbl_isempty(tasks) then
        overseer.run_action(tasks[1], 'open float')
      else
        vim.notify('No tasks', vim.log.levels.INFO)
      end
    end), { desc = 'tasks.output', silent = true })

    -- SPC t a - Run action on a task
    vim.keymap.set('n', '<leader>ta', with_overseer(function()
      vim.cmd 'OverseerTaskAction'
    end), { desc = 'tasks.action', silent = true })

    -- SPC t ! - Run shell command as a tracked task
    vim.keymap.set('n', '<leader>t!', with_overseer(function()
      vim.ui.input({ prompt = 'Task command: ' }, function(cmd)
        if not cmd or cmd == '' then return end
        require('overseer').new_task({
          cmd = cmd,
          cwd = project_root(),
          components = {
            { 'on_output_quickfix', open = true },
            'on_complete_notify',
            'default',
          },
        }):start()
      end)
    end), { desc = 'tasks.shell_command', silent = true })

    -- SPC t s - Toggle restart-on-save (watch mode)
    vim.keymap.set('n', '<leader>ts', with_overseer(function()
      local overseer = require 'overseer'
      local tasks = overseer.list_tasks { recent_first = true }
      if vim.tbl_isempty(tasks) then
        vim.notify('No tasks to watch', vim.log.levels.WARN)
        return
      end
      local task = tasks[1]
      if task:has_component 'restart_on_save' then
        task:remove_component 'restart_on_save'
        vim.notify('Watch OFF: ' .. task.name, vim.log.levels.INFO)
      else
        task:add_component { 'restart_on_save', paths = { project_root() } }
        vim.notify('Watch ON: ' .. task.name .. ' (restarts on save)', vim.log.levels.INFO)
      end
    end), { desc = 'tasks.toggle_watch', silent = true })

    -- SPC t k - Stop running task
    vim.keymap.set('n', '<leader>tk', with_overseer(function()
      local overseer = require 'overseer'
      local tasks = overseer.list_tasks { status = { overseer.STATUS.RUNNING } }
      if vim.tbl_isempty(tasks) then
        vim.notify('No running tasks', vim.log.levels.INFO)
        return
      end
      if #tasks == 1 then
        tasks[1]:stop()
        return
      end
      vim.ui.select(tasks, {
        prompt = 'Stop task:',
        format_item = function(t) return t.name end,
      }, function(task)
        if task then task:stop() end
      end)
    end), { desc = 'tasks.stop', silent = true })

    -- ── Display registrations ─────────────────────────────────────
    env.display.register {
      id     = 'terminal.interactive',
      kind   = 'split',
      module = 'terminal',
      desc   = 'Interactive terminal (DWIM, named tools)',
    }

    env.display.register {
      id     = 'terminal.tasks',
      kind   = 'split',
      module = 'terminal',
      desc   = 'Overseer task runner (just/make/cargo/npm)',
    }
  end,
}
