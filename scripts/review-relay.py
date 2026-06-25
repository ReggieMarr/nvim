#!/usr/bin/env python3
"""Tiny HTTP relay for neovim review module heading-level sync.

Serves the contents of a URL file written by neovim's review.lua module.
A companion userscript in the browser polls this endpoint and scrolls
to the target heading without stealing window focus.

Usage:
    python3 review-relay.py <port> <url-file>

Endpoints:
    GET /       → returns the current target URL (text/plain)
    GET /port   → returns the preview port (for userscript auto-detection)

The server binds to 127.0.0.1 only (not exposed to network).
"""

import sys
import os
from http.server import HTTPServer, BaseHTTPRequestHandler


class RelayHandler(BaseHTTPRequestHandler):
    url_file = ""
    preview_port = ""

    def do_GET(self):
        # CORS headers for userscript fetch
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache, no-store")
        self.end_headers()

        if self.path == "/port":
            self.wfile.write(self.preview_port.encode())
            return

        try:
            with open(self.url_file, "r") as f:
                url = f.read().strip()
            self.wfile.write(url.encode())
        except FileNotFoundError:
            self.wfile.write(b"")

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def log_message(self, format, *args):
        # Suppress request logging to keep overseer output clean
        pass


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <port> <url-file>", file=sys.stderr)
        sys.exit(1)

    port = int(sys.argv[1])
    url_file = sys.argv[2]

    # Derive preview port from relay port (relay = preview + 10000)
    preview_port = str(port - 10000)

    RelayHandler.url_file = url_file
    RelayHandler.preview_port = preview_port

    server = HTTPServer(("127.0.0.1", port), RelayHandler)
    print(f"review-relay: listening on http://127.0.0.1:{port}")
    print(f"review-relay: serving URL file {url_file}")
    print(f"review-relay: preview port {preview_port}")
    sys.stdout.flush()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        # Clean up URL file
        try:
            os.remove(url_file)
        except OSError:
            pass


if __name__ == "__main__":
    main()
