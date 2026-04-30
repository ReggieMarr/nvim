-- lua/plugins/treesitter.lua
local languages = require 'languages'

-- Parsers not tied to a specific language workflow:
-- tooling, markup, config formats that every project uses.
local universal_parsers = {
  'vim', 'vimdoc',
  'markdown', 'markdown_inline',
  'bash',
  'json', 'jsonc',
  'toml', 'yaml',
  'regex',
}

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
    config = function()
      require('nvim-treesitter').setup {
        install_dir = vim.fn.stdpath 'data' .. '/site',
      }

      -- Single source of truth: language specs + universal set
      local language_parsers = languages.get_treesitter_parsers()
      local all_parsers = vim.tbl_keys(
        vim.tbl_extend('keep',
          vim.tbl_map(function() return true end,
            vim.iter(universal_parsers):totable()),
          vim.tbl_map(function() return true end,
            vim.iter(language_parsers):totable())
        )
      )
      -- simpler dedup:
      local seen, parsers = {}, {}
      for _, p in ipairs(universal_parsers) do
        if not seen[p] then seen[p] = true; table.insert(parsers, p) end
      end
      for _, p in ipairs(language_parsers) do
        if not seen[p] then seen[p] = true; table.insert(parsers, p) end
      end

      require('nvim-treesitter').install(parsers)

      vim.api.nvim_create_autocmd('FileType', {
        callback = function() pcall(vim.treesitter.start) end,
      })
    end,

    -- Textobject keymaps, highlight config, etc. live here in opts
    -- and are passed to the old-api setup if you use it, or configured
    -- via the module directly. Keep them here as they are generic,
    -- not language-specific.
    opts = {
      highlight = {
        enable = true,
        disable = function(_, buf)
          local max = 1.5 * 1024 * 1024
          local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
          return ok and stats and stats.size > max
        end,
      },
      indent = { enable = false },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = '<C-space>',
          node_incremental = '<C-space>',
          scope_incremental = '<C-S-space>',
          node_decremental = '<BS>',
        },
      },
      textobjects = {
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            ['af'] = '@function.outer',
            ['if'] = '@function.inner',
            ['ac'] = '@class.outer',
            ['ic'] = '@class.inner',
            ['aa'] = '@parameter.outer',
            ['ia'] = '@parameter.inner',
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            [']f'] = '@function.outer',
            [']c'] = '@class.outer',
          },
          goto_previous_start = {
            ['[f'] = '@function.outer',
            ['[c'] = '@class.outer',
          },
        },
      },
    },
  },

  {
    'nvim-treesitter/nvim-treesitter-context',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      enable = true,
      max_lines = 4,
      trim_scope = 'outer',
      mode = 'cursor',
      separator = '─',
    },
  },
}
