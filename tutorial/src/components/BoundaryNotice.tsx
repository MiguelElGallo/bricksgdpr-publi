import { Icon } from "./Icon";

export function BoundaryNotice() {
  return (
    <section className="boundary-notice" aria-labelledby="teaching-boundary-title">
      <div className="boundary-icon">
        <Icon name="shield" size={19} />
      </div>
      <p>
        <strong id="teaching-boundary-title">DuckDB teaching edition</strong>
        <span aria-hidden="true">·</span>
        Synthetic data only. This browser lab teaches the transformation flow; it does not prove
        Databricks or Unity Catalog security controls.
      </p>
      <a href="../explanation/demo-and-production-boundaries/">
        Read the boundary
        <Icon name="chevron" size={14} />
      </a>
    </section>
  );
}
