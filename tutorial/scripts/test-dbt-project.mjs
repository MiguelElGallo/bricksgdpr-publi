import { mkdir, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const tutorialRoot = resolve(scriptDirectory, "..");
const projectDirectory = resolve(tutorialRoot, "lesson", "project");
const temporaryDirectory = await mkdtemp(resolve(tmpdir(), "bricksgdpr-tutorial-"));

function run(command, args, databasePath) {
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

const invocations = [
  {
    name: "full-project",
    args: ["build"],
  },
  {
    name: "invoice-quarantine",
    args: [
      "build",
      "--select",
      "+assert_invoice_partition",
      "--indirect-selection",
      "cautious",
    ],
  },
  {
    name: "customer-flow",
    args: [
      "build",
      "--select",
      "+assert_customer_flow_fixture",
      "--indirect-selection",
      "cautious",
    ],
  },
];

try {
  for (const invocation of invocations) {
    const invocationDirectory = resolve(temporaryDirectory, invocation.name);
    const databasePath = resolve(invocationDirectory, "tutorial.duckdb");
    await mkdir(invocationDirectory, { recursive: true });
    console.log(`\nValidating ${invocation.name} on a clean DuckDB database`);
    await run(
      "uvx",
      [
        "--from",
        "dbt-core==1.10.8",
        "--with",
        "dbt-duckdb==1.9.6",
        "dbt",
        ...invocation.args,
        "--project-dir",
        projectDirectory,
        "--profiles-dir",
        projectDirectory,
        "--target-path",
        resolve(invocationDirectory, "target"),
        "--no-use-colors",
      ],
      databasePath,
    );
  }
} finally {
  await rm(temporaryDirectory, { recursive: true, force: true });
}
