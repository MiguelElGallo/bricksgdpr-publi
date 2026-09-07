"""Render the evidence access macro with existing and absent ambient grants."""

import unittest
from pathlib import Path
from types import SimpleNamespace

from jinja2 import Environment, StrictUndefined


class EvidenceAccessTests(unittest.TestCase):
    def render_access(self, ambient):
        source = (
            Path(__file__).resolve().parents[2] / "macros/deletion_operations.sql"
        ).read_text()
        macro = source.split("{% macro apply_deletion_evidence_access() %}", 1)[1]
        macro = macro.split("{% endmacro %}", 1)[0]
        queries = []

        def query(sql):
            queries.append(sql)
            return SimpleNamespace(rows=[(principal,) for principal in ambient])

        Environment(extensions=["jinja2.ext.do"], undefined=StrictUndefined).from_string(
            macro
        ).render(
            execute=True,
            deletion_evidence_relation=lambda name: f"`demo_evidence`.`deletion_control`.`{name}`",
            var=lambda name, default: default,
            env_var=lambda name, default: "demo" if name == "DBT_PROJECT_CATALOG" else default,
            adapter=SimpleNamespace(quote=lambda name: f"`{name}`"),
            run_query=query,
        )
        return queries

    def test_existing_ambient_groups_lose_all_evidence_boundaries(self):
        discovery, *revokes = self.render_access(["account users", "users"])
        self.assertIn("catalog_name = 'demo_evidence'", discovery)
        self.assertIn("table_catalog = 'demo_evidence'", discovery)
        self.assertIn("schema_name = 'deletion_control'", discovery)
        self.assertIn("table_schema = 'deletion_control'", discovery)
        self.assertIn("grantee in ('account users', 'users')", discovery)
        self.assertEqual(len(revokes), 20)
        for principal in [
            "privacy_admins",
            "restricted_users",
            "case_users",
            "account users",
            "users",
        ]:
            for boundary in [
                "catalog `demo_evidence`",
                "schema `demo_evidence`.`deletion_control`",
                "table `demo_evidence`.`deletion_control`.`control_history`",
                "table `demo_evidence`.`deletion_control`.`execution_events`",
            ]:
                self.assertIn(f"revoke all privileges on {boundary} from `{principal}`", revokes)

    def test_absent_ambient_groups_are_not_revoked(self):
        for ambient in [[], ["account users"]]:
            with self.subTest(ambient=ambient):
                _, *revokes = self.render_access(ambient)
                self.assertEqual(len(revokes), 12 + 4 * len(ambient))
                self.assertFalse(any(sql.endswith("from `users`") for sql in revokes))


if __name__ == "__main__":
    unittest.main()
