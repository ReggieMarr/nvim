-- lua/file_browser/mini_files_config.lua
-- Separated from the autocmd/keymap setup so it can be required at
-- plugin spec time (before the plugin itself is loaded).

local C = require 'utils.file_browsing.columns'

local M = {}

-- Called by mini.files for every entry on every render.
-- Returns (prefix_text, hl_group).  The hl_group here covers the whole
-- prefix string; per-column colours are applied later via extmarks.
function M.make_prefix(fs_entry)
  local entry = {
    path = fs_entry.path,
    name = fs_entry.name,
    is_dir = fs_entry.fs_type == 'directory',
    stat = vim.uv.fs_stat(fs_entry.path),
  }

  -- Build each column string to its fixed width, identical to the picker.
  -- Trailing spaces form the gap between columns and between prefix and name.
  local icon_col = string.format('%-2s', C.render_icon(entry))
  local perms_col = string.format('%-9s', C.render_perms(entry))
  local size_col = string.format('%6s', C.render_size(entry):gsub('%s+', ''))
  local time_col = string.format('%-12s', C.render_time(entry))

  local text = icon_col
    .. string.rep(' ', C.GAPS.icon)
    .. perms_col
    .. string.rep(' ', C.GAPS.perms)
    .. size_col
    .. string.rep(' ', C.GAPS.size)
    .. time_col
    .. string.rep(' ', C.GAPS.time)

  -- Return the icon-specific highlight as the prefix-wide hl.
  -- Per-segment colours are applied in apply_line_highlights().
  return text, C.hl_icon(entry)
end

function M.make_highlight(fs_entry) return fs_entry.fs_type == 'directory' and 'MiniFilesDirectory' or 'MiniFilesFile' end

return M
