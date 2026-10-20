"""Small standard-library HTTP service used by the failover demonstration."""

from __future__ import annotations

import html
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


def service_identity() -> dict[str, str]:
    return {
        "datacentre": os.environ.get("DEMO_DATACENTRE", "unknown"),
        "hostname": os.environ.get("DEMO_HOSTNAME", "unknown"),
        "version": os.environ.get("DEMO_VERSION", "unknown"),
    }


def health_response() -> dict[str, str]:
    return {"status": "healthy", **service_identity()}


def homepage() -> str:
    identity = service_identity()
    return f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Woolworths Demo Service</title>
    <style>
      body {{ font: 1.2rem system-ui, sans-serif; margin: 3rem auto; max-width: 42rem; }}
      h1 {{ color: #176b3a; }}
      .status {{ border-left: .4rem solid #25864b; padding: 1rem; background: #f2faf4; }}
      dt {{ font-weight: 700; margin-top: .75rem; }}
    </style>
  </head>
  <body>
    <h1>Woolworths Demo Service</h1>
    <section class="status">
      <strong>STATUS: HEALTHY</strong>
      <dl>
        <dt>ACTIVE DATACENTRE</dt><dd>{html.escape(identity["datacentre"].upper())}</dd>
        <dt>HOST</dt><dd>{html.escape(identity["hostname"])}</dd>
        <dt>APPLICATION VERSION</dt><dd>{html.escape(identity["version"])}</dd>
      </dl>
    </section>
  </body>
</html>
"""


class DemoRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        path = urlsplit(self.path).path
        if path == "/health":
            body = json.dumps(health_response()).encode("utf-8")
            content_type = "application/json; charset=utf-8"
            status = 200
        elif path == "/":
            body = homepage().encode("utf-8")
            content_type = "text/html; charset=utf-8"
            status = 200
        else:
            body = b'{"error":"not found"}'
            content_type = "application/json; charset=utf-8"
            status = 404

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), DemoRequestHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
