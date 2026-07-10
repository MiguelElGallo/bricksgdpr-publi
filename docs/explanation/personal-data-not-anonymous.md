---
icon: lucide/user-round-check
---

# Pseudonymized data is not anonymous

bricksgdpr uses **Personal Data** in the GDPR sense. It never describes a versioned hash as
anonymous data.

## The short version

A value such as `v1:…` hides the readable source value from ordinary analytics, but the project
keeps additional information that can reconnect it to a person: the protected `priva_map` area.
That is pseudonymization, not anonymization.

This is not only a wording preference. It changes how the data must be handled:

- protected keys still need access control;
- uses of the data still need an appropriate purpose and governance;
- deletion and retention obligations do not disappear;
- joining several protected tables can still build a detailed record about one person.

## More than names and SSNs

The project treats several categories as Personal Data, including customer and source identifiers,
names, email, phone, birth date, customer address, service identifiers, and installation address.
The installation address is included because information can relate to an identifiable person even
when it is not itself a government-issued identifier.

Event and invoice identifiers are left readable in the demo and become fact keys. That is a
deliberate **fixture classification assumption**: the synthetic values are assumed not to identify
a person independently. A production source must classify its real identifiers rather than copy
that assumption.

## Pseudonymization still creates useful analytics

The stable keys preserve the relationships that analytics needs:

- events can join to a customer;
- invoices can join to a customer and one service period;
- case views can prove that protected and readable rows have the same grain;
- terminal deletion can remove a person's governed outputs by key.

The design reduces routine exposure without pretending the linkability has vanished.

## What this project does not establish

The repository does not determine lawful basis, consent, purpose limitation, retention periods,
data-subject request policy, breach response, residency, or processor contracts. Those are wider
organizational and legal questions.

!!! warning "Not a compliance certification"
    A passing dbt build proves selected technical assertions against one deployment. It does not
    prove that an organization complies with the GDPR.

For the exact categories and tags, see [`priva_map` models](../reference/priva-map.md). The legal
definition used by the project comes from
[GDPR Article 4](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32016R0679).
