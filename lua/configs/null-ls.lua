local present, null_ls = pcall(require, "null-ls")
if not present then
  return
end

local b = null_ls.builtins

-- Helper function to create sources from tools configuration
local function create_sources()
  local sources = {
    -- Always included sources
    b.diagnostics.todo_comments,
    b.diagnostics.trail_space,
    b.code_actions.ts_node_action,
    b.hover.dictionary,
    b.code_actions.refactoring,
  }

  return sources
end

null_ls.setup {
  debug = true,
  sources = create_sources(),
}
