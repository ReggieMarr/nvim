// ==UserScript==
// @name         Neovim Review Sync
// @namespace    nvim-review
// @version      3.0
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
  const SCROLL_RETRY_MS = 100;
  const SCROLL_MAX_RETRIES = 15; // 100ms × 15 = 1.5s max wait

  // Relay port = preview port + 10000.  Auto-detect from current page.
  const previewPort = window.location.port || "8080";
  const relayPort = String(Number(previewPort) + 10000);
  const WS_URL = `ws://127.0.0.1:${relayPort}`;

  let ws = null;

  // ── Pending scroll ────────────────────────────────────────────────────
  // After SPA navigation, we wait for Quartz's "nav" event before
  // scrolling.  If no event arrives within the retry window, we fall
  // back to polling for the heading element.
  let pendingAnchor = null;
  let scrollRetryTimer = null;
  let scrollRetryCount = 0;

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
    const targetPath = msg.path || "/";
    const targetAnchor = msg.anchor || "";
    const currentPath = window.location.pathname;

    // Normalise trailing slash for comparison
    const normTarget = targetPath.replace(/\/$/, "") || "/";
    const normCurrent = currentPath.replace(/\/$/, "") || "/";

    if (normTarget !== normCurrent) {
      // Different page — trigger SPA navigation
      navigateToPage(normTarget, targetAnchor);
      return;
    }

    // Same page — scroll to anchor
    if (targetAnchor) {
      scrollToAnchor(targetAnchor);
    }
  }

  // ── SPA-aware page navigation ─────────────────────────────────────────
  // Quartz v5 SPA mode intercepts clicks on internal <a> elements.
  // We create a temporary link and click it to trigger Quartz's router.
  // If that doesn't work (SPA disabled, wrong URL), fall back to
  // location.href which does a full page load.

  function navigateToPage(targetPath, anchor) {
    // Remember anchor so we can scroll after navigation completes
    pendingAnchor = anchor || null;
    cancelScrollRetry();

    // Try SPA navigation by clicking a synthetic link
    const tempLink = document.createElement("a");
    tempLink.href = targetPath;
    tempLink.style.display = "none";
    document.body.appendChild(tempLink);

    // Listen for Quartz's "nav" event (fires after SPA DOM swap)
    if (pendingAnchor) {
      waitForNavThenScroll(pendingAnchor);
    }

    tempLink.click();
    tempLink.remove();

    // If Quartz SPA doesn't handle it (no "nav" event within timeout),
    // the retry loop in waitForNavThenScroll will attempt to scroll
    // or we fall through to full navigation.
  }

  // ── Wait for Quartz "nav" event, then scroll ─────────────────────────
  // Quartz v5 fires a "nav" custom event on `document` after SPA
  // navigation completes and the new DOM is in place.

  function waitForNavThenScroll(anchor) {
    cancelScrollRetry();
    scrollRetryCount = 0;

    // Strategy 1: listen for Quartz's "nav" event (preferred)
    const onNav = () => {
      document.removeEventListener("nav", onNav);
      cancelScrollRetry();
      // Small delay to let Quartz finish rendering (e.g., syntax highlighting)
      setTimeout(() => scrollToAnchor(anchor), 50);
    };
    document.addEventListener("nav", onNav, { once: true });

    // Strategy 2: poll for the element (fallback if "nav" never fires,
    // e.g., full page navigation or non-Quartz server)
    scrollRetryTimer = setInterval(() => {
      scrollRetryCount++;
      const el = findHeadingElement(anchor);
      if (el) {
        document.removeEventListener("nav", onNav);
        cancelScrollRetry();
        el.scrollIntoView({ behavior: "smooth", block: "start" });
        history.replaceState(null, "", "#" + anchor);
      } else if (scrollRetryCount >= SCROLL_MAX_RETRIES) {
        document.removeEventListener("nav", onNav);
        cancelScrollRetry();
        console.log(`[nvim-review] Heading "#${anchor}" not found after ${SCROLL_MAX_RETRIES} retries`);
      }
    }, SCROLL_RETRY_MS);
  }

  function cancelScrollRetry() {
    if (scrollRetryTimer) {
      clearInterval(scrollRetryTimer);
      scrollRetryTimer = null;
    }
    scrollRetryCount = 0;
  }

  // ── Scroll to anchor ─────────────────────────────────────────────────

  function findHeadingElement(id) {
    return (
      document.getElementById(id) ||
      document.querySelector(`[data-heading="${id}"]`) ||
      // Quartz wraps heading text in an anchor; check for that too
      document.querySelector(`h1 a[href="#${id}"], h2 a[href="#${id}"], h3 a[href="#${id}"], h4 a[href="#${id}"], h5 a[href="#${id}"], h6 a[href="#${id}"]`)
    );
  }

  function scrollToAnchor(id) {
    const el = findHeadingElement(id);
    if (el) {
      // If we found an anchor inside a heading, scroll the heading itself
      const heading = el.closest("h1, h2, h3, h4, h5, h6") || el;
      heading.scrollIntoView({ behavior: "smooth", block: "start" });
      history.replaceState(null, "", "#" + id);
    } else {
      console.log(`[nvim-review] Heading "#${id}" not found on page`);
    }
  }

  // ── Handle Quartz SPA "nav" events for pending scrolls ────────────────
  // When Quartz navigates via SPA (user clicking links, not our sync),
  // clear any stale pending state.
  document.addEventListener("nav", () => {
    pendingAnchor = null;
  });

  // ── Start ─────────────────────────────────────────────────────────────

  console.log(
    `[nvim-review] Userscript v3.0 active — WebSocket relay at :${relayPort}`
  );
  connect();
})();
