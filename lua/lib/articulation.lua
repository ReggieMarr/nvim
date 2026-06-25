-- lua/lib/articulation.lua
-- Action registry: modules register named actions with their keybindings.
--
-- Calling register() both:
--   1. Sets vim keymaps via vim.keymap.set() for every listed binding
--   2. Records the action for introspection via :ConfigStatus keys
--
-- Usage pattern:
--   Use vim.keymap.set() directly for simple global module-level keymaps.
--   Use articulation.register() for buffer-local or conditional actions that
--   need module attribution, clean lifecycle management, or call-hierarchy docs.
--
-- The desc convention (module.action_name) is consistent with global keymaps
-- so :ConfigStatus keys gives a unified view across both surfaces.

local M = {}

---@class ActionBinding
---@field lhs string              Key sequence, e.g. ']c' or '<leader>gs'
---@field mode? string|string[]   Vim mode(s). Defaults to 'n'.
---@field buffer? integer         Buffer handle for buffer-local maps.

---@class ActionSpec
---@field id string               Unique dot-namespaced ID, e.g. 'version_control.stage_hunk_42'
---@field handler function        The action implementation
---@field desc string             Human readable description (shown in which-key)
---@field module string           Registering module name
---@field bindings ActionBinding[] One or more keybindings for this action

---Internal store: id → ActionSpec
---Buffer-local actions use bufnr-suffixed ids so each buffer gets its own entry.
---@type table<string, ActionSpec>
M._actions = {}

---Register an action and set all its keymaps.
---@param spec ActionSpec
function M.register(spec)
  vim.validate {
    id       = { spec.id,       'string'   },
    handler  = { spec.handler,  'function' },
    desc     = { spec.desc,     'string'   },
    module   = { spec.module,   'string'   },
    bindings = { spec.bindings, 'table'    },
  }

  M._actions[spec.id] = spec

  -- Set keymaps for each binding
  for _, binding in ipairs(spec.bindings) do
    local mode = binding.mode or 'n'
    local opts = {
      desc     = spec.desc,
      silent   = true,
      callback = spec.handler,
    }
    if binding.buffer then opts.buffer = binding.buffer end
    -- vim.keymap.set handles both string and table modes natively
    vim.keymap.set(mode, binding.lhs, spec.handler, opts)
  end
end

---Return registered actions, optionally filtered.
---@param opts? { module?: string }
---@return ActionSpec[]
function M.get_actions(opts)
  opts = opts or {}
  local result = {}
  for _, action in pairs(M._actions) do
    if opts.module and action.module ~= opts.module then goto continue end
    table.insert(result, action)
    ::continue::
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

---Print a human-readable summary of registered actions, grouped by module.
function M.status()
  local lines = { '── Articulation ──────────────────────────────────────' }

  if vim.tbl_isempty(M._actions) then
    table.insert(lines, '  (no actions registered)')
    table.insert(lines, '  Note: global keymaps with desc fields are visible via :ConfigStatus state')
    vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
    return
  end

  -- Group by module
  local by_module = {}
  for _, action in pairs(M._actions) do
    by_module[action.module] = by_module[action.module] or {}
    table.insert(by_module[action.module], action)
  end

  local module_names = vim.tbl_keys(by_module)
  table.sort(module_names)

  for _, mod in ipairs(module_names) do
    -- Deduplicate actions that were registered multiple times (one per buffer)
    -- by stripping the trailing _NNN bufnr suffix for display purposes.
    local seen_base = {}
    local display_actions = {}
    for _, action in ipairs(by_module[mod]) do
      local base = action.id:gsub('_%d+$', '')
      if not seen_base[base] then
        seen_base[base] = true
        table.insert(display_actions, { action = action, base = base })
      end
    end
    table.sort(display_actions, function(a, b) return a.base < b.base end)

    table.insert(lines, '  ■ ' .. mod .. ' (' .. #display_actions .. ' actions)')
    for _, entry in ipairs(display_actions) do
      local action = entry.action
      local bindings_str = vim.tbl_map(function(b)
        local mode = type(b.mode) == 'table'
          and table.concat(b.mode, '/')
          or (b.mode or 'n')
        local buf_flag = b.buffer and '*' or ''
        return mode .. ':' .. b.lhs .. buf_flag
      end, action.bindings)
      table.insert(lines, string.format(
        '    %-44s  %s',
        entry.base,
        table.concat(bindings_str, '  ')
      ))
      table.insert(lines, '      ' .. action.desc)
    end
  end

  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

return M
