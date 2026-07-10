import { useEffect, useRef, useState } from "react";
import { TutorialWorkspace } from "./components";
import { BrowserDbtEngine, parseDbtCommand } from "./engine";
import type { CatalogRelation, RawQueryResult, RuntimeInfo } from "./engine";
import {
  LESSON_OPTIONS,
  LESSONS,
  getLessonSpec,
  invocationIncludesLessonResources,
  lessonIdFromSearch,
} from "./lesson/lessons";
import { createTutorialFiles, filesForLesson, mergeProjectFiles } from "./lesson/project";
import type {
  EngineStatus,
  LessonDefinition,
  LessonId,
  LessonTask,
  QueryResult,
  RelationKind,
  RelationSummary,
  ResultCell,
  RunRequest,
  TerminalEntry,
  TerminalEntryTone,
  TutorialFile,
} from "./types";

interface LessonSessionState {
  tasks: LessonTask[];
  activeFilePath: string;
  selectedRelation: string | null;
  result: QueryResult | null;
}

type LessonSessions = Record<LessonId, LessonSessionState>;

const initialTerminal: TerminalEntry[] = [
  {
    id: "welcome",
    tone: "info",
    text: "Synthetic data and all compute stay inside this browser tab. Choose a lesson and boot the engine to begin.",
  },
];

function createInitialTasks(lessonId: LessonId): LessonTask[] {
  return getLessonSpec(lessonId).tasks.map((task, index) => ({
    ...task,
    status: index === 0 ? "active" : "pending",
  }));
}

function createInitialLessonSessions(): LessonSessions {
  return LESSONS.reduce((sessions, lesson) => {
    sessions[lesson.id] = {
      tasks: createInitialTasks(lesson.id),
      activeFilePath: lesson.filePaths[0],
      selectedRelation: null,
      result: null,
    };
    return sessions;
  }, {} as LessonSessions);
}

function withTaskProgress(
  tasks: LessonTask[],
  completedIds: readonly string[],
  activeId?: string,
): LessonTask[] {
  return tasks.map((task) => ({
    ...task,
    status: completedIds.includes(task.id)
      ? "complete"
      : task.id === activeId
        ? "active"
        : "pending",
  }));
}

function toLessonDefinition(
  lessonId: LessonId,
  session: LessonSessionState,
): LessonDefinition {
  const lesson = getLessonSpec(lessonId);
  return {
    id: lesson.id,
    number: lesson.number,
    total: LESSONS.length,
    title: lesson.title,
    summary: lesson.summary,
    objective: lesson.objective,
    duration: lesson.duration,
    tasks: session.tasks,
  };
}

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
  if (name === "demo_customer_map") return "Mapping";
  if (["customer", "customer_services", "invoices"].includes(name)) return "Sources";
  if (name.startsWith("stg_") || name.startsWith("quarantine_")) return "Layer1";
  if (name.startsWith("dim_") || name.startsWith("fct_")) return "Layer3";
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
  const [activeLessonId, setActiveLessonId] = useState<LessonId>(() =>
    lessonIdFromSearch(window.location.search),
  );
  const [lessonSessions, setLessonSessions] = useState<LessonSessions>(() =>
    createInitialLessonSessions(),
  );
  const [engineStatus, setEngineStatus] = useState<EngineStatus>("idle");
  const [engineMessage, setEngineMessage] = useState("Runtime not started");
  const [files, setFiles] = useState<TutorialFile[]>(() => createTutorialFiles());
  const [relations, setRelations] = useState<RelationSummary[]>([]);
  const [terminal, setTerminal] = useState<TerminalEntry[]>(initialTerminal);
  const engineRef = useRef<BrowserDbtEngine | null>(null);
  const entrySequence = useRef(0);

  const activeLessonSpec = getLessonSpec(activeLessonId);
  const activeSession = lessonSessions[activeLessonId];
  const lesson = toLessonDefinition(activeLessonId, activeSession);
  const visibleFiles = filesForLesson(files, activeLessonId);
  const visibleRelationNames = new Set(activeLessonSpec.visibleRelationNames);
  const visibleRelations = relations.filter((relation) => visibleRelationNames.has(relation.name));

  useEffect(() => {
    const url = new URL(window.location.href);
    if (url.searchParams.get("lesson") === activeLessonId) return;
    url.searchParams.set("lesson", activeLessonId);
    window.history.replaceState(window.history.state, "", url);
  }, [activeLessonId]);

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

  function markTaskProgress(
    lessonId: LessonId,
    completedIds: readonly string[],
    activeId?: string,
  ) {
    setLessonSessions((current) => ({
      ...current,
      [lessonId]: {
        ...current[lessonId],
        tasks: withTaskProgress(current[lessonId].tasks, completedIds, activeId),
      },
    }));
  }

  function markEngineReadyForAllLessons() {
    setLessonSessions((current) =>
      LESSONS.reduce((next, candidate) => {
        next[candidate.id] = {
          ...current[candidate.id],
          tasks: withTaskProgress(current[candidate.id].tasks, ["boot"], "build"),
        };
        return next;
      }, { ...current }),
    );
  }

  function invalidateLessonProof(lessonId: LessonId, bootComplete: boolean) {
    setLessonSessions((current) => ({
      ...current,
      [lessonId]: {
        ...current[lessonId],
        result: null,
        selectedRelation: null,
        tasks: withTaskProgress(
          current[lessonId].tasks,
          bootComplete ? ["boot"] : [],
          bootComplete ? "build" : "boot",
        ),
      },
    }));
  }

  function invalidateAllLessonProofs(bootComplete: boolean) {
    setLessonSessions((current) =>
      LESSONS.reduce((next, candidate) => {
        next[candidate.id] = {
          ...current[candidate.id],
          result: null,
          selectedRelation: null,
          tasks: withTaskProgress(
            current[candidate.id].tasks,
            bootComplete ? ["boot"] : [],
            bootComplete ? "build" : "boot",
          ),
        };
        return next;
      }, { ...current }),
    );
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
      markEngineReadyForAllLessons();
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

  async function validateLesson(engine: BrowserDbtEngine, lessonId: LessonId) {
    const lessonSpec = getLessonSpec(lessonId);
    const startedAt = performance.now();
    const raw = await engine.query(lessonSpec.proof.sql);
    if (!isCurrentEngine(engine)) return;
    const queryResult = toQueryResult(
      raw,
      lessonSpec.proof.label,
      Math.round(performance.now() - startedAt),
    );
    setLessonSessions((current) => ({
      ...current,
      [lessonId]: {
        ...current[lessonId],
        result: queryResult,
        selectedRelation: lessonSpec.proof.selectedRelation,
      },
    }));

    if (lessonSpec.proof.validate(raw)) {
      markTaskProgress(
        lessonId,
        lessonSpec.tasks.map((task) => task.id),
      );
      appendTerminal("success", lessonSpec.proof.successMessage);
    } else {
      markTaskProgress(lessonId, ["boot", "build"], lessonSpec.tasks[2]?.id);
      appendTerminal("error", lessonSpec.proof.failureMessage);
    }
  }

  async function runDbtCommand(command: string, lessonId: LessonId) {
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

    const lessonSpec = getLessonSpec(lessonId);
    const invalidatesLessonProof = args[0] === "build" || args[0] === "run";
    const gradesLesson = args[0] === "build";
    if (invalidatesLessonProof) invalidateLessonProof(lessonId, true);

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
      await refreshCatalog(engine);
      if (!isCurrentEngine(engine)) return;

      if (gradesLesson) {
        if (invocationIncludesLessonResources(lessonSpec, invocation.results)) {
          markTaskProgress(lessonId, ["boot", "build"], lessonSpec.tasks[2]?.id);
          await validateLesson(engine, lessonId);
          if (!isCurrentEngine(engine)) return;
        } else {
          markTaskProgress(lessonId, ["boot"], "build");
          appendTerminal(
            "info",
            `dbt succeeded, but it did not rebuild every required resource for “${lessonSpec.title}”. Run the lesson command to grade it.`,
          );
        }
      } else if (args[0] === "run") {
        appendTerminal(
          "info",
          "dbt run rebuilt models but did not execute the lesson test. Use the lesson’s dbt build command to grade it.",
        );
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
    void runDbtCommand(request.command, request.lessonId);
  }

  function handleReset() {
    const engine = engineRef.current;
    engineRef.current = null;
    engine?.terminate();
    setEngineStatus("idle");
    setEngineMessage("Runtime not started");
    setLessonSessions(createInitialLessonSessions());
    setFiles(createTutorialFiles());
    setRelations([]);
    setTerminal(initialTerminal);
    entrySequence.current = 0;
  }

  function handleLessonSelect(lessonId: LessonId) {
    if (engineStatus === "booting" || engineStatus === "running") return;
    setActiveLessonId(lessonId);
  }

  function handleFileSelect(path: string) {
    setLessonSessions((current) => ({
      ...current,
      [activeLessonId]: { ...current[activeLessonId], activeFilePath: path },
    }));
  }

  function handleFileChange(path: string, content: string) {
    setFiles((current) =>
      current.map((file) => (file.path === path ? { ...file, content, dirty: true } : file)),
    );
    invalidateAllLessonProofs(engineStatus === "ready" || engineStatus === "running");
    setRelations([]);
  }

  async function handleRelationSelect(name: string) {
    if (engineStatus !== "ready") return;
    const lessonId = activeLessonId;
    setLessonSessions((current) => ({
      ...current,
      [lessonId]: { ...current[lessonId], selectedRelation: name },
    }));
    const engine = engineRef.current;
    const relation = relations.find((candidate) => candidate.name === name);
    if (!engine || !relation) return;
    const quotedSchema = `"${relation.schema.replaceAll('"', '""')}"`;
    const quotedName = `"${relation.name.replaceAll('"', '""')}"`;
    try {
      const startedAt = performance.now();
      const raw = await engine.query(`select * from ${quotedSchema}.${quotedName} limit 50`);
      if (!isCurrentEngine(engine)) return;
      const queryResult = toQueryResult(
        raw,
        `${relation.schema}.${relation.name}`,
        Math.round(performance.now() - startedAt),
      );
      setLessonSessions((current) => ({
        ...current,
        [lessonId]: { ...current[lessonId], result: queryResult },
      }));
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
    void runDbtCommand(command, activeLessonId);
  }

  return (
    <TutorialWorkspace
      lesson={lesson}
      lessons={LESSON_OPTIONS}
      activeLessonId={activeLessonId}
      files={visibleFiles}
      activeFilePath={activeSession.activeFilePath}
      relations={visibleRelations}
      selectedRelation={activeSession.selectedRelation}
      result={activeSession.result}
      terminal={terminal}
      engineStatus={engineStatus}
      engineMessage={engineMessage}
      command={activeLessonSpec.command}
      onBoot={handleBoot}
      onRun={handleRun}
      onReset={handleReset}
      onLessonSelect={handleLessonSelect}
      onFileSelect={handleFileSelect}
      onFileChange={handleFileChange}
      onRelationSelect={(name) => void handleRelationSelect(name)}
      onTerminalSubmit={handleTerminalSubmit}
    />
  );
}
