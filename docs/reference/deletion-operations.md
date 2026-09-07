---
icon: lucide/clipboard-check
---

# Deletion operations and recovery

Deletion authorization, target construction, and verified output are separate facts. The operations
workflow preserves evidence and records progress without treating an admitted ledger key as proof
that every dependent table has finished rebuilding.

## Durable evidence

`bootstrap_project_catalog` also creates a separate evidence catalog. The default is the analytical
catalog name followed by `_evidence`; set `DBT_EVIDENCE_CATALOG` or dbt variable `evidence_catalog`
to choose it explicitly. The two catalogs must differ.

| Relation in `deletion_control` | Contents |
| --- | --- |
| `control_history` | Original typed row serialized as JSON, source relation, payload hash, archive timestamp, and dbt invocation ID |
| `execution_events` | Execution ID, target name, plan digest, state, timestamp, and dbt invocation ID |

Both are created with Delta `appendOnly=true`. Bootstrap checks that property on existing tables.
They are managed by explicit macros, outside the dbt model graph: model replacement, full refresh,
and `dbt clean` do not replace them. Identical archived payloads are deduplicated on replay.

Post-hooks archive requests, decision inputs, evaluated authorization history, authorized plans,
and terminal-ledger states. Reusing a decision revision ID with changed content fails the build;
submit a new revision instead. The raw evidence remains Personal Data and is not a public artifact.
`apply_access_controls` removes the three persona groups' catalog, schema, and table privileges on
this evidence. It also discovers and removes grants to `account users` and `users` at those
boundaries, without requiring both ambient groups to exist in every workspace.
The deployment owner and platform administrators retain administrative authority;
append-only properties do not prevent an administrator from changing properties or dropping tables.
Production separation of duties and independent backup remain operator responsibilities.

The three incremental controls—requests, plan, and terminal ledger—set `full_refresh: false` in
`dbt_project.yml`. A full-refresh flag cannot reset them. Pre-hooks refuse a missing control table
when archived evidence exists, missing archived keys in a surviving table, or a FULL ledger key
that was downgraded. Guards require a single writer for each analytical/evidence catalog pair.

Archive writes and model writes are separate transactions. If a post-hook fails or the process
stops between them, stop publication and rerun the affected control build to finish archiving.
Do not describe the archive as an atomic transaction across all target tables.

## Execution states

Each workflow attempt uses one `deletion_execution_id`. The bundle supplies its job run ID; the
private runner generates a UUID and uses it across all stages. A target's plan digest covers the
sorted hashes of all of its current authorized plan rows, including decision and policy fields.

| State | Meaning |
| --- | --- |
| `PENDING` | A target is planned, or its model was skipped |
| `COMPLETED` | That target model built successfully; deletion verification is still required |
| `FAILED` | A model failed, or the reserved `__workflow__` row records a failed execution phase |
| `VERIFIED` | Required deletion/access tests passed, with no failed result, and every target has current-plan completion evidence for this execution |

`record_deletion_results` runs after tracked dbt commands. A selection missing any required verification test cannot produce
`VERIFIED`. Failed tests record a workflow failure. The bundle's failure task and the local runner
also attempt a durable failure write after an earlier stage fails. The bundle uses
`record_deletion_failure_and_raise`, which deliberately fails after recording evidence so the
terminal task cannot turn an upstream failure into a successful job status. If the warehouse or evidence
store is unavailable, that write can fail too: retain the job failure or private summary as the
failure evidence. A terminated process can leave unfinished targets pending.

Inspect both target events and `__workflow__`; a prior `COMPLETED` row does not negate a later
workflow failure. Events are append-only history, not a mutable current-status table. A successful
repair can append new completion and verification events. Use the latest relevant attempt and plan
digest, rather than searching for any historical `VERIFIED` event.

## Private integration validation

The controls stage selects ancestors through the terminal ledger with cautious indirect test
selection. Tests referencing unselected downstream outputs wait for the full build, so a fresh
catalog does not require downstream tables or functions before their creation. The runner treats
`NoNodesForSelectionCriteria` as an error, preventing an unmatched selector from silently skipping
the intended work. It passes `*` directly as a subprocess argument; the bundle quotes the wildcard
in its shell command for the same selection behavior.

The runner uses the existing Databricks CLI OAuth session. It obtains a short-lived access token
for each dbt stage and passes it only through subprocess memory. The temporary dbt profile contains
a `DBT_ENV_SECRET_` environment-variable reference, not the token. dbt treats that value as a
secret when recording artifacts and logs. This avoids the adapter's separate browser OAuth
flow. Never print the token or persist it in `.env`.

Set the explicit workspace profile, expected host, expected caller, warehouse, and an existing
`DBT_CONTROL_CATALOG` in the ignored environment file. Use an empty schema prefix and isolated
catalog names matching `bricksgdpr_validation_[a-z0-9_]+`:

```bash
export DBT_PROJECT_CATALOG=bricksgdpr_validation_review
export DBT_EVIDENCE_CATALOG=bricksgdpr_validation_review_evidence
export DBT_SCHEMA_PREFIX=

uv run --locked python scripts/validate_integration.py
uv run --locked python scripts/validate_integration.py --apply --personas
```

The first command checks effective authentication, caller, warehouse, persona groups, and the
presence of the pepper key without reading its value. Full persona validation also needs the
account, identity, pinned-group, and warehouse-permission setup documented in
[Identity and acceptance](identity-and-acceptance.md).

The second command bootstraps catalogs, builds controls, records pending targets, builds outputs,
applies grants, runs all tests, and executes temporary-persona acceptance. Omitting `--personas`
explicitly leaves that check unrun. An isolated catalog is retained for inspection; this runner
does not delete analytical data or durable evidence on exit.

Each applied run that passes preflight writes a private directory below `target/integration/`. Stage logs and raw dbt
artifacts stay ignored locally. Only `summary.json` is intended for sharing: it allowlists node IDs,
statuses, durations, stage return codes, and whether persona validation ran. It excludes compiled
SQL, result rows, adapter responses, and error messages. Public GitHub Actions remains offline;
run this workflow from a trusted operator environment, not an untrusted pull request.

## Recovery rehearsal

```bash
uv run --locked python scripts/validate_recovery.py
uv run --locked python scripts/validate_recovery.py --apply
```

This uses the same explicit target variables but does not require demo identities or a pepper.
It creates a uniquely named synthetic schema in `DBT_CONTROL_CATALOG` and a new evidence catalog.
Checks cover archive replay, full-refresh retention with an empty source, missing-table refusal,
typed restoration, overwrite refusal,
truncated-control refusal, execution states, partial/failed verification, and invalid identifiers.
Cleanup deletes only resources carrying that rehearsal's unique marker. The sanitized result lives
under `target/recovery/`; failed cleanup is a failed rehearsal. This proves the tested mechanics,
not the complete persona or production deployment boundary.

## Recover a failed build

1. Keep the request, plan, ledger, and evidence intact. Inspect the failing stage's private logs.
2. Fix the cause, then rerun the private workflow or repair the bundle from `prepare_controls`.
   This records pending work again and rechecks retained controls before rebuilding outputs.
3. Require the output, access-control, and verification stages to succeed. Run persona acceptance
   after changes to grants, masks, identity setup, or the validation runner.
4. Retain the latest verified plan and the sanitized run summary together.

Do not remove a terminal-ledger row to make a retry succeed.

## Restore a missing control table

Stop other writers and review the archived source relation and expected schema first. The recovery
macro supports only `customer_deletion_requests`, `int_customer_deletion_plan`, and
`int_terminal_deleted_customer_keys`:

```bash
uv run dbt run-operation restore_deletion_control \
  --args '{model_name: int_terminal_deleted_customer_keys}'
```

It refuses to overwrite an existing table or restore without evidence. Rows are decoded using the
current model's declared column types, selected by the model's unique key, and restored with FULL
preferred over SPECIAL for a terminal key. A schema change needs a separately reviewed migration;
do not use restoration to invent new fields or reverse deletion decisions. Restoration does not
reapply grants, tags, or downstream data: rebuild the affected controls/descendants, apply access
controls, and complete verification before publishing outputs.

A truncated but still-existing table deliberately requires operator investigation; the macro does
not drop it automatically. Neither this workflow nor these evidence tables implement key rotation,
source purge, storage-history erasure, exports, or backup erasure.
