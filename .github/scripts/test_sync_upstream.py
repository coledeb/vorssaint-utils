"""Exercise sync decisions without changing GitHub."""

import unittest
from unittest.mock import Mock

from sync_upstream import sync


class SyncTests(unittest.TestCase):
    def test_no_updates_does_not_write(self):
        api = Mock(side_effect=[{"object": {"sha": "a"}}, {"object": {"sha": "a"}}, {"ahead_by": 0}])
        self.assertIn("No PR needed", sync(api))
        self.assertTrue(all(call.args[0] == "GET" for call in api.call_args_list))

    def test_fast_forward_and_create_pr(self):
        api = Mock(side_effect=[{"object": {"sha": "b"}}, {"object": {"sha": "a"}},
                               {"status": "ahead"}, {}, {"ahead_by": 3}, [], {"html_url": "https://example.test/pr/1"}])
        self.assertIn("Created update PR", sync(api))
        writes = [call for call in api.call_args_list if call.args[0] != "GET"]
        self.assertEqual(len(writes), 2)
        self.assertTrue(writes[0].args[1].endswith("/git/refs/heads/upstream"))
        self.assertEqual(writes[0].args[2], {"sha": "b", "force": False})
        self.assertEqual(writes[1].args[2]["base"], "main")

    def test_existing_pr_is_reused(self):
        api = Mock(side_effect=[{"object": {"sha": "a"}}, {"object": {"sha": "a"}},
                               {"ahead_by": 2}, [{"html_url": "https://example.test/pr/1"}]])
        self.assertIn("tracking upstream", sync(api))
        self.assertTrue(all(call.args[0] == "GET" for call in api.call_args_list))

    def test_divergence_and_rewound_source_stop_without_writes(self):
        for status in ("diverged", "behind"):
            with self.subTest(status=status):
                api = Mock(side_effect=[{"object": {"sha": "b"}}, {"object": {"sha": "a"}}, {"status": status}])
                with self.assertRaises(RuntimeError):
                    sync(api)
                self.assertTrue(all(call.args[0] == "GET" for call in api.call_args_list))

    def test_dry_run_never_writes(self):
        api = Mock(side_effect=[{"object": {"sha": "b"}}, {"object": {"sha": "a"}},
                               {"status": "ahead"}, {"ahead_by": 1}, []])
        self.assertIn("Would open", sync(api, dry_run=True))
        self.assertTrue(all(call.args[0] == "GET" for call in api.call_args_list))

    def test_update_failure_stops_before_pr(self):
        api = Mock(side_effect=[{"object": {"sha": "b"}}, {"object": {"sha": "a"}},
                               {"status": "ahead"}, RuntimeError("ref changed")])
        with self.assertRaisesRegex(RuntimeError, "ref changed"):
            sync(api)
        self.assertEqual(api.call_count, 4)


if __name__ == "__main__":
    unittest.main()
