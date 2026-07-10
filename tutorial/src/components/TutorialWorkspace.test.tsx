import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import type { TutorialWorkspaceProps } from "../types";
import { TutorialWorkspace } from "./TutorialWorkspace";

function createProps(
  overrides: Partial<TutorialWorkspaceProps> = {},
): TutorialWorkspaceProps {
  return {
    lesson: {
      number: 1,
      total: 5,
      title: "Trace an invoice into quarantine",
      summary: "Follow the invalid invoice.",
      objective: "Prove the accepted or quarantine partition.",
      duration: "12 min",
      tasks: [
        {
          id: "boot",
          title: "Start the local lab",
          detail: "Load the browser runtime.",
          status: "active",
        },
      ],
    },
    files: [
      {
        path: "models/quarantine_invoices.sql",
        label: "quarantine_invoices.sql",
        language: "sql",
        editable: true,
        content: "select * from {{ ref('stg_invoices') }}",
      },
      {
        path: "tests/assert_partition.sql",
        label: "assert_partition.sql",
        language: "sql",
        editable: true,
        content: "select invoice_id from partitioned",
      },
    ],
    activeFilePath: "models/quarantine_invoices.sql",
    relations: [
      {
        name: "quarantine_invoices",
        schema: "layer1",
        layer: "Layer1",
        kind: "table",
        rowCount: 1,
        columns: [{ name: "invoice_id", type: "VARCHAR" }],
      },
    ],
    selectedRelation: "quarantine_invoices",
    result: null,
    terminal: [],
    engineStatus: "idle",
    command: "dbt build --select +quarantine_invoices",
    onBoot: vi.fn(),
    onRun: vi.fn(),
    onReset: vi.fn(),
    onFileSelect: vi.fn(),
    onFileChange: vi.fn(),
    onRelationSelect: vi.fn(),
    onTerminalSubmit: vi.fn(),
    ...overrides,
  };
}

describe("TutorialWorkspace", () => {
  it("makes the teaching boundary and engine state explicit", () => {
    const props = createProps();
    render(<TutorialWorkspace {...props} />);

    expect(screen.getByRole("heading", { name: "Trace an invoice into quarantine" })).toBeVisible();
    expect(screen.getByText("DuckDB teaching edition")).toBeVisible();
    expect(screen.getByText(/Synthetic data only/)).toBeVisible();
    expect(screen.getByRole("status")).toHaveTextContent("Engine offline");
    expect(screen.getByRole("button", { name: "Run lesson" })).toBeDisabled();

    fireEvent.click(screen.getByRole("button", { name: "Boot engine" }));
    expect(props.onBoot).toHaveBeenCalledOnce();
  });

  it("forwards editor, run, database, and terminal interactions", () => {
    const props = createProps({ engineStatus: "ready" });
    render(<TutorialWorkspace {...props} />);

    fireEvent.click(screen.getByRole("tab", { name: /assert_partition\.sql/ }));
    expect(props.onFileSelect).toHaveBeenCalledWith("tests/assert_partition.sql");

    fireEvent.change(screen.getByLabelText("Edit models/quarantine_invoices.sql"), {
      target: { value: "select 'changed'" },
    });
    expect(props.onFileChange).toHaveBeenCalledWith(
      "models/quarantine_invoices.sql",
      "select 'changed'",
    );

    fireEvent.click(screen.getByRole("button", { name: "Run lesson" }));
    expect(props.onRun).toHaveBeenCalledWith({
      command: "dbt build --select +quarantine_invoices",
      sql: "select * from {{ ref('stg_invoices') }}",
      activeFilePath: "models/quarantine_invoices.sql",
    });

    fireEvent.click(screen.getByRole("tab", { name: /Database/ }));
    fireEvent.click(screen.getByRole("button", { name: /quarantine_invoices/ }));
    expect(props.onRelationSelect).toHaveBeenCalledWith("quarantine_invoices");

    fireEvent.change(screen.getByLabelText("Enter a dbt command"), {
      target: { value: "dbt test" },
    });
    fireEvent.click(screen.getByRole("button", { name: /^Run$/ }));
    expect(props.onTerminalSubmit).toHaveBeenCalledWith("dbt test");
  });

  it("keeps reset available and blocks relation queries while the engine is busy", () => {
    const props = createProps({ engineStatus: "running" });
    render(<TutorialWorkspace {...props} />);

    expect(screen.getByRole("button", { name: "Reset lesson" })).toBeEnabled();
    expect(screen.getByRole("button", { name: "Running…" })).toBeDisabled();

    fireEvent.click(screen.getByRole("tab", { name: /Database/ }));
    const relation = screen.getByRole("button", { name: /quarantine_invoices/ });
    expect(relation).toBeDisabled();
    fireEvent.click(relation);
    expect(props.onRelationSelect).not.toHaveBeenCalled();
  });
});
