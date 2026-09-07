const allowedCommands = new Set(["build", "compile", "ls", "run", "seed", "show", "test"]);
const valueFlags = new Set([
  "--exclude",
  "--indirect-selection",
  "--limit",
  "--select",
  "-s",
]);
const booleanFlags = new Set(["--fail-fast", "--full-refresh", "--quiet", "--warn-error"]);

function tokenize(command: string): string[] {
  const tokens: string[] = [];
  let token = "";
  let quote: "'" | '"' | null = null;

  for (const character of command.trim()) {
    if (quote) {
      if (character === quote) quote = null;
      else token += character;
      continue;
    }
    if (character === "'" || character === '"') {
      quote = character;
    } else if (/\s/.test(character)) {
      if (token) {
        tokens.push(token);
        token = "";
      }
    } else {
      token += character;
    }
  }
  if (quote) throw new Error("The dbt command contains an unmatched quote");
  if (token) tokens.push(token);
  return tokens;
}

export function parseDbtCommand(command: string): string[] {
  if (/[\0\r\n]/.test(command)) throw new Error("Enter one dbt command at a time");
  const tokens = tokenize(command);
  if (tokens[0] !== "dbt" || !allowedCommands.has(tokens[1])) {
    throw new Error("Allowed commands: dbt build, run, seed, test, show, compile, and ls");
  }

  const args = [tokens[1]];
  for (let index = 2; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (booleanFlags.has(token)) {
      args.push(token);
      continue;
    }
    if (valueFlags.has(token)) {
      const value = tokens[index + 1];
      if (!value || value.startsWith("-")) throw new Error(`${token} requires a value`);
      if (token === "--limit" && (!/^[1-9]\d*$/.test(value) || !Number.isSafeInteger(Number(value)))) {
        throw new Error("--limit must be a positive integer");
      }
      if (token === "--indirect-selection" && value !== "cautious") {
        throw new Error("--indirect-selection must be cautious in this browser tutorial");
      }
      args.push(token, value);
      index += 1;
      continue;
    }
    throw new Error(`Unsupported browser tutorial option: ${token}`);
  }
  return args;
}
