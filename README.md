# Neovim Configuration

A modular Neovim configuration designed for consistency with Doom Emacs.
Same `SPC` leader grammar, same navigation model, same git workflow (Magit → Neogit),
same file management (dired → oil.nvim), same org-mode workflow (org-mode → nvim-orgmode).

## Design Goals

- **Modularity** — features are isolated into modules that declare dependencies
- **Consistency with Doom Emacs** — same keymap grammar, navigation model, and workflows
- **Introspection** — running state is queryable via `:ConfigStatus`
- **Observable state** — editor state surfaced through registered providers, not ad-hoc globals
- **Language-spec-driven** — LSP, formatters, and treesitter declared per-language

---

## Directory Structure

```
~/.config/nvim/
├── init.lua                          # Entry point: module manifest, lazy bootstrap
├── README.md                         # This file
├── lua/
│   ├── env.lua                       # Single-import facade for all lib surfaces
│   ├── core/
│   │   ├── base_config.lua           # Vim options, autocmds, emacs keybindings
│   │   └── pickers.lua               # Bootstraps vim.ui.picker table
│   ├── lib/
│   │   ├── module.lua                # Module registry, DAG resolution, plugin spec collection
│   │   ├── state.lua                 # Observable state model (providers → key/value store)
│   │   ├── capabilities.lua          # Runtime extension registry (picker, notifier, etc.)
│   │   ├── display.lua               # Display contribution registry
│   │   └── articulation.lua          # Action registry (keymaps with module attribution)
│   ├── modules/
│   │   ├── interface.lua             # UI: colorscheme, statusline, which-key, oil, snacks
│   │   ├── introspection.lua         # Help/describe/inspect keymaps (SPC h, SPC i)
│   │   ├── filesystem/              # File pickers, project navigation
│   │   │   ├── init.lua
│   │   │   ├── pickers.lua           # Custom Vertico-style file browser (mini.pick)
│   │   │   └── utils.lua             # File listing, icons, show functions
│   │   ├── text_editing/            # LSP, treesitter, completion, formatting
│   │   │   ├── init.lua
│   │   │   ├── lsp.lua               # LSP client config, state providers
│   │   │   ├── languages/            # Per-language specs (lua, python, c, etc.)
│   │   │   ├── treesitter.lua
│   │   │   └── pickers.lua           # Buffer-local picker utilities
│   │   ├── version_control.lua       # Neogit (magit), gitsigns, diffview (SPC g)
│   │   ├── workspace.lua             # Project management, sessions, switching (SPC p)
│   │   ├── orgmode.lua               # Org-mode: agenda, capture, export (SPC o, ;)
│   │   ├── agents.lua                # AI coding agents: pi, claude code (SPC a)
│   │   └── terminal.lua              # Terminal UX + overseer task runner (SPC t, SPC o s)
│   └── utils/
│       └── file_browsing/            # Shared dired-style column rendering
│           ├── columns.lua           # Column width/gap/highlight definitions
│           ├── directory_editor.lua  # mini.files dired-style enhancements
│           ├── minibuffer_picker.lua # Vertico-style minibuffer file picker
│           ├── oil_columns.lua       # Oil custom column providers
│           └── file_search_config.lua
├── tests/
│   ├── minimal_init.lua
│   ├── run.sh
│   └── spec/                         # Unit tests for lib surfaces
```

---

## Module System

Modules register via `env.module.register { name, domain, depends_on, plugins, setup }`.
The module loader resolves a dependency DAG, collects all plugin specs into a single
lazy.nvim call, then runs each module's `setup()` in dependency order.

### Active Modules

| Module | Domain | Purpose |
|--------|--------|---------|
| `interface` | interface | Colorscheme, statusline (lualine), which-key, oil, snacks |
| `introspection` | introspection | Help/describe/inspect pickers (`SPC h`, `SPC i`) |
| `filesystem` | filesystem | File pickers, mini.files explorer, project navigation |
| `text_editing` | text_editing | LSP, treesitter, completion (blink.cmp), formatting |
| `version_control` | version_control | Neogit (magit), gitsigns, diffview |
| `workspace` | workspace | Project switching, per-project sessions, root detection |
| `orgmode` | orgmode | Org-mode: agenda, capture, TODO workflow |
| `agents` | agents | AI coding agents (pi, claude code) |
| `terminal` | terminal | Terminal UX, overseer task runner |
| `review` | review | Document review: live preview + inline comments |

---

## Keybindings

Leader: `SPC` · Local leader: `;` (org-mode buffer keymaps)

### Emacs Compatibility (all modes)

| Key | Action |
|-----|--------|
| `C-g` | Escape (cancel) |
| `C-s` | Save file |
| `C-a` / `C-e` | Beginning / end of line |
| `C-f` / `C-b` | Forward / back char (insert mode) |
| `C-n` / `C-p` | Next / prev line (insert mode) |
| `C-d` | Delete char forward |
| `C-k` | Kill to end of line |
| `C-y` | Yank (paste) |
| `C-/` | Undo |
| `M-f` / `M-b` | Forward / back word |
| `M-d` | Delete word forward |
| `M-w` | Copy region (visual) |
| `C-w` | Kill region (visual) |
| `M-x` | Command palette |

### Doom-Style Leader Keymaps

#### `SPC` — Top-Level

| Key | Action |
|-----|--------|
| `SPC .` | Find file |
| `SPC ,` | Switch buffer |
| `SPC /` | Search project (grep) |
| `SPC :` | Command palette |
| `SPC SPC` | Project find file |
| `SPC X` | Org quick capture |
| `SPC TAB` | Tab management |

#### `SPC f` — Find

| Key | Action |
|-----|--------|
| `SPC f s` | Save file |
| `SPC f f` | Find files (cwd) |

#### `SPC b` — Buffers

| Key | Action |
|-----|--------|
| `SPC b b` | Switch buffer |
| `SPC b d` | Delete buffer |
| `SPC b n` / `SPC b p` | Next / prev buffer |
| `SPC b k` | Kill buffer |

#### `SPC p` — Project

| Key | Action | Doom Equivalent |
|-----|--------|-----------------|
| `SPC p p` | Switch project (discover + recent) | `projectile-switch-project` |
| `SPC p f` | Find file in project | `projectile-find-file` |
| `SPC p g` | Grep in project | `+default/search-project` |
| `SPC p r` | Recent files in project | `projectile-recentf` |
| `SPC p b` | Buffers in project | `projectile-switch-to-buffer` |
| `SPC p d` | Browse project root (oil) | `projectile-dired` |
| `SPC p t` | Terminal at project root | `+vterm/here` |
| `SPC p a` | Agent at project root | — |
| `SPC p !` | Shell command at project root | `projectile-run-shell-command` |
| `SPC p s` | Save project session | `doom/save-session` |
| `SPC p l` | Load/list sessions | `doom/load-session` |
| `SPC p k` | Kill all project buffers | `projectile-kill-buffers` |
| `SPC p e` | Edit project config (`.nvim.lua`) | `.dir-locals.el` |
| `SPC p i` | Project info | — |
| `SPC p D` | Delete saved session | — |

#### `SPC g` — Git (Magit-style)

| Key | Action | Magit Equivalent |
|-----|--------|------------------|
| `SPC g g` | Neogit status | `magit-status` |
| `SPC g G` | Lazygit (float) | — |
| `SPC g c` | Commit | `magit-commit` |
| `SPC g P` | Push | `magit-push` |
| `SPC g F` | Pull | `magit-pull` |
| `SPC g f` | Fetch | `magit-fetch` |
| `SPC g B` | Branch | `magit-branch` |
| `SPC g r` | Rebase | `magit-rebase` |
| `SPC g z` | Stash | `magit-stash` |
| `SPC g l` | Log | `magit-log` |
| `SPC g v` | Diffview open | `magit-diff` |
| `SPC g V` | Diffview close | — |
| `SPC g H` | File history (diffview) | `magit-log-buffer-file` |
| `SPC g L` | Find commits (picker) | — |
| `SPC g SPC` | Find branches (picker) | — |
| `SPC g w` | Find status (picker) | — |
| `SPC g Z` | Find stash (picker) | — |

##### Buffer-local (gitsigns, inside files)

| Key | Action |
|-----|--------|
| `SPC g s` | Stage hunk |
| `SPC g u` | Unstage hunk |
| `SPC g x` | Reset hunk |
| `SPC g S` | Stage buffer |
| `SPC g X` | Reset buffer |
| `SPC g p` | Preview hunk |
| `SPC g b` | Toggle inline blame |
| `SPC g d` | Diff (index) |
| `SPC g D` | Diff (HEAD) |
| `]c` / `[c` | Next / prev hunk |

#### `SPC t` — Tasks (Overseer)

| Key | Action |
|-----|--------|
| `SPC t t` | Run task (Justfile/Makefile/cargo/npm picker) |
| `SPC t r` | Restart last task |
| `SPC t l` | Task list |
| `SPC t o` | Task output (float) |
| `SPC t a` | Task action menu |
| `SPC t !` | Run shell command as task |
| `SPC t s` | Toggle restart-on-save (watch mode) |
| `SPC t k` | Stop running task |
| `SPC t v` | Send visual selection to terminal |
| `SPC t L` | Send current line to terminal |

#### `SPC o` — Open / Org

| Key | Action |
|-----|--------|
| `SPC o a` | Org agenda |
| `SPC o c` | Org capture |
| `SPC o t` | Org TODO list |
| `SPC o f` | Org find file |
| `SPC o g` | Org grep |
| `SPC o s` | DWIM terminal (pick or open) |
| `SPC o S` | New terminal at project root |

#### `SPC a` — AI Agents

| Key | Action |
|-----|--------|
| `SPC a p` | Toggle pi (personal tokens) |
| `SPC a c` | Toggle claude code (corporate) |
| `SPC a t` | Toggle plain terminal |
| `SPC a a` | Toggle last-used agent |
| `SPC a s` | Send selection to agent (visual) |
| `` C-` `` | Global agent/terminal toggle |

#### `SPC d` — Document Review

| Key | Action |
|-----|--------|
| `SPC d p` | Start preview server (auto-detects backend) |
| `SPC d P` | Stop preview server / detach external |
| `SPC d o` | Open browser to preview |
| `SPC d s` | Sync browser to current file + heading |
| `SPC d S` | Toggle auto-sync (page on BufEnter, heading on CursorMoved) |
| `SPC d e` | Re-export current file (org -> markdown via x7-tools) |
| `SPC d E` | Re-export all docs |
| `SPC d c` | Add review comment block below cursor |
| `SPC d c` | Comment on selection (visual mode) |
| `SPC d i` | Add inline review comment at end of line |
| `SPC d r` | Resolve (delete) review comment at cursor |
| `SPC d l` | List all review comments in buffer (loclist) |
| `SPC d g` | Grep all review comments across project |
| `]r` / `[r` | Next / previous review comment |

#### `SPC x` — Files / Dired

| Key | Action | Dired Equivalent |
|-----|--------|------------------|
| `SPC x d` | Oil — open directory of current file | `dired` |
| `SPC x D` | Oil — open project root | `dired` (project root) |

#### `SPC l` — LSP

| Key | Action |
|-----|--------|
| `SPC l d` | Definitions |
| `SPC l s` | Document symbols |
| `SPC l S` | Workspace symbols |
| `SPC l r` | References |
| `SPC l i` | Implementations |
| `SPC l t` | Type definitions |
| `SPC l c i` | Incoming calls |
| `SPC l c o` | Outgoing calls |
| `SPC l n` | Rename |
| `SPC l a` | Code action |
| `SPC l I` | Toggle inlay hints |
| `SPC l R` | Restart LSP |

#### `SPC w` — Windows

| Key | Action |
|-----|--------|
| `SPC w h/j/k/l` | Navigate windows |
| `SPC w H/J/K/L` | Move windows |
| `SPC w s` | Split horizontal |
| `SPC w v` | Split vertical |
| `SPC w d` | Delete window |
| `SPC w o` | Delete other windows |

#### `SPC s` — Search

| Key | Action |
|-----|--------|
| `SPC s f` | Find files at cwd |
| `SPC s p` | Search project (grep) |

#### `SPC n` — Narrow

| Key | Action | Doom Equivalent |
|-----|--------|-----------------|
| `SPC n r` | Narrow to region (visual) | `narrow-to-region` |
| `SPC n d` | Narrow to defun (treesitter) | `narrow-to-defun` |
| `SPC n w` | Widen | `widen` |

#### `SPC u` — UI Toggles

| Key | Action |
|-----|--------|
| `SPC u n` | Toggle line numbers |
| `SPC u r` | Toggle relative numbers |
| `SPC u s` | Toggle spell check |
| `SPC u x` | Toggle word wrap |
| `SPC u l` | Toggle line numbers (both) |
| `SPC u w` | Toggle word highlights |
| `SPC u i` | Toggle indent guides |
| `SPC u d` | Toggle inline diagnostics |

#### `SPC h` — Help / Describe

| Key | Action |
|-----|--------|
| `SPC h h` | Help tags |
| `SPC h k` | Keymaps |
| `SPC h c` | Commands |
| `SPC h a` | Autocmds |
| `SPC h s` | Scripts |
| `SPC h H` | Highlights |
| `SPC h r` | Runtime files |

#### `SPC i` — Inspect

| Key | Action |
|-----|--------|
| `SPC i c` | Cursor inspect (treesitter) |
| `SPC i l` | LSP clients |
| `SPC i b` | Buffer options |
| `SPC i w` | Window options |

#### `SPC c` — Config

| Key | Action |
|-----|--------|
| `SPC c m` | Module status |
| `SPC c k` | All keymaps |
| `SPC c c` | Capabilities |
| `SPC c s` | State providers |

### Terminal Mode

| Key | Action |
|-----|--------|
| `Esc Esc` | Normal mode |
| `C-h/j/k/l` | Window navigation |
| `M-k` / `M-j` | Scroll up / down (half-page) |
| `` M-` `` | Toggle terminal in-place |

### Oil Buffer (dired-style)

| Key | Action | Dired Equivalent |
|-----|--------|------------------|
| `CR` | Open file/directory | `dired-find-file` |
| `BS` | Go to parent directory | `dired-up-directory` |
| `C-s` | Open in vertical split | — |
| `C-x` | Open in horizontal split | — |
| `C-p` | Preview file | — |
| `C-h` | Toggle hidden files | `dired-omit-mode` |
| `o` | Change sort | `dired-sort-toggle-or-edit` |
| `q` | Close | `quit-window` |
| `_` | Open cwd | — |
| `` ` `` | cd to oil directory | — |
| `C-o` | Open externally | `dired-open-externally` |
| `;q` | Toggle read-only (edit mode) | `dired-toggle-read-only` |

### Neogit Buffer (magit-style)

| Key | Action | Magit Equivalent |
|-----|--------|------------------|
| `TAB` | Toggle section | `magit-section-toggle` |
| `SPC` / `s` | Stage | `magit-stage` |
| `S` | Stage all | `magit-stage-modified` |
| `u` | Unstage | `magit-unstage` |
| `x` | Discard | `magit-discard` |
| `CR` | Open or scroll down | `magit-visit-thing` |
| `q` | Close | `magit-mode-bury-buffer` |

---

## Commands

| Command | Description |
|---------|-------------|
| `:ConfigStatus` | Show module status, keymaps, state |
| `:Make [args]` | Async make via overseer (output → quickfix) |
| `:OS <cmd>` | Run shell command as overseer task |
| `:OverseerRun` | Run task from template |
| `:OverseerToggle` | Toggle task list |
| `:Neogit` | Open neogit status |

---

## Plugin Stack

| Category | Plugin | Purpose |
|----------|--------|---------|
| **Core UI** | tokyonight.nvim | Colorscheme (storm, transparent bg) |
| | lualine.nvim | Statusline (doom-modeline layout + overseer) |
| | which-key.nvim | Keymap discovery and hints |
| | snacks.nvim | Pickers, terminal, input, scope, scratch |
| **File Management** | oil.nvim | Directory editor (dired-style) |
| | mini.files | File explorer with preview and dired columns |
| **Completion** | blink.cmp | Completion engine (Tab/S-Tab/CR) |
| **Formatting** | conform.nvim | Format-on-save (language-spec driven) |
| **LSP** | mason + mason-tool-installer | LSP/tool installation |
| **Treesitter** | nvim-treesitter + textobjects + context | Syntax, navigation, sticky headers |
| **Git** | neogit | Magit-style git interface |
| | gitsigns.nvim | Sign column, blame, hunk operations |
| | diffview.nvim | Side-by-side diff viewer + file history |
| **Tasks** | overseer.nvim | Task runner (just/make/cargo/npm/vscode) |
| **Org** | nvim-orgmode | Org-mode (agenda, capture, export) |
| | org-bullets.nvim | Pretty org heading bullets |
| | headlines.nvim | Org headline highlighting |
| **Pickers** | mini.pick | Custom Vertico-style file browser |
| | mini.extra | Buffer-lines picker |
| | fff.nvim | File search + live grep |
| **Sessions** | mini.sessions | Session save/restore |

---

## State Providers

All state is queryable via `env.state.get('key')`.

| Key | Module | Description |
|-----|--------|-------------|
| `workspace.cwd` | core | Current working directory |
| `workspace.root` | workspace | Project root (LSP → markers → git → cwd) |
| `workspace.project_name` | workspace | Basename of project root |
| `vcs.branch` | version_control | Current git branch |
| `vcs.status` | version_control | Working tree status (staged/unstaged/untracked) |
| `vcs.head_commit` | version_control | HEAD hash + message |
| `vcs.is_repo` | version_control | Whether cwd is a git repo |
| `vcs.hunk_count` | version_control | Changed hunks in current buffer |
| `lsp.attached_servers` | text_editing | Attached LSP server names |
| `lsp.diagnostics` | text_editing | Diagnostic counts by severity |
| `lsp.current_symbol` | text_editing | Symbol under cursor |
| `lsp.capabilities` | text_editing | Aggregated LSP capabilities |
| `filesystem.tree_visible` | filesystem | Whether file tree is showing |

---

## Magit (Neogit) Integration

Neogit mirrors Magit's transient popup workflow. Every `SPC g` keymap opens
the corresponding Neogit popup (commit, push, pull, branch, rebase, stash, log).
Inside the Neogit status buffer, the keybindings match Magit conventions:

- **`TAB`** toggles section fold (like `magit-section-toggle`)
- **`s`/`SPC`** stages, **`u`** unstages, **`x`** discards
- **`CR`** visits the file/hunk
- Transient popups (commit, push, etc.) appear inline

Configuration mirrors Doom's Magit settings:
- `diff_viewer = 'codediff'` for side-by-side diffs
- `graph_style = 'unicode'` for git log graphs
- `recent_commit_count = 10` in status
- `show_staged_diff = true` in commit editor
- `auto_refresh = true` after operations
- Snacks picker integration for finder UIs

---

## Dired (Oil + mini.files) Integration

Oil.nvim serves as the primary directory editor, replacing Emacs dired.
The buffer is editable — rename files by editing the buffer, delete by
removing lines, then save to apply (like `wdired-mode`).

- **`SPC x d`** opens oil at the current file's directory (`dired`)
- **`SPC x D`** opens oil at the project root
- **`SPC p d`** also opens project root in oil
- **`-`** (normal mode) opens oil for the current file's parent directory

Oil shows dired-style columns: permissions, size, mtime, icon.
The `utils/file_browsing/` utilities provide a shared column rendering
system used by both oil and mini.files for a consistent dired look.

Mini.files provides a Miller-columns file explorer with dired-style
stat columns (permissions, size, mtime) rendered via the same shared
column system. Both surfaces are visually identical.

---

## Task Runner (Overseer)

Overseer auto-discovers tasks from project files:

| Source | Detected From |
|--------|---------------|
| Just | `Justfile`, `justfile` |
| Make | `Makefile`, `GNUmakefile` |
| Cargo | `Cargo.toml` |
| npm | `package.json` |
| VS Code | `.vscode/tasks.json` |
| Tox | `tox.ini` |
| Mix | `mix.exs` |
| Deno | `deno.json` |
| Rake | `Rakefile` |
| Mise | `mise.toml` |

Task output can be piped to quickfix/diagnostics. The `:Make` command
provides async make with output parsed through `errorformat`.
The lualine statusline shows overseer task status (running/success/failure).

Watch mode (`SPC t s`) restarts the most recent task on file save —
replaces manual re-running and tools like `entr`/`watchexec`.

---

## Document Review

The review module provides a split-desktop workflow for document review:
editor on one side, live-reloading preview in a browser on the other.

### Preview Backends

Auto-detected in priority order:

| Backend | Detected By | Use Case |
|---------|-------------|----------|
| **Quartz** (pages-preview.sh) | `tools/pages-preview.sh` | x7-forge org→md pipeline |
| **x7-tools pages preview** | `tools/x7-forge/implementation/x7-tools/run.sh` | x7-forge submodule (system repos) |
| **x7-forge tools** | `tools/x7-forge/tools/run.sh` | x7-forge nested layout |
| **grip** | `grip` in PATH | GitHub-flavored markdown |
| **python3 http.server** | `docs/` directory | Static HTML fallback |

The preview server runs as an overseer task — visible in `SPC t l`,
stoppable with `SPC d P`, output captured in the task list.

**External server:** If you start the preview externally, attach with
`:ReviewAttach <port>` (e.g. `:ReviewAttach 8080`). Neovim will sync
the browser without owning the server lifecycle. `:ReviewDetach` disconnects.

### Review Comments

File-type-aware comment format:

**Org-mode:**
```org
#+begin_review Reg Marr 2026-06-25 14:30
This section needs a reference to the SDP.
#+end_review
```

**Markdown:**
```markdown
<!-- REVIEW Reg Marr 2026-06-25 14:30
This section needs a reference to the SDP.
-->
```

**Inline comments** (appended to end of line):
```org
The system shall...  # REVIEW(Reg Marr 2026-06-25 14:30): verify against SRS
```

Comments are highlighted with a warm background. Navigate with `]r`/`[r`,
grep across the project with `SPC d g`, resolve (delete) with `SPC d r`.

### Browser Sync

Two sync modes, designed for a split-desktop workflow:

| Mode | Trigger | Browser behaviour |
|------|---------|--------------------|
| **Page-level** | `SPC d s`, `BufEnter` (auto-sync) | `xdg-open` navigates browser (may steal focus) |
| **Heading-level** | `CursorMoved` (auto-sync) | Writes URL to `/tmp/nvim-review-<port>`, relay serves it, userscript scrolls smoothly — **no focus steal** |

Heading-level sync uses a debounced `CursorMoved` hook: `nearest_heading_slug()` is
called on each movement, but the 500ms timer only starts when the slug changes.
Rapid scrolling within a section never triggers sync.

**File → URL mapping:**
- Strips `docs_root` (default `documentation`) from the file path
- Removes file extension, lowercases the whole relative path
- Example: `documentation/plans/icmp/Interface_Control_Model_Plan.org`
  → `/plans/icmp/interface_control_model_plan`

**Configuring docs_root** (per-project):
```lua
-- In .nvim.lua at project root, or via :ReviewDocsRoot
vim.g.review_docs_root = 'documentation'  -- default
```

**Custom path mapping** (overrides built-in logic):
```lua
vim.g.review_path_map = function(file)
  return '/my-custom-path'
end
```

**Auto-sync** (`SPC d S`) is OFF by default. When enabled:
- `BufEnter` → page-level sync (navigates browser)
- `CursorMoved` → heading-level sync (smooth scroll via relay, no focus steal)
- All hooks are removed when auto-sync is toggled off

#### Relay + Userscript Setup

For heading-level sync without focus stealing:

1. The relay server starts automatically with preview (or `:ReviewAttach`)
2. Install `scripts/review-sync.user.js` in Violentmonkey/Greasemonkey
3. The userscript polls `http://127.0.0.1:<port+10000>/` and scrolls to anchors

### Re-export

`SPC d e` re-runs `x7-tools pages prepare` for the current org file to
regenerate its markdown output after edits. `SPC d E` re-exports all docs.
Also available as `:ReviewExport` (current) / `:ReviewExport!` (all).

### Commands

| Command | Description |
|---------|-------------|
| `:ReviewPreview` | Start the preview server |
| `:ReviewPreview!` | Stop the preview server |
| `:ReviewAttach <port>` | Attach to external server on `<port>` |
| `:ReviewDetach` | Detach (stop sync, keep server running) |
| `:ReviewSync` | Sync browser to current file + heading |
| `:ReviewExport` | Re-export current file (org → md) |
| `:ReviewExport!` | Re-export all docs |
| `:ReviewPort [port]` | Get or set the preview port (default: 8080) |
| `:ReviewDocsRoot [path]` | Get or set the docs root directory |
| `:ReviewComment [text]` | Insert a review comment |

---

## Design Influences

- **Doom Emacs** — keymap grammar, module system, magit/dired/org workflow
- **Spacemacs** — `SPC` as universal leader
- **Projectile** — project discovery and session management
- **vim-dispatch** — async `:Make` → quickfix pattern
