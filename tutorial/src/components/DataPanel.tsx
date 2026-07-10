import { useMemo, useState } from "react";
import type { QueryResult, RelationSummary, ResultCell } from "../types";
import { Icon } from "./Icon";

interface DataPanelProps {
  relations: RelationSummary[];
  selectedRelation: string | null;
  result: QueryResult | null;
  disabled?: boolean;
  onRelationSelect: (name: string) => void;
}

type DataTab = "results" | "database";

function displayCell(value: ResultCell) {
  if (value === null) return <span className="null-value">NULL</span>;
  if (typeof value === "boolean") return value ? "true" : "false";
  return String(value);
}

export function DataPanel({
  relations,
  selectedRelation,
  result,
  disabled = false,
  onRelationSelect,
}: DataPanelProps) {
  const [activeTab, setActiveTab] = useState<DataTab>("results");
  const selected = relations.find((relation) => relation.name === selectedRelation) ?? relations[0];
  const groupedRelations = useMemo(() => {
    return relations.reduce<Record<string, RelationSummary[]>>((groups, relation) => {
      (groups[relation.layer] ??= []).push(relation);
      return groups;
    }, {});
  }, [relations]);

  function selectRelation(name: string) {
    onRelationSelect(name);
    setActiveTab("database");
  }

  return (
    <aside className="data-panel" aria-label="Data explorer">
      <header className="data-tabs" role="tablist" aria-label="Data views">
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === "results"}
          aria-controls="results-view"
          data-active={activeTab === "results"}
          onClick={() => setActiveTab("results")}
        >
          <Icon name="table" size={15} />
          Query result
          {result ? <span className="tab-count">{result.rowCount}</span> : null}
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={activeTab === "database"}
          aria-controls="database-view"
          data-active={activeTab === "database"}
          onClick={() => setActiveTab("database")}
        >
          <Icon name="database" size={15} />
          Database
          <span className="tab-count">{relations.length}</span>
        </button>
      </header>

      {activeTab === "results" ? (
        <section className="result-view" id="results-view" role="tabpanel">
          {result ? (
            <>
              <header className="result-summary">
                <div>
                  <span className="result-success-mark" aria-hidden="true">
                    <Icon name="check" size={14} />
                  </span>
                  <span>
                    <strong>{result.label ?? "Query complete"}</strong>
                    <small>
                      {result.rowCount} {result.rowCount === 1 ? "row" : "rows"}
                    </small>
                  </span>
                </div>
                {result.elapsedMs !== undefined ? <span>{result.elapsedMs} ms</span> : null}
              </header>
              <div className="table-scroll">
                <table className="result-table">
                  <caption className="sr-only">Query results</caption>
                  <thead>
                    <tr>
                      {result.columns.map((column) => (
                        <th scope="col" key={column.key}>
                          <span>{column.label}</span>
                          {column.type ? <small>{column.type}</small> : null}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {result.rows.map((row, rowIndex) => (
                      <tr key={rowIndex}>
                        {result.columns.map((column) => (
                          <td key={column.key}>{displayCell(row[column.key] ?? null)}</td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          ) : (
            <div className="result-empty">
              <span>
                <Icon name="table" size={22} />
              </span>
              <h2>No query result yet</h2>
              <p>Boot the engine, then run the lesson to inspect the classified invoice.</p>
              <button type="button" onClick={() => setActiveTab("database")}>
                Browse loaded relations
                <Icon name="chevron" size={14} />
              </button>
            </div>
          )}
        </section>
      ) : (
        <section className="database-view" id="database-view" role="tabpanel">
          <div className="relation-browser">
            <div className="relation-browser-title">
              <span>main</span>
              <small>DuckDB</small>
            </div>
            {Object.entries(groupedRelations).map(([layer, layerRelations]) => (
              <section className="relation-group" key={layer} aria-labelledby={`layer-${layer}`}>
                <h2 id={`layer-${layer}`}>{layer}</h2>
                <ul>
                  {layerRelations.map((relation) => (
                    <li key={relation.name}>
                      <button
                        type="button"
                        disabled={disabled}
                        data-active={relation.name === selected?.name}
                        aria-current={relation.name === selected?.name ? "true" : undefined}
                        onClick={() => selectRelation(relation.name)}
                      >
                        <Icon name={relation.kind === "view" ? "code" : "table"} size={14} />
                        <span>{relation.name}</span>
                        {relation.rowCount !== undefined ? <small>{relation.rowCount}</small> : null}
                      </button>
                    </li>
                  ))}
                </ul>
              </section>
            ))}
          </div>

          {selected ? (
            <div className="relation-detail">
              <header>
                <span className="relation-kind-icon">
                  <Icon name={selected.kind === "view" ? "code" : "table"} size={17} />
                </span>
                <span>
                  <small>{selected.schema}</small>
                  <h2>{selected.name}</h2>
                </span>
                <span className="relation-kind">{selected.kind}</span>
              </header>
              <div className="relation-meta">
                <span>
                  Rows <strong>{selected.rowCount ?? "—"}</strong>
                </span>
                <span>
                  Columns <strong>{selected.columns.length}</strong>
                </span>
              </div>
              <table className="schema-table">
                <caption className="sr-only">Columns in {selected.name}</caption>
                <thead>
                  <tr>
                    <th scope="col">Column</th>
                    <th scope="col">Type</th>
                  </tr>
                </thead>
                <tbody>
                  {selected.columns.map((column) => (
                    <tr key={column.name}>
                      <td>{column.name}</td>
                      <td>{column.type}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="relation-detail result-empty">
              <p>No relations are loaded.</p>
            </div>
          )}
        </section>
      )}
    </aside>
  );
}
