-- lua/lib/capabilities.lua
-- Runtime capability extension registry.
--
-- Modules extend named capability slots with methods.
-- env.use(slot) returns the merged capability object.
-- env.capabilities.extend(slot, methods, module) both registers for introspection
-- AND writes into vim.ui.picker (for the 'picker' slot) so all existing
-- vim.ui.picker.xxx call-sites continue to work.
--
-- Built-in slots: 'picker', 'notifier'
-- The picker slot is special: env.use('picker') returns vim.ui.picker directly.
-- All other slots return the merged M._objects[slot] table.
--
-- Status: :ConfigStatus capabilities  →  shows slot/method/module attribution
--         plus a live LSP capability snapshot for the current buffer.

local M = {}

---@class CapabilityEntry
---@field method string
---@field handler function
---@field module string  Registering module name

---Internal registry: slot → ordered list of entries (later overwrites earlier)
---@type table<string, CapabilityEntry[]>
M._entries = {}

---Merged capability objects — rebuilt on each extend call.
---For the 'picker' slot this is not used directly (vim.ui.picker is canonical).
---@type table<string, table>
M._objects = {}

---Extend a named capability slot with additional methods.
---Methods are merged into the slot's object; later calls shadow earlier ones.
---For the 'picker' slot, methods are also written into vim.ui.picker so that
---existing vim.ui.picker.xxx call-sites and core/pickers.lua fallbacks still work.
---@param slot string           Capability slot name (e.g. 'picker', 'notifier')
---@param methods table<string, function>
---@param module_name string    Registering module (for attribution in status())
function M.extend(slot, methods, module_name)
  M._entries[slot] = M._entries[slot] or {}
  M._objects[slot] = M._objects[slot] or {}

  for name, fn in pairs(methods) do
    table.insert(M._entries[slot], { method = name, handler = fn, module = module_name or 'unknown' })
    -- Last-write wins in the merged object
    M._objects[slot][name] = fn

    -- Picker slot: keep vim.ui.picker in sync so both APIs work
    if slot == 'picker' and vim.ui and vim.ui.picker then
      vim.ui.picker[name] = fn
    end
  end
end

---Return the merged capability object for a slot.
---For the 'picker' slot this is vim.ui.picker (the canonical table).
---Returns an empty table (not nil) for unknown slots.
---@param slot string
---@return table
function M.get(slot)
  if slot == 'picker' and vim.ui and vim.ui.picker then
    return vim.ui.picker
  end
  return M._objects[slot] or {}
end

---List all registered slot names.
---@return string[]
function M.slots()
  return vim.tbl_keys(M._entries)
end

---Print a human-readable summary of capability registrations and live LSP state.
function M.status()
  local lines = { '── Capabilities ──────────────────────────────────────' }

  -- ── Registered slots ──────────────────────────────────────────
  if vim.tbl_isempty(M._entries) then
    table.insert(lines, '  (no capability slots registered)')
  else
    local slot_names = vim.tbl_keys(M._entries)
    table.sort(slot_names)

    for _, slot in ipairs(slot_names) do
      table.insert(lines, '  ● ' .. slot)
      -- Only show the winning (latest) entry per method name
      local by_method = {}
      for _, entry in ipairs(M._entries[slot]) do
        by_method[entry.method] = entry
      end
      local methods = vim.tbl_keys(by_method)
      table.sort(methods)
      for _, method in ipairs(methods) do
        local e = by_method[method]
        table.insert(lines, string.format('    %-32s  [%s]', method, e.module))
      end
    end
  end

  -- ── Live LSP snapshot for current buffer ─────────────────────
  table.insert(lines, '')
  table.insert(lines, '  LSP clients (buf=' .. vim.api.nvim_get_current_buf() .. '):')
  local ok, clients = pcall(vim.lsp.get_clients, { bufnr = 0 })
  if not ok or #clients == 0 then
    table.insert(lines, '    (none attached)')
  else
    for _, client in ipairs(clients) do
      local caps = client.server_capabilities or {}
      local flags = {}
      if caps.hoverProvider              then table.insert(flags, 'hover') end
      if caps.completionProvider         then table.insert(flags, 'completion') end
      if caps.definitionProvider         then table.insert(flags, 'definition') end
      if caps.referencesProvider         then table.insert(flags, 'references') end
      if caps.renameProvider             then table.insert(flags, 'rename') end
      if caps.codeActionProvider         then table.insert(flags, 'code-action') end
      if caps.inlayHintProvider          then table.insert(flags, 'inlay-hints') end
      if caps.documentFormattingProvider then table.insert(flags, 'format') end
      if caps.semanticTokensProvider     then table.insert(flags, 'sem-tokens') end
      if caps.callHierarchyProvider      then table.insert(flags, 'call-hierarchy') end
      table.insert(lines, string.format(
        '    [%d] %-22s  %s',
        client.id, client.name, #flags > 0 and table.concat(flags, '  ') or '(no caps)'
      ))
    end
  end

  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end

return M
