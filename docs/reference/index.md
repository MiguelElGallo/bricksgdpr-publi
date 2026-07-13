---
title: Reference
icon: lucide/book-open
---

# Reference

This section records the exact dbt resources, configuration names, relation grains, command
signatures, and security contracts in `bricksgdpr`.

Use [Tutorials](../tutorials/index.md) for guided lessons, [How-to guides](../how-to-guides/index.md)
for task-oriented instructions, and [Explanation](../explanation/index.md) for design context.

## Project inventory

| Resource type | Count | Notes |
| --- | ---: | --- |
| Models | 34 | 9 views, 16 tables, 3 incremental models, and 6 ephemeral models |
| Seeds | 5 | Four source extracts and one independent deletion-confirmation control |
| SQL functions | 3 | Created in the fixed `priva_internal` schema |
| Model-generation macro API | 11 | Seven layer scaffolding operations plus four deletion generators |
| Data tests | 336 | 293 generic tests and 43 singular tests |
| Unit tests | 7 | Authorization, mode policy, service resolution, and invoice quality |
| Sources | 0 | Seeds are referenced directly with `ref()` |
| Snapshots | 0 | Current-state outputs use replacement; deletion request, plan, and execution ledgers are incremental |
| Exposures, metrics, semantic models | 0 | No semantic-layer resources are defined |
| Named selectors | 0 | Selection uses resource names, graph operators, and tags |

Counts describe the checked-in project manifest. Fixture result counts apply only to the
checked-in synthetic seeds.

## Pages

| Page | Lookup subject |
| --- | --- |
| [Project layout](project-layout.md) | Repository paths and dbt resource locations |
| [Configuration](configuration.md) | Environment variables, dbt variables, and fixed names |
| [Commands](commands.md) | Local, dbt, identity, acceptance, and bundle commands |
| [Catalogs and schemas](catalogs-and-schemas.md) | Catalog placement, schema names, and default readers |
| [Sources and Layer1](sources-and-layer1.md) | Seeds, typed staging views, and raw quarantine tables |
| [Customer deletion control](deletion-control.md) | Detection, confirmation, authorization, target plan, and execution gate |
| [`priva_map`](priva-map.md) | Raw-to-pseudonymous mapping relations, tags, and masks |
| [Layer2](layer2.md) | Key boundaries, classifiers, accepted tables, and reason codes |
| [Layer3 and case views](layer3-and-case.md) | Dimensions, facts, and controlled readable views |
| [Macro API reference](macro-api.md) | Complete developer-facing model-generation macro contract |
| [Model generation log](model-generation-log.md) | Exact per-model generation commands, artifact hashes, and diff counts |
| [Tests and selectors](tests-and-selectors.md) | Test counts, enforced invariants, tags, and selection forms |
| [Access control](access-control.md) | Persona matrix, grants, masks, and trusted boundaries |
| [Identity and acceptance](identity-and-acceptance.md) | Identity modes, required variables, and task-state contract |
| [Bundle job](bundle-job.md) | Databricks Asset Bundle target and job definition |
| [Glossary](glossary.md) | Project-specific terms and abbreviations |

## Scope

`bricksgdpr` is a Databricks demonstration of pseudonymization, controlled resolution, access
metadata, quarantine, and current-state identity unlinking. It is not a GDPR compliance
certification or legal-advice system. Production controls outside this repository include lawful
basis, consent, retention enforcement, audit operations, incident response, subject-request
orchestration, backup erasure, and case approval.

The Layer1, Layer2, and Layer3 names describe the project's conceptual organization. The SQL
implementation is Databricks- and Spark-specific.

## Source-path notation

Each page lists repository-relative source paths as code, for example
`models/layer2/int_invoice_resolution.sql`. These paths identify implementation evidence; they are
not documentation-site routes.
