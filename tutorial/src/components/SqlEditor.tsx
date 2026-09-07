import { useMemo, useRef } from "react";
import type { KeyboardEvent, UIEvent } from "react";
import type { TutorialFile } from "../types";
import { Icon } from "./Icon";

interface SqlEditorProps {
  files: TutorialFile[];
  activeFilePath: string;
  disabled?: boolean;
  runLabel?: string;
  onFileSelect: (path: string) => void;
  onFileChange: (path: string, content: string) => void;
  onFileRestore?: (path: string) => void;
  onRun: () => void;
}

export function SqlEditor({
  files,
  activeFilePath,
  disabled = false,
  runLabel = "Run lesson",
  onFileSelect,
  onFileChange,
  onFileRestore,
  onRun,
}: SqlEditorProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const gutterRef = useRef<HTMLPreElement>(null);
  const activeFile = files.find((file) => file.path === activeFilePath) ?? files[0];
  const lineNumbers = useMemo(() => {
    if (!activeFile) return "1";
    return Array.from({ length: activeFile.content.split("\n").length }, (_, index) => index + 1).join(
      "\n",
    );
  }, [activeFile]);

  if (!activeFile) {
    return (
      <section className="editor-panel empty-panel" aria-label="SQL editor">
        <Icon name="file" />
        <p>No tutorial files are loaded.</p>
      </section>
    );
  }

  function handleKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (disabled) return;
    if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
      event.preventDefault();
      onRun();
      return;
    }

    // Preserve normal Tab navigation so keyboard users can leave the editor.
    if (event.key !== "Tab" || !event.altKey || event.metaKey || event.ctrlKey || !activeFile.editable) return;
    event.preventDefault();
    const target = event.currentTarget;
    const start = target.selectionStart;
    const end = target.selectionEnd;
    onFileChange(activeFile.path, `${activeFile.content.slice(0, start)}  ${activeFile.content.slice(end)}`);
    requestAnimationFrame(() => textareaRef.current?.setSelectionRange(start + 2, start + 2));
  }

  function syncGutter(event: UIEvent<HTMLTextAreaElement>) {
    if (gutterRef.current) gutterRef.current.scrollTop = event.currentTarget.scrollTop;
  }

  return (
    <section className="editor-panel" aria-labelledby="editor-heading">
      <div className="file-tabs" role="tablist" aria-label="Tutorial files">
        {files.map((file) => (
          <button
            type="button"
            role="tab"
            aria-selected={file.path === activeFile.path}
            aria-controls="code-editor-panel"
            className="file-tab"
            data-active={file.path === activeFile.path}
            disabled={disabled}
            key={file.path}
            onClick={() => onFileSelect(file.path)}
          >
            <Icon name="file" size={14} />
            <span>{file.label}</span>
            {file.dirty ? <span className="dirty-dot" aria-label="Modified" /> : null}
          </button>
        ))}
      </div>

      <div className="editor-toolbar">
        <div className="editor-path">
          <Icon name="code" size={15} />
          <h2 id="editor-heading">{activeFile.path}</h2>
        </div>
        <div className="editor-toolbar-meta">
          {onFileRestore && activeFile.editable ? (
            <button type="button" className="restore-file" disabled={disabled || !activeFile.dirty}
              onClick={() => onFileRestore(activeFile.path)} title="Restore this file to the lesson version">
              Restore file
            </button>
          ) : null}
          <span>{activeFile.language.toUpperCase()}</span>
          {activeFile.editable ? <span className="editable-badge">Editable</span> : null}
        </div>
      </div>

      <div
        className="code-editor"
        id="code-editor-panel"
        role="tabpanel"
        aria-label={`${activeFile.label} editor`}
      >
        <pre className="line-numbers" ref={gutterRef} aria-hidden="true">
          {lineNumbers}
        </pre>
        <label className="sr-only" htmlFor="tutorial-sql-editor">
          Edit {activeFile.path}
        </label>
        <textarea
          id="tutorial-sql-editor"
          ref={textareaRef}
          className="code-textarea"
          value={activeFile.content}
          readOnly={!activeFile.editable}
          disabled={disabled}
          onChange={(event) => onFileChange(activeFile.path, event.target.value)}
          onKeyDown={handleKeyDown}
          onScroll={syncGutter}
          autoCapitalize="off"
          autoCorrect="off"
          spellCheck={false}
          wrap="off"
        />
      </div>

      <footer className="editor-footer">
        <span>
          <span className="keyboard-key">Ctrl / ⌘</span>
          <span className="keyboard-key">↵</span>
          {runLabel}
        </span>
        <span>Tab moves focus · {activeFile.content.split("\n").length} lines</span>
      </footer>
    </section>
  );
}
