local capabilities = require("nvchad.configs.lspconfig").capabilities

local lspconfig = require "lspconfig"

-- List of language servers to set up
local servers = { "cssls", "clangd", "rust_analyzer", "cmake" }

-- LSP mappings
local function setup_lsp_mappings(client, bufnr)
  local function opts(desc)
    return { buffer = bufnr, desc = "LSP: " .. desc, noremap = true, silent = true }
  end

  -- LSP mappings
  vim.keymap.set('n', '<leader>lD', vim.lsp.buf.declaration, opts("Go to declaration"))
  vim.keymap.set('n', '<leader>ld', vim.lsp.buf.definition, opts("Go to definition"))
  vim.keymap.set('n', '<leader>lI', vim.lsp.buf.implementation, opts("Go to implementation"))
  vim.keymap.set('n', '<leader>lr', vim.lsp.buf.references, opts("Show references"))
  vim.keymap.set('n', '<leader>lt', vim.lsp.buf.type_definition, opts("Go to type definition"))
  vim.keymap.set('n', '<leader>lk', vim.lsp.buf.hover, opts("Show hover information"))
  vim.keymap.set('n', '<leader>la', vim.lsp.buf.code_action, opts("Code action"))
  vim.keymap.set('n', '<leader>lf', vim.lsp.buf.format, opts("Format code"))  -- Note: changed from formatting() to format()
  vim.keymap.set('n', '<leader>lR', vim.lsp.buf.rename, opts("Rename symbol"))
  
  -- Additional mappings from the original config
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
  vim.keymap.set('n', '<leader>lq', vim.diagnostic.setloclist, opts("Set diagnostic to loclist"))

  -- Document symbols (if the client supports it)
  if client.server_capabilities.documentSymbolProvider then
    vim.keymap.set('n', '<leader>ls', vim.lsp.buf.document_symbol, opts("Document symbols"))
  end

  -- Workspace symbols (if the client supports it)
  if client.server_capabilities.workspaceSymbolProvider then
    vim.keymap.set('n', '<leader>lS', vim.lsp.buf.workspace_symbol, opts("Workspace symbols"))
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
