-- lua/modules/text_editing/languages/c.lua
-- C and C++ language support.
--
-- Stack:
--   LSP:       clangd — background indexing, tidy, IWYU header insertion
--   Formatter: clang-format (only if .clang-format present in project tree)
--   Treesitter: c, cpp, cmake parsers + textobjects
--
-- Cross-compilation (x7 / embedded):
--   clangd reads compile_commands.json automatically. Generate it with:
--     cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON <build-dir>
--   or via bear/compiledb for Make-based projects.
--   For explicit cross-compiler override add a project-local .clangd:
--     CompileFlags:
--       Add: [--target=arm-none-eabi, --sysroot=/path/to/sysroot]
--
-- MISRA / static analysis:
--   clang-tidy runs via --clang-tidy. Project .clang-tidy or CMake presets
--   control which checks are enabled. For MISRA use clang-tidy-misra or
--   cppcheck (add as a future linter entry).
--
-- Doom alignment:
--   <leader>lo  switch header/source  (mirrors lsp-clangd-find-other-file)
--   <leader>ld  find definitions
--   <leader>lr  find references
--   <leader>la  code actions
--   All other LSP bindings inherited from lsp.lua on_attach.

return {
  ft = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },

  lsp = {
    clangd = {
      -- System-managed: /usr/bin/clangd — do not install via mason
      install = false,
      config = {
        cmd = {
          'clangd',
          '--all-scopes-completion',
          '--background-index',
          '--background-index-priority=normal',
          '--clang-tidy',
          '--completion-parse=auto',
          '--completion-style=detailed',
          '--function-arg-placeholders',
          '--header-insertion=iwyu',
          '--header-insertion-decorators',
          '--enable-config',       -- reads per-project .clangd file
          '--malloc-trim',         -- return memory to OS between requests
          '--pch-storage=memory',  -- faster than disk, more RAM usage
        },
        init_options = {
          clangdFileStatus       = true,
          usePlaceholders        = true,
          completeUnimported     = true,
          semanticHighlighting   = true,
        },
        root_dir = function(fname)
          return require('lspconfig.util').root_pattern(
            'compile_commands.json', -- cmake / bear / compiledb
            'compile_flags.txt',     -- simple single-directory projects
            '.clangd',               -- explicit clangd project config
            'CMakeLists.txt',
            'Makefile',
            '.git'
          )(fname)
        end,
        -- Server-specific on_attach: adds clangd-only operations.
        -- The shared on_attach in lsp.lua fires first (via chain in lsp.setup).
        on_attach = function(client, bufnr)
          -- Switch between header and source (.h ↔ .c/.cpp)
          -- Mirrors Doom's lsp-clangd-find-other-file bound to <leader>lo
          vim.keymap.set('n', '<leader>lo', function()
            vim.lsp.buf.execute_command {
              command   = 'clangd.switchSourceHeader',
              arguments = { vim.uri_from_bufnr(bufnr) },
            }
          end, {
            buffer = bufnr,
            silent = true,
            desc   = 'language.clangd_switch_header',
          })

          -- Enable inlay hints by default for C/C++ — type info is dense
          if client.server_capabilities.inlayHintProvider then
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
          end
        end,
      },
    },
  },

  formatters = {
    {
      name           = 'clang-format',
      mason_package  = 'clang-format',
      config = {
        -- Only apply clang-format when the project has opted in.
        -- This prevents imposing a style on supplier code or legacy repos.
        condition = function(_, ctx)
          return vim.fs.find(
            { '.clang-format', '_clang-format' },
            { path = ctx.filename, upward = true }
          )[1] ~= nil
        end,
      },
    },
  },

  treesitter = {
    parsers = { 'c', 'cpp', 'cmake' },
  },
}
