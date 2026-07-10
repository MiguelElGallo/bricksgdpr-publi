import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const tutorialRoot = resolve(scriptDirectory, "..");
const projectDirectory = resolve(tutorialRoot, "lesson", "project");
const temporaryDirectory = await mkdtemp(resolve(tmpdir(), "bricksgdpr-tutorial-"));
const databasePath = resolve(temporaryDirectory, "tutorial.duckdb");

function run(command, args) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, {
      cwd: tutorialRoot,
      env: { ...process.env, TUTORIAL_DUCKDB_PATH: databasePath },
      stdio: "inherit",
    });
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) resolvePromise();
      else reject(new Error(`${command} exited with status ${code}`));
    });
  });
}

try {
  await run("uvx", [
    "--from",
    "dbt-core==1.10.8",
    "--with",
    "dbt-duckdb==1.9.6",
    "dbt",
    "build",
    "--project-dir",
    projectDirectory,
    "--profiles-dir",
    projectDirectory,
    "--target-path",
    resolve(temporaryDirectory, "target"),
    "--no-use-colors",
  ]);
} finally {
  await rm(temporaryDirectory, { recursive: true, force: true });
}
