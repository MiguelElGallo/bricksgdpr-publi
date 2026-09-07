# bricksgdpr browser lab

[Open the browser lab](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/) to build and test a
small dbt project with synthetic data. You need a modern desktop browser, an internet connection
for the first runtime download, and basic familiarity with `SELECT`, joins, and `WHERE`. You do
not need Python, a Databricks account, or a local database.

The lab runs real dbt Core and DuckDB inside the tab. SQL edits change executable models; tests
and checkpoint queries check the results. Allow time for the initial Python runtime and package
load. Subsequent builds reuse the tab's runtime.

## Start with the customer flow

[Customer flow](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/?lesson=customer-flow)
is the default lesson. Follow `CUST-0001` through five checkpoints, taking about 22 minutes:

| Checkpoint | What you learn | Expected result |
| --- | --- | --- |
| Staging | Preserve typed source changes at one row per event. | 21 changes; `CUST-0001` is a readable UPSERT. |
| Current customers | Separate detection from authorization; require a complete deletion plan. | 15 customers; pending `CUST-0095` survives and authorized `CUST-0097`/`CUST-0099` do not. |
| Teaching map | Normalize valid input and derive domain-separated, deterministic keys. | 15 rows; customer and email keys differ and readable values remain in the map. |
| Protected Layer2 | Carry an explicit allowlist of keys and business attributes. | 15 rows, exactly 13 columns, no readable identity columns. |
| Layer3 dimension | Preserve the protected row contract and one-customer-per-key grain. | 15 rows matching Layer2; the end-to-end assertion passes. |

For each checkpoint:

1. Read **Why**, **Change**, and the expected observation before running SQL. Open the focus file
   and follow its `ref()` dependencies in the supporting files.
2. Build the checkpoint. The `+` selector includes its upstream models and seeds.
   `--indirect-selection cautious` includes a dependent test only when its parents are selected;
   an early checkpoint can run on a clean database without unrelated missing-table errors.
3. Inspect the checkpoint result and expand **Query behind this result** to read its SQL.
   In the **Database** tab, select a relation and choose **Preview up to 50 rows** to inspect data.
   A green command is only one part of completion: required dbt resources must succeed and the
   result must match the semantic proof.
4. Try the optional experiment. Predict the outcome, change the named SQL, build, and read the
   test or checkpoint failure. **Restore file** restores only the active file to its lesson version
   and invalidates its affected checkpoints; other edits and the running engine remain. Rebuild
   before choosing **Next**.

The experiments deliberately break one assumption at a time: dropping a source event, deleting
without confirmation, changing a key domain, leaking a readable field, and losing dimension rows.
A test failure during an experiment is useful feedback, not a reason to weaken the assertion.

## Then trace an invoice

[Invoice quarantine](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/?lesson=invoice-quarantine)
takes about 12 minutes. `INV-0105` references missing service `SVC-7777-A`. It must appear once in
quarantine with `SERVICE_NOT_FOUND` and zero times in accepted invoices. The shared classifier
uses an ordered `CASE`: the first matching reason wins, so its order is part of the contract.

The experiment changes that reason to `ACCEPTED`. Notice that a partition can remain structurally
valid while the business classification is wrong. The checkpoint checks both the reason and
accepted-row count. Restore the classifier before completing the lesson.

Both paths also include the mode-specific deletion fixtures:

| Customer | Decision in this fixture snapshot | Current customer output | Invoice behavior |
| --- | --- | --- | --- |
| `CUST-0095` | No confirmation: `PENDING` | Retained while active | Normal classification applies. |
| `CUST-0097` | `SPECIAL_DELETION` | Removed | `INV-0097` remains, with customer and service identifiers `-99999` and `is_erased_customer = true`. |
| `CUST-0099` | Escalated to `FULL_GOVERNED_OUTPUT_DELETION` | Removed, including historical identifiers | `INV-0099` is absent from governed current invoice outputs. |

The plan has 18 rows: three historical SSNs across six teaching targets. Every target must have
the expected action for a request and SSN before it can execute. Duplicate plan rows cannot replace
a missing target; complete overlapping requests reduce to one mode per SSN, with FULL taking
precedence. The regression tests cover incomplete plans, incorrect actions, pending plans, unknown
modes, duplicate rows, and overlapping SPECIAL/FULL requests.

## What the browser can prove

| Capability | Browser lesson | Canonical Databricks project |
| --- | --- | --- |
| Transformations and tests | Executes the focused customer and invoice DAG with deterministic fixtures. | Executes the broader customer/service/invoice graph. |
| Key contract | Validates synthetic SSN and international phone syntax; demonstrates normalization, domains, null handling, and propagation. | Uses the secret-backed `v1:` pseudonymization implementation. |
| Analytical projection | Verifies exact columns, row grain, and key propagation. | Also applies Unity Catalog access controls and masks. |
| Deletion semantics | Recomputes decisions, complete plans, FULL precedence, and SPECIAL invoice reassignment from the current fixture snapshot. | Maintains guarded incremental control state, retained evidence, execution status, and recovery checks. |
| Identity and authorization | Reads synthetic decision fields as data. All browser data is accessible to the learner. | Uses configured identities, groups, grants, secrets, and live persona validation. |
| Physical erasure | No proof of purge, retained-version removal, exports, or backup erasure. | Governed current-output deletion is also distinct from physical-erasure verification. |

**Use synthetic data only.** The public `demo-v1:` teaching constant is embedded in the downloaded
code. These hashes provide no confidentiality or anonymization, and the lab's “protected” name
means a tested column projection. The browser does not enforce a private mapping boundary.

The deletion registry is rebuilt and terminal modes are ephemeral. Removing a source tombstone
or changing a confirmation can change a later browser build; the lab does **not** demonstrate
persistent suppression, immutable decision history, anti-resurrection recovery, or evidence-ledger
protection. Production also supports a decision-time cutoff; this compact project uses the latest
fixture revision and fixed `CUSTOMER_DELETION_V1`. No key rotation is performed.

The invoice lesson intentionally retains readable synthetic identifiers to make classification
inspectable. It is not the production fact-key layout; production applies its reusable policy
macro to every modeled fact key.

## Runtime and troubleshooting

- React and Vite provide the interface. Pyodide runs Python in a Web Worker, so dbt execution stays
  outside the interface thread.
- Versions are pinned in `wheelhouse-lock.json`: dbt Core 1.10.8, dbt-duckdb 1.9.6, and Pyodide
  0.27.7. That Pyodide release supplies DuckDB 1.1.2; native compatibility checks pin the same
  DuckDB version. Python wheels are hash-verified before publication.
- The project uses only copied synthetic fixtures under `lesson/project/seeds`. There is no
  tutorial backend or Databricks authentication; queries execute in the browser tab.
- Explorer previews show up to 50 rows. The worker caps each returned query result at 1,000 rows
  and marks truncated results; neither limit changes the underlying table or a dbt test.
- Treat the tab as a disposable workspace. Reloading restarts the in-memory database and lesson
  state. Copy SQL you want to keep before closing or reloading.
- If runtime loading fails, read the terminal error and check network access to the runtime
  assets. **Boot engine** retries startup. After a fatal worker error, retry preserves SQL edits
  but starts a fresh database and clears earlier proofs, so rebuild your checkpoints. Browser
  storage/privacy restrictions or blocked downloads can prevent boot. **Reset lab** also discards
  edits and restarts lesson state; use it when you want a completely fresh session.
- If a build fails after an edit, read the first failing resource, restore that model, and rebuild
  the focused checkpoint. Do not replace a failing assertion with an always-passing query.

For production operation, continue with the repository's
[deletion control reference](../docs/reference/deletion-control.md),
[deletion operations runbook](../docs/reference/deletion-operations.md), and
[macro API](../docs/reference/macro-api.md).

## Run locally

Prerequisites are Node.js 24 or newer and `npm`. The first run downloads the pinned Python wheels
and Pyodide runtime, so it also needs network access.

```bash
cd tutorial
npm ci
npm run dev
```

Open the local URL printed by Vite. `npm run dev` prepares the hash-verified wheelhouse before
starting the server.

## Validate the browser lessons

Install `uv` as well for the native dbt compatibility check, then run:

```bash
npm test
npm run typecheck
npm run build
npm run test:dbt
```

The checks cover the interface and command parser, TypeScript compilation, the production bundle,
fixture synchronization, the pinned browser wheelhouse, a full `dbt build`, each lesson's exact
focused command on its own clean DuckDB database, and expected failures for malformed key input.
`npm run test:dbt` removes every temporary database after the run. Native dbt checks complement browser testing; they do not prove runtime
asset loading or browser-specific behavior.

## Publication

The documentation workflow builds this directory and copies `dist/` into `site/tutorial/` before
uploading the single GitHub Pages artifact. Pull requests and manual runs from non-`main` refs can
build the artifact for validation but cannot deploy it.
