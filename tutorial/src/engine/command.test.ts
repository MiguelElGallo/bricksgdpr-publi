import { describe, expect, it } from "vitest";
import { parseDbtCommand } from "./command";

describe("parseDbtCommand", () => {
  it.each(["0", "-1", "1.5", "9007199254740992"])("rejects invalid row limit %s", (limit) => {
    expect(() => parseDbtCommand(`dbt show --limit ${limit}`)).toThrow();
  });

  it("does not consume a short flag as another flag's value", () => {
    expect(() => parseDbtCommand("dbt build --select -s model")).toThrow("requires a value");
  });

  it("accepts the invoice lesson's cautious indirect selection", () => {
    expect(
      parseDbtCommand(
        "dbt build --select +assert_invoice_partition --indirect-selection cautious",
      ),
    ).toEqual([
      "build",
      "--select",
      "+assert_invoice_partition",
      "--indirect-selection",
      "cautious",
    ]);
  });

  it("accepts the customer lesson's cautious indirect selection", () => {
    expect(
      parseDbtCommand(
        "dbt build --select +assert_customer_flow_fixture --indirect-selection cautious",
      ),
    ).toEqual([
      "build",
      "--select",
      "+assert_customer_flow_fixture",
      "--indirect-selection",
      "cautious",
    ]);
  });

  it("rejects commands outside the controlled dbt surface", () => {
    expect(() => parseDbtCommand("dbt run-operation unsafe_macro")).toThrow(
      "Allowed commands",
    );
    expect(() => parseDbtCommand("dbt build; curl example.invalid")).toThrow(
      "Allowed commands",
    );
    expect(() =>
      parseDbtCommand("dbt build --indirect-selection eager"),
    ).toThrow("must be cautious");
  });
});
