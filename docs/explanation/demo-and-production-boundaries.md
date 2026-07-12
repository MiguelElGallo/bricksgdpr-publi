---
icon: lucide/factory
---

# Demo and production boundaries

bricksgdpr is deliberately small enough to inspect end to end. That makes the control mechanics
clear, but several conveniences are unsuitable as production claims.

## What the demo is good at showing

- A readable-to-pseudonymous mapping can be isolated from ordinary analytics.
- Stable, domain-separated keys can preserve joins across layers.
- Late and invalid records can be quarantined instead of disappearing.
- Current governed outputs can choose SPECIAL erased-member fact retention or FULL fact deletion.
- Unity Catalog masks, grants, tags, and UDF privileges can be tested as metadata.
- Positive and negative persona behavior can be exercised without retaining credentials.

## Synthetic inputs are control fixtures

The four source CSV seeds contain deterministic edge cases and between 21 and 39 rows; a fifth
four-row seed represents immutable independent decision revisions. Exact counts such as 15 protected
customers or 27 accepted invoices make regression tests easy to understand. They are not
production capacities, error budgets, or expected distributions.

The source simulator keeps raw values and deletion fixtures in Git. Real Personal Data must not be
committed as a seed.

## Full replacement simplifies current state

Tables are replaced on rebuild, so a corrected late arrival can leave quarantine and an authorized
subject's facts can be reassigned or removed according to mode. Production ingestion usually needs
incremental replay controls, idempotent event handling, stateful tombstone propagation, retention,
and recovery procedures.

## The deployment target assumes one trusted operator

The checked-in `dev` bundle target writes the canonical demo catalog. It deploys one unscheduled,
UI-locked job beneath the deployer's private bundle path and runs as the deployer. A shared
production deployment needs an explicit service principal, centrally owned job or isolated
catalogs, separation of duties, and monitored scheduling.

## Configuration has intentional sharp edges

dbt can prefix the data schemas and target another catalog, while functions remain in the fixed
`priva_internal` schema. However, the persona SQL files currently hardcode the canonical
`bricksgdpr` catalog and unprefixed schemas. Automated persona acceptance therefore supports only
that canonical layout unless the SQL and runner are parameterized.

The `as_of_date` is also a fixed demo clock, and the date dimension has configured 2025–2028
bounds. Production logic needs an explicit policy for business time and calendar extension.

## Important assumptions to revisit

- A nondeleted customer is assumed not to change SSN without an identity-history strategy.
- Event and invoice IDs are assumed not to be independently identifying.
- The erased-member key is not itself evidence that retained fact attributes are anonymous.
- `dim_service` is Type-2-style by service ID and `valid_from`; it is not a complete SCD Type 2
  engine with overlap, gap, and current-row management.
- Case access is group-wide, not restricted to an approved subject or case.
- Secret immutability and the secret-scope ACL are operator controls outside the repo tests.

## Controls outside this repository

A production GDPR program also needs organizational and cross-system controls for lawful basis,
purpose limitation, data-subject requests, retention, audit and monitoring, incident response,
data residency, processors, exports, caches, backups, and recovery copies.

!!! note
    The production value of the project is its explicit boundaries and executable examples—not a
    claim that copying the repository completes a compliance program.

Use [Configuration](../reference/configuration.md) for the exact supported defaults and
[Bundle job](../reference/bundle-job.md) for the deployment contract.
