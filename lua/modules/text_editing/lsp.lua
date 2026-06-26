-- lua/modules/text_editing/lsp.lua
-- Lsp capabilities

local env = require 'env'

-- ── Shared LSP on_attach ───────────────────────────────────────
local function on_attach(client, bufnr)
  -- env.state._update('lsp.attached_servers', vim.lsp.get_clients { bufnr = bufnr })

  -- if client.server_capabilities.inlayHintProvider then vim.lsp.inlay_hint.enable(true, { bufnr = bufnr }) end
  -- ── Helper ──────────────────────────────────────────────────────
  --- Notify the user that the LSP server does not provide a capability.
  ---@param capability string The capability name as it appears in server_capabilities
  local function missing(capability)
    vim.notify(
      string.format('LSP: %s does not provide %s\nclient_id=%d  root=%s', client.name, capability, client.id, (client.root_dir or '(no root)')),
      vim.log.levels.WARN
    )
  end

  -- ── Always-available keymaps ────────────────────────────────────
  vim.keymap.set('n', '<leader>ld', function() vim.ui.picker.lsp_definitions() end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.find_definitions',
  })

  vim.keymap.set('n', '<leader>ll', function() vim.diagnostic.open_float { scope = 'line' } end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.show_diagnostics_line',
  })

  -- Diagnostic navigation follows ]d / [d / ]e / [e conventions
  -- established by vim-unimpaired and adopted widely.
  vim.keymap.set('n', ']d', function() vim.diagnostic.jump { count = 1, float = true } end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.diagnostics_next',
  })

  vim.keymap.set('n', '[d', function() vim.diagnostic.jump { count = -1, float = true } end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.diagnostics_prev',
  })

  vim.keymap.set('n', ']e', function() vim.diagnostic.jump { count = 1, float = true, severity = vim.diagnostic.severity.ERROR } end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.diagnostics_next_error',
  })

  vim.keymap.set('n', '[e', function() vim.diagnostic.jump { count = -1, float = true, severity = vim.diagnostic.severity.ERROR } end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.diagnostics_prev_error',
  })

  -- ── Picker keymaps (conditional) ────────────────────────────────

  -- <leader>ls  — document Symbols (mnemonic: s for symbols, scoped to buffer)
  vim.keymap.set('n', '<leader>ls', function()
    if client.server_capabilities.documentSymbolProvider then
      vim.ui.picker.lsp_document_symbols()
    else
      missing 'documentSymbolProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.find_symbols_document',
  })

  -- <leader>lS  — workspace Symbols (capital S = wider scope)
  vim.keymap.set('n', '<leader>lS', function()
    if client.server_capabilities.workspaceSymbolProvider then
      vim.ui.picker.lsp_workspace_symbols()
    else
      missing 'workspaceSymbolProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.find_symbols_workspace',
  })

  -- <leader>lr  — References
  vim.keymap.set('n', '<leader>lr', function()
    if client.server_capabilities.referencesProvider then
      vim.ui.picker.lsp_references()
    else
      missing 'referencesProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.find_references',
  })

  -- <leader>li  — Implementations
  vim.keymap.set('n', '<leader>li', function()
    if client.server_capabilities.implementationProvider then
      vim.ui.picker.lsp_implementations()
    else
      missing 'implementationProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.find_implementations',
  })

  -- <leader>lt  — Type definitions
  vim.keymap.set('n', '<leader>lt', function()
    if client.server_capabilities.typeDefinitionProvider then
      vim.ui.picker.lsp_type_definitions()
    else
      missing 'typeDefinitionProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.find_type_definitions',
  })

  -- <leader>lci — incoming Calls (mnemonic: c for calls, i for incoming)
  vim.keymap.set('n', '<leader>lci', function()
    if client.server_capabilities.callHierarchyProvider then
      vim.ui.picker.lsp_incoming_calls()
    else
      missing 'callHierarchyProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.find_incoming_calls',
  })

  -- <leader>lco — outgoing Calls (mnemonic: c for calls, o for outgoing)
  vim.keymap.set('n', '<leader>lco', function()
    if client.server_capabilities.callHierarchyProvider then
      vim.ui.picker.lsp_outgoing_calls()
    else
      missing 'callHierarchyProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.find_outgoing_calls',
  })

  -- ── Non-picker LSP actions (conditional) ────────────────────────

  -- gd — go to Definition (gd is a widely established default)
  vim.keymap.set('n', 'gd', function()
    if client.server_capabilities.definitionProvider then
      vim.lsp.buf.definition()
    else
      missing 'definitionProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.go_to_definition',
  })

  -- gD — go to Declaration (capital D, parallel to gd)
  vim.keymap.set('n', 'gD', function()
    if client.server_capabilities.declarationProvider then
      vim.lsp.buf.declaration()
    else
      missing 'declarationProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.go_to_declaration',
  })

  -- K — hover docs (K is the established vim default for keyword lookup)
  vim.keymap.set('n', 'K', function()
    if client.server_capabilities.hoverProvider then
      vim.lsp.buf.hover()
    else
      missing 'hoverProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.hover',
  })

  -- <leader>lh — signature Help (h for help; also available in insert mode)
  vim.keymap.set({ 'n', 'i' }, '<leader>lh', function()
    if client.server_capabilities.signatureHelpProvider then
      vim.lsp.buf.signature_help()
    else
      missing 'signatureHelpProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.signature_help',
  })

  -- <leader>ln — reName symbol
  vim.keymap.set('n', '<leader>ln', function()
    if client.server_capabilities.renameProvider then
      vim.lsp.buf.rename()
    else
      missing 'renameProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.rename',
  })

  -- <leader>la — code Actions (visual + normal for range actions)
  vim.keymap.set({ 'n', 'v' }, '<leader>la', function()
    if client.server_capabilities.codeActionProvider then
      vim.lsp.buf.code_action()
    else
      missing 'codeActionProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.code_action',
  })

  -- <leader>lI — toggle Inlay hints (capital I, distinct from implementations)
  local function toggle_inlay_hints() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = bufnr }, { bufnr = bufnr }) end

  vim.keymap.set('n', '<leader>lI', function()
    if client.server_capabilities.inlayHintProvider then
      toggle_inlay_hints()
    else
      missing 'inlayHintProvider'
    end
  end, {
    buffer = bufnr,
    silent = true,
    desc = 'language.toggle_inlay_hints',
  })
end

local M = {}

function M.setup()
  -- ── Picker capability extensions ───────────────────────────────
  -- Extend the 'picker' slot with LSP-specific finders via the capabilities system.
  -- These are added to vim.ui.picker.* automatically by env.capabilities.extend.
  env.capabilities.extend('picker', {
    lsp_references        = function(o) require('snacks').picker.lsp_references(o) end,
    lsp_definitions       = function(o) require('snacks').picker.lsp_definitions(o) end,
    lsp_implementations   = function(o) require('snacks').picker.lsp_implementations(o) end,
    lsp_type_definitions  = function(o) require('snacks').picker.lsp_type_definitions(o) end,
    lsp_document_symbols  = function(o) require('snacks').picker.lsp_symbols(o) end,
    lsp_workspace_symbols = function(o) require('snacks').picker.lsp_workspace_symbols(o) end,
    lsp_incoming_calls    = function(o) require('snacks').picker.lsp_incoming_calls(o) end,
    lsp_outgoing_calls    = function(o) require('snacks').picker.lsp_outgoing_calls(o) end,
  }, 'text_editing')
  -- ── Shared capabilities ───────────────────────────────────────
  local capabilities = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), require('blink.cmp').get_lsp_capabilities())

  local languages = require 'modules.text_editing.languages'
  -- ── Per-server setup ──────────────────────────────────────────
  for server_name, lsp in languages.iter_lsp_servers() do
    local config = vim.tbl_deep_extend('force', {
      capabilities = capabilities,
      on_attach = on_attach,
    }, lsp.config or {})

    -- Chain server-specific on_attach after shared one
    if lsp.config and lsp.config.on_attach then
      local server_on_attach = lsp.config.on_attach
      config.on_attach = function(client, bufnr)
        on_attach(client, bufnr)
        server_on_attach(client, bufnr)
      end
    end

    -- ── Adapt root_dir for native vim.lsp API ──────────────────
    -- Language specs use lspconfig convention: root_dir(fname) -> string|nil
    -- Neovim's native vim.lsp.config() passes root_dir(bufnr, on_dir) instead.
    -- Wrap the function to translate the signature so specs stay portable.
    if type(config.root_dir) == 'function' then
      local lspconfig_root_dir = config.root_dir
      config.root_dir = function(bufnr_arg, on_dir)
        local fname = vim.api.nvim_buf_get_name(bufnr_arg)
        local root = lspconfig_root_dir(fname)
        if root and on_dir then
          on_dir(root)
        end
        return root
      end
    end

    vim.lsp.config(server_name, config)
    vim.lsp.enable(server_name)
  end
  -- ── Global LSP articulation (non-buffer-local) ─────────────────
  -- Actions that operate across buffers or don't require
  -- an attached LSP client go here rather than in on_attach
  vim.keymap.set('n', '<leader>lR', '', {
    desc = 'language.restart_lsp_clients',
    silent = true,
    callback = function() vim.cmd 'lsp restart' end,
  })

  -- ── LspAttach autocmd: clean state on detach ───────────────────
  vim.api.nvim_create_autocmd('LspDetach', {
    group = vim.api.nvim_create_augroup('language_lsp_detach', { clear = true }),
    callback = function(event)
      -- Refresh server list immediately on detach
      -- The state provider fires on LspDetach but the client
      -- may still appear in get_clients() briefly; force an update
      vim.schedule(function() env.state._update('lsp.attached_servers', vim.lsp.get_clients { bufnr = event.buf }) end)
    end,
  })

  -- ── State providers ────────────────────────────────────────────
  -- Feed LSP state into env.state so consumers (statusline, pickers, conditions)
  -- read from a single source rather than calling vim.lsp.get_clients() directly.
  env.state.register_provider {
    id     = 'lsp.attached_servers',
    events = { 'LspAttach', 'LspDetach', 'BufEnter' },
    collect = function() return vim.lsp.get_clients { bufnr = 0 } end,
    desc   = 'LSP clients attached to the current buffer',
  }

  env.state.register_provider {
    id     = 'lsp.diagnostics',
    events = { 'DiagnosticChanged', 'BufEnter' },
    collect = function() return vim.diagnostic.get(0) end,
    desc   = 'Diagnostics for the current buffer',
  }

  env.state.register_provider {
    id     = 'lsp.current_symbol',
    events = { 'CursorHold' },
    collect = function()
      -- Symbol under cursor: treesitter first (fast, no RPC), LSP as fallback.
      local node = vim.treesitter.get_node()
      if node then
        local text = vim.treesitter.get_node_text(node, 0)
        if text and #text < 50 and text:match '^[%w_]+$' then return text end
      end
      return nil
    end,
    desc = 'Symbol name under cursor (for winbar context)',
  }

  env.state.register_provider {
    id     = 'lsp.capabilities',
    events = { 'LspAttach', 'LspDetach', 'BufEnter' },
    collect = function()
      local caps = {}
      for _, client in ipairs(vim.lsp.get_clients { bufnr = 0 }) do
        caps[client.name] = client.server_capabilities
      end
      return caps
    end,
    desc = 'Server capabilities map per attached LSP client',
  }
end

return M
