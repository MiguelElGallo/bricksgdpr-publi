---
icon: lucide/badge-check
---

# Executable security controls

A green transformation job answers one question: did dbt build the selected graph and pass the
selected tests? It does not automatically prove that live grants, masks, tags, denial paths, and
identity topology match the intended security model.

bricksgdpr turns several of those expectations into executable checks.

## CI and live-evidence boundary

Public CI is intentionally credential-free. It proves deterministic generation, linting, typing,
Bash syntax, dbt parsing, documentation, and publication-safety rules. Pull requests receive no
repository secret; trusted runs receive only encrypted host and HTTP-path identifiers for offline
parsing. Trusted here means a push to `main` or a manual run explicitly selected on `main`.

CI does not prove OAuth, connectivity, model execution, live grants, bundle deployment, identity
topology, or persona access. Those checks remain local, using the ignored `.env` plus a CLI-managed
OAuth profile. This separation prevents untrusted pull-request code from gaining a Databricks
credential while keeping the public validation reproducible.

## Data-contract checks

Generic dbt tests cover required values, uniqueness, relationships, and accepted enumerations.
Singular tests add cross-model invariants such as:

- every eligible row belongs to exactly one accepted/quarantine partition;
- mapping tuples and protected tuples agree;
- protected layers avoid known raw-column names and readable-state tags;
- Layer3 preserves Layer2 grains and relationships;
- terminally deleted keys are absent from governed outputs.

The project also has two unit tests for the service classifier: the same service is quarantined
before its customer/map exists and accepted after they exist.

## Metadata checks

Dedicated SQL tests query Unity Catalog metadata to compare:

- direct relation grants with an allowlist;
- parent `USE CATALOG` and `USE SCHEMA` privileges with an allowlist;
- consumer UDF privileges with an empty set;
- all 13 expected column masks;
- exact classification tags on the two mapping tables;
- unexpected ambient principals and privileges.

This matters because dbt can finish materializing a table even when an out-of-band privilege or
metadata change has weakened the boundary.

## Denial is part of acceptance

The persona workflow runs positive aggregate queries and prohibited queries as isolated temporary
service principals. A negative task passes only when it fails for insufficient permission with
SQLSTATE `42501`. A missing table, parse error, or compute failure is not evidence that access was
denied correctly.

## What these tests cannot prove

Executable controls are powerful only when their evidence boundary is clear:

- “no raw columns” checks use names and tags plus source review; an arbitrarily renamed or
  misclassified payload could evade the heuristic;
- metadata allowlists see direct grants available to the test caller, not every possible
  transitive entitlement;
- the trusted deployment owner remains privileged by design;
- fixture counts prove deterministic demo behavior, not production data quality;
- tests do not inspect the pepper value or secret-scope ACL;
- access tests detect extra privileges that `apply_access_controls` does not necessarily remove.

The right interpretation is **bounded evidence**, not a blanket security proof.

See [Tests and selectors](../reference/tests-and-selectors.md) for the complete inventory and
[Identity and acceptance](../reference/identity-and-acceptance.md) for the task-state matrix.
