import type { TutorialFile } from "../types";

const rawProjectModules = import.meta.glob<string>(
  ["../../lesson/project/**/*.{sql,yml,yaml,csv}", "!../../lesson/project/target/**"],
  {
    eager: true,
    import: "default",
    query: "?raw",
  },
);

const projectPathMarker = "/lesson/project/";

export const initialProjectFiles = Object.fromEntries(
  Object.entries(rawProjectModules).map(([modulePath, contents]) => {
    const markerIndex = modulePath.indexOf(projectPathMarker);
    if (markerIndex < 0) throw new Error(`Unexpected tutorial project path: ${modulePath}`);
    return [modulePath.slice(markerIndex + projectPathMarker.length), contents];
  }),
);

const visibleProjectFiles = [
  "models/stg_invoices.sql",
  "models/int_invoice_resolution.sql",
  "models/quarantine_invoices.sql",
  "tests/assert_invoice_partition.sql",
] as const;

export function createTutorialFiles(): TutorialFile[] {
  return visibleProjectFiles.map((path) => ({
    path,
    label: path.split("/").at(-1) ?? path,
    language: "sql",
    content: initialProjectFiles[path],
    editable: true,
  }));
}

export function mergeProjectFiles(files: TutorialFile[]): Record<string, string> {
  const merged = { ...initialProjectFiles };
  for (const file of files) merged[file.path] = file.content;
  return merged;
}
