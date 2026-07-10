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

const successfulInvocation = {
  success: true,
  exception: null,
  results: [{ uniqueId: "model.tutorial.quarantine_invoices", status: "success" }],
  nodes: [],
  artifacts: ["manifest.json", "run_results.json"],
};

const requiredCatalog = [
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
];

const proofResult = {
  columns: [
    { name: "invoice_id", type: "VARCHAR" },
    { name: "service_id", type: "VARCHAR" },
    { name: "quarantine_reason", type: "VARCHAR" },
    { name: "accepted_rows", type: "BIGINT" },
  ],
  rows: [["INV-0105", "SVC-7777-A", "SERVICE_NOT_FOUND", 0]],
};

beforeEach(() => {
  engineMock.boot.mockReset().mockResolvedValue(runtimeInfo);
  engineMock.invoke.mockReset().mockResolvedValue(successfulInvocation);
  engineMock.catalog.mockReset().mockResolvedValue(requiredCatalog);
  engineMock.query.mockReset().mockResolvedValue(proofResult);
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

describe("App engine integration", () => {
  it("lets reset terminate boot and ignores callbacks from the old engine", async () => {
    let resolveBoot!: (value: typeof runtimeInfo) => void;
    engineMock.boot.mockReturnValueOnce(
      new Promise((resolve) => {
        resolveBoot = resolve;
      }),
    );
    render(<App />);

    fireEvent.click(screen.getByRole("button", { name: "Boot engine" }));
    const reset = screen.getByRole("button", { name: "Reset lesson" });
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

  it("invalidates a completed proof after an edit and keeps it invalid after a failed build", async () => {
    render(<App />);
    await bootAndBuild();
    expect(screen.getByText("SERVICE_NOT_FOUND", { selector: "td" })).toBeVisible();

    fireEvent.change(screen.getByLabelText("Edit models/stg_invoices.sql"), {
      target: { value: "select from" },
    });
    expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
      "aria-valuenow",
      "20",
    );
    expect(screen.getByText("No query result yet")).toBeVisible();
    expect(screen.getByRole("tab", { name: /Database\s*0/ })).toBeVisible();

    engineMock.invoke.mockResolvedValueOnce({
      ...successfulInvocation,
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
    expect(screen.getByRole("tab", { name: /Database\s*0/ })).toBeVisible();
  });

  it("does not re-award proof for a partial command against stale relations", async () => {
    render(<App />);
    await bootAndBuild();
    expect(engineMock.query).toHaveBeenCalledOnce();

    fireEvent.change(screen.getByLabelText("Edit models/stg_invoices.sql"), {
      target: { value: "select * from {{ ref('invoices') }}" },
    });
    fireEvent.change(screen.getByLabelText("Enter a dbt command"), {
      target: { value: "dbt run --select stg_invoices" },
    });
    fireEvent.click(screen.getByRole("button", { name: /^Run$/ }));

    await waitFor(() =>
      expect(
        screen.getByText(/full invoice path was not rebuilt/),
      ).toBeVisible(),
    );
    expect(engineMock.query).toHaveBeenCalledOnce();
    expect(screen.getByRole("progressbar", { name: "Lesson progress" })).toHaveAttribute(
      "aria-valuenow",
      "20",
    );
    expect(screen.getByText("No query result yet")).toBeVisible();
  });
});
