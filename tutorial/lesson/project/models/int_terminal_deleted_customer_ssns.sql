{{ config(materialized='ephemeral') }}

-- STEP 2 execution gate: require all six target/action pairs for each request and identity.
-- Collapse complete plans to one mode per SSN; FULL takes precedence over SPECIAL.
-- This is recomputed from browser fixtures. It is not a durable anti-resurrection ledger.

{{ tutorial_effective_deletion_modes(ref('int_customer_deletion_plan')) }}
