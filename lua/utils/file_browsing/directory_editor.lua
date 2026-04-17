-- lua/file_browser/directory_editor.lua
-- dired-style file browser
local C = require 'utils.file_browsing.columns'

local M = {}

-- ── Stat cache ────────────────────────────────────────────────────────────────
-- mini.files calls prefix() and highlight() on every render cycle (including
-- cursor movement via MiniFilesWindowUpdate). Cache stat results per path to
-- avoid hammering uv.fs_stat on every cursor move.

local stat_cache = {}

local function get_stat(path)
  if stat_cache[path] == nil then
    stat_cache[path] = vim.uv.fs_stat(path) or false -- false = "checked, missing"
  end
  return stat_cache[path] or nil
end

-- Invalidate cache entries for paths affected by file action events so that
-- renames/moves/creates show fresh metadata on next render.
vim.api.nvim_create_autocmd('User', {
  pattern = {
    'MiniFilesActionCreate',
    'MiniFilesActionDelete',
    'MiniFilesActionRename',
    'MiniFilesActionCopy',
    'MiniFilesActionMove',
  },
  callback = function(ev)
    if ev.data.from then stat_cache[ev.data.from] = nil end
    if ev.data.to then stat_cache[ev.data.to] = nil end
  end,
})

-- Flush whole cache when explorer closes so stale entries don't accumulate
-- across sessions (e.g. external changes between opens).
vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniFilesExplorerClose',
  callback = function() stat_cache = {} end,
})

-- ── Normalise a mini.files fs_entry into our shared column format ─────────────

local function normalise_fs_entry(fs_entry)
  return {
    path = fs_entry.path,
    name = fs_entry.name,
    is_dir = fs_entry.fs_type == 'directory',
    stat = get_stat(fs_entry.path),
  }
end

-- ── Per-segment extmark highlights ───────────────────────────────────────────
-- mini.files renders prefix + name into the buffer then fires
-- MiniFilesBufferUpdate.  We walk every line and apply the same column
-- highlight ranges that custom_show applies in the picker, so both surfaces
-- are pixel-identical.

local hl_ns = vim.api.nvim_create_namespace 'file_browser_minifiles'

local function apply_line_highlights(buf_id)
  vim.api.nvim_buf_clear_namespace(buf_id, hl_ns, 0, -1)

  local line_count = vim.api.nvim_buf_line_count(buf_id)
  local MiniFiles = require 'mini.files'

  for lnum = 1, line_count do
    local fs_entry = MiniFiles.get_fs_entry(buf_id, lnum)
    if fs_entry then
      local entry = normalise_fs_entry(fs_entry)
      local row = lnum - 1
      local cursor = 0

      -- Walk the same ordered column specs as the picker.
      -- We derive the byte ranges from C.WIDTHS / C.GAPS — single source of truth.
      local segments = {
        { width = C.WIDTHS.icon, gap = C.GAPS.icon, hl = C.hl_icon(entry) },
        { width = C.WIDTHS.perms, gap = C.GAPS.perms, hl = 'Comment' },
        { width = C.WIDTHS.size, gap = C.GAPS.size, hl = 'Number' },
        { width = C.WIDTHS.time, gap = C.GAPS.time, hl = 'Special' },
      }

      for _, seg in ipairs(segments) do
        vim.hl.range(buf_id, hl_ns, seg.hl, { row, cursor }, { row, cursor + seg.width })
        cursor = cursor + seg.width + seg.gap
      end

      -- Name segment: cursor is now at NAME_COL, highlight to end of line.
      -- Use MiniFilesDirectory / MiniFilesFile to stay consistent with
      -- mini.files' own highlight groups rather than our picker groups.
      local name_hl = entry.is_dir and 'MiniFilesDirectory' or 'MiniFilesFile'
      vim.hl.range(buf_id, hl_ns, name_hl, { row, cursor }, { row, -1 })
    end
  end
end

vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniFilesBufferUpdate',
  callback = function(ev)
    -- ev.data.buf_id is the directory buffer that was just updated
    apply_line_highlights(ev.data.buf_id)
  end,
})

-- ── Window styling ────────────────────────────────────────────────────────────
-- Keep window chrome consistent with the picker's rounded borders.

vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniFilesWindowOpen',
  callback = function(ev)
    local win_id = ev.data.win_id
    vim.wo[win_id].winblend = 0
    local config = vim.api.nvim_win_get_config(win_id)
    config.border = 'rounded'
    config.title_pos = 'left'
    vim.api.nvim_win_set_config(win_id, config)
  end,
})

-- ── Buffer-local keymaps (MiniFilesBufferCreate) ──────────────────────────────

vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniFilesBufferCreate',
  callback = function(ev)
    local buf_id = ev.data.buf_id
    local MiniFiles = require 'mini.files'

    local function map(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = buf_id, desc = desc, nowait = true }) end

    -- ── Toggle hidden files (mirrors picker's <C-h>) ──────────────────────

    local show_hidden = false
    local filter_show = function(_) return true end
    local filter_hide = function(fs_entry) return not vim.startswith(fs_entry.name, '.') end

    map('<C-h>', function()
      show_hidden = not show_hidden
      MiniFiles.refresh { content = { filter = show_hidden and filter_show or filter_hide } }
    end, 'Toggle hidden files')

    -- ── Splits (mirrors picker's <C-v> / <C-x>) ───────────────────────────

    local function map_split(lhs, direction, desc)
      map(lhs, function()
        local state = MiniFiles.get_explorer_state()
        local target = state and state.target_window
        if not target or not vim.api.nvim_win_is_valid(target) then return end
        local new_target = vim.api.nvim_win_call(target, function()
          vim.cmd(direction .. ' split')
          return vim.api.nvim_get_current_win()
        end)
        MiniFiles.set_target_window(new_target)
        -- Immediately go in so the file opens in the new split
        MiniFiles.go_in { close_on_file = true }
      end, desc)
    end

    map_split('<C-v>', 'belowright vertical', 'Open in vsplit')
    map_split('<C-x>', 'belowright horizontal', 'Open in split')

    -- ── Tab open ──────────────────────────────────────────────────────────

    map('<C-t>', function()
      local fs_entry = MiniFiles.get_fs_entry()
      if not fs_entry or fs_entry.fs_type == 'directory' then return end
      MiniFiles.close()
      vim.schedule(function() vim.cmd('tabedit ' .. vim.fn.fnameescape(fs_entry.path)) end)
    end, 'Open in new tab')

    -- ── Yank path (mirrors picker's gy) ───────────────────────────────────

    map('gy', function()
      local fs_entry = MiniFiles.get_fs_entry()
      if not fs_entry then return end
      vim.fn.setreg(vim.v.register, fs_entry.path)
      vim.notify('Yanked: ' .. fs_entry.path, vim.log.levels.INFO, { title = 'mini.files' })
    end, 'Yank path')

    -- ── Set cwd to focused directory ──────────────────────────────────────

    map('g~', function()
      local fs_entry = MiniFiles.get_fs_entry()
      if not fs_entry then return end
      local dir = fs_entry.fs_type == 'directory' and fs_entry.path or vim.fs.dirname(fs_entry.path)
      vim.fn.chdir(dir)
      vim.notify('cwd: ' .. dir, vim.log.levels.INFO, { title = 'mini.files' })
    end, 'Set cwd')

    -- ── OS open (useful for images, PDFs, etc.) ───────────────────────────

    map('gX', function()
      local fs_entry = MiniFiles.get_fs_entry()
      if fs_entry then vim.ui.open(fs_entry.path) end
    end, 'OS open')
  end,
})

-- ── Bookmarks (MiniFilesExplorerOpen) ────────────────────────────────────────

vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniFilesExplorerOpen',
  callback = function()
    local MiniFiles = require 'mini.files'
    MiniFiles.set_bookmark('~', '~', { desc = 'Home' })
    MiniFiles.set_bookmark('w', vim.fn.getcwd, { desc = 'Working directory' })
    MiniFiles.set_bookmark('c', vim.fn.stdpath 'config', { desc = 'Neovim config' })
    MiniFiles.set_bookmark('d', vim.fn.stdpath 'data', { desc = 'Neovim data' })
  end,
})

-- Calculate the anchor point for the leftmost window so the whole
-- explorer panel appears centred. We don't know how many windows will
-- open, but we can centre on the focused (first) window as a reasonable
-- approximation, or reserve a fixed total width.

local TOTAL_WIDTH = math.floor(vim.o.columns * 0.85)
local TOTAL_HEIGHT = math.floor(vim.o.lines * 0.75)
local ROW_OFFSET = math.floor((vim.o.lines - TOTAL_HEIGHT) / 2)
local COL_OFFSET = math.floor((vim.o.columns - TOTAL_WIDTH) / 2)

vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniFilesWindowOpen',
  callback = function(ev)
    local win_id = ev.data.win_id
    local config = vim.api.nvim_win_get_config(win_id)
    config.border = 'rounded'
    config.title_pos = 'left'
    -- Anchor the very first window; mini.files positions subsequent
    -- windows relative to the first one automatically.
    config.row = ROW_OFFSET
    config.col = COL_OFFSET
    vim.api.nvim_win_set_config(win_id, config)
  end,
})

-- WindowUpdate fires after internal layout recalculation and will
-- overwrite row/col, so we must re-apply there too.
vim.api.nvim_create_autocmd('User', {
  pattern = 'MiniFilesWindowUpdate',
  callback = function(_ev)
    local MiniFiles = require 'mini.files'
    local state = MiniFiles.get_explorer_state()
    if not state or not state.windows or #state.windows == 0 then return end

    -- Recompute col for every window in the branch left-to-right,
    -- accumulating widths so each window is placed immediately after
    -- the previous one, all anchored to our COL_OFFSET.
    local col = COL_OFFSET

    for _, win_data in ipairs(state.windows) do
      local wid = win_data.win_id
      if vim.api.nvim_win_is_valid(wid) then
        local config = vim.api.nvim_win_get_config(wid)

        config.row = ROW_OFFSET
        config.col = col
        -- Clamp height so all columns are the same height
        config.height = TOTAL_HEIGHT

        vim.api.nvim_win_set_config(wid, config)

        -- Advance col by this window's width plus border columns (2 = left+right border)
        col = col + config.width + 2
      end
    end
  end,
})
-- ── Public open helper (called from choose_custom) ────────────────────────────

function M.open(path)
  -- use_latest=false so navigating to a directory from the picker always
  -- gives a fresh view of that specific path rather than restoring wherever
  -- the user was last time they opened mini.files at a different anchor.
  require('mini.files').open(path, false)
end

return M
