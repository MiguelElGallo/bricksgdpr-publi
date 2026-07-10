# bricksgdpr browser lab

This directory contains the phase-one interactive tutorial published at
[miguelelgallo.github.io/bricksgdpr-publi/tutorial/](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/).
It runs a focused dbt project against DuckDB in the browser so a learner can edit a model, execute
the build, inspect results, and observe the accepted-versus-quarantined invoice partition.

## Runtime boundary

- React and Vite provide the tutorial interface.
- Pyodide starts Python in a Web Worker so dbt execution does not block the interface.
- The worker runs the versions pinned in `wheelhouse-lock.json`: dbt Core 1.10.8 and dbt-duckdb
  1.9.6, with DuckDB provided by Pyodide.
- The lesson uses only the copied synthetic fixtures under `lesson/project/seeds`.
- Processing stays in the browser tab. There is no tutorial backend and no Databricks
  authentication.

Do not load real Personal Data into the lab. DuckDB demonstrates the portable transformation,
testing, and quarantine behavior only. It does not implement or prove Unity Catalog grants, tags,
column masks, secrets, identity topology, or case-view authorization from the canonical
Databricks project.

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

## Validate phase one

Install `uv` as well for the native dbt compatibility check, then run:

```bash
npm test
npm run typecheck
npm run build
npm run test:dbt
```

The checks cover the interface and command parser, TypeScript compilation, the production bundle,
fixture synchronization, the pinned browser wheelhouse, and a real `dbt build` of the focused
DuckDB project. `npm run test:dbt` uses a temporary database and removes it after the run.

## Publication

The documentation workflow builds this directory and copies `dist/` into `site/tutorial/` before
uploading the single GitHub Pages artifact. Pull requests and manual runs from non-`main` refs can
build the artifact for validation but cannot deploy it.
