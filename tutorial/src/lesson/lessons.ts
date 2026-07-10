import type { RawQueryResult } from "../engine";
import type { LessonId, LessonOption, LessonTask } from "../types";

type LessonTaskSpec = Omit<LessonTask, "status">;

interface LessonProofSpec {
  sql: string;
  label: string;
  selectedRelation: string;
  successMessage: string;
  failureMessage: string;
  validate: (result: RawQueryResult) => boolean;
}

export interface LessonSpec {
  id: LessonId;
  number: number;
  title: string;
  summary: string;
  objective: string;
  duration: string;
  command: string;
  filePaths: readonly string[];
  visibleRelationNames: readonly string[];
  requiredSuccessfulResources: readonly string[];
  tasks: readonly LessonTaskSpec[];
  proof: LessonProofSpec;
}

export const DEFAULT_LESSON_ID: LessonId = "invoice-quarantine";

const invoiceValidationSql = `
select
    quarantine.invoice_id,
    quarantine.service_id,
    quarantine.quarantine_reason,
    (
        select count(*)
        from main.int_invoices_resolved as accepted
        where accepted.invoice_id = quarantine.invoice_id
    ) as accepted_rows
from main.quarantine_invoices as quarantine
where quarantine.invoice_id = 'INV-0105'
`;

const customerValidationSql = `
with expected_protected_columns (table_name, column_name) as (
    values
        ('int_customer_protected', 'customer_key'),
        ('int_customer_protected', 'customer_pk_key'),
        ('int_customer_protected', 'customer_id_key'),
        ('int_customer_protected', 'first_name_key'),
        ('int_customer_protected', 'last_name_key'),
        ('int_customer_protected', 'full_name_key'),
        ('int_customer_protected', 'email_key'),
        ('int_customer_protected', 'phone_key'),
        ('int_customer_protected', 'birth_date_key'),
        ('int_customer_protected', 'address_key'),
        ('int_customer_protected', 'customer_segment'),
        ('int_customer_protected', 'is_active'),
        ('int_customer_protected', 'source_updated_at'),
        ('dim_customer', 'customer_key'),
        ('dim_customer', 'customer_pk_key'),
        ('dim_customer', 'customer_id_key'),
        ('dim_customer', 'first_name_key'),
        ('dim_customer', 'last_name_key'),
        ('dim_customer', 'full_name_key'),
        ('dim_customer', 'email_key'),
        ('dim_customer', 'phone_key'),
        ('dim_customer', 'birth_date_key'),
        ('dim_customer', 'address_key'),
        ('dim_customer', 'customer_segment'),
        ('dim_customer', 'is_active'),
        ('dim_customer', 'source_updated_at')
),

actual_protected_columns as (
    select table_name, column_name
    from information_schema.columns
    where
        table_schema = 'main'
        and table_name in ('int_customer_protected', 'dim_customer')
),

protected_schema_differences as (
    (
        select table_name, column_name from actual_protected_columns
        except
        select table_name, column_name from expected_protected_columns
    )
    union all
    (
        select table_name, column_name from expected_protected_columns
        except
        select table_name, column_name from actual_protected_columns
    )
),

protected_schema_audit as (
    select count(*) as protected_schema_violations
    from protected_schema_differences
)

select
    source.customer_id,
    source.customer_ssn as source_ssn,
    source.email as source_email,
    mapped.customer_key,
    mapped.email_key,
    protected.customer_segment,
    protected.is_active,
    (
        mapped.customer_key = protected.customer_key
        and protected.customer_key = dimension.customer_key
    ) as key_preserved,
    mapped.customer_key != mapped.email_key as keys_differ,
    audit.protected_schema_violations
from main.stg_customer as source
inner join main.demo_customer_map as mapped
    on source.customer_id = mapped.customer_id_value
inner join main.int_customer_protected as protected
    on mapped.customer_key = protected.customer_key
inner join main.dim_customer as dimension
    on protected.customer_key = dimension.customer_key
cross join protected_schema_audit as audit
where
    source.customer_id = 'CUST-0001'
    and source.source_operation = 'UPSERT'
`;

function firstRowByColumn(result: RawQueryResult): Record<string, unknown> | null {
  const values = result.rows[0];
  if (!values || result.rows.length !== 1) return null;
  return Object.fromEntries(result.columns.map((column, index) => [column.name, values[index]]));
}

const lessonSpecs: readonly LessonSpec[] = [
  {
    id: "invoice-quarantine",
    number: 1,
    title: "Trace an invoice into quarantine",
    summary:
      "Run real dbt Core in your browser and follow one deliberately invalid synthetic invoice through deterministic classification.",
    objective:
      "INV-0105 is preserved with SERVICE_NOT_FOUND, excluded from accepted analytics, and placed in exactly one output partition.",
    duration: "12 min",
    command: "dbt build --select +assert_invoice_partition --indirect-selection cautious",
    filePaths: [
      "models/stg_invoices.sql",
      "models/int_invoice_resolution.sql",
      "models/quarantine_invoices.sql",
      "tests/assert_invoice_partition.sql",
    ],
    visibleRelationNames: [
      "customer",
      "customer_services",
      "invoices",
      "stg_customer",
      "stg_customer_services",
      "stg_invoices",
      "int_invoices_resolved",
      "quarantine_invoices",
    ],
    requiredSuccessfulResources: [
      "int_invoices_resolved",
      "quarantine_invoices",
      "assert_invoice_partition",
    ],
    tasks: [
      {
        id: "boot",
        title: "Start the local lab",
        detail: "Load dbt Core, DuckDB and the synthetic project in this browser tab.",
      },
      {
        id: "build",
        title: "Build the invoice path",
        detail: "Build the focused staging, accepted and quarantine path with its dbt test.",
      },
      {
        id: "inspect",
        title: "Inspect INV-0105",
        detail: "Confirm that its source service ID is SVC-7777-A.",
      },
      {
        id: "classify",
        title: "Read the decision",
        detail: "Observe the stable SERVICE_NOT_FOUND quarantine reason.",
      },
      {
        id: "partition",
        title: "Prove the partition",
        detail: "Verify the invoice appears once in quarantine and zero times in accepted Layer2.",
      },
    ],
    proof: {
      sql: invoiceValidationSql,
      label: "INV-0105 quarantine proof",
      selectedRelation: "quarantine_invoices",
      successMessage:
        "Lesson complete: INV-0105 is quarantined as SERVICE_NOT_FOUND and has 0 accepted rows.",
      failureMessage: "The build passed, but the invoice semantic proof did not match.",
      validate(result) {
        const row = firstRowByColumn(result);
        return (
          row?.invoice_id === "INV-0105" &&
          row.service_id === "SVC-7777-A" &&
          row.quarantine_reason === "SERVICE_NOT_FOUND" &&
          Number(row.accepted_rows) === 0
        );
      },
    },
  },
  {
    id: "customer-flow",
    number: 2,
    title: "Follow a customer through protected layers",
    summary:
      "Trace one synthetic customer from readable Layer1 fields through a local mapping into protected analytical keys.",
    objective:
      "CUST-0001 keeps useful business attributes while direct identifiers become distinct demo keys that remain stable into Layer3.",
    duration: "15 min",
    command:
      "dbt build --select +assert_customer_flow_fixture --indirect-selection cautious",
    filePaths: [
      "models/stg_customer.sql",
      "macros/demo_personal_data_key.sql",
      "models/int_current_customers.sql",
      "models/demo_customer_map.sql",
      "models/int_customer_protected.sql",
      "models/dim_customer.sql",
      "tests/assert_customer_flow_fixture.sql",
    ],
    visibleRelationNames: [
      "customer",
      "stg_customer",
      "demo_customer_map",
      "int_customer_protected",
      "dim_customer",
    ],
    requiredSuccessfulResources: [
      "demo_customer_map",
      "int_customer_protected",
      "dim_customer",
      "assert_customer_flow_fixture",
    ],
    tasks: [
      {
        id: "boot",
        title: "Start the local lab",
        detail: "Reuse the same private dbt and DuckDB runtime for both lessons.",
      },
      {
        id: "build",
        title: "Build the customer path",
        detail: "Build the focused mapping, protected Layer2 and Layer3 dimension path.",
      },
      {
        id: "inspect",
        title: "Inspect CUST-0001",
        detail: "Find the readable synthetic SSN and email at the Layer1 boundary.",
      },
      {
        id: "protect",
        title: "Compare protected keys",
        detail: "Confirm customer and email use distinct demo keys.",
      },
      {
        id: "dimension",
        title: "Verify the Layer3 row",
        detail: "Prove the key is preserved and both protected outputs match the exact allowed schema.",
      },
    ],
    proof: {
      sql: customerValidationSql,
      label: "CUST-0001 protected customer proof",
      selectedRelation: "dim_customer",
      successMessage:
        "Lesson complete: CUST-0001 reaches Layer3 with preserved, distinct demo keys and the exact protected schema.",
      failureMessage: "The build passed, but the customer-flow semantic proof did not match.",
      validate(result) {
        const row = firstRowByColumn(result);
        return (
          row?.customer_id === "CUST-0001" &&
          row.source_ssn === "900-00-0001" &&
          row.source_email === "customer01@example.invalid" &&
          row.customer_key ===
            "demo-v1:825c0ec1125ce7f0b50d3ad4013f02ac42d0565d8cc4a202b3a0ab5f1ee0f3c8" &&
          row.email_key ===
            "demo-v1:a84a4bc9c4f38a8e1a06248ed3499d7ce505d09dbc745275d3226d021ef03853" &&
          row.customer_segment === "small_business" &&
          row.is_active === true &&
          row.key_preserved === true &&
          row.keys_differ === true &&
          Number(row.protected_schema_violations) === 0
        );
      },
    },
  },
];

export const LESSONS = lessonSpecs;

export const LESSON_OPTIONS: LessonOption[] = lessonSpecs.map(({ id, number, title }) => ({
  id,
  number,
  title,
}));

export function isLessonId(value: string | null): value is LessonId {
  return lessonSpecs.some((lesson) => lesson.id === value);
}

export function lessonIdFromSearch(search: string): LessonId {
  const requested = new URLSearchParams(search).get("lesson");
  return isLessonId(requested) ? requested : DEFAULT_LESSON_ID;
}

export function getLessonSpec(lessonId: LessonId): LessonSpec {
  const lesson = lessonSpecs.find((candidate) => candidate.id === lessonId);
  if (!lesson) throw new Error(`Unknown tutorial lesson: ${lessonId}`);
  return lesson;
}

export function invocationIncludesLessonResources(
  lesson: LessonSpec,
  results: Array<{ uniqueId: string; status: string }>,
) {
  const successfulIds = results
    .filter((result) => ["pass", "success"].includes(result.status.toLowerCase()))
    .map((result) => result.uniqueId);
  return lesson.requiredSuccessfulResources.every((resource) =>
    successfulIds.some((uniqueId) => uniqueId.endsWith(`.${resource}`)),
  );
}
