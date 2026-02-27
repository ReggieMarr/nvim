-- lua/features/lsp.lua

local M = {}

-- ============================================================================
-- PLUGIN DEPENDENCIES
-- ============================================================================
M.dependencies = {
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      {
        'williamboman/mason.nvim',
        cmd = 'Mason',
        build = ':MasonUpdate',
        opts = {
          install_root_dir = os.getenv 'HOME' .. '/.local/share/nvim/mason/',
          ensure_installed = {
            'lua_ls',
            'rust_analyzer',
            'clangd',
            'clang_format',
            'cmake_language_server',
            'lua_language_server',
            'pyright',
            'ts_ls',
          },
        },
      },
      {
        'jay-babu/mason-null-ls.nvim',
        event = { 'BufReadPre', 'BufNewFile' },
        dependencies = {
          'williamboman/mason.nvim',
          'nvimtools/none-ls.nvim',
        },
        opts = {
          install_root_dir = os.getenv 'HOME' .. '/.local/share/nvim/mason/',
          ensure_installed = {
            'codespell',
            'cspell',
            'gitlint',
            'alex',
            'cmake-lint',
            'ruff',
            'write-good',
            'textidote',
            'textlint',
            'markdownlint',
            'proselint',
          },
          automatic_installation = true,
          handlers = {},
        },
      },

      {
        'williamboman/mason-lspconfig.nvim',
        dependencies = {
          'williamboman/mason.nvim',
        },
        opts = {
          install_root_dir = os.getenv 'HOME' .. '/.local/share/nvim/mason/',
        },
      },
    },
  },

  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
    },
  },
}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
function M.get_capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
  if ok then capabilities = cmp_nvim_lsp.default_capabilities(capabilities) end
  return capabilities
end

-- This runs on LSP attach per buffer (see main LSP attach function in 'neovim/nvim-lspconfig' config for more info,
-- it is better explained there). This allows easily switching between pickers if you prefer using something else!
function M.on_attach(client, bufnr)
  -- Enable inlay hints if supported
  if client.supports_method 'textDocument/inlayHint' then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end
end

function M.setup_mason()
  require('mason').setup {
    ui = {
      border = 'rounded',
      icons = {
        package_installed = '✓',
        package_pending = '➜',
        package_uninstalled = '✗',
      },
    },
  }

  require('mason-lspconfig').setup {
    opts = {
      install_root_dir = os.getenv 'HOME' .. '/.local/share/nvim/mason/',
    },
    automatic_installation = true,
  }
end

function M.setup_servers()
  local capabilities = M.get_capabilities()

  -- Base configuration shared by all servers
  local base_config = {
    on_attach = M.on_attach,
    capabilities = capabilities,
  }

  -- ============================================================================
  -- Lua Language Server
  -- ============================================================================
  vim.lsp.config(
    'lua_ls',
    vim.tbl_deep_extend('force', base_config, {
      settings = {
        Lua = {
          runtime = { version = 'LuaJIT' },
          workspace = {
            checkThirdParty = false,
            library = {
              vim.env.VIMRUNTIME,
              -- Add other libraries as needed
              -- "${3rd}/luv/library",
            },
          },
          diagnostics = {
            globals = { 'vim' },
          },
          telemetry = { enable = false },
          completion = {
            callSnippet = 'Replace',
          },
        },
      },
    })
  )

  -- ============================================================================
  -- Rust Analyzer
  -- ============================================================================
  vim.lsp.config(
    'rust_analyzer',
    vim.tbl_deep_extend('force', base_config, {
      settings = {
        ['rust-analyzer'] = {
          cargo = {
            allFeatures = true,
            loadOutDirsFromCheck = true,
          },
          checkOnSave = {
            command = 'clippy',
          },
          procMacro = {
            enable = true,
          },
        },
      },
    })
  )

  -- ============================================================================
  -- Python (Pyright)
  -- ============================================================================
  vim.lsp.config(
    'pyright',
    vim.tbl_deep_extend('force', base_config, {
      settings = {
        python = {
          analysis = {
            autoSearchPaths = true,
            diagnosticMode = 'workspace',
            useLibraryCodeForTypes = true,
          },
        },
      },
    })
  )

  -- ============================================================================
  -- TypeScript
  -- ============================================================================
  vim.lsp.config('ts_ls', base_config)

  -- Enable LSP servers (this triggers them to start)
  vim.lsp.enable 'lua_ls'
  vim.lsp.enable 'rust_analyzer'
  vim.lsp.enable 'pyright'
  vim.lsp.enable 'ts_ls'
end

function M.setup_completion()
  local cmp = require 'cmp'
  local luasnip = require 'luasnip'

  cmp.setup {
    snippet = {
      expand = function(args) luasnip.lsp_expand(args.body) end,
    },
    window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert {
      ['<C-b>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.abort(),
      ['<CR>'] = cmp.mapping.confirm { select = true },
      ['<Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        elseif luasnip.expand_or_jumpable() then
          luasnip.expand_or_jump()
        else
          fallback()
        end
      end, { 'i', 's' }),
      ['<S-Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        elseif luasnip.jumpable(-1) then
          luasnip.jump(-1)
        else
          fallback()
        end
      end, { 'i', 's' }),
    },
    sources = cmp.config.sources({
      { name = 'nvim_lsp' },
      { name = 'luasnip' },
    }, {
      { name = 'buffer' },
      { name = 'path' },
    }),
  }
end

-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================
function M.setup_autocmds()
  local augroup = vim.api.nvim_create_augroup('LSP', { clear = true })

  -- Highlight symbol under cursor
  vim.api.nvim_create_autocmd('LspAttach', {
    group = augroup,
    callback = function(event)
      print 'LSP Attach'

      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if client and client.supports_method 'textDocument/documentHighlight' then
        local highlight_group =
          vim.api.nvim_create_augroup('LSPDocumentHighlight', { clear = false })

        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          group = highlight_group,
          buffer = event.buf,
          callback = vim.lsp.buf.document_highlight,
        })

        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          group = highlight_group,
          buffer = event.buf,
          callback = vim.lsp.buf.clear_references,
        })
      end

      local buf = event.buf
      local builtin = require 'telescope.builtin'

      -- Find references for the word under your cursor.
      vim.keymap.set(
        'n',
        '<leader>lc',
        function() Snacks.picker.lsp_incoming_calls() end,
        { buffer = buf, desc = 'LSP incoming calls' }
      )
      vim.keymap.set(
        'n',
        '<leader>lC',
        function() Snacks.picker.lsp_outgoing_calls() end,
        { buffer = buf, desc = 'LSP incoming calls' }
      )
      vim.keymap.set(
        'n',
        '<leader>lr',
        function() Snacks.picker.lsp_references() end,
        { buffer = buf, desc = '[L]sp Goto [R]eferences' }
      )
      vim.keymap.set(
        'n',
        '<leader>ln',
        vim.lsp.buf.rename,
        { buffer = buf, desc = '[L]sp Re[N]ame' }
      )
      vim.keymap.set(
        'n',
        '<leader>la',
        vim.lsp.buf.code_action,
        { buffer = buf, desc = 'Code Action' }
      )

      -- Jump to the implementation of the word under your cursor.
      -- Useful when your language has ways of declaring types without an actual implementation.
      vim.keymap.set(
        'n',
        '<leader>li',
        vim.lsp.buf.implementation,
        { buffer = buf, desc = '[L]sp Goto [I]mplementation' }
      )

      -- Jump to the definition of the word under your cursor.
      -- This is where a variable was first declared, or where a function is defined, etc.
      -- To jump back, press <C-t>.
      vim.keymap.set(
        'n',
        '<leader>ld',
        vim.lsp.buf.definition,
        { buffer = buf, desc = '[G]oto [D]efinition' }
      )
      vim.keymap.set(
        'n',
        '<leader>lD',
        vim.lsp.buf.declaration,
        { buffer = buf, desc = '[G]oto [D]eclaration' }
      )

      -- Fuzzy find all the symbols in your current document.
      -- Symbols are things like variables, functions, types, etc.
      vim.keymap.set(
        'n',
        '<leader>ls',
        function() Snacks.picker.lsp_symbols() end,
        { buffer = buf, desc = 'Search [Lsp] Document [S]ymbols' }
      )

      -- Fuzzy find all the symbols in your current workspace.
      -- Similar to document symbols, except searches over your entire project.
      vim.keymap.set(
        'n',
        '<leader>lS',
        function() Snacks.picker.lsp_workspace_symbols() end,
        { buffer = buf, desc = 'Search [Lsp] workplace [S]ymbols' }
      )

      -- Jump to the type of the word under your cursor.
      -- Useful when you're not sure what type a variable is and you want to see
      -- the definition of its *type*, not where it was *defined*.
      vim.keymap.set(
        'n',
        '<leader>lt',
        function() Snacks.picker.lsp_type_definitions() end,
        { buffer = buf, desc = 'Search [L]sp [T]ype Declaration' }
      )

      vim.keymap.set('n', '<leader>ll', vim.lsp.buf.hover, { desc = 'Hover' })
      vim.keymap.set(
        'n',
        '<leader>lf',
        function() vim.lsp.buf.format { async = true } end,
        { desc = 'Format Buffer' }
      )

      -- -- Workspace
      vim.keymap.set(
        'n',
        '<leader>wa',
        vim.lsp.buf.add_workspace_folder,
        { desc = 'Add Workspace Folder' }
      )
      vim.keymap.set(
        'n',
        '<leader>wr',
        vim.lsp.buf.remove_workspace_folder,
        { desc = 'Remove Workspace Folder' }
      )
      -- vim.keymap.set('n', '<leader>wl', function()
      --     print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
      -- end, {desc = 'List Workspace Folders'})
      -- The following code creates a keymap to toggle inlay hints in your
      -- code, if the language server you are using supports them
      --
      -- This may be unwanted, since they displace some of your code
      -- if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, buf) then
      -- vim.keymap.set(
      --     'n',
      --     '<leader>lh',
      --     function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = buf }) end,
      --     {desc = '[L]sp Toggle Inlay [H]ints'}
      -- )
      -- end
    end,
  })

  -- Show diagnostic on hover
  vim.api.nvim_create_autocmd('CursorHold', {
    group = augroup,
    callback = function()
      local opts = {
        focusable = false,
        close_events = { 'BufLeave', 'CursorMoved', 'InsertEnter', 'FocusLost' },
        border = 'rounded',
        source = 'always',
        prefix = ' ',
      }
      vim.diagnostic.open_float(nil, opts)
    end,
  })
end

-- ============================================================================
-- KEYMAPS
-- ============================================================================
function M.setup_keymaps()
  -- Global LSP keymaps
  vim.keymap.set('n', '<leader>lm', '<cmd>Mason<cr>', { desc = 'Mason' })
  vim.keymap.set('n', '<leader>lI', '<cmd>LspInfo<cr>', { desc = 'LSP Info' })
  vim.keymap.set('n', '<leader>lR', '<cmd>LspRestart<cr>', { desc = 'LSP Restart' })
end

-- ============================================================================
-- MAIN SETUP FUNCTION
-- ============================================================================
function M.setup()
  -- Configure Mason first
  M.setup_mason()

  -- Setup LSP servers
  M.setup_servers()

  -- Setup completion
  M.setup_completion()

  -- Setup autocmds and keymaps
  M.setup_autocmds()
  M.setup_keymaps()
end

return M
