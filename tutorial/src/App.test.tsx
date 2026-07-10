import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const engineMock = vi.hoisted(() => ({
  boot: vi.fn(),
  invoke: vi.fn(),
  catalog: vi.fn(),
  query: vi.fn(),
  terminate: vi.fn(),
  options: [] as Array<{
    onLog: (line: string, stream: "out" | "err") => void;
    onStatus: (phase: string, detail?: string) => void;
  }>,
}));

vi.mock("./engine", async (importOriginal) => {
  const original = await importOriginal<typeof import("./engine")>();

  class MockBrowserDbtEngine {
    constructor(options: (typeof engineMock.options)[number]) {
      engineMock.options.push(options);
    }

    boot() {
      return engineMock.boot();
    }

    invoke(args: string[], files: Record<string, string>) {
      return engineMock.invoke(args, files);
    }

    catalog() {
      return engineMock.catalog();
    }

    query(sql: string) {
      return engineMock.query(sql);
    }

    terminate() {
      engineMock.terminate();
    }
  }

  return { ...original, BrowserDbtEngine: MockBrowserDbtEngine };
});

import App from "./App";

const runtimeInfo = {
  pyodideVersion: "0.27.7",
  pythonVersion: "3.12.7",
  dbtVersion: "1.10.8",
  duckdbVersion: "1.1.2",
};

const invoiceInvocation = {
  success: true,
  exception: null,
  results: [
    { uniqueId: "model.tutorial.int_invoices_resolved", status: "success" },
    { uniqueId: "model.tutorial.quarantine_invoices", status: "success" },
    { uniqueId: "test.tutorial.assert_invoice_partition", status: "pass" },
  ],
  nodes: [],
  artifacts: ["manifest.json", "run_results.json"],
};

const customerInvocation = {
  ...invoiceInvocation,
  results: [
    { uniqueId: "model.tutorial.demo_customer_map", status: "success" },
    { uniqueId: "model.tutorial.int_customer_protected", status: "success" },
    { uniqueId: "model.tutorial.dim_customer", status: "success" },
    { uniqueId: "test.tutorial.assert_customer_flow_fixture", status: "pass" },
  ],
};

const combinedCatalog = [
  {
    schema: "main",
    name: "quarantine_invoices",
    tableType: "BASE TABLE",
    rowCount: 11,
    columns: [{ name: "invoice_id", type: "VARCHAR", nullable: false }],
  },
  {
    schema: "main",
    name: "int_invoices_resolved",
    tableType: "BASE TABLE",
    rowCount: 25,
    columns: [{ name: "invoice_id", type: "VARCHAR", nullable: false }],
  },
  {
    schema: "main",
    name: "demo_customer_map",
    tableType: "BASE TABLE",
    rowCount: 14,
    columns: [{ name: "customer_key", type: "VARCHAR", nullable: false }],
  },
  {
    schema: "main",
    name: "int_customer_protected",
    tableType: "BASE TABLE",
    rowCount: 14,
    columns: [{ name: "customer_key", type: "VARCHAR", nullable: false }],
  },
  {
    schema: "main",
    name: "dim_customer",
    tableType: "BASE TABLE",
    rowCount: 14,
    columns: [{ name: "customer_key", type: "VARCHAR", nullable: false }],
  },
];

const invoiceProofResult = {
  columns: [
    { name: "invoice_id", type: "VARCHAR" },
    { name: "service_id", type: "VARCHAR" },
    { name: "quarantine_reason", type: "VARCHAR" },
    { name: "accepted_rows", type: "BIGINT" },
  ],
  rows: [["INV-0105", "SVC-7777-A", "SERVICE_NOT_FOUND", 0]],
};

const customerProofResult = {
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

beforeEach(() => {
  window.history.replaceState(null, "", "/?lesson=invoice-quarantine");
  engineMock.boot.mockReset().mockResolvedValue(runtimeInfo);
  engineMock.invoke.mockReset().mockResolvedValue(invoiceInvocation);
  engineMock.catalog.mockReset().mockResolvedValue(combinedCatalog);
  engineMock.query.mockReset().mockResolvedValue(invoiceProofResult);
  engineMock.terminate.mockReset();
  engineMock.options.length = 0;
});

async function bootAndBuild() {
  fireEvent.click(screen.getByRole("button", { name: "Boot engine" }));
  await waitFor(() => expect(screen.getByRole("button", { name: "Run lesson" })).toBeEnabled());
  fireEvent.click(screen.getByRole("button", { name: "Run lesson" }));
  await waitFor(() =>
    expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
      "aria-valuenow",
      "100",
    ),
  );
}

function selectLesson(lessonId: "invoice-quarantine" | "customer-flow") {
  fireEvent.change(screen.getByRole("combobox", { name: "Choose lesson" }), {
    target: { value: lessonId },
  });
}

describe("App engine integration", () => {
  it("falls back from an invalid deep link and opens a valid customer deep link", async () => {
    window.history.replaceState(null, "", "/?lesson=not-a-lesson");
    const first = render(<App />);

    expect(
      screen.getByRole("heading", { name: "Trace an invoice into quarantine" }),
    ).toBeVisible();
    await waitFor(() =>
      expect(new URL(window.location.href).searchParams.get("lesson")).toBe("invoice-quarantine"),
    );

    first.unmount();
    window.history.replaceState(null, "", "/?lesson=customer-flow");
    render(<App />);
    expect(
      screen.getByRole("heading", { name: "Follow a customer through protected layers" }),
    ).toBeVisible();
    expect(screen.getByRole("tab", { name: /demo_personal_data_key\.sql/ })).toBeVisible();
    expect(screen.queryByRole("tab", { name: /quarantine_invoices\.sql/ })).not.toBeInTheDocument();
  });

  it("lets reset terminate boot and ignores callbacks from the old engine", async () => {
    let resolveBoot!: (value: typeof runtimeInfo) => void;
    engineMock.boot.mockReturnValueOnce(
      new Promise((resolve) => {
        resolveBoot = resolve;
      }),
    );
    render(<App />);

    fireEvent.click(screen.getByRole("button", { name: "Boot engine" }));
    const reset = screen.getByRole("button", { name: "Reset lab" });
    expect(reset).toBeEnabled();
    fireEvent.click(reset);

    engineMock.options[0].onStatus("loading-packages", "Stale status");
    engineMock.options[0].onLog("Stale log", "out");
    await act(async () => {
      resolveBoot(runtimeInfo);
      await Promise.resolve();
    });

    expect(engineMock.terminate).toHaveBeenCalledOnce();
    expect(screen.getByText("Engine offline")).toBeVisible();
    expect(screen.queryByText("Stale status")).not.toBeInTheDocument();
    expect(screen.queryByText("Stale log")).not.toBeInTheDocument();
  });

  it("shares one booted engine while preserving lesson progress, results, and relation scope", async () => {
    render(<App />);
    await bootAndBuild();
    expect(screen.getByText("SERVICE_NOT_FOUND", { selector: "td" })).toBeVisible();

    selectLesson("customer-flow");
    expect(engineMock.options).toHaveLength(1);
    expect(engineMock.terminate).not.toHaveBeenCalled();
    expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
      "aria-valuenow",
      "20",
    );
    expect(screen.queryByText("SERVICE_NOT_FOUND", { selector: "td" })).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("tab", { name: /Database/ }));
    expect(screen.getByRole("button", { name: /dim_customer/ })).toBeVisible();
    expect(screen.queryByRole("button", { name: /quarantine_invoices/ })).not.toBeInTheDocument();

    selectLesson("invoice-quarantine");
    expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
      "aria-valuenow",
      "100",
    );
    expect(screen.getByText("SERVICE_NOT_FOUND", { selector: "td" })).toBeVisible();
  });

  it("keeps a late relation query attached to the lesson that started it", async () => {
    render(<App />);
    await bootAndBuild();

    let resolveRelation!: (value: typeof invoiceProofResult) => void;
    engineMock.query.mockReturnValueOnce(
      new Promise((resolve) => {
        resolveRelation = resolve;
      }),
    );
    fireEvent.click(screen.getByRole("tab", { name: /Database/ }));
    fireEvent.click(screen.getByRole("button", { name: /quarantine_invoices/ }));
    selectLesson("customer-flow");

    await act(async () => {
      resolveRelation({
        columns: [{ name: "invoice_id", type: "VARCHAR" }],
        rows: [["LATE-INVOICE-RESULT"]],
      } as typeof invoiceProofResult);
      await Promise.resolve();
    });
    expect(screen.queryByText("LATE-INVOICE-RESULT")).not.toBeInTheDocument();

    selectLesson("invoice-quarantine");
    expect(await screen.findByText("LATE-INVOICE-RESULT", { selector: "td" })).toBeVisible();
  });

  it("resets every session while retaining the selected lesson", async () => {
    window.history.replaceState(null, "", "/?lesson=customer-flow");
    render(<App />);
    fireEvent.click(screen.getByRole("button", { name: "Boot engine" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "Run lesson" })).toBeEnabled());

    fireEvent.change(screen.getByLabelText("Edit models/stg_customer.sql"), {
      target: { value: "select from" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Reset lab" }));

    expect(screen.getByRole("combobox", { name: "Choose lesson" })).toHaveValue("customer-flow");
    expect(
      screen.getByRole("heading", { name: "Follow a customer through protected layers" }),
    ).toBeVisible();
    expect(screen.getByLabelText("Edit models/stg_customer.sql")).not.toHaveValue("select from");
    expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
      "aria-valuenow",
      "0",
    );
    expect(screen.getByText("Engine offline")).toBeVisible();
  });

  it("runs and grades the exact customer lesson contract", async () => {
    window.history.replaceState(null, "", "/?lesson=customer-flow");
    engineMock.invoke.mockResolvedValue(customerInvocation);
    engineMock.query.mockResolvedValue(customerProofResult);
    render(<App />);

    await bootAndBuild();

    expect(engineMock.invoke).toHaveBeenCalledWith(
      [
        "build",
        "--select",
        "+assert_customer_flow_fixture",
        "--indirect-selection",
        "cautious",
      ],
      expect.objectContaining({
        "models/demo_customer_map.sql": expect.any(String),
        "models/dim_customer.sql": expect.any(String),
      }),
    );
    expect(engineMock.query.mock.calls[0][0]).toContain("from main.stg_customer as source");
    expect(engineMock.query.mock.calls[0][0]).toContain("main.demo_customer_map");
    expect(
      screen.getByText(
        "demo-v1:825c0ec1125ce7f0b50d3ad4013f02ac42d0565d8cc4a202b3a0ab5f1ee0f3c8",
        { selector: "td" },
      ),
    ).toBeVisible();
    expect(screen.getByText(/Lesson complete: CUST-0001 reaches Layer3/)).toBeVisible();
  });

  it("locks lesson navigation while the shared engine is busy", async () => {
    let resolveBoot!: (value: typeof runtimeInfo) => void;
    engineMock.boot.mockReturnValueOnce(
      new Promise((resolve) => {
        resolveBoot = resolve;
      }),
    );
    render(<App />);

    fireEvent.click(screen.getByRole("button", { name: "Boot engine" }));
    expect(screen.getByRole("combobox", { name: "Choose lesson" })).toBeDisabled();
    fireEvent.change(screen.getByRole("combobox", { name: "Choose lesson" }), {
      target: { value: "customer-flow" },
    });
    expect(screen.getByRole("combobox", { name: "Choose lesson" })).toHaveValue(
      "invoice-quarantine",
    );

    await act(async () => {
      resolveBoot(runtimeInfo);
      await Promise.resolve();
    });
    expect(screen.getByRole("combobox", { name: "Choose lesson" })).toBeEnabled();
  });

  it("invalidates both lesson proofs after a shared project edit", async () => {
    render(<App />);
    await bootAndBuild();

    selectLesson("customer-flow");
    engineMock.invoke.mockResolvedValueOnce(customerInvocation);
    engineMock.query.mockResolvedValueOnce(customerProofResult);
    fireEvent.click(screen.getByRole("button", { name: "Run lesson" }));
    await waitFor(() =>
      expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
        "aria-valuenow",
        "100",
      ),
    );

    fireEvent.change(screen.getByLabelText("Edit models/stg_customer.sql"), {
      target: { value: "select from" },
    });
    expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
      "aria-valuenow",
      "20",
    );
    expect(screen.getByText("No query result yet")).toBeVisible();

    selectLesson("invoice-quarantine");
    expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
      "aria-valuenow",
      "20",
    );
    expect(screen.getByText("No query result yet")).toBeVisible();
  });

  it("keeps a completed proof invalid after an edit and failed rebuild", async () => {
    render(<App />);
    await bootAndBuild();

    fireEvent.change(screen.getByLabelText("Edit models/stg_invoices.sql"), {
      target: { value: "select from" },
    });
    expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
      "aria-valuenow",
      "20",
    );

    engineMock.invoke.mockResolvedValueOnce({
      ...invoiceInvocation,
      success: false,
      exception: "broken model",
    });
    fireEvent.click(screen.getByRole("button", { name: "Run lesson" }));
    await waitFor(() => expect(screen.getByText("broken model")).toBeVisible());
    expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
      "aria-valuenow",
      "20",
    );
    expect(screen.getByText("No query result yet")).toBeVisible();
  });

  it("does not grade dbt run against stale catalog relations or model-only success", async () => {
    render(<App />);
    await bootAndBuild();
    expect(engineMock.query).toHaveBeenCalledOnce();

    engineMock.invoke.mockResolvedValueOnce({
      ...invoiceInvocation,
      results: invoiceInvocation.results.filter((result) => !result.uniqueId.includes("test.")),
    });
    fireEvent.change(screen.getByLabelText("Enter a dbt command"), {
      target: { value: "dbt run --select stg_invoices" },
    });
    fireEvent.click(screen.getByRole("button", { name: /^Run$/ }));

    await waitFor(() => expect(screen.getByText(/did not execute the lesson test/)).toBeVisible());
    expect(engineMock.query).toHaveBeenCalledOnce();
    expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
      "aria-valuenow",
      "20",
    );
    expect(screen.getByText("No query result yet")).toBeVisible();
  });

  it("does not grade dbt build when the lesson test is absent from the invocation", async () => {
    render(<App />);
    fireEvent.click(screen.getByRole("button", { name: "Boot engine" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "Run lesson" })).toBeEnabled());
    engineMock.invoke.mockResolvedValueOnce({
      ...invoiceInvocation,
      results: invoiceInvocation.results.filter((result) => !result.uniqueId.includes("test.")),
    });

    fireEvent.click(screen.getByRole("button", { name: "Run lesson" }));

    await waitFor(() =>
      expect(screen.getByText(/did not rebuild every required resource/)).toBeVisible(),
    );
    expect(engineMock.query).not.toHaveBeenCalled();
    expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
      "aria-valuenow",
      "20",
    );
  });
});
