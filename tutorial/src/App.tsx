import { useEffect, useRef, useState } from "react";
import { TutorialWorkspace } from "./components";
import { BrowserDbtEngine, parseDbtCommand } from "./engine";
import type { CatalogRelation, RawQueryResult, RuntimeInfo } from "./engine";
import { createTutorialFiles, mergeProjectFiles } from "./lesson/project";
import type {
  EngineStatus,
  LessonDefinition,
  QueryResult,
  RelationKind,
  RelationSummary,
  ResultCell,
  RunRequest,
  TerminalEntry,
  TerminalEntryTone,
  TutorialFile,
} from "./types";

const initialLesson: LessonDefinition = {
  number: 1,
  total: 5,
  title: "Trace an invoice into quarantine",
  summary:
    "Run real dbt Core in your browser and follow one deliberately invalid synthetic invoice through deterministic classification.",
  objective:
    "INV-0105 is preserved with SERVICE_NOT_FOUND, excluded from accepted analytics, and placed in exactly one output partition.",
  duration: "12 min",
  tasks: [
    {
      id: "boot",
      title: "Start the local lab",
      detail: "Load dbt Core, DuckDB and the synthetic project in this browser tab.",
      status: "active",
    },
    {
      id: "build",
      title: "Build the invoice path",
      detail: "Run dbt build to create the staging, accepted and quarantine relations.",
      status: "pending",
    },
    {
      id: "inspect",
      title: "Inspect INV-0105",
      detail: "Confirm that its source service ID is SVC-7777-A.",
      status: "pending",
    },
    {
      id: "classify",
      title: "Read the decision",
      detail: "Observe the stable SERVICE_NOT_FOUND quarantine reason.",
      status: "pending",
    },
    {
      id: "partition",
      title: "Prove the partition",
      detail: "Verify the invoice appears once in quarantine and zero times in accepted Layer2.",
      status: "pending",
    },
  ],
};

const defaultCommand = "dbt build";
const validationSql = `
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

const initialTerminal: TerminalEntry[] = [
  {
    id: "welcome",
    tone: "info",
    text: "Synthetic data and all compute stay inside this browser tab. Boot the engine to begin.",
  },
];

function resultCell(value: unknown): ResultCell {
  if (value === null || ["string", "number", "boolean"].includes(typeof value)) {
    return value as ResultCell;
  }
  return String(value);
}

function toQueryResult(raw: RawQueryResult, label: string, elapsedMs?: number): QueryResult {
  const columns = raw.columns.map((column, index) => ({
    key: `${column.name}-${index}`,
    label: column.name,
    type: column.type,
  }));
  return {
    label,
    elapsedMs,
    rowCount: raw.rows.length,
    columns,
    rows: raw.rows.map((values) =>
      Object.fromEntries(columns.map((column, index) => [column.key, resultCell(values[index])])),
    ),
  };
}

function relationLayer(name: string) {
  if (["customer", "customer_services", "invoices"].includes(name)) return "Sources";
  if (name.startsWith("stg_") || name.startsWith("quarantine_")) return "Layer1";
  return "Layer2";
}

function relationKind(relation: CatalogRelation): RelationKind {
  if (["customer", "customer_services", "invoices"].includes(relation.name)) return "seed";
  return relation.tableType.toUpperCase().includes("VIEW") ? "view" : "table";
}

function toRelationSummary(relation: CatalogRelation): RelationSummary {
  return {
    name: relation.name,
    schema: relation.schema,
    layer: relationLayer(relation.name),
    kind: relationKind(relation),
    rowCount: relation.rowCount,
    columns: relation.columns,
  };
}

export default function App() {
  const [engineStatus, setEngineStatus] = useState<EngineStatus>("idle");
  const [engineMessage, setEngineMessage] = useState("Runtime not started");
  const [lesson, setLesson] = useState<LessonDefinition>(initialLesson);
  const [files, setFiles] = useState<TutorialFile[]>(() => createTutorialFiles());
  const [activeFilePath, setActiveFilePath] = useState(() => createTutorialFiles()[0].path);
  const [relations, setRelations] = useState<RelationSummary[]>([]);
  const [selectedRelation, setSelectedRelation] = useState<string | null>(null);
  const [result, setResult] = useState<QueryResult | null>(null);
  const [terminal, setTerminal] = useState<TerminalEntry[]>(initialTerminal);
  const engineRef = useRef<BrowserDbtEngine | null>(null);
  const entrySequence = useRef(0);

  useEffect(
    () => () => {
      const engine = engineRef.current;
      engineRef.current = null;
      engine?.terminate();
    },
    [],
  );

  function appendTerminal(tone: TerminalEntryTone, text: string) {
    if (!text.trim()) return;
    entrySequence.current += 1;
    const entry: TerminalEntry = {
      id: `terminal-${entrySequence.current}`,
      tone,
      text,
      timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
    };
    setTerminal((current) => [...current.slice(-399), entry]);
  }

  function markTaskProgress(completedIds: string[], activeId?: string) {
    setLesson((current) => ({
      ...current,
      tasks: current.tasks.map((task) => ({
        ...task,
        status: completedIds.includes(task.id)
          ? "complete"
          : task.id === activeId
            ? "active"
            : "pending",
      })),
    }));
  }

  function invalidateLessonProof(bootComplete: boolean) {
    setResult(null);
    setRelations([]);
    setSelectedRelation(null);
    markTaskProgress(bootComplete ? ["boot"] : [], bootComplete ? "build" : "boot");
  }

  function isCurrentEngine(engine: BrowserDbtEngine) {
    return engineRef.current === engine;
  }

  function createEngine() {
    let engine: BrowserDbtEngine;
    engine = new BrowserDbtEngine({
      onLog: (line, stream) => {
        if (!isCurrentEngine(engine)) return;
        const tone: TerminalEntryTone = stream === "err" ? "error" : "info";
        appendTerminal(tone, line);
      },
      onStatus: (_phase, detail) => {
        if (!isCurrentEngine(engine)) return;
        if (detail) setEngineMessage(detail);
      },
    });
    return engine;
  }

  async function handleBoot() {
    if (engineStatus === "booting" || engineStatus === "running" || engineStatus === "ready") {
      return;
    }
    const previousEngine = engineRef.current;
    engineRef.current = null;
    previousEngine?.terminate();
    const engine = createEngine();
    engineRef.current = engine;
    setEngineStatus("booting");
    setEngineMessage("Loading the local WebAssembly runtime");
    appendTerminal("command", "boot browser dbt engine");

    try {
      const runtime: RuntimeInfo = await engine.boot();
      if (!isCurrentEngine(engine)) return;
      setEngineStatus("ready");
      setEngineMessage(`dbt ${runtime.dbtVersion} · DuckDB ${runtime.duckdbVersion}`);
      markTaskProgress(["boot"], "build");
      appendTerminal(
        "success",
        `Ready: dbt ${runtime.dbtVersion}, DuckDB ${runtime.duckdbVersion}, Python ${runtime.pythonVersion}.`,
      );
    } catch (error) {
      if (!isCurrentEngine(engine)) return;
      setEngineStatus("error");
      setEngineMessage("Engine boot failed; retry is available");
      appendTerminal("error", error instanceof Error ? error.message : String(error));
    }
  }

  async function refreshCatalog(engine: BrowserDbtEngine) {
    const catalog = await engine.catalog();
    if (!isCurrentEngine(engine)) return null;
    const summaries = catalog.map(toRelationSummary);
    setRelations(summaries);
    return summaries;
  }

  async function validateLesson(engine: BrowserDbtEngine) {
    const startedAt = performance.now();
    const raw = await engine.query(validationSql);
    if (!isCurrentEngine(engine)) return;
    const queryResult = toQueryResult(
      raw,
      "INV-0105 quarantine proof",
      Math.round(performance.now() - startedAt),
    );
    setResult(queryResult);
    setSelectedRelation("quarantine_invoices");

    const row = raw.rows[0] ?? [];
    const passed =
      row[0] === "INV-0105" &&
      row[1] === "SVC-7777-A" &&
      row[2] === "SERVICE_NOT_FOUND" &&
      Number(row[3]) === 0;
    if (passed) {
      markTaskProgress(["boot", "build", "inspect", "classify", "partition"]);
      appendTerminal(
        "success",
        "Lesson complete: INV-0105 is quarantined as SERVICE_NOT_FOUND and has 0 accepted rows.",
      );
    } else {
      markTaskProgress(["boot", "build"], "inspect");
      appendTerminal("error", "The build passed, but the phase-one semantic proof did not match.");
    }
  }

  async function runDbtCommand(command: string) {
    const engine = engineRef.current;
    if (!engine || engineStatus !== "ready") {
      appendTerminal("error", "Boot the local engine before running dbt.");
      return;
    }

    let args: string[];
    try {
      args = parseDbtCommand(command);
    } catch (error) {
      appendTerminal("error", error instanceof Error ? error.message : String(error));
      return;
    }

    const gradesLesson = args[0] === "build" || args[0] === "run";
    if (gradesLesson) invalidateLessonProof(true);

    setEngineStatus("running");
    setEngineMessage(`Running ${command}`);
    appendTerminal("command", command);
    try {
      const invocation = await engine.invoke(args, mergeProjectFiles(files));
      if (!isCurrentEngine(engine)) return;
      if (!invocation.success) {
        setEngineStatus("ready");
        setEngineMessage("dbt reported an error; edit and retry");
        appendTerminal("error", invocation.exception ?? "dbt command failed");
        return;
      }

      const failures = invocation.results.filter(
        (item) => !["pass", "success"].includes(item.status.toLowerCase()),
      );
      appendTerminal(
        failures.length === 0 ? "success" : "error",
        `${invocation.results.length} dbt nodes finished; ${failures.length} failed.`,
      );
      const refreshedRelations = await refreshCatalog(engine);
      if (!isCurrentEngine(engine)) return;

      if (gradesLesson) {
        const isPartialCommand = args.some((argument) =>
          ["--select", "-s", "--exclude"].includes(argument),
        );
        const hasInvoicePath = ["quarantine_invoices", "int_invoices_resolved"].every((name) =>
          refreshedRelations?.some((relation) => relation.name === name),
        );
        if (!isPartialCommand && hasInvoicePath) {
          markTaskProgress(["boot", "build"], "inspect");
          await validateLesson(engine);
          if (!isCurrentEngine(engine)) return;
        } else {
          markTaskProgress(["boot"], "build");
          appendTerminal(
            "info",
            "dbt succeeded, but the full invoice path was not rebuilt. Run dbt build without selectors to grade the lesson.",
          );
        }
      }
      setEngineStatus("ready");
      setEngineMessage("Engine ready for another command");
    } catch (error) {
      if (!isCurrentEngine(engine)) return;
      setEngineStatus("ready");
      setEngineMessage("Command failed; edit and retry");
      appendTerminal("error", error instanceof Error ? error.message : String(error));
    }
  }

  function handleRun(request: RunRequest) {
    void runDbtCommand(request.command);
  }

  function handleReset() {
    const engine = engineRef.current;
    engineRef.current = null;
    engine?.terminate();
    setEngineStatus("idle");
    setEngineMessage("Runtime not started");
    setLesson(initialLesson);
    const resetFiles = createTutorialFiles();
    setFiles(resetFiles);
    setActiveFilePath(resetFiles[0].path);
    setRelations([]);
    setSelectedRelation(null);
    setResult(null);
    setTerminal(initialTerminal);
  }

  function handleFileChange(path: string, content: string) {
    setFiles((current) =>
      current.map((file) => (file.path === path ? { ...file, content, dirty: true } : file)),
    );
    invalidateLessonProof(engineStatus === "ready" || engineStatus === "running");
  }

  async function handleRelationSelect(name: string) {
    if (engineStatus !== "ready") return;
    setSelectedRelation(name);
    const engine = engineRef.current;
    const relation = relations.find((candidate) => candidate.name === name);
    if (!engine || !relation) return;
    const quotedSchema = `"${relation.schema.replaceAll('"', '""')}"`;
    const quotedName = `"${relation.name.replaceAll('"', '""')}"`;
    try {
      const startedAt = performance.now();
      const raw = await engine.query(`select * from ${quotedSchema}.${quotedName} limit 50`);
      if (!isCurrentEngine(engine)) return;
      setResult(
        toQueryResult(raw, `${relation.schema}.${relation.name}`, Math.round(performance.now() - startedAt)),
      );
    } catch (error) {
      if (!isCurrentEngine(engine)) return;
      appendTerminal("error", error instanceof Error ? error.message : String(error));
    }
  }

  function handleTerminalSubmit(command: string) {
    if (command === "clear") {
      setTerminal([]);
      return;
    }
    if (command === "help") {
      appendTerminal(
        "info",
        "Try dbt build, dbt run, dbt test, dbt show, dbt compile, or dbt ls. This is a controlled dbt prompt, not a shell.",
      );
      return;
    }
    if (command === "reset") {
      handleReset();
      return;
    }
    void runDbtCommand(command);
  }

  return (
    <TutorialWorkspace
      lesson={lesson}
      files={files}
      activeFilePath={activeFilePath}
      relations={relations}
      selectedRelation={selectedRelation}
      result={result}
      terminal={terminal}
      engineStatus={engineStatus}
      engineMessage={engineMessage}
      command={defaultCommand}
      onBoot={handleBoot}
      onRun={handleRun}
      onReset={handleReset}
      onFileSelect={setActiveFilePath}
      onFileChange={handleFileChange}
      onRelationSelect={(name) => void handleRelationSelect(name)}
      onTerminalSubmit={handleTerminalSubmit}
    />
  );
}
