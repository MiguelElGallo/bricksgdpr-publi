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
  onFileSelect,
  onFileChange,
  onRelationSelect,
  onTerminalSubmit,
}: TutorialWorkspaceProps) {
  const activeFile = files.find((file) => file.path === activeFilePath) ?? files[0];

  function runActiveLesson() {
    if (!activeFile) return;
    const request: RunRequest = {
      lessonId: activeLessonId,
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
        onBoot={onBoot}
        onRun={runActiveLesson}
        onReset={onReset}
      />
      <BoundaryNotice />
      <main className="studio-grid" id="tutorial-workspace">
        <LessonPanel
          lesson={lesson}
          lessons={lessons}
          activeLessonId={activeLessonId}
          selectionDisabled={engineStatus === "booting" || engineStatus === "running"}
          onLessonSelect={onLessonSelect}
        />
        <div className="workbench-column">
          <SqlEditor
            files={files}
            activeFilePath={activeFilePath}
            disabled={engineStatus === "running"}
            onFileSelect={onFileSelect}
            onFileChange={onFileChange}
            onRun={runActiveLesson}
          />
          <TerminalPanel
            entries={terminal}
            engineStatus={engineStatus}
            onSubmit={onTerminalSubmit}
          />
        </div>
        <DataPanel
          key={activeLessonId}
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
