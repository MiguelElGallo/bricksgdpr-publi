---
icon: lucide/lightbulb
---

# Explanation

These pages explain **why** bricksgdpr is designed the way it is.

Use them when you want the reasoning behind a boundary or control. If you need to carry out a
task, go to the [how-to guides](../how-to-guides/index.md). If you need an exact name, default, or
contract, use the [reference](../reference/index.md).

## Architecture and data boundaries

<div class="grid cards" markdown>

-   :lucide-network: **[Architecture and trust boundaries](architecture-and-trust-boundaries.md)**

    ---

    Why raw values, mappings, protected analytics, case views, and internal functions live in
    separate areas.

-   :lucide-user-round-check: **[Pseudonymized data is not anonymous](personal-data-not-anonymous.md)**

    ---

    Why the project consistently calls its governed data **Personal Data**.

-   :lucide-key-round: **[Versioned, domain-separated keys](versioned-domain-separated-keys.md)**

    ---

    How canonicalization, framing, domains, and a pepper create stable keys without creating a
    public matching oracle.

-   :lucide-shield-check: **[Stored masks and pseudonymous joins](stored-masks-and-joins.md)**

    ---

    Why masks return stored keys and why joins never depend on masked raw columns.

</div>

## Operations and assurance

<div class="grid cards" markdown>

-   :lucide-triangle-alert: **[Quarantine instead of silent dropping](quarantine-not-silent-dropping.md)**

    ---

    Why rejected rows stay observable and why one deterministic reason wins.

-   :lucide-trash-2: **[Terminal deletion versus physical erasure](terminal-deletion-vs-erasure.md)**

    ---

    What the demo removes from current governed outputs—and what it cannot erase by itself.

-   :lucide-eye: **[Case views and least privilege](case-views-and-least-privilege.md)**

    ---

    Why readable values reappear only through four narrow, fail-closed views.

-   :lucide-badge-check: **[Executable security controls](executable-security-controls.md)**

    ---

    Why a successful model build is not enough without metadata and denial checks.

-   :lucide-factory: **[Demo and production boundaries](demo-and-production-boundaries.md)**

    ---

    Which lessons transfer to production and which controls still need real system integration.

</div>

!!! note "This is an engineering demonstration"
    bricksgdpr demonstrates selected technical controls. It is not legal advice, a complete GDPR
    control framework, or evidence that a deployment is compliant.
