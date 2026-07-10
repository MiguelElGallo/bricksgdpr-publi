export interface RuntimeInfo {
  pyodideVersion: string;
  pythonVersion: string;
  dbtVersion: string;
  duckdbVersion: string;
}

export interface InvocationNodeResult {
  uniqueId: string;
  status: string;
  message?: string;
  executionTime?: number;
}

export interface InvocationResult {
  success: boolean;
  exception: string | null;
  results: InvocationNodeResult[];
  nodes: Array<{
    uniqueId: string;
    name: string;
    resourceType: string;
    dependsOn: string[];
  }>;
  artifacts: string[];
}

export interface RawQueryResult {
  columns: Array<{ name: string; type: string }>;
  rows: unknown[][];
}

export interface CatalogRelation {
  schema: string;
  name: string;
  tableType: string;
  rowCount: number;
  columns: Array<{ name: string; type: string; nullable: boolean }>;
}

export type EnginePhase =
  | "loading-pyodide"
  | "loading-packages"
  | "installing-dbt"
  | "patching-runtime";
