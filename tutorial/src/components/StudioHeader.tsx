import type { EngineStatus } from "../types";
import { Icon } from "./Icon";

interface StudioHeaderProps {
  engineStatus: EngineStatus;
  engineMessage?: string;
  lessonNumber: number;
  lessonTotal: number;
  onBoot: () => void;
  onRun: () => void;
  onReset: () => void;
}

const statusLabels: Record<EngineStatus, string> = {
  idle: "Engine offline",
  booting: "Starting engine",
  ready: "Engine ready",
  running: "Running dbt",
  error: "Engine needs attention",
};

export function StudioHeader({
  engineStatus,
  engineMessage,
  lessonNumber,
  lessonTotal,
  onBoot,
  onRun,
  onReset,
}: StudioHeaderProps) {
  const isBusy = engineStatus === "booting" || engineStatus === "running";

  return (
    <header className="studio-header">
      <div className="brand-lockup">
        <div className="brand-mark" aria-hidden="true">
          <span />
          <span />
          <span />
        </div>
        <div>
          <a className="brand-name" href="./" aria-label="bricksgdpr browser lab home">
            bricks<span>gdpr</span>
          </a>
          <p>Browser lab</p>
        </div>
      </div>

      <div className="header-lesson" aria-label={`Lesson ${lessonNumber} of ${lessonTotal}`}>
        <span>Interactive tutorial</span>
        <strong>
          Lesson {lessonNumber} <span>/ {lessonTotal}</span>
        </strong>
      </div>

      <div className="engine-cluster">
        <div
          className="engine-status"
          data-status={engineStatus}
          role="status"
          aria-live="polite"
          title={engineMessage}
        >
          <span className="status-light" aria-hidden="true" />
          <span>
            <small>Local runtime</small>
            <strong>{statusLabels[engineStatus]}</strong>
          </span>
        </div>

        <div className="header-actions" aria-label="Lab controls">
          <button
            className="icon-button"
            type="button"
            onClick={onReset}
            aria-label="Reset lab"
            title="Reset lab"
          >
            <Icon name="refresh" />
          </button>
          <button
            className="button button-secondary boot-button"
            type="button"
            onClick={onBoot}
            disabled={isBusy || engineStatus === "ready"}
          >
            <Icon name="power" />
            {engineStatus === "booting" ? "Booting…" : "Boot engine"}
          </button>
          <button
            className="button button-primary run-button"
            type="button"
            onClick={onRun}
            disabled={engineStatus !== "ready"}
          >
            <Icon name="play" size={16} />
            {engineStatus === "running" ? "Running…" : "Run lesson"}
          </button>
        </div>
      </div>
    </header>
  );
}
