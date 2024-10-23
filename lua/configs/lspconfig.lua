local nvlsp = require "nvchad.configs.lspconfig"
local lspconfig = require "lspconfig"

-- nvlsp.defaults() -- loads nvchad's defaults

-- LSP mappings
local function setup_lsp_mappings(client, bufnr)
  local telescope_ok, telescope = pcall(require, "telescope.builtin")
  if not telescope_ok then
    print "Telescope not found. Some LSP mappings will not be available."
    telescope = {}
  end
  -- Helper function for options
  local function opts(desc)
    return { noremap = true, silent = true, desc = "LSP: " .. desc }
  end

  vim.keymap.set("n", "<leader>ld", function()
    telescope.lsp_definitions()
  end, opts "Go to definition")
  vim.keymap.set("n", "<leader>lI", function()
    telescope.lsp_implementations()
  end, opts "Go to implementation")
  vim.keymap.set("n", "<leader>lr", function()
    telescope.lsp_references()
  end, opts "Show references")
  vim.keymap.set("n", "<leader>lt", function()
    telescope.lsp_type_definitions()
  end, opts "Go to type definition")
  vim.keymap.set("n", "<leader>la", function()
    vim.lsp.buf.code_action()
  end, opts "Code action")
  vim.keymap.set("n", "<leader>lh", function()
    vim.lsp.buf.hover()
  end, opts "Show hover info")
  vim.keymap.set("n", "<leader>lq", function()
    telescope.diagnostics()
  end, opts "Show diagnostics")
  vim.keymap.set("n", "<leader>ls", function()
    telescope.lsp_document_symbols()
  end, opts "Document symbols")

  -- Additional mappings
  vim.keymap.set("n", "<leader>lwa", function()
    vim.lsp.buf.add_workspace_folder()
  end, opts "Add workspace folder")
  vim.keymap.set("n", "<leader>wr", function()
    vim.lsp.buf.remove_workspace_folder()
  end, opts "Remove workspace folder")

  -- Diagnostic mappings
  vim.keymap.set("n", "<leader>le", function()
    vim.diagnostic.open_float()
  end, opts "Show line diagnostics")
  vim.keymap.set("n", "[d", function()
    vim.diagnostic.goto_prev()
  end, opts "Go to previous diagnostic")
  vim.keymap.set("n", "]d", function()
    vim.diagnostic.goto_next()
  end, opts "Go to next diagnostic")
  vim.keymap.set("n", "<leader>lq", function()
    telescope.diagnostics()
  end, opts "Show diagnostics")
  -- Workspace symbols (if the client supports it)
  if client.server_capabilities.workspaceSymbolProvider then
    vim.keymap.set("n", "<leader>lS", function()
      telescope.lsp_dynamic_workspace_symbols()
    end, opts "Workspace symbols")
  end
end

-- Separate formatting setup
-- TODO potentiall remove
-- local function setup_formatting(client, bufnr)
--   require("lsp-format-modifications").attach(client, bufnr, {
--     format_callback = function(params)
--       require("conform").format {
--         bufnr = params.bufnr,
--         async = true,
--         range = params.range,
--       }
--     end,
--     format_on_save = true,
--     vcs = "git",
--     experimental_empty_line_handling = true,
--   })
-- end

local function custom_on_attach(client, bufnr)
  setup_lsp_mappings(client, bufnr)
  -- setup_formatting(client, bufnr)
end

local servers = { "html", "cssls", "clangd", "rust_analyzer", "cmake" }

for _, lsp in ipairs(servers) do
  local custom_capabilities = nvlsp.capabilities

  -- Special handling for clangd
  if lsp == "clangd" then
    custom_capabilities = vim.tbl_deep_extend("force", custom_capabilities or {}, {
      offsetEncoding = { "utf-16" },
    })
  end

  lspconfig[lsp].setup {
    on_attach = custom_on_attach,
    on_init = nvlsp.on_init,
    capabilities = custom_capabilities,
  }
end
