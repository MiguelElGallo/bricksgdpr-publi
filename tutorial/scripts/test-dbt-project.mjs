import { mkdir, mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const tutorialRoot = resolve(scriptDirectory, "..");
const projectDirectory = resolve(tutorialRoot, "lesson", "project");
const temporaryDirectory = await mkdtemp(resolve(tmpdir(), "bricksgdpr-tutorial-"));
// Pyodide 0.27.7 ships DuckDB 1.1.2. Validate the same SQL behavior natively.
const runtimeArgs = [
  "--from", "dbt-core==1.10.8",
  "--with", "dbt-duckdb==1.9.6",
  "--with", "duckdb==1.1.2",
];

function run(command, args, databasePath, expectedError = null) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, {
      cwd: tutorialRoot,
      env: { ...process.env, TUTORIAL_DUCKDB_PATH: databasePath },
      stdio: expectedError ? ["ignore", "pipe", "pipe"] : "inherit",
    });
    let output = "";
    child.stdout?.on("data", (chunk) => { output += chunk; });
    child.stderr?.on("data", (chunk) => { output += chunk; });
    child.on("error", reject);
    child.on("close", (code) => {
      if (expectedError) {
        if (code !== null && code !== 0 && output.includes(expectedError)) resolvePromise();
        else reject(new Error(`Expected failure containing ${JSON.stringify(expectedError)}, got status ${code}:\n${output}`));
      } else if (code === 0) resolvePromise();
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
    name: "customer-staging",
    args: [
      "build",
      "--select",
      "+stg_customer",
      "--indirect-selection",
      "cautious",
    ],
  },
  {
    name: "customer-current",
    args: [
      "build",
      "--select",
      "+int_current_customers",
      "--indirect-selection",
      "cautious",
    ],
  },
  {
    name: "customer-mapping",
    args: [
      "build",
      "--select",
      "+demo_customer_map",
      "--indirect-selection",
      "cautious",
    ],
  },
  {
    name: "customer-layer2",
    args: [
      "build",
      "--select",
      "+int_customer_protected",
      "--indirect-selection",
      "cautious",
    ],
  },
  {
    name: "customer-layer3",
    args: [
      "build",
      "--select",
      "+dim_customer",
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
        ...runtimeArgs,
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

  const rejectedKeys = [
    ["invalid-ssn", "'900letters000001'", "customer.ssn", "ssn", "Invalid synthetic SSN"],
    ["phone-without-country-code", "'3585550101'", "customer.phone", "phone", "Invalid phone"],
    ["phone-extension", "'+3585550101ext2'", "customer.phone", "phone", "Invalid phone"],
    ["unknown-key-kind", "'anything'", "customer.email", "unknown", "kind must be text, ssn, phone, or date"],
  ];
  for (const [name, expression, namespace, kind, expectedError] of rejectedKeys) {
    console.log(`\nValidating expected key-contract rejection: ${name}`);
    await run("uvx", [
      ...runtimeArgs, "dbt", "show", "--inline",
      `select {{ demo_personal_data_key(${JSON.stringify(expression)}, '${namespace}', '${kind}') }} as key`,
      "--project-dir", projectDirectory,
      "--profiles-dir", projectDirectory,
      "--target-path", resolve(temporaryDirectory, name, "target"),
      "--no-use-colors",
    ], resolve(temporaryDirectory, "full-project", "tutorial.duckdb"), expectedError);
  }

  // Exercise the actual worker query implementation, rather than a duplicate.
  const workerSource = await readFile(resolve(tutorialRoot, "public", "dbt-worker.js"), "utf8");
  const queryHelpers = workerSource.slice(
    workerSource.indexOf("def json_value(value):"),
    workerSource.indexOf("def browser_catalog():"),
  );
  if (!queryHelpers.includes("def browser_query(sql):")) {
    throw new Error("Could not locate worker query helpers for runtime validation");
  }
  const queryChecks = `
from pathlib import Path
from datetime import date, datetime
from decimal import Decimal
import os
import duckdb

DATABASE = Path(os.environ["TUTORIAL_DUCKDB_PATH"])
def close_dbt_connections():
    pass

${queryHelpers}

def rejected(sql, message):
    try:
        browser_query(sql)
    except Exception as error:
        assert message in str(error), str(error)
    else:
        raise AssertionError("Query should have been rejected: " + sql)

rejected("select 1", "Run a dbt build")
connection = duckdb.connect(str(DATABASE))
connection.execute("create table example as select 42 as value")
connection.close()
assert browser_query("select * from example")["rows"] == [[42]]
assert browser_query("with example as (select 'a;b' as value) select * from example;")["rows"] == [["a;b"]]
assert browser_query("select * from range(1000)")["truncated"] is False
large = browser_query("select * from range(10000)")
assert len(large["rows"]) == 1000 and large["truncated"] is True
for sql in ["select 1; select 2", "delete from example", "create table bad as select 1", "copy example to '/tmp/bad.csv'", "set enable_external_access = true"]:
    rejected(sql, "one read-only SELECT")
rejected("select * from read_csv('/tmp/missing.csv')", "disabled")
assert browser_query("select * from example")["rows"] == [[42]]
print("Worker query checks passed on DuckDB " + duckdb.__version__)
`;
  await run("uvx", [...runtimeArgs, "python", "-c", queryChecks], resolve(temporaryDirectory, "query-checks.duckdb"));
} finally {
  await rm(temporaryDirectory, { recursive: true, force: true });
}
