# bricksgdpr browser lab

This directory contains the interactive browser lessons published at
[miguelelgallo.github.io/bricksgdpr-publi/tutorial/](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/).
They run a focused dbt project against DuckDB in the browser so a learner can edit a model, execute
the build, and inspect deterministic results:

- [Customer flow](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/?lesson=customer-flow)
  builds `CUST-0001` through staging, the current-customer view, the teaching map, protected Layer2,
  and the Layer3 dimension;
- [Invoice quarantine](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/?lesson=invoice-quarantine)
  proves the accepted-versus-quarantined partition for `INV-0105`.

The customer flow is cumulative. Each checkpoint explains why the next model is needed, identifies
what it builds on, highlights the main change and any supporting code in executable SQL comments,
runs a focused dbt command, and shows the exact result to inspect. A completed checkpoint remains in
view until the learner chooses **Next**:

1. inspect the readable `stg_customer` change for `CUST-0001`;
2. detect deletion requests, require a valid decision, then reduce 21 changes to 15 current
   customers: unconfirmed `CUST-0095` remains while SPECIAL `CUST-0097` and FULL `CUST-0099` leave
   customer outputs;
3. create distinct, domain-separated keys in `demo_customer_map`;
4. leave readable mapping values behind in protected `int_customer_protected`;
5. preserve the protected key and customer grain in `dim_customer` and run the final fixture proof.

## Runtime boundary

- React and Vite provide the tutorial interface.
- Pyodide starts Python in a Web Worker so dbt execution does not block the interface.
- The worker runs the versions pinned in `wheelhouse-lock.json`: dbt Core 1.10.8 and dbt-duckdb
  1.9.6, with DuckDB provided by Pyodide.
- The lessons use only the copied synthetic fixtures under `lesson/project/seeds`. The deletion
  policy version is intentionally fixed to `CUSTOMER_DELETION_V1` in this compact teaching project;
  the canonical Databricks project also supports a staged decision-time cutoff for replay tests.
- Processing stays in the browser tab. There is no tutorial backend and no Databricks
  authentication.

Do not load real Personal Data into the lab. DuckDB demonstrates portable transformation, key
propagation, testing, and quarantine behavior only. The customer lesson's deterministic
`demo-v1:` keys are a teaching convention, not the canonical secret-backed Databricks `v1:`
pseudonymization implementation. The lab does not implement or prove Unity Catalog grants, tags,
column masks, secrets, identity topology, or case-view authorization.

The invoice models do demonstrate the canonical mode distinction with string keys: SPECIAL keeps
`INV-0097` under customer and service member `-99999` with `is_erased_customer = true`; FULL removes
`INV-0099` from governed current invoice outputs. Production uses the reusable parameterized macro
documented in the main deletion reference and applies the erased member to every modeled fact key.

## Run locally

Prerequisites are Node.js 24 or newer and `npm`. The first run can download the pinned Python
wheels and Pyodide runtime, so it also needs network access.

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
fixture synchronization, the pinned browser wheelhouse, a full `dbt build`, and each lesson's exact
focused command on its own clean DuckDB database. `npm run test:dbt` removes every temporary
database after the run.

## Publication

The documentation workflow builds this directory and copies `dist/` into `site/tutorial/` before
uploading the single GitHub Pages artifact. Pull requests and manual runs from non-`main` refs can
build the artifact for validation but cannot deploy it.
