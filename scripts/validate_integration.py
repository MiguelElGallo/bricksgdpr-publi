"""Run private dbt validation with isolated catalogs and sanitized per-stage evidence."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SUCCESS = {"success", "pass"}


def summarize_results(path: Path) -> dict[str, Any]:
    """Allowlist aggregate and node status fields; exclude SQL, errors and Personal Data."""
    if not path.exists():
        return {"available": False, "nodes": []}
    raw = json.loads(path.read_text())
    return {
        "available": True,
        "nodes": [
            {
                "node": row["unique_id"],
                "status": row["status"],
                "seconds": row.get("execution_time", 0),
            }
            for row in raw.get("results", [])
        ],
    }


def checked_configuration(env: dict[str, str]) -> dict[str, str]:
    """Require an explicit target and reject canonical/shared analytical catalogs."""
    required = [
        "DATABRICKS_CONFIG_PROFILE",
        "DATABRICKS_EXPECTED_HOST",
        "DATABRICKS_EXPECTED_CALLER",
        "DATABRICKS_WAREHOUSE_ID",
        "DBT_CONTROL_CATALOG",
        "DBT_PROJECT_CATALOG",
        "DBT_EVIDENCE_CATALOG",
    ]
    config = {key: env.get(key, "") for key in required}
    if any(not value for value in config.values()):
        raise ValueError("Set all integration target variables; see operations documentation.")
    for key in ["DBT_PROJECT_CATALOG", "DBT_EVIDENCE_CATALOG"]:
        if not re.fullmatch(r"bricksgdpr_validation_[a-z0-9_]+", config[key]):
            raise ValueError(f"{key} must match bricksgdpr_validation_[a-z0-9_]+.")
    if config["DBT_PROJECT_CATALOG"] == config["DBT_EVIDENCE_CATALOG"]:
        raise ValueError("Analytical and evidence catalogs must differ.")
    if env.get("DBT_SCHEMA_PREFIX", ""):
        raise ValueError("Use catalog isolation with an empty DBT_SCHEMA_PREFIX.")
    return config


def cli_json(profile: str, *args: str) -> Any:
    """Capture CLI output privately, including short-lived OAuth tokens."""
    result = subprocess.run(
        ["databricks", *args, "--profile", profile, "--output", "json"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        raise RuntimeError("Databricks CLI preflight failed; reauthenticate the selected profile.")
    return json.loads(result.stdout)


def preflight(config: dict[str, str], *, require_demo: bool = True) -> None:
    profile = config["DATABRICKS_CONFIG_PROFILE"]
    auth = cli_json(profile, "auth", "describe")
    actual_host = auth.get("details", {}).get("configuration", {}).get("host", {}).get("value")
    if actual_host != config["DATABRICKS_EXPECTED_HOST"].rstrip("/"):
        raise ValueError("Effective authentication host does not match DATABRICKS_EXPECTED_HOST.")
    user = cli_json(profile, "current-user", "me")
    if user.get("userName", "").lower() != config["DATABRICKS_EXPECTED_CALLER"].lower():
        raise ValueError("The authenticated caller does not match the expected caller.")
    cli_json(profile, "warehouses", "get", config["DATABRICKS_WAREHOUSE_ID"])
    if not require_demo:
        return
    groups = cli_json(profile, "groups", "list")
    names = {g.get("displayName") for g in groups}
    if not {"privacy_admins", "restricted_users", "case_users"} <= names:
        raise ValueError("Provision the three account persona groups before live integration.")
    secrets = cli_json(profile, "secrets", "list-secrets", "bricksgdpr")
    if "pepper_v1" not in {item.get("key") for item in secrets}:
        raise ValueError("Create the immutable demo pepper before live integration.")


def stages() -> list[tuple[str, list[str], bool]]:
    return [
        ("bootstrap", ["run-operation", "bootstrap_project_catalog"], False),
        (
            "controls",
            [
                "build",
                "--select",
                "+int_terminal_deleted_customer_keys",
                "--indirect-selection",
                "cautious",
                "--exclude",
                "tag:access_control",
            ],
            False,
        ),
        ("pending", ["run-operation", "begin_deletion_execution"], False),
        ("outputs", ["build", "--select", "*", "--exclude", "tag:access_control"], True),
        ("access", ["run-operation", "apply_access_controls"], False),
        ("verify", ["test", "--select", "*"], True),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply", action="store_true", help="Execute builds after read-only preflight."
    )
    parser.add_argument(
        "--personas", action="store_true", help="Also run temporary-persona acceptance."
    )
    args = parser.parse_args()
    config = checked_configuration(dict(os.environ))
    preflight(config)
    if not args.apply:
        print("Preflight passed. Review the target; use --apply to execute isolated validation.")
        return 0
    execution = uuid.uuid4().hex
    output = ROOT / "target" / "integration" / execution
    output.mkdir(parents=True, mode=0o700)
    report: dict[str, Any] = {"execution_id": execution, "stages": [], "status": "running"}
    report_path = output / "summary.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    # Tokens are passed only in subprocess memory, never written to the profile or artifacts.
    with tempfile.TemporaryDirectory(prefix="bricksgdpr-profile-") as directory:
        profile = Path(directory) / "profiles.yml"
        profile.write_text("""bricksgdpr:
  target: validation
  outputs:
    validation:
      type: databricks
      host: "{{ env_var('DATABRICKS_HOST') }}"
      http_path: "{{ env_var('DATABRICKS_HTTP_PATH') }}"
      catalog: "{{ env_var('DBT_CONTROL_CATALOG') }}"
      schema: default
      token: "{{ env_var('DBT_ENV_SECRET_BRICKSGDPR_SESSION_TOKEN') }}"
      threads: 4
""")
        for name, command, tracking in stages():
            env = dict(os.environ)
            env["DATABRICKS_HOST"] = config["DATABRICKS_EXPECTED_HOST"].removeprefix("https://")
            env["DATABRICKS_HTTP_PATH"] = "/sql/1.0/warehouses/" + config["DATABRICKS_WAREHOUSE_ID"]
            token = cli_json(config["DATABRICKS_CONFIG_PROFILE"], "auth", "token")
            env["DBT_ENV_SECRET_BRICKSGDPR_SESSION_TOKEN"] = token["access_token"]
            variables = {
                "project_catalog": config["DBT_PROJECT_CATALOG"],
                "evidence_catalog": config["DBT_EVIDENCE_CATALOG"],
                "deletion_execution_id": execution,
                "track_deletion_execution": tracking,
            }
            stage_dir = output / name
            stage_dir.mkdir(mode=0o700)
            # Local raw logs stay ignored/private. The summary below is the shareable artifact.
            with (stage_dir / "console.log").open("w") as log:
                result = subprocess.run(
                    [
                        str(Path(sys.executable).with_name("dbt")),
                        *command,
                        "--profiles-dir",
                        directory,
                        "--target-path",
                        str(stage_dir),
                        "--log-path",
                        str(stage_dir),
                        "--quiet",
                        "--warn-error-options",
                        '{"error": ["NoNodesForSelectionCriteria"]}',
                        "--vars",
                        json.dumps(variables),
                    ],
                    cwd=ROOT,
                    env=env,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    check=False,
                )
            report["stages"].append(
                {
                    "stage": name,
                    "returncode": result.returncode,
                    **summarize_results(stage_dir / "run_results.json"),
                }
            )
            report["status"] = "failed" if result.returncode else "running"
            report_path.write_text(json.dumps(report, indent=2) + "\n")
            if result.returncode:
                failure_command = [
                    str(Path(sys.executable).with_name("dbt")),
                    "run-operation",
                    "record_deletion_failure",
                    "--profiles-dir",
                    directory,
                    "--target-path",
                    str(stage_dir / "failure"),
                    "--log-path",
                    str(stage_dir / "failure"),
                    "--quiet",
                    "--vars",
                    json.dumps(variables),
                ]
                with (stage_dir / "failure.log").open("w") as failure_log:
                    failure = subprocess.run(
                        failure_command,
                        cwd=ROOT,
                        env=env,
                        stdout=failure_log,
                        stderr=subprocess.STDOUT,
                        check=False,
                    )
                report["failure_evidence_returncode"] = failure.returncode
                report_path.write_text(json.dumps(report, indent=2) + "\n")
                print(f"Stage {name} failed. Private evidence: {stage_dir}")
                return result.returncode
        if args.personas:
            persona = subprocess.run(
                ["bash", str(ROOT / "scripts/validate_personas.sh"), "--apply"],
                cwd=ROOT,
                check=False,
            )
            report["personas"] = {"returncode": persona.returncode}
            if persona.returncode:
                report["status"] = "failed"
                report_path.write_text(json.dumps(report, indent=2) + "\n")
                return persona.returncode
        report["status"] = "passed"
        report["personas"] = report.get("personas", {"status": "not_run"})
        report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Integration passed. Sanitized summary: {report_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1) from None
