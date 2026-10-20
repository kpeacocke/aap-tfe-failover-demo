"""Local TLS JSON:API fixture exercising the real Ansible collection and SDK."""

from __future__ import annotations

import json
import os
from pathlib import Path
import ssl
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


class WorkspaceFixture(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.workspaces = {
            site: {
                "id": f"ws-{site}",
                "type": "workspaces",
                "attributes": {
                    "name": f"ww-demo-{site}",
                    "locked": False,
                    "locked-reason": "",
                    "execution-mode": "local",
                    "permissions": {"can-lock": True, "can-unlock": True},
                },
                "relationships": {
                    "organization": {"data": {"type": "organizations", "id": "test-org"}},
                    "locked-by": {"data": None},
                },
            }
            for site in ("shared", "dc1", "dc2")
        }
        self.outputs = {
            "shared": {
                "frontdoor_public_ip": "192.0.2.50",
                "frontdoor_url": "http://192.0.2.50",
                "haproxy_private_ip": "10.20.0.10",
            },
            **{
                site: {
                    "datacentre_name": site,
                    "application_private_ips": [f"10.20.{number}.10", f"10.20.{number}.11"],
                    "application_instance_ids": ["i-0123", "i-0456"],
                    "health_urls": [
                        f"http://10.20.{number}.10:8080/health",
                        f"http://10.20.{number}.11:8080/health",
                    ],
                }
                for site, number in (("dc1", 1), ("dc2", 2))
            },
        }
        self.posts: list[str] = []
        self.paths: list[str] = []
        self.sensitive: set[str] = set()
        self.status = 200
        self.lock_conflict = False
        self.unlock_conflict = False
        self.processing_responses = 0
        fixture = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, format: str, *args: object) -> None:
                return

            def reply(self, status: int, body: object) -> None:
                data = json.dumps(body).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/vnd.api+json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def do_GET(self) -> None:
                path = urlsplit(self.path).path
                fixture.paths.append(path)
                if self.headers.get("Authorization") != "Bearer fixture-token":
                    self.reply(401, {"errors": [{"status": "401", "title": "Unauthorized"}]})
                    return
                if fixture.status != 200:
                    self.reply(fixture.status, {"errors": [{"title": "Fixture request refused"}]})
                    return
                if path.startswith("/api/v2/organizations/test-org/workspaces/ww-demo-"):
                    site = path.rsplit("-", 1)[1]
                elif path.startswith("/api/v2/workspaces/ws-"):
                    site = path.split("/")[4].removeprefix("ws-")
                else:
                    self.reply(404, {"errors": [{"title": "Unknown fixture path"}]})
                    return
                if site not in fixture.workspaces:
                    self.reply(404, {"errors": [{"title": "Workspace missing"}]})
                    return
                if path.endswith("/current-state-version-outputs"):
                    if fixture.processing_responses:
                        fixture.processing_responses -= 1
                        self.reply(503, {"errors": [{"title": "Outputs processing"}]})
                        return
                    entries = [
                        {
                            "id": f"wsout-{site}{index}",
                            "type": "state-version-outputs",
                            "attributes": {
                                "name": name,
                                "value": value,
                                "sensitive": name in fixture.sensitive,
                                "type": "array" if isinstance(value, list) else "string",
                            },
                        }
                        for index, (name, value) in enumerate(fixture.outputs[site].items())
                    ]
                    self.reply(200, {"data": entries, "links": {"next": None}})
                else:
                    self.reply(200, {"data": fixture.workspaces[site]})

            def do_POST(self) -> None:
                path = urlsplit(self.path).path
                fixture.posts.append(path)
                body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
                site = path.split("/")[4].removeprefix("ws-")
                workspace = fixture.workspaces[site]
                attributes = workspace["attributes"]
                if path.endswith("/actions/lock"):
                    if fixture.lock_conflict or attributes["locked"]:
                        self.reply(409, {"errors": [{"title": "Workspace already locked"}]})
                        return
                    fixture.lock_site(site, body["reason"])
                elif path.endswith("/actions/unlock"):
                    if fixture.unlock_conflict:
                        self.reply(409, {"errors": [{"title": "Cannot unlock"}]})
                        return
                    attributes["locked"] = False
                    attributes["locked-reason"] = ""
                    workspace["relationships"]["locked-by"]["data"] = None
                else:
                    self.reply(404, {"errors": [{"title": "Forbidden fixture operation"}]})
                    return
                self.reply(200, {"data": workspace})

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cert = self.root / "cert.pem"
        key = self.root / "key.pem"
        subprocess.run(
            ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
             "-keyout", str(key), "-out", str(cert), "-days", "1",
             "-subj", "/CN=127.0.0.1", "-addext", "subjectAltName=IP:127.0.0.1"],
            check=True, capture_output=True,
        )
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert, key)
        self.server.socket = context.wrap_socket(self.server.socket, server_side=True)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.env = {
            **os.environ,
            "ANSIBLE_CONFIG": "/repo/ansible.cfg",
            "TFE_ADDRESS": f"https://127.0.0.1:{self.server.server_port}",
            "TFE_TOKEN": "fixture-token",
            "HCP_TERRAFORM_ORGANIZATION": "test-org",
            "SSL_CERT_FILE": str(cert),
            "NO_PROXY": "127.0.0.1,localhost",
        }

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.directory.cleanup()

    def lock_site(self, site: str = "dc1", reason: str | None = None) -> None:
        workspace = self.workspaces[site]
        workspace["attributes"]["locked"] = True
        workspace["attributes"]["locked-reason"] = reason or f"Demo-managed datacentre quarantine - INC123 - {site}"
        workspace["relationships"]["locked-by"]["data"] = {"id": "user-fixture", "type": "users"}

    def run_play(self, action: str | None = None, **variables: object) -> subprocess.CompletedProcess[str]:
        playbook = "tests/terraform_api/operation.yml" if action else "playbooks/terraform-discover.yml"
        request = self.root / "request.json"
        request.write_text(json.dumps({
            "terraform_workspace_inventory_path": str(self.root / "inventory.json"),
            "runtime_ssh_private_key_path": "/fixture/dummy-key",
            **({"test_action": action} if action else {}),
            **variables,
        }))
        result = subprocess.run(
            ["ansible-playbook", "-i", "localhost,", playbook, "-e", f"@{request}"],
            env=self.env, text=True, capture_output=True, timeout=120,
        )
        self.assertNotIn("fixture-token", result.stdout + result.stderr)
        return result

    def require_success(self, result: subprocess.CompletedProcess[str]) -> None:
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def require_failure(self, result: subprocess.CompletedProcess[str], message: str = "") -> None:
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        if message:
            self.assertIn(message, result.stdout + result.stderr)


if __name__ == "__main__":
    service = WorkspaceFixture()
    service.setUp()
    try:
        Path(sys.argv[1]).write_text(json.dumps({
            "address": service.env["TFE_ADDRESS"],
            "ca_bundle": service.env["SSL_CERT_FILE"],
        }))
        threading.Event().wait()
    finally:
        service.tearDown()
