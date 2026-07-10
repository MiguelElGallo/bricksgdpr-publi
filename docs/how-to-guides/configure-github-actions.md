---
icon: lucide/shield-check
---

# Configure GitHub Actions validation

The `CI` workflow runs deterministic seed generation, Python linting and typing, Bash syntax, and
`dbt parse`. It deliberately does not authenticate to Databricks or execute live data-plane work.

## Add the trusted-event identifiers

In the repository's **Settings > Secrets and variables > Actions**, add exactly these two
repository secrets:

| Secret | Value |
| --- | --- |
| `DATABRICKS_HOST` | Databricks workspace hostname without `https://` |
| `DATABRICKS_HTTP_PATH` | SQL warehouse HTTP path |

These values are tenancy identifiers, not authentication credentials. They are encrypted as
repository secrets to keep them out of Git and workflow logs.

!!! danger
    Do not add a Databricks token, OAuth material, client secret, service-principal credential,
    profile configuration, account/group/warehouse ID, operator or persona email, private key, or
    pseudonymization pepper to GitHub Actions.

## Understand event isolation

Every `pull_request` run—including same-repository, fork, and Dependabot pull requests—uses
reserved placeholders and never references repository secrets. Only trusted pushes to `main` and
manual maintainer runs selected on `main` inject the two encrypted identifiers. A manual run from
any other ref also uses reserved placeholders.

Do not change this workflow to `pull_request_target`. That event runs with elevated access to the
base repository and must not execute untrusted pull-request code.

## Interpret a green run correctly

`dbt parse` renders the checked-in profile but does not contact Databricks. CI therefore proves:

- deterministic checked-in seeds;
- Python linting and typing;
- Bash syntax;
- dbt project parsing with the intended configuration shape.

It does **not** prove OAuth, workspace or warehouse connectivity, live model execution, grants,
bundle deployment, identity topology, or persona access. Run those checks locally through the
ignored `.env` and CLI-managed OAuth profile.

The separate `Publication safety` workflow scans the checked-out tree and reachable Git history.
Its output contains rule names and source locations only, never matched values.
