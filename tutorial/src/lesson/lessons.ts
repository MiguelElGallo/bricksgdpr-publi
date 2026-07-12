import type { RawQueryResult } from "../engine";
import type { LessonId, LessonOption, LessonTask } from "../types";

type LessonTaskSpec = Omit<LessonTask, "status">;

export interface LessonProofSpec {
  sql: string;
  label: string;
  selectedRelation: string;
  successMessage: string;
  failureMessage: string;
  validate: (result: RawQueryResult) => boolean;
}

export interface LessonRunSpec {
  command: string;
  requiredSuccessfulResources: readonly string[];
  proof: LessonProofSpec;
}

export interface LessonStepSpec extends LessonRunSpec {
  id: string;
  title: string;
  buildsOn: string;
  why: string;
  change: string;
  observe: string;
  focusFilePath: string;
  revealFilePaths: readonly string[];
  visibleRelationNames: readonly string[];
}

export interface LessonSpec extends LessonRunSpec {
  id: LessonId;
  number: number;
  title: string;
  summary: string;
  objective: string;
  duration: string;
  filePaths: readonly string[];
  visibleRelationNames: readonly string[];
  tasks: readonly LessonTaskSpec[];
  steps?: readonly LessonStepSpec[];
}

export interface TutorialLocation {
  lessonId: LessonId;
  stepId: string | null;
}

export const DEFAULT_LESSON_ID: LessonId = "invoice-quarantine";
export const DEFAULT_CUSTOMER_STEP_ID = "staging";

const CUSTOMER_KEY =
  "demo-v1:825c0ec1125ce7f0b50d3ad4013f02ac42d0565d8cc4a202b3a0ab5f1ee0f3c8";
const CUSTOMER_EMAIL_KEY =
  "demo-v1:a84a4bc9c4f38a8e1a06248ed3499d7ce505d09dbc745275d3226d021ef03853";

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

const stagingValidationSql = `
select
    customer_change_id,
    customer_id,
    customer_ssn,
    email,
    customer_segment,
    is_active,
    source_operation,
    (select count(*) from main.stg_customer) as staged_change_count
from main.stg_customer
where customer_id = 'CUST-0001'
`;

const currentValidationSql = `
select
    customer_change_id,
    customer_id,
    customer_ssn,
    email,
    customer_segment,
    is_active,
    (select count(*) from main.int_current_customers) as current_customer_count,
    (
        select count(*)
        from main.int_current_customers as current_customers
        where current_customers.customer_id = 'CUST-0097'
    ) as pending_customer_rows,
    (
        select count(*)
        from main.int_current_customers as current_customers
        where current_customers.customer_id = 'CUST-0099'
    ) as authorized_deleted_rows
from main.int_current_customers
where customer_id = 'CUST-0001'
`;

const mappingValidationSql = `
select
    customer_id_value,
    customer_key,
    email_key,
    customer_segment,
    customer_key != email_key as keys_differ,
    (select count(*) from main.demo_customer_map) as mapped_customer_count
from main.demo_customer_map
where customer_id_value = 'CUST-0001'
`;

const layer2ValidationSql = `
with expected_columns (column_name) as (
    values
        ('customer_key'),
        ('customer_pk_key'),
        ('customer_id_key'),
        ('first_name_key'),
        ('last_name_key'),
        ('full_name_key'),
        ('email_key'),
        ('phone_key'),
        ('birth_date_key'),
        ('address_key'),
        ('customer_segment'),
        ('is_active'),
        ('source_updated_at')
),

actual_columns as (
    select column_name
    from information_schema.columns
    where table_schema = 'main' and table_name = 'int_customer_protected'
),

schema_differences as (
    (select column_name from actual_columns except select column_name from expected_columns)
    union all
    (select column_name from expected_columns except select column_name from actual_columns)
)

select
    customer_key,
    email_key,
    customer_segment,
    is_active,
    (select count(*) from main.int_customer_protected) as protected_customer_count,
    (select count(*) from actual_columns) as protected_column_count,
    (select count(*) from schema_differences) as protected_schema_violations
from main.int_customer_protected
where customer_key = '${CUSTOMER_KEY}'
`;

const layer3ValidationSql = `
select
    dimension.customer_key,
    dimension.email_key,
    dimension.customer_segment,
    dimension.is_active,
    (
        dimension.customer_key = protected.customer_key
        and dimension.email_key = protected.email_key
        and dimension.customer_segment = protected.customer_segment
        and dimension.is_active = protected.is_active
        and dimension.source_updated_at = protected.source_updated_at
    ) as layer2_row_preserved,
    (select count(*) from main.dim_customer) as dimension_customer_count
from main.dim_customer as dimension
inner join main.int_customer_protected as protected
    on dimension.customer_key = protected.customer_key
where dimension.customer_key = '${CUSTOMER_KEY}'
`;

function firstRowByColumn(result: RawQueryResult): Record<string, unknown> | null {
  const values = result.rows[0];
  if (!values || result.rows.length !== 1) return null;
  return Object.fromEntries(result.columns.map((column, index) => [column.name, values[index]]));
}

const customerSteps: readonly LessonStepSpec[] = [
  {
    id: "staging",
    title: "Start with the staged change",
    buildsOn: "The synthetic customer seed",
    why: "Layer1 needs typed, normalized source events before downstream models can rely on them.",
    change:
      "Trim and cast the source fields while keeping the readable synthetic identifiers at the Layer1 boundary.",
    observe:
      "CUST-0001 is one readable UPSERT, and the staged change feed contains 19 rows.",
    focusFilePath: "models/stg_customer.sql",
    revealFilePaths: ["models/stg_customer.sql"],
    visibleRelationNames: ["customer", "stg_customer"],
    command: "dbt build --select +stg_customer --indirect-selection cautious",
    requiredSuccessfulResources: ["stg_customer"],
    proof: {
      sql: stagingValidationSql,
      label: "Step 1 · staged CUST-0001",
      selectedRelation: "stg_customer",
      successMessage:
        "Step 1 complete: CUST-0001 is a typed, readable UPSERT in the 19-row staging change feed.",
      failureMessage: "The staging build passed, but the CUST-0001 checkpoint did not match.",
      validate(result) {
        const row = firstRowByColumn(result);
        return (
          row?.customer_change_id === "CCHG-0001-U" &&
          row.customer_id === "CUST-0001" &&
          row.customer_ssn === "900-00-0001" &&
          row.email === "customer01@example.invalid" &&
          row.customer_segment === "small_business" &&
          row.is_active === true &&
          row.source_operation === "UPSERT" &&
          Number(row.staged_change_count) === 19
        );
      },
    },
  },
  {
    id: "current",
    title: "Reduce the feed to current customers",
    buildsOn: "Step 1 · the typed staging change feed",
    why: "Staging contains source events, but analytical models need one current active row per customer.",
    change:
      "Store source deletions, join a separate privacy decision, plan every target only when authorized, then exclude planned identities.",
    observe:
      "CUST-0001 appears once; pending CUST-0097 remains, confirmed CUST-0099 is absent, and 15 current customers survive.",
    focusFilePath: "models/int_current_customers.sql",
    revealFilePaths: [
      "models/stg_customer_deletion_confirmations.sql",
      "models/int_customer_deletion_requests.sql",
      "models/int_customer_deletion_authorizations.sql",
      "models/int_customer_deletion_plan.sql",
      "models/int_terminal_deleted_customer_ssns.sql",
      "models/int_current_customers.sql",
    ],
    visibleRelationNames: [
      "customer",
      "customer_deletion_confirmations",
      "stg_customer",
      "int_customer_deletion_requests",
      "int_customer_deletion_authorizations",
      "int_customer_deletion_plan",
      "int_current_customers",
    ],
    command: "dbt build --select +int_current_customers --indirect-selection cautious",
    requiredSuccessfulResources: [
      "int_current_customers",
      "assert_current_customers_terminal_deletion",
      "assert_deletion_confirmation_gate",
    ],
    proof: {
      sql: currentValidationSql,
      label: "Step 2 · current CUST-0001",
      selectedRelation: "int_current_customers",
      successMessage:
        "Step 2 complete: the 15-row view preserves pending CUST-0097 and removes only confirmed CUST-0099.",
      failureMessage: "The current-state build passed, but the current-customer checkpoint did not match.",
      validate(result) {
        const row = firstRowByColumn(result);
        return (
          row?.customer_change_id === "CCHG-0001-U" &&
          row.customer_id === "CUST-0001" &&
          row.customer_ssn === "900-00-0001" &&
          row.email === "customer01@example.invalid" &&
          row.customer_segment === "small_business" &&
          row.is_active === true &&
          Number(row.current_customer_count) === 15 &&
          Number(row.pending_customer_rows) === 1 &&
          Number(row.authorized_deleted_rows) === 0
        );
      },
    },
  },
  {
    id: "mapping",
    title: "Create domain-separated demo keys",
    buildsOn: "Step 2 · one current active row per customer",
    why: "Analytics needs stable join keys without carrying readable identifiers into protected layers.",
    change:
      "Create public demo-v1 keys beside readable synthetic values inside the browser-only mapping boundary.",
    observe:
      "CUST-0001 receives exact customer and email keys that are stable and different; the map contains 15 rows.",
    focusFilePath: "models/demo_customer_map.sql",
    revealFilePaths: ["macros/demo_personal_data_key.sql", "models/demo_customer_map.sql"],
    visibleRelationNames: [
      "customer",
      "stg_customer",
      "int_current_customers",
      "demo_customer_map",
    ],
    command: "dbt build --select +demo_customer_map --indirect-selection cautious",
    requiredSuccessfulResources: ["demo_customer_map", "assert_demo_customer_key_contract"],
    proof: {
      sql: mappingValidationSql,
      label: "Step 3 · mapped CUST-0001",
      selectedRelation: "demo_customer_map",
      successMessage:
        "Step 3 complete: CUST-0001 has stable, distinct public demo keys in the 15-row teaching map.",
      failureMessage: "The mapping build passed, but the demo-key checkpoint did not match.",
      validate(result) {
        const row = firstRowByColumn(result);
        return (
          row?.customer_id_value === "CUST-0001" &&
          row.customer_key === CUSTOMER_KEY &&
          row.email_key === CUSTOMER_EMAIL_KEY &&
          row.customer_segment === "small_business" &&
          row.keys_differ === true &&
          Number(row.mapped_customer_count) === 15
        );
      },
    },
  },
  {
    id: "layer2",
    title: "Cross into protected Layer2",
    buildsOn: "Step 3 · readable values beside public demo keys in the mapping",
    why: "The protected analytical boundary must keep keys and useful business facts without readable identity values.",
    change:
      "Project the ten key columns plus segment, lifecycle state, and update time; leave every *_value column behind.",
    observe:
      "The same keys remain in 15 rows, and Layer2 has exactly 13 allowed columns with zero schema violations.",
    focusFilePath: "models/int_customer_protected.sql",
    revealFilePaths: ["models/int_customer_protected.sql"],
    visibleRelationNames: [
      "customer",
      "stg_customer",
      "int_current_customers",
      "demo_customer_map",
      "int_customer_protected",
    ],
    command: "dbt build --select +int_customer_protected --indirect-selection cautious",
    requiredSuccessfulResources: [
      "int_customer_protected",
      "assert_customer_map_projection",
      "assert_customer_protected_schema",
    ],
    proof: {
      sql: layer2ValidationSql,
      label: "Step 4 · protected CUST-0001",
      selectedRelation: "int_customer_protected",
      successMessage:
        "Step 4 complete: Layer2 keeps CUST-0001's keys and business facts in the exact 13-column protected schema.",
      failureMessage: "The Layer2 build passed, but the protected-schema checkpoint did not match.",
      validate(result) {
        const row = firstRowByColumn(result);
        return (
          row?.customer_key === CUSTOMER_KEY &&
          row.email_key === CUSTOMER_EMAIL_KEY &&
          row.customer_segment === "small_business" &&
          row.is_active === true &&
          Number(row.protected_customer_count) === 15 &&
          Number(row.protected_column_count) === 13 &&
          Number(row.protected_schema_violations) === 0
        );
      },
    },
  },
  {
    id: "layer3",
    title: "Publish the protected Layer3 dimension",
    buildsOn: "Step 4 · the protected Layer2 customer contract",
    why: "An analytics-facing dimension should preserve the protected grain without reaching back to readable data.",
    change:
      "Build dim_customer only from Layer2 and preserve one row per active customer key for downstream consumers.",
    observe:
      "CUST-0001's keys and business facts are unchanged in the 15-row dimension, and the final flow assertion passes.",
    focusFilePath: "models/dim_customer.sql",
    revealFilePaths: ["models/dim_customer.sql"],
    visibleRelationNames: [
      "customer",
      "stg_customer",
      "int_current_customers",
      "demo_customer_map",
      "int_customer_protected",
      "dim_customer",
    ],
    command: "dbt build --select +dim_customer --indirect-selection cautious",
    requiredSuccessfulResources: [
      "dim_customer",
      "assert_customer_dimension_integrity",
      "assert_customer_flow_fixture",
    ],
    proof: {
      sql: layer3ValidationSql,
      label: "Step 5 · Layer3 CUST-0001",
      selectedRelation: "dim_customer",
      successMessage:
        "Tutorial complete: Layer3 preserves CUST-0001's protected Layer2 contract across all five checkpoints.",
      failureMessage: "The Layer3 build passed, but the final customer-flow checkpoint did not match.",
      validate(result) {
        const row = firstRowByColumn(result);
        return (
          row?.customer_key === CUSTOMER_KEY &&
          row.email_key === CUSTOMER_EMAIL_KEY &&
          row.customer_segment === "small_business" &&
          row.is_active === true &&
          row.layer2_row_preserved === true &&
          Number(row.dimension_customer_count) === 15
        );
      },
    },
  },
];

const customerFilePaths = customerSteps.flatMap((step) => [...step.revealFilePaths]);
const customerVisibleRelations = customerSteps.at(-1)?.visibleRelationNames ?? [];
const customerFinalStep = customerSteps.at(-1);
if (!customerFinalStep) throw new Error("Customer tutorial requires at least one step");

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
    title: "Build a customer flow from staging to Layer3",
    summary:
      "Start with one readable staged change, then add one dbt model at a time until it becomes a protected Layer3 customer dimension.",
    objective:
      "Across five focused checkpoints, CUST-0001 keeps useful business facts while readable identifiers stop at the mapping boundary.",
    duration: "22 min",
    command: customerFinalStep.command,
    filePaths: customerFilePaths,
    visibleRelationNames: customerVisibleRelations,
    requiredSuccessfulResources: customerFinalStep.requiredSuccessfulResources,
    tasks: customerSteps.map((step) => ({
      id: step.id,
      title: step.title,
      detail: step.why,
    })),
    steps: customerSteps,
    proof: customerFinalStep.proof,
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

export function getLessonSpec(lessonId: LessonId): LessonSpec {
  const lesson = lessonSpecs.find((candidate) => candidate.id === lessonId);
  if (!lesson) throw new Error(`Unknown tutorial lesson: ${lessonId}`);
  return lesson;
}

export function getLessonStep(lesson: LessonSpec, stepId: string | null): LessonStepSpec | null {
  if (!lesson.steps) return null;
  return lesson.steps.find((step) => step.id === stepId) ?? lesson.steps[0] ?? null;
}

export function tutorialLocationFromSearch(search: string): TutorialLocation {
  const parameters = new URLSearchParams(search);
  const requestedLesson = parameters.get("lesson");
  const lessonId = isLessonId(requestedLesson) ? requestedLesson : DEFAULT_LESSON_ID;
  const lesson = getLessonSpec(lessonId);
  if (!lesson.steps) return { lessonId, stepId: null };
  const requestedStep = parameters.get("step");
  const stepId = lesson.steps.some((step) => step.id === requestedStep)
    ? requestedStep
    : (lesson.steps[0]?.id ?? DEFAULT_CUSTOMER_STEP_ID);
  return { lessonId, stepId };
}

export function lessonIdFromSearch(search: string): LessonId {
  return tutorialLocationFromSearch(search).lessonId;
}

export function invocationIncludesRequiredResources(
  requiredSuccessfulResources: readonly string[],
  results: Array<{ uniqueId: string; status: string }>,
) {
  const successfulIds = results
    .filter((result) => ["pass", "success"].includes(result.status.toLowerCase()))
    .map((result) => result.uniqueId);
  return requiredSuccessfulResources.every((resource) =>
    successfulIds.some((uniqueId) => uniqueId.endsWith(`.${resource}`)),
  );
}

export function invocationIncludesLessonResources(
  lesson: LessonSpec,
  results: Array<{ uniqueId: string; status: string }>,
) {
  return invocationIncludesRequiredResources(lesson.requiredSuccessfulResources, results);
}
