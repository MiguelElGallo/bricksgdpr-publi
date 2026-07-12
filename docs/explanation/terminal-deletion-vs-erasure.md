---
icon: lucide/trash-2
---

# Terminal deletion versus physical erasure

The demo implements **logical current-state deletion** across the governed dbt outputs. It does
not, by itself, physically erase every copy of a person's data.

## What “terminal” means here

A customer change row with `source_operation = 'DELETE'` is first stored as a detected request. It
does not delete anything by itself. A separate privacy decision must be `CONFIRMED`, and no legal
hold may apply, before the request becomes `AUTHORIZED`.

Only then does the deletion plan expand the stable customer ID to every historical SSN, derive all
corresponding customer keys, and authorize those keys for removal from:

- both `priva_map` tables;
- durable Layer2 relations;
- Layer1 quarantine tables;
- Layer3 dimensions and facts;
- controlled case views.

Dependent extracts that still carry an older SSN are removed because the plan expands through the
stable customer ID first. A later upsert cannot resurrect an authorized key. A pending, rejected,
or held request creates no plan and cannot enter the execution gate.

The exact models, states, and 17 planned targets are listed in
[Customer deletion control](../reference/deletion-control.md).

## What remains on purpose

The synthetic CSV seeds retain the upsert, tombstone, and confirmation fixtures so the demo is
reproducible. Ordinary Layer1 staging views retain source-shaped rows, and restricted deletion
control tables retain minimum case evidence. The absence claim covers every current-state target
enumerated in the deletion plan—not the source simulator, ordinary source-history staging views,
or the evidence records themselves.

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

A production erasure workflow normally has to verify the request and applicable legal basis, honor
exceptions and restrictions, fence replay, resolve every identity version, delete dependents
before the final map, notify recipients, purge or age out source and storage history, cover exports
and backups, and record evidence. The exact operations are environment-specific and are not fully
implemented in this repository.

For that reason, the documentation provides a how-to for
[verifying the demo's terminal deletion](../how-to-guides/verify-terminal-deletion.md), but not a
pretend universal procedure for physical erasure.

!!! warning "Use an owner session for the dbt deletion tests"
    The compiled deletion tests read restricted control evidence and invoke the protected
    pseudonymization wrapper. Ordinary persona sessions are intentionally denied those privileges.
    A case-view check must be performed separately through an authorized aggregate query or by a
    trusted owner session that can execute the dbt test.
