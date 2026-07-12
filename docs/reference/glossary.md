---
title: Glossary
icon: lucide/book-a
---

# Glossary

## Terms

| Term | Meaning in this project |
| --- | --- |
| Accepted record | An ordinary valid record or an erased fact whose classifier returns `ACCEPTED` |
| Canonical value | Input normalized before pseudonymization: digits-only SSN/phone, ISO date, or lowercase trimmed whitespace-collapsed text |
| Case view | Standard `layer3_case` view that preserves protected keys and resolves a fixed readable subset for `case_users` or `privacy_admins` |
| Control catalog/schema | The connection-default `workspace.default` context, distinct from governed output placement |
| Controlled readable | Column metadata state used for readable values exposed by case views |
| Data schema | One of the six prefixable schemas from `layer1_source` through `layer3_case` |
| Deployment identity | Privileged dbt producer/owner that creates the catalog, functions, relations, and grants |
| Domain separation | Inclusion of a stable namespace such as `customer.email` in the digest input so equal values used for different purposes do not share a key |
| `fa_pd` | Prefix used by the full-access Personal Data mapping models |
| Grain | The entity or event represented by one relation row |
| Layer1 | Source-shaped typed staging and raw quarantine area |
| Layer1 source | Four dbt seed tables that simulate upstream extracts |
| Layer2 | Pseudonymous key boundary, classifier, and accepted protected tables |
| Layer3 | Protected dimensions and facts for analytical access |
| Current-state identity unlinking | Absence of original subject keys and readable mappings; retained facts use erased members |
| Mapping tuple | Complete set of stored pseudonymous keys used to validate a customer or service join |
| Personal Data | GDPR term for information relating to an identified or identifiable natural person; pseudonymized values remain Personal Data |
| Pepper | Secret input included in deterministic key generation; `pepper_v1` is an operator-managed value |
| Physical erasure | Removal from current and retained physical storage, including Delta history, caches, exports, source retention, and backups |
| `priva_internal` | Fixed unprefixed schema containing the three SQL functions |
| `priva_map` | Governed mapping schema holding readable values beside their stored pseudonymous keys |
| Protected relation | Layer2 or Layer3 relation without the project's raw identity columns |
| Pseudonymous key | `v1:<digest>` value generated from purpose, version, domain, canonical input, and pepper |
| Pseudonymized | Personal Data state in which direct values are replaced with keys but remain attributable using additional information |
| Quarantine | Raw Layer1 table containing a rejected nondeleted record and one deterministic reason |
| Resolution status | Classifier output: `ACCEPTED` or one stream-specific quarantine reason |
| Schema prefix | Optional `DBT_SCHEMA_PREFIX` added to all data schemas but not `priva_internal` |
| Source simulator | Checked-in deterministic seeds; not a production ingestion or retention design |
| Stable SSN assumption | Nondeleted customer relationships use the SSN-derived key and do not maintain a historical alias map |
| Standard view | Persisted SQL view whose query-time predicate and masks evaluate for the caller; the four case models are standard views |
| Terminal deletion | Rule that an authorized deletion plan excludes all historical SSN keys for a customer ID, even after a later upsert; a source tombstone alone is not authorization |
| Type-1 current dimension | Customer dimension that exposes only the current active protected row |
| Type-2-style service dimension | One row per service validity period keyed by service ID plus start date; not a complete SCD2 implementation |
| `USING COLUMNS` | Unity Catalog mask metadata that passes the matching stored pseudonymous column to the mask function |
| Version pin | Fixed association of wrapper name, `v1`, secret scope, and secret key name |

## Concept boundaries

- Pseudonymized does not mean anonymous. See
  [Personal Data is not anonymous](../explanation/personal-data-not-anonymous.md).
- Logical deletion does not mean physical erasure. See
  [Terminal deletion versus erasure](../explanation/terminal-deletion-vs-erasure.md).
- Demo controls do not establish production GDPR compliance. See
  [Demo and production boundaries](../explanation/demo-and-production-boundaries.md).
