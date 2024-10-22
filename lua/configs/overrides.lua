local M = {}

M.treesitter = {
  ensure_installed = {
    -- defaults
    "vim",
    "lua",
    -- web dev
    "html",
    "css",
    "javascript",
    "typescript",
    "tsx",
    "json",
    -- "vue", "svelte",
    -- Systems programming
    "c",
    "cpp",
    "cmake",
    "rust",
    -- Note
    "org",
    "markdown",
    "markdown_inline",
    -- Script
    "bash",
    "cmake",
    "python",
  },
  indent = {
    enable = true,
    -- disable = {
    --   "python"
    -- },
  },
}

M.mason = {
  install_root_dir = os.getenv "HOME" .. "/.local/share/nvim/mason/",
  ensure_installed = {
    -- lua stuff
    "lua-language-server",
    "stylua",

    -- web dev stuff
    "css-lsp",
    "html-lsp",
    "typescript-language-server",
    "deno",
    "prettier",

    -- c/cpp stuff
    "clangd",
    "clang-format",

    -- Rust stuff
    "rust-analyzer",

    -- Shell stuff
    "shellcheck",
    "shfmt",

    -- Python
    -- TODO: Remove mason-dap-install plugin and use the default
    "black",
    "debugpy",
  },
}

-- git support in nvimtree
M.nvimtree = {
  git = {
    enable = true,
  },

  renderer = {
    highlight_git = true,
    icons = {
      show = {
        git = true,
      },
    },
  },
}

return M
