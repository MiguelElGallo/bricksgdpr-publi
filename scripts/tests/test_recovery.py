"""Verify expected recovery failures cannot depend on a dbt diagnostic stream."""

import subprocess
import unittest

from scripts.validate_recovery import operation_passed


class RecoveryOutcomeTests(unittest.TestCase):
    def test_expected_failure_matches_either_diagnostic_stream(self):
        for stdout, stderr in [
            ("Control relation missing", ""),
            ("", "Control relation missing"),
            ("dbt initialized", "Database Error: Control relation missing\n"),
        ]:
            with self.subTest(stdout=stdout, stderr=stderr):
                result = subprocess.CompletedProcess(["dbt"], 1, stdout, stderr)
                self.assertTrue(operation_passed(result, "Control relation missing"))

    def test_unrelated_failure_is_not_a_successful_rehearsal(self):
        result = subprocess.CompletedProcess(["dbt"], 1, "", "OAuth authentication failed")
        self.assertFalse(operation_passed(result, "Control relation missing"))

    def test_expected_message_with_success_exit_does_not_pass(self):
        for stdout, stderr in [("Control relation missing", ""), ("", "Control relation missing")]:
            with self.subTest(stdout=stdout, stderr=stderr):
                result = subprocess.CompletedProcess(["dbt"], 0, stdout, stderr)
                self.assertFalse(operation_passed(result, "Control relation missing"))

    def test_normal_operations_require_a_success_exit(self):
        self.assertTrue(operation_passed(subprocess.CompletedProcess(["dbt"], 0, "", ""), None))
        self.assertFalse(
            operation_passed(
                subprocess.CompletedProcess(["dbt"], 1, "", "unexpected failure"), None
            )
        )


if __name__ == "__main__":
    unittest.main()
