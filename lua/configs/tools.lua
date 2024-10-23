-- tools.lua
return {
  -- Formatters
  formatters = {
    lua = {
      "stylua",
    },
    shell = {
      "shfmt",
    },
    cpp = {
      "clang-format",
    },
    python = {
      "black",
    },
    markdown = {
      "deno_fmt",
    },
    json = {
      "fixjson",
    },
    toml = {
      "taplo",
    },
    cmake = {
      "cmake_format",
    },
    rust = {
      "rustfmt",
    },
  },

  -- LSP Servers
  lsp = {
    "lua-language-server",
    "clangd",
    "rust-analyzer",
    "pyright",
    "cmake-language-server",
  },

  -- Linters & Diagnostics
  linters = {
    general = {
      "codespell",
      "cspell",
    },
    git = {
      "gitlint",
    },
    markdown = {
      "alex",
      "write-good",
      "textidote",
      "textlint",
      "markdownlint",
      "proselint",
    },
    cpp = {
      "cppcheck",
    },
    cmake = {
      "cmake-lint",
    },
    python = {
      "ruff",
    },
  },

  -- Debug Adapters
  dap = {
    python = {
      "debugpy",
    },
  },
}
