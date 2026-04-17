-- lua/utils/git_format.lua

local M = {}

--- Returns a list of {start_line, end_line} (1-indexed) for lines
--- modified or added in the current file according to git
function M.get_modified_ranges(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if filepath == "" then
    return {}
  end

  -- Use git diff to get hunks for this file
  -- @unified=0 gives us only hunk headers with no context lines
  local result = vim.system(
    { "git", "diff", "--unified=0", "--", filepath },
    { text = true }
  ):wait()

  if result.code ~= 0 or result.stdout == "" then
    return {}
  end

  local ranges = {}

  -- Parse hunk headers like: @@ -old_start,old_count +new_start,new_count @@
  for hunk in result.stdout:gmatch("@@ [^@]+ @@") do
    -- Extract the '+' side (new file lines)
    local start_line, count = hunk:match("%+(%d+),?(%d*)")

    if start_line then
      start_line = tonumber(start_line)
      count = tonumber(count) or 1  -- missing count means 1

      -- count=0 means lines were only deleted, skip
      if count > 0 then
        local end_line = start_line + count - 1
        table.insert(ranges, { start_line, end_line })
      end
    end
  end

  return ranges
end

--- Format only git-modified ranges in the current buffer
--- NOTE for untracked files this will apply to the whole buffer
--- TODO add cache-able request for confirmation of untracked
--- files need to be formatted
function M.format_modified(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ranges = M.get_modified_ranges(bufnr)

  local conform = require("conform")

  -- Untracked file or no git diff: format everything
  if vim.tbl_isempty(ranges) then
    -- Check if file is untracked
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    local result = vim.system(
      { "git", "ls-files", "--error-unmatch", "--", filepath },
      { text = true }
    ):wait()

    if result.code ~= 0 then
      -- File is untracked, format the whole buffer
      conform.format({ bufnr = bufnr })
    end
    return
  end

  for _, range in ipairs(ranges) do
    conform.format({
      bufnr = bufnr,
      range = {
        ["start"] = { range[1], 0 },
        ["end"]   = { range[2], vim.v.maxcol },
      },
    })
  end
end

return M
