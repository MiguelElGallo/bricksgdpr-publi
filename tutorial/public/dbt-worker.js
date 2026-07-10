const PYODIDE_VERSION = "0.27.7";
const PYODIDE_BASE = `https://cdn.jsdelivr.net/pyodide/v${PYODIDE_VERSION}/full/`;

let pyodide = null;
let bootPromise = null;
let invocationActive = false;
let requestQueue = Promise.resolve();

const allowedCommands = new Set(["build", "compile", "ls", "run", "seed", "show", "test"]);
const valueFlags = new Set([
  "--exclude",
  "--indirect-selection",
  "--limit",
  "--select",
  "-s",
]);
const booleanFlags = new Set(["--fail-fast", "--full-refresh", "--quiet", "--warn-error"]);

function sendLog(line, stream = "out") {
  self.postMessage({ type: "log", line, stream });
}

function sendStatus(phase, detail) {
  self.postMessage({ type: "status", phase, detail });
}

function stringifyError(error) {
  return error?.message ?? String(error);
}

function ensureRelativeProjectPath(path) {
  if (
    typeof path !== "string" ||
    path.length === 0 ||
    path.startsWith("/") ||
    path.includes("..") ||
    path.includes("\\") ||
    path.includes("\0")
  ) {
    throw new Error(`Unsafe tutorial project path: ${path}`);
  }
  return path;
}

function validateDbtArgs(args) {
  if (!Array.isArray(args) || !allowedCommands.has(args[0])) {
    throw new Error("Unsupported browser tutorial dbt command");
  }

  const validated = [args[0]];
  for (let index = 1; index < args.length; index += 1) {
    const token = args[index];
    if (typeof token !== "string" || /[\0\r\n]/.test(token)) {
      throw new Error("Unsafe browser tutorial dbt argument");
    }
    if (booleanFlags.has(token)) {
      validated.push(token);
      continue;
    }
    if (valueFlags.has(token)) {
      const value = args[index + 1];
      if (
        typeof value !== "string" ||
        value.length === 0 ||
        value.startsWith("--") ||
        /[\0\r\n]/.test(value)
      ) {
        throw new Error(`${token} requires a safe value`);
      }
      if (token === "--limit" && !/^\d+$/.test(value)) {
        throw new Error("--limit must be a positive integer");
      }
      if (token === "--indirect-selection" && value !== "cautious") {
        throw new Error("--indirect-selection must be cautious in this browser tutorial");
      }
      validated.push(token, value);
      index += 1;
      continue;
    }
    throw new Error(`Unsupported browser tutorial option: ${token}`);
  }
  return validated;
}

function validateProjectFiles(files) {
  if (files === null || typeof files !== "object" || Array.isArray(files)) {
    throw new Error("Tutorial project files must be a path-to-content mapping");
  }
  return Object.fromEntries(
    Object.entries(files).map(([path, contents]) => {
      if (typeof contents !== "string") {
        throw new Error(`Tutorial project file must contain text: ${path}`);
      }
      return [ensureRelativeProjectPath(path), contents];
    }),
  );
}

async function installRuntime(wheelhouseBase) {
  sendStatus("loading-pyodide", `Loading Python ${PYODIDE_VERSION}`);
  self.importScripts(`${PYODIDE_BASE}pyodide.js`);
  pyodide = await self.loadPyodide({
    indexURL: PYODIDE_BASE,
    stdout: (line) => sendLog(line, "out"),
    stderr: (line) => sendLog(line, "err"),
  });

  sendStatus("loading-packages", "Loading DuckDB and compiled Python packages");
  await pyodide.loadPackage([
    "click",
    "duckdb",
    "jsonschema",
    "markupsafe",
    "more-itertools",
    "msgpack",
    "packaging",
    "protobuf",
    "pydantic",
    "python-dateutil",
    "pytz",
    "pyyaml",
    "requests",
    "typing-extensions",
    "micropip",
  ]);

  sendStatus("installing-dbt", "Installing the pinned dbt Core teaching runtime");
  const manifestUrl = new URL("manifest.json", wheelhouseBase);
  const manifestResponse = await fetch(manifestUrl);
  if (!manifestResponse.ok) throw new Error("Unable to load the tutorial wheelhouse manifest");
  const manifest = await manifestResponse.json();
  if (manifest.pyodide !== PYODIDE_VERSION) {
    throw new Error(`Wheelhouse expects Pyodide ${manifest.pyodide}`);
  }
  const wheelUrls = manifest.packages.map((entry) =>
    new URL(entry.filename, wheelhouseBase).toString(),
  );
  pyodide.globals.set("browser_wheel_urls", wheelUrls);
  await pyodide.runPythonAsync(`
import micropip
await micropip.install(list(browser_wheel_urls), deps=False)
`);

  sendStatus("patching-runtime", "Preparing dbt for the single-worker browser runtime");
  await pyodide.runPythonAsync(`
import concurrent.futures
import json
import multiprocessing
import os
import site
import sys
import threading
import types
from contextlib import contextmanager
from contextvars import ContextVar
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

os.environ["DBT_SEND_ANONYMOUS_USAGE_STATS"] = "false"

# dbt-extractor is a native Rust extension. The tutorial disables static parsing,
# so this private compatibility distribution always asks dbt to use its Jinja parser.
site_packages = Path(site.getsitepackages()[0])
extractor_module = site_packages / "dbt_extractor"
extractor_dist = site_packages / "dbt_extractor-0.6.0.dist-info"
extractor_module.mkdir(exist_ok=True)
extractor_dist.mkdir(exist_ok=True)
(extractor_module / "__init__.py").write_text(
    "class ExtractionError(Exception):\\n"
    "    pass\\n\\n"
    "def py_extract_from_source(source):\\n"
    "    raise ExtractionError('Static parsing is unavailable in WebAssembly')\\n"
)
(extractor_dist / "METADATA").write_text(
    "Metadata-Version: 2.1\\nName: dbt-extractor\\nVersion: 0.6.0\\n"
)
(extractor_dist / "WHEEL").write_text(
    "Wheel-Version: 1.0\\nGenerator: bricksgdpr-browser-lab\\n"
    "Root-Is-Purelib: true\\nTag: py3-none-any\\n"
)

# Pyodide intentionally omits process-backed synchronization. dbt runs with
# --single-threaded here, so thread locks and completed Futures preserve its API contract.
sync_module = types.ModuleType("multiprocessing.synchronize")
sync_module.Lock = threading.Lock
sync_module.RLock = threading.RLock
sys.modules["multiprocessing.synchronize"] = sync_module

class BrowserMpContext:
    def Lock(self):
        return threading.Lock()

    def RLock(self):
        return threading.RLock()

multiprocessing.get_context = lambda method=None: BrowserMpContext()

class BrowserExecutor(concurrent.futures.Executor):
    def __init__(self, *args, **kwargs):
        pass

    def submit(self, fn, /, *args, **kwargs):
        future = concurrent.futures.Future()
        try:
            future.set_result(fn(*args, **kwargs))
        except BaseException as exc:
            future.set_exception(exc)
        return future

concurrent.futures.ProcessPoolExecutor = BrowserExecutor

from dbt.cli.main import dbtRunner
import dbt.task.run
import dbt.task.runnable
from dbt.adapters.base.connections import BaseConnectionManager
from dbt.adapters.duckdb.connections import DuckDBConnectionManager
from dbt_common.utils.executor import SingleThreadedExecutor

class BrowserThreadPool:
    def __init__(self, *args, **kwargs):
        self.closed = False

    def close(self):
        self.closed = True

    def join(self):
        pass

    def terminate(self):
        self.closed = True

    def is_closed(self):
        return self.closed

    def apply_async(self, *args, **kwargs):
        raise RuntimeError("Parallel dbt work is unavailable in the browser runtime")

dbt.task.runnable.DbtThreadPool = BrowserThreadPool
dbt.task.run.DbtThreadPool = BrowserThreadPool

# The synchronous executor still needs distinct logical connection slots. Without
# them, schema setup can close the master DuckDB connection used by a model.
connection_slot = ContextVar("dbt_browser_connection_slot", default="main")
BaseConnectionManager.get_thread_identifier = staticmethod(
    lambda: ("browser", connection_slot.get())
)

@contextmanager
def browser_connection_named(self, adapter, name):
    token = connection_slot.set(name)
    try:
        with adapter.connection_named(name):
            yield
    finally:
        connection_slot.reset(token)

SingleThreadedExecutor.connection_named = browser_connection_named

PROJECT = Path("/project")
TARGET = PROJECT / "target"
DATABASE = PROJECT / "tutorial.duckdb"

def close_dbt_connections():
    DuckDBConnectionManager.close_all_connections()

def read_json_artifact(name):
    path = TARGET / name
    return json.loads(path.read_text()) if path.exists() else None

def browser_invoke(args):
    os.chdir(PROJECT)
    invocation = dbtRunner().invoke([
        *list(args),
        "--project-dir", str(PROJECT),
        "--profiles-dir", str(PROJECT),
        "--target-path", str(TARGET),
        "--single-threaded",
        "--no-use-colors",
    ])
    run_results = read_json_artifact("run_results.json")
    manifest = read_json_artifact("manifest.json")
    close_dbt_connections()
    return {
        "success": invocation.success,
        "exception": None if invocation.exception is None else repr(invocation.exception),
        "results": [] if run_results is None else [
            {
                "uniqueId": item.get("unique_id"),
                "status": item.get("status"),
                "message": item.get("message"),
                "executionTime": item.get("execution_time"),
            }
            for item in run_results.get("results", [])
        ],
        "nodes": [] if manifest is None else [
            {
                "uniqueId": unique_id,
                "name": node.get("name"),
                "resourceType": node.get("resource_type"),
                "dependsOn": node.get("depends_on", {}).get("nodes", []),
            }
            for unique_id, node in manifest.get("nodes", {}).items()
        ],
        "artifacts": sorted(path.name for path in TARGET.glob("*.json")),
    }

def json_value(value):
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return str(value)

def browser_query(sql):
    import duckdb
    close_dbt_connections()
    connection = duckdb.connect(str(DATABASE), read_only=True)
    try:
        connection.execute("SET TimeZone = 'UTC'")
        cursor = connection.execute(sql)
        columns = [
            {"name": item[0], "type": str(item[1])}
            for item in (cursor.description or [])
        ]
        rows = [[json_value(value) for value in row] for row in cursor.fetchall()]
        return {"columns": columns, "rows": rows}
    finally:
        connection.close()

def browser_catalog():
    import duckdb
    close_dbt_connections()
    if not DATABASE.exists():
        return []
    connection = duckdb.connect(str(DATABASE), read_only=True)
    try:
        connection.execute("SET TimeZone = 'UTC'")
        relations = connection.execute("""
            select table_schema, table_name, table_type
            from information_schema.tables
            where table_schema not in ('information_schema', 'pg_catalog')
            order by table_schema, table_name
        """).fetchall()
        columns = connection.execute("""
            select table_schema, table_name, column_name, data_type, is_nullable
            from information_schema.columns
            where table_schema not in ('information_schema', 'pg_catalog')
            order by table_schema, table_name, ordinal_position
        """).fetchall()
        columns_by_relation = {}
        for schema, table, column, data_type, nullable in columns:
            columns_by_relation.setdefault((schema, table), []).append({
                "name": column,
                "type": data_type,
                "nullable": nullable == "YES",
            })
        result = []
        for schema, table, table_type in relations:
            quoted_schema = '"' + schema.replace('"', '""') + '"'
            quoted_table = '"' + table.replace('"', '""') + '"'
            count = connection.execute(
                f"select count(*) from {quoted_schema}.{quoted_table}"
            ).fetchone()[0]
            result.append({
                "schema": schema,
                "name": table,
                "tableType": table_type,
                "rowCount": count,
                "columns": columns_by_relation.get((schema, table), []),
            })
        return result
    finally:
        connection.close()
`);
  return {
    pyodideVersion: PYODIDE_VERSION,
    pythonVersion: pyodide.runPython("import platform; platform.python_version()"),
    dbtVersion: pyodide.runPython("import dbt.version; dbt.version.__version__"),
    duckdbVersion: pyodide.runPython("import duckdb; duckdb.__version__"),
  };
}

async function boot(payload) {
  if (!bootPromise) bootPromise = installRuntime(payload.wheelhouseBase);
  return bootPromise;
}

async function syncProject(files) {
  if (!pyodide) throw new Error("The browser engine has not been booted");
  pyodide.globals.set("browser_project_files", validateProjectFiles(files));
  await pyodide.runPythonAsync(`
import shutil
from pathlib import Path

project = Path("/project")
for resource in ("models", "seeds", "tests", "macros", "analyses", "snapshots"):
    shutil.rmtree(project / resource, ignore_errors=True)
shutil.rmtree(project / "target", ignore_errors=True)
project.mkdir(parents=True, exist_ok=True)

for relative_path, contents in browser_project_files.to_py().items():
    destination = project / relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(contents)
`);
}

async function invoke(payload) {
  if (invocationActive) throw new Error("A dbt command is already running");
  invocationActive = true;
  try {
    await syncProject(payload.files);
    pyodide.globals.set("browser_command_args", validateDbtArgs(payload.args));
    const resultJson = await pyodide.runPythonAsync(
      "json.dumps(browser_invoke(list(browser_command_args)))",
    );
    return JSON.parse(resultJson);
  } finally {
    invocationActive = false;
  }
}

async function query(payload) {
  pyodide.globals.set("browser_sql", payload.sql);
  const resultJson = await pyodide.runPythonAsync("json.dumps(browser_query(str(browser_sql)))");
  return JSON.parse(resultJson);
}

async function catalog() {
  const resultJson = await pyodide.runPythonAsync("json.dumps(browser_catalog())");
  return JSON.parse(resultJson);
}

async function dispatchRequest(message) {
  const { type, payload = {} } = message;
  if (type === "boot") return boot(payload);
  if (type === "invoke") return invoke(payload);
  if (type === "query") return query(payload);
  if (type === "catalog") return catalog();
  throw new Error(`Unsupported browser-engine request: ${type}`);
}

self.onmessage = (event) => {
  const { id, type, payload = {} } = event.data ?? {};
  const request = requestQueue.then(() => dispatchRequest({ type, payload }));
  requestQueue = request.then(
    () => undefined,
    () => undefined,
  );
  request.then(
    (result) => self.postMessage({ type: "result", id, ok: true, result }),
    (error) =>
      self.postMessage({
        type: "result",
        id,
        ok: false,
        error: stringifyError(error),
        stack: error?.stack,
      }),
  );
};
