local M = {}

---@param bufnr integer
---@return conform.Range[]|nil
local function get_git_ranges(bufnr)
  -- Get git diff for current buffer
  local diff_cmd = string.format("git diff --unified=0 %s", vim.fn.bufname(bufnr))
  local diff_output = vim.fn.system(diff_cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to get git diff", vim.log.levels.WARN)
    return nil
  end

  local ranges = {}
  for line in diff_output:gmatch "[^\n\r]+" do
    if line:find "^@@" then
      local line_nums = line:match "%+.- "
      if line_nums:find "," then
        local _, _, first, second = line_nums:find "(%d+),(%d+)"
        table.insert(ranges, {
          start = { tonumber(first), 0 },
          ["end"] = { tonumber(first) + tonumber(second), 0 },
        })
      else
        local first = tonumber(line_nums:match "%d+")
        table.insert(ranges, {
          start = { first, 0 },
          ["end"] = { first + 1, 0 }, -- Include the next line for single-line changes
        })
      end
    end
  end
  return ranges
end

---@param bufnr integer
function M.format_on_save_handler(bufnr)
  -- Check if we should ignore this filetype
  local ignore_filetypes = { "lua" }
  if vim.tbl_contains(ignore_filetypes, vim.bo[bufnr].filetype) then
    return { timeout_ms = 500, lsp_fallback = true }
  end

  -- Get changed ranges from git
  local ranges = get_git_ranges(bufnr)
  if not ranges or #ranges == 0 then
    return -- No changes to format
  end

  -- Format each range
  local format = require("conform").format
  for _, range in ipairs(ranges) do
    format {
      bufnr = bufnr,
      range = range,
      timeout_ms = 500,
      lsp_fallback = true,
      async = false, -- Synchronous to ensure ranges are formatted in order
    }
  end

  -- Return false to prevent default format_on_save behavior
  return false
end

return M
