import type { LessonId, TutorialFile } from "../types";
import { LESSONS, getLessonSpec } from "./lessons";

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

const visibleProjectFiles = [...new Set(LESSONS.flatMap((lesson) => lesson.filePaths))];

export function createTutorialFiles(): TutorialFile[] {
  return visibleProjectFiles.map((path) => {
    const content = initialProjectFiles[path];
    if (typeof content !== "string") {
      throw new Error(`Tutorial lesson references a missing project file: ${path}`);
    }
    return {
      path,
      label: path.split("/").at(-1) ?? path,
      language: "sql",
      content,
      editable: true,
    };
  });
}

export function filesForLesson(files: TutorialFile[], lessonId: LessonId): TutorialFile[] {
  const visible = new Set(getLessonSpec(lessonId).filePaths);
  return files.filter((file) => visible.has(file.path));
}

export function mergeProjectFiles(files: TutorialFile[]): Record<string, string> {
  const merged = { ...initialProjectFiles };
  for (const file of files) merged[file.path] = file.content;
  return merged;
}
