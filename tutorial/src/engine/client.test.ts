import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { BrowserDbtEngine } from "./client";

class FakeWorker extends EventTarget {
  static instances: FakeWorker[] = [];
  postMessage = vi.fn();
  terminate = vi.fn();

  constructor() {
    super();
    FakeWorker.instances.push(this);
  }

  reply(data: unknown) {
    this.dispatchEvent(new MessageEvent("message", { data }));
  }
}

describe("BrowserDbtEngine lifecycle", () => {
  beforeEach(() => {
    FakeWorker.instances = [];
    vi.stubGlobal("Worker", FakeWorker);
  });

  afterEach(() => vi.unstubAllGlobals());

  function createEngine() {
    const options = { onLog: vi.fn(), onStatus: vi.fn() };
    const engine = new BrowserDbtEngine(options);
    return { engine, worker: FakeWorker.instances[0], options };
  }

  it("routes overlapping requests by id and preserves query truncation", async () => {
    const { engine, worker } = createEngine();
    const query = engine.query("select 1");
    const catalog = engine.catalog();
    worker.reply({ type: "result", id: 2, ok: true, result: [] });
    worker.reply({ type: "result", id: 1, ok: true, result: { rows: [[1]], columns: [], truncated: true } });
    await expect(catalog).resolves.toEqual([]);
    await expect(query).resolves.toMatchObject({ truncated: true });
    engine.terminate();
  });

  it("rejects pending and future requests after reset and ignores late events", async () => {
    const { engine, worker, options } = createEngine();
    const pending = expect(engine.boot()).rejects.toThrow("reset");
    engine.terminate();
    await pending;
    await expect(engine.catalog()).rejects.toThrow("reset");
    worker.reply({ type: "log", line: "late", stream: "out" });
    expect(options.onLog).not.toHaveBeenCalled();
    expect(worker.postMessage).toHaveBeenCalledTimes(1);
    expect(worker.terminate).toHaveBeenCalledTimes(1);
  });

  it.each(["error", "messageerror"])("rejects all work when the worker emits %s", async (eventType) => {
    const { engine, worker } = createEngine();
    const boot = expect(engine.boot()).rejects.toThrow();
    const query = expect(engine.query("select 1")).rejects.toThrow();
    worker.dispatchEvent(new Event(eventType));
    await Promise.all([boot, query]);
    await expect(engine.catalog()).rejects.toThrow();
    expect(worker.terminate).toHaveBeenCalledOnce();
  });

  it("rejects a failed postMessage while allowing later requests to complete", async () => {
    const { engine, worker } = createEngine();
    worker.postMessage.mockImplementationOnce(() => { throw new Error("clone failed"); });
    await expect(engine.query("select 1")).rejects.toThrow("clone failed");
    const catalog = engine.catalog();
    worker.reply({ type: "result", id: 2, ok: true, result: [] });
    await expect(catalog).resolves.toEqual([]);
    engine.terminate();
  });
});
