import type { RunRequest, TutorialWorkspaceProps } from "../types";
import { BoundaryNotice } from "./BoundaryNotice";
import { DataPanel } from "./DataPanel";
import { LessonPanel } from "./LessonPanel";
import { SqlEditor } from "./SqlEditor";
import { StudioHeader } from "./StudioHeader";
import { TerminalPanel } from "./TerminalPanel";

export function TutorialWorkspace({
  lesson,
  lessons,
  activeLessonId,
  selectedStepId,
  files,
  activeFilePath,
  relations,
  selectedRelation,
  result,
  terminal,
  engineStatus,
  engineMessage,
  command,
  onBoot,
  onRun,
  onReset,
  onLessonSelect,
  onStepSelect,
  onFileSelect,
  onFileChange,
  onFileRestore,
  onRelationSelect,
  onTerminalSubmit,
}: TutorialWorkspaceProps) {
  const activeFile = files.find((file) => file.path === activeFilePath) ?? files[0];
  const hasGuide = Boolean(lesson.guideSteps?.length);
  const runLabel = hasGuide ? "Run step" : "Run lesson";

  function runActiveLesson() {
    if (!activeFile) return;
    const request: RunRequest = {
      lessonId: activeLessonId,
      ...(selectedStepId ? { stepId: selectedStepId } : {}),
      command,
      sql: activeFile.content,
      activeFilePath: activeFile.path,
    };
    onRun(request);
  }

  return (
    <div className="tutorial-app" data-engine-status={engineStatus}>
      <a className="skip-link" href="#tutorial-workspace">
        Skip to tutorial workspace
      </a>
      <StudioHeader
        engineStatus={engineStatus}
        engineMessage={engineMessage}
        lessonNumber={lesson.number}
        lessonTotal={lesson.total}
        runLabel={runLabel}
        onBoot={onBoot}
        onRun={runActiveLesson}
        onReset={onReset}
      />
      <BoundaryNotice />
      <div className="runtime-guidance" aria-live="polite">
        <strong>{engineStatus === "idle" ? "Start here" : engineStatus === "error" ? "Startup needs attention" : "In this tab"}</strong>
        <span>{engineStatus === "idle"
          ? "Boot the engine, read the step, then run it. The first boot downloads Python and dbt; it can take a minute."
          : engineStatus === "booting"
            ? `${engineMessage ?? "Starting…"}. Keep this tab open while the runtime loads.`
            : engineStatus === "error"
              ? "Check the terminal, then choose Boot engine to retry. Your SQL edits are kept; rebuild to verify them."
              : engineStatus === "running"
                ? "dbt is running. Follow the terminal output; Reset lab stops the runtime and clears this session."
                : "Edit, run, and inspect the result. Reloading clears edits and data; Restore file undoes one experiment."}</span>
      </div>
      <main className="studio-grid" id="tutorial-workspace">
        <LessonPanel
          lesson={lesson}
          lessons={lessons}
          activeLessonId={activeLessonId}
          selectedStepId={selectedStepId}
          selectionDisabled={engineStatus === "booting" || engineStatus === "running"}
          onLessonSelect={onLessonSelect}
          onStepSelect={onStepSelect}
        />
        <div className="workbench-column">
          <SqlEditor
            files={files}
            activeFilePath={activeFilePath}
            disabled={engineStatus === "booting" || engineStatus === "running"}
            runLabel={runLabel}
            onFileSelect={onFileSelect}
            onFileChange={onFileChange}
            onFileRestore={onFileRestore}
            onRun={runActiveLesson}
          />
          <TerminalPanel
            entries={terminal}
            engineStatus={engineStatus}
            onSubmit={onTerminalSubmit}
          />
        </div>
        <DataPanel
          key={`${activeLessonId}:${selectedStepId ?? "lesson"}`}
          relations={relations}
          selectedRelation={selectedRelation}
          result={result}
          disabled={engineStatus === "booting" || engineStatus === "running"}
          onRelationSelect={onRelationSelect}
        />
      </main>
    </div>
  );
}
