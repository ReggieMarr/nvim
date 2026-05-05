-- lua/file_browser/picker_minibuffer.lua
-- Vertico-style file browser using minibuffer.nvim
-- Lightweight and minimal compared to the mini.pick version

local M = {}

-- ============================================================================
-- Formatting & Utilities
-- ============================================================================

local function format_size(bytes)
  if bytes < 1024 then return string.format('%dB', bytes) end
  if bytes < 1024 * 1024 then return string.format('%.1fK', bytes / 1024) end
  if bytes < 1024 * 1024 * 1024 then return string.format('%.1fM', bytes / (1024 * 1024)) end
  return string.format('%.1fG', bytes / (1024 * 1024 * 1024))
end

local function format_time(ts) return os.date('%b %d %H:%M', ts) end

local function format_permissions(mode)
  local m = mode % 4096
  local chars = {}
  local bits = { 256, 128, 64, 32, 16, 8, 4, 2, 1 }
  local labels = { 'r', 'w', 'x', 'r', 'w', 'x', 'r', 'w', 'x' }
  for i, bit in ipairs(bits) do
    table.insert(chars, (m % (bit * 2) >= bit) and labels[i] or '-')
  end
  return table.concat(chars)
end

local function get_icon(path, is_dir)
  local ok, mini_icons = pcall(require, 'mini.icons')
  if not ok then return '', 'Normal' end

  if is_dir then
    return mini_icons.get('default', 'directory')
  else
    return mini_icons.get('file', vim.fn.fnamemodify(path, ':t'))
  end
end

local function enrich_item(item)
  if item.is_cwd then
    item.icon, item.icon_hl = '', 'Normal'
    item.permissions = '---------'
    item.size_str = '-'
    item.time_str = '-'
    return item
  end

  local stat = vim.uv.fs_stat(item.path)
  item.icon, item.icon_hl = get_icon(item.path, item.is_dir)

  if stat then
    item.permissions = format_permissions(stat.mode)
    item.size_str = item.is_dir and '-' or format_size(stat.size)
    item.time_str = format_time(stat.mtime.sec)
  else
    item.permissions = '---------'
    item.size_str = '?'
    item.time_str = '?'
  end

  return item
end

-- Format a single line with highlight chunks
-- Returns: { {text, hl}, {text, hl}, ... }
local function format_item(item)
  local icon_col = string.format('%-2s', item.icon or '')
  local perms_col = string.format('%-9s', item.permissions or '---------')
  local size_col = string.format('%6s', item.size_str or '-')
  local time_col = string.format('%-12s', item.time_str or '-')

  return {
    { text = ' ' .. perms_col, hl = 'Comment' },
    { text = ' ' .. size_col, hl = 'Number' },
    { text = '  ' .. time_col, hl = 'Special' },
    { text = ' ' .. icon_col, hl = item.icon_hl or 'Normal' },
    { text = ' ' .. (item.text or ''), hl = item.is_dir and 'Directory' or 'Normal' },
  }
end

local function get_entries(cwd)
  local items = {}
  local item_id = 1

  table.insert(
    items,
    enrich_item {
      id = item_id,
      text = './',
      path = cwd,
      is_cwd = true,
      is_dir = true,
    }
  )
  item_id = item_id + 1

  local entries = vim.fn.readdir(cwd)
  local dirs = {}
  local files = {}

  local show_hidden = true
  for _, name in ipairs(entries) do
    if show_hidden or name:sub(1, 1) ~= '.' then
      local full_path = cwd .. '/' .. name
      local is_dir = vim.fn.isdirectory(full_path) == 1
      local item = enrich_item {
        id = item_id,
        text = is_dir and (name .. '/') or name,
        path = full_path,
        is_dir = is_dir,
        is_cwd = false,
      }
      if is_dir then
        table.insert(dirs, item)
      else
        table.insert(files, item)
      end
      item_id = item_id + 1
    end
  end

  local alpha = function(a, b) return a.text:lower() < b.text:lower() end
  table.sort(dirs, alpha)
  table.sort(files, alpha)

  for _, item in ipairs(dirs) do
    table.insert(items, item)
  end
  for _, item in ipairs(files) do
    table.insert(items, item)
  end

  return items
end

local function create_file(path)
  local dir = vim.fn.fnamemodify(path, ':h')
  vim.fn.mkdir(dir, 'p')
  local ok, err = pcall(vim.fn.writefile, {}, path)
  if not ok then
    vim.notify('Failed to create file: ' .. err, vim.log.levels.ERROR)
    return false
  end
  return true
end

local function create_directory(path)
  local ok = vim.fn.mkdir(path, 'p')
  if ok == 0 then
    vim.notify('Failed to create directory: ' .. path, vim.log.levels.ERROR)
    return false
  end
  return true
end

-- ============================================================================
-- Main File Browser - minibuffer version
-- ============================================================================

function M.find_file_at(cwd)
  print('cwd receieved: %s', cwd)
  show_hidden = true
  local minibuffer = require 'minibuffer'

  local function navigate_to(dir)
    minibuffer.get_active_session():close()
    vim.schedule(function() M.find_file_at(dir, show_hidden) end)
  end

  local function navigate_up()
    local parent = vim.fn.fnamemodify(cwd, ':h')
    if parent ~= cwd then navigate_to(parent) end
  end

  -- Simple fuzzy filter (substring match)
  local function filter_fn(items, input)
    if input == '' then return items end

    local results = {}
    for _, item in ipairs(items) do
      if item.text:lower():find(input:lower(), 1, true) then table.insert(results, item) end
    end
    return results
  end

  local function on_select(selection)
    if not selection or #selection == 0 then return end

    local item = selection[1]
    if not item then return end

    -- Current dir → open directory editor
    if item.is_cwd then
      vim.schedule(function() require('utils.file_browsing.directory_editor').open(item.path) end)
      return
    end

    -- Directory → navigate into it
    if item.is_dir then
      navigate_to(item.path)
      return
    end

    -- File → open it
    vim.cmd.edit(item.path)
  end

  minibuffer.select {
    resumable = true,
    prompt = 'Mini Find: ' .. vim.fn.fnamemodify(cwd, ':~'),
    items = get_entries(cwd),
    format_fn = format_item,
    filter_fn = filter_fn,
    async_fetch = get_entries,
    max_height = 12,
    allow_shrink = true,
    on_select = on_select,
    on_start = function(buf, sess, keyset)
      -- Navigate up (backspace when query is empty)
      -- keyset('i', '<BS>', function()
      --   if sess.input == '' then
      --     navigate_up()
      --   else
      --     -- Let default backspace behavior work
      --     vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-h>', true, false, true), 'i', true)
      --   end
      -- end, { buffer = buf, noremap = true, silent = true })

      -- Toggle hidden files
      keyset('i', '<C-h>', function()
        local show_hidden = not show_hidden
        sess.items = get_entries(cwd)
        sess.filtered_items = filter_fn(sess.items, sess.input)
        sess.current_index = math.min(sess.current_index, #sess.filtered_items)
        sess:render()
      end, { buffer = buf, noremap = true, silent = true })
    end,
  }
end

return M
