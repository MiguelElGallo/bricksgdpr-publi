---
icon: lucide/graduation-cap
---

# Tutorials

These tutorials are lessons. They use the repository's deterministic synthetic data so you can
perform an action, see the result, and connect that result to the next layer of the project.

## Browser lab — phase one

[Launch the browser lab](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/) to build and
inspect a focused dbt project with DuckDB. It runs locally in the browser, uses only synthetic
fixtures, and needs no Databricks workspace, credentials, or backend service.

To run the same lab from a local checkout:

```bash
cd tutorial
npm ci
npm run dev
```

The browser lab teaches portable transformation, testing, and quarantine concepts. It does not
implement or prove Unity Catalog grants, tags, masks, secrets, identities, or case-view access.
Those remain part of the canonical Databricks tutorials below. See the
[`tutorial/README.md`](https://github.com/MiguelElGallo/bricksgdpr-publi/blob/main/tutorial/README.md)
for the complete local validation workflow and runtime boundary.

## Databricks tutorials

Follow these in order the first time. Each tutorial assumes the result of the previous one.

!!! note
    The records use reserved `example.invalid` values, but the project governs them as if they
    were real Personal Data. Pseudonymized values are still Personal Data; they are not anonymous.

### Start here

1. [Build and explore the demo](build-and-explore-the-demo.md)
   establishes a working build and checks the fixture counts.
2. [Follow a customer through the layers](follow-a-customer-through-the-layers.md)
   traces one identity from readable source fields to protected analytical keys.
3. [Trace an invoice into quarantine](trace-an-invoice-into-quarantine.md)
   follows one invalid source record through the deterministic classifier.
4. [Observe terminal deletion](observe-terminal-deletion.md)
   shows why a later upsert cannot resurrect a deleted customer.
5. [Prove a protected-layer invariant](prove-a-protected-layer-invariant.md)
   runs the metadata tests that reject forbidden names and readable-data tags in protected schemas.

At the end, you will have encountered the project's main flow:

```text
synthetic seeds -> Layer1 -> priva_map -> Layer2 -> Layer3 -> controlled case views
                      \-> quarantine
```

The [`priva_map`](../reference/priva-map.md) is the separately governed mapping area that
holds readable values beside stable pseudonymous keys. The protected layers use the keys, not the
readable values.

## When you already know the project

Use the [how-to guides](../how-to-guides/index.md) when you have a real task to complete. They are
shorter, assume familiarity, and do not repeat the learning journey.

For the reasons behind the layer boundaries, read
[Architecture and trust boundaries](../explanation/architecture-and-trust-boundaries.md).
