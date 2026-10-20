"""Read-only authentication, workspace identity and output contract tests."""

import json

from support import WorkspaceFixture


class DiscoveryTests(WorkspaceFixture):
    def test_discovers_three_workspaces_and_writes_only_infrastructure_inventory(self) -> None:
        self.outputs["shared"]["secret_test_value"] = "must-not-appear"
        self.sensitive.add("secret_test_value")
        self.require_success(self.run_play())
        text = (self.root / "inventory.json").read_text()
        host = json.loads(text)["all"]["children"]["haproxy"]["hosts"]["demo_haproxy"]
        self.assertEqual(host["ansible_host"], "192.0.2.50")
        self.assertEqual(host["runtime_sites"]["dc2"][1]["address"], "10.20.2.11")
        self.assertEqual(set(host["terraform_workspace_workspaces"]), {"shared", "dc1", "dc2"})
        self.assertNotIn("must-not-appear", text)
        self.assertNotIn("fixture-token", text)
        self.assertEqual(self.posts, [])
        self.assertFalse(any("state-versions/" in path for path in self.paths))

    def test_refuses_bad_auth_missing_workspace_and_missing_outputs(self) -> None:
        self.env["TFE_TOKEN"] = "invalid-fixture-token"
        self.require_failure(self.run_play())
        self.env["TFE_TOKEN"] = "fixture-token"
        del self.workspaces["dc2"]
        self.require_failure(self.run_play())
        self.assertEqual(self.posts, [])

    def test_rejects_sensitive_missing_and_invalid_output_values(self) -> None:
        self.sensitive.add("frontdoor_public_ip")
        self.require_failure(self.run_play(), "is missing, duplicated, null or sensitive")
        self.sensitive.clear()
        del self.outputs["shared"]["haproxy_private_ip"]
        self.require_failure(self.run_play(), "is missing, duplicated, null or sensitive")
        self.outputs["shared"]["haproxy_private_ip"] = "10.20.0.10"
        self.outputs["dc1"]["health_urls"][0] = "http://unexpected.invalid/health"
        self.require_failure(self.run_play(), "Unexpected address, instance ID or health URL")
        self.assertEqual(self.posts, [])

    def test_retries_processing_outputs_and_rejects_wrong_workspace_identity(self) -> None:
        self.processing_responses = 1
        self.require_success(self.run_play())
        self.workspaces["dc1"]["attributes"]["name"] = "unrelated"
        self.require_failure(self.run_play(), "Unexpected Terraform workspace identity")
        self.assertEqual(self.posts, [])
