---
title: Project layout
icon: lucide/folders
---

# Project layout

The repository is a dbt project with Databricks deployment and identity helpers.

## Top-level paths

| Path | Contents |
| --- | --- |
| `dbt_project.yml` | Project name, resource paths, variables, model defaults, grants, and tags |
| `profiles.yml` | Local Databricks OAuth target |
| `databricks.yml` | Databricks Asset Bundle definition and `dev` target |
| `resources/bricksgdpr.job.yml` | Bundle job and dbt task commands |
| `pyproject.toml` | Python version, pinned dbt packages, and development tools |
| `uv.lock` | Locked Python dependency graph |
| `.env.example` | Workspace, dbt, identity, and persona example variables |
| `.github/workflows/ci.yml` | Offline seed, lint, type, Bash, and dbt-parse validation |
| `.github/workflows/publication-safety.yml` | Redacted tree and Git-history privacy checks |
| `.github/workflows/docs.yml` | Strict documentation build and public-only Pages deployment |
| `models/` | Layer1, `priva_map`, Layer2, Layer3, and case models |
| `seeds/` | Four deterministic CSV source simulators, one deletion-confirmation control, and metadata |
| `functions/` | Three dbt-managed Databricks SQL functions |
| `macros/` | Seven local Jinja macros |
| `tests/` | Thirty-nine singular dbt data tests |
| `acceptance/personas/` | Three positive and six denial SQL file tasks |
| `scripts/generate_seeds.py` | Deterministic CSV generator |
| `scripts/provision_identities.sh` | Persona identity topology preflight and apply operation |
| `scripts/validate_personas.sh` | Temporary-service-principal persona acceptance runner |
| `docs/` | Diataxis documentation source |

## Model paths

| Path | dbt resources | Default materialization |
| --- | ---: | --- |
| `models/layer1/` | 5 typed staging models, 3 quarantine models, 2 deletion-control models | Views; quarantine/authorization models use tables and the request ledger is incremental |
| `models/priva_map/` | 2 mapping models | Table |
| `models/layer2/` | 6 ephemeral boundary/classifier models, 4 protected models, 2 deletion-control models | Table; the plan and execution ledger are incremental |
| `models/layer3/` | 3 dimensions, 2 facts | Table |
| `models/layer3_case/` | 4 controlled readable models | View |

## Metadata files

| Path | Documented resources |
| --- | --- |
| `seeds/_seeds.yml` | Five seeds and their string input types |
| `functions/_functions.yml` | Function signatures and fixed placement |
| `models/layer1/_layer1.yml` | Staging and quarantine contracts |
| `models/layer1/_deletion_control.yml` | Detection, confirmation, and authorization contracts |
| `models/priva_map/_priva_map.yml` | Mapping columns, tags, masks, and generic tests |
| `models/layer2/_layer2_customer.yml` | Protected customer model |
| `models/layer2/_layer2_events.yml` | Event boundary, classifier, and accepted model |
| `models/layer2/_layer2_services.yml` | Service boundary, classifier, accepted model, and two unit tests |
| `models/layer2/_layer2_invoices.yml` | Invoice boundary, classifier, and accepted model |
| `models/layer2/_deletion_control.yml` | Authorized relation-by-relation deletion-plan contract |
| `models/layer3/_layer3_dimensions.yml` | Customer, service, and date dimensions |
| `models/layer3/_layer3_facts.yml` | Event and invoice facts |
| `models/layer3_case/_layer3_case.yml` | Four case-view contracts |

## Generated and local-only paths

| Path | Status |
| --- | --- |
| `target/` | Generated dbt artifacts; ignored by Git |
| `logs/` | dbt logs; ignored by Git |
| `.venv/` | Local `uv` environment; ignored by Git |
| `.databricks/` | Local bundle state; ignored by Git |
| `.env` | Local environment values; ignored by Git |
| `.databrickscfg` and `.dbt/` | Local authentication/profile material; ignored by Git |

## Platform dependency

The layer names are not adapter contracts. Models and controls use Databricks/Spark features,
including SQL functions, `secret()`, Unity Catalog tags and column masks, account-group
membership predicates, `left anti join`, `count_if`, `max_by`, `explode(sequence())`, and system
information-schema relations.

**Sources:** `dbt_project.yml`, `.gitignore`, `models/`, `functions/`, `macros/`, `tests/`.
