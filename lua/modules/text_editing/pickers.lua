-- lua/text_editing/pickers.lua
-- Vertico-style file browser

local M = {}

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

local buf_show_lines_ns = vim.api.nvim_create_namespace 'show_buf_lines'
-- Parse "lnum| content" produced by mini.extra buf_lines
local function parse_item(item)
  -- item.lnum is reliable; extract content after the null byte separator
  local content = (item.text or ''):match '%z(.*)$'
  return item.lnum, content or item.text or ''
end

function M.make_buf_lines_show(source_buf, source_win)
  -- Cache the language and highlighter per source buffer to avoid re-querying
  local lang = vim.treesitter.language.get_lang(vim.bo[source_buf].filetype)

  -- Apply treesitter highlights to a range of lines in the pick buffer.
  -- We do this by copying the relevant source lines into a scratch buffer,
  -- parsing with treesitter, then transferring the highlight captures back.
  local function apply_ts_highlights(buf_id, items_to_show, line_offset)
    if not lang then return end

    -- Build a mini source-text from the items so the parser has context
    -- We only highlight the content portion (col offset = 8 for "  NNNN: ")
    local content_col = 8 -- "  NNNN: " is 8 chars

    local ok, parser = pcall(vim.treesitter.get_parser, source_buf, lang)
    if not ok or not parser then return end

    local tree = parser:parse()[1]
    if not tree then return end

    local root = tree:root()
    local query_ok, query = pcall(vim.treesitter.query.get, lang, 'highlights')
    if not query_ok or not query then return end

    for i, item in ipairs(items_to_show) do
      local lnum_0 = line_offset + (i - 1)
      local src_lnum, _ = parse_item(item)
      local src_lnum_0 = src_lnum - 1

      -- Walk query captures for this source line
      for id, node in query:iter_captures(root, source_buf, src_lnum_0, src_lnum_0 + 1) do
        local capture_name = query.captures[id]
        local hl_group = '@' .. capture_name .. '.' .. lang
        -- Fallback to the base capture if the lang-specific one doesn't exist
        if vim.fn.hlexists(hl_group) == 0 then hl_group = '@' .. capture_name end

        local sr, sc, er, ec = node:range()
        -- Only apply if the node is on the source line we care about
        if sr == src_lnum_0 then
          -- Map source columns to pick buffer columns (offset by content_col)
          local pick_sc = content_col + sc
          local pick_ec = content_col + ec
          -- Clamp end row: multi-line nodes get clipped to this line
          local pick_er = lnum_0
          if er > src_lnum_0 then pick_ec = -1 end
          vim.hl.range(buf_id, buf_show_lines_ns, hl_group, { lnum_0, pick_sc }, { pick_er, pick_ec })
        end
      end
    end
  end

  local function mini_pick_buf_lines_show(buf_id, items_to_show, query)
    vim.api.nvim_buf_clear_namespace(buf_id, buf_show_lines_ns, 0, -1)

    local matched_item = require('mini.pick').get_picker_matches().current

    if matched_item and vim.api.nvim_win_is_valid(source_win) then
      vim.api.nvim_win_set_cursor(source_win, { matched_item.lnum, 0 })
      vim.api.nvim_win_call(source_win, function() vim.cmd 'normal! zz' end)
    end

    local buf_name = vim.api.nvim_buf_get_name(source_buf)
    local rel = vim.fn.fnamemodify(buf_name, ':~:.')
    rel = rel ~= '' and rel or '[No File]'

    if not items_to_show or #items_to_show == 0 then
      local win = vim.fn.bufwinid(buf_id)
      local height = win ~= -1 and vim.api.nvim_win_get_height(win) or 20
      local placeholder = { rel } -- header as real line
      for _ = 2, height do
        placeholder[#placeholder + 1] = ''
      end
      vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, placeholder)
      vim.hl.range(buf_id, buf_show_lines_ns, 'DiagnosticWarn', { 0, 0 }, { 0, -1 })
      return
    end

    -- Header is line 0, items start at line 1
    local content_col = 8
    local lines = { rel } -- real line for the header
    for _, item in ipairs(items_to_show) do
      local lnum, content = parse_item(item)
      lines[#lines + 1] = string.format('  %4d: %s', lnum, content)
    end
    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

    -- Highlight the header line
    vim.hl.range(buf_id, buf_show_lines_ns, 'DiagnosticWarn', { 0, 0 }, { 0, -1 })

    -- Dim line number prefixes (offset by 1 for header line)
    for i = 1, #items_to_show do
      vim.hl.range(buf_id, buf_show_lines_ns, 'LineNr', { i, 0 }, { i, content_col })
    end

    -- Treesitter highlights pass line_offset=1 to account for header
    apply_ts_highlights(buf_id, items_to_show, 1)

    -- Query match highlights
    if query and #query > 0 then
      local pattern = table.concat(query):lower()
      for i, line in ipairs(lines) do
        if i > 1 then -- skip header
          local lower_line = line:lower()
          local start = 1
          while true do
            local s, e = lower_line:find(pattern, start, true)
            if not s then break end
            vim.hl.range(buf_id, buf_show_lines_ns, 'Search', { i - 1, s - 1 }, { i - 1, e })
            start = e + 1
          end
        end
      end
    end
  end
  return mini_pick_buf_lines_show
end

return M
