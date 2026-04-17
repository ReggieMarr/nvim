-- lua/file_browser/columns.lua
-- Canonical column definitions shared between the mini.pick explorer
-- and the oil file browser so both surfaces render identically.

local M = {}

-- ── Utilities (moved here from the picker module) ────────────────────────────

function M.format_size(bytes)
  if bytes < 1024 then return string.format('%dB', bytes) end
  if bytes < 1024 * 1024 then return string.format('%.1fK', bytes / 1024) end
  if bytes < 1024 * 1024 * 1024 then return string.format('%.1fM', bytes / (1024 * 1024)) end
  return string.format('%.1fG', bytes / (1024 * 1024 * 1024))
end

function M.format_time(ts) return os.date('%b %d %H:%M', ts) end

function M.format_permissions(mode)
  local m = mode % 4096
  local chars = {}
  local bits = { 256, 128, 64, 32, 16, 8, 4, 2, 1 }
  local labels = { 'r', 'w', 'x', 'r', 'w', 'x', 'r', 'w', 'x' }
  for i, bit in ipairs(bits) do
    chars[i] = (m % (bit * 2) >= bit) and labels[i] or '-'
  end
  return table.concat(chars)
end

-- ── Column specs ─────────────────────────────────────────────────────────────
-- Each spec mirrors what format_item_line produces so that the two surfaces
-- stay pixel-identical without duplicating logic.
--
-- A spec is:
--   {
--     width   : integer          -- fixed rendered width (chars)
--     gap     : integer          -- trailing spaces before the next column
--     hl      : string           -- highlight group
--     render  : fn(entry) → str  -- returns a string of exactly `width` chars
--   }
--
-- `entry` is a uv.fs_stat-enriched table.  For oil columns the entry comes
-- from oil's internal entry object; for the picker it comes from enrich_item.
-- Both are normalised through `M.normalise_entry` before being passed in.

-- Normalise an entry from either source into a common shape:
--   { path, name, is_dir, stat }
-- where stat is the raw uv.fs_stat result (or nil).
function M.normalise_entry(raw)
  -- Oil entry shape
  if raw._oil_entry ~= nil then
    local oil = require 'oil'
    local path = oil.get_entry_path(raw)
    return {
      path = path,
      name = raw.name,
      is_dir = raw.type == 'directory',
      stat = vim.uv.fs_stat(path),
    }
  end
  -- Picker item shape (already enriched)
  return {
    path = raw.path,
    name = raw.display or raw.text or '',
    is_dir = raw.is_dir or false,
    stat = vim.uv.fs_stat(raw.path),
  }
end

-- ── Individual column renderers ───────────────────────────────────────────────

-- Width constants — single source of truth consumed by both surfaces
M.WIDTHS = {
  icon = 2,
  perms = 9,
  size = 6,
  time = 12,
}

M.GAPS = {
  icon = 1,
  perms = 1,
  size = 2,
  time = 2,
}

-- Derived: byte offset at which the name column begins.
-- Identical to NAME_COL in the old picker code but now computed from the
-- canonical constants rather than hardcoded.
M.NAME_COL = M.WIDTHS.icon + M.GAPS.icon + M.WIDTHS.perms + M.GAPS.perms + M.WIDTHS.size + M.GAPS.size + M.WIDTHS.time + M.GAPS.time

function M.render_icon(entry)
  local devicons = require 'nvim-web-devicons'
  if entry.is_dir then return '' end -- nerd font folder
  local ext = entry.name:match '%.([^.]+)$' or ''
  local icon, _hl = devicons.get_icon(entry.name, ext, { default = true })
  return icon or ''
end

function M.hl_icon(entry)
  if entry.is_dir then return 'Directory' end
  local devicons = require 'nvim-web-devicons'
  local ext = entry.name:match '%.([^.]+)$' or ''
  local _icon, hl = devicons.get_icon(entry.name, ext, { default = true })
  return hl or 'MiniPickNormal'
end

function M.render_perms(entry)
  if not entry.stat then return '---------' end
  return M.format_permissions(entry.stat.mode)
end

function M.render_size(entry)
  if entry.is_dir then return string.format('%6s', '-') end
  if not entry.stat then return string.format('%6s', '?') end
  return string.format('%6s', M.format_size(entry.stat.size))
end

function M.render_time(entry)
  if not entry.stat then return string.format('%-12s', '?') end
  return string.format('%-12s', M.format_time(entry.stat.mtime.sec))
end

-- ── Full line renderer (used by the picker) ───────────────────────────────────

---@class PickerColumnSpec
---@field hl     string
---@field value  string   exact substring written into the buffer line
---@field gap    integer  trailing spaces after this segment

--- Returns the formatted line string and an ordered list of PickerColumnSpecs.
--- Identical contract to the old format_item_line but driven by M.* constants.
---@param entry table  normalised entry from M.normalise_entry
---@return string, PickerColumnSpec[]
function M.format_line(entry)
  local icon_str = string.format('%-2s', M.render_icon(entry))
  local perms_str = string.format('%-9s', M.render_perms(entry))
  local size_str = string.format('%6s', M.render_size(entry):gsub('%s', ''))
  local time_str = string.format('%-12s', M.render_time(entry):gsub('%s', ''))
  local name_str = entry.name or ''

  local line = icon_str
    .. string.rep(' ', M.GAPS.icon)
    .. perms_str
    .. string.rep(' ', M.GAPS.perms)
    .. size_str
    .. string.rep(' ', M.GAPS.size)
    .. time_str
    .. string.rep(' ', M.GAPS.time)
    .. name_str

  ---@type PickerColumnSpec[]
  local cols = {
    { hl = M.hl_icon(entry), value = icon_str, gap = M.GAPS.icon },
    { hl = 'Comment', value = perms_str, gap = M.GAPS.perms },
    { hl = 'Number', value = size_str, gap = M.GAPS.size },
    { hl = 'Special', value = time_str, gap = M.GAPS.time },
    { hl = entry.is_dir and 'Directory' or 'MiniPickNormal', value = name_str, gap = 0 },
  }

  return line, cols
end

return M
