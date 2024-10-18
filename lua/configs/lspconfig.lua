local nvon_attach = require("nvchad.configs.lspconfig").on_attach
local capabilities = require("nvchad.configs.lspconfig").capabilities

local lspconfig = require "lspconfig"

-- if you just want default config for the servers then put them in a table
local servers = { "cssls", "clangd", "rust_analyzer", "cmake" }
--                                    ^^^^^^^^^^^^^^^^-- TODO: Set up with rust-tools.nvim

-- LSP mappings
local function setup_lsp_mappings(client, bufnr)
    local function buf_set_keymap(...)
        vim.api.nvim_buf_set_keymap(bufnr, ...)
    end

    local opts = { noremap=true, silent=true }

    -- LSP mappings
    buf_set_keymap('n', '<leader>lD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
    buf_set_keymap('n', '<leader>ld', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
    buf_set_keymap('n', '<leader>lI', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
    buf_set_keymap('n', '<leader>lr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
    buf_set_keymap('n', '<leader>lt', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
    buf_set_keymap('n', '<leader>lk', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
    buf_set_keymap('n', '<leader>la', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
    buf_set_keymap('n', '<leader>lf', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)
    buf_set_keymap('n', '<leader>lr', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
end
local function on_attach(client, bufnr)
    nv_onattach(client, bufnr)
    nvlsp.on_attach(client, bufnr)
    setup_lsp_mappings(client, bufnr)
    -- Add any other custom on_attach logic here
    vim.keymap.set("n", "gd", "<cmd> Telescope lsp_definitions<cr>", { buffer = bufnr })
end

for _, lsp in ipairs(servers) do
    lspconfig[lsp].setup {
        on_attach = on_attach,
        on_init = nvlsp.on_init,
        capabilities = nvlsp.capabilities,
    }
end
