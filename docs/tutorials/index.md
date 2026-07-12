---
icon: lucide/graduation-cap
---

# Tutorials

These tutorials are lessons. They use the repository's deterministic synthetic data so you can
perform an action, see the result, and connect that result to the next layer of the project.

## Browser lessons

[Open the browser lab](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/) to build and
inspect a focused dbt project with DuckDB. It runs locally in the browser, uses only synthetic
fixtures, and needs no Databricks workspace, credentials, or backend service. Choose:

- [Follow a customer through the teaching flow](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/?lesson=customer-flow)
  to build one customer through five cumulative checkpoints: staging, current state, mapping,
  protected Layer2, and Layer3;
- [Trace an invoice into quarantine](https://miguelelgallo.github.io/bricksgdpr-publi/tutorial/?lesson=invoice-quarantine)
  to inspect one deterministic rejection and its accepted-versus-quarantine partition.

The customer lesson introduces one focused modeling checkpoint at a time. Commented executable SQL
identifies the main change and any supporting code, while the guide explains what it builds on,
runs a focused dbt command, and keeps the exact result visible until the learner chooses the next
step.

To run the same lab from a local checkout:

```bash
cd tutorial
npm ci
npm run dev
```

The DuckDB lessons validate portable model behavior and deterministic fixture outcomes only. The
customer lesson uses deterministic `demo-v1:` teaching keys, not the canonical secret-backed
Databricks `v1:` implementation. The lessons do not implement or prove Unity Catalog grants, tags,
masks, secrets, identities, or case-view access. Those controls remain part of the canonical
Databricks tutorials below. See the
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
4. [Customer deletion: before and after](observe-terminal-deletion.md)
   builds both control states, shows every Layer3 table, and proves that only an independently
   confirmed complete plan removes the customer.
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
