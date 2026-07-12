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
import { getLessonSpec } from "./lesson/lessons";

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
    { uniqueId: "model.bricksgdpr_tutorial.int_invoices_resolved", status: "success" },
    { uniqueId: "model.bricksgdpr_tutorial.quarantine_invoices", status: "success" },
    { uniqueId: "test.bricksgdpr_tutorial.assert_invoice_partition", status: "pass" },
  ],
  nodes: [],
  artifacts: ["manifest.json", "run_results.json"],
};

const customerStepIds = ["staging", "current", "mapping", "layer2", "layer3"] as const;
type CustomerStepId = (typeof customerStepIds)[number];

const customerStepTitles: Record<CustomerStepId, string> = {
  staging: "Start with the staged change",
  current: "Reduce the feed to current customers",
  mapping: "Create domain-separated demo keys",
  layer2: "Cross into protected Layer2",
  layer3: "Publish the protected Layer3 dimension",
};

const customerStepCommands: Record<CustomerStepId, string[]> = {
  staging: ["build", "--select", "+stg_customer", "--indirect-selection", "cautious"],
  current: ["build", "--select", "+int_current_customers", "--indirect-selection", "cautious"],
  mapping: ["build", "--select", "+demo_customer_map", "--indirect-selection", "cautious"],
  layer2: [
    "build",
    "--select",
    "+int_customer_protected",
    "--indirect-selection",
    "cautious",
  ],
  layer3: ["build", "--select", "+dim_customer", "--indirect-selection", "cautious"],
};

const customerRequiredResources: Record<CustomerStepId, string[]> = {
  staging: ["model.bricksgdpr_tutorial.stg_customer"],
  current: [
    "model.bricksgdpr_tutorial.int_current_customers",
    "test.bricksgdpr_tutorial.assert_current_customers_terminal_deletion",
    "test.bricksgdpr_tutorial.assert_deletion_confirmation_gate",
  ],
  mapping: [
    "model.bricksgdpr_tutorial.demo_customer_map",
    "test.bricksgdpr_tutorial.assert_demo_customer_key_contract",
  ],
  layer2: [
    "model.bricksgdpr_tutorial.int_customer_protected",
    "test.bricksgdpr_tutorial.assert_customer_map_projection",
    "test.bricksgdpr_tutorial.assert_customer_protected_schema",
  ],
  layer3: [
    "model.bricksgdpr_tutorial.dim_customer",
    "test.bricksgdpr_tutorial.assert_customer_dimension_integrity",
    "test.bricksgdpr_tutorial.assert_customer_flow_fixture",
  ],
};

const customerInvocations = Object.fromEntries(
  customerStepIds.map((stepId) => [
    stepId,
    {
      success: true,
      exception: null,
      results: customerRequiredResources[stepId].map((uniqueId) => ({
        uniqueId,
        status: uniqueId.startsWith("test.") ? "pass" : "success",
      })),
      nodes: [],
      artifacts: ["manifest.json", "run_results.json"],
    },
  ]),
) as Record<CustomerStepId, typeof invoiceInvocation>;

const CUSTOMER_KEY =
  "demo-v1:825c0ec1125ce7f0b50d3ad4013f02ac42d0565d8cc4a202b3a0ab5f1ee0f3c8";
const CUSTOMER_EMAIL_KEY =
  "demo-v1:a84a4bc9c4f38a8e1a06248ed3499d7ce505d09dbc745275d3226d021ef03853";

const customerProofResults = {
  staging: {
    columns: [
      { name: "customer_change_id", type: "VARCHAR" },
      { name: "customer_id", type: "VARCHAR" },
      { name: "customer_ssn", type: "VARCHAR" },
      { name: "email", type: "VARCHAR" },
      { name: "customer_segment", type: "VARCHAR" },
      { name: "is_active", type: "BOOLEAN" },
      { name: "source_operation", type: "VARCHAR" },
      { name: "staged_change_count", type: "BIGINT" },
    ],
    rows: [
      [
        "CCHG-0001-U",
        "CUST-0001",
        "900-00-0001",
        "customer01@example.invalid",
        "small_business",
        true,
        "UPSERT",
        21,
      ],
    ],
  },
  current: {
    columns: [
      { name: "customer_change_id", type: "VARCHAR" },
      { name: "customer_id", type: "VARCHAR" },
      { name: "customer_ssn", type: "VARCHAR" },
      { name: "email", type: "VARCHAR" },
      { name: "customer_segment", type: "VARCHAR" },
      { name: "is_active", type: "BOOLEAN" },
      { name: "current_customer_count", type: "BIGINT" },
      { name: "pending_customer_rows", type: "BIGINT" },
      { name: "authorized_deleted_rows", type: "BIGINT" },
    ],
    rows: [
      [
        "CCHG-0001-U",
        "CUST-0001",
        "900-00-0001",
        "customer01@example.invalid",
        "small_business",
        true,
        15,
        1,
        0,
      ],
    ],
  },
  mapping: {
    columns: [
      { name: "customer_id_value", type: "VARCHAR" },
      { name: "customer_key", type: "VARCHAR" },
      { name: "email_key", type: "VARCHAR" },
      { name: "customer_segment", type: "VARCHAR" },
      { name: "keys_differ", type: "BOOLEAN" },
      { name: "mapped_customer_count", type: "BIGINT" },
    ],
    rows: [["CUST-0001", CUSTOMER_KEY, CUSTOMER_EMAIL_KEY, "small_business", true, 15]],
  },
  layer2: {
    columns: [
      { name: "customer_key", type: "VARCHAR" },
      { name: "email_key", type: "VARCHAR" },
      { name: "customer_segment", type: "VARCHAR" },
      { name: "is_active", type: "BOOLEAN" },
      { name: "protected_customer_count", type: "BIGINT" },
      { name: "protected_column_count", type: "BIGINT" },
      { name: "protected_schema_violations", type: "BIGINT" },
    ],
    rows: [[CUSTOMER_KEY, CUSTOMER_EMAIL_KEY, "small_business", true, 15, 13, 0]],
  },
  layer3: {
    columns: [
      { name: "customer_key", type: "VARCHAR" },
      { name: "email_key", type: "VARCHAR" },
      { name: "customer_segment", type: "VARCHAR" },
      { name: "is_active", type: "BOOLEAN" },
      { name: "layer2_row_preserved", type: "BOOLEAN" },
      { name: "dimension_customer_count", type: "BIGINT" },
    ],
    rows: [[CUSTOMER_KEY, CUSTOMER_EMAIL_KEY, "small_business", true, true, 15]],
  },
};

const customerProofLabels: Record<CustomerStepId, string> = {
  staging: "Step 1 · staged CUST-0001",
  current: "Step 2 · current CUST-0001",
  mapping: "Step 3 · mapped CUST-0001",
  layer2: "Step 4 · protected CUST-0001",
  layer3: "Step 5 · Layer3 CUST-0001",
};

const combinedCatalog = [
  {
    schema: "main",
    name: "customer",
    tableType: "BASE TABLE",
    rowCount: 21,
    columns: [{ name: "customer_id", type: "VARCHAR", nullable: false }],
  },
  {
    schema: "main",
    name: "stg_customer",
    tableType: "BASE TABLE",
    rowCount: 21,
    columns: [{ name: "customer_id", type: "VARCHAR", nullable: false }],
  },
  {
    schema: "main",
    name: "int_current_customers",
    tableType: "VIEW",
    rowCount: 15,
    columns: [{ name: "customer_id", type: "VARCHAR", nullable: false }],
  },
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
    rowCount: 15,
    columns: [{ name: "customer_key", type: "VARCHAR", nullable: false }],
  },
  {
    schema: "main",
    name: "int_customer_protected",
    tableType: "BASE TABLE",
    rowCount: 15,
    columns: [{ name: "customer_key", type: "VARCHAR", nullable: false }],
  },
  {
    schema: "main",
    name: "dim_customer",
    tableType: "BASE TABLE",
    rowCount: 15,
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

beforeEach(() => {
  window.history.replaceState(null, "", "/?lesson=invoice-quarantine");
  engineMock.boot.mockReset().mockResolvedValue(runtimeInfo);
  engineMock.invoke.mockReset().mockResolvedValue(invoiceInvocation);
  engineMock.catalog.mockReset().mockResolvedValue(combinedCatalog);
  engineMock.query.mockReset().mockResolvedValue(invoiceProofResult);
  engineMock.terminate.mockReset();
  engineMock.options.length = 0;
});

function progressBar() {
  return screen.getByRole("progressbar", { name: "Lesson progress" });
}

function customerStepButton(stepId: CustomerStepId) {
  const stepNumber = customerStepIds.indexOf(stepId) + 1;
  return screen.getByRole("button", {
    name: new RegExp(`^Step ${stepNumber} of 5: ${customerStepTitles[stepId]}\\.`),
  });
}

function customerStepSpec(stepId: CustomerStepId) {
  const step = getLessonSpec("customer-flow").steps?.find((candidate) => candidate.id === stepId);
  if (!step) throw new Error(`Missing customer tutorial step: ${stepId}`);
  return step;
}

function submitTerminalCommand(command: string) {
  fireEvent.change(screen.getByLabelText("Enter a dbt command"), {
    target: { value: command },
  });
  fireEvent.click(screen.getByRole("button", { name: /^Run$/ }));
}

function queueCustomerStep(stepId: CustomerStepId) {
  engineMock.invoke.mockResolvedValueOnce(customerInvocations[stepId]);
  engineMock.query.mockResolvedValueOnce(customerProofResults[stepId]);
}

function queueAllCustomerSteps() {
  customerStepIds.forEach(queueCustomerStep);
}

async function bootEngine() {
  fireEvent.click(screen.getByRole("button", { name: "Boot engine" }));
  await waitFor(() =>
    expect(screen.getByRole("button", { name: /Run (?:lesson|step)/ })).toBeEnabled(),
  );
}

async function runInvoiceLesson() {
  await bootEngine();
  fireEvent.click(screen.getByRole("button", { name: "Run lesson" }));
  await waitFor(() => expect(progressBar()).toHaveAttribute("aria-valuenow", "100"));
  await waitFor(() => expect(screen.getByRole("button", { name: "Run lesson" })).toBeEnabled());
}

async function runSelectedCustomerStep(expectedProgress: number) {
  fireEvent.click(screen.getByRole("button", { name: "Run step" }));
  await waitFor(() =>
    expect(progressBar()).toHaveAttribute("aria-valuenow", String(expectedProgress)),
  );
  await waitFor(() => expect(screen.getByRole("button", { name: "Run step" })).toBeEnabled());
}

function selectLesson(lessonId: "invoice-quarantine" | "customer-flow") {
  fireEvent.change(screen.getByRole("combobox", { name: "Choose lesson" }), {
    target: { value: lessonId },
  });
}

async function completeCustomerTutorial() {
  queueAllCustomerSteps();
  await bootEngine();
  for (const [index, stepId] of customerStepIds.entries()) {
    expect(customerStepButton(stepId)).toHaveAttribute("aria-current", "step");
    await runSelectedCustomerStep((index + 1) * 20);
    if (index < customerStepIds.length - 1) {
      fireEvent.click(screen.getByRole("button", { name: "Next" }));
    }
  }
}

describe("App engine integration", () => {
  it("normalizes invalid deep links and opens the customer tutorial at staging", async () => {
    window.history.replaceState(null, "", "/?lesson=not-a-lesson&step=layer3");
    const first = render(<App />);

    expect(screen.getByRole("heading", { name: "Trace an invoice into quarantine" })).toBeVisible();
    await waitFor(() => {
      const parameters = new URL(window.location.href).searchParams;
      expect(parameters.get("lesson")).toBe("invoice-quarantine");
      expect(parameters.has("step")).toBe(false);
    });

    first.unmount();
    window.history.replaceState(null, "", "/?lesson=customer-flow&step=not-a-step");
    render(<App />);
    expect(
      screen.getByRole("heading", { name: "Build a customer flow from staging to Layer3" }),
    ).toBeVisible();
    expect(customerStepButton("staging")).toHaveAttribute("aria-current", "step");
    expect(screen.getByRole("tab", { name: /stg_customer\.sql/ })).toBeVisible();
    expect(screen.queryByRole("tab", { name: /demo_personal_data_key\.sql/ })).not.toBeInTheDocument();
    await waitFor(() =>
      expect(new URL(window.location.href).searchParams.get("step")).toBe("staging"),
    );
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

  it("shares one booted engine while preserving invoice progress, proof, and relation scope", async () => {
    render(<App />);
    await runInvoiceLesson();
    expect(screen.getByText("SERVICE_NOT_FOUND", { selector: "td" })).toBeVisible();

    selectLesson("customer-flow");
    expect(engineMock.options).toHaveLength(1);
    expect(engineMock.terminate).not.toHaveBeenCalled();
    expect(progressBar()).toHaveAttribute("aria-valuenow", "0");
    expect(screen.queryByText("SERVICE_NOT_FOUND", { selector: "td" })).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("tab", { name: /Database/ }));
    expect(screen.getByRole("button", { name: /stg_customer/ })).toBeVisible();
    expect(screen.queryByRole("button", { name: /dim_customer/ })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /quarantine_invoices/ })).not.toBeInTheDocument();

    selectLesson("invoice-quarantine");
    expect(progressBar()).toHaveAttribute("aria-valuenow", "100");
    expect(screen.getByText("SERVICE_NOT_FOUND", { selector: "td" })).toBeVisible();
  });

  it("keeps a late relation query attached to the lesson that started it", async () => {
    render(<App />);
    await runInvoiceLesson();

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

  it("runs the five exact customer checkpoints and restores cached proofs with Previous and Next", async () => {
    window.history.replaceState(null, "", "/?lesson=customer-flow");
    render(<App />);

    await completeCustomerTutorial();

    expect(screen.getByText(customerProofLabels.layer3)).toBeVisible();
    expect(screen.getByText("Tutorial complete: Layer3 preserves CUST-0001's protected Layer2 contract across all five checkpoints.")).toBeVisible();
    expect(engineMock.invoke.mock.calls.map(([args]) => args)).toEqual(
      customerStepIds.map((stepId) => customerStepCommands[stepId]),
    );
    expect(
      engineMock.invoke.mock.calls.map(([, files]) =>
        Object.keys(files).filter((path) =>
          [
            "models/stg_customer.sql",
            "models/int_current_customers.sql",
            "models/demo_customer_map.sql",
            "models/int_customer_protected.sql",
            "models/dim_customer.sql",
            "tests/assert_customer_protected_schema.sql",
          ].includes(path),
        ).sort(),
      ),
    ).toEqual(
      Array.from({ length: 5 }, () => [
        "models/demo_customer_map.sql",
        "models/dim_customer.sql",
        "models/int_current_customers.sql",
        "models/int_customer_protected.sql",
        "models/stg_customer.sql",
        "tests/assert_customer_protected_schema.sql",
      ]),
    );
    const customerSteps = getLessonSpec("customer-flow").steps ?? [];
    expect(engineMock.query.mock.calls.map(([sql]) => sql)).toEqual(
      customerSteps.map((step) => step.proof.sql),
    );
    expect(customerStepIds.map((stepId) => customerInvocations[stepId].results.map((result) => result.uniqueId))).toEqual(
      customerStepIds.map((stepId) => customerRequiredResources[stepId]),
    );

    fireEvent.click(screen.getByRole("button", { name: "Previous" }));
    expect(customerStepButton("layer2")).toHaveAttribute("aria-current", "step");
    expect(screen.getByText(customerProofLabels.layer2)).toBeVisible();
    expect(screen.getByText("13", { selector: "td" })).toBeVisible();

    fireEvent.click(screen.getByRole("button", { name: "Next" }));
    expect(customerStepButton("layer3")).toHaveAttribute("aria-current", "step");
    expect(screen.getByText(customerProofLabels.layer3)).toBeVisible();
    expect(progressBar()).toHaveAttribute("aria-valuenow", "100");
  });

  it("opens a Layer3 deep link without auto-completion and grades only that later step", async () => {
    window.history.replaceState(null, "", "/?lesson=customer-flow&step=layer3");
    queueCustomerStep("layer3");
    render(<App />);

    expect(customerStepButton("layer3")).toHaveAttribute("aria-current", "step");
    expect(progressBar()).toHaveAttribute("aria-valuenow", "0");
    expect(screen.getByLabelText("Edit models/dim_customer.sql")).toBeVisible();
    await bootEngine();
    expect(progressBar()).toHaveAttribute("aria-valuenow", "0");

    await runSelectedCustomerStep(20);

    expect(engineMock.invoke).toHaveBeenCalledWith(
      customerStepCommands.layer3,
      expect.objectContaining({
        "models/int_customer_protected.sql": expect.any(String),
        "models/dim_customer.sql": expect.any(String),
      }),
    );
    expect(engineMock.query).toHaveBeenCalledWith(
      getLessonSpec("customer-flow").steps?.find((step) => step.id === "layer3")?.proof.sql,
    );
    expect(customerStepButton("layer3")).toHaveAccessibleName(/Complete$/);
    expect(customerStepButton("staging")).toHaveAccessibleName(/Current task$/);
    expect(customerStepButton("current")).toHaveAccessibleName(/Not started$/);
    expect(screen.getByText(customerProofLabels.layer3)).toBeVisible();
  });

  it("grades the exact selected Step 1 command from the terminal and preserves the invoice proof", async () => {
    render(<App />);
    await runInvoiceLesson();

    selectLesson("customer-flow");
    queueCustomerStep("staging");
    submitTerminalCommand(customerStepSpec("staging").command);

    await waitFor(() => expect(progressBar()).toHaveAttribute("aria-valuenow", "20"));
    expect(customerStepButton("staging")).toHaveAccessibleName(/Complete$/);
    expect(screen.getByText(customerProofLabels.staging)).toBeVisible();
    expect(engineMock.invoke).toHaveBeenLastCalledWith(
      customerStepCommands.staging,
      expect.any(Object),
    );
    expect(engineMock.query).toHaveBeenLastCalledWith(customerStepSpec("staging").proof.sql);

    selectLesson("invoice-quarantine");
    expect(progressBar()).toHaveAttribute("aria-valuenow", "100");
    expect(screen.getByText("SERVICE_NOT_FOUND", { selector: "td" })).toBeVisible();
  });

  it("grades the invoice lesson only when its exact command runs from the terminal", async () => {
    render(<App />);
    await bootEngine();

    submitTerminalCommand(getLessonSpec("invoice-quarantine").command);

    await waitFor(() => expect(progressBar()).toHaveAttribute("aria-valuenow", "100"));
    expect(screen.getByText("INV-0105 quarantine proof")).toBeVisible();
    expect(screen.getByText("SERVICE_NOT_FOUND", { selector: "td" })).toBeVisible();
    expect(engineMock.query).toHaveBeenCalledOnce();
  });

  it("does not grade a mismatched invoice terminal build even when resources succeed", async () => {
    render(<App />);
    await bootEngine();

    submitTerminalCommand("dbt build --select quarantine_invoices");

    await waitFor(() =>
      expect(screen.getByText(/did not match the guided command currently shown/)).toBeVisible(),
    );
    expect(progressBar()).toHaveAttribute("aria-valuenow", "20");
    expect(engineMock.query).not.toHaveBeenCalled();
  });

  it("grades only the selected later step when its exact command runs from the terminal", async () => {
    window.history.replaceState(null, "", "/?lesson=customer-flow&step=current");
    queueCustomerStep("current");
    render(<App />);
    await bootEngine();

    submitTerminalCommand(customerStepSpec("current").command);

    await waitFor(() => expect(progressBar()).toHaveAttribute("aria-valuenow", "20"));
    expect(customerStepButton("current")).toHaveAttribute("aria-current", "step");
    expect(customerStepButton("current")).toHaveAccessibleName(/Complete$/);
    expect(customerStepButton("staging")).toHaveAccessibleName(/Current task$/);
    expect(customerStepButton("mapping")).toHaveAccessibleName(/Not started$/);
    expect(screen.getByText(customerProofLabels.current)).toBeVisible();
    expect(engineMock.invoke).toHaveBeenLastCalledWith(
      customerStepCommands.current,
      expect.any(Object),
    );
    expect(engineMock.query).toHaveBeenCalledOnce();
    expect(engineMock.query).toHaveBeenCalledWith(customerStepSpec("current").proof.sql);
  });

  it("does not grade a mismatched terminal build and conservatively invalidates both lessons", async () => {
    render(<App />);
    await runInvoiceLesson();
    selectLesson("customer-flow");
    queueCustomerStep("staging");
    await runSelectedCustomerStep(20);

    engineMock.invoke.mockResolvedValueOnce(customerInvocations.staging);
    submitTerminalCommand("dbt build --select stg_customer");

    await waitFor(() =>
      expect(screen.getByText(/did not match the guided command currently shown/)).toBeVisible(),
    );
    expect(progressBar()).toHaveAttribute("aria-valuenow", "0");
    expect(screen.getByText("No query result yet")).toBeVisible();
    expect(engineMock.query).toHaveBeenCalledTimes(2);

    selectLesson("invoice-quarantine");
    expect(progressBar()).toHaveAttribute("aria-valuenow", "20");
    expect(screen.getByText("No query result yet")).toBeVisible();
  });

  it("locks guided steps and file tabs while a proof is pending and never shows it under another step", async () => {
    window.history.replaceState(null, "", "/?lesson=customer-flow&step=layer3");
    let resolveProof!: (value: (typeof customerProofResults)["layer3"]) => void;
    engineMock.invoke.mockResolvedValueOnce(customerInvocations.layer3);
    engineMock.query.mockReturnValueOnce(
      new Promise((resolve) => {
        resolveProof = resolve;
      }),
    );
    render(<App />);
    await bootEngine();

    fireEvent.click(screen.getByRole("button", { name: "Run step" }));
    await waitFor(() =>
      expect(engineMock.query).toHaveBeenCalledWith(
        getLessonSpec("customer-flow").steps?.find((step) => step.id === "layer3")?.proof.sql,
      ),
    );

    const stagingTab = screen.getByRole("tab", { name: /stg_customer\.sql/ });
    const layer3Tab = screen.getByRole("tab", { name: /dim_customer\.sql/ });
    expect(stagingTab).toBeDisabled();
    expect(layer3Tab).toBeDisabled();
    expect(customerStepButton("staging")).toBeDisabled();
    expect(customerStepButton("layer3")).toBeDisabled();
    expect(layer3Tab).toHaveAttribute("aria-selected", "true");
    fireEvent.click(stagingTab);
    fireEvent.click(customerStepButton("staging"));
    expect(screen.getByLabelText("Edit models/dim_customer.sql")).toBeDisabled();
    expect(customerStepButton("layer3")).toHaveAttribute("aria-current", "step");

    await act(async () => {
      resolveProof(customerProofResults.layer3);
      await Promise.resolve();
    });
    await waitFor(() => expect(progressBar()).toHaveAttribute("aria-valuenow", "20"));
    expect(screen.getByText(customerProofLabels.layer3)).toBeVisible();

    await waitFor(() => expect(stagingTab).toBeEnabled());
    fireEvent.click(stagingTab);
    expect(customerStepButton("staging")).toHaveAttribute("aria-current", "step");
    expect(screen.getByLabelText("Edit models/stg_customer.sql")).toBeVisible();
    expect(screen.getByText("No query result yet")).toBeVisible();
    expect(screen.queryByText(customerProofLabels.layer3)).not.toBeInTheDocument();
  });

  it("invalidates an edited customer step and every downstream proof while preserving upstream proofs", async () => {
    window.history.replaceState(null, "", "/?lesson=customer-flow");
    render(<App />);
    await completeCustomerTutorial();

    fireEvent.click(customerStepButton("mapping"));
    expect(screen.getByText(customerProofLabels.mapping)).toBeVisible();
    fireEvent.change(screen.getByLabelText("Edit models/demo_customer_map.sql"), {
      target: { value: "select from" },
    });

    expect(progressBar()).toHaveAttribute("aria-valuenow", "40");
    expect(screen.getByText("No query result yet")).toBeVisible();
    expect(customerStepButton("staging")).toHaveAccessibleName(/Complete$/);
    expect(customerStepButton("current")).toHaveAccessibleName(/Complete$/);
    expect(customerStepButton("mapping")).toHaveAccessibleName(/Current task$/);
    expect(customerStepButton("layer2")).toHaveAccessibleName(/Not started$/);
    expect(customerStepButton("layer3")).toHaveAccessibleName(/Not started$/);

    fireEvent.click(screen.getByRole("button", { name: "Previous" }));
    expect(screen.getByText(customerProofLabels.current)).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: "Next" }));
    expect(screen.getByText("No query result yet")).toBeVisible();
  });

  it("resets every session, restores the customer source, and returns the retained lesson to staging", async () => {
    window.history.replaceState(null, "", "/?lesson=customer-flow&step=layer3");
    render(<App />);
    await bootEngine();

    fireEvent.change(screen.getByLabelText("Edit models/dim_customer.sql"), {
      target: { value: "select from" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Reset lab" }));

    expect(screen.getByRole("combobox", { name: "Choose lesson" })).toHaveValue("customer-flow");
    expect(
      screen.getByRole("heading", { name: "Build a customer flow from staging to Layer3" }),
    ).toBeVisible();
    expect(customerStepButton("staging")).toHaveAttribute("aria-current", "step");
    expect(screen.getByLabelText("Edit models/stg_customer.sql")).not.toHaveValue("select from");
    expect(screen.queryByLabelText("Edit models/dim_customer.sql")).not.toBeInTheDocument();
    expect(progressBar()).toHaveAttribute("aria-valuenow", "0");
    expect(screen.getByText("Engine offline")).toBeVisible();
    expect(engineMock.terminate).toHaveBeenCalledOnce();
    await waitFor(() =>
      expect(new URL(window.location.href).searchParams.get("step")).toBe("staging"),
    );
  });

  it("locks lesson and step navigation while the shared engine is busy", async () => {
    window.history.replaceState(null, "", "/?lesson=customer-flow");
    let resolveBoot!: (value: typeof runtimeInfo) => void;
    engineMock.boot.mockReturnValueOnce(
      new Promise((resolve) => {
        resolveBoot = resolve;
      }),
    );
    render(<App />);

    fireEvent.click(screen.getByRole("button", { name: "Boot engine" }));
    expect(screen.getByRole("combobox", { name: "Choose lesson" })).toBeDisabled();
    expect(customerStepButton("current")).toBeDisabled();
    fireEvent.change(screen.getByRole("combobox", { name: "Choose lesson" }), {
      target: { value: "invoice-quarantine" },
    });
    expect(screen.getByRole("combobox", { name: "Choose lesson" })).toHaveValue("customer-flow");

    await act(async () => {
      resolveBoot(runtimeInfo);
      await Promise.resolve();
    });
    expect(screen.getByRole("combobox", { name: "Choose lesson" })).toBeEnabled();
    expect(customerStepButton("current")).toBeEnabled();
  });

  it("invalidates customer and invoice proofs after editing their shared staged customer model", async () => {
    render(<App />);
    await runInvoiceLesson();

    selectLesson("customer-flow");
    queueCustomerStep("staging");
    await runSelectedCustomerStep(20);
    fireEvent.change(screen.getByLabelText("Edit models/stg_customer.sql"), {
      target: { value: "select from" },
    });

    expect(progressBar()).toHaveAttribute("aria-valuenow", "0");
    expect(screen.getByText("No query result yet")).toBeVisible();

    selectLesson("invoice-quarantine");
    expect(progressBar()).toHaveAttribute("aria-valuenow", "20");
    expect(screen.getByText("No query result yet")).toBeVisible();
  });

  it("discards a relation query that resolves after its source file is edited", async () => {
    render(<App />);
    await runInvoiceLesson();

    let resolveRelation!: (value: typeof invoiceProofResult) => void;
    engineMock.query.mockReturnValueOnce(
      new Promise((resolve) => {
        resolveRelation = resolve;
      }),
    );
    fireEvent.click(screen.getByRole("tab", { name: /Database/ }));
    fireEvent.click(screen.getByRole("button", { name: /quarantine_invoices/ }));
    await waitFor(() => expect(engineMock.query).toHaveBeenCalledTimes(2));

    fireEvent.change(screen.getByLabelText("Edit models/stg_invoices.sql"), {
      target: { value: "select from" },
    });
    await act(async () => {
      resolveRelation({
        columns: [{ name: "invoice_id", type: "VARCHAR" }],
        rows: [["STALE-AFTER-EDIT"]],
      } as typeof invoiceProofResult);
      await Promise.resolve();
    });

    expect(screen.queryByText("STALE-AFTER-EDIT")).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("tab", { name: /Query result/ }));
    expect(screen.getByText("No query result yet")).toBeVisible();
    expect(progressBar()).toHaveAttribute("aria-valuenow", "20");
  });

  it("keeps the newest same-step relation result when an older query resolves last", async () => {
    render(<App />);
    await runInvoiceLesson();

    let resolveOlder!: (value: typeof invoiceProofResult) => void;
    let resolveNewer!: (value: typeof invoiceProofResult) => void;
    engineMock.query
      .mockReturnValueOnce(
        new Promise((resolve) => {
          resolveOlder = resolve;
        }),
      )
      .mockReturnValueOnce(
        new Promise((resolve) => {
          resolveNewer = resolve;
        }),
      );
    fireEvent.click(screen.getByRole("tab", { name: /Database/ }));
    fireEvent.click(screen.getByRole("button", { name: /quarantine_invoices/ }));
    fireEvent.click(screen.getByRole("button", { name: /int_invoices_resolved/ }));
    await waitFor(() => expect(engineMock.query).toHaveBeenCalledTimes(3));

    await act(async () => {
      resolveNewer({
        columns: [{ name: "invoice_id", type: "VARCHAR" }],
        rows: [["NEWEST-RELATION-RESULT"]],
      } as typeof invoiceProofResult);
      await Promise.resolve();
    });
    fireEvent.click(screen.getByRole("tab", { name: /Query result/ }));
    expect(await screen.findByText("NEWEST-RELATION-RESULT", { selector: "td" })).toBeVisible();

    await act(async () => {
      resolveOlder({
        columns: [{ name: "invoice_id", type: "VARCHAR" }],
        rows: [["OLDER-RELATION-RESULT"]],
      } as typeof invoiceProofResult);
      await Promise.resolve();
    });
    expect(screen.getByText("NEWEST-RELATION-RESULT", { selector: "td" })).toBeVisible();
    expect(screen.queryByText("OLDER-RELATION-RESULT")).not.toBeInTheDocument();
  });

  it("invalidates both lesson caches when a mutating command runs from the terminal", async () => {
    render(<App />);
    await runInvoiceLesson();
    selectLesson("customer-flow");
    queueCustomerStep("staging");
    await runSelectedCustomerStep(20);
    expect(screen.getByText(customerProofLabels.staging)).toBeVisible();

    engineMock.invoke.mockResolvedValueOnce({
      ...customerInvocations.staging,
      results: customerInvocations.staging.results.filter((result) =>
        result.uniqueId.startsWith("model."),
      ),
    });
    fireEvent.change(screen.getByLabelText("Enter a dbt command"), {
      target: { value: "dbt run --select stg_customer" },
    });
    fireEvent.click(screen.getByRole("button", { name: /^Run$/ }));

    await waitFor(() => expect(screen.getByText(/did not execute the lesson test/)).toBeVisible());
    expect(progressBar()).toHaveAttribute("aria-valuenow", "0");
    expect(screen.getByText("No query result yet")).toBeVisible();
    expect(engineMock.query).toHaveBeenCalledTimes(2);

    selectLesson("invoice-quarantine");
    expect(progressBar()).toHaveAttribute("aria-valuenow", "20");
    expect(screen.getByText("No query result yet")).toBeVisible();
    selectLesson("customer-flow");
    expect(progressBar()).toHaveAttribute("aria-valuenow", "0");
    expect(screen.getByText("No query result yet")).toBeVisible();
  });

  it("keeps a completed invoice proof invalid after an edit and failed rebuild", async () => {
    render(<App />);
    await runInvoiceLesson();

    fireEvent.change(screen.getByLabelText("Edit models/stg_invoices.sql"), {
      target: { value: "select from" },
    });
    expect(progressBar()).toHaveAttribute("aria-valuenow", "20");

    engineMock.invoke.mockResolvedValueOnce({
      ...invoiceInvocation,
      success: false,
      exception: "broken model",
    });
    fireEvent.click(screen.getByRole("button", { name: "Run lesson" }));
    await waitFor(() => expect(screen.getByText("broken model")).toBeVisible());
    expect(progressBar()).toHaveAttribute("aria-valuenow", "20");
    expect(screen.getByText("No query result yet")).toBeVisible();
  });

  it("does not grade dbt run against stale invoice relations or model-only success", async () => {
    render(<App />);
    await runInvoiceLesson();
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
    expect(progressBar()).toHaveAttribute("aria-valuenow", "20");
    expect(screen.getByText("No query result yet")).toBeVisible();
  });

  it("does not grade an invoice build when a required lesson test is absent", async () => {
    render(<App />);
    await bootEngine();
    engineMock.invoke.mockResolvedValueOnce({
      ...invoiceInvocation,
      results: invoiceInvocation.results.filter((result) => !result.uniqueId.includes("test.")),
    });

    fireEvent.click(screen.getByRole("button", { name: "Run lesson" }));

    await waitFor(() =>
      expect(screen.getByText(/did not rebuild every required resource/)).toBeVisible(),
    );
    expect(engineMock.query).not.toHaveBeenCalled();
    expect(progressBar()).toHaveAttribute("aria-valuenow", "20");
  });
});
