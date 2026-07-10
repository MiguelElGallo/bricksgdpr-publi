import type { LessonDefinition, LessonId, LessonOption, TaskStatus } from "../types";
import { Icon } from "./Icon";

interface LessonPanelProps {
  lesson: LessonDefinition;
  lessons: LessonOption[];
  activeLessonId: LessonId;
  selectionDisabled?: boolean;
  onLessonSelect: (lessonId: LessonId) => void;
}

const statusText: Record<TaskStatus, string> = {
  pending: "Not started",
  active: "Current task",
  complete: "Complete",
};

export function LessonPanel({
  lesson,
  lessons,
  activeLessonId,
  selectionDisabled = false,
  onLessonSelect,
}: LessonPanelProps) {
  const completed = lesson.tasks.filter((task) => task.status === "complete").length;
  const progress = Math.round((completed / lesson.tasks.length) * 100);

  return (
    <aside className="lesson-panel" aria-labelledby="lesson-title">
      <div className="lesson-scroll">
        <nav className="lesson-selector" aria-label="Tutorial lesson navigation">
          <label htmlFor="tutorial-lesson-select">Choose lesson</label>
          <div className="lesson-select-control">
            <select
              id="tutorial-lesson-select"
              value={activeLessonId}
              disabled={selectionDisabled}
              onChange={(event) => onLessonSelect(event.target.value as LessonId)}
            >
              {lessons.map((option) => (
                <option value={option.id} key={option.id}>
                  {option.number}. {option.title}
                </option>
              ))}
            </select>
            <Icon name="chevron" size={14} />
          </div>
          <span className="sr-only" aria-live="polite" aria-atomic="true">
            Lesson {lesson.number} selected: {lesson.title}
          </span>
        </nav>
        <div className="lesson-kicker">
          <span>Lesson {lesson.number}</span>
          <span className="lesson-duration">{lesson.duration}</span>
        </div>
        <h1 id="lesson-title">{lesson.title}</h1>
        <p className="lesson-summary">{lesson.summary}</p>

        <section className="lesson-objective" aria-labelledby="objective-title">
          <div className="objective-icon">
            <Icon name="book" size={17} />
          </div>
          <div>
            <h2 id="objective-title">What you will prove</h2>
            <p>{lesson.objective}</p>
          </div>
        </section>

        <div className="progress-block">
          <div className="progress-copy">
            <span>Lesson progress</span>
            <strong>{progress}%</strong>
          </div>
          <div
            className="progress-track"
            role="progressbar"
            aria-label="Lesson progress"
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={progress}
          >
            <span style={{ width: `${progress}%` }} />
          </div>
        </div>

        <section className="task-section" aria-labelledby="task-title">
          <div className="section-heading">
            <h2 id="task-title">Your tasks</h2>
            <span>
              {completed}/{lesson.tasks.length}
            </span>
          </div>
          <ol className="task-list">
            {lesson.tasks.map((task, index) => (
              <li className="task-item" data-status={task.status} key={task.id}>
                <span className="task-marker" aria-hidden="true">
                  {task.status === "complete" ? <Icon name="check" size={15} /> : index + 1}
                </span>
                <div>
                  <div className="task-title-row">
                    <h3>{task.title}</h3>
                    <span className="sr-only">{statusText[task.status]}</span>
                  </div>
                  <p>{task.detail}</p>
                </div>
              </li>
            ))}
          </ol>
        </section>
      </div>

      <footer className="lesson-footer">
        <span className="synthetic-dot" aria-hidden="true" />
        <span>
          Dataset
          <strong>Reserved synthetic fixtures</strong>
        </span>
      </footer>
    </aside>
  );
}
