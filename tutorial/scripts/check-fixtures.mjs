import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const tutorialRoot = resolve(scriptDirectory, "..");
const repositoryRoot = resolve(tutorialRoot, "..");
const fixtureNames = ["customer.csv", "customer_services.csv", "invoices.csv"];

for (const name of fixtureNames) {
  const canonical = await readFile(resolve(repositoryRoot, "seeds", name));
  const tutorial = await readFile(resolve(tutorialRoot, "lesson", "project", "seeds", name));
  if (!canonical.equals(tutorial)) {
    throw new Error(`Tutorial fixture is out of sync with seeds/${name}`);
  }
}

console.log(`Tutorial fixtures match ${fixtureNames.length} canonical synthetic seeds.`);
