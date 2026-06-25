// ==UserScript==
// @name         Neovim Review Sync
// @namespace    nvim-review
// @version      2.0
// @description  Connects to neovim's WebSocket relay and scrolls to the
//               target heading without stealing browser focus.
//               Install via Violentmonkey or Greasemonkey.
// @match        http://localhost:*/*
// @match        http://127.0.0.1:*/*
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function () {
  "use strict";

  // ── Configuration ─────────────────────────────────────────────────────
  const RECONNECT_DELAY_MS = 2000;

  // Relay port = preview port + 10000.  Auto-detect from current page.
  const previewPort = window.location.port || "8080";
  const relayPort = String(Number(previewPort) + 10000);
  const WS_URL = `ws://127.0.0.1:${relayPort}`;

  let lastUrl = "";
  let ws = null;

  // ── WebSocket connection ──────────────────────────────────────────────

  function connect() {
    try {
      ws = new WebSocket(WS_URL);
    } catch (e) {
      setTimeout(connect, RECONNECT_DELAY_MS);
      return;
    }

    ws.onopen = function () {
      console.log(`[nvim-review] Connected to relay on :${relayPort}`);
    };

    ws.onmessage = function (event) {
      try {
        const msg = JSON.parse(event.data);
        handleMessage(msg);
      } catch (e) {
        console.warn("[nvim-review] Invalid message:", event.data);
      }
    };

    ws.onclose = function () {
      console.log("[nvim-review] Relay disconnected, reconnecting...");
      ws = null;
      setTimeout(connect, RECONNECT_DELAY_MS);
    };

    ws.onerror = function () {
      // onclose will fire after this, triggering reconnect
    };
  }

  // ── Message handling ──────────────────────────────────────────────────

  function handleMessage(msg) {
    // msg: { type: "scroll"|"navigate", url, path, anchor }
    const targetUrl = msg.url;
    if (!targetUrl || targetUrl === lastUrl) return;
    lastUrl = targetUrl;

    const currentPath = window.location.pathname;
    const targetPath = msg.path || "/";
    const targetAnchor = msg.anchor || "";

    if (msg.type === "navigate" || targetPath !== currentPath) {
      // Page-level: navigate (full page load or SPA nav)
      if (targetPath !== currentPath) {
        // Try Quartz SPA navigation first (looks for internal links)
        const spaLink = document.querySelector(
          `a[href="${targetPath}"], a[href="${targetPath}/"]`
        );
        if (spaLink) {
          spaLink.click();
          // After SPA nav, scroll to anchor
          if (targetAnchor) {
            setTimeout(() => scrollToAnchor(targetAnchor), 300);
          }
        } else {
          window.location.href = targetUrl;
        }
        return;
      }
    }

    // Same page: scroll to anchor
    if (targetAnchor) {
      scrollToAnchor(targetAnchor);
      history.replaceState(null, "", "#" + targetAnchor);
    }
  }

  function scrollToAnchor(id) {
    // Quartz uses id attributes on headings
    const el =
      document.getElementById(id) ||
      document.querySelector(`[data-heading="${id}"]`) ||
      document.querySelector(`a[href="#${id}"]`);

    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "start" });
    } else {
      console.log(`[nvim-review] Heading "#${id}" not found on page`);
    }
  }

  // ── Start ─────────────────────────────────────────────────────────────

  console.log(
    `[nvim-review] Userscript v2.0 active — WebSocket relay at :${relayPort}`
  );
  connect();
})();
