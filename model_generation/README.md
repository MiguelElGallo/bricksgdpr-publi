# Model regeneration harness

This directory records the reproducible, model-by-model exercise of the public layer-generation
macros against every checked-in dbt SQL model.

The inventory is the first control. `model_inventory.yml` must contain exactly one entry for every
model resolved by `target/manifest.json`. Later regeneration steps create:

- one normalized specification per model;
- the exact `dbt run-operation` command used for that model;
- generated model SQL and schema YAML;
- structural and semantic diff evidence;
- an isolated regenerated project used for live Databricks regression testing.

Generated build artifacts belong under `target/model_generation/` and remain ignored. The durable
command/evidence ledger is written to `docs/reference/model-generation-log.md` after validation.
