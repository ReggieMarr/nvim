-- lua/file_browser/oil_columns.lua

local C = require 'utils.file_browsing.columns'

local M = {}

-- ── Factory: builds an oil column definition from a M.* renderer ─────────────

local function make_column(name, width, gap, render_fn, hl_fn)
  return {
    -- The name oil uses to identify this column in its `columns` config
    name = name,

    -- oil calls this to know how wide to make the column.
    -- We add the gap here so oil's layout accounts for the separator space.
    get_width = function(_conf, _bufnr) return width + gap end,

    -- oil calls this per entry; must return { text, hl_group } or just text.
    render = function(entry, _conf)
      local norm = C.normalise_entry(entry)
      local text = render_fn(norm)
      -- Pad to (width + gap) so columns align even when oil doesn't pad itself
      local padded = string.format('%-' .. (width + gap) .. 's', text)
      return { padded, hl_fn and hl_fn(norm) or nil }
    end,
  }
end

-- ── Column definitions ────────────────────────────────────────────────────────

M.icon = make_column('file_browser_icon', C.WIDTHS.icon, C.GAPS.icon, C.render_icon, C.hl_icon)

M.permissions = make_column('file_browser_permissions', C.WIDTHS.perms, C.GAPS.perms, C.render_perms, function(_) return 'Comment' end)

M.size = make_column('file_browser_size', C.WIDTHS.size, C.GAPS.size, function(entry)
  -- render_size already includes format width padding; strip it for oil
  return C.render_size(entry):gsub('^%s+', '')
end, function(_) return 'Number' end)

M.time = make_column(
  'file_browser_time',
  C.WIDTHS.time,
  C.GAPS.time,
  function(entry) return C.render_time(entry):gsub('%s+$', '') end,
  function(_) return 'Special' end
)

return M
