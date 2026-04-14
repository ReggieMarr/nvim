-- lua/lib/display.lua
-- Display contribution registry.
--
-- Scope for this initial implementation:
--   - Namespace management (each contributor gets an isolated extmark namespace)
--   - Conditional registration (when conditions evaluated against env.state)
--   - Display contribution metadata for introspection
--
-- What this does NOT own yet:
--   - Rendering itself (plugins still handle that)
--   - Statusline composition (lualine/heirline own that)
--   - Float window management
--
-- The practical value right now: the `when` condition system lets modules
-- declare "this display element should only be active when X" without
-- each plugin implementing its own condition logic.

---@class DisplayLib
local M = {}

---@type table<string, DisplayContribution>
M._contributions = {}

---@type table<string, integer> contribution_id -> namespace handle
M._namespaces = {}

---@class DisplayContribution
---@field id string Dot-namespaced identifier e.g. "version_control.git_signs"
---@field module string Module that registered this
---@field region DisplayRegion Where this contribution renders
---@field when? fun(state: table): boolean Condition for activation
---@field priority? number Z-order when multiple contributions share a region
---@field on_enable? fun() Called when condition becomes true
---@field on_disable? fun() Called when condition becomes false
---@field desc? string Human readable description

---@alias DisplayRegion
---| "signs"          # Signs column
---| "virtual_text"   # Inline virtual text
---| "statusline"     # Status line
---| "winbar"         # Window bar
---| "float"          # Floating windows
---| "highlight"      # Buffer highlights
---| "notification"   # Notification area
---| "cmdline"        # Command line area

---Register a display contribution.
---@param spec DisplayContribution
function M.register(spec)
  vim.validate {
    id = { spec.id, 'string' },
    module = { spec.module, 'string' },
    region = { spec.region, 'string' },
  }

  if M._contributions[spec.id] then vim.notify(string.format("[display] Duplicate contribution: '%s'", spec.id), vim.log.levels.WARN) end

  -- Allocate a private namespace for this contributor's extmarks
  -- Converts dots to underscores for valid namespace naming
  local ns_name = 'env_display_' .. spec.id:gsub('%.', '_')
  M._namespaces[spec.id] = vim.api.nvim_create_namespace(ns_name)

  spec.priority = spec.priority or 100
  M._contributions[spec.id] = spec

  -- If a when condition is provided, set up evaluation on state changes
  if spec.when then M._watch_condition(spec) end
end

---Watch a contribution's condition and call on_enable/on_disable on transitions.
---@param spec DisplayContribution
function M._watch_condition(spec)
  local last_state = nil

  local augroup_name = 'env_display_' .. spec.id:gsub('%.', '_')
  local augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })

  -- Re-evaluate on any event that might change state
  -- Using a broad set here; can be narrowed per contribution if needed
  vim.api.nvim_create_autocmd({
    'BufEnter',
    'WinEnter',
    'FileType',
    'LspAttach',
    'LspDetach',
    'DiagnosticChanged',
  }, {
    group = augroup,
    callback = function()
      local state = require('lib.state').snapshot()
      local ok, result = pcall(spec.when, state)
      if not ok then return end

      local new_state = result == true

      if new_state ~= last_state then
        last_state = new_state
        if new_state and spec.on_enable then
          pcall(spec.on_enable)
        elseif not new_state and spec.on_disable then
          pcall(spec.on_disable)
        end
      end
    end,
  })
end

---Get the extmark namespace handle for a contribution.
---Plugin configs use this to write to the correct namespace.
---@param contribution_id string
---@return integer|nil
function M.get_namespace(contribution_id) return M._namespaces[contribution_id] end

---Clear all extmarks for a contribution in a given buffer.
---@param contribution_id string
---@param bufnr? number Defaults to current buffer
function M.clear(contribution_id, bufnr)
  local ns = M._namespaces[contribution_id]
  if not ns then return end
  vim.api.nvim_buf_clear_namespace(bufnr or 0, ns, 0, -1)
end

---Introspection
function M.status()
  local lines = { '# Display Registry', string.rep('─', 50), '' }

  -- Group by region
  local by_region = {}
  for _, contrib in pairs(M._contributions) do
    by_region[contrib.region] = by_region[contrib.region] or {}
    table.insert(by_region[contrib.region], contrib)
  end

  local regions = vim.tbl_keys(by_region)
  table.sort(regions)

  for _, region in ipairs(regions) do
    table.insert(lines, '## ' .. region)
    local contribs = by_region[region]
    table.sort(contribs, function(a, b) return (a.priority or 100) > (b.priority or 100) end)

    for _, contrib in ipairs(contribs) do
      table.insert(lines, string.format('  [%3d] %s', contrib.priority or 100, contrib.id))
      if contrib.desc then table.insert(lines, string.format('        %s', contrib.desc)) end

      -- Evaluate current condition state
      if contrib.when then
        local state = require('lib.state').snapshot()
        local ok, result = pcall(contrib.when, state)
        local status = ok and (result and '✓ active' or '○ inactive') or '! error'
        table.insert(lines, string.format('        condition: %s', status))
      else
        table.insert(lines, '        condition: always active')
      end
    end
    table.insert(lines, '')
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].modifiable = false
  vim.cmd 'vsplit'
  vim.api.nvim_win_set_buf(0, buf)
end

---@return DisplayLib
return M
