import type {
  CatalogRelation,
  EnginePhase,
  InvocationResult,
  RawQueryResult,
  RuntimeInfo,
} from "./types";

interface EngineClientOptions {
  onLog: (line: string, stream: "out" | "err") => void;
  onStatus: (phase: EnginePhase, detail?: string) => void;
}

interface PendingCall {
  resolve: (value: unknown) => void;
  reject: (reason: Error) => void;
}

export class BrowserDbtEngine {
  private worker: Worker;
  private pending = new Map<number, PendingCall>();
  private nextId = 1;
  private assetBase: URL;

  constructor(private options: EngineClientOptions) {
    this.assetBase = new URL(import.meta.env.BASE_URL, window.location.href);
    this.worker = new Worker(new URL("dbt-worker.js", this.assetBase));
    this.worker.addEventListener("message", this.handleMessage);
    this.worker.addEventListener("error", this.handleWorkerError);
  }

  boot(): Promise<RuntimeInfo> {
    return this.call("boot", {
      wheelhouseBase: new URL("wheelhouse/", this.assetBase).toString(),
    });
  }

  invoke(args: string[], files: Record<string, string>): Promise<InvocationResult> {
    return this.call("invoke", { args, files });
  }

  query(sql: string): Promise<RawQueryResult> {
    return this.call("query", { sql });
  }

  catalog(): Promise<CatalogRelation[]> {
    return this.call("catalog", {});
  }

  terminate() {
    this.worker.terminate();
    this.worker.removeEventListener("message", this.handleMessage);
    this.worker.removeEventListener("error", this.handleWorkerError);
    const error = new Error("The browser dbt engine was reset");
    for (const call of this.pending.values()) call.reject(error);
    this.pending.clear();
  }

  private call<T>(type: string, payload: unknown): Promise<T> {
    const id = this.nextId;
    this.nextId += 1;
    return new Promise<T>((resolve, reject) => {
      this.pending.set(id, {
        resolve: resolve as (value: unknown) => void,
        reject,
      });
      this.worker.postMessage({ id, type, payload });
    });
  }

  private handleMessage = (event: MessageEvent) => {
    const message = event.data ?? {};
    if (message.type === "log") {
      this.options.onLog(message.line, message.stream === "err" ? "err" : "out");
      return;
    }
    if (message.type === "status") {
      this.options.onStatus(message.phase, message.detail);
      return;
    }
    if (message.type !== "result") return;

    const call = this.pending.get(message.id);
    if (!call) return;
    this.pending.delete(message.id);
    if (message.ok) call.resolve(message.result);
    else call.reject(new Error(message.error || "Browser dbt engine request failed"));
  };

  private handleWorkerError = (event: ErrorEvent) => {
    const error = new Error(event.message || "The browser dbt worker stopped unexpectedly");
    for (const call of this.pending.values()) call.reject(error);
    this.pending.clear();
  };
}
