# Persona data-plane acceptance

These SQL files are designed for Databricks SQL **file tasks**. Databricks documents the file
task as the SQL task type that fully honors a Lakeflow Job's Run-as identity. Every positive file
asserts `session_user()`, the exact persona group vector, and only aggregate access properties; it
never returns readable Personal Data.

Pass `expected_user` to the positive file as the user email or service-principal application ID
used by `run_as`. The complete group vector is hard-coded so an identity with cross-persona
membership fails.

| Run-as persona | Positive file must succeed | Negative files that must fail with SQLSTATE 42501 |
| --- | --- | --- |
| `privacy_admins` | `privacy_admin.sql` | `deny_udf.sql` |
| `restricted_users` | `restricted_user.sql` | `deny_layer1.sql`, `deny_quarantine.sql`, `deny_layer3_case.sql`, `deny_udf.sql` |
| `case_users` | `case_user.sql` | `deny_layer1.sql`, `deny_quarantine.sql`, `deny_layer2.sql`, `deny_priva_map.sql`, `deny_udf.sql` |

Create one separate one-time run per persona and put that persona's independent tasks in the run
with no dependencies. Each parent run is expected to be failed because negative tasks intentionally
fail. Acceptance passes only when the positive task is
`SUCCESS` and every negative task is `FAILED` with `INSUFFICIENT_PERMISSIONS` and SQLSTATE `42501`.
An arbitrary parse, missing-object, compute, or internal error is not an access-control pass.

For automated validation, use one temporary service principal per persona. Assign it to the
workspace at `USER`, add it to exactly one persona group, give it no direct Unity Catalog,
warehouse, UDF, or secret permissions, and set `run_as.service_principal_name` to its application
ID. Deactivate and delete all temporary principals after collecting the task states. This proves
the group-driven data plane without creating or retaining credentials.

[`scripts/validate_personas.sh`](../../scripts/validate_personas.sh) implements that complete
workflow behind an explicit `--apply` gate, including task-state/error validation and cleanup.

The repository-owned `@example.invalid` users are persistent identity-topology fixtures. Their
reserved addresses cannot complete Databricks email verification, so Unity Catalog correctly
rejects execution as those users with `email_not_verified`. Use deliverable or IdP-backed users
when separately authenticated human-session acceptance is required.

Primary Databricks references:

- [Lakeflow Jobs identity and Run-as privileges](https://docs.databricks.com/aws/en/jobs/privileges)
- [SQL file tasks](https://docs.databricks.com/aws/en/jobs/tasks/sql)
- [Service Principal User role](https://docs.databricks.com/aws/en/security/auth/access-control/service-principal-acl)
- [Email sign-in and verification](https://docs.databricks.com/aws/en/security/auth/email-login)
