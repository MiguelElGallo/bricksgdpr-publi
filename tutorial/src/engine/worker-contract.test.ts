/// <reference types="node" />

import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { runInNewContext } from "node:vm";
import { describe, expect, it, vi } from "vitest";

interface WorkerContract {
  ensureRelativeProjectPath: (path: unknown) => string;
  validateDbtArgs: (args: unknown) => string[];
  validateProjectFiles: (files: unknown) => Record<string, string>;
  setHandlers: (handlers: Record<string, (payload?: unknown) => Promise<unknown>>) => void;
}

function loadWorkerContract() {
  const source = readFileSync(resolve(process.cwd(), "public", "dbt-worker.js"), "utf8");
  const messages: unknown[] = [];
  const workerSelf = {
    postMessage: (message: unknown) => messages.push(message),
    onmessage: (_event: unknown) => undefined,
  };
  const context = { self: workerSelf, URL, Promise, Set };
  runInNewContext(
    `${source}\nself.__contract = {
      ensureRelativeProjectPath,
      validateDbtArgs,
      validateProjectFiles,
      setHandlers(handlers) {
        boot = handlers.boot ?? boot;
        invoke = handlers.invoke ?? invoke;
        query = handlers.query ?? query;
        catalog = handlers.catalog ?? catalog;
      },
    };`,
    context,
  );
  return {
    contract: (workerSelf as typeof workerSelf & { __contract: WorkerContract }).__contract,
    messages,
    send: (data: unknown) => workerSelf.onmessage({ data }),
  };
}

describe("dbt worker contract", () => {
  it("accepts only safe project paths and text contents", () => {
    const { contract } = loadWorkerContract();

    expect(contract.validateProjectFiles({ "models/example.sql": "select 1" })).toEqual({
      "models/example.sql": "select 1",
    });
    expect(() => contract.validateProjectFiles({ "../escape.sql": "select 1" })).toThrow(
      "Unsafe tutorial project path",
    );
    expect(() => contract.validateProjectFiles({ "/absolute.sql": "select 1" })).toThrow(
      "Unsafe tutorial project path",
    );
    expect(() => contract.validateProjectFiles({ "models/example.sql": 1 })).toThrow(
      "must contain text",
    );
  });

  it("mirrors the controlled dbt command surface inside the worker", () => {
    const { contract } = loadWorkerContract();

    expect(contract.validateDbtArgs(["build", "--select", "+quarantine_invoices"])).toEqual([
      "build",
      "--select",
      "+quarantine_invoices",
    ]);
    expect(() => contract.validateDbtArgs(["run-operation", "unsafe_macro"])).toThrow(
      "Unsupported browser tutorial dbt command",
    );
    expect(() => contract.validateDbtArgs(["build", "--profiles-dir", "/tmp"])).toThrow(
      "Unsupported browser tutorial option",
    );
    expect(() => contract.validateDbtArgs(["build", "--select", "model\nseed"])).toThrow(
      "requires a safe value",
    );
  });

  it("serializes requests even when the first handler is still pending", async () => {
    const { contract, messages, send } = loadWorkerContract();
    const order: string[] = [];
    let releaseFirst: (() => void) | undefined;
    const firstFinished = new Promise<void>((resolve) => {
      releaseFirst = resolve;
    });
    contract.setHandlers({
      boot: async () => {
        order.push("boot-start");
        await firstFinished;
        order.push("boot-end");
        return "booted";
      },
      catalog: async () => {
        order.push("catalog");
        return [];
      },
    });

    send({ id: 1, type: "boot" });
    send({ id: 2, type: "catalog" });
    await vi.waitFor(() => expect(order).toEqual(["boot-start"]));
    releaseFirst?.();
    await vi.waitFor(() => expect(messages).toHaveLength(2));

    expect(order).toEqual(["boot-start", "boot-end", "catalog"]);
    expect(messages).toEqual([
      { type: "result", id: 1, ok: true, result: "booted" },
      { type: "result", id: 2, ok: true, result: [] },
    ]);
  });
});
