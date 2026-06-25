-- lua/lib/display.lua
-- Registry for display contributions.
--
-- Modules call display.register() to declare what they add to the visible editor:
-- statusline segments, virtual text providers, sign column registrations, etc.
-- This makes the set of active display contributions greppable and auditable
-- via :ConfigStatus display.
--
-- Convention: register in setup(), not in the plugin spec.
-- Use descriptive IDs that reflect the module.component pattern.

local M = {}

---@class DisplaySpec
---@field id string        Dot-namespaced ID, e.g. "version_control.signs"
---@field kind string      'statusline' | 'virtual_text' | 'signs' | 'winbar' | 'diagnostic' | 'notification'
---@field module string    Registering module name
---@field desc? string     Human readable description of what this contributes

---@type table<string, DisplaySpec>
M._registry = {}

---Register a display contribution.
---@param spec DisplaySpec
function M.register(spec)
  vim.validate {
    id     = { spec.id,     'string' },
    kind   = { spec.kind,   'string' },
    module = { spec.module, 'string' },
  }
  if M._registry[spec.id] then
    vim.notify(
      string.format("[display] Duplicate id '%s' — overwriting previous registration", spec.id),
      vim.log.levels.WARN
    )
  end
  M._registry[spec.id] = spec
end

---Return all registered display contributions.
---@return table<string, DisplaySpec>
function M.get_registered()
  return vim.deepcopy(M._registry)
end

---Print a human-readable summary of display contributions.
function M.status()
  local lines = { '── Display ───────────────────────────────────────────' }

  if vim.tbl_isempty(M._registry) then
    table.insert(lines, '  (no display contributions registered)')
    vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
    return
  end

  -- Group by kind for readability
  local by_kind = {}
  for _, spec in pairs(M._registry) do
    by_kind[spec.kind] = by_kind[spec.kind] or {}
    table.insert(by_kind[spec.kind], spec)
  end

  local kinds = vim.tbl_keys(by_kind)
  table.sort(kinds)

  for _, kind in ipairs(kinds) do
    table.insert(lines, '  ● ' .. kind .. ':')
    local specs = by_kind[kind]
    table.sort(specs, function(a, b) return a.id < b.id end)
    for _, spec in ipairs(specs) do
      local desc = spec.desc and ('  — ' .. spec.desc) or ''
      table.insert(lines, string.format('    %-36s  [%s]%s', spec.id, spec.module, desc))
    end
  end

  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

return M
