"""Normal-unlock behavior; runtime recovery guards are exercised separately."""

from support import WorkspaceFixture


class UnlockTests(WorkspaceFixture):
    def test_normal_unlock_is_idempotent_and_never_forces(self) -> None:
        self.lock_site()
        self.require_success(self.run_play("unlock"))
        self.assertFalse(self.workspaces["dc1"]["attributes"]["locked"])
        self.require_success(self.run_play("unlock"))
        self.assertEqual(self.posts, ["/api/v2/workspaces/ws-dc1/actions/unlock"])

    def test_refuses_other_incident_and_missing_normal_unlock_permission(self) -> None:
        self.lock_site(reason="Demo-managed datacentre quarantine - OTHER123 - dc1")
        self.require_failure(self.run_play("unlock"), "unrelated or run-owned lock")
        self.lock_site()
        self.workspaces["dc1"]["attributes"]["permissions"]["can-unlock"] = False
        self.require_failure(self.run_play("unlock"), "Token cannot normally unlock")
        self.assertEqual(self.posts, [])
        self.assertTrue(self.workspaces["dc1"]["attributes"]["locked"])

    def test_unlock_failure_preserves_quarantine(self) -> None:
        self.lock_site()
        self.unlock_conflict = True
        self.require_failure(self.run_play("unlock"))
        self.assertTrue(self.workspaces["dc1"]["attributes"]["locked"])
        self.assertEqual(self.posts, ["/api/v2/workspaces/ws-dc1/actions/unlock"])
