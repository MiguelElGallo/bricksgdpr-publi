# Synthetic operations rehearsal

Run `uv run --locked python scripts/validate_recovery.py --apply` from the repository root after
setting the explicit integration target variables. The runner copies these fixtures into ignored
`target/recovery/`, loads the repository macros and request durability configuration, and uses the
existing CLI OAuth session in process memory.

It creates a unique synthetic schema and evidence catalog, tests archive replay, full-refresh
retention with an empty upstream source, missing/truncated control guards, typed restoration,
overwrite refusal, target/failure states, partial/failed verification, and rejected identifiers.
Cleanup is restricted to resources marked with that execution's unique ID. No demo persona group,
pepper, or original customer data is used. See [operations and recovery](../../docs/reference/deletion-operations.md).
