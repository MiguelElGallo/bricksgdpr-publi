import { describe, expect, it } from "vitest";
import { parseDbtCommand } from "../engine";
import type { RawQueryResult } from "../engine";
import { createTutorialFiles, filesForLesson, initialProjectFiles } from "./project";
import {
  DEFAULT_CUSTOMER_STEP_ID,
  DEFAULT_LESSON_ID,
  LESSONS,
  getLessonSpec,
  invocationIncludesLessonResources,
  invocationIncludesRequiredResources,
  lessonIdFromSearch,
  tutorialLocationFromSearch,
} from "./lessons";

function proofResult(columns: string[], row: unknown[]): RawQueryResult {
  return {
    columns: columns.map((name) => ({ name, type: "VARCHAR" })),
    rows: [row],
  };
}

const invoiceProof = proofResult(
  ["invoice_id", "service_id", "quarantine_reason", "accepted_rows"],
  ["INV-0105", "SVC-7777-A", "SERVICE_NOT_FOUND", 0],
);

const customerProofs = {
  staging: proofResult(
    [
      "customer_change_id",
      "customer_id",
      "customer_ssn",
      "email",
      "customer_segment",
      "is_active",
      "source_operation",
      "staged_change_count",
    ],
    [
      "CCHG-0001-U",
      "CUST-0001",
      "900-00-0001",
      "customer01@example.invalid",
      "small_business",
      true,
      "UPSERT",
      19,
    ],
  ),
  current: proofResult(
    [
      "customer_change_id",
      "customer_id",
      "customer_ssn",
      "email",
      "customer_segment",
      "is_active",
      "current_customer_count",
      "terminal_deleted_rows",
    ],
    [
      "CCHG-0001-U",
      "CUST-0001",
      "900-00-0001",
      "customer01@example.invalid",
      "small_business",
      true,
      14,
      0,
    ],
  ),
  mapping: proofResult(
    [
      "customer_id_value",
      "customer_key",
      "email_key",
      "customer_segment",
      "keys_differ",
      "mapped_customer_count",
    ],
    [
      "CUST-0001",
      "demo-v1:825c0ec1125ce7f0b50d3ad4013f02ac42d0565d8cc4a202b3a0ab5f1ee0f3c8",
      "demo-v1:a84a4bc9c4f38a8e1a06248ed3499d7ce505d09dbc745275d3226d021ef03853",
      "small_business",
      true,
      14,
    ],
  ),
  layer2: proofResult(
    [
      "customer_key",
      "email_key",
      "customer_segment",
      "is_active",
      "protected_customer_count",
      "protected_column_count",
      "protected_schema_violations",
    ],
    [
      "demo-v1:825c0ec1125ce7f0b50d3ad4013f02ac42d0565d8cc4a202b3a0ab5f1ee0f3c8",
      "demo-v1:a84a4bc9c4f38a8e1a06248ed3499d7ce505d09dbc745275d3226d021ef03853",
      "small_business",
      true,
      14,
      13,
      0,
    ],
  ),
  layer3: proofResult(
    [
      "customer_key",
      "email_key",
      "customer_segment",
      "is_active",
      "layer2_row_preserved",
      "dimension_customer_count",
    ],
    [
      "demo-v1:825c0ec1125ce7f0b50d3ad4013f02ac42d0565d8cc4a202b3a0ab5f1ee0f3c8",
      "demo-v1:a84a4bc9c4f38a8e1a06248ed3499d7ce505d09dbc745275d3226d021ef03853",
      "small_business",
      true,
      true,
      14,
    ],
  ),
} satisfies Record<string, RawQueryResult>;

const customerStepCases = [
  {
    id: "staging",
    command: [
      "build",
      "--select",
      "+stg_customer",
      "--indirect-selection",
      "cautious",
    ],
    proof: customerProofs.staging,
    weakenedColumn: "staged_change_count",
    weakenedValue: 18,
  },
  {
    id: "current",
    command: [
      "build",
      "--select",
      "+int_current_customers",
      "--indirect-selection",
      "cautious",
    ],
    proof: customerProofs.current,
    weakenedColumn: "terminal_deleted_rows",
    weakenedValue: 1,
  },
  {
    id: "mapping",
    command: [
      "build",
      "--select",
      "+demo_customer_map",
      "--indirect-selection",
      "cautious",
    ],
    proof: customerProofs.mapping,
    weakenedColumn: "keys_differ",
    weakenedValue: false,
  },
  {
    id: "layer2",
    command: [
      "build",
      "--select",
      "+int_customer_protected",
      "--indirect-selection",
      "cautious",
    ],
    proof: customerProofs.layer2,
    weakenedColumn: "protected_schema_violations",
    weakenedValue: 1,
  },
  {
    id: "layer3",
    command: [
      "build",
      "--select",
      "+dim_customer",
      "--indirect-selection",
      "cautious",
    ],
    proof: customerProofs.layer3,
    weakenedColumn: "layer2_row_preserved",
    weakenedValue: false,
  },
] as const;

describe("lesson specifications", () => {
  it("defines two uniquely numbered lessons whose visible files exist", () => {
    expect(LESSONS.map((lesson) => lesson.id)).toEqual([
      "invoice-quarantine",
      "customer-flow",
    ]);
    expect(new Set(LESSONS.map((lesson) => lesson.number)).size).toBe(LESSONS.length);

    for (const lesson of LESSONS) {
      expect(lesson.filePaths.length).toBeGreaterThan(0);
      for (const path of lesson.filePaths) {
        expect(initialProjectFiles[path]).toEqual(expect.any(String));
      }
    }

    expect(createTutorialFiles().map((file) => file.path)).toEqual(
      expect.arrayContaining(LESSONS.flatMap((lesson) => [...lesson.filePaths])),
    );
  });

  it("keeps the invoice command and all five customer commands inside the controlled parser", () => {
    expect(parseDbtCommand(getLessonSpec("invoice-quarantine").command)).toEqual([
      "build",
      "--select",
      "+assert_invoice_partition",
      "--indirect-selection",
      "cautious",
    ]);

    const customerLesson = getLessonSpec("customer-flow");
    expect(customerLesson.steps?.map((step) => step.id)).toEqual(
      customerStepCases.map(({ id }) => id),
    );
    for (const testCase of customerStepCases) {
      const step = customerLesson.steps?.find(({ id }) => id === testCase.id);
      expect(step, `missing customer step ${testCase.id}`).toBeDefined();
      expect(parseDbtCommand(step!.command)).toEqual(testCase.command);
    }
  });

  it("normalizes lesson and step query parameters for defaults and deep links", () => {
    expect(tutorialLocationFromSearch("")).toEqual({
      lessonId: DEFAULT_LESSON_ID,
      stepId: null,
    });
    expect(tutorialLocationFromSearch("?lesson=invalid&step=layer3")).toEqual({
      lessonId: DEFAULT_LESSON_ID,
      stepId: null,
    });
    expect(tutorialLocationFromSearch("?lesson=invoice-quarantine&step=staging")).toEqual({
      lessonId: "invoice-quarantine",
      stepId: null,
    });
    expect(tutorialLocationFromSearch("?lesson=customer-flow")).toEqual({
      lessonId: "customer-flow",
      stepId: DEFAULT_CUSTOMER_STEP_ID,
    });
    expect(tutorialLocationFromSearch("?lesson=customer-flow&step=invalid")).toEqual({
      lessonId: "customer-flow",
      stepId: DEFAULT_CUSTOMER_STEP_ID,
    });
    for (const { id } of customerStepCases) {
      expect(tutorialLocationFromSearch(`?lesson=customer-flow&step=${id}`)).toEqual({
        lessonId: "customer-flow",
        stepId: id,
      });
    }

    expect(lessonIdFromSearch("?lesson=customer-flow&step=layer3")).toBe("customer-flow");
    expect(lessonIdFromSearch("?lesson=invalid")).toBe(DEFAULT_LESSON_ID);
  });

  it("grades the invoice proof by column contract rather than incidental order", () => {
    const lesson = getLessonSpec("invoice-quarantine");
    expect(lesson.proof.validate(invoiceProof)).toBe(true);
    expect(
      lesson.proof.validate({
        ...invoiceProof,
        rows: [["INV-0105", "SVC-7777-A", "ACCEPTED", 1]],
      }),
    ).toBe(false);
    expect(lesson.proof.validate({ ...invoiceProof, rows: [] })).toBe(false);
  });

  it.each(customerStepCases)(
    "grades the $id proof and rejects its weakened checkpoint",
    ({ id, proof, weakenedColumn, weakenedValue }) => {
      const lesson = getLessonSpec("customer-flow");
      const step = lesson.steps?.find((candidate) => candidate.id === id);
      expect(step, `missing customer step ${id}`).toBeDefined();
      expect(step!.proof.validate(proof)).toBe(true);

      const weakened = structuredClone(proof);
      const weakenedIndex = weakened.columns.findIndex(
        (column) => column.name === weakenedColumn,
      );
      expect(weakenedIndex).toBeGreaterThanOrEqual(0);
      weakened.rows[0]![weakenedIndex] = weakenedValue;
      expect(step!.proof.validate(weakened)).toBe(false);
      expect(step!.proof.validate({ ...proof, rows: [] })).toBe(false);
      expect(step!.proof.validate({ ...proof, rows: [...proof.rows, ...proof.rows] })).toBe(false);
    },
  );

  it.each(customerStepCases)("requires every successful resource for $id", ({ id }) => {
    const lesson = getLessonSpec("customer-flow");
    const step = lesson.steps?.find((candidate) => candidate.id === id);
    expect(step, `missing customer step ${id}`).toBeDefined();
    const complete = step!.requiredSuccessfulResources.map((resource, index) => ({
      uniqueId: `${index % 2 === 0 ? "model" : "test"}.tutorial.${resource}`,
      status: index % 2 === 0 ? "success" : "pass",
    }));

    expect(invocationIncludesRequiredResources(step!.requiredSuccessfulResources, complete)).toBe(
      true,
    );
    for (const [index, resource] of step!.requiredSuccessfulResources.entries()) {
      expect(
        invocationIncludesRequiredResources(
          step!.requiredSuccessfulResources,
          complete.filter((_, resultIndex) => resultIndex !== index),
        ),
        `${id} should require ${resource}`,
      ).toBe(false);
    }
    expect(
      invocationIncludesRequiredResources(
        step!.requiredSuccessfulResources,
        complete.map((result, index) =>
          index === complete.length - 1 ? { ...result, status: "error" } : result,
        ),
      ),
    ).toBe(false);
  });

  it("keeps the lesson-level resource gate aligned with the final customer checkpoint", () => {
    const lesson = getLessonSpec("customer-flow");
    const complete = lesson.requiredSuccessfulResources.map((resource) => ({
      uniqueId: `test.tutorial.${resource}`,
      status: "pass",
    }));
    expect(invocationIncludesLessonResources(lesson, complete)).toBe(true);
    expect(invocationIncludesLessonResources(lesson, complete.slice(0, -1))).toBe(false);
  });

  it("reveals customer SQL cumulatively from staging through Layer3", () => {
    const lesson = getLessonSpec("customer-flow");
    const files = createTutorialFiles();
    const expectedPaths = new Set<string>();

    for (const step of lesson.steps ?? []) {
      step.revealFilePaths.forEach((path) => expectedPaths.add(path));
      expect(filesForLesson(files, lesson.id, step.id).map((file) => file.path)).toEqual(
        expect.arrayContaining([...expectedPaths]),
      );
      expect(filesForLesson(files, lesson.id, step.id)).toHaveLength(expectedPaths.size);
      expect(expectedPaths).toContain(step.focusFilePath);
    }

    expect(expectedPaths).toEqual(new Set(lesson.filePaths));
  });
});
