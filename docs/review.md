# Review Module

## Overview

The review module (`lua/modules/review.lua`) provides a live-preview sync
workflow for documentation editing. It connects neovim to a browser preview
(typically Quartz) so that moving the cursor in the editor scrolls the browser
to match.

Designed for a split-desktop workflow:
- **Left:** browser with live-reloading preview (Quartz / grip / etc.)
- **Right:** Neovim editing the org/markdown source

## Architecture

```
┌─────────────┐          ┌──────────────────┐        ┌────────────────────┐
│   Neovim    │  push    │  WebSocket Relay  │  push  │      Browser       │
│             │ ───────► │  (vim.uv TCP)     │ ──────►│  (Quartz page +    │
│ CursorMoved │  JSON    │  127.0.0.1:18080  │  JSON  │   review-sync.js)  │
└─────────────┘          └──────────────────┘        └────────────────────┘
```

Three components:

1. **Neovim (review.lua):** Tracks cursor position, finds the nearest
   heading, slugifies it to match Quartz's `github-slugger` IDs, and
   pushes `{ type, url, path, anchor }` JSON messages via WebSocket.

2. **WebSocket relay (lua/utils/websocket.lua):** A pure-Lua TCP server
   using `vim.uv` that runs inside neovim. Handles the WebSocket
   handshake (SHA1 via openssl) and broadcasts messages to connected
   browser clients. Binds to `127.0.0.1` only (localhost, safe for dev).

3. **Browser client:** JavaScript injected into every Quartz page via the
   `source-positions` plugin's `externalResources`. Connects to the relay,
   receives messages, and scrolls to the target heading. Handles Quartz
   SPA navigation (creates synthetic `<a>` clicks, listens for the `"nav"`
   event). No userscript manager (Violentmonkey/Tampermonkey) required.

   A standalone userscript at `scripts/review-sync.user.js` is provided
   as a fallback for non-Quartz preview servers (grip, http.server, etc.)
   that don't use the source-positions plugin.

## Port Convention

- **Preview server:** port 8080 (configurable via `preview.port`)
- **WebSocket relay:** preview port + 10000 = 18080 by default
- The browser client auto-detects the relay port from `window.location.port`

## Browser Sync Modes

### Manual sync (`SPC d s`)

Opens the browser via `xdg-open` (focus steal is acceptable for a manual
action) and pushes a "navigate" WebSocket message. Use when you want to
jump the browser to a specific file.

### Auto-sync (`SPC d S`)

Toggles automatic synchronisation:

- **BufEnter** → pushes a "navigate" message via WebSocket (no focus steal).
  The browser client navigates to the new page via SPA.
- **CursorMoved** → finds the nearest heading, debounces for 500ms, then
  pushes a "scroll" message. The browser smoothly scrolls to the heading.

Auto-sync only activates for `*.org`, `*.md`, `*.markdown`, `*.qmd` files
inside the detected docs root.

## Heading Slug Algorithm

Slugs must match `github-slugger` (used by Quartz's `rehype-slug`). Key
difference from a naive slugify: **each space becomes one hyphen independently,
consecutive hyphens are NOT collapsed**. This matters for headings containing
em dashes:

```
"Interfaces — Details"  →  "interfaces--details"   (double hyphen)
"The Three-Layer Model" →  "the-three-layer-model"
```

The implementation uses `gsub(' ', '-')` (individual space replacement)
rather than `gsub('%s+', '-')` (collapse).

## Performance

The `CursorMoved` autocmd is the most performance-sensitive code path. It
fires on every cursor movement in normal mode. Optimisations:

1. **Heading index cache.** The first call to `nearest_heading_slug()` scans
   the entire buffer and builds a sorted `{ row, slug }` index. Subsequent
   calls use this index until the buffer text changes (`b:changedtick`).
   Cache hit cost: O(log N) binary search over the heading list.

2. **Early exit.** If the slug matches `last_synced_slug[bufnr]`, the
   callback returns immediately (no timer, no WebSocket message).

3. **Single-compute debounce.** The slug is captured at CursorMoved time
   and passed to the timer callback. The timer and `sync_browser` do not
   re-call `nearest_heading_slug()`.

4. **Docs-root cache.** `get_docs_root()` caches the result per project
   root to avoid repeated `vim.fn.isdirectory()` syscalls.

## Preview Detection

When starting a preview via `SPC d p`, the module searches for backends
in order:

1. `tools/pages-preview.sh` (legacy standalone script)
2. `tools/x7-forge/implementation/x7-tools/run.sh pages preview`
3. `tools/x7-forge/tools/run.sh pages preview`
4. `grip` (GitHub-flavoured markdown preview)
5. `python3 -m http.server` on `docs/` (fallback)

The x7-forge backends set `X7_NO_DOCKER=1` when started from neovim so the
preview runs on the host (no Docker container). The relay runs inside neovim
on the host regardless; with Docker `--network host` mode, the browser can
reach both the preview server and the relay on localhost.

## Docker Compatibility

The x7-forge `run.sh` uses `--network host`, so the Docker container shares
the host's network stack:

| Component       | Runs on       | Port              | Browser accessible? |
|-----------------|---------------|-------------------|---------------------|
| Quartz preview  | Docker (host) | `localhost:8080`  | ✓                   |
| WebSocket relay | Neovim (host) | `127.0.0.1:18080` | ✓                   |
| Sync client JS  | Browser       | connects to 18080 | ✓                   |

No port mapping or special Docker configuration is needed.

## Inline Review Comments

The module also supports inline review annotations:

| Keybinding  | Action                                      |
|-------------|---------------------------------------------|
| `SPC d c`   | Insert block review comment at cursor        |
| `SPC d C`   | Insert inline review comment at end of line  |
| `SPC d n`   | Jump to next review comment                  |
| `SPC d N`   | Jump to previous review comment              |
| `SPC d r`   | Resolve (delete) review comment under cursor |
| `SPC d l`   | List all review comments in location list    |

Comments use filetype-aware syntax:
- **Org:** `#+begin_review` / `#+end_review` blocks
- **Markdown:** `<!-- REVIEW(...) -->` inline or block comments
- **Other:** Filetype's `commentstring`

## Re-export (`SPC d e`)

Runs `x7-tools pages prepare` to re-export org sources to markdown. The
Quartz watcher picks up the changed markdown and hot-reloads the page.

## Quartz Plugin Integration

The review workflow relies on two local Quartz plugins:

### source-positions

Located at `documentation/site/quartz-plugins/source-positions/`.

- **markdownPlugins:** Stamps `data-source-start`/`data-source-end` attributes
  on block-level MDAST nodes (propagated to HTML by remark-rehype).
- **htmlPlugins:** Injects `<meta name="source-file">` for the annotation client.
- **externalResources:** Injects two client-side scripts:
  1. Annotation client (inline comment/review UI)
  2. Review-sync client (WebSocket auto-scroll — replaces userscript)

### d2-diagrams

Located at `documentation/site/quartz-plugins/d2-diagrams/`.

- Renders fenced `` ```d2 `` code blocks to inline SVG at build time.
- Dual light/dark renders with CSS toggle (`[saved-theme]` + media query).
- Strips SVG background rects for transparent blending with Quartz theme.
- Rewrites absolute spread-imports to repo-local paths.

## Key Files

| File | Role |
|------|------|
| `lua/modules/review.lua` | Main module (preview, sync, comments) |
| `lua/utils/websocket.lua` | Pure-Lua WebSocket server (vim.uv) |
| `scripts/review-sync.user.js` | Standalone userscript (fallback) |
| `tests/spec/review_url_spec.lua` | URL mapping + slugify tests |
| `docs/review-enhancement-plan.md` | Future plans (line-level sync, MR workflow) |

## Future Plans

See `docs/review-enhancement-plan.md` for the roadmap:

- **Line-level sync** via `data-source-line` attributes (Step 3)
- **Browser comment collection** with WebSocket push back to neovim (Step 4)
- **GitLab MR integration** via `glab mr note create` (Step 4)
