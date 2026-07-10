import { describe, expect, it } from "vitest";
import { parseDbtCommand } from "../engine";
import type { RawQueryResult } from "../engine";
import { createTutorialFiles, initialProjectFiles } from "./project";
import {
  DEFAULT_LESSON_ID,
  LESSONS,
  getLessonSpec,
  invocationIncludesLessonResources,
  lessonIdFromSearch,
} from "./lessons";

const invoiceProof: RawQueryResult = {
  columns: [
    { name: "invoice_id", type: "VARCHAR" },
    { name: "service_id", type: "VARCHAR" },
    { name: "quarantine_reason", type: "VARCHAR" },
    { name: "accepted_rows", type: "BIGINT" },
  ],
  rows: [["INV-0105", "SVC-7777-A", "SERVICE_NOT_FOUND", 0]],
};

const customerProof: RawQueryResult = {
  columns: [
    { name: "customer_id", type: "VARCHAR" },
    { name: "source_ssn", type: "VARCHAR" },
    { name: "source_email", type: "VARCHAR" },
    { name: "customer_key", type: "VARCHAR" },
    { name: "email_key", type: "VARCHAR" },
    { name: "customer_segment", type: "VARCHAR" },
    { name: "is_active", type: "BOOLEAN" },
    { name: "key_preserved", type: "BOOLEAN" },
    { name: "keys_differ", type: "BOOLEAN" },
    { name: "protected_schema_violations", type: "BIGINT" },
  ],
  rows: [
    [
      "CUST-0001",
      "900-00-0001",
      "customer01@example.invalid",
      "demo-v1:825c0ec1125ce7f0b50d3ad4013f02ac42d0565d8cc4a202b3a0ab5f1ee0f3c8",
      "demo-v1:a84a4bc9c4f38a8e1a06248ed3499d7ce505d09dbc745275d3226d021ef03853",
      "small_business",
      true,
      true,
      true,
      0,
    ],
  ],
};

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

  it("keeps both lesson commands inside the controlled parser", () => {
    expect(parseDbtCommand(getLessonSpec("invoice-quarantine").command)).toEqual([
      "build",
      "--select",
      "+assert_invoice_partition",
      "--indirect-selection",
      "cautious",
    ]);
    expect(parseDbtCommand(getLessonSpec("customer-flow").command)).toEqual([
      "build",
      "--select",
      "+assert_customer_flow_fixture",
      "--indirect-selection",
      "cautious",
    ]);
  });

  it("falls invalid and absent query parameters back to the invoice lesson", () => {
    expect(lessonIdFromSearch("?lesson=customer-flow")).toBe("customer-flow");
    expect(lessonIdFromSearch("?lesson=invalid")).toBe(DEFAULT_LESSON_ID);
    expect(lessonIdFromSearch("")).toBe(DEFAULT_LESSON_ID);
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

  it("grades all ten customer-flow fields and rejects a weakened proof", () => {
    const lesson = getLessonSpec("customer-flow");
    expect(lesson.proof.validate(customerProof)).toBe(true);

    const weakened = structuredClone(customerProof);
    weakened.rows[0][8] = false;
    expect(lesson.proof.validate(weakened)).toBe(false);
    const schemaMismatch = structuredClone(customerProof);
    schemaMismatch.rows[0][9] = 1;
    expect(lesson.proof.validate(schemaMismatch)).toBe(false);
    expect(lesson.proof.validate({ ...customerProof, rows: [] })).toBe(false);
  });

  it("requires successful resources from the current invocation", () => {
    const lesson = getLessonSpec("customer-flow");
    const complete = lesson.requiredSuccessfulResources.map((resource) => ({
      uniqueId: `model.tutorial.${resource}`,
      status: "success",
    }));
    expect(invocationIncludesLessonResources(lesson, complete)).toBe(true);
    expect(invocationIncludesLessonResources(lesson, complete.slice(1))).toBe(false);
    expect(invocationIncludesLessonResources(lesson, complete.slice(0, -1))).toBe(false);
    expect(
      invocationIncludesLessonResources(lesson, [
        ...complete.slice(0, -1),
        { uniqueId: "model.tutorial.dim_customer", status: "error" },
      ]),
    ).toBe(false);
  });
});
