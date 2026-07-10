---
icon: lucide/eye
---

# Case views and least privilege

Protected analytics are useful precisely because most work does not need readable identity. Some
investigations do. The case-view layer provides a narrow return path without turning the mapping
table into a general consumer surface.

## Four views, four preserved grains

Each case view begins with one protected Layer3 relation:

- customer dimension;
- service-period dimension;
- customer-event fact;
- invoice fact.

It joins to the mapping tables through the complete pseudonymous tuple needed for that grain, then
adds only selected readable fields. The view does not build a wide “customer 360” relation that
could multiply facts or expose every mapped attribute.

## Fail closed when the group is absent

Every view ends with the same invoker-aware predicate: the session must be a member of
`case_users` or `privacy_admins`. An unaffiliated deployment session receives zero rows even when
it owns the underlying relations.

`restricted_users` can read protected Layer3 but receive no grant on the case-view schema. This
keeps routine analytical access separate from readable case work.

## This is not a case-management system

The predicate checks group membership only. There is no case ID, approved-subject list, purpose,
time window, ticket, per-row entitlement, or built-in access audit.

As implemented, every member of `case_users` can resolve every row exposed by all four case views.
A production case workflow needs a narrower authorization and audit model if “need to know” is
subject- or case-specific.

## Defense in depth is intentionally coupled

Case users are recognized by the map's column-mask function as readers of raw values. The views
need that behavior to resolve approved fields. A separate grant rule denies case users direct
access to `priva_map`.

That coupling is why tests cover both masks and direct relation grants. If either side drifts, the
security property changes.

## Grain is a security property

A join that duplicates an invoice or event can disclose more than intended and corrupt analytical
meaning. Case-view tests compare authorized-view counts and key uniqueness with their protected
parents, and the SQL joins on complete customer and service tuples.

For the exact exposed columns, see
[Layer3 models and case views](../reference/layer3-and-case.md). For persona permissions, see
[Access control](../reference/access-control.md).
