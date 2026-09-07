---
icon: lucide/wrench
---

# How-to guides

Use these guides when you know what you need to accomplish. Each page starts from a defined
situation and gives the shortest supported path to a verifiable result.

If this is your first encounter with the project, begin with the
[tutorials](../tutorials/index.md) instead.

## Develop

- [Configure a development environment](configure-a-development-environment.md)
- [Configure GitHub Actions validation](configure-github-actions.md)
- [Generate a layer-model scaffold](../reference/macro-api.md#layer-model-scaffold-api)
- [Run a focused build](run-a-focused-build.md)
- [Use an isolated development schema](use-an-isolated-development-schema.md)

## Deploy

- [Deploy the demo for the first time](deploy-the-demo-for-the-first-time.md)
- [Deploy and run the Databricks bundle](deploy-and-run-the-databricks-bundle.md)

## Secure and validate

- [Reconcile access controls](reconcile-access-controls.md)
- [Provision persona identities](provision-persona-identities.md)
- [Validate persona access](validate-persona-access.md)
- [Verify customer deletion](verify-terminal-deletion.md)

!!! note
    Commands that change Databricks resources are called out explicitly. Read the surrounding
    preconditions before running an `--apply`, `deploy`, or `--full-refresh` command.

For exact names, defaults, and selectors, use the [reference](../reference/index.md). For design
reasons and trade-offs, use the [explanation](../explanation/index.md).

See [Deletion operations and recovery](../reference/deletion-operations.md) for durable control archives, execution states,
isolated private validation, and recovery rehearsal.
