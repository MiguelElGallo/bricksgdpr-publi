import { createHash } from "node:crypto";
import { mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const tutorialRoot = resolve(scriptDirectory, "..");
const lockPath = resolve(tutorialRoot, "wheelhouse-lock.json");
const wheelhouseDirectory = resolve(tutorialRoot, "public", "wheelhouse");
const updateLock = process.argv.includes("--update-lock");

const packageSpecs = [
  ["agate", "1.9.1"],
  ["babel", "2.18.0"],
  ["colorama", "0.4.6"],
  ["daff", "1.4.2"],
  ["dbt-adapters", "1.16.3"],
  ["dbt-common", "1.27.1"],
  ["dbt-core", "1.10.8"],
  ["dbt-duckdb", "1.9.6"],
  ["dbt-protos", "1.0.541"],
  ["dbt-semantic-interfaces", "0.9.0"],
  ["deepdiff", "7.0.1"],
  ["importlib-metadata", "8.9.0"],
  ["isodate", "0.6.1"],
  ["jinja2", "3.1.6"],
  ["leather", "0.4.1"],
  ["mashumaro", "3.14"],
  ["networkx", "3.4.2"],
  ["ordered-set", "4.1.0"],
  ["parsedatetime", "2.6"],
  ["pathspec", "0.12.1"],
  ["python-slugify", "8.0.4"],
  ["pytimeparse", "1.1.8"],
  ["snowplow-tracker", "1.1.0"],
  ["sqlparse", "0.5.5"],
  ["text-unidecode", "1.3"],
  ["zipp", "4.1.0"],
];

function sha256(buffer) {
  return createHash("sha256").update(buffer).digest("hex");
}

async function createLock() {
  const packages = [];

  for (const [name, version] of packageSpecs) {
    const response = await fetch(`https://pypi.org/pypi/${name}/${version}/json`);
    if (!response.ok) {
      throw new Error(`PyPI metadata request failed for ${name}==${version}`);
    }
    const metadata = await response.json();
    const wheel = metadata.urls.find((candidate) =>
      candidate.filename.endsWith("none-any.whl"),
    );
    if (!wheel) {
      throw new Error(`No universal wheel exists for ${name}==${version}`);
    }
    packages.push({
      name,
      version,
      filename: wheel.filename,
      sha256: wheel.digests.sha256,
      url: wheel.url,
    });
  }

  const lock = {
    generatedBy: "tutorial/scripts/sync-wheelhouse.mjs --update-lock",
    pyodide: "0.27.7",
    dbtCore: "1.10.8",
    dbtDuckdb: "1.9.6",
    packages,
  };
  await writeFile(lockPath, `${JSON.stringify(lock, null, 2)}\n`);
  return lock;
}

async function readLock() {
  const lock = JSON.parse(await readFile(lockPath, "utf8"));
  const expected = new Map(packageSpecs.map(([name, version]) => [name, version]));
  for (const entry of lock.packages) {
    if (expected.get(entry.name) !== entry.version) {
      throw new Error(`wheelhouse lock does not match ${entry.name}==${entry.version}`);
    }
    expected.delete(entry.name);
  }
  if (expected.size > 0) {
    throw new Error(`wheelhouse lock is missing: ${[...expected.keys()].join(", ")}`);
  }
  return lock;
}

async function syncWheelhouse(lock) {
  await mkdir(wheelhouseDirectory, { recursive: true });
  const expectedFiles = new Set(lock.packages.map((entry) => entry.filename));

  for (const entry of lock.packages) {
    const destination = resolve(wheelhouseDirectory, entry.filename);
    let existing = null;
    try {
      existing = await readFile(destination);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
    if (existing && sha256(existing) === entry.sha256) continue;

    const response = await fetch(entry.url);
    if (!response.ok) {
      throw new Error(`Wheel download failed for ${entry.name}==${entry.version}`);
    }
    const contents = Buffer.from(await response.arrayBuffer());
    const actualHash = sha256(contents);
    if (actualHash !== entry.sha256) {
      throw new Error(`SHA-256 mismatch for ${entry.filename}`);
    }
    await writeFile(destination, contents);
  }

  for (const filename of await readdir(wheelhouseDirectory)) {
    if (filename.endsWith(".whl") && !expectedFiles.has(filename)) {
      await rm(resolve(wheelhouseDirectory, filename));
    }
  }

  const runtimeManifest = {
    pyodide: lock.pyodide,
    packages: lock.packages.map(({ name, version, filename, sha256: digest }) => ({
      name,
      version,
      filename,
      sha256: digest,
    })),
  };
  await writeFile(
    resolve(wheelhouseDirectory, "manifest.json"),
    `${JSON.stringify(runtimeManifest, null, 2)}\n`,
  );
}

const lock = updateLock ? await createLock() : await readLock();
await syncWheelhouse(lock);
console.log(`Wheelhouse ready: ${lock.packages.length} pinned packages.`);
