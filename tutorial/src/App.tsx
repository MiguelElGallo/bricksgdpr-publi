import { useEffect, useRef, useState } from "react";
import { TutorialWorkspace } from "./components";
import { BrowserDbtEngine, parseDbtCommand } from "./engine";
import type { CatalogRelation, RawQueryResult, RuntimeInfo } from "./engine";
import {
  LESSON_OPTIONS,
  LESSONS,
  getLessonStep,
  getLessonSpec,
  invocationIncludesRequiredResources,
  tutorialLocationFromSearch,
} from "./lesson/lessons";
import type { LessonRunSpec, LessonStepSpec, TutorialLocation } from "./lesson/lessons";
import { createTutorialFiles, filesForLesson, initialProjectFiles, mergeProjectFiles } from "./lesson/project";
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
  selectedStepId: string | null;
  stepProofResults: Record<string, QueryResult>;
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

function createInitialLessonSessions(initialLocation?: TutorialLocation): LessonSessions {
  return LESSONS.reduce((sessions, lesson) => {
    const requestedStepId = initialLocation?.lessonId === lesson.id ? initialLocation.stepId : null;
    const selectedStep = getLessonStep(lesson, requestedStepId);
    sessions[lesson.id] = {
      tasks: createInitialTasks(lesson.id),
      activeFilePath: selectedStep?.focusFilePath ?? lesson.filePaths[0],
      selectedStepId: selectedStep?.id ?? null,
      stepProofResults: {},
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

function withGuidedProgress(tasks: LessonTask[], completedIds: readonly string[]): LessonTask[] {
  const nextActive = tasks.find((task) => !completedIds.includes(task.id))?.id;
  return withTaskProgress(tasks, completedIds, nextActive);
}

function completedTaskIds(tasks: LessonTask[]) {
  return tasks.filter((task) => task.status === "complete").map((task) => task.id);
}

function commandMatchesArguments(command: string, args: string[]) {
  const expectedArgs = parseDbtCommand(command);
  return (
    expectedArgs.length === args.length &&
    expectedArgs.every((expected, index) => expected === args[index])
  );
}

function toLessonDefinition(
  lessonId: LessonId,
  session: LessonSessionState,
): LessonDefinition {
  const lesson = getLessonSpec(lessonId);
  const taskById = new Map(session.tasks.map((task) => [task.id, task]));
  return {
    id: lesson.id,
    number: lesson.number,
    total: LESSONS.length,
    title: lesson.title,
    summary: lesson.summary,
    objective: lesson.objective,
    duration: lesson.duration,
    experiment: lesson.experiment,
    tasks: session.tasks,
    guideSteps: lesson.steps?.map((step, index) => ({
      id: step.id,
      number: index + 1,
      total: lesson.steps?.length ?? 0,
      title: step.title,
      buildsOn: step.buildsOn,
      why: step.why,
      change: step.change,
      observe: step.observe,
      experiment: step.experiment,
      command: step.command,
      status: taskById.get(step.id)?.status ?? "pending",
    })),
  };
}

function resultCell(value: unknown): ResultCell {
  if (value === null || ["string", "number", "boolean"].includes(typeof value)) {
    return value as ResultCell;
  }
  return String(value);
}

function toQueryResult(raw: RawQueryResult, label: string, elapsedMs?: number, sql?: string): QueryResult {
  const columns = raw.columns.map((column, index) => ({
    key: `${column.name}-${index}`,
    label: column.name,
    type: column.type,
  }));
  return {
    label,
    elapsedMs,
    sql,
    truncated: raw.truncated,
    rowCount: raw.rows.length,
    columns,
    rows: raw.rows.map((values) =>
      Object.fromEntries(columns.map((column, index) => [column.key, resultCell(values[index])])),
    ),
  };
}

function relationLayer(name: string) {
  if (name === "demo_customer_map") return "Mapping";
  if (name === "int_current_customers") return "Current state";
  if (["customer", "customer_services", "invoices", "customer_deletion_confirmations"].includes(name)) return "Sources";
  if (["int_customer_deletion_requests", "int_customer_deletion_authorizations", "int_customer_deletion_plan", "int_terminal_deleted_customer_ssns"].includes(name)) return "Deletion controls";
  if (name.startsWith("stg_") || name.startsWith("quarantine_")) return "Layer1";
  if (name.startsWith("dim_") || name.startsWith("fct_")) return "Layer3";
  return "Layer2";
}

function relationKind(relation: CatalogRelation): RelationKind {
  if (["customer", "customer_services", "invoices", "customer_deletion_confirmations"].includes(relation.name)) return "seed";
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
  const initialLocation = useRef<TutorialLocation>(
    tutorialLocationFromSearch(window.location.search),
  );
  const [activeLessonId, setActiveLessonId] = useState<LessonId>(
    initialLocation.current.lessonId,
  );
  const [lessonSessions, setLessonSessions] = useState<LessonSessions>(() =>
    createInitialLessonSessions(initialLocation.current),
  );
  const [engineStatus, setEngineStatus] = useState<EngineStatus>("idle");
  const [engineMessage, setEngineMessage] = useState("Runtime not started");
  const [files, setFiles] = useState<TutorialFile[]>(() => createTutorialFiles());
  const [relations, setRelations] = useState<RelationSummary[]>([]);
  const [terminal, setTerminal] = useState<TerminalEntry[]>(initialTerminal);
  const engineRef = useRef<BrowserDbtEngine | null>(null);
  const relationRequestGeneration = useRef(0);
  const entrySequence = useRef(0);

  const activeLessonSpec = getLessonSpec(activeLessonId);
  const activeSession = lessonSessions[activeLessonId];
  const activeStep = getLessonStep(activeLessonSpec, activeSession.selectedStepId);
  const activeRunSpec: LessonRunSpec = activeStep ?? activeLessonSpec;
  const lesson = toLessonDefinition(activeLessonId, activeSession);
  const visibleFiles = filesForLesson(files, activeLessonId, activeSession.selectedStepId);
  const visibleRelationNames = new Set(
    activeStep?.visibleRelationNames ?? activeLessonSpec.visibleRelationNames,
  );
  const visibleRelations = relations.filter((relation) => visibleRelationNames.has(relation.name));

  useEffect(() => {
    const url = new URL(window.location.href);
    url.searchParams.set("lesson", activeLessonId);
    if (activeStep) url.searchParams.set("step", activeStep.id);
    else url.searchParams.delete("step");
    window.history.replaceState(window.history.state, "", url);
  }, [activeLessonId, activeStep]);

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

  function invalidatePendingRelationQueries() {
    relationRequestGeneration.current += 1;
  }

  function markEngineReadyForAllLessons() {
    setLessonSessions((current) =>
      LESSONS.reduce((next, candidate) => {
        if (candidate.steps) {
          next[candidate.id] = current[candidate.id];
          return next;
        }
        next[candidate.id] = {
          ...current[candidate.id],
          tasks: withTaskProgress(current[candidate.id].tasks, ["boot"], "build"),
        };
        return next;
      }, { ...current }),
    );
  }

  function invalidateLessonProof(lessonId: LessonId, bootComplete: boolean) {
    const lessonSpec = getLessonSpec(lessonId);
    setLessonSessions((current) => ({
      ...current,
      [lessonId]: {
        ...current[lessonId],
        result: null,
        stepProofResults: lessonSpec.steps ? {} : current[lessonId].stepProofResults,
        selectedRelation: null,
        tasks: lessonSpec.steps
          ? withGuidedProgress(current[lessonId].tasks, [])
          : withTaskProgress(
              current[lessonId].tasks,
              bootComplete ? ["boot"] : [],
              bootComplete ? "build" : "boot",
            ),
      },
    }));
  }

  function invalidateGuidedFrom(lessonId: LessonId, stepId: string) {
    const lessonSpec = getLessonSpec(lessonId);
    const stepIndex = lessonSpec.steps?.findIndex((step) => step.id === stepId) ?? -1;
    if (!lessonSpec.steps || stepIndex < 0) return;
    const invalidatedIds = new Set(lessonSpec.steps.slice(stepIndex).map((step) => step.id));
    setLessonSessions((current) => {
      const session = current[lessonId];
      const retainedCompletedIds = completedTaskIds(session.tasks).filter(
        (taskId) => !invalidatedIds.has(taskId),
      );
      const retainedProofs = Object.fromEntries(
        Object.entries(session.stepProofResults).filter(([proofStepId]) =>
          !invalidatedIds.has(proofStepId),
        ),
      );
      const selectedWasInvalidated =
        session.selectedStepId !== null && invalidatedIds.has(session.selectedStepId);
      return {
        ...current,
        [lessonId]: {
          ...session,
          tasks: withGuidedProgress(session.tasks, retainedCompletedIds),
          stepProofResults: retainedProofs,
          result: selectedWasInvalidated ? null : session.result,
          selectedRelation: selectedWasInvalidated ? null : session.selectedRelation,
        },
      };
    });
  }

  function invalidateAllLessonProofs(bootComplete: boolean) {
    setLessonSessions((current) =>
      LESSONS.reduce((next, candidate) => {
        next[candidate.id] = {
          ...current[candidate.id],
          result: null,
          stepProofResults: candidate.steps ? {} : current[candidate.id].stepProofResults,
          selectedRelation: null,
          tasks: candidate.steps
            ? withGuidedProgress(current[candidate.id].tasks, [])
            : withTaskProgress(
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
    invalidateAllLessonProofs(false);
    setRelations([]);
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

  async function validateCheckpoint(
    engine: BrowserDbtEngine,
    lessonId: LessonId,
    runSpec: LessonRunSpec,
    stepId: string | null,
  ) {
    const lessonSpec = getLessonSpec(lessonId);
    const startedAt = performance.now();
    const raw = await engine.query(runSpec.proof.sql);
    if (!isCurrentEngine(engine)) return;
    const queryResult = toQueryResult(
      raw,
      runSpec.proof.label,
      Math.round(performance.now() - startedAt),
      runSpec.proof.sql,
    );
    const passed = runSpec.proof.validate(raw);
    queryResult.verification = passed ? "passed" : "failed";
    setLessonSessions((current) => {
      const session = current[lessonId];
      if (stepId && lessonSpec.steps) {
        const completedIds = new Set(completedTaskIds(session.tasks));
        if (passed) completedIds.add(stepId);
        const isStillSelected = session.selectedStepId === stepId;
        return {
          ...current,
          [lessonId]: {
            ...session,
            result: isStillSelected ? queryResult : session.result,
            selectedRelation: isStillSelected
              ? runSpec.proof.selectedRelation
              : session.selectedRelation,
            tasks: withGuidedProgress(session.tasks, [...completedIds]),
            stepProofResults: passed
              ? { ...session.stepProofResults, [stepId]: queryResult }
              : session.stepProofResults,
          },
        };
      }
      return {
        ...current,
        [lessonId]: {
          ...session,
          result: queryResult,
          selectedRelation: runSpec.proof.selectedRelation,
          tasks: passed
            ? withTaskProgress(
                session.tasks,
                lessonSpec.tasks.map((task) => task.id),
              )
            : withTaskProgress(session.tasks, ["boot", "build"], lessonSpec.tasks[2]?.id),
        },
      };
    });

    appendTerminal(passed ? "success" : "error", passed ? runSpec.proof.successMessage : runSpec.proof.failureMessage);
  }

  async function runDbtCommand(
    command: string,
    lessonId: LessonId,
    stepId: string | null = null,
    origin: "guided" | "terminal" = "guided",
  ) {
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
    const requestedStep = stepId
      ? (lessonSpec.steps?.find((step) => step.id === stepId) ?? null)
      : null;
    const activeTerminalStep =
      origin === "terminal" && lessonSpec.steps
        ? (lessonSpec.steps.find(
            (step) => step.id === lessonSessions[lessonId].selectedStepId,
          ) ?? null)
        : null;
    const terminalMatchesSelectedStep = Boolean(
      activeTerminalStep && commandMatchesArguments(activeTerminalStep.command, args),
    );
    const terminalMatchesLesson =
      origin === "terminal" &&
      !lessonSpec.steps &&
      commandMatchesArguments(lessonSpec.command, args);
    const selectedStep =
      requestedStep ?? (terminalMatchesSelectedStep ? activeTerminalStep : null);
    const terminalMatchesGuidedCommand =
      terminalMatchesSelectedStep || terminalMatchesLesson;
    const runSpec: LessonRunSpec = selectedStep ?? lessonSpec;
    const mutatesRelations = ["build", "run", "seed"].includes(args[0]);
    const gradesCheckpoint =
      args[0] === "build" &&
      (origin === "terminal"
        ? terminalMatchesGuidedCommand
        : !lessonSpec.steps || selectedStep !== null);
    if (mutatesRelations) {
      invalidatePendingRelationQueries();
      if (origin === "terminal" && !terminalMatchesGuidedCommand) {
        invalidateAllLessonProofs(true);
      } else if (selectedStep) {
        invalidateGuidedFrom(lessonId, selectedStep.id);
      } else {
        invalidateLessonProof(lessonId, true);
      }
    }

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

      if (gradesCheckpoint) {
        if (
          invocationIncludesRequiredResources(
            runSpec.requiredSuccessfulResources,
            invocation.results,
          )
        ) {
          await validateCheckpoint(engine, lessonId, runSpec, selectedStep?.id ?? null);
          if (!isCurrentEngine(engine)) return;
        } else {
          appendTerminal(
            "info",
            `dbt succeeded, but it did not rebuild every required resource for “${selectedStep?.title ?? lessonSpec.title}”. Run the guided command to grade it.`,
          );
        }
      } else if (args[0] === "build" && origin === "terminal") {
        appendTerminal(
          "info",
          "The terminal build ran, but it did not match the guided command currently shown. Run that exact command to grade progress.",
        );
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
      setEngineStatus(engine.isStopped ? "error" : "ready");
      setEngineMessage(engine.isStopped ? "Runtime stopped; boot again to keep your SQL edits" : "Command failed; edit and retry");
      appendTerminal("error", error instanceof Error ? error.message : String(error));
    }
  }

  function handleRun(request: RunRequest) {
    void runDbtCommand(request.command, request.lessonId, request.stepId ?? null);
  }

  function handleReset() {
    invalidatePendingRelationQueries();
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

  function selectGuidedStep(lessonId: LessonId, step: LessonStepSpec) {
    setLessonSessions((current) => {
      const session = current[lessonId];
      const cachedProof = session.stepProofResults[step.id] ?? null;
      return {
        ...current,
        [lessonId]: {
          ...session,
          selectedStepId: step.id,
          activeFilePath: step.focusFilePath,
          result: cachedProof,
          selectedRelation: cachedProof ? step.proof.selectedRelation : null,
        },
      };
    });
  }

  function handleStepSelect(stepId: string) {
    if (engineStatus === "booting" || engineStatus === "running") return;
    const step = activeLessonSpec.steps?.find((candidate) => candidate.id === stepId);
    if (step) {
      invalidatePendingRelationQueries();
      selectGuidedStep(activeLessonId, step);
    }
  }

  function handleFileSelect(path: string) {
    if (engineStatus === "booting" || engineStatus === "running") return;
    invalidatePendingRelationQueries();
    const owningStep = activeLessonSpec.steps?.find((step) => step.revealFilePaths.includes(path));
    if (owningStep) {
      setLessonSessions((current) => {
        const session = current[activeLessonId];
        const cachedProof = session.stepProofResults[owningStep.id] ?? null;
        return {
          ...current,
          [activeLessonId]: {
            ...session,
            selectedStepId: owningStep.id,
            activeFilePath: path,
            result: cachedProof,
            selectedRelation: cachedProof ? owningStep.proof.selectedRelation : null,
          },
        };
      });
      return;
    }
    setLessonSessions((current) => ({
      ...current,
      [activeLessonId]: { ...current[activeLessonId], activeFilePath: path },
    }));
  }

  function handleFileChange(path: string, content: string) {
    if (engineStatus === "booting" || engineStatus === "running") return;
    invalidatePendingRelationQueries();
    setFiles((current) =>
      current.map((file) => (file.path === path ? { ...file, content, dirty: content !== initialProjectFiles[path] } : file)),
    );
    const customerLesson = getLessonSpec("customer-flow");
    const owningCustomerStep = customerLesson.steps?.find((step) =>
      step.revealFilePaths.includes(path),
    );
    const bootComplete = engineStatus === "ready";
    if (owningCustomerStep) {
      invalidateGuidedFrom("customer-flow", owningCustomerStep.id);
      if (["staging", "current"].includes(owningCustomerStep.id)) {
        invalidateLessonProof("invoice-quarantine", bootComplete);
      }
    } else if (getLessonSpec("invoice-quarantine").filePaths.includes(path)) {
      invalidateLessonProof("invoice-quarantine", bootComplete);
    } else {
      invalidateAllLessonProofs(bootComplete);
    }
    setRelations([]);
  }

  function handleFileRestore(path: string) {
    const original = initialProjectFiles[path];
    if (typeof original !== "string") return;
    handleFileChange(path, original);
    appendTerminal("info", `Restored ${path}. Run the step again to verify it.`);
  }

  async function handleRelationSelect(name: string) {
    if (engineStatus !== "ready") return;
    relationRequestGeneration.current += 1;
    const requestGeneration = relationRequestGeneration.current;
    const lessonId = activeLessonId;
    const stepId = lessonSessions[lessonId].selectedStepId;
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
      const previewSql = `select * from ${quotedSchema}.${quotedName} limit 50`;
      const raw = await engine.query(previewSql);
      if (
        !isCurrentEngine(engine) ||
        relationRequestGeneration.current !== requestGeneration
      ) {
        return;
      }
      const queryResult = toQueryResult(
        raw,
        `${relation.schema}.${relation.name}`,
        Math.round(performance.now() - startedAt),
        previewSql,
      );
      queryResult.truncated = raw.truncated || (relation.rowCount ?? raw.rows.length) > raw.rows.length;
      setLessonSessions((current) => ({
        ...current,
        [lessonId]:
          current[lessonId].selectedStepId === stepId
            ? { ...current[lessonId], result: queryResult }
            : current[lessonId],
      }));
    } catch (error) {
      if (
        !isCurrentEngine(engine) ||
        relationRequestGeneration.current !== requestGeneration
      ) {
        return;
      }
      if (engine.isStopped) {
        setEngineStatus("error");
        setEngineMessage("Runtime stopped; boot again to keep your SQL edits");
      }
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
    void runDbtCommand(command, activeLessonId, null, "terminal");
  }

  return (
    <TutorialWorkspace
      lesson={lesson}
      lessons={LESSON_OPTIONS}
      activeLessonId={activeLessonId}
      selectedStepId={activeSession.selectedStepId}
      files={visibleFiles}
      activeFilePath={activeSession.activeFilePath}
      relations={visibleRelations}
      selectedRelation={activeSession.selectedRelation}
      result={activeSession.result}
      terminal={terminal}
      engineStatus={engineStatus}
      engineMessage={engineMessage}
      command={activeRunSpec.command}
      onBoot={handleBoot}
      onRun={handleRun}
      onReset={handleReset}
      onLessonSelect={handleLessonSelect}
      onStepSelect={handleStepSelect}
      onFileSelect={handleFileSelect}
      onFileChange={handleFileChange}
      onFileRestore={handleFileRestore}
      onRelationSelect={(name) => void handleRelationSelect(name)}
      onTerminalSubmit={handleTerminalSubmit}
    />
  );
}
