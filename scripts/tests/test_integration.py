"""Verify isolation, artifact redaction, and fail-closed workflow ordering."""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import yaml

from scripts.validate_integration import checked_configuration, preflight, stages, summarize_results


class IntegrationTests(unittest.TestCase):
    def test_bundle_wildcards_survive_shell_expansion(self):
        root = Path(__file__).resolve().parents[2]
        job = yaml.safe_load((root / "resources/bricksgdpr.job.yml").read_text())
        tasks = job["resources"]["jobs"]["bricksgdpr_dbt_workflow"]["tasks"]
        for task in tasks:
            if task["task_key"] not in {"build_outputs", "verify"}:
                continue
            command = task["dbt_task"]["commands"][0].split(" --vars ", 1)[0]
            result = subprocess.run(
                ["bash", "-c", 'dbt() { printf "%s\\n" "$@"; }\n' + command],
                cwd=root,
                capture_output=True,
                text=True,
                check=True,
            )
            arguments = result.stdout.splitlines()
            self.assertEqual(arguments[arguments.index("--select") + 1], "*")
            self.assertIn("--warn-error-options", arguments)

    def configuration(self):
        return {
            "DATABRICKS_CONFIG_PROFILE": "validation",
            "DATABRICKS_EXPECTED_HOST": "https://example.invalid",
            "DATABRICKS_EXPECTED_CALLER": "operator@example.invalid",
            "DATABRICKS_WAREHOUSE_ID": "warehouse",
            "DBT_CONTROL_CATALOG": "workspace",
            "DBT_PROJECT_CATALOG": "bricksgdpr_validation_test",
            "DBT_EVIDENCE_CATALOG": "bricksgdpr_validation_test_evidence",
        }

    def test_isolation(self):
        for catalog in ["bricksgdpr", "production", "bricksgdpr_validation_x;drop", ""]:
            with self.subTest(catalog=catalog), self.assertRaises(ValueError):
                checked_configuration(self.configuration() | {"DBT_PROJECT_CATALOG": catalog})
        config = self.configuration()
        config["DBT_EVIDENCE_CATALOG"] = config["DBT_PROJECT_CATALOG"]
        with self.assertRaises(ValueError):
            checked_configuration(config)
        self.assertEqual(checked_configuration(self.configuration()), self.configuration())

    def test_wrong_host_stops_before_identity_or_secrets(self):
        with (
            patch(
                "scripts.validate_integration.cli_json",
                return_value={
                    "details": {"configuration": {"host": {"value": "https://wrong.invalid"}}}
                },
            ) as cli,
            self.assertRaises(ValueError),
        ):
            preflight(self.configuration())
        self.assertEqual(cli.call_count, 1)

    def test_effective_identity_preflight_without_demo_setup(self):
        replies = [
            {"details": {"configuration": {"host": {"value": "https://example.invalid"}}}},
            {"userName": "operator@example.invalid"},
            {"id": "warehouse"},
        ]
        with patch("scripts.validate_integration.cli_json", side_effect=replies) as cli:
            preflight(self.configuration(), require_demo=False)
        self.assertEqual(cli.call_count, 3)

    def test_summary_excludes_sensitive_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "run_results.json"
            path.write_text(
                json.dumps(
                    {
                        "args": {"token": "secret"},
                        "results": [
                            {
                                "unique_id": "model.bricksgdpr.example",
                                "status": "error",
                                "execution_time": 1,
                                "message": "Personal Data",
                                "compiled_code": "sensitive SQL",
                                "adapter_response": {"data": "private"},
                            }
                        ],
                    }
                )
            )
            summary = summarize_results(path)
            self.assertEqual(set(summary["nodes"][0]), {"node", "status", "seconds"})
            self.assertNotIn("secret", json.dumps(summary))
            self.assertFalse(summarize_results(Path(directory) / "missing.json")["available"])

    def test_workflow_tracks_only_outputs_and_verification(self):
        commands = stages()
        self.assertEqual(
            [name for name, _, tracking in commands if tracking], ["outputs", "verify"]
        )
        self.assertEqual(commands[-1][1], ["test", "--select", "*"])
        self.assertLess(
            [s[0] for s in commands].index("pending"), [s[0] for s in commands].index("outputs")
        )


if __name__ == "__main__":
    unittest.main()
