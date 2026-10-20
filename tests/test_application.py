import unittest
from http.server import ThreadingHTTPServer
from json import load
from threading import Thread
from urllib.request import urlopen
from unittest.mock import patch

from application.app import DemoRequestHandler, health_response, homepage


class DemoApplicationTests(unittest.TestCase):
    def test_homepage_uses_generic_branding(self) -> None:
        page = homepage()
        self.assertIn("<title>Datacentre Failover Demo</title>", page)
        self.assertIn("<h1>Datacentre Failover Demo</h1>", page)

    def test_health_response_includes_datacentre_and_hostname(self) -> None:
        with patch.dict(
            "os.environ",
            {
                "DEMO_DATACENTRE": "dc1",
                "DEMO_HOSTNAME": "dc1-app-01",
                "DEMO_VERSION": "1.0.0",
            },
            clear=True,
        ):
            self.assertEqual(
                health_response(),
                {
                    "status": "healthy",
                    "datacentre": "dc1",
                    "hostname": "dc1-app-01",
                    "version": "1.0.0",
                },
            )

    def test_homepage_escapes_identity_values(self) -> None:
        with patch.dict(
            "os.environ",
            {
                "DEMO_DATACENTRE": "<script>",
                "DEMO_HOSTNAME": "node&one",
                "DEMO_VERSION": "1.0.0",
            },
            clear=True,
        ):
            page = homepage()

        self.assertIn("&lt;SCRIPT&gt;", page)
        self.assertIn("node&amp;one", page)
        self.assertNotIn("<script>", page)

    def test_health_endpoint_returns_json(self) -> None:
        server = ThreadingHTTPServer(("127.0.0.1", 0), DemoRequestHandler)
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with patch.dict(
                "os.environ",
                {
                    "DEMO_DATACENTRE": "dc2",
                    "DEMO_HOSTNAME": "dc2-app-02",
                    "DEMO_VERSION": "1.0.0",
                },
                clear=True,
            ):
                with urlopen(f"http://127.0.0.1:{server.server_port}/health") as response:
                    self.assertEqual(response.status, 200)
                    self.assertEqual(
                        load(response),
                        {
                            "status": "healthy",
                            "datacentre": "dc2",
                            "hostname": "dc2-app-02",
                            "version": "1.0.0",
                        },
                    )
        finally:
            server.shutdown()
            thread.join()
            server.server_close()


if __name__ == "__main__":
    unittest.main()
