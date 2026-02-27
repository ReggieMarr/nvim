local M = {}

-- ============================================================================
-- PLUGIN DEPENDENCIES
-- ============================================================================
M.dependencies = {
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    cmd = { 'ToggleTerm', 'TermExec' },
    keys = {
      '<leader>ot',
      '<leader>oT',
      '<leader>tb',
      '<leader>tg',
      '<leader>td',
      '<leader>ts',
      '<leader>tS',
      '<leader>ti',
      '<C-\\>',
    },
  },
  -- Picker used for DWIM buffer switching (mirrors consult--read)
  {
    'nvim-telescope/telescope.nvim',
    optional = true,
  },
}

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local HORIZONTAL_SIZE = 18
local VERTICAL_SIZE = 60
local FLOAT_WIDTH = 0.85
local FLOAT_HEIGHT = 0.80

local ID = {
  BUILD = 1,
  GDB = 2,
  SERIAL = 3,
  LAZYGIT = 4,
  SCRATCH = 5,
}

-- ============================================================================
-- UTILITIES
-- ============================================================================
local function shell(override) return override or vim.o.shell end

local function detect_serial_device()
  local candidates = vim.fn.glob('/dev/ttyUSB*\n/dev/ttyACM*\n/dev/cu.usb*', false, true)
  return candidates[1] or '/dev/ttyUSB0'
end

-- ============================================================================
-- DWIM TERMINAL PICKER
-- ============================================================================
-- Mirrors:
--   (consult--buffer-query :include '("\\*.*vterm.*$"))
--   If results → consult--read picker
--   If no results → open a new terminal here
--
-- `pattern`  – lua pattern matched against buffer names
-- `open_fn`  – called when no existing terminal is found
-- `prompt`   – picker prompt string

local function dwim_terminal(pattern, open_fn, prompt)
  -- Collect matching terminal buffers (visible ones first, mirrors :sort 'visibility)
  local matches = {}
  local current = vim.api.nvim_get_current_buf()

  -- Visible (in a window) first
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match(pattern) and buf ~= current then
      table.insert(matches, { buf = buf, name = name, visible = true })
    end
  end

  -- Then hidden terminal buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal' then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:match(pattern) and buf ~= current then
        -- Avoid duplicates already added from visible pass
        local already = false
        for _, m in ipairs(matches) do
          if m.buf == buf then
            already = true
            break
          end
        end
        if not already then table.insert(matches, { buf = buf, name = name, visible = false }) end
      end
    end
  end

  -- No existing terminals → open a new one (mirrors (+vterm/here nil))
  if vim.tbl_isempty(matches) then
    open_fn()
    return
  end

  -- Exactly one match → jump straight to it (no picker needed)
  if #matches == 1 then
    vim.api.nvim_set_current_buf(matches[1].buf)
    vim.cmd 'startinsert'
    vim.notify('Switched to existing terminal', vim.log.levels.INFO, { title = 'terminal' })
    return
  end

  -- Multiple matches → show picker (mirrors consult--read)
  -- Try telescope first, fall back to vim.ui.select
  local names = vim.tbl_map(
    function(m) return (m.visible and '● ' or '○ ') .. vim.fn.fnamemodify(m.name, ':t') end,
    matches
  )

  local ok_telescope, _ = pcall(require, 'telescope')
  if ok_telescope then
    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    pickers
      .new({}, {
        prompt_title = prompt or 'Switch Terminal',
        finder = finders.new_table {
          results = matches,
          entry_maker = function(entry)
            return {
              value = entry,
              display = (entry.visible and '● ' or '○ ')
                .. vim.fn.fnamemodify(entry.name, ':t'),
              ordinal = entry.name,
            }
          end,
        },
        sorter = conf.generic_sorter {},
        attach_mappings = function(buf_nr)
          actions.select_default:replace(function()
            actions.close(buf_nr)
            local sel = action_state.get_selected_entry()
            if sel then
              vim.api.nvim_set_current_buf(sel.value.buf)
              vim.cmd 'startinsert'
            end
          end)
          return true
        end,
      })
      :find()
  else
    -- Fallback: vim.ui.select (mirrors consult--read minimally)
    vim.ui.select(names, { prompt = prompt or 'Switch Terminal: ' }, function(choice, idx)
      if not choice or not idx then return end
      vim.api.nvim_set_current_buf(matches[idx].buf)
      vim.cmd 'startinsert'
    end)
  end
end

-- ============================================================================
-- TOGGLETERM SETUP
-- ============================================================================
function M.setup_toggleterm()
  require('toggleterm').setup {
    size = function(term)
      if term.direction == 'horizontal' then
        return HORIZONTAL_SIZE
      elseif term.direction == 'vertical' then
        return VERTICAL_SIZE
      end
    end,
    shade_terminals = true,
    shading_factor = 2,
    start_in_insert = true,
    insert_mappings = true,
    terminal_mappings = true,
    persist_size = true,
    persist_mode = true,
    close_on_exit = true,
    auto_scroll = true,
    shell = shell(),

    float_opts = {
      border = 'rounded',
      width = math.floor(vim.o.columns * FLOAT_WIDTH),
      height = math.floor(vim.o.lines * FLOAT_HEIGHT),
      winblend = 5,
      zindex = 50,
      title_pos = 'center',
    },

    winbar = {
      enabled = true,
      name_formatter = function(term)
        local icons = {
          [ID.BUILD] = ' ',
          [ID.GDB] = ' ',
          [ID.SERIAL] = '󰈻 ',
          [ID.LAZYGIT] = ' ',
          [ID.SCRATCH] = ' ',
        }
        return (icons[term.id] or '  ') .. (term.display_name or term.name)
      end,
    },

    highlights = {
      Normal = { link = 'Normal' },
      NormalFloat = { link = 'NormalFloat' },
      FloatBorder = { link = 'FloatBorder' },
      StatusLine = { link = 'StatusLine' },
      StatusLineNC = { link = 'StatusLineNC' },
    },

    on_open = function(term)
      -- ── Appearance ──────────────────────────────────────────────────────
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.opt_local.signcolumn = 'no'
      vim.opt_local.foldcolumn = '0'
      vim.opt_local.spell = false

      local buf = term.bufnr

      -- ── Escape to normal mode ───────────────────────────────────────────
      vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { buffer = buf, desc = 'Term: Normal Mode' })
      vim.keymap.set('t', 'jk', [[<C-\><C-n>]], { buffer = buf, desc = 'Term: Normal Mode (jk)' })

      -- ── Window navigation ───────────────────────────────────────────────
      vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-w>h]], { buffer = buf, desc = 'Term: Win Left' })
      vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-w>j]], { buffer = buf, desc = 'Term: Win Down' })
      vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-w>k]], { buffer = buf, desc = 'Term: Win Up' })
      vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-w>l]], { buffer = buf, desc = 'Term: Win Right' })

      -- ── Scroll through history (mirrors vterm M-k / M-j) ────────────────
      -- In terminal mode: send the real up/down to the shell (history nav)
      vim.keymap.set(
        't',
        '<M-k>',
        function()
          vim.api.nvim_feedkeys(
            vim.api.nvim_replace_termcodes('<C-\\><C-n>k', true, false, true),
            'n',
            false
          )
        end,
        { buffer = buf, desc = 'Term: Scroll Up' }
      )

      vim.keymap.set(
        't',
        '<M-j>',
        function()
          vim.api.nvim_feedkeys(
            vim.api.nvim_replace_termcodes('<C-\\><C-n>j', true, false, true),
            'n',
            false
          )
        end,
        { buffer = buf, desc = 'Term: Scroll Down' }
      )

      -- In normal mode (while scrolling): M-j/k move by half-page
      vim.keymap.set('n', '<M-k>', '<C-u>', { buffer = buf, desc = 'Term: Page Up' })
      vim.keymap.set('n', '<M-j>', '<C-d>', { buffer = buf, desc = 'Term: Page Down' })
    end,

    on_close = function(_term) vim.cmd 'wincmd p' end,
  }
end

-- ============================================================================
-- NAMED TERMINAL DEFINITIONS
-- ============================================================================
local terminals = {}

local function get_terminal(id)
  if terminals[id] then return terminals[id] end
  local Terminal = require('toggleterm.terminal').Terminal

  local configs = {
    [ID.BUILD] = {
      id = ID.BUILD,
      display_name = 'build',
      direction = 'horizontal',
      on_open = function(term) term:send('cd ' .. vim.fn.getcwd(), false) end,
    },
    [ID.GDB] = {
      id = ID.GDB,
      display_name = 'debug',
      direction = 'vertical',
      cmd = vim.fn.executable 'probe-rs' == 1 and 'probe-rs debugger'
        or vim.fn.executable 'arm-none-eabi-gdb' == 1 and 'arm-none-eabi-gdb'
        or 'gdb',
      on_open = function(_term) vim.opt_local.wrap = false end,
    },
    [ID.SERIAL] = {
      id = ID.SERIAL,
      display_name = 'serial',
      direction = 'horizontal',
      cmd = M.make_serial_cmd(),
      close_on_exit = false,
    },
    [ID.LAZYGIT] = {
      id = ID.LAZYGIT,
      display_name = 'lazygit',
      cmd = 'lazygit',
      direction = 'float',
      hidden = true,
      float_opts = {
        border = 'rounded',
        width = math.floor(vim.o.columns * 0.95),
        height = math.floor(vim.o.lines * 0.92),
        zindex = 60,
      },
      on_open = function(term)
        -- lazygit manages its own keybinds – don't intercept <Esc>
        pcall(vim.keymap.del, 't', '<Esc>', { buffer = term.bufnr })
      end,
      on_close = function(_term) vim.cmd 'checktime' end,
    },
    [ID.SCRATCH] = {
      id = ID.SCRATCH,
      display_name = 'scratch',
      direction = 'float',
      hidden = true,
    },
  }

  local cfg = configs[id]
  if not cfg then
    vim.notify('terminal: unknown id ' .. id, vim.log.levels.ERROR)
    return nil
  end

  terminals[id] = Terminal:new(cfg)
  return terminals[id]
end

-- ============================================================================
-- SERIAL COMMAND BUILDER
-- ============================================================================
function M.make_serial_cmd(device, baud)
  device = device or detect_serial_device()
  baud = baud or 115200
  if vim.fn.executable 'tio' == 1 then
    return string.format('tio -b %d %s', baud, device)
  elseif vim.fn.executable 'picocom' == 1 then
    return string.format('picocom -b %d %s', baud, device)
  elseif vim.fn.executable 'minicom' == 1 then
    return string.format('minicom -b %d -D %s', baud, device)
  else
    vim.notify(
      'terminal: no serial client found (tio/picocom/minicom)',
      vim.log.levels.WARN,
      { title = 'terminal' }
    )
    return shell()
  end
end

function M.reconnect_serial(device, baud)
  local term = terminals[ID.SERIAL]
  if term then
    term:close()
    terminals[ID.SERIAL] = nil
  end
  local Terminal = require('toggleterm.terminal').Terminal
  terminals[ID.SERIAL] = Terminal:new {
    id = ID.SERIAL,
    display_name = 'serial',
    direction = 'horizontal',
    cmd = M.make_serial_cmd(device, baud),
    close_on_exit = false,
  }
  terminals[ID.SERIAL]:toggle()
end

-- ============================================================================
-- DWIM OPENERS  (mirrors my/open-term-dwim / my/open-shell-dwim)
-- ============================================================================

-- Open or pick an existing scratch (float) terminal
-- Mirrors: my/open-term-dwim → searches "*vterm*" buffers
function M.open_term_dwim()
  dwim_terminal(
    'term://', -- pattern: any terminal buffer
    function() get_terminal(ID.SCRATCH):toggle() end,
    'Switch Terminal'
  )
end

-- Open or pick an existing shell (horizontal) terminal
-- Mirrors: my/open-shell-dwim → searches "*shell*" buffers
function M.open_shell_dwim()
  dwim_terminal(
    'term://.*toggleterm#' .. ID.BUILD, -- pattern: build terminal specifically
    function() get_terminal(ID.BUILD):toggle() end,
    'Switch Shell'
  )
end

-- ============================================================================
-- KILL BUFFER (mirrors my/kill-buffer)
-- ============================================================================
-- Kill terminal buffers without any confirmation prompts,
-- behave normally for every other buffer type.
function M.kill_buffer()
  if vim.bo.buftype == 'terminal' then
    -- Force-kill: no "process still running?" prompt
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_delete(buf, { force = true })
  else
    vim.cmd 'bdelete'
  end
end

-- ============================================================================
-- TERMINAL IN CURRENT WINDOW
-- ============================================================================

-- Get the most recently used terminal buffer (if any exists)
local function get_last_term_buf()
  local last = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal' then
      -- Prefer the scratch terminal, fall back to any terminal
      if vim.api.nvim_buf_get_name(buf):match('toggleterm#' .. ID.SCRATCH) then return buf end
      last = buf
    end
  end
  return last
end

-- Open a terminal in the current window, or if already in a terminal,
-- swap it back to the last normal buffer.
-- Mirrors the Doom/evil "SPC '" or "C-`" toggle-in-place behaviour.
function M.toggle_term_in_current_window()
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_win = vim.api.nvim_get_current_win()
  local is_term = vim.bo[cur_buf].buftype == 'terminal'

  if is_term then
    -- ── We ARE in a terminal → go back to last normal buffer ─────────────
    -- Walk the buffer list backwards looking for a non-terminal buffer
    local bufs = vim.api.nvim_list_bufs()
    local target = nil

    -- First preference: alternate buffer (like C-^) if it's not a terminal
    local alt = vim.fn.bufnr '#'
    if
      alt ~= -1
      and vim.api.nvim_buf_is_valid(alt)
      and vim.bo[alt].buftype ~= 'terminal'
      and vim.bo[alt].buflisted
    then
      target = alt
    end

    -- Second preference: most recently used listed buffer
    if not target then
      for i = #bufs, 1, -1 do
        local b = bufs[i]
        if
          b ~= cur_buf
          and vim.api.nvim_buf_is_valid(b)
          and vim.bo[b].buftype ~= 'terminal'
          and vim.bo[b].buflisted
        then
          target = b
          break
        end
      end
    end

    if target then
      vim.api.nvim_win_set_buf(cur_win, target)
      vim.cmd 'stopinsert'
    else
      vim.notify('No normal buffer to return to', vim.log.levels.WARN, { title = 'terminal' })
    end
  else
    -- ── We are NOT in a terminal → bring one into this window ────────────
    -- Save this buffer as the "previous" so we can return to it
    local prev_buf = cur_buf

    local term_buf = get_last_term_buf()

    if term_buf then
      -- Reuse existing terminal buffer in place
      vim.api.nvim_win_set_buf(cur_win, term_buf)
      vim.cmd 'startinsert'
    else
      -- No terminal exists yet – open a new one in this window
      -- We use termopen() directly so it stays in the current split
      -- rather than opening a new one (toggleterm always splits)
      vim.cmd 'enew'
      local new_buf = vim.api.nvim_get_current_buf()
      vim.fn.termopen(shell(), {
        on_exit = function()
          -- mirrors vterm-kill-buffer-on-exit
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(new_buf) then
              -- Try to restore the previous buffer before wiping
              if vim.api.nvim_buf_is_valid(prev_buf) and vim.bo[prev_buf].buftype ~= 'terminal' then
                vim.api.nvim_win_set_buf(cur_win, prev_buf)
              end
              vim.api.nvim_buf_delete(new_buf, { force = true })
            end
          end)
        end,
      })
      -- Apply the same local options as toggleterm's on_open
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.opt_local.signcolumn = 'no'
      vim.opt_local.foldcolumn = '0'
      vim.opt_local.spell = false
      vim.opt_local.buflisted = false
      vim.opt_local.scrollback = 5000
      -- Keymaps on the new buffer
      local buf = vim.api.nvim_get_current_buf()
      vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { buffer = buf, desc = 'Term: Normal Mode' })
      vim.keymap.set(
        't',
        '<M-k>',
        function()
          vim.api.nvim_feedkeys(
            vim.api.nvim_replace_termcodes('<C-\\><C-n>k', true, false, true),
            'n',
            false
          )
        end,
        { buffer = buf, desc = 'Term: Scroll Up' }
      )
      vim.keymap.set(
        't',
        '<M-j>',
        function()
          vim.api.nvim_feedkeys(
            vim.api.nvim_replace_termcodes('<C-\\><C-n>j', true, false, true),
            'n',
            false
          )
        end,
        { buffer = buf, desc = 'Term: Scroll Down' }
      )
      vim.cmd 'startinsert'
    end
  end
end

-- Move the terminal that is open in another window into THIS window,
-- sending the other window back to its previous buffer.
-- Useful when a toggleterm split opened somewhere you didn't want.
function M.pull_term_here()
  local cur_win = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_get_current_buf()

  -- Find a window that contains a terminal (other than current)
  local term_win = nil
  local term_buf = nil

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= cur_win then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == 'terminal' then
        term_win = win
        term_buf = buf
        break
      end
    end
  end

  if not term_win then
    -- No terminal visible in another window – fall back to toggle-in-place
    vim.notify(
      'No terminal window found – opening one here instead',
      vim.log.levels.INFO,
      { title = 'terminal' }
    )
    M.toggle_term_in_current_window()
    return
  end

  -- Swap buffers between the two windows
  vim.api.nvim_win_set_buf(cur_win, term_buf)

  -- Send the other window back to a sensible buffer (our previous buffer
  -- if it's a normal one, otherwise whatever it had before)
  if vim.bo[cur_buf].buftype ~= 'terminal' and vim.bo[cur_buf].buflisted then
    vim.api.nvim_win_set_buf(term_win, cur_buf)
  else
    -- Just move it to any listed non-terminal buffer
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if
        buf ~= term_buf
        and vim.api.nvim_buf_is_valid(buf)
        and vim.bo[buf].buftype ~= 'terminal'
        and vim.bo[buf].buflisted
      then
        vim.api.nvim_win_set_buf(term_win, buf)
        break
      end
    end
  end

  vim.api.nvim_set_current_win(cur_win)
  vim.cmd 'startinsert'
end
-- ============================================================================
-- REMAINING HELPERS
-- ============================================================================
function M.toggle_gdb() get_terminal(ID.GDB):toggle() end
function M.toggle_lazygit() get_terminal(ID.LAZYGIT):toggle() end
function M.toggle_scratch() get_terminal(ID.SCRATCH):toggle() end

function M.run_build(cmd)
  local term = get_terminal(ID.BUILD)
  term:open()
  term:send(cmd, true)
end

function M.send_to_build(cmd)
  require('toggleterm').exec(cmd, ID.BUILD, HORIZONTAL_SIZE, vim.fn.getcwd(), 'horizontal')
end

function M.prompt_serial_config()
  vim.ui.input({ prompt = 'Serial device: ', default = detect_serial_device() }, function(device)
    if not device or device == '' then return end
    vim.ui.input({ prompt = 'Baud rate: ', default = '115200' }, function(baud)
      if not baud or baud == '' then return end
      M.reconnect_serial(device, tonumber(baud))
    end)
  end)
end

function M.show_terminal_status()
  local ok, list = pcall(require, 'toggleterm.terminal')
  if not ok then return end
  local lines = { 'Open terminals:' }
  for _, term in pairs(list.get_all(true)) do
    table.insert(
      lines,
      string.format(
        '  [%d] %-12s  dir=%-10s  cmd=%s',
        term.id,
        term.display_name or term.name,
        term.direction,
        term.cmd or vim.o.shell
      )
    )
  end
  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO, { title = 'terminal' })
end

-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================
function M.setup_autocmds()
  local augroup = vim.api.nvim_create_augroup('Terminal', { clear = true })

  -- Auto-insert when entering a terminal window
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    pattern = 'term://*',
    callback = function()
      if vim.bo.buftype == 'terminal' then vim.cmd 'startinsert' end
    end,
  })

  -- Keep terminal buffers out of the buffer list
  vim.api.nvim_create_autocmd('TermOpen', {
    group = augroup,
    pattern = '*',
    callback = function()
      vim.opt_local.buflisted = false
      -- mirrors (setq vterm-max-scrollback 5000)
      vim.opt_local.scrollback = 5000
    end,
  })

  -- Refit float terminals on editor resize
  vim.api.nvim_create_autocmd('VimResized', {
    group = augroup,
    callback = function()
      for _, term in pairs(terminals) do
        if term.direction == 'float' and term:is_open() then
          term:close()
          term:open()
        end
      end
    end,
  })

  -- mirrors (setq vterm-kill-buffer-on-exit t)
  vim.api.nvim_create_autocmd('TermClose', {
    group = augroup,
    pattern = 'term://*',
    callback = function(ev)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(ev.buf) then
          vim.api.nvim_buf_delete(ev.buf, { force = true })
        end
      end)
    end,
  })
end

-- ============================================================================
-- KEYMAPS
-- ============================================================================
function M.setup_keymaps()
  local map = vim.keymap.set

  -- ── Doom-style SPC o t / SPC o T ───────────────────────────────────────
  -- Mirrors:
  --   (map! :leader :prefix ("o") :desc "t" "t" #'my/open-term-dwim)
  --   (map! :leader :prefix ("o") :desc "T" "T" #'(+vterm/here nil))
  map('n', '<leader>ot', M.open_term_dwim, { desc = 'Term: DWIM (pick or open scratch)' })
  map('n', '<leader>oT', M.toggle_scratch, { desc = 'Term: Open New Scratch Here' })
  map('n', '<leader>os', M.open_shell_dwim, { desc = 'Term: DWIM (pick or open build shell)' })

  -- ── Kill buffer (mirrors my/kill-buffer) ────────────────────────────────
  map('n', '<leader>bk', M.kill_buffer, { desc = 'Kill Buffer (force if terminal)' })

  -- ── Named terminals ──────────────────────────────────────────────────────
  map('n', '<leader>tg', M.toggle_lazygit, { desc = 'Term: Lazygit' })
  map('n', '<leader>td', M.toggle_gdb, { desc = 'Term: Debugger' })
  map('n', '<leader>tS', M.prompt_serial_config, { desc = 'Term: Configure Serial' })
  map('n', '<leader>ti', M.show_terminal_status, { desc = 'Term: Status' })
  -- Toggle terminal in current window / swap back to last buffer
  -- Closest Neovim equivalent of Doom's SPC ' or C-`
  map(
    { 'n', 't' },
    '<M-`>',
    M.toggle_term_in_current_window,
    { desc = 'Term: Toggle in Current Window' }
  )

  -- Pull a terminal from another split into this window
  map('n', '<leader>tp', M.pull_term_here, { desc = 'Term: Pull Terminal Here' })
  -- ── Send text to build terminal ──────────────────────────────────────────
  map('v', '<leader>tv', function()
    local saved = vim.fn.getreg '"'
    vim.cmd 'normal! y'
    local text = vim.fn.getreg '"'
    vim.fn.setreg('"', saved)
    M.send_to_build(vim.trim(text))
  end, { desc = 'Term: Send Selection to Build' })

  map(
    'n',
    '<leader>tl',
    function() M.send_to_build(vim.api.nvim_get_current_line()) end,
    { desc = 'Term: Send Line to Build' }
  )
end

-- ============================================================================
-- MAIN SETUP
-- ============================================================================
function M.setup()
  M.setup_toggleterm()
  M.setup_autocmds()
  M.setup_keymaps()
end

return M
