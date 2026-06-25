// ==UserScript==
// @name         Neovim Review Sync
// @namespace    nvim-review
// @version      1.0
// @description  Polls neovim review-relay and scrolls to the target heading
//               without stealing browser focus.  Install via Violentmonkey
//               or Greasemonkey.
// @match        http://localhost:*/*
// @match        http://127.0.0.1:*/*
// @grant        GM_xmlhttpRequest
// @connect      127.0.0.1
// @connect      localhost
// @run-at       document-idle
// ==/UserScript==

(function () {
  "use strict";

  // ── Configuration ─────────────────────────────────────────────────────
  const POLL_INTERVAL_MS = 500;

  // Relay port = preview port + 10000.  Auto-detect from current page.
  const previewPort = window.location.port || "8080";
  const relayPort = String(Number(previewPort) + 10000);
  const RELAY_URL = `http://127.0.0.1:${relayPort}/`;

  let lastUrl = "";
  let relayReachable = false;
  let failCount = 0;
  const MAX_SILENT_FAILS = 20; // Stop warning after this many consecutive fails

  // ── Polling loop ──────────────────────────────────────────────────────

  function poll() {
    // Use GM_xmlhttpRequest to bypass CORS restrictions
    if (typeof GM_xmlhttpRequest !== "undefined") {
      GM_xmlhttpRequest({
        method: "GET",
        url: RELAY_URL,
        timeout: 1000,
        onload: function (response) {
          failCount = 0;
          if (!relayReachable) {
            relayReachable = true;
            console.log(
              `[nvim-review] Connected to relay on :${relayPort}`
            );
          }
          handleResponse(response.responseText);
        },
        onerror: function () {
          failCount++;
          if (relayReachable && failCount === 1) {
            console.log("[nvim-review] Relay disconnected, will retry...");
          }
          relayReachable = false;
        },
        ontimeout: function () {
          failCount++;
          relayReachable = false;
        },
      });
    } else {
      // Fallback: standard fetch (may hit CORS issues)
      fetch(RELAY_URL, { cache: "no-store" })
        .then((r) => r.text())
        .then((text) => {
          failCount = 0;
          if (!relayReachable) {
            relayReachable = true;
            console.log(
              `[nvim-review] Connected to relay on :${relayPort}`
            );
          }
          handleResponse(text);
        })
        .catch(() => {
          failCount++;
          relayReachable = false;
        });
    }
  }

  function handleResponse(targetUrl) {
    if (!targetUrl || targetUrl === lastUrl) return;
    lastUrl = targetUrl;

    try {
      const target = new URL(targetUrl);
      const current = window.location;

      // Same page, different anchor → smooth scroll
      if (target.pathname === current.pathname) {
        if (target.hash) {
          scrollToAnchor(target.hash.slice(1));
          // Update URL bar without navigation
          history.replaceState(null, "", target.hash);
        }
        return;
      }

      // Different page → navigate (this will reload)
      window.location.href = targetUrl;
    } catch (e) {
      console.warn("[nvim-review] Invalid URL from relay:", targetUrl);
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
    `[nvim-review] Userscript active — polling relay at :${relayPort}`
  );
  setInterval(poll, POLL_INTERVAL_MS);

  // Initial poll
  poll();
})();
