local capabilities = require("nvchad.configs.lspconfig").capabilities

local lspconfig = require "lspconfig"

-- List of language servers to set up
local servers = { "cssls", "clangd", "rust_analyzer", "cmake" }

-- LSP mappings
local function setup_lsp_mappings(client, bufnr)

  local telescope_ok, telescope = pcall(require, 'telescope.builtin')
  if not telescope_ok then
    print("Telescope not found. Some LSP mappings will not be available.")
    telescope = {}
  end
  -- Helper function for options
  local function opts(desc)
    return { noremap = true, silent = true, desc = "LSP: " .. desc }
  end

  vim.keymap.set('n', '<leader>ld', function() telescope.lsp_definitions() end, opts("Go to definition"))
  vim.keymap.set('n', '<leader>lI', function() telescope.lsp_implementations() end, opts("Go to implementation"))
  vim.keymap.set('n', '<leader>lr', function() telescope.lsp_references() end, opts("Show references"))
  vim.keymap.set('n', '<leader>lt', function() telescope.lsp_type_definitions() end, opts("Go to type definition"))
  vim.keymap.set('n', '<leader>la', function() telescope.lsp_code_actions() end, opts("Code action"))
  vim.keymap.set('n', '<leader>lq', function() telescope.diagnostics() end, opts("Show diagnostics"))
  vim.keymap.set('n', '<leader>ls', function() telescope.lsp_document_symbols() end, opts("Document symbols"))
  vim.keymap.set('n', '<leader>lS', function() telescope.lsp_dynamic_workspace_symbols() end, opts("Workspace symbols"))

  -- Additional mappings
  vim.keymap.set('n', '<leader>sh', vim.lsp.buf.signature_help, opts("Show signature help"))
  vim.keymap.set('n', '<leader>lwa', vim.lsp.buf.add_workspace_folder, opts("Add workspace folder"))
  vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts("Remove workspace folder"))
  vim.keymap.set('n', '<leader>ll', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, opts("List workspace folders"))

  -- Diagnostic mappings
  vim.keymap.set('n', '<leader>le', vim.diagnostic.open_float, opts("Show line diagnostics"))
  vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts("Go to previous diagnostic"))
  vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts("Go to next diagnostic"))
  vim.keymap.set('n', '<leader>lq', telescope.diagnostics, opts("Show diagnostics"))

  vim.keymap.set('n', '<leader>ll', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, opts("List workspace folders"))

  -- Diagnostic mappings
  vim.keymap.set('n', '<leader>le', vim.diagnostic.open_float, opts("Show line diagnostics"))
  vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts("Go to previous diagnostic"))
  vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts("Go to next diagnostic"))
  vim.keymap.set('n', '<leader>lq', vim.diagnostic.setloclist, opts("Set diagnostic to loclist"))

  -- Document symbols (if the client supports it)
  if client.server_capabilities.documentSymbolProvider then
    vim.keymap.set('n', '<leader>ls', telescope.lsp_document_symbols, opts("Document symbols"))
  end

  -- Workspace symbols (if the client supports it)
  if client.server_capabilities.workspaceSymbolProvider then
    vim.keymap.set('n', '<leader>lS', telescope.lsp_dynamic_workspace_symbols, opts("Workspace symbols"))
  end
end


local function on_attach(client, bufnr)
    setup_lsp_mappings(client, bufnr)
    vim.keymap.set("n", "gd", "<cmd> Telescope lsp_definitions<cr>", { buffer = bufnr })
end

-- Problem: clangd uses a different offset encoding (UTF-16) compared to other LSP servers (UTF-8).
-- This can cause conflicts and warnings about "multiple different client offset_encodings".
-- Solution: We create a specialized setup for clangd to use UTF-16 encoding.

-- Create a specialized setup function for clangd
local function setup_clangd()
    local clangd_capabilities = vim.deepcopy(capabilities)
    clangd_capabilities.offsetEncoding = { "utf-16" }
    
    lspconfig.clangd.setup {
        on_attach = on_attach,
        capabilities = clangd_capabilities,
        -- Add any other clangd-specific settings here
    }
end

-- Set up other language servers
for _, lsp in ipairs(servers) do
    if lsp ~= "clangd" then  -- We handle clangd separately
        lspconfig[lsp].setup {
            on_attach = on_attach,
            capabilities = capabilities,
        }
    end
end

-- Set up clangd with specialized configuration
setup_clangd()
