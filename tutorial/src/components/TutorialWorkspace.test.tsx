import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import type { LessonGuideStep, TutorialWorkspaceProps } from "../types";
import { TutorialWorkspace } from "./TutorialWorkspace";

const guideSteps: LessonGuideStep[] = [
  {
    id: "source",
    number: 1,
    total: 5,
    title: "Read the source",
    buildsOn: "The reserved synthetic customer seed.",
    why: "Start with the readable boundary before applying transformations.",
    change: "Type and normalize the customer feed in stg_customer.",
    observe: "One readable CUST-0001 staging row.",
    command: "dbt build --select +stg_customer --indirect-selection cautious",
    status: "complete",
  },
  {
    id: "current",
    number: 2,
    total: 5,
    title: "Keep current customers",
    buildsOn: "The typed Layer1 customer feed.",
    why: "Deletion tombstones must win over later upserts.",
    change: "Rank upserts and remove terminally deleted identities.",
    observe: "Fifteen current customers; only confirmed deletion fixtures are absent.",
    command: "dbt build --select +int_current_customers --indirect-selection cautious",
    status: "active",
  },
  {
    id: "mapping",
    number: 3,
    total: 5,
    title: "Create demo keys",
    buildsOn: "The current-customer view.",
    why: "The teaching map separates readable values from analytical keys.",
    change: "Create deterministic demo-v1 keys beside synthetic values.",
    observe: "Distinct customer and email keys for CUST-0001.",
    command: "dbt build --select +demo_customer_map --indirect-selection cautious",
    status: "pending",
  },
  {
    id: "layer2",
    number: 4,
    total: 5,
    title: "Project Layer2",
    buildsOn: "The local teaching map.",
    why: "Readable identifiers must stay outside protected analytical output.",
    change: "Select only the exact allowed key and business columns.",
    observe: "A keyed row with no unexpected columns.",
    command: "dbt build --select +int_customer_protected --indirect-selection cautious",
    status: "pending",
  },
  {
    id: "layer3",
    number: 5,
    total: 5,
    title: "Verify Layer3",
    buildsOn: "The protected Layer2 projection.",
    why: "The dimension should preserve grain, keys, and schema.",
    change: "Build dim_customer and execute the final fixture test.",
    observe: "The same protected customer identity in Layer3.",
    command: "dbt build --select +assert_customer_flow_fixture --indirect-selection cautious",
    status: "pending",
  },
];

function createProps(
  overrides: Partial<TutorialWorkspaceProps> = {},
): TutorialWorkspaceProps {
  return {
    lesson: {
      id: "invoice-quarantine",
      number: 1,
      total: 2,
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
    lessons: [
      {
        id: "invoice-quarantine",
        number: 1,
        title: "Trace an invoice into quarantine",
      },
      {
        id: "customer-flow",
        number: 2,
        title: "Follow a customer through protected layers",
      },
    ],
    activeLessonId: "invoice-quarantine",
    selectedStepId: null,
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
    onLessonSelect: vi.fn(),
    onStepSelect: vi.fn(),
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
    expect(screen.getByText(/demo-v1 uses a public constant/)).toBeVisible();
    expect(screen.getByText(/not pseudonymization or a security control/)).toBeVisible();
    expect(screen.getByRole("status")).toHaveTextContent("Engine offline");
    expect(screen.getByRole("button", { name: "Run lesson" })).toBeDisabled();
    expect(screen.getByRole("heading", { name: "Your tasks" })).toBeVisible();
    expect(screen.queryByRole("heading", { name: "Tutorial steps" })).not.toBeInTheDocument();
    expect(screen.getByRole("combobox", { name: "Choose lesson" })).toHaveValue(
      "invoice-quarantine",
    );

    fireEvent.click(screen.getByRole("button", { name: "Boot engine" }));
    expect(props.onBoot).toHaveBeenCalledOnce();
  });

  it("forwards editor, run, database, and terminal interactions", () => {
    const props = createProps({ engineStatus: "ready" });
    render(<TutorialWorkspace {...props} />);

    const fileTabs = within(screen.getByRole("tablist", { name: "Tutorial files" })).getAllByRole(
      "tab",
    );
    expect(fileTabs).toHaveLength(2);
    fileTabs.forEach((tab) => expect(tab).toBeEnabled());
    expect(screen.getByLabelText("Edit models/quarantine_invoices.sql")).toBeEnabled();

    fireEvent.change(screen.getByRole("combobox", { name: "Choose lesson" }), {
      target: { value: "customer-flow" },
    });
    expect(props.onLessonSelect).toHaveBeenCalledWith("customer-flow");

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
      lessonId: "invoice-quarantine",
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

  it.each(["booting", "running"] as const)(
    "locks SQL file tabs and the editor while the engine is %s",
    (engineStatus) => {
      const props = createProps({ engineStatus });
      render(<TutorialWorkspace {...props} />);

      const fileTabs = within(
        screen.getByRole("tablist", { name: "Tutorial files" }),
      ).getAllByRole("tab");
      expect(fileTabs).toHaveLength(2);
      fileTabs.forEach((tab) => expect(tab).toBeDisabled());
      expect(screen.getByLabelText("Edit models/quarantine_invoices.sql")).toBeDisabled();
    },
  );

  it("renders an accessible guided customer step and forwards step navigation", () => {
    const props = createProps({
      activeLessonId: "customer-flow",
      selectedStepId: "source",
      command: guideSteps[0].command,
      engineStatus: "ready",
      lesson: {
        id: "customer-flow",
        number: 2,
        total: 2,
        title: "Follow a customer through protected layers",
        summary: "Build one customer concept at a time.",
        objective: "Trace CUST-0001 through five cumulative checkpoints.",
        duration: "20 min",
        tasks: [],
        guideSteps,
      },
    });
    render(<TutorialWorkspace {...props} />);

    const selected = screen.getByRole("button", {
      name: "Step 1 of 5: Read the source. Complete",
    });
    expect(selected).toHaveAttribute("aria-current", "step");
    expect(selected.querySelector("h3")).toBeNull();
    expect(screen.getByText("Step 1 of 5: Read the source")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Read the source" })).toBeVisible();
    expect(screen.getByText("Builds on")).toBeVisible();
    expect(screen.getByText("Why")).toBeVisible();
    expect(screen.getByText("Change")).toBeVisible();
    expect(screen.getByText("You should see")).toBeVisible();
    expect(screen.getByText(guideSteps[0].command, { selector: "code" })).toBeVisible();

    const guideCard = screen.getByRole("region", { name: "Read the source" });
    const stepNavigator = screen.getByRole("region", { name: "Tutorial steps" });
    expect(guideCard.compareDocumentPosition(stepNavigator)).toBe(Node.DOCUMENT_POSITION_FOLLOWING);
    expect(Array.from(guideCard.querySelectorAll("dt"), (term) => term.textContent)).toEqual([
      "Why",
      "Builds on",
      "Change",
      "Run",
      "You should see",
    ]);

    expect(screen.getByRole("button", { name: "Previous" })).toBeDisabled();
    fireEvent.click(screen.getByRole("button", { name: "Next" }));
    expect(props.onStepSelect).toHaveBeenCalledWith("current");

    fireEvent.click(
      screen.getByRole("button", { name: "Step 3 of 5: Create demo keys. Not started" }),
    );
    expect(props.onStepSelect).toHaveBeenCalledWith("mapping");

    fireEvent.click(screen.getByRole("button", { name: "Run step" }));
    expect(props.onRun).toHaveBeenCalledWith({
      lessonId: "customer-flow",
      stepId: "source",
      command: guideSteps[0].command,
      sql: "select * from {{ ref('stg_invoices') }}",
      activeFilePath: "models/quarantine_invoices.sql",
    });
    expect(screen.getByText("Run step", { selector: ".editor-footer span" })).toBeVisible();
  });

  it("always renders guided Previous and Next controls and disables them while busy", () => {
    const props = createProps({
      activeLessonId: "customer-flow",
      selectedStepId: "layer3",
      engineStatus: "running",
      lesson: {
        id: "customer-flow",
        number: 2,
        total: 2,
        title: "Follow a customer through protected layers",
        summary: "Build one customer concept at a time.",
        objective: "Trace CUST-0001 through five cumulative checkpoints.",
        duration: "20 min",
        tasks: [],
        guideSteps,
      },
    });
    render(<TutorialWorkspace {...props} />);

    expect(screen.getByRole("button", { name: "Previous" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Next" })).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Step 1 of 5: Read the source. Complete" }),
    ).toBeDisabled();
    expect(screen.getByRole("button", { name: "Running…" })).toBeDisabled();
  });

  it("keeps reset available and blocks relation queries while the engine is busy", () => {
    const props = createProps({ engineStatus: "running" });
    render(<TutorialWorkspace {...props} />);

    expect(screen.getByRole("button", { name: "Reset lab" })).toBeEnabled();
    expect(screen.getByRole("button", { name: "Running…" })).toBeDisabled();
    expect(screen.getByRole("combobox", { name: "Choose lesson" })).toBeDisabled();

    fireEvent.click(screen.getByRole("tab", { name: /Database/ }));
    const relation = screen.getByRole("button", { name: /quarantine_invoices/ });
    expect(relation).toBeDisabled();
    fireEvent.click(relation);
    expect(props.onRelationSelect).not.toHaveBeenCalled();
  });
});
