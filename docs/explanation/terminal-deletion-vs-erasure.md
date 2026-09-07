---
icon: lucide/trash-2
---

# Terminal deletion versus physical erasure

The demo implements **logical current-state identity unlinking** across governed dbt outputs. It
does not, by itself, anonymise retained facts or physically erase every copy of a person's data.

## What “terminal” means here

A customer change row with `source_operation = 'DELETE'` is first stored as a detected request. It
does not delete anything by itself. A separate privacy decision must be `CONFIRMED`, and no legal
hold may apply, before the request becomes `AUTHORIZED`.

Only then does the deletion plan expand the stable customer ID to every historical SSN, derive all
corresponding customer keys, and authorize mode-specific action:

- both `priva_map` tables;
- customer/service Layer2 relations;
- Layer1 quarantine tables;
- Layer3 customer/service dimensions;
- SPECIAL event/invoice reassignment to `-99999`, or FULL governed-output fact deletion;
- controlled case views.

Dependent extracts that still carry an older SSN lose their identifying link because the plan
expands through the stable customer ID first. A later upsert cannot resurrect an authorized key. A
pending, rejected, or held request creates no plan and cannot enter the suppression gate.

The exact models, states, and 17 planned targets are listed in
[Customer deletion tombstone and macros](../reference/deletion-control.md).

## What remains on purpose

The synthetic CSV seeds retain the upsert, tombstone, and confirmation fixtures so the demo is
reproducible. Ordinary Layer1 staging views retain source-shaped rows, and restricted deletion
control tables retain minimum case evidence. SPECIAL facts retain measures and dates under the
shared erased member; FULL facts are absent from governed current outputs. The absence claim does
not cover the source simulator, ordinary history views, or evidence records.

## Why the erased member is not automatically anonymous

Kimball's special-member pattern solves dimensional referential integrity: a fact foreign key
joins to a descriptive row instead of becoming null. It does not answer the legal identifiability
question. Exact timestamps, amounts, measures, and transaction identifiers can still allow
singling out or linkage. If that risk remains, the facts remain Personal Data even though the
modeled customer key is `-99999`.

The EDPB's July 2026 version-one anonymisation guidance proposes checking for record isolation,
linkage, and inference. Exact event and invoice identifiers deliberately remain in this demo, so it
does not claim that the retained facts satisfy that framework. The guidance is currently under
[public consultation](https://www.edpb.europa.eu/public-consultations/guidelines-022026-on-anonymisation_en).

Production must either retain those facts under an applicable purpose, legal basis, and Article 17
exception, or transform them further until the controller can substantiate anonymisation. Possible
controls include coarser time buckets, suppressed rare categories, aggregated measures, and
replacement of identifying transaction IDs.

## Why a successful query is not physical erasure

The models use replacement materializations. After a successful rebuild, current mappings and
dimensions no longer return the original customer/service keys; SPECIAL facts use erased members,
FULL facts are absent, and case views expose neither. Storage systems can still retain other copies:

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

See [Deletion operations and recovery](../reference/deletion-operations.md) for durable control archives, execution states,
isolated private validation, and recovery rehearsal.
