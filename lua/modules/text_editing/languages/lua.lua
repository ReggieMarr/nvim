-- lua/languages/lua.lua

---@type LanguageSpec
return {
  ft = 'lua',

  treesitter = {
    parsers = { 'lua', 'luadoc' },
  },

  lsp = {
    lua_ls = {
      install = true,
      config = {
        cmd = { 'lua-language-server' },
        settings = {
          Lua = {
            runtime = { version = 'LuaJIT' },
            workspace = {
              checkThirdParty = false,
              library = vim.list_extend(
                vim.api.nvim_get_runtime_file('', true),
                {
                  vim.fn.stdpath 'config' .. '/lua',
                  '${3rd}/luv/library',
                  '${3rd}/busted/library',
                }
              ),
            },
            completion = { callSnippet = 'Replace' },
            hint = {
              enable = true,
              arrayIndex = 'Disable',
              setType = true,
            },
            diagnostics = {
              globals = { 'vim' },
              disable = { 'missing-fields' },
            },
            telemetry = { enable = false },
            format = { enable = false },
          },
        },
      },
    },
  },

  formatters = {
    {
      name = 'stylua',
      -- mason_package defaults to name when absent
    },
  },
}
