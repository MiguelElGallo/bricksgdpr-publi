# bricksgdpr

A dbt-first Databricks demonstration of GDPR Personal Data controls. Four synthetic source
extracts flow through conceptual Layer1, Layer2, and Layer3 boundaries that can be adapted to
other data platforms. The executable implementation is Databricks-specific: it depends on Unity
Catalog grants, tags and column masks, Databricks SQL functions and secrets, and a Databricks
Asset Bundle. Raw-to-pseudonymous mapping is isolated in `priva_map`; protected analytics contain
only stable, versioned keys; controlled case views resolve a deliberately narrow set of readable
fields.

The repository uses **Personal Data** in the GDPR sense. Pseudonymized values remain Personal
Data and are not described as anonymous.

This is an engineering demonstration, not legal advice or a GDPR compliance certification.

## Documentation

Start at the [documentation index](docs/index.md) or browse its four sections:

- [Tutorials](docs/tutorials/index.md) for guided, hands-on learning;
- [How-to guides](docs/how-to-guides/index.md) for specific operational tasks;
- [Reference](docs/reference/index.md) for exact commands, resources, and contracts;
- [Explanation](docs/explanation/index.md) for architecture and design reasoning.

The canonical design pages include:

- [Architecture and trust boundaries](docs/explanation/architecture-and-trust-boundaries.md);
- [Access control](docs/reference/access-control.md);
- [Macro API reference](docs/reference/macro-api.md);
- [Terminal deletion versus physical erasure](docs/explanation/terminal-deletion-vs-erasure.md).

Preview the complete site locally:

```bash
uv sync --locked --only-group docs
uv run --locked --only-group docs zensical serve
```

### Browser tutorials

[Open the browser lab](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/) to run real dbt
Core against DuckDB entirely in your browser. Choose:

- [Follow a customer through the teaching flow](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/?lesson=customer-flow)
  to build synthetic `CUST-0001` cumulatively through staging, current state, mapping, protected
  Layer2, and Layer3, with commented SQL and an exact result at each checkpoint;
- [Trace an invoice into quarantine](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/?lesson=invoice-quarantine)
  to prove that `INV-0105` is classified as `SERVICE_NOT_FOUND` and excluded from accepted output.

The browser lessons use only synthetic fixtures and require no Databricks workspace, credentials,
or backend service. The customer lesson's deterministic `demo-v1:` keys are a local teaching
convention, not the canonical Databricks `v1:` pseudonymization implementation. The lessons
demonstrate portable transformation, key propagation, testing, and quarantine behavior; they do
not implement or prove Unity Catalog grants, tags, masks, secrets, identity isolation, or case-view
authorization.

Run the lab locally with Node.js 24 or newer:

```bash
cd tutorial
npm ci
npm run dev
```

See [`tutorial/README.md`](tutorial/README.md) for the browser runtime boundary and the complete
validation commands.

## What is built

| Area | Relations |
| --- | --- |
| Layer1 source | four deterministic source seeds plus one deletion-confirmation control |
| Layer1 | five typed staging views, three raw quarantine tables, and request/authorization controls |
| `priva_map` | customer and service-address mapping tables with 13 exact column masks |
| Layer2 | protected customer, event, service, and invoice tables |
| Layer3 | customer/service/date dimensions and event/invoice facts |
| Layer3 case | four fail-closed standard views with hashes plus selected readable values |
| Internal | three Databricks SQL UDFs for hashing, versioned pseudonymization, and masking |

Current control fixtures produce:

- 15 protected customers, including one detected-but-unconfirmed fixture that remains linked;
- 30 accepted events, including one SPECIAL fact under `-99999`, plus one quarantined and one FULL-deleted event;
- 17 accepted service periods, three quarantined periods, and two deletion-controlled periods;
- 27 accepted invoices, including one SPECIAL fact, plus 11 quarantined and one FULL-deleted invoice;
- no original customer/service keys for authorized deletions in governed outputs or case views.

This is executable SPECIAL/FULL governed-output handling driven by a persisted request, independent
versioned confirmation, and an exact 17-target action plan. The synthetic seeds, source-shaped staging views, and
restricted control evidence intentionally retain reproducible fixtures; they are outside that
current-output deletion claim. Production physical erasure still
requires source purge, Delta retention, cache/export, and backup controls described in
[Terminal deletion versus physical erasure](docs/explanation/terminal-deletion-vs-erasure.md).
The exact state machine is in
[Customer deletion control](docs/reference/deletion-control.md).

## Prerequisites

- Databricks CLI 1.7.0 or newer;
- `uv`;
- `jq` for identity provisioning and validation;
- OpenSSL for first-time pepper generation;
- `uuidgen` for temporary-persona validation;
- access to a Databricks workspace;
- permission to create and govern the Unity Catalog catalog, schemas, relations, tags, masks, and
  SQL UDFs; manage the Databricks secret scope; manage account identities and workspace
  assignments; grant warehouse access; and use temporary service principals as Job Run-as
  identities.

The checked-in `profiles.yml` uses Databricks OAuth. Configuration has three separate trust
boundaries:

- `.env.example` contains only blank or reserved public examples;
- the ignored local `.env` may contain real tenancy/account identifiers and operator email, but
  never credentials or the pseudonymization pepper;
- GitHub Actions stores only `DATABRICKS_HOST` and `DATABRICKS_HTTP_PATH` as encrypted repository
  secrets for trusted offline parsing.

OAuth sessions stay outside the repository. The private integration runner uses the existing CLI
session; direct dbt OAuth can require its own browser login. Live connectivity,
deployment, identity, grant, and persona checks run locally, not in public CI. See
[Configure GitHub Actions validation](docs/how-to-guides/configure-github-actions.md).

## First deployment

```bash
cp .env.example .env
git check-ignore -q .env
chmod 600 .env
# Fill every blank workspace/account value in .env before continuing.
set -a
source .env
set +a

databricks auth login \
  --host "$DATABRICKS_EXPECTED_HOST" \
  --profile "$DATABRICKS_CONFIG_PROFILE"

uv sync --locked
uv run dbt run-operation bootstrap_project_catalog
```

Create `bricksgdpr/pepper_v1` once. Never overwrite it in place: rotation creates a new secret,
wrapper, and parallel key columns.

```bash
databricks secrets create-scope bricksgdpr --profile "$DATABRICKS_CONFIG_PROFILE"
databricks secrets list-secrets bricksgdpr \
  --profile "$DATABRICKS_CONFIG_PROFILE" \
  --output json
```

Continue only when the listing does **not** contain `pepper_v1`, then create it:

```bash
openssl rand -base64 48 \
  | databricks secrets put-secret bricksgdpr pepper_v1 \
      --profile "$DATABRICKS_CONFIG_PROFILE"
```

The repository pins the scope/key name but cannot prevent an operator from overwriting the value
or prove the secret-scope ACL. Treat immutability and the deployment-identity-only ACL as external
operator controls.

Create or reconcile the three deterministic synthetic users, account groups, workspace
assignments, memberships, and warehouse permissions:

```bash
export DATABRICKS_IDENTITY_MODE='synthetic'
export PRIVACY_ADMIN_EMAIL='bricksgdpr.privacy.admin@example.invalid'
export RESTRICTED_USER_EMAIL='bricksgdpr.restricted.user@example.invalid'
export CASE_USER_EMAIL='bricksgdpr.case.user@example.invalid'
export DATABRICKS_EXPECTED_CALLER='authenticated.admin@your-company.example'
scripts/provision_identities.sh
scripts/provision_identities.sh --apply
```

Synthetic mode accepts only those repository-owned reserved addresses. The script defaults to a
read-only preflight; only explicit `--apply` can create or assign identities. It refuses missing,
malformed, duplicate, inactive, wrongly marked synthetic, or directly cross-persona inputs. Human
mode rejects the reserved demo domain, but the operator must attest that its three addresses are
deliverable or IdP-backed; only a successful separately authenticated session proves that claim.

The synthetic users prove persistent identity topology but cannot complete email verification.
The group-driven data plane is validated without user passwords by running the aggregate-only SQL
files in [`acceptance/personas`](acceptance/personas/README.md) as isolated temporary service
principals, one per persona group. No temporary principal or credential remains after validation.

Build relations first, apply parent privileges and function revocations, then run the complete
acceptance suite:

```bash
uv run dbt build --select '*' --exclude tag:access_control
uv run dbt run-operation apply_access_controls
uv run dbt test --select tag:access_control
uv run dbt build --select '*'
```

The persona suite then proves readable, masked, and denied behavior. Its positive task must
succeed; every negative task must fail specifically with SQLSTATE `42501`.

Run the reproducible temporary-principal acceptance workflow only after reviewing its plan and
confirming the explicit target variables:

```bash
scripts/validate_personas.sh --apply
```

The persona runner renders the checked-in SQL for the reviewed `DBT_PROJECT_CATALOG`.
Catalog names must match `[a-z][a-z0-9_]*`; `DBT_SCHEMA_PREFIX` must be empty.

The runner creates no credential. It uploads aggregate-only SQL files, creates one short-lived
service principal per persona, validates the exact task-state matrix, deactivates and deletes the
principals, removes its workspace files, and reruns the identity preflight.

## Bundle deployment

The default `dev` target deploys one UI-locked Databricks job beneath the deployer's private
bundle workspace path. The job has no schedule: it runs only when explicitly started. Serverless
Jobs compute runs the pinned dbt CLI environment, while the configured SQL warehouse executes the
generated SQL. Bundle targets `dev`, `validation`, and `prod` use separate analytical and evidence
catalogs. The latter two require an explicit pre-provisioned service-principal Run As identity.
Use a distinct catalog pair for each concurrent deployer; see [Bundle job](docs/reference/bundle-job.md).

Validate and inspect every planned workspace change before deployment, then deploy and run the
workflow with the authenticated CLI profile named in `.env`:

```bash
databricks bundle validate --strict --profile "$DATABRICKS_CONFIG_PROFILE"
databricks bundle plan --profile "$DATABRICKS_CONFIG_PROFILE"
databricks bundle deploy --profile "$DATABRICKS_CONFIG_PROFILE"
databricks bundle summary --profile "$DATABRICKS_CONFIG_PROFILE"
databricks bundle run bricksgdpr_dbt_workflow \
  --profile "$DATABRICKS_CONFIG_PROFILE"
```

The bundle pins the same dbt package versions used locally. Its required `warehouse_id` setting,
loaded from `BUNDLE_VAR_warehouse_id` in the reviewed `.env`, makes Databricks generate a
run-scoped dbt connection for the job's Run As principal. The local OAuth `profiles.yml` is
intentionally excluded from bundle synchronization. Override the reviewed warehouse for one
command only when targeting another compatible serverless or pro warehouse:

```bash
databricks bundle validate --strict --profile "$DATABRICKS_CONFIG_PROFILE" \
  --var="warehouse_id=<warehouse-id>"
```

The routine job prepares controls, records pending targets, builds governed outputs, applies access
controls, and verifies all tests in separate tasks. A failure task records failed execution evidence. Account-level identity provisioning
and temporary-persona acceptance remain separate, explicitly invoked controls.

## Durable deletion operations

Requests, plans, and terminal controls resist full refresh. Post-hooks archive their evidence and
privacy decisions to a separate append-only catalog. A tracked run distinguishes pending targets,
completed builds, failures, and verified outcomes.

Use the [operations and recovery guide](docs/reference/deletion-operations.md) for isolated private
validation, sanitized per-stage reports, synthetic recovery rehearsals, and missing-table recovery.
Key rotation and physical-erasure tracking remain outside this implementation.

## Development loop

Generate complete reviewed Layer1, `priva_map`, Layer2, Layer3, or case-view scaffolds through the
[Macro API](docs/reference/macro-api.md#layer-model-scaffold-api). The operations print source code
and schema YAML; they do not write files or mutate the warehouse.

Generate the exact synthetic fixtures and validate local code:

```bash
uv run python scripts/generate_seeds.py
uv run ruff check .
uv run ty check scripts
uv run --locked dbt parse --profiles-dir .
scripts/check_publication_safety.sh --tree
scripts/check_publication_safety.sh --history
```

The publication checks reject concrete Databricks tenancy identifiers, non-reserved email
addresses, personal home paths, common token formats, and private keys. Findings contain only the
rule and source location, never the matched value. Ignored files are outside the tree scan; keeping
`.env` ignored is therefore the first boundary. If `.env` is ever force-added, it becomes tracked
and the scan rejects its real identifiers.

GitHub Actions mirrors the offline seed, lint, type, Bash, and parse checks. Every pull request uses
reserved placeholders and receives no repository secret; only trusted `main` pushes and manual
runs selected on `main` use the two encrypted connection identifiers. A manual run from another
ref uses placeholders. A green CI run does not prove authentication, workspace connectivity,
deployment, grants, or persona behavior.

Useful focused builds:

```bash
uv run dbt build --select +tag:layer1
uv run dbt build --select +tag:priva_map
uv run dbt build --select "+tag:layer2 +tag:quarantine"
uv run dbt build --select +tag:layer3
uv run dbt build --select +tag:case_views
```

Preview a selector with `dbt ls --select ...` before executing it. The leading `+` includes the
upstream UDFs, maps, and staging relations needed for a self-consistent focused result.

`DBT_SCHEMA_PREFIX` prefixes data schemas for isolated development. Security functions remain in
the stable `priva_internal` schema so column-mask references cannot drift.

## Security invariants

- The `v1` wrapper pins the hash version and the `bricksgdpr/pepper_v1` reference; the operator
  must keep the referenced secret value immutable and its ACL restricted.
- The digest is purpose-, version-, domain-, and value-separated with length framing.
- Consumer groups have no `EXECUTE` privilege on any internal UDF.
- Exact `priva_map` table/column tags and all 13 masks are executable metadata tests.
- Restricted users can query `priva_map` only through masks and can read protected Layer2/Layer3.
- Case users cannot query `priva_map`; they receive selected readable fields only through approved
  Layer3 case views.
- Privacy administrators can read governed raw areas but still receive no pseudonymization-oracle
  execution privilege.
- Accepted/quarantine partitions and deletion absence in mapping, Layer2, Layer3, and quarantine
  are executable dbt assertions; authorized case-view deletion also requires the separate
  aggregate persona check documented in the how-to guide.
