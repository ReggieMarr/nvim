# Review Module Enhancement Plan

## Status: Steps 1–3 Complete, Step 4 Planned

This document evaluates how to leverage `live-preview.nvim` and its dependencies
to improve the review module's browser sync and enable a future commenting→MR
workflow.

---

## 1. live-preview.nvim Evaluation

### Architecture Summary

live-preview.nvim is a **standalone markdown preview plugin** that:
- Runs a pure-Lua HTTP + WebSocket server using `vim.uv` (no external process)
- Serves markdown files rendered client-side via `markdown-it` (browser JS)
- Uses WebSocket for live reload and **line-level scroll sync**
- Injects `data-source-line` attributes via `markdown-it-inject-linenumbers`
- Client JS finds the nearest `[data-source-line="N"]` element and scrolls to it

### What It Does NOT Support
- **Org-mode files** — only Markdown, HTML, AsciiDoc, SVG
- **Custom URL path mapping** — serves files by filesystem path only
- **Quartz integration** — renders its own HTML, not compatible with Quartz's
  remark/rehype pipeline or its theme/layout/SPA routing
- **Existing preview servers** — replaces rather than integrates with them

### Verdict
**Cannot be used as a drop-in preview backend** for our workflow.
However, several components are directly reusable.

---

## 2. Reusable Components

### 2a. WebSocket Server (Lua) — Replace Python Relay

**Source:** `livepreview/server/websocket.lua` (~60 lines)

live-preview.nvim implements a pure-Lua WebSocket server using `vim.uv` TCP.
This handles handshake (SHA1 + base64), frame encoding/decoding, and JSON
message sending — all without any external process.

**What this replaces:** Our `scripts/review-relay.py` (Python HTTP server that
the userscript polls via `fetch`). The Lua WebSocket runs inside Neovim itself.

**Benefits:**
- No external Python process to manage via overseer
- Lower latency (WebSocket push vs HTTP polling at 500ms intervals)
- Simpler lifecycle (starts/stops with Neovim, no cleanup needed)
- One fewer moving part

**Implementation sketch:**
```lua
-- In review.lua, adapted from livepreview/server/websocket.lua
local uv = vim.uv
local server = uv.new_tcp()
server:bind('127.0.0.1', relay_port)
server:listen(1, function(err)
  local client = uv.new_tcp()
  server:accept(client)
  -- WebSocket handshake + frame handling
  -- On connect, send current page URL
end)

-- On heading change, push to all connected clients:
websocket.send_json(client, {
  type = "scroll",
  url = "http://localhost:8080/plans/icmp/interface_control_model_plan#overview"
})
```

### 2b. Line-Number Injection — Line-Level Scroll Sync

**Source:** `markdown-it-inject-linenumbers` / `static/markdown/line-numbers.js`

This plugin adds `data-source-line="N"` and `class="source-line"` attributes to
every block-level HTML element during rendering, mapping each rendered paragraph
back to its source line number.

**Current state:** Our sync operates at heading granularity (find nearest `*`/`#`
heading, slugify, navigate to `#anchor`). Line-level would be much more precise.

**Challenge:** We use Quartz (remark/rehype pipeline), not markdown-it. The
equivalent for Quartz would be a **rehype plugin** that does the same thing.

**Implementation: Quartz Transformer Plugin**

```typescript
// quartz-plugins/line-numbers.ts
import { QuartzTransformerPlugin } from "@quartz-community/types"
import { visit } from "unist-util-visit"

export const InjectLineNumbers: QuartzTransformerPlugin = () => ({
  name: "InjectLineNumbers",
  htmlPlugins() {
    return [
      () => (tree) => {
        visit(tree, "element", (node) => {
          if (node.position?.start?.line) {
            node.properties = node.properties || {}
            node.properties["data-source-line"] = node.position.start.line
            node.properties.className = [
              ...(node.properties.className || []),
              "source-line",
            ]
          }
        })
      },
    ]
  },
})
```

This would go in the Quartz config alongside the existing plugins.

### 2c. Client-Side Scroll Sync Protocol

**Source:** `static/ws-client.js`

live-preview.nvim's scroll protocol sends `{type: "scroll", filepath, cursor}`
over WebSocket. The client finds the nearest `[data-source-line="N"]` element
and calls `scrollIntoView({ behavior: "smooth", block: "center" })`.

**What we'd adopt:**
- Replace the userscript's HTTP polling with a WebSocket connection
- Use the same `data-source-line` nearest-element lookup
- Add SPA-aware navigation (Quartz uses `popstate` events, not full reloads)

**This replaces:** `scripts/review-sync.user.js` (HTTP-polling userscript)

### 2d. Reconnection Logic

`ws-client.js` includes auto-reconnect with status tracking. Our replacement
script (either userscript or Quartz plugin client JS) should adopt this pattern.

---

## 3. Recommended Architecture (Future)

### Current Stack (what we have now)
```
Neovim → writes URL to /tmp file → Python relay serves it → userscript polls
```
3 moving parts, 500ms polling latency, requires Violentmonkey install.

### Proposed Stack
```
Neovim (vim.uv WebSocket server) → Quartz plugin (client JS connects)
```
1 moving part on the Neovim side, push-based (no polling), no userscript needed.

### Components to Build

| Component | Type | Replaces |
|-----------|------|----------|
| `review-websocket.lua` | Lua module in nvim config | `review-relay.py` |
| `quartz-nvim-sync` | Quartz transformer plugin | `review-sync.user.js` |
| `quartz-line-numbers` | Quartz transformer plugin | heading-only sync |

The Quartz plugin would:
1. **Transformer:** Inject `data-source-line` attributes via rehype
2. **externalResources:** Load client-side JS that connects to Neovim's WebSocket
3. **Component (future):** Add a comment overlay UI

### Quartz Plugin: `quartz-nvim-sync`

```typescript
// A single Quartz plugin combining line numbers + WebSocket client
import { QuartzTransformerPlugin } from "@quartz-community/types"
import { visit } from "unist-util-visit"

export const NvimSync: QuartzTransformerPlugin = () => ({
  name: "NvimSync",

  // Inject line numbers into HTML
  htmlPlugins() {
    return [() => (tree) => {
      visit(tree, "element", (node) => {
        if (node.position?.start?.line) {
          node.properties ||= {}
          node.properties["data-source-line"] = node.position.start.line
          node.properties.className = [
            ...(node.properties.className || []),
            "source-line",
          ]
        }
      })
    }]
  },

  // Load client-side WebSocket scroll sync script
  externalResources() {
    return {
      js: [{
        // Inline script that connects to Neovim's WebSocket relay
        src: "",
        loadTime: "afterDOMReady",
        contentType: "inline",
        script: NVIM_SYNC_CLIENT_JS,  // see below
      }],
    }
  },
})

const NVIM_SYNC_CLIENT_JS = `
  const port = Number(location.port) + 10000;
  let ws;
  function connect() {
    ws = new WebSocket("ws://127.0.0.1:" + port);
    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.type === "scroll") {
        // Line-level sync
        const el = document.querySelector('[data-source-line="' + msg.line + '"]')
          || findNearest(msg.line);
        if (el) el.scrollIntoView({ behavior: "smooth", block: "center" });
      } else if (msg.type === "navigate") {
        // Page-level sync (Quartz SPA navigation)
        if (msg.path !== location.pathname) {
          // Quartz SPA: use its router instead of full page load
          const link = document.querySelector('a[href="' + msg.path + '"]');
          if (link) link.click();
          else location.href = msg.url;
        }
      }
    };
    ws.onclose = () => setTimeout(connect, 2000);
  }
  connect();
`;
```

### Neovim Side: `review-websocket.lua`

Adapted from `livepreview/server/websocket.lua`:

```lua
-- Pure Lua WebSocket server using vim.uv
-- Sends two message types:
--   {type: "navigate", path: "/plans/icmp/...", url: "http://..."}
--   {type: "scroll", line: 42, filepath: "Interface_Control_Model_Plan.org"}

local M = {}
local uv = vim.uv

function M.start(port)
  -- TCP server with WebSocket upgrade
  -- SHA1 handshake from livepreview/server/websocket.lua
  -- Maintain list of connected clients
  -- Push messages on BufEnter (navigate) and CursorMoved (scroll)
end
```

---

## 4. Future: Commenting Workflow → GitLab MR

### Vision
Reviewers can add comments on the rendered webpage. Comments are collected
and pushed to a GitLab MR as discussion threads using `glab`.

### Architecture

```
Browser (Quartz comment UI) → WebSocket → Neovim → glab mr note create
```

### Phase 1: Webpage Comment UI (Quartz Component Plugin)

A Quartz component plugin that adds a comment overlay:

```typescript
export const ReviewComments: QuartzComponentPlugin = () => ({
  name: "ReviewComments",
  // Renders a floating "Add Comment" button on paragraph hover
  // Clicking opens a small form
  // Comment stored in-memory, displayed as highlight overlay
  afterDOMLoaded: `
    document.addEventListener("nav", () => {
      document.querySelectorAll(".source-line").forEach(el => {
        el.addEventListener("click", (e) => {
          if (e.altKey) {  // Alt+click to comment
            showCommentForm(el, el.dataset.sourceLine);
          }
        });
      });
    });
  `,
})
```

### Phase 2: Neovim Collection

When the reviewer is done, comments are sent over WebSocket to Neovim:

```json
{
  "type": "comment",
  "file": "plans/icmp/interface_control_model_plan",
  "line": 42,
  "text": "This interface definition needs to reference the MDS schema"
}
```

Neovim collects these and can:
1. Insert them as `#+begin_review` blocks in the org source (existing feature)
2. Push to GitLab MR via `glab`

### Phase 3: Push to GitLab MR

`glab mr note create` supports inline diff comments with `--file` and `--line`:

```bash
# File-level comment
glab mr note create --file documentation/plans/icmp/Interface_Control_Model_Plan.org \
  -m "This interface definition needs to reference the MDS schema"

# Line-level diff comment (on the generated markdown in the MR diff)
glab mr note create --file Interface_Control_Model_Plan.md \
  --line 42 \
  -m "This interface definition needs to reference the MDS schema"

# Multiline range
glab mr note create --file main.go --line 10:15 \
  -m "Extract this block"
```

The Neovim command would:
1. Detect the current MR for the branch (`glab mr list --source-branch $(git branch --show-current)`)
2. Map org source line → generated markdown line (using the pandoc line mapping)
3. Create the note with `glab mr note create`

### Neovim Commands (Future)

```
:ReviewPushMR              Push all review comments to current branch's MR
:ReviewPushMR!             Push and resolve local comments after pushing
SPC d m                    Push comments to MR (interactive, shows preview)
```

---

## 5. Migration Path

### Step 1 (Done)
- File-based relay (`review-relay.py`) + userscript polling
- Heading-level sync only
- Superseded by Step 2

### Step 2 (Done) ✅
- Lua WebSocket server (`lua/utils/websocket.lua`) adapted from live-preview.nvim
- Push-based WebSocket messaging (no polling)
- Heading-level sync with debounced CursorMoved + slug comparison
- Auto-detect docs_root (`documentation/content` > `documentation` > `docs`)
- No external process needed

### Step 3 (Done) ✅
- Review-sync client embedded in `source-positions` plugin via `externalResources`
- Client JS injected into every Quartz page automatically (no userscript manager)
- SPA-aware navigation (synthetic `<a>` click + Quartz `"nav"` event listener)
- Slug algorithm fixed to match `github-slugger` (em dash double-hyphen compat)
- BufEnter auto-sync uses WebSocket push-only (no `xdg-open` focus steal)
- Performance: heading index cache + binary search, docs-root cache
- Standalone userscript v3.0 kept as fallback for non-Quartz servers

### Step 4 (Planned)
- Inject `data-source-line` attributes via rehype plugin for line-level sync
- Add Quartz component plugin for comment UI
- WebSocket bidirectional: Neovim sends scroll, browser sends comments
- `glab` integration for MR workflow

### Dependencies Between Steps
- Steps 1–3 complete
- Step 4 requires Step 3 (needs line numbers + WebSocket)

---

## 6. Key Files Reference

| File | Role |
|------|------|
| `lua/modules/review.lua` | Main module (preview, sync, comments) |
| `lua/utils/websocket.lua` | Pure-Lua WebSocket server (vim.uv) |
| `scripts/review-sync.user.js` | Standalone userscript v3.0 (fallback) |
| `docs/review.md` | Full module documentation |
| `tests/spec/review_url_spec.lua` | URL mapping + slugify tests |

## 7. live-preview.nvim Source Reference

| Component | Path | What to Borrow |
|-----------|------|----------------|
| WebSocket server | `lua/livepreview/server/websocket.lua` | SHA1 handshake, frame encode/decode |
| WebSocket client | `static/ws-client.js` | Reconnection, message handling |
| Line numbers | `static/markdown/line-numbers.js` | `data-source-line` injection concept |
| Scroll sync | `ws-client.js` lines 80-100 | Nearest-line lookup + scrollIntoView |
| SHA1 utility | `lua/livepreview/utils.lua` | SHA1 for WebSocket handshake |
| Server init | `lua/livepreview/server/init.lua` | `send_scroll()` — cursor dedup pattern |

License: live-preview.nvim is MIT+GPL dual-licensed. The WebSocket
implementation references `glacambre/firenvim` for SHA1.
