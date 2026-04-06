# Neovim Configuration

A modular Neovim configuration built around explicit feature flags, dependency
declaration, and a formal interface layer designed to support both human and
AI agent interaction with the editor.

## Design Goals

- **Modularity** — features can be enabled or disabled in isolation
- **Consistency** — all picking, searching, and navigation uses a single unified UI
- **Introspection** — the running state of the config is queryable at any time
- **Agent readiness** — the editor exposes a stable, structured action surface for AI agent articulation
- **Explicitness** — dependencies, capabilities, and keymaps are declared, not implied

---

## Directory Structure

```
~/.config/nvim/
├── init.lua                 # Entry point: feature flags, bootstrap, module loading
├── lua/
│   ├── base.lua             # Options, global keymaps, autocmds (no plugin deps)
│   ├── lib/
│   │   ├── module.lua       # Module registration, dependency resolution, lifecycle
│   │   ├── keys.lua         # Keymap registration, conflict detection, action registry
│   │   ├── capabilities.lua # Capability registration and interface validation
│   │   ├── state.lua        # Editor state observation for agent context
│   │   └── agent.lua        # Formal agent interface, tool registry, plan execution
│   └── modules/
│       ├── interface.lua    # UI chrome: statusline, colorscheme, notifications
│       ├── navigation.lua   # Fuzzy finding, picking, search consistency layer
│       ├── language.lua     # LSP, treesitter, completion, formatting, diagnostics
│       ├── version_control.lua # Git signs, blame, diff, conflict resolution
│       ├── execution.lua    # Terminals, build runners, test runners
│       ├── system.lua       # File system, OS integration
│       └── project.lua      # External services: issue trackers, project management
```

---

## Core Concepts

### Feature Flags

Features are declared as a table in `init.lua` and exposed as an immutable
global. This is the single source of truth for what is active in the config.

```lua
local features = {
  interface       = true,
  navigation      = true,
  language        = true,
  version_control = true,
  execution       = true,
  system          = true,
  project         = false, -- disabled
}
```

Toggling a feature disables all modules that belong to it and prevents their
plugins from being passed to lazy. Disabled features still appear in
`:ConfigStatus modules` so you can see the full picture.

---

### Modules

A module is a single `.lua` file in `lua/modules/`. Each module:

- Belongs to exactly one feature flag
- Declares its hard dependencies on other modules
- Declares its optional dependencies
- Organizes its plugin specs into `display` and `articulation` categories

```lua
-- lua/modules/example.lua
local module = require("lib.module")
local keys   = require("lib.keys")
local caps   = require("lib.capabilities")

module.register({
  name       = "example",
  feature    = "navigation",  -- maps to features.navigation
  depends_on = { "interface" },
  optional_deps = { "language" },

  -- Plugins whose primary concern is rendering information
  display = {
    { "author/plugin.nvim", opts = {} },
  },

  -- Plugins and keymaps whose primary concern is interaction
  articulation = {
    {
      "author/plugin.nvim",
      keys = (function()
        keys.map_group("example", {
          {
            lhs  = "<leader>ex",
            rhs  = function() end,
            desc = "Example action",
          },
        })
        return {}
      end)(),
    },
  },
})
```

#### Display vs Articulation

Every module organizes its plugin specs into two categories:

| Category | Concern | Examples |
|---|---|---|
| `display` | Rendering information passively | Statusline, git signs, diagnostics virtual text, colorscheme |
| `articulation` | Acting on or with information | Keymaps, pickers, commands, UI interactions |

Some plugins serve both concerns. Place them under whichever is their
*primary* concern and document exceptions with a comment. Infrastructure
plugins with no clear primary concern belong in `providers`.

This distinction is organizational — lazy receives a flat list of all specs
regardless of category.

---

### Dependencies

Modules declare dependencies explicitly. The module system validates the
dependency graph before lazy loads any plugins.

```lua
module.register({
  name       = "language",
  feature    = "language",
  depends_on = { "navigation" },  -- hard: must be present and enabled
  optional_deps = { "interface" }, -- soft: degrades gracefully without
  ...
})
```

**Hard dependencies** (`depends_on`) — if a required module is missing or
its feature is disabled, `validate()` reports an error at startup.

**Optional dependencies** (`optional_deps`) — if an optional module is
unavailable, an info notification is emitted and the module loads with
reduced functionality.

Load order is resolved automatically via topological sort of the dependency
graph. You do not need to manually order module files.

---

### Capabilities

Capabilities are the mechanism for enforcing a consistent UI across all
features. Rather than each module calling its own picker or notification
system, modules register what they provide and consumers retrieve it by name.

```lua
-- A module registers a capability once
caps.register("picker", {
  find_files   = function(opts) ... end,
  live_grep    = function(opts) ... end,
  find_buffers = function(opts) ... end,
  ...
}, "navigation")

-- Any other module retrieves it without knowing the implementation
local picker = caps.require("picker")
picker.find_files()
```

This is what ensures that finding files, buffers, LSP references, git
commits, and test results all use the same UI and the same keybinding
grammar, regardless of which plugin is providing them.

#### Known Capability Interfaces

The following capability interfaces are defined and validated:

| Name | Provider Module | Purpose |
|---|---|---|
| `picker` | `navigation` | Unified fuzzy finding and list UI |
| `filesystem` | `system` | File tree and file operations |
| `notifier` | `interface` | Notifications and progress reporting |
| `terminal` | `execution` | Terminal management |
| `task_runner` | `execution` | Build and test execution |

Capabilities not in this table are valid but receive no interface validation.
See `lib/capabilities.lua` for the full interface definitions.

---

### Keymaps

All keymaps are registered through `lib/keys.lua`. Direct calls to
`vim.keymap.set()` are avoided outside of `lib/` itself.

```lua
keys.map_group("navigation", {
  {
    lhs  = "<leader>ff",
    rhs  = function() caps.require("picker").find_files() end,
    desc = "Find files",
    when = function() return true end, -- optional precondition for agents
  },
})
```

Registering through `lib/keys.lua` provides:

- **Conflict detection** — duplicate keymaps emit a warning with attribution
- **Description enforcement** — keymaps without descriptions are rejected
- **Action registry** — every global keymap is automatically addressable by
  AI agents via a composed ID (`module.description_as_snake_case`)
- **Introspection** — all keymaps queryable via `:ConfigStatus keys`

#### Keymap Grammar

| Prefix | Domain |
|---|---|
| `<leader>f` | Find (pickers, search) |
| `<leader>b` | Buffers |
| `<leader>g` | Git |
| `<leader>l` | LSP |
| `<leader>t` | Tasks |
| `<leader>p` | Project |
| `<leader>c` | Config |

---

### Agent Interface

The config exposes a structured interface for AI agent articulation via
`lib/agent.lua`. Agents interact with the editor through three mechanisms:

**Action execution** — agents invoke any registered keymap action by its
stable ID without needing to know the keybinding:

```lua
-- ID is composed automatically from module name and description
-- "navigation" + "Find files" -> "navigation.find_files"
require("lib.keys").execute("navigation.find_files")
```

**Plan execution** — agents submit an ordered sequence of actions with
a failure policy:

```lua
require("lib.agent").execute_plan({
  on_failure = "rollback", -- or "stop" or "continue"
  steps = {
    { action_id = "lsp.go_to_definition" },
    { action_id = "lsp.show_diagnostics" },
  },
})
```

**Tool registration** — modules expose higher-level, parameterized
operations beyond individual keymaps:

```lua
require("lib.agent").register_tool({
  name        = "fix_diagnostics",
  description = "Apply LSP code actions to fix auto-fixable diagnostics",
  parameters  = {
    severity = { type = "string", enum = { "error", "warning", "all" } },
  },
  execute = function(params) ... end,
})
```

Tool schemas are available in OpenAI/Anthropic function calling format via
`require("lib.agent").get_tool_schemas()`.

---

## Introspection

The running state of the config is fully queryable. All introspection
commands open a markdown-formatted scratch buffer.

| Command | Description |
|---|---|
| `:ConfigStatus modules` | Module registry, feature flags, load order, dependency errors |
| `:ConfigStatus keys` | All registered keymaps grouped by module |
| `:ConfigStatus capabilities` | Registered capabilities and interface conformance |
| `:ConfigStatus agent` | Registered tools and agent audit log |
| `:ConfigStatus` | All of the above |

---

## Adding a New Module

1. Create `lua/modules/yourmodule.lua`
2. Call `module.register()` with your spec
3. Add the module file to the load list in `init.lua`
4. Register any capabilities your module provides
5. Register keymaps through `keys.map_group()`

The module system will validate your dependency declarations at startup and
include your plugin specs in the lazy setup automatically.

## Enabling and Disabling Features

Edit the `features` table in `init.lua`:

```lua
local features = {
  project = true, -- was false
}
```

Restart Neovim. The module system will include or exclude all modules
belonging to that feature and validate the dependency graph with the
new configuration.

---

## Library Reference

| Module | Purpose |
|---|---|
| `lib/module.lua` | Module registration, DAG validation, plugin spec collection |
| `lib/keys.lua` | Keymap registration, conflict detection, action registry |
| `lib/capabilities.lua` | Capability registration, interface validation, adapter layer |
| `lib/state.lua` | Snapshot editor state for agent context and observation |
| `lib/agent.lua` | Agent interface, plan execution, tool registry |

---

## Design Influences

- **Doom Emacs** — feature flag system, module organization, and the principle
  that a consistent UI matters more than flexibility in individual components
- **Hexagonal Architecture** — the capability system acts as a ports-and-adapters
  layer between feature modules and their underlying implementations
- **CQRS** — the display/articulation split mirrors the command/query
  responsibility distinction; display is the read model, articulation is the
  write model
- **Language Server Protocol** — the agent interface is modeled on the idea
  of a formal protocol between the editor and an external process, rather
  than ad-hoc integration
