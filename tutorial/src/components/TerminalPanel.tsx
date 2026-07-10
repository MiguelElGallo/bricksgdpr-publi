import { useEffect, useRef, useState } from "react";
import type { FormEvent } from "react";
import type { EngineStatus, TerminalEntry } from "../types";
import { Icon } from "./Icon";

interface TerminalPanelProps {
  entries: TerminalEntry[];
  engineStatus: EngineStatus;
  onSubmit: (command: string) => void;
}

export function TerminalPanel({ entries, engineStatus, onSubmit }: TerminalPanelProps) {
  const [command, setCommand] = useState("");
  const logRef = useRef<HTMLDivElement>(null);
  const disabled = engineStatus === "booting" || engineStatus === "running";

  useEffect(() => {
    const log = logRef.current;
    if (log) log.scrollTop = log.scrollHeight;
  }, [entries]);

  function submitCommand(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalized = command.trim();
    if (!normalized) return;
    onSubmit(normalized);
    setCommand("");
  }

  return (
    <section className="terminal-panel" aria-labelledby="terminal-title">
      <header className="terminal-header">
        <div>
          <Icon name="terminal" size={16} />
          <h2 id="terminal-title">Terminal</h2>
        </div>
        <span>local · browser</span>
      </header>
      <div
        className="terminal-log"
        ref={logRef}
        role="log"
        aria-live="polite"
        aria-label="Command output"
      >
        {entries.length === 0 ? (
          <p className="terminal-empty">Boot the local engine to begin.</p>
        ) : (
          entries.map((entry) => (
            <div className="terminal-entry" data-tone={entry.tone} key={entry.id}>
              <span className="terminal-entry-mark" aria-hidden="true">
                {entry.tone === "command" ? "$" : entry.tone === "error" ? "!" : "›"}
              </span>
              <pre>{entry.text}</pre>
              {entry.timestamp ? <time>{entry.timestamp}</time> : null}
            </div>
          ))
        )}
      </div>
      <form className="terminal-input-row" onSubmit={submitCommand}>
        <label className="sr-only" htmlFor="terminal-command">
          Enter a dbt command
        </label>
        <span aria-hidden="true">$</span>
        <input
          id="terminal-command"
          value={command}
          onChange={(event) => setCommand(event.target.value)}
          placeholder={engineStatus === "ready" ? "dbt build" : "Boot engine first"}
          autoCapitalize="off"
          autoComplete="off"
          autoCorrect="off"
          spellCheck={false}
          disabled={disabled}
        />
        <button type="submit" disabled={disabled || command.trim().length === 0}>
          Run
          <span aria-hidden="true">↵</span>
        </button>
      </form>
    </section>
  );
}
