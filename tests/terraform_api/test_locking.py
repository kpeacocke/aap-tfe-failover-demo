"""Incident ownership, idempotency, permissions and lock-conflict tests."""

from support import WorkspaceFixture


class LockTests(WorkspaceFixture):
    def test_locks_source_once_and_reuses_same_incident_without_affecting_target(self) -> None:
        self.require_success(self.run_play("lock"))
        self.assertTrue(self.workspaces["dc1"]["attributes"]["locked"])
        self.assertEqual(self.workspaces["dc1"]["attributes"]["locked-reason"],
                         "Demo-managed datacentre quarantine - INC123 - dc1")
        self.require_success(self.run_play("lock"))
        self.assertEqual(self.posts, ["/api/v2/workspaces/ws-dc1/actions/lock"])
        self.assertFalse(self.workspaces["dc2"]["attributes"]["locked"])
        self.assertFalse(self.workspaces["shared"]["attributes"]["locked"])

    def test_refuses_unrelated_or_run_owned_lock(self) -> None:
        self.lock_site(reason="Other operator maintenance")
        self.require_failure(self.run_play("lock"), "unrelated or run-owned lock")
        self.lock_site()
        self.workspaces["dc1"]["relationships"]["locked-by"]["data"] = {"id": "run-other", "type": "runs"}
        self.require_failure(self.run_play("lock"), "unrelated or run-owned lock")
        self.assertEqual(self.posts, [])

    def test_refuses_missing_permission_and_does_not_swallow_api_conflict(self) -> None:
        self.workspaces["dc1"]["attributes"]["permissions"]["can-lock"] = False
        self.require_failure(self.run_play("lock"), "Token cannot lock")
        self.assertEqual(self.posts, [])
        self.workspaces["dc1"]["attributes"]["permissions"]["can-lock"] = True
        self.lock_conflict = True
        self.require_failure(self.run_play("lock"))
        self.assertFalse(self.workspaces["dc1"]["attributes"]["locked"])
