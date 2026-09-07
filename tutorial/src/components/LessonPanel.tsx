import type { LessonDefinition, LessonId, LessonOption, TaskStatus } from "../types";
import { Icon } from "./Icon";

interface LessonPanelProps {
  lesson: LessonDefinition;
  lessons: LessonOption[];
  activeLessonId: LessonId;
  selectedStepId: string | null;
  selectionDisabled?: boolean;
  onLessonSelect: (lessonId: LessonId) => void;
  onStepSelect: (stepId: string) => void;
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
  selectedStepId,
  selectionDisabled = false,
  onLessonSelect,
  onStepSelect,
}: LessonPanelProps) {
  const guideSteps = lesson.guideSteps ?? [];
  const hasGuide = guideSteps.length > 0;
  const selectedStepIndex = hasGuide
    ? Math.max(
        0,
        guideSteps.findIndex((step) => step.id === selectedStepId),
      )
    : -1;
  const selectedStep = selectedStepIndex >= 0 ? guideSteps[selectedStepIndex] : null;
  const completed = hasGuide
    ? guideSteps.filter((step) => step.status === "complete").length
    : lesson.tasks.filter((task) => task.status === "complete").length;
  const progressTotal = hasGuide ? guideSteps.length : lesson.tasks.length;
  const progress = progressTotal === 0 ? 0 : Math.round((completed / progressTotal) * 100);
  const experiment = selectedStep?.experiment ?? lesson.experiment;
  const previousStep = selectedStepIndex > 0 ? guideSteps[selectedStepIndex - 1] : null;
  const nextStep =
    selectedStepIndex >= 0 && selectedStepIndex < guideSteps.length - 1
      ? guideSteps[selectedStepIndex + 1]
      : null;

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

        {progress === 100 ? (
          <section className="lesson-complete" aria-label="Lesson complete">
            <strong>Lesson complete</strong>
            <p>The fixture checks passed. Try the experiment below, or choose the other lesson.</p>
          </section>
        ) : selectedStep?.status === "complete" ? (
          <p className="checkpoint-complete">Checkpoint passed. Inspect the result, then choose Next.</p>
        ) : null}

        {hasGuide && selectedStep ? (
          <>
            <section className="guide-card" aria-labelledby="selected-guide-step-title">
              <header className="guide-card-header">
                <span>
                  Step {selectedStep.number} of {selectedStep.total}
                </span>
                <h2 id="selected-guide-step-title">{selectedStep.title}</h2>
              </header>
              <dl className="guide-card-fields">
                <div>
                  <dt>Why</dt>
                  <dd>{selectedStep.why}</dd>
                </div>
                <div>
                  <dt>Builds on</dt>
                  <dd>{selectedStep.buildsOn}</dd>
                </div>
                <div>
                  <dt>Change</dt>
                  <dd>{selectedStep.change}</dd>
                </div>
                <div>
                  <dt>Run</dt>
                  <dd>
                    <code>{selectedStep.command}</code>
                  </dd>
                </div>
                <div>
                  <dt>You should see</dt>
                  <dd>{selectedStep.observe}</dd>
                </div>
              </dl>
              <div className="guide-step-controls" aria-label="Tutorial step navigation">
                <button
                  type="button"
                  disabled={selectionDisabled || !previousStep}
                  onClick={() => previousStep && onStepSelect(previousStep.id)}
                >
                  <Icon className="guide-back-icon" name="chevron" size={14} />
                  Previous
                </button>
                <button
                  type="button"
                  disabled={selectionDisabled || !nextStep}
                  onClick={() => nextStep && onStepSelect(nextStep.id)}
                >
                  Next
                  <Icon name="chevron" size={14} />
                </button>
              </div>
              <span className="sr-only" aria-live="polite" aria-atomic="true">
                Step {selectedStep.number} of {selectedStep.total}: {selectedStep.title}
              </span>
            </section>

            <section className="task-section guide-step-section" aria-labelledby="guide-step-title">
              <div className="section-heading">
                <h2 id="guide-step-title">Tutorial steps</h2>
                <span>
                  {completed}/{guideSteps.length}
                </span>
              </div>
              <ol className="guide-step-list">
                {guideSteps.map((step) => {
                  const isSelected = step.id === selectedStep.id;
                  return (
                    <li
                      className="guide-step-item"
                      data-selected={isSelected}
                      data-status={step.status}
                      key={step.id}
                    >
                      <button
                        type="button"
                        aria-label={`Step ${step.number} of ${step.total}: ${step.title}. ${statusText[step.status]}`}
                        aria-current={isSelected ? "step" : undefined}
                        disabled={selectionDisabled}
                        onClick={() => onStepSelect(step.id)}
                      >
                        <span className="guide-step-marker" aria-hidden="true">
                          {step.status === "complete" ? <Icon name="check" size={14} /> : step.number}
                        </span>
                        <span className="guide-step-button-copy">
                          <span className="guide-step-button-kicker">
                            Step {step.number} of {step.total}
                          </span>
                          <span className="guide-step-button-title">{step.title}</span>
                        </span>
                        <span className="sr-only">{statusText[step.status]}</span>
                      </button>
                    </li>
                  );
                })}
              </ol>
            </section>
          </>
        ) : (
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
        )}
        {experiment ? (
          <section className="experiment-card" aria-labelledby="experiment-title">
            <h2 id="experiment-title">Try an experiment</h2>
            <p>{experiment.prompt}</p>
            <details><summary>Show a hint</summary><p>{experiment.hint}</p></details>
            <details><summary>Explain the result</summary><p>{experiment.explanation}</p></details>
            <small>Use Restore file after experimenting, then rerun the step to restore its proof.</small>
          </section>
        ) : null}
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
