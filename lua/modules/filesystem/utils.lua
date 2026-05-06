-- lua/modules/filesystem/utils.lua
-- Utility functions used for filesystem operations

-- TODO use the column.lua common file for this stuff
-- Format bytes into human readable string
local function format_size(bytes)
  if bytes < 1024 then return string.format('%dB', bytes) end
  if bytes < 1024 * 1024 then return string.format('%.1fK', bytes / 1024) end
  if bytes < 1024 * 1024 * 1024 then return string.format('%.1fM', bytes / (1024 * 1024)) end
  return string.format('%.1fG', bytes / (1024 * 1024 * 1024))
end

-- Format unix timestamp → "MMM DD HH:MM" like ls -l
local function format_time(ts) return os.date('%b %d %H:%M', ts) end

-- Format permissions bits like rwxr-xr-x
local function format_permissions(mode)
  -- mode is the st_mode from uv.fs_stat, extract lower 12 bits
  local m = mode % 4096
  local chars = {}
  local bits = { 256, 128, 64, 32, 16, 8, 4, 2, 1 }
  local labels = { 'r', 'w', 'x', 'r', 'w', 'x', 'r', 'w', 'x' }
  for i, bit in ipairs(bits) do
    table.insert(chars, (m % (bit * 2) >= bit) and labels[i] or '-')
  end
  return table.concat(chars)
end

-- Get icon + highlight group for an item
local function get_icon(item)
  local icons = require 'mini.icons'
  if item.is_cwd then return icons.get('default', 'default') end
  if item.is_dir then return icons.get('default', 'directory') end
  return icons.get('file', vim.fn.fnamemodify(item.path, ':t'))
end

-- Enrich an item with stat metadata
local function enrich_item(item)
  if item.is_cwd then
    item.icon, item.icon_hl = '', 'MiniPickNormal'
    item.permissions = '---------'
    item.size_str = '-'
    item.time_str = '-'
    return item
  end

  local stat = vim.uv.fs_stat(item.path)
  item.icon, item.icon_hl, _ = get_icon(item)

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

-- Build the display columns, returning line string + highlight regions
-- Format: <icon> <perms> <size> <time>  <name>
-- Describes one rendered column segment: its highlight group and the
-- string value that was written into that column (used to measure width).
---@class ColumnSpec
---@field hl      string   highlight group name
---@field value   string   the exact substring written to the buffer
---@field gap     integer  number of space chars appended AFTER this segment

local M = {}
-- Returns both the formatted line and an ordered list of ColumnSpecs so
-- that highlight ranges can be derived purely from segment lengths, with
-- no hardcoded magic offsets.
-- TODO we should get this from the cli instead
function M.format_item_line(item)
  local icon = item.icon or ''
  local perms = item.permissions or '---------'
  local size = item.size_str or '-'
  local time = item.time_str or '-'
  local name = item.display or item.text or ''

  -- Each segment is formatted to a fixed visual width via format directives,
  -- then stored verbatim so we can measure its byte length below.
  local icon_col = string.format('%-2s', icon) -- 2 cols: glyph + space
  local perms_col = string.format('%-9s', perms) -- 9 cols
  local size_col = string.format('%6s', size) -- 6 cols, right-aligned
  local time_col = string.format('%-12s', time) -- 12 cols

  local line = perms_col .. ' ' .. size_col .. '  ' .. time_col .. ' ' .. icon_col .. '  ' .. name

  ---@type ColumnSpec[]
  local cols = {
    { hl = 'Comment', value = perms_col, gap = 1 },
    { hl = 'Number', value = size_col, gap = 2 },
    { hl = 'Special', value = time_col, gap = 2 },
    { hl = item.icon_hl or 'MiniPickNormal', value = icon_col, gap = 1 },
    -- name segment has no gap (goes to end of line); hl resolved at call site
    { hl = item.is_dir and 'Directory' or 'MiniPickNormal', value = name, gap = 0 },
  }

  return line, cols
end

function M.explorer_show(buf_id, items_to_show, query)
  local ns = vim.api.nvim_create_namespace 'mini_pick_filebrowser'
  vim.api.nvim_buf_clear_namespace(buf_id, ns, 0, -1)

  -- First pass: build lines
  local lines = {}
  local all_cols = {} -- parallel array of ColumnSpec[] per item

  for _, item in ipairs(items_to_show) do
    local line, cols = M.format_item_line(item)
    table.insert(lines, line)
    table.insert(all_cols, cols)
  end

  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

  -- Second pass: highlights derived entirely from segment byte lengths
  for i, item in ipairs(items_to_show) do
    local row = i - 1
    local cursor = 0 -- byte offset into the line, advances as we consume segments

    for col_idx, seg in ipairs(all_cols[i]) do
      local seg_len = #seg.value -- byte length of this segment's content
      local seg_end = cursor + seg_len

      vim.hl.range(buf_id, ns, seg.hl, { row, cursor }, { row, seg_end })

      -- The last column is the name; apply match highlights within it
      local is_name_col = col_idx == #all_cols[i]
      if is_name_col then
        local name_start = cursor
        local display = item.display or item.text or ''

        for _, query_char in ipairs(query) do
          local s, e = display:find(vim.pesc(query_char), 1, true)
          if s then vim.hl.range(buf_id, ns, 'MiniPickMatchCurrent', { row, name_start + s - 1 }, { row, name_start + e }) end
        end
      end

      -- Advance past the segment content AND its trailing gap spaces
      cursor = seg_end + seg.gap
    end
  end
end

function M.find_files_at_show(buf_id, items_to_show, query)
  local ns = vim.api.nvim_create_namespace 'mini_pick_filebrowser'
  vim.api.nvim_buf_clear_namespace(buf_id, ns, 0, -1)

  local lines = {}
  local all_cols = {}

  for _, item in ipairs(items_to_show) do
    -- if item.is_header then
    --   -- Headers get their own simple line, no column formatting
    --   table.insert(lines, item.text)
    --   table.insert(all_cols, nil) -- placeholder so indices stay aligned
    -- else
    local line, cols = M.format_item_line(item)
    table.insert(lines, line)
    table.insert(all_cols, cols)
    -- end
  end

  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

  for i, item in ipairs(items_to_show) do
    local row = i - 1

    -- if item.is_header then
    --   -- Apply a single highlight across the whole header line
    --   vim.hl.range(
    --     buf_id,
    --     ns,
    --     'MiniPickHeader', -- define this in your colorscheme / highlights setup
    --     { row, 0 },
    --     { row, #item.text }
    --   )
    -- else
    local cols = all_cols[i]
    local cursor = 0

    for col_idx, seg in ipairs(cols) do
      local seg_len = #seg.value
      local seg_end = cursor + seg_len

      vim.hl.range(buf_id, ns, seg.hl, { row, cursor }, { row, seg_end })

      local is_name_col = col_idx == #cols
      if is_name_col then
        local name_start = cursor
        local display = item.display or item.text or ''

        for _, query_char in ipairs(query) do
          local s, e = display:find(vim.pesc(query_char), 1, true)
          if s then vim.hl.range(buf_id, ns, 'MiniPickMatchCurrent', { row, name_start + s - 1 }, { row, name_start + e }) end
        end
      end

      cursor = seg_end + seg.gap
    end
    -- end
  end
end

-- Recursively collect all files (not dirs) under a root path
function M.get_files_recursive(root, show_hidden)
  local results = {}

  local function walk(dir)
    local entries = vim.fn.readdir(dir)
    local dirs = {}
    local files = {}

    for _, name in ipairs(entries) do
      if show_hidden or name:sub(1, 1) ~= '.' then
        local full_path = dir .. '/' .. name
        local is_dir = vim.fn.isdirectory(full_path) == 1
        if is_dir then
          table.insert(dirs, { name = name, path = full_path })
        else
          table.insert(files, { name = name, path = full_path })
        end
      end
    end

    local alpha = function(a, b) return a.name:lower() < b.name:lower() end
    table.sort(dirs, alpha)
    table.sort(files, alpha)

    for _, f in ipairs(files) do
      table.insert(
        results,
        enrich_item {
          text = f.name,
          path = f.path,
          is_dir = false,
          is_cwd = false,
        }
      )
    end

    for _, d in ipairs(dirs) do
      walk(d.path)
    end
  end

  walk(root)
  return results
end

-- Takes a flat list of file items and groups them under directory header items.
-- Headers are inserted whenever the parent directory changes.
-- root is stripped from the front of paths for display brevity.
function M.group_files_as_tree(items, root)
  local grouped = {}
  local current_dir = nil

  -- Normalise root so we can strip it cleanly
  local root_prefix = root:gsub('/$', '') .. '/'

  for _, item in ipairs(items) do
    -- Derive the parent directory of this file
    local parent = item.path:match '(.+)/[^/]+$' or item.path

    if parent ~= current_dir then
      current_dir = parent

      -- Build a display path relative to root, fallback to full path
      local rel = parent:gsub('^' .. vim.pesc(root_prefix), '')
      if rel == parent then
        rel = parent -- nothing was stripped, keep full path
      end

      -- Insert a header item for this directory
      table.insert(
        grouped,
        enrich_item {
          text = rel .. '/',
          path = parent,
          is_dir = true,
          is_cwd = false,
          -- is_header = true, -- extra flag so the shower can style it differently
        }
      )
    end

    table.insert(grouped, item)
  end

  return grouped
end

function M.get_files_recursive_grouped(cwd, show_hidden)
  local flat = M.get_files_recursive(cwd, show_hidden)
  local grouped = M.group_files_as_tree(flat, cwd)
  return grouped
end

-- Get directory entries, injecting './' as first item
function M.get_files_in_dir(cwd, show_hidden)
  local items = {}

  table.insert(
    items,
    enrich_item {
      text = './',
      path = cwd,
      is_cwd = true,
      is_dir = true,
    }
  )

  local entries = vim.fn.readdir(cwd)
  local dirs = {}
  local files = {}

  for _, name in ipairs(entries) do
    if show_hidden or name:sub(1, 1) ~= '.' then
      local full_path = cwd .. '/' .. name
      local is_dir = vim.fn.isdirectory(full_path) == 1
      local item = enrich_item {
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

--- Check if a path is tracked/inside a git repo
---@param path string
---@return boolean is_git, boolean is_tracked
local function git_status(path)
  local dir = vim.fn.fnamemodify(path, ':h')

  vim.fn.system { 'git', '-C', dir, 'rev-parse', '--is-inside-work-tree' }
  if vim.v.shell_error ~= 0 then return false, false end

  vim.fn.system { 'git', '-C', dir, 'ls-files', '--error-unmatch', path }
  return true, vim.v.shell_error == 0
end

--- Delete a file, using git rm if tracked
---@param path string
function M.delete_path(path)
  local is_dir = vim.fn.isdirectory(path) == 1

  if is_dir then
    local is_git, _ = git_status(path)
    if is_git then
      local result = vim.fn.system { 'git', 'rm', '-rf', path }
      if vim.v.shell_error ~= 0 then vim.notify('git rm failed: ' .. result, vim.log.levels.ERROR) end
    else
      local ok = vim.fn.delete(path, 'rf')
      if ok ~= 0 then vim.notify('Failed to delete directory: ' .. path, vim.log.levels.ERROR) end
    end
  else
    local is_git, is_tracked = git_status(path)
    local normalized = vim.fn.fnamemodify(path, ':p')

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local buf_normalized = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':p')
        if buf_normalized == normalized then
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_buf(win) == buf then vim.api.nvim_win_call(win, function() vim.cmd.bnext() end) end
          end
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
    end

    if is_git and is_tracked then
      local result = vim.fn.system { 'git', 'rm', '--force', path }
      if vim.v.shell_error ~= 0 then vim.notify('git rm failed: ' .. result, vim.log.levels.ERROR) end
    else
      local ok = vim.fn.delete(path)
      if ok ~= 0 then vim.notify('Failed to delete: ' .. path, vim.log.levels.ERROR) end
    end
  end
end

--- Create a file, using git add if inside a git repo
---@param path string
function M.create_file(path)
  local ok, err = pcall(vim.fn.writefile, {}, path)
  if not ok then
    vim.notify('Failed to create file: ' .. err, vim.log.levels.ERROR)
    return
  end

  local is_git, _ = git_status(path)
  if is_git then
    local result = vim.fn.system { 'git', 'add', path }
    if vim.v.shell_error ~= 0 then vim.notify('git add failed: ' .. result, vim.log.levels.ERROR) end
  end
end

--- Check if a path is tracked/inside a git repo
---@param path string
---@param select_fun fun(opts: table|nil): nil
---@param select_fun_opts table:nil
---@return nil
function M.create_dwim(path, select_fun, select_fun_opts)
  vim.schedule(function()
    if path:match '%.[^./]+$' then
      M.create_file(path)
      vim.cmd.edit(path)
      local buf = vim.fn.bufadd(path)
      vim.bo[buf].buflisted = true
      vim.api.nvim_set_current_buf(buf)
    else
      local ok = vim.fn.mkdir(path, 'p')
      if ok == 0 then
        vim.notify('Failed to create directory: ' .. path, vim.log.levels.ERROR)
        return
      end
      local opts = vim.tbl_deep_extend('force', select_fun_opts, { cwd = path })
      select_fun(select_fun_opts)
    end
  end)
end

return M
