"""Rehearse deletion archive and recovery using disposable synthetic Databricks fixtures."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

import yaml

if __package__:
    from .validate_integration import ROOT, checked_configuration, cli_json, preflight
else:
    from validate_integration import ROOT, checked_configuration, cli_json, preflight


def operation_passed(result: subprocess.CompletedProcess[str], expected_error: str | None) -> bool:
    """Require the expected outcome, recognizing dbt diagnostics on either output stream."""
    if expected_error is None:
        return result.returncode == 0
    combined_output = result.stdout + "\n" + result.stderr
    return result.returncode != 0 and expected_error in combined_output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    config = checked_configuration(dict(os.environ))
    preflight(config, require_demo=False)
    if not args.apply:
        print("Preflight passed. --apply creates and removes synthetic recovery fixtures.")
        return 0
    execution = uuid.uuid4().hex
    schema = "bricksgdpr_validation_ops_" + execution
    catalog = schema + "_evidence"
    output = ROOT / "target" / "recovery" / execution
    output.mkdir(parents=True, mode=0o700)
    project = output / "project"
    shutil.copytree(ROOT / "acceptance/operations", project)
    (project / "dbt_project.yml").write_text(
        yaml.safe_dump(
            {
                "name": "bricksgdpr",
                "version": "1.0",
                "config-version": 2,
                "profile": "bricksgdpr",
                "macro-paths": [str(ROOT / "macros"), "macros"],
                "model-paths": ["models"],
                "models": {
                    "bricksgdpr": {
                        "customer_deletion_requests": yaml.safe_load(
                            (ROOT / "dbt_project.yml").read_text()
                        )["models"]["bricksgdpr"]["layer1"]["customer_deletion_requests"]
                    }
                },
            }
        )
    )
    variables = {
        "project_catalog": config["DBT_CONTROL_CATALOG"],
        "evidence_catalog": catalog,
        "deletion_execution_id": execution,
        "track_deletion_execution": True,
    }
    report: dict = {"execution_id": execution, "checks": [], "status": "running"}
    with tempfile.TemporaryDirectory(prefix="bricksgdpr-recovery-") as directory:
        Path(directory, "profiles.yml").write_text("""bricksgdpr:
  target: validation
  outputs:
    validation:
      type: databricks
      host: "{{ env_var('DATABRICKS_HOST') }}"
      http_path: "{{ env_var('DATABRICKS_HTTP_PATH') }}"
      catalog: "{{ env_var('DBT_CONTROL_CATALOG') }}"
      schema: "{{ env_var('BRICKSGDPR_FIXTURE_SCHEMA') }}"
      token: "{{ env_var('DBT_ENV_SECRET_BRICKSGDPR_SESSION_TOKEN') }}"
      threads: 1
""")

        def run(operation: str, expected_error: str | None = None) -> bool:
            env = dict(os.environ)
            env["DATABRICKS_HOST"] = config["DATABRICKS_EXPECTED_HOST"].removeprefix("https://")
            env["DATABRICKS_HTTP_PATH"] = "/sql/1.0/warehouses/" + config["DATABRICKS_WAREHOUSE_ID"]
            env["BRICKSGDPR_FIXTURE_SCHEMA"] = schema
            env["DBT_ENV_SECRET_BRICKSGDPR_SESSION_TOKEN"] = cli_json(
                config["DATABRICKS_CONFIG_PROFILE"], "auth", "token"
            )["access_token"]
            command = (
                ["build", "--select", "customer_deletion_requests", "--full-refresh"]
                if operation == "build_full_refresh"
                else ["run-operation", operation]
            )
            result = subprocess.run(
                [
                    str(Path(sys.executable).with_name("dbt")),
                    *command,
                    "--project-dir",
                    str(project),
                    "--profiles-dir",
                    directory,
                    "--log-path",
                    str(output / "logs"),
                    "--quiet",
                    "--vars",
                    json.dumps(variables),
                ],
                capture_output=True,
                text=True,
                env=env,
                check=False,
            )
            (output / (operation + ".log")).write_text(result.stdout + result.stderr)
            passed = operation_passed(result, expected_error)
            report["checks"].append(
                {
                    "operation": operation,
                    "passed": passed,
                    "expected_failure": expected_error is not None,
                }
            )
            print(f"{operation}: {'PASS' if passed else 'FAIL'}", flush=True)
            return passed

        succeeded = False
        try:
            checks = [
                ("operations_fixture_setup", None),
                ("operations_fixture_missing", "Control relation missing"),
                ("operations_fixture_restore", None),
                ("build_full_refresh", None),
                ("operations_fixture_assert_retained", None),
                ("operations_fixture_restore", "refuses to overwrite"),
                ("operations_fixture_truncate", "keys are missing"),
                ("operations_fixture_status", None),
                ("operations_fixture_partial_verification", None),
                ("record_deletion_failure_and_raise", "Workflow failed; durable failure recording"),
                ("operations_fixture_invalid_ssn", "Invalid synthetic SSN"),
                ("operations_fixture_invalid_phone", "Invalid phone"),
            ]
            succeeded = all(run(operation, error) for operation, error in checks)
        finally:
            cleaned = run("operations_fixture_cleanup")
            report["status"] = "passed" if succeeded and cleaned else "failed"
            (output / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Sanitized recovery evidence: {output / 'summary.json'}")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1) from None
