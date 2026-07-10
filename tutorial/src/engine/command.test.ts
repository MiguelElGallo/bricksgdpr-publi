import { describe, expect, it } from "vitest";
import { parseDbtCommand } from "./command";

describe("parseDbtCommand", () => {
  it("accepts the phase-one build command", () => {
    expect(parseDbtCommand("dbt build --select +quarantine_invoices")).toEqual([
      "build",
      "--select",
      "+quarantine_invoices",
    ]);
  });

  it("rejects commands outside the controlled dbt surface", () => {
    expect(() => parseDbtCommand("dbt run-operation unsafe_macro")).toThrow(
      "Allowed commands",
    );
    expect(() => parseDbtCommand("dbt build; curl example.invalid")).toThrow(
      "Allowed commands",
    );
  });
});
