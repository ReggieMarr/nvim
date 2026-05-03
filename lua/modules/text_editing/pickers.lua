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

function BufLinesShow:_apply_ts_highlights(buf_id, items_to_show, items_bufrn)
  local lang = vim.treesitter.language.get_lang(vim.bo[items_bufrn].filetype)

  local ok, parser = pcall(vim.treesitter.get_parser, items_bufrn, lang)
  if not ok or not parser then return end

  local tree = parser:parse()[1]
  if not tree then return end

  local root = tree:root()
  local query_ok, query = pcall(vim.treesitter.query.get, lang, 'highlights')
  if not query_ok or not query then return end

  for i, item in ipairs(items_to_show) do
    local lnum_0 = (i - 1)
    local src_lnum_0 = item.lnum - 1

    for id, node in query:iter_captures(root, items_bufrn, src_lnum_0, src_lnum_0 + 1) do
      local capture_name = query.captures[id]
      local hl_group = '@' .. capture_name .. '.' .. lang
      if vim.fn.hlexists(hl_group) == 0 then hl_group = '@' .. capture_name end

      local sr, sc, er, ec = node:range()
      if sr == src_lnum_0 then
        local pick_sc = self.content_col + sc
        local pick_ec = self.content_col + ec
        local pick_er = lnum_0
        if er > src_lnum_0 then pick_ec = -1 end
        vim.hl.range(buf_id, self.ns, hl_group, { lnum_0, pick_sc }, { pick_er, pick_ec })
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

-- Groups items by bufnr, preserving order of first appearance.
-- Returns { { bufnr, header, items } }
function BufLinesShow:_group_by_buf(items_to_show)
  local groups = {}
  local seen = {}
  for _, item in ipairs(items_to_show) do
    local bufnr = item.bufnr
    local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p')
    if not seen[bufnr] then
      seen[bufnr] = #groups + 1
      groups[#groups + 1] = {
        bufnr = bufnr,
        header = buf_name,
        items = {},
      }
    end
    local g = groups[seen[bufnr]]
    g.items[#g.items + 1] = item
  end
  return groups
end

function BufLinesShow:show(buf_id, items_to_show, query)
  vim.api.nvim_buf_clear_namespace(buf_id, self.ns, 0, -1)

  -- If nothing to show then just return
  -- NOTE we could display some message here but that'd likely be a nusance
  if not items_to_show or #items_to_show == 0 then return end
  -- NOTE items_to_show is assumed to come from a single buffer
  -- so we just take the bufnr from the first item (later we'll ensure this is true)
  local items_bufnr = items_to_show[1].bufnr

  -- Set header in the picker window's winbar
  -- NOTE it would be nice to do this with virtual text
  -- but it seems there's a fundamental constraint around setting
  -- virtual text above the first line in a mini-picker buffer
  -- TODO revist if using minibuffer
  local win = vim.fn.bufwinid(buf_id)
  if win ~= -1 then
    local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(items_bufnr), ':p')
    vim.wo[win].winbar = '%#DiagnosticWarn#' .. buf_name .. '%*'
  end

  local groups = self:_group_by_buf(items_to_show)
  -- Track where each item lands in the pick buffer for highlight mapping.
  -- { pick_lnum_0, bufnr, src_lnum_0 }
  local item_positions = {}

  -- Insert a blank first line as a dedicated header row
  local lines = {} -- blank placeholder for header

  for _, group in ipairs(groups) do
    -- In multi-file mode each group gets a header line.
    -- In single-file mode we still emit it (consistent behaviour, callers
    -- can style it differently via opts later).
    local header_pick_lnum = #lines -- 0-indexed position this header will be at
    -- lines[#lines + 1] = '' -- placeholder: header is virtual text, real line is blank
    for _, item in ipairs(items_to_show) do
      local content = (item.text or ''):match '%z(.*)$'
      local src_lnum_0 = item.lnum - 1
      local pick_lnum_0 = #lines
      lines[#lines + 1] = string.format('  %4d: %s', item.lnum, content)
      item_positions[#item_positions + 1] = {
        pick_lnum_0 = pick_lnum_0,
        bufnr = group.bufnr,
        src_lnum_0 = src_lnum_0,
      }
    end
    -- Attach virtual text header above the blank separator line.
    -- We defer extmark setting until after buf_set_lines.
    group._header_pick_lnum = header_pick_lnum
    group._header_text = group.header
  end
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

  -- Set virtual text headers now that lines exist
  -- for _, group in ipairs(groups) do
  --   vim.api.nvim_buf_set_extmark(buf_id, self.ns, group._header_pick_lnum, 0, {
  --     virt_text = { { group._header_text, 'DiagnosticWarn' } },
  --     virt_text_pos = 'overlay',
  --     -- Ensure it covers the whole line visually
  --     virt_text_hide = false,
  --   })
  -- end

  -- Line number prefix highlights
  for _, pos in ipairs(item_positions) do
    vim.hl.range(buf_id, self.ns, 'LineNr', { pos.pick_lnum_0, 0 }, { pos.pick_lnum_0, self.content_col })
  end

  -- Treesitter highlights
  for _, pos in ipairs(item_positions) do
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

  -- vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
  --
  -- -- Line number prefix highlight (offset by 1 for header)
  -- vim.hl.range(buf_id, self.ns, 'LineNr', { 0, 0 }, { #items_to_show, self.content_col })
  --
  -- self:_apply_ts_highlights(buf_id, items_to_show, items_bufnr)

  -- Query match highlights (applied last so they sit on top)
  self:_apply_query_highlights(buf_id, lines, query)

  self.display_callback()
end

-- Returns the bound show function that MiniPick expects
function BufLinesShow:as_fn()
  return function(buf_id, items_to_show, query) self:show(buf_id, items_to_show, query) end
end
