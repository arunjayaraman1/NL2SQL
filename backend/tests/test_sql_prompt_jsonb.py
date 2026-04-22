import unittest
from unittest.mock import patch

from backend.core.sql_prompt import (
    build_profiled_schema_prompt,
    build_sql_generation_prompt,
)


class SqlPromptJsonbTests(unittest.TestCase):
    def test_build_sql_generation_prompt_excludes_jsonb_hints_by_default(self):
        prompt = build_sql_generation_prompt("Table: public.events", "Find active records")
        self.assertNotIn("PostgreSQL JSONB hints (optional feature enabled):", prompt)

    def test_build_sql_generation_prompt_includes_jsonb_hints_when_enabled(self):
        prompt = build_sql_generation_prompt(
            "Table: public.events",
            "Find records where payload status is active",
            enable_jsonb_querying=True,
        )
        self.assertIn("PostgreSQL JSONB hints (optional feature enabled):", prompt)
        self.assertIn("->> to extract text values", prompt)

    def test_build_profiled_schema_prompt_includes_jsonb_hints_when_enabled(self):
        with patch(
            "backend.core.sql_prompt.format_enhanced_schema",
            return_value="Table: public.events",
        ):
            prompt = build_profiled_schema_prompt(
                object(),
                "Count rows where metadata contains tier gold",
                enable_jsonb_querying=True,
            )
            self.assertIn("PostgreSQL JSONB hints (optional feature enabled):", prompt)


if __name__ == "__main__":
    unittest.main()
