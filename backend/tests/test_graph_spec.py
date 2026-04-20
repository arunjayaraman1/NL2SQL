import unittest

from backend.core import graph_spec


class GraphSpecTests(unittest.TestCase):
    def test_validate_graph_spec_accepts_valid_spec(self):
        columns = ["department", "total_salary", "headcount"]
        data = [
            {"department": "Engineering", "total_salary": 1000, "headcount": 3},
            {"department": "Sales", "total_salary": 700, "headcount": 2},
        ]
        spec = {
            "chart_type": "bar",
            "x_key": "department",
            "y_keys": ["total_salary", "headcount"],
        }

        validated = graph_spec.validate_graph_spec(spec, columns, data)

        self.assertEqual(validated["chart_type"], "bar")
        self.assertEqual(validated["x_key"], "department")
        self.assertEqual(validated["y_keys"], ["total_salary", "headcount"])

    def test_validate_graph_spec_rejects_missing_columns(self):
        columns = ["department", "total_salary"]
        data = [{"department": "Engineering", "total_salary": 1000}]
        spec = {"chart_type": "line", "x_key": "day", "y_keys": ["total_salary"]}

        validated = graph_spec.validate_graph_spec(spec, columns, data)

        self.assertIsNone(validated)

    def test_fallback_graph_spec_prefers_line_for_time_series(self):
        columns = ["order_date", "revenue"]
        data = [
            {"order_date": "2026-01-01", "revenue": 100},
            {"order_date": "2026-01-02", "revenue": 140},
        ]

        spec = graph_spec.build_fallback_graph_spec(columns, data)

        self.assertEqual(spec["chart_type"], "line")
        self.assertEqual(spec["x_key"], "order_date")
        self.assertEqual(spec["y_keys"], ["revenue"])

    def test_fallback_graph_spec_uses_none_when_not_chartable(self):
        columns = ["id", "name"]
        data = [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]

        spec = graph_spec.build_fallback_graph_spec(columns, data)

        self.assertEqual(spec["chart_type"], "none")
        self.assertEqual(spec["x_key"], "")
        self.assertEqual(spec["y_keys"], [])


if __name__ == "__main__":
    unittest.main()
