# Neovim Configuration

A modular Neovim configuration with explicit dependency declaration, an
observable state model, and a keymap grammar aligned with Doom Emacs. Built
for seamless context-switching between Emacs and Neovim.

## Design Goals

- **Modularity** — features are isolated into modules that declare their dependencies
- **Consistency with Doom Emacs** — same `SPC` leader grammar, same navigation model (file vs project), same git workflow (Magit-style via Neogit)
- **Introspection** — the running state is queryable at any time via `:ConfigStatus`
- **Observable state** — editor state is surfaced through registered providers, not ad-hoc globals
- **Language-spec-driven** — LSP servers, formatters, and treesitter parsers are declared per-language, not scattered across config

---

## Directory Structure

```
~/.config/nvim/
├── init.lua                          # Entry point: module manifest, lazy bootstrap
├── lua/
│   ├── env.lua                       # Single-import facade for all lib surfaces
│   ├── core/
│   │   ├── base_config.lua           # Vim options, global autocmds (no plugin deps)
│   │   └── pickers.lua               # Bootstraps vim.ui.picker table
│   ├── lib/
│   │   ├── module.lua                # Module registry, DAG resolution, plugin spec collection
│   │   ├── state.lua                 # Observable state model (providers → key/value store)
│   │   ├── capabilities.lua          # Runtime extension registry (picker, notifier, etc.)
│   │   ├── display.lua               # Display contribution registry (statusline, signs, vtext)
│   │   └── articulation.lua          # Action registry (keymaps with module attribution)
│   ├── modules/
│   │   ├── interface.lua             # UI: colorscheme, statusline, which-key, snacks, lualine
│   │   ├── introspection.lua         # Help/describe/inspect keymaps
│   │   ├── filesystem/
│   │   │   ├── init.lua              # Oil, mini.files, file/project pickers, path utils
│   │   │   ├── pickers.lua           # Custom Vertico-style file browser (mini.pick)
│   │   │   └── utils.lua             # File listing, icons, show functions for pickers
│   │   ├── text_editing/
│   │   │   ├── init.lua              # Treesitter, completion (blink.cmp), conform, diagnostics
│   │   │   ├── lsp.lua               # LSP client config, state providers, LSP pickers
│   │   │   ├── languages/
│   │   │   │   ├── init.lua          # Language spec registry + query API
│   │   │   │   ├── lua.lua           # lua_ls + stylua
│   │   │   │   ├── python.lua        # basedpyright + ruff
│   │   │   │   └── c.lua             # clangd + clang-format (x7-cavorite aligned)
│   │   │   ├── treesitter.lua        # Treesitter config helpers
│   │   │   └── pickers.lua           # Buffer-local picker utilities
│   │   ├── version_control.lua       # Neogit, gitsigns, codediff, SPC-g keymaps
│   │   └── workspace.lua             # Project root detection (LSP/marker), project name
│   └── utils/                        # Shared utilities (file browsing, git formatting)
├── tests/
│   ├── minimal_init.lua              # Headless test init (no plugins)
│   ├── run.sh                        # Test runner: ./tests/run.sh [spec_name]
│   └── spec/
│       ├── capabilities_spec.lua     # 7 tests
│       ├── state_spec.lua            # 7 tests
│       ├── articulation_spec.lua     # 6 tests
│       ├── language_spec.lua         # 23 tests (schema + query API)
│       └── plugin_deps_spec.lua      # 11 tests (require coverage)
```

---

## Module System

### Registration

Modules register with `env.module.register{}` and declare their name,
domain, hard dependencies, optional dependencies, plugin specs, and
a `setup()` function that runs after lazy loads plugins.

```lua
return env.module.register {
  name        = 'filesystem',
  domain      = 'filesystem',
  depends_on  = { 'interface' },
  optional_deps = {},
  plugins = { ... },
  setup = function() ... end,
}
```

### Module Manifest

The load list in `init.lua` is the single control surface:

```lua
local module_files = {
  'modules.interface',
  'modules.introspection',
  'modules.filesystem',
  'modules.text_editing',
  'modules.version_control',
  'modules.workspace',
}
```

Comment a line to disable that module. The module system validates the
dependency graph and collects merged plugin specs before handing off to lazy.

### Active Modules

| Module | Domain | Purpose |
|--------|--------|---------|
| `interface` | interface | Colorscheme, statusline (lualine), which-key, snacks.nvim |
| `introspection` | introspection | Help/describe/inspect pickers (`SPC h`, `SPC i`) |
| `filesystem` | filesystem | Oil, mini.files, file browser, project navigation |
| `text_editing` | text_editing | LSP, treesitter, completion, formatting, diagnostics |
| `version_control` | version_control | Neogit, gitsigns, codediff |
| `workspace` | workspace | Project root detection, project name state |

---

## Env Facade (`lua/env.lua`)

All lib surfaces are accessed through a single import:

```lua
local env = require 'env'

env.state             -- observable state (register_provider, get, _update)
env.module            -- module system (register, validate)
env.capabilities      -- runtime extension registry (extend, get, slots)
env.display           -- display contribution registry (register, status)
env.articulation      -- action registry with keymap setting (register, get_actions)
env.use('picker')     -- shorthand for env.capabilities.get('picker')
env.module_active(n)  -- check if module is loaded
env.domain_active(d)  -- check if any module in domain is loaded
```

---

## Keymap Grammar

Leader: `Space` · LocalLeader: `;`

Aligned with Doom Emacs. Where Doom uses `SPC`, Neovim uses `<leader>`.

| Prefix | Group | Key examples |
|--------|-------|-------------|
| `SPC f` | find | `ff` explorer, `fr` recent, `fn` notifications |
| `SPC s` | search | `sf` files, `sd` grep cwd, `sb` buffer lines, `sp` project grep |
| `SPC p` | project | `pf` project files, `pg` project grep |
| `SPC b` | buffers | `bb` picker, `bd` delete, `bo` close others, `bs` scratch |
| `SPC g` | git | `gg` status, `gc` commit, `gP` push, `gF` pull, `gs` stage hunk |
| `SPC l` | lsp | `ld` definition, `lr` references, `la` code action, `lo` switch h/c |
| `SPC h` | help/describe | `hh` help, `hk` keymaps, `hc` commands, `ha` autocmds |
| `SPC i` | inspect | `ii` inspect under cursor, `ih` highlight groups |
| `SPC w` | windows | `wh/j/k/l` navigate, `wv/ws` split, `wd` close, `wf` zoom |
| `SPC t` | tasks | *(reserved — execution module)* |
| `SPC u` | ui | `ul` line numbers, `uw` word highlight, `ud` diagnostics toggle |
| `SPC c` | config | *(reserved)* |
| `SPC x` | files (oil) | *(oil-specific)* |
| `]c`/`[c` | | Hunk navigation (gitsigns / diff mode) |
| `ih`/`ah` | | Hunk text objects (visual/operator) |

---

## Picker Architecture

Two picker backends coexist, each serving a distinct purpose:

| Backend | Used for | Why |
|---------|----------|-----|
| **snacks.picker** | All standard pickers (files, grep, help, keymaps, LSP symbols, git, diagnostics) | Modern, fast, centered `vertical` layout matching Doom's vertico+childframe |
| **mini.pick** | Custom file browser (`SPC f f`), buffer line search (`SPC s b`) | Exposes low-level mutation API (`set_picker_items`, `set_picker_query`) needed for the Vertico-style navigable directory explorer |

Both are configured with centered floating windows. snacks uses the
`vertical` layout preset; mini.pick uses a golden-ratio centered window
function.

---

## Language Specs

Language support is declared in `lua/modules/text_editing/languages/`. Each
spec file exports a `LanguageSpec` table:

```lua
-- lua/modules/text_editing/languages/c.lua
return {
  ft = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  lsp = {
    clangd = {
      install = false,  -- system binary, not mason
      config  = { cmd = { '/usr/bin/clangd', '--background-index', ... } },
    },
  },
  formatters = {
    { name = 'clang-format', mason_package = false, condition = function(ctx) ... end },
  },
  treesitter = { parsers = { 'c', 'cpp', 'cmake' } },
}
```

The query API in `languages/init.lua` aggregates across all specs:

| Function | Returns |
|----------|---------|
| `get_mason_lsp_packages()` | LSP servers to install via mason |
| `get_mason_tool_packages()` | Formatters/tools to install via mason |
| `get_treesitter_parsers()` | All parsers (language + universal) |
| `get_formatters_by_ft()` | Filetype → formatter list (feeds conform) |
| `get_conform_formatter_configs()` | Per-formatter config overrides |
| `iter_lsp_servers()` | Iterator over all (server, spec) pairs |

**Active specs:** Lua (lua_ls + stylua), Python (basedpyright + ruff), C/C++ (clangd + clang-format)

---

## State Providers

Modules register state providers that collect values on editor events.
All state is queryable via `env.state.get('key')`.

| Key | Module | Description |
|-----|--------|-------------|
| `workspace.cwd` | core | Current working directory |
| `workspace.root` | workspace | Project root (LSP → git → cwd) |
| `workspace.project_name` | workspace | Basename of project root |
| `vcs.branch` | version_control | Current git branch |
| `vcs.status` | version_control | Working tree status summary |
| `vcs.head_commit` | version_control | HEAD hash + message |
| `vcs.is_repo` | version_control | Whether cwd is a git repo |
| `vcs.hunk_count` | version_control | Changed hunks in current buffer |
| `lsp.attached_servers` | text_editing | List of attached LSP server names |
| `lsp.diagnostics` | text_editing | Diagnostic counts by severity |
| `lsp.current_symbol` | text_editing | Symbol under cursor (treesitter) |
| `lsp.capabilities` | text_editing | Aggregated LSP capabilities |
| `filesystem.tree_visible` | filesystem | Whether file tree is showing |

---

## Introspection

| Command | Description |
|---------|-------------|
| `:ConfigStatus` | Run all sub-commands |
| `:ConfigStatus modules` | Module registry, dependency graph, load order |
| `:ConfigStatus state` | All registered state providers and current values |
| `:ConfigStatus capabilities` | Capability slots, registered methods, LSP snapshot |
| `:ConfigStatus display` | Display contributions (statusline, signs, virtual text) |
| `:ConfigStatus keys` | All articulation-registered actions grouped by module |

---

## Testing

```bash
./tests/run.sh              # run all specs
./tests/run.sh capabilities  # run one spec by name
```

Tests run headlessly via `nvim --headless --noplugin`. They exercise lib/*
modules and pure data (language specs) without loading plugins.

| Spec | Tests | What it covers |
|------|-------|---------------|
| `capabilities_spec` | 7 | extend, get, shadowing, picker mirror to vim.ui.picker |
| `state_spec` | 7 | register, update, get, validation, pcall error guard |
| `articulation_spec` | 6 | register, keymap.set calls, multi-mode, validation, filtering |
| `language_spec` | 23 | Schema validation for all 3 language specs + query API |
| `plugin_deps_spec` | 11 | Every live require() has a matching plugin spec |

---

## Plugin Stack

| Category | Plugin | Purpose |
|----------|--------|---------|
| Picker | snacks.nvim | Standard pickers (vertical centered layout) |
| Picker | mini.pick | Custom file browser (low-level API) |
| Picker | mini.extra | Buffer-lines picker |
| Picker | fff.nvim | File search + live grep |
| Completion | blink.cmp | Completion engine (Tab/S-Tab/CR) |
| Formatting | conform.nvim | Format-on-save (language-spec driven) |
| LSP | mason + mason-tool-installer | LSP/tool installation |
| Treesitter | nvim-treesitter + textobjects + context | Syntax, navigation, sticky headers |
| Git | neogit | Magit-style git interface |
| Git | gitsigns.nvim | Sign column, blame, hunk operations |
| Git | codediff.nvim | Diff viewer |
| File mgmt | oil.nvim | Directory editor |
| File mgmt | mini.files | File explorer with preview |
| UI | lualine.nvim | Statusline (doom-modeline layout) |
| UI | which-key.nvim | Keymap hints |
| UI | tokyonight.nvim | Colorscheme (storm, transparent) |
| UI | mini.icons | File/symbol icons |
| UI | mini.sessions | Session management |

---

## Design Influences

- **Doom Emacs** — keymap grammar, module organization, consistent picker UI,
  Magit-style git workflow, project-scoped navigation
- **Hexagonal Architecture** — capabilities act as ports-and-adapters between
  modules and their implementations
- **Observable state** — state providers are a lightweight form of event sourcing;
  display components read from the state store rather than polling
