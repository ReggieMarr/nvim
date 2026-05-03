-- lua/modules/languages/init.lua

---@class LspSpec
---@field mason_name? string         Mason registry name if different from lspconfig key
---@field install boolean            Whether mason should ensure this is installed
---@field config table               vim.lsp.config() options (cmd, settings, root_dir, etc.)

---@class FormatterSpec
---@field name string                conform.nvim formatter name
---@field mason_package? string      Mason package to install (if different from name)
---@field config? table              conform formatter config table (condition, etc.)

---@class TreesitterSpec
---@field parsers string[]           Parser names to install
---@field textobjects? table         Language-specific textobject overrides (future use)

---@class LanguageSpec
---@field ft string|string[]         Filetype(s) this spec applies to
---@field lsp? table<string, LspSpec>  Keyed by lspconfig server name
---@field formatters? FormatterSpec[]  In priority order for conform
---@field treesitter? TreesitterSpec
---@field linters? string[]          Future: nvim-lint package names
---
-- Explicit registration: no magic directory scanning,
-- load order is intentional and greppable.
local specs = {
  require 'modules.text_editing.languages.lua',
  require 'modules.text_editing.languages.python',
  -- require 'languages.go',
  -- require 'languages.rust',
}

local M = {}

-- Parsers not tied to a specific language workflow:
-- tooling, markup, config formats that every project uses.
M.universal_parsers = {
  'vim',
  'vimdoc',
  'markdown',
  'markdown_inline',
  'bash',
  'json',
  'toml',
  'yaml',
  'regex',
}
-- ── Internal helpers ────────────────────────────────────────────────

--- Normalize ft field to always be a list
---@param ft string|string[]
---@return string[]
local function ft_list(ft) return type(ft) == 'string' and { ft } or ft end

-- ── Public query API ────────────────────────────────────────────────

--- Returns flat list of all LSP server names that should be mason-installed.
--- Used by mason-lspconfig ensure_installed.
---@return string[]
function M.get_mason_lsp_packages()
  local names = {}
  for _, spec in ipairs(specs) do
    for server, lsp in pairs(spec.lsp or {}) do
      if lsp.install then table.insert(names, lsp.mason_name or server) end
    end
  end
  return names
end

--- Returns flat list of mason tool packages for formatters/linters.
--- Deduplicates. mason_package = false means "skip mason install".
---@return string[]
function M.get_mason_tool_packages()
  local seen, names = {}, {}
  for _, spec in ipairs(specs) do
    for _, fmt in ipairs(spec.formatters or {}) do
      -- mason_package = false: tool ships with an LSP (e.g. ruff)
      -- mason_package = nil:   default to formatter name
      local pkg = fmt.mason_package
      if pkg ~= false then
        pkg = pkg or fmt.name
        if not seen[pkg] then
          seen[pkg] = true
          table.insert(names, pkg)
        end
      end
    end
  end
  return names
end

--- Returns all treesitter parsers across all language specs, deduplicated.
---@return string[]
function M.get_treesitter_parsers()
  local seen, parsers = {}, {}
  for _, spec in ipairs(specs) do
    for _, parser in ipairs((spec.treesitter or {}).parsers or {}) do
      if not seen[parser] then
        seen[parser] = true
        table.insert(parsers, parser)
      end
    end
  end
  return parsers
end

--- Returns conform.nvim formatters_by_ft table.
--- Keys are filetypes, values are ordered lists of formatter names.
---@return table<string, string[]>
function M.get_formatters_by_ft()
  local by_ft = {}
  for _, spec in ipairs(specs) do
    if spec.formatters and #spec.formatters > 0 then
      local names = vim.tbl_map(function(f) return f.name end, spec.formatters)
      for _, ft in ipairs(ft_list(spec.ft)) do
        by_ft[ft] = names
      end
    end
  end
  return by_ft
end

--- Returns conform.nvim formatters config table (the per-formatter settings).
---@return table<string, table>
function M.get_conform_formatter_configs()
  local configs = {}
  for _, spec in ipairs(specs) do
    for _, fmt in ipairs(spec.formatters or {}) do
      if fmt.config then configs[fmt.name] = fmt.config end
    end
  end
  return configs
end

--- Returns iterator of (server_name, lsp_spec) pairs across all language specs.
--- Used by the LSP setup loop.
---@return fun(): string, LspSpec
function M.iter_lsp_servers()
  local items = {}
  for _, spec in ipairs(specs) do
    for server, lsp in pairs(spec.lsp or {}) do
      table.insert(items, { server, lsp })
    end
  end
  local i = 0
  return function()
    i = i + 1
    if items[i] then return items[i][1], items[i][2] end
  end
end

return M
