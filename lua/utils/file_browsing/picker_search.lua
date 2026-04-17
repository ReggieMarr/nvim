-- lua/file_browser/picker_search.lua
-- Vertico-style file browser

local M = {}

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

-- Returns both the formatted line and an ordered list of ColumnSpecs so
-- that highlight ranges can be derived purely from segment lengths, with
-- no hardcoded magic offsets.
local function format_item_line(item)
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

local function custom_show(buf_id, items_to_show, query)
  local ns = vim.api.nvim_create_namespace 'mini_pick_filebrowser'
  vim.api.nvim_buf_clear_namespace(buf_id, ns, 0, -1)

  -- First pass: build lines
  local lines = {}
  local all_cols = {} -- parallel array of ColumnSpec[] per item

  for _, item in ipairs(items_to_show) do
    local line, cols = format_item_line(item)
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

-- Get directory entries, injecting './' as first item
local function get_entries(cwd, show_hidden)
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

function M.find_file_at(cwd, show_hidden)
  cwd = vim.fn.resolve(vim.fn.expand(cwd or vim.fn.getcwd()))
  show_hidden = show_hidden or false
  local MiniPick = require 'mini.pick'

  -- Restart picker at a new directory
  local function navigate_to(dir)
    MiniPick.stop()
    vim.schedule(function() M.find_file_at(dir, show_hidden) end)
  end

  local function navigate_up()
    local parent = vim.fn.fnamemodify(cwd, ':h')
    if parent ~= cwd then navigate_to(parent) end
  end

  local function choose_custom(item)
    if not item then return end

    -- Current dir item → open in oil float at this directory
    if item.is_cwd then
      MiniPick.stop()
      vim.schedule(function() require('utils.file_browsing.directory_editor').open(item.path) end)
      return
    end

    -- Directory → navigate into it
    if item.is_dir then
      navigate_to(item.path)
      return
    end

    -- File → open it in target window
    local target_win = MiniPick.get_picker_state().windows.target
    vim.api.nvim_win_call(target_win, function() vim.cmd.edit(item.path) end)
    MiniPick.stop()
  end

  MiniPick.start {
    source = {
      name = 'Find: ' .. vim.fn.fnamemodify(cwd, ':~'),
      cwd = cwd,
      items = get_entries(cwd, show_hidden),
      show = custom_show,
      choose = choose_custom,

      preview = function(buf_id, item)
        if not item then return end
        if item.is_dir then
          -- Show directory listing as preview
          local entries = vim.fn.readdir(item.path)
          local lines = {}
          for _, name in ipairs(entries) do
            local full = item.path .. '/' .. name
            local suffix = vim.fn.isdirectory(full) == 1 and '/' or ''
            table.insert(lines, name .. suffix)
          end
          table.sort(lines)
          vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
        else
          -- Default file preview
          MiniPick.default_preview(buf_id, item)
        end
      end,
    },

    mappings = {
      -- NOTE we need to disable the built-in first otherwise we'll get a warning
      delete_char = '',
      -- Backspace: go up if query empty, else delete char
      dwim_backspace = {
        char = '<BS>',
        func = function()
          local query = MiniPick.get_picker_query()
          if #query == 0 then
            navigate_up()
          else
            -- Remove last character from query
            local new_query = vim.list_slice(query, 1, #query - 1)
            MiniPick.set_picker_query(new_query)
          end
        end,
      },
      choose = '',

      dwim_choose = {
        char = '<CR>',
        func = function()
          local matches = MiniPick.get_picker_matches()
          local item = matches and matches.current

          if item then
            -- Delegate to your normal choose logic (extracted to a function)
            return choose_custom(item)
          end

          -- No item matched → create from query
          local query_str = table.concat(MiniPick.get_picker_query())
          print(query_str)
          local name = query_str
          if name == '' then return end

          MiniPick.stop()
          vim.schedule(function()
            if query_str:match '%.[^./]+$' then
              if create_file(query_str) then vim.cmd.edit(query_str) end
            else
              if create_directory(query_str) then find_file_at(query_str, show_hidden) end
            end
          end)
          return true
        end,
      },
      move_down = '',
      -- Tab: navigate into selected dir (or open file)
      navigate_in = {
        char = '<Tab>',
        func = function()
          local item = MiniPick.get_picker_matches().current
          choose_custom(item)
          return true
        end,
      },

      -- Toggle hidden files
      scroll_left = '',
      toggle_hidden = {
        char = '<C-h>',
        func = function()
          show_hidden = not show_hidden
          MiniPick.set_picker_items(get_entries(cwd, show_hidden))
        end,
      },

      -- Create file/directory from current query (vertico-style)
      create = {
        char = '<C-n>',
        func = function()
          local query = table.concat(MiniPick.get_picker_query())
          if query == '' then return end

          local target = cwd .. '/' .. query
          MiniPick.stop()
          vim.schedule(function()
            if query:match '%.[^./]+$' ~= nil then
              -- Has extension → create file and open
              if create_file(target) then vim.cmd.edit(target) end
            else
              -- No extension → create directory and navigate into it
              if create_directory(target) then find_file_at(target, show_hidden) end
            end
          end)
          return true
        end,
      },

      -- Disable built-in that typically uses C-t
      choose_in_tabpage = '',
    },

    window = {
      config = function()
        local height = math.floor(0.618 * vim.o.lines)
        local width = math.floor(0.618 * vim.o.columns)
        return {
          anchor = 'NW',
          height = height,
          width = width,
          row = math.floor(0.5 * (vim.o.lines - height)),
          col = math.floor(0.5 * (vim.o.columns - width)),
        }
      end,
    },
  }
end

return M
