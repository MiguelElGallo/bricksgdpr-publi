---
icon: lucide/trash-2
---

# Terminal deletion versus physical erasure

The demo implements **logical current-state deletion** across the governed dbt outputs. It does
not, by itself, physically erase every copy of a person's data.

## What “terminal” means here

A customer change row with `source_operation = 'DELETE'` is a tombstone. Once a stable customer ID
has any such row, later upserts do not resurrect it.

The deletion control expands that customer ID to every historical SSN recorded for it, derives all
corresponding customer keys, and removes those keys from:

- both `priva_map` tables;
- durable Layer2 relations;
- Layer1 quarantine tables;
- Layer3 dimensions and facts;
- controlled case views.

Dependent extracts that still carry an older SSN are removed because the control expands through
the stable customer ID first.

## What remains on purpose

The synthetic CSV seeds retain the upsert and tombstone fixtures so the demo is reproducible.
Ordinary Layer1 staging views therefore also retain those source-shaped rows. The absence claim
starts at the mapping boundary and includes protected, quarantine, analytical, and case outputs—not
the source simulator or its staging views.

## Why a successful query is not physical erasure

The models use replacement materializations. After a successful rebuild, current tables and views
no longer return the deleted subject. Storage systems can still retain other copies:

- Delta table history and deletion vectors;
- cloud-object versions;
- SQL and application caches;
- exports and downstream products;
- source-system history;
- backups and disaster-recovery copies.

These systems have their own retention, legal-hold, recovery, and audit requirements. dbt cannot
prove or coordinate them merely by returning zero current rows.

## The production sequence is a design obligation

A production erasure workflow normally has to fence replay, resolve every identity version,
delete dependents before the final map, purge or age out source and storage history, cover exports
and backups, and record evidence. The exact operations are environment-specific and are not
implemented in this repository.

For that reason, the documentation provides a how-to for
[verifying the demo's terminal deletion](../how-to-guides/verify-terminal-deletion.md), but not a
pretend universal procedure for physical erasure.

!!! warning "Use an owner session for the dbt deletion tests"
    The compiled deletion tests expand an ephemeral model that reads Layer1 and invokes the
    protected pseudonymization wrapper. Ordinary persona sessions are intentionally denied those
    privileges. A case-view check must be performed separately through an authorized aggregate
    query or by a trusted owner session that can execute the dbt test.
