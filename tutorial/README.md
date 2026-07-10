# bricksgdpr browser lab

This directory contains the interactive browser lessons published at
[miguelelgallo.github.io/bricksgdpr-publi/tutorial/](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/).
They run a focused dbt project against DuckDB in the browser so a learner can edit a model, execute
the build, and inspect deterministic results:

- [Customer flow](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/?lesson=customer-flow)
  traces `CUST-0001` from readable staging into a local keyed analytical output;
- [Invoice quarantine](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/?lesson=invoice-quarantine)
  proves the accepted-versus-quarantined partition for `INV-0105`.

## Runtime boundary

- React and Vite provide the tutorial interface.
- Pyodide starts Python in a Web Worker so dbt execution does not block the interface.
- The worker runs the versions pinned in `wheelhouse-lock.json`: dbt Core 1.10.8 and dbt-duckdb
  1.9.6, with DuckDB provided by Pyodide.
- The lessons use only the copied synthetic fixtures under `lesson/project/seeds`.
- Processing stays in the browser tab. There is no tutorial backend and no Databricks
  authentication.

Do not load real Personal Data into the lab. DuckDB demonstrates portable transformation, key
propagation, testing, and quarantine behavior only. The customer lesson's deterministic
`demo-v1:` keys are a teaching convention, not the canonical secret-backed Databricks `v1:`
pseudonymization implementation. The lab does not implement or prove Unity Catalog grants, tags,
column masks, secrets, identity topology, or case-view authorization.

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
