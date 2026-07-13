#!/usr/bin/env python3
"""Regenerate every dbt model through the public layer-model macro API."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[1]
INVENTORY_PATH = ROOT / "model_generation" / "model_inventory.yml"
EPHEMERAL_COLUMNS_PATH = ROOT / "model_generation" / "ephemeral_columns.yml"
MANIFEST_PATH = ROOT / "target" / "manifest.json"
OUTPUT_ROOT = ROOT / "target" / "model_generation"
ARTIFACT_ROOT = OUTPUT_ROOT / "artifacts"
REGENERATED_PROJECT = OUTPUT_ROOT / "regenerated_project"
COMMAND_LOG_PATH = OUTPUT_ROOT / "commands.log"
REFERENCE_LOG_PATH = ROOT / "docs" / "reference" / "model-generation-log.md"

CONFIG_RE = re.compile(r"^\s*\{\{\s*config\(.*?\)\s*\}\}\s*", re.DOTALL)
TIMESTAMP_RE = re.compile(r"^\d{2}:\d{2}:\d{2}(?:\s{2}.*)?$")


def load_yaml(path: Path) -> dict[str, Any]:
    value = yaml.safe_load(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a YAML mapping")
    return value


def load_manifest() -> dict[str, Any]:
    if not MANIFEST_PATH.exists():
        raise FileNotFoundError(
            "target/manifest.json is missing; run dbt parse before regeneration"
        )
    return json.loads(MANIFEST_PATH.read_text())


def inventory() -> list[dict[str, Any]]:
    entries = load_yaml(INVENTORY_PATH).get("models")
    if not isinstance(entries, list):
        raise ValueError("model_inventory.yml models must be a list")
    return entries


def ephemeral_columns() -> dict[str, list[dict[str, Any]]]:
    models = load_yaml(EPHEMERAL_COLUMNS_PATH).get("models")
    if not isinstance(models, dict):
        raise ValueError("ephemeral_columns.yml models must be a mapping")
    return models


def manifest_models(manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for node in manifest["nodes"].values():
        if node.get("resource_type") == "model":
            result[node["original_file_path"]] = node
    return result


def validate_inventory(
    entries: list[dict[str, Any]], nodes_by_path: dict[str, dict[str, Any]]
) -> None:
    listed = [entry["path"] for entry in entries]
    actual = list(nodes_by_path)
    if len(listed) != len(set(listed)):
        raise ValueError("model inventory contains duplicate paths")
    if set(listed) != set(actual):
        missing = sorted(set(actual) - set(listed))
        extra = sorted(set(listed) - set(actual))
        raise ValueError(f"model inventory mismatch; missing={missing}, extra={extra}")


def strip_leading_config(raw_code: str) -> str:
    return CONFIG_RE.sub("", raw_code, count=1).strip()


def normalized_columns(
    node: dict[str, Any], ephemeral: dict[str, list[dict[str, Any]]]
) -> list[dict[str, Any]]:
    if node["config"]["materialized"] == "ephemeral":
        columns = ephemeral.get(node["name"])
        if not columns:
            raise ValueError(f"missing ephemeral column contract for {node['name']}")
        return columns

    columns: list[dict[str, Any]] = []
    for column in node["columns"].values():
        data_type = column.get("data_type")
        description = column.get("description")
        if not data_type or not description:
            raise ValueError(f"{node['name']}.{column['name']} requires data_type and description")
        normalized: dict[str, Any] = {
            "name": column["name"],
            "data_type": data_type,
            "description": description,
        }
        materialized = node["config"]["materialized"]
        if materialized in {"table", "incremental"}:
            if column.get("databricks_tags") is not None:
                normalized["databricks_tags"] = column["databricks_tags"]
            if column.get("column_mask") is not None:
                normalized["column_mask"] = column["column_mask"]
        columns.append(normalized)
    return columns


def deletion_spec(policy: str) -> dict[str, Any] | None:
    policies: dict[str, dict[str, Any] | None] = {
        "none": None,
        "raw_customer_ssn": {
            "model_type": "QUARANTINE",
            "customer_key_column": "customer_ssn",
            "customer_key_domain": "customer.ssn",
            "customer_key_kind": "ssn",
        },
        "customer_key": {
            "model_type": "MAPPING",
            "customer_key_column": "customer_key",
        },
        "identity_key": {
            "model_type": "IDENTITY",
            "customer_key_column": "customer_key",
        },
        "service_key": {
            "model_type": "SERVICE",
            "customer_key_column": "customer_key",
        },
        "dimension_key": {
            "model_type": "DIMENSION",
            "customer_key_column": "customer_key",
        },
        "fact_applied_customer": {
            "model_type": "FACT",
            "customer_key_column": "customer_key",
            "special_replacement_columns": ["customer_key"],
            "erased_flag_column": "is_erased_customer",
            "source_is_policy_applied": True,
        },
        "fact_applied_invoice_resolution": {
            "model_type": "FACT",
            "customer_key_column": "customer_key",
            "special_replacement_columns": [
                "customer_key",
                "service_key",
                "resolved_service_version_key",
            ],
            "erased_flag_column": "is_erased_customer",
            "source_is_policy_applied": True,
        },
        "fact_applied_invoice": {
            "model_type": "FACT",
            "customer_key_column": "customer_key",
            "special_replacement_columns": [
                "customer_key",
                "service_key",
                "service_version_key",
            ],
            "erased_flag_column": "is_erased_customer",
            "source_is_policy_applied": True,
        },
        "case_customer_key": {
            "model_type": "CASE_VIEW",
            "customer_key_column": "customer_key",
        },
    }
    if policy not in policies:
        raise ValueError(f"unknown inventory policy: {policy}")
    value = policies[policy]
    return dict(value) if value is not None else None


def build_spec(
    entry: dict[str, Any],
    node: dict[str, Any],
    ephemeral: dict[str, list[dict[str, Any]]],
) -> dict[str, Any]:
    spec: dict[str, Any] = {
        "model_kind": entry["kind"],
        "model_name": node["name"],
        "description": node.get("description") or f"Regenerated {node['name']} model.",
    }
    if entry["kind"] == "DATE_DIMENSION":
        spec["materialized"] = node["config"]["materialized"]
        spec["tags"] = node.get("tags", [])
        return spec

    spec.update(
        {
            "primary_key": entry["primary_key"],
            "source_cte": "regenerated_source",
            "ctes": [
                {
                    "name": "regenerated_source",
                    "sql": strip_leading_config(node["raw_code"]),
                }
            ],
            "columns": normalized_columns(node, ephemeral),
            "materialized": node["config"]["materialized"],
            "tags": node.get("tags", []),
        }
    )
    if node["config"].get("databricks_tags"):
        spec["databricks_tags"] = node["config"]["databricks_tags"]
    if node["config"]["materialized"] == "incremental":
        spec["incremental"] = {
            "unique_key": node["config"]["unique_key"],
            "strategy": node["config"].get("incremental_strategy") or "merge",
            "on_schema_change": node["config"].get("on_schema_change") or "fail",
        }
    deletion = deletion_spec(entry["policy"])
    if deletion is not None:
        spec["deletion"] = deletion
    return spec


def all_specs() -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    manifest = load_manifest()
    nodes_by_path = manifest_models(manifest)
    entries = inventory()
    validate_inventory(entries, nodes_by_path)
    ephemeral = ephemeral_columns()
    specs: dict[str, dict[str, Any]] = {}
    for entry in entries:
        node = nodes_by_path[entry["path"]]
        specs[node["name"]] = build_spec(entry, node, ephemeral)
    return entries, specs


def args_json(model_name: str) -> str:
    _, specs = all_specs()
    try:
        spec = specs[model_name]
    except KeyError as exc:
        raise ValueError(f"unknown model: {model_name}") from exc
    return json.dumps({"spec": spec}, separators=(",", ":"))


def exact_command(*, model_name: str, generator: str) -> str:
    args_command = (
        "uv run --locked python scripts/regenerate_models.py args --model "
        + shlex.quote(model_name)
    )
    return " ".join(
        [
            "DATABRICKS_CONFIG_PROFILE=bricksgdpr",
            "DBT_SEND_ANONYMOUS_USAGE_STATS=false",
            "DBT_PROJECT_CATALOG=bricksgdpr",
            "DBT_CONTROL_CATALOG=workspace",
            "DBT_CONTROL_SCHEMA=default",
            "uv run --locked dbt run-operation",
            shlex.quote(generator),
            f'--args "$({args_command})"',
            "--profiles-dir . --no-use-colors",
        ]
    )


def extract_sections(output: str) -> tuple[str, str]:
    lines = output.splitlines()
    try:
        model_index = next(i for i, line in enumerate(lines) if line.strip() == "MODEL SQL")
        schema_index = next(i for i, line in enumerate(lines) if line.strip() == "SCHEMA YAML")
    except StopIteration as exc:
        raise ValueError("generator output is missing MODEL SQL or SCHEMA YAML") from exc
    model_lines = lines[model_index + 1 : schema_index]
    while model_lines and TIMESTAMP_RE.match(model_lines[-1]):
        model_lines.pop()
    model_sql = "\n".join(model_lines).strip()
    schema_lines = lines[schema_index + 1 :]
    while schema_lines and TIMESTAMP_RE.match(schema_lines[-1]):
        schema_lines.pop()
    schema_yaml = "\n".join(schema_lines).strip()
    if not model_sql or not schema_yaml:
        raise ValueError("generator output contained an empty artifact section")
    if any(TIMESTAMP_RE.match(line.strip()) for line in model_sql.splitlines()):
        raise ValueError("generator model SQL contains a dbt log timestamp")
    if any(TIMESTAMP_RE.match(line.strip()) for line in schema_yaml.splitlines()):
        raise ValueError("generator schema YAML contains a dbt log timestamp")
    return model_sql + "\n", schema_yaml + "\n"


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def generation_input_sha256() -> str:
    paths = [
        INVENTORY_PATH,
        EPHEMERAL_COLUMNS_PATH,
        Path(__file__),
        ROOT / "dbt_project.yml",
        *sorted((ROOT / "macros").rglob("*.sql")),
        *sorted((ROOT / "models").rglob("*.sql")),
        *sorted((ROOT / "models").rglob("*.yml")),
    ]
    digest = hashlib.sha256()
    for path in paths:
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def diff_counts(original: str, generated: str) -> tuple[int, int]:
    import difflib

    diff = difflib.unified_diff(original.splitlines(), generated.splitlines(), lineterm="")
    added = 0
    removed = 0
    for line in diff:
        if line.startswith("+++") or line.startswith("---"):
            continue
        if line.startswith("+"):
            added += 1
        elif line.startswith("-"):
            removed += 1
    return added, removed


def prepare_regenerated_project(generated_by_path: dict[str, str]) -> None:
    if REGENERATED_PROJECT.exists():
        shutil.rmtree(REGENERATED_PROJECT)

    ignored_top_level = {
        ".databricks",
        ".databrickscfg",
        ".dbt",
        ".env",
        ".git",
        ".user.yml",
        ".venv",
        "logs",
        "site",
        "target",
        "tutorial",
    }

    def ignore(directory: str, names: list[str]) -> set[str]:
        if Path(directory) == ROOT:
            return {name for name in names if name in ignored_top_level}
        return {"__pycache__"} & set(names)

    shutil.copytree(ROOT, REGENERATED_PROJECT, ignore=ignore)
    for relative_path, generated_sql in generated_by_path.items():
        destination = REGENERATED_PROJECT / relative_path
        destination.write_text(generated_sql)


def write_reference_log(
    *,
    rows: list[dict[str, Any]],
    commands: list[str],
) -> None:
    commit = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    generated_at = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()
    lines = [
        "---",
        "title: Model generation log",
        "icon: lucide/file-clock",
        "---",
        "",
        "# Model generation log",
        "",
        f"- Baseline commit: `{commit}`",
        f"- Generation-input SHA-256: `{generation_input_sha256()}`",
        f"- Generated at: `{generated_at}`",
        "- Databricks profile: `bricksgdpr`",
        "- Connection inputs: `DATABRICKS_HOST` and `DATABRICKS_HTTP_PATH` environment variables",
        f"- Models generated: `{len(rows)}`",
        "- Artifact workspace: `target/model_generation/` (ignored)",
        "",
        "Each command below was executed from the repository root. Specifications are derived from",
        "the checked-in inventory, model SQL, model YAML metadata, and the parsed dbt manifest.",
        "Connection variables were supplied to the harness environment and are intentionally",
        "not expanded in this publication-safe log.",
        "",
        "## Artifact and textual-diff summary",
        "",
        "| Model | Generator | Kind | Text diff | Generated SQL SHA-256 | Generated YAML SHA-256 |",
        "| --- | --- | --- | ---: | --- | --- |",
    ]
    for row in rows:
        summary_row = (
            "| `{model}` | `{generator}` | `{kind}` | +{added}/-{removed} | "
            "`{sql_hash}` | `{yaml_hash}` |"
        )
        lines.append(summary_row.format(**row))
    lines.extend(["", "## Exact generation commands", ""])
    for row, command in zip(rows, commands, strict=True):
        lines.extend(
            [
                f"### `{row['model']}`",
                "",
                "```bash",
                command,
                "```",
                "",
            ]
        )
    lines.extend(
        [
            "## Evidence boundary",
            "",
            "Textual differences are expected because the generator wraps bespoke business SQL in",
            "an explicit source CTE and projection. Equality is established only after the",
            "isolated regenerated project passes compilation, the full live dbt build, and",
            "bidirectional `EXCEPT ALL` comparisons against canonical physical relations.",
            "",
        ]
    )
    REFERENCE_LOG_PATH.write_text("\n".join(lines))


def generate_all(host: str, http_path: str) -> None:
    entries, specs = all_specs()
    del specs  # Specifications are resolved per exact logged command.
    if OUTPUT_ROOT.exists():
        shutil.rmtree(OUTPUT_ROOT)
    ARTIFACT_ROOT.mkdir(parents=True)

    generated_by_path: dict[str, str] = {}
    rows: list[dict[str, Any]] = []
    commands: list[str] = []
    raw_logs = OUTPUT_ROOT / "raw_logs"
    raw_logs.mkdir()

    manifest = load_manifest()
    nodes_by_path = manifest_models(manifest)
    for index, entry in enumerate(entries, start=1):
        node = nodes_by_path[entry["path"]]
        command = exact_command(
            model_name=node["name"],
            generator=entry["generator"],
        )
        print(f"[{index:02d}/{len(entries)}] {node['name']}", flush=True)
        result = subprocess.run(
            command,
            cwd=ROOT,
            shell=True,
            executable="/bin/zsh",
            capture_output=True,
            text=True,
            env={
                **os.environ,
                "DATABRICKS_HOST": host,
                "DATABRICKS_HTTP_PATH": http_path,
            },
        )
        combined_output = result.stdout + result.stderr
        (raw_logs / f"{node['name']}.log").write_text(combined_output)
        if result.returncode != 0:
            raise RuntimeError(
                f"generator failed for {node['name']} with exit {result.returncode}; "
                f"see {raw_logs / (node['name'] + '.log')}"
            )
        model_sql, schema_yaml = extract_sections(combined_output)
        relative = Path(entry["path"])
        artifact_dir = ARTIFACT_ROOT / relative.parent
        artifact_dir.mkdir(parents=True, exist_ok=True)
        sql_path = artifact_dir / f"{relative.stem}.generated.sql"
        yaml_path = artifact_dir / f"{relative.stem}.generated.yml"
        sql_path.write_text(model_sql)
        yaml_path.write_text(schema_yaml)
        original = (ROOT / relative).read_text()
        added, removed = diff_counts(original, model_sql)
        rows.append(
            {
                "model": node["name"],
                "generator": entry["generator"],
                "kind": entry["kind"],
                "added": added,
                "removed": removed,
                "sql_hash": sha256_text(model_sql),
                "yaml_hash": sha256_text(schema_yaml),
            }
        )
        commands.append(command)
        generated_by_path[entry["path"]] = model_sql

    COMMAND_LOG_PATH.write_text("\n".join(commands) + "\n")
    (OUTPUT_ROOT / "generation_summary.json").write_text(json.dumps(rows, indent=2) + "\n")
    prepare_regenerated_project(generated_by_path)
    write_reference_log(
        rows=rows,
        commands=commands,
    )
    print(f"Generated {len(rows)} models into {OUTPUT_ROOT}")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    subparsers = result.add_subparsers(dest="command", required=True)
    args_parser = subparsers.add_parser("args", help="Print dbt --args JSON for one model")
    args_parser.add_argument("--model", required=True)
    generate_parser = subparsers.add_parser(
        "generate-all", help="Run every exact generator command and prepare a temp project"
    )
    generate_parser.add_argument(
        "--host", default=os.environ.get("DATABRICKS_HOST"), required=False
    )
    generate_parser.add_argument(
        "--http-path", default=os.environ.get("DATABRICKS_HTTP_PATH"), required=False
    )
    return result


def main() -> int:
    arguments = parser().parse_args()
    try:
        if arguments.command == "args":
            print(args_json(arguments.model))
        elif arguments.command == "generate-all":
            if not arguments.host or not arguments.http_path:
                raise ValueError("generate-all requires --host and --http-path")
            generate_all(arguments.host, arguments.http_path)
    except (FileNotFoundError, RuntimeError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
