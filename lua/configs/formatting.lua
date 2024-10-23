local M = {}

M.setup_format_on_save = function(client, bufnr)
  if client.supports_method("textDocument/formatting") then
    local format_modifications_group = vim.api.nvim_create_augroup(
      "FormatModifications" .. bufnr,
      { clear = true }
    )
    
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = format_modifications_group,
      buffer = bufnr,
      callback = function()
        require("lsp-format-modifications").format_modifications(client, bufnr, {
          diff_callback = function(compareee_content, buf_content)
            return vim.diff(compareee_content, buf_content, {
              algorithm = "histogram",
              ignore_whitespace = true,
            })
          end,
          format_callback = function(_, bufnr, ranges)
            require("conform").format({
              bufnr = bufnr,
              async = true,
              range = ranges[1],
            })
          end,
          vcs = "git",
          experimental_empty_line_handling = true,
        })
      end,
    })
  end
end

return M

