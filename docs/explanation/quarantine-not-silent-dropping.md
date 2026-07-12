---
icon: lucide/triangle-alert
---

# Quarantine instead of silent dropping

A source row that cannot enter protected analytics still carries operational meaning. Silently
dropping it would hide both a data-quality problem and a possible gap in governed processing.

bricksgdpr divides events into accepted or quarantined outcomes. Invoices have a third explicit
outcome: an invalid row for a suppression-admitted customer is authorized-suppressed from current
accepted and raw-quarantine outputs. Service periods for deleted subjects are removed because they
are identifying dimension records.

```mermaid
flowchart LR
    source["source event or invoice"] --> keyed["replace raw identifiers with keys"]
    keyed --> classify{"deterministic classifier"}
    classify -->|ACCEPTED| protected["durable Layer2 table"]
    classify -->|reason code| quarantine["raw Layer1 quarantine"]
    classify -->|"invalid + authorized deletion"| suppressed["authorized suppression<br/>reconstructable from restricted source and plan evidence"]
```

## Why quarantine stays in Layer1

The rejected row may need its readable source values for controlled remediation. Putting it into
Layer2 would violate the promise that durable Layer2 relations contain no raw Personal Data.

Quarantine therefore remains in the restricted raw-data boundary and is readable only by privacy
administrators and the trusted deployment identity.

## One reason wins

A record can violate more than one rule. The classifiers use a fixed order so the same row receives
the same primary reason every time.

For example, an invoice first checks whether its customer and service can be resolved. Only then
does it evaluate service validity, date ranges, and payment consistency. This makes the reason
actionable: an operator fixes the first blocking condition, rebuilds, and then sees whether another
condition remains.

The order is part of the contract. Reordering conditions can change observed reasons even if the
accepted set remains the same.

## Late arrivals can resolve themselves

The quarantine models are rebuilt as tables rather than appended as an error log. A service that
arrives before its customer receives `CUSTOMER_NOT_FOUND`. When the customer later appears, the
same deterministic keys resolve and the next rebuild moves the service into Layer2.

This behavior is different from authorized deletion. Valid event and invoice facts are accepted
under the erased member; an invalid erased invoice is authorized-suppressed rather than promoted
or copied into a raw quarantine. Customer and service dimension rows are removed. Deletion is not
presented as a fixable late-arrival error.

## What the partition tests prove

The singular tests compare classifier inputs with accepted, quarantined, and authorized-suppressed
outcomes. They assert that every row has exactly one outcome, including erased-member facts. The
suppressed outcome remains reconstructable only from restricted source history plus deletion-plan
evidence; it is not an analytical or raw-quarantine row.

Fixture-specific tests also check exact example counts and reasons. Those counts describe the
synthetic demo; they are not production thresholds.

For the complete reason codes, see [Sources and Layer1](../reference/sources-and-layer1.md) and
[Layer2 models](../reference/layer2.md).
