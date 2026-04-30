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

--- Check if a path is tracked/inside a git repo
---@param path string
---@return boolean is_git, boolean is_tracked
local function git_status(path)
  local dir = vim.fn.fnamemodify(path, ':h')

  -- Check if inside a git repo
  local git_check = vim.fn.system { 'git', '-C', dir, 'rev-parse', '--is-inside-work-tree' }
  if vim.v.shell_error ~= 0 then return false, false end

  -- Check if file is tracked
  local tracked = vim.fn.system { 'git', '-C', dir, 'ls-files', '--error-unmatch', path }
  return true, vim.v.shell_error == 0
end

--- Delete a file, using git rm if tracked
---@param path string
local function delete_path(path)
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
local function create_file(path)
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

---@param local_opts table|nil
---@return nil
function M.find_file_at(local_opts)
  local MiniPick = require 'mini.pick'
  local_opts = local_opts or {} -- guard nil (called from registry.registry)
  local cwd = vim.fn.resolve(vim.fn.expand(local_opts.cwd or vim.fn.getcwd()))
  local show_hidden = local_opts.show_hidden or false

  local function create_dwim(path)
    vim.schedule(function()
      if path:match '%.[^./]+$' then
        create_file(path)
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
        -- git doesn't track directories, so no git add needed
        M.find_file_at { cwd = path, show_hidden }
      end
    end)
    MiniPick.stop()
  end

  -- Restart picker at a new directory
  local function navigate_to(dir)
    MiniPick.set_picker_query { '' }
    local current_opts = MiniPick.get_picker_opts()
    current_opts.source.name = 'Find: ' .. vim.fn.fnamemodify(dir, ':~')
    current_opts.source.cwd = dir
    MiniPick.set_picker_opts(current_opts)
    MiniPick.set_picker_items(get_entries(dir, show_hidden), { do_match = false, querytick = nil })
    MiniPick.refresh()
  end

  local function navigate_up()
    local current_opts = MiniPick.get_picker_opts()
    local dir = current_opts.source.cwd
    local parent = vim.fn.fnamemodify(dir, ':h')
    if parent ~= dir then navigate_to(parent) end
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

  -- Store marks outside the function so they persist between picker sessions
  local marked_paths = {}

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
          if query_str == '' then return end

          return create_dwim(query_str)
        end,
      },
      move_down = '',
      -- Tab: navigate into selected dir (or open file)
      navigate_in = {
        char = '<Tab>',
        func = function()
          local matches = MiniPick.get_picker_matches()
          local item = matches and matches.current
          choose_custom(item)
        end,
      },
      -- Toggle mark on current item
      toggle_mark = {
        char = '<C-m>',
        func = function()
          local matches = MiniPick.get_picker_matches()
          if not matches or not matches.current then return end
          local path = matches.current.path
          if marked_paths[path] then
            marked_paths[path] = nil
          else
            marked_paths[path] = true
          end
          -- Refresh to show updated mark indicators
          MiniPick.refresh()
        end,
      },
      remove_query = {
        char = '<C-d>',
        func = function()
          local matches = MiniPick.get_picker_matches()
          if #matches.all == 0 then return end
          local path = matches.all[1].path

          delete_path(path)

          local current_opts = MiniPick.get_picker_opts()
          local dir = current_opts.source.cwd
          MiniPick.set_picker_query { '' }
          MiniPick.set_picker_items(get_entries(dir, show_hidden), { do_match = false, querytick = nil })
          MiniPick.refresh()
        end,
      },

      create_query = {
        char = '<C-n>',
        func = function()
          local matches = MiniPick.get_picker_matches()
          print(#matches.all, vim.inspect(matches.all))
          if #matches.all == 0 then return end
          print(vim.inspect(matches.all[1].path))
          local path = matches.all[1].path
          create_dwim(path)
          MiniPick.refresh()
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

      -- Disable built-in that typically uses C-t
      choose_in_tabpage = '',
    },
  }
end

local function lsp_picker_show(buf_id, items_to_show, query)
  print 'in show'
  local ns = vim.api.nvim_create_namespace 'minipick_lsp_custom'
  vim.api.nvim_buf_clear_namespace(buf_id, ns, 0, -1)

  -- One line per item: the filename header
  local lines = {}
  for _, item in ipairs(items_to_show) do
    local path = item.path or item.filename or ''
    local rel = vim.fn.fnamemodify(path, ':~:.')
    lines[#lines + 1] = rel ~= '' and rel or '[No File]'
  end
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

  -- Highlight filename lines yellow and attach virt_lines for content
  for i, item in ipairs(items_to_show) do
    local lnum_0 = i - 1 -- 0-indexed

    -- Yellow highlight on the filename line
    vim.hl.range(buf_id, ns, 'DiagnosticWarn', { lnum_0, 0 }, { lnum_0, -1 })

    -- Virtual line below with line number + content
    local item_lnum = item.lnum or 0
    local text = item.text or ''
    -- mini.extra formats text as "filepath:lnum:col: content" strip it
    local content = text:match ':%d+:%d+:%s?(.*)$' or text
    local virt_line = {
      { string.format('  %4d: ', item_lnum), 'LineNr' },
      { content, 'Normal' },
    }
    vim.api.nvim_buf_set_extmark(buf_id, ns, lnum_0, 0, {
      virt_lines = { virt_line },
      virt_lines_above = false,
    })
  end
end

-- Picker that provides side by side preview with a bit of a hack
-- For now we just use snacks instead
function M.make_lsp_split_picker(scope, local_opts)
  local pick = require 'mini.pick'
  local extra = require 'mini.extra'

  local total_width = vim.o.columns
  local has_tabline = vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
  local has_statusline = vim.o.laststatus > 0
  local total_height = vim.o.lines - vim.o.cmdheight - (has_tabline and 1 or 0) - (has_statusline and 1 or 0)
  local row_start = has_tabline and 1 or 0

  local items_width = math.floor(total_width * 0.38)
  local preview_width = total_width - items_width - 4

  local preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { 'Waiting for selection...' })

  local preview_win = vim.api.nvim_open_win(preview_buf, false, {
    relative = 'editor',
    anchor = 'NW',
    row = row_start,
    col = items_width + 2,
    width = preview_width,
    height = total_height,
    style = 'minimal',
    border = 'rounded',
    focusable = false,
    zindex = 250,
  })

  local function render_preview(item)
    if not item then return end
    local path = item.path or item.filename
    if not path then return end

    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok or not lines then return end

    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

    local ft = vim.filetype.match { filename = path, buf = preview_buf }
    if ft then vim.bo[preview_buf].filetype = ft end

    local lnum_0 = (item.lnum or 1) - 1
    local col_0 = (item.col or 1) - 1

    local ns = vim.api.nvim_create_namespace 'lsp_split_preview'
    vim.api.nvim_buf_clear_namespace(preview_buf, ns, 0, -1)
    vim.hl.range(preview_buf, ns, 'CursorLine', { lnum_0, 0 }, { lnum_0, -1 })
    if item.col then
      local col_end = item.end_col or (col_0 + 1)
      vim.hl.range(preview_buf, ns, 'Search', { lnum_0, col_0 }, { lnum_0, col_end })
    end

    vim.api.nvim_win_set_buf(preview_win, preview_buf)
    vim.api.nvim_win_set_cursor(preview_win, { lnum_0 + 1, col_0 })
    vim.api.nvim_win_call(preview_win, function() vim.cmd 'normal! zz' end)
  end

  -- wrap show: mini.pick calls this every time the visible items change
  -- which includes moving up and down through the list
  local function show_with_preview(buf_id, items_to_show, query)
    -- call your existing show function for the items list display
    lsp_picker_show(buf_id, items_to_show, query)

    -- after show, current item may have changed so update preview
    -- use vim.schedule since get_picker_matches reads state that may
    -- not be fully updated at the point show is called
    vim.schedule(function()
      if not pick.is_picker_active() then return end
      local item = pick.get_picker_matches().current
      render_preview(item)
    end)
  end

  local aug = vim.api.nvim_create_augroup('LspSplitPicker', { clear = true })

  vim.api.nvim_create_autocmd('User', {
    pattern = 'MiniPickStop',
    group = aug,
    once = true,
    callback = function()
      pcall(vim.api.nvim_win_close, preview_win, true)
      pcall(vim.api.nvim_buf_delete, preview_buf, { force = true })
      vim.api.nvim_del_augroup_by_id(aug)
    end,
  })

  extra.pickers.lsp(vim.tbl_extend('force', { scope = scope }, local_opts or {}), {
    source = {
      show = show_with_preview,
    },
    window = {
      config = {
        relative = 'editor',
        anchor = 'NW',
        row = row_start,
        col = 0,
        width = items_width,
        height = total_height,
        border = 'double',
        zindex = 251,
      },
    },
  })
end

return M
