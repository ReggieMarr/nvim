# Agent Instructions — Neovim Configuration

This is a modular Neovim configuration. It is designed to be maintained by
both the user and AI agents. Read the full architecture in README.md.

## Critical Rules

1. **No stubs.** Either fully implement a feature or remove it. Do not leave
   commented-out placeholder code or empty functions that pretend to work.

2. **Run tests.** After any change, run `./tests/run.sh` from the repo root.
   All specs must pass before declaring work done.

3. **Verify startup.** After structural changes (new modules, new plugins,
   changed dependencies), verify with:

   ```bash
   nvim --headless -c "lua print(require('lib.module').validate())" -c "qa!"
   ```

   There should be no `E5113` or `Error in init.lua` lines.

4. **Doom Emacs alignment.** This config mirrors the user's Doom Emacs setup.
   Keybindings must follow the same `SPC` prefix grammar. When in doubt,
   check `~/Downloads/gitDownloads/dark_helmet/doom.d/config.org`.

5. **Plugin spec coverage.** Every `require('plugin_name')` in module code
   must have a corresponding `['author/plugin_name']` in some module's
   `plugins` table. The `plugin_deps_spec.lua` test enforces this.

## Architecture Quick Reference

### Module system

- Modules register via `env.module.register { name, domain, depends_on, plugins, setup }`.
- The manifest in `init.lua` controls which modules load. Comment a line to disable.
- `lib/module.lua` resolves load order via topological sort of `depends_on`.
- Plugin specs are merged across modules before passing to lazy.nvim.
  If two modules declare the same plugin, `opts` tables are deep-merged
  (first writer wins when opts is a function).

### Env facade

- All lib surfaces are accessed via `local env = require 'env'`.
- `env.state` — observable state (providers register, values collected on events).
- `env.capabilities` — runtime extension slots (e.g., 'picker'). The 'picker'
  slot mirrors into `vim.ui.picker.*` for backward compatibility.
- `env.display` — declares what a module adds to the visible surface.
- `env.articulation` — registers keymaps AND records them for introspection.
- `env.use('picker')` — shorthand for `env.capabilities.get('picker')`.

### Language specs

- Located in `lua/modules/text_editing/languages/`.
- Each file returns a `LanguageSpec` table: `{ ft, lsp, formatters, treesitter }`.
- The registry in `languages/init.lua` aggregates specs and feeds mason,
  conform, and treesitter configuration.
- To add a new language: create `languages/foo.lua`, add it to `_specs` in
  `languages/init.lua`, and run `./tests/run.sh language` to validate the schema.

### Picker backends

- **snacks.picker** — standard pickers (files, grep, help, LSP, git). Uses
  `vertical` layout preset for centered floating windows.
- **mini.pick** — custom file browser (`SPC f f`) and buffer search. Uses
  golden-ratio centered window. The file browser relies on mini.pick's
  low-level mutation API which snacks does not expose.
- Do NOT remove mini.pick — it is required by `filesystem/pickers.lua`.

### Keymaps

- Module keymaps are set in each module's `setup()` function.
- Buffer-local keymaps (e.g., gitsigns hunk ops) use `env.articulation.register`
  so they appear in `:ConfigStatus keys`.
- Global keymaps use `vim.keymap.set` directly (acceptable for module setup).
- which-key group declarations live in `interface.lua`.

## File Locations

| What | Where |
|------|-------|
| Module manifest | `init.lua` lines 28-35 |
| Env facade | `lua/env.lua` |
| Module registry | `lua/lib/module.lua` |
| State system | `lua/lib/state.lua` |
| Capabilities | `lua/lib/capabilities.lua` |
| Display registry | `lua/lib/display.lua` |
| Action registry | `lua/lib/articulation.lua` |
| Language specs | `lua/modules/text_editing/languages/*.lua` |
| LSP configuration | `lua/modules/text_editing/lsp.lua` |
| Git integration | `lua/modules/version_control.lua` |
| File navigation | `lua/modules/filesystem/init.lua` |
| Custom file browser | `lua/modules/filesystem/pickers.lua` |
| Tests | `tests/spec/*.lua` |
| Test runner | `tests/run.sh` |

## Companion Doom Emacs Config

The user maintains a parallel Doom Emacs configuration at:
`~/Downloads/gitDownloads/dark_helmet/doom.d/`

Key files: `config.org` (literate config), `init.el` (module flags),
`packages.el` (extra packages).

When modifying keybindings or adding features, check both configs for
consistency. The goal is seamless context-switching between editors.

## Project Context

The user works on **x7-cavorite**, a DO-178C aerospace program with:

- Hand-written C (embedded, clangd)
- MATLAB/Simulink MBD models
- Python CLI tooling (x7-tools, uv/pytest)
- Lua Pandoc filters
- Org-mode documentation

The C/C++ language spec (`languages/c.lua`) is configured for this project:
system clangd (not mason), clang-format gated on `.clang-format` presence,
`<leader>lo` for header/source switching.
