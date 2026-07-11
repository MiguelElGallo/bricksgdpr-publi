export type EngineStatus = "idle" | "booting" | "ready" | "running" | "error";

export type LessonId = "invoice-quarantine" | "customer-flow";

export type TaskStatus = "pending" | "active" | "complete";

export interface LessonTask {
  id: string;
  title: string;
  detail: string;
  status: TaskStatus;
}

export interface LessonGuideStep {
  id: string;
  number: number;
  total: number;
  title: string;
  buildsOn: string;
  why: string;
  change: string;
  observe: string;
  command: string;
  status: TaskStatus;
}

export interface LessonDefinition {
  id: LessonId;
  number: number;
  total: number;
  title: string;
  summary: string;
  objective: string;
  duration: string;
  tasks: LessonTask[];
  guideSteps?: LessonGuideStep[];
}

export interface LessonOption {
  id: LessonId;
  number: number;
  title: string;
}

export type TutorialFileLanguage = "sql" | "yaml" | "csv";

export interface TutorialFile {
  path: string;
  label: string;
  language: TutorialFileLanguage;
  content: string;
  editable: boolean;
  dirty?: boolean;
}

export interface RelationColumn {
  name: string;
  type: string;
  nullable?: boolean;
}

export type RelationKind = "seed" | "view" | "table";

export interface RelationSummary {
  name: string;
  schema: string;
  layer: string;
  kind: RelationKind;
  rowCount?: number;
  columns: RelationColumn[];
}

export interface ResultColumn {
  key: string;
  label: string;
  type?: string;
}

export type ResultCell = string | number | boolean | null;

export interface QueryResult {
  columns: ResultColumn[];
  rows: Record<string, ResultCell>[];
  rowCount: number;
  elapsedMs?: number;
  label?: string;
}

export type TerminalEntryTone = "command" | "info" | "success" | "error";

export interface TerminalEntry {
  id: string;
  text: string;
  tone: TerminalEntryTone;
  timestamp?: string;
}

export interface RunRequest {
  lessonId: LessonId;
  stepId?: string;
  command: string;
  sql: string;
  activeFilePath: string;
}

export interface TutorialWorkspaceProps {
  lesson: LessonDefinition;
  lessons: LessonOption[];
  activeLessonId: LessonId;
  selectedStepId: string | null;
  files: TutorialFile[];
  activeFilePath: string;
  relations: RelationSummary[];
  selectedRelation: string | null;
  result: QueryResult | null;
  terminal: TerminalEntry[];
  engineStatus: EngineStatus;
  engineMessage?: string;
  command: string;
  onBoot: () => void;
  onRun: (request: RunRequest) => void;
  onReset: () => void;
  onLessonSelect: (lessonId: LessonId) => void;
  onStepSelect: (stepId: string) => void;
  onFileSelect: (path: string) => void;
  onFileChange: (path: string, content: string) => void;
  onRelationSelect: (name: string) => void;
  onTerminalSubmit: (command: string) => void;
}
