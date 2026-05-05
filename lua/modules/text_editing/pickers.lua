-- lua/text_editing/pickers.lua
-- Vertico-style file browser

-- Caches treesitter data per buffer to avoid re-parsing on every render.
-- Shared across all BufLinesShow instances so multi-file doesn't re-parse
-- the same buffer twice.
local TsCache = {}
TsCache.__index = TsCache

_G.TsCache = TsCache

function TsCache.new()
  local self = setmetatable({}, TsCache)
  -- keyed by bufnr -> { lang, parser, tree, query, hl_exists_cache }
  self._cache = {}
  return self
end

function TsCache:_ensure(bufnr)
  if self._cache[bufnr] then return self._cache[bufnr] end

  local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
  if not lang then
    self._cache[bufnr] = false -- negative cache: don't retry
    return false
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok or not parser then
    self._cache[bufnr] = false
    return false
  end

  local tree = parser:parse()[1]
  if not tree then
    self._cache[bufnr] = false
    return false
  end

  local query_ok, query = pcall(vim.treesitter.query.get, lang, 'highlights')
  if not query_ok or not query then
    self._cache[bufnr] = false
    return false
  end

  local entry = {
    lang = lang,
    parser = parser,
    tree = tree,
    query = query,
    -- Cache hlexists results so we don't call vim.fn per capture per line
    hl_exists = {},
  }
  self._cache[bufnr] = entry
  return entry
end

-- Call when a buffer's content changes so we re-parse next access
function TsCache:invalidate(bufnr) self._cache[bufnr] = nil end

function TsCache:get_line_highlights(bufnr, src_lnum_0)
  local entry = self:_ensure(bufnr)
  if not entry then return {} end

  local results = {}
  local root = entry.tree:root()

  for id, node in entry.query:iter_captures(root, bufnr, src_lnum_0, src_lnum_0 + 1) do
    local sr, sc, er, ec = node:range()
    if sr == src_lnum_0 then
      local capture_name = entry.query.captures[id]
      -- Check lang-specific first, then base, cache both results
      local lang_group = '@' .. capture_name .. '.' .. entry.lang
      local base_group = '@' .. capture_name
      local hl_group

      if entry.hl_exists[lang_group] == nil then entry.hl_exists[lang_group] = vim.fn.hlexists(lang_group) == 1 end

      if entry.hl_exists[lang_group] then
        hl_group = lang_group
      else
        if entry.hl_exists[base_group] == nil then entry.hl_exists[base_group] = vim.fn.hlexists(base_group) == 1 end
        hl_group = entry.hl_exists[base_group] and base_group or nil
      end

      if hl_group then
        results[#results + 1] = {
          sc = sc,
          -- Clamp multiline nodes to this line
          ec = er > src_lnum_0 and -1 or ec,
          hl_group = hl_group,
        }
      end
    end
  end

  return results
end

-- Represents a single picker session's rendering state.
-- Decoupled from buffer count so it works for 1 or N source buffers.
local BufLinesShow = {}
BufLinesShow.__index = BufLinesShow

_G.BufLinesShow = BufLinesShow

local function parse_item(item)
  local text = type(item) == 'string' and item or (item.text or '')

  -- buf_lines format: item is a table with lnum and "\0content" in text
  if type(item) == 'table' and item.lnum then
    local content = text:match '%z(.*)$'
    return {
      filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(item.bufnr or 0), ':~:.'),
      lnum = item.lnum,
      -- col = 1,
      content = content or text,
      path = vim.api.nvim_buf_get_name(item.bufnr or 0),
      bufnr = item.bufnr,
    }
  end

  -- grep_live format: "filename\0lnum\0col\0content"
  if text:find '^[^%z]+%z%d+%z%d+%z' then
    local filename, lnum, col, content = text:match '^([^%z]+)%z(%d+)%z(%d+)%z(.*)$'
    return {
      filename = filename,
      lnum = tonumber(lnum),
      -- col = tonumber(col),
      content = content,
      path = vim.fn.fnamemodify(filename, ':p'),
      -- bufnr may not exist yet since grep results can be unloaded files
      -- Note if a buffer is unloaded it may return a small positive number.
      -- That's why we perform the check and set it to negative if the buffer
      -- doesn't exist/has been unloaded
      bufnr = (vim.fn.bufexists(vim.fn.bufnr(filename)) and vim.fn.bufnr(filename) or -1),
    }
  end

  return nil
end
-- ts_cache should be a shared TsCache instance passed in from outside
-- so multiple pickers don't duplicate parse work.
function BufLinesShow.new(display_callback, ts_cache)
  -- TODO add type hinting
  vim.validate {
    ts_cache = { ts_cache, 'table' },
  }
  local self = setmetatable({}, BufLinesShow)
  self.ts_cache = ts_cache
  self.display_callback = display_callback
  self.ns = vim.api.nvim_create_namespace 'show_buf_lines'
  -- TODO could calculate this per buffer results
  self.content_col = 8 -- "  NNNN: " is 8 chars
  return self
end

function BufLinesShow:_apply_ts_highlights(buf_id, item_positions)
  local current_item_source = nil
  for _, pos in ipairs(item_positions) do
    if pos.filename ~= current_item_source then
      -- First item uses the win_buf
      if current_item_source == nil then
        -- Set header in the picker window's winbar
        -- NOTE it would be nice to do this with virtual text
        -- but it seems there's a fundamental constraint around setting
        -- virtual text above the first line in a mini-picker buffer
        -- TODO revist if using minibuffer
        local win = vim.fn.bufwinid(buf_id)
        if win ~= -1 then vim.wo[win].winbar = '%#DiagnosticWarn#' .. pos.filename .. '%*' end
      else
        -- Set virtual text headers for all others
        local virt_line = {
          { pos.filename, 'DiagnosticWarn' },
        }

        vim.api.nvim_buf_set_extmark(buf_id, self.ns, pos.pick_lnum_0, 0, {
          virt_lines = { virt_line },
          virt_lines_above = true,
          virt_text_pos = 'overlay',
          -- Ensure it covers the whole line visually
          virt_text_hide = false,
        })
      end
      current_item_source = pos.filename
    end

    -- TODO load in buffers for treesitter capture on a deferred basis
    if pos.bufnr ~= -1 then
      local captures = self.ts_cache:get_line_highlights(pos.bufnr, pos.src_lnum_0)
      for _, cap in ipairs(captures) do
        vim.hl.range(
          buf_id,
          self.ns,
          cap.hl_group,
          { pos.pick_lnum_0, self.content_col + cap.sc },
          { pos.pick_lnum_0, cap.ec == -1 and -1 or self.content_col + cap.ec }
        )
      end
    end
  end
end

function BufLinesShow:_apply_query_highlights(buf_id, lines, query)
  if not query or #query == 0 then return end
  local pattern = table.concat(query):lower()
  for i, line in ipairs(lines) do
    -- Skip empty lines
    if line ~= '' then
      local lower = line:lower()
      local s, e = lower:find(pattern, 1, true)
      while s do
        vim.hl.range(buf_id, self.ns, 'Search', { i - 1, s - 1 }, { i - 1, e })
        s, e = lower:find(pattern, e + 1, true)
      end
    end
  end
end

function BufLinesShow:show(buf_id, items_to_show, query)
  vim.api.nvim_buf_clear_namespace(buf_id, self.ns, 0, -1)

  -- If nothing to show then just return
  -- NOTE we could display some message here but that'd likely be a nusance
  if not items_to_show or #items_to_show == 0 then return end

  -- Track where each item lands in the pick buffer for highlight mapping.
  -- { pick_lnum_0, bufnr, src_lnum_0 }
  local item_positions = {}

  -- Insert a blank first line as a dedicated header row
  local lines = {} -- blank placeholder for header

  -- TODO we should figure out how many items are actually displayed
  -- and defer higlighting/rendering those that wouldn't be displayed anyways
  for _, item in ipairs(items_to_show) do
    local parsed_item = parse_item(item)

    local content = parsed_item.content
    local src_lnum_0 = parsed_item.lnum - 1
    local pick_lnum_0 = #lines
    lines[#lines + 1] = string.format('  %4d: %s', parsed_item.lnum, content)
    item_positions[#item_positions + 1] = {
      pick_lnum_0 = pick_lnum_0,
      bufnr = parsed_item.bufnr,
      src_lnum_0 = src_lnum_0,
      filename = parsed_item.filename,
    }
  end

  -- Populate the display buffer
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

  -- Highlight the line number prefix
  vim.hl.range(buf_id, self.ns, 'LineNr', { 0, 0 }, { #items_to_show, self.content_col })

  -- Treesitter highlights
  self:_apply_ts_highlights(buf_id, item_positions)

  -- Highlight query matches (applied last so they sit on top)
  self:_apply_query_highlights(buf_id, lines, query)

  if self.display_callback then self.display_callback() end
end

-- Returns the bound show function that MiniPick expects
function BufLinesShow:as_fn()
  return function(buf_id, items_to_show, query) self:show(buf_id, items_to_show, query) end
end
