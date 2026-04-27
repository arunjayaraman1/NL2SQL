"""
JSONB Column Formatter for NL2SQL

Formats JSONB columns in query results for better readability.
Transforms raw JSON arrays/objects into human-readable text.
"""

from __future__ import annotations

import json
from typing import Any


MAX_DISPLAY_ITEMS = 5


def _is_json_serializable(value: Any) -> bool:
    """Check if value is JSON-like (list or dict)."""
    return isinstance(value, (list, dict))


def _format_json_value(value: Any, max_items: int = MAX_DISPLAY_ITEMS) -> str:
    """Format JSON list/dict as readable text."""
    if value is None:
        return "(empty)"

    if isinstance(value, list):
        if not value:
            return "(empty)"
        formatted = [str(v) for v in value[:max_items]]
        if len(value) > max_items:
            return f"{', '.join(formatted)}, +{len(value) - max_items} more"
        return ", ".join(formatted)

    if isinstance(value, dict):
        if not value:
            return "(empty)"
        parts = []
        for k, v in list(value.items())[:max_items]:
            if isinstance(v, (list, dict)):
                parts.append(f"{k}: {_format_json_value(v, max_items=3)}")
            else:
                parts.append(f"{k}: {v}")
        if len(value) > max_items:
            return ", ".join(parts) + f", +{len(value) - max_items} more"
        return ", ".join(parts)

    return str(value)


def _parse_json_string(value: Any) -> Any:
    """Parse JSON string if possible, else return original."""
    if isinstance(value, str):
        try:
            return json.loads(value)
        except (json.JSONDecodeError, TypeError):
            pass
    return value


def get_jsonb_column_names(profile_cache) -> set[str]:
    """Extract all JSONB column names from profile cache."""
    if profile_cache is None:
        return set()

    jsonb_cols: set[str] = set()
    for table in profile_cache.tables.values():
        for col_name, col in table.columns.items():
            if col.is_json_type:
                jsonb_cols.add(col_name)
    return jsonb_cols


def format_results(
    rows: list[dict],
    columns: list[str],
    profile_cache,
) -> tuple[list[dict], list[str]]:
    """
    Format JSONB columns in query results for readability.

    Args:
        rows: List of row dicts from query
        columns: Column names
        profile_cache: ProfileCache with column type info

    Returns:
        Tuple of (formatted_rows, columns)
    """
    if not profile_cache or not rows:
        return rows, columns

    jsonb_cols = get_jsonb_column_names(profile_cache)
    if not jsonb_cols:
        return rows, columns

    formatted_rows: list[dict] = []
    for row in rows:
        new_row: dict[str, Any] = {}
        for col, value in row.items():
            if col in jsonb_cols and value is not None:
                parsed = _parse_json_string(value)
                if _is_json_serializable(parsed):
                    value = _format_json_value(parsed)
            new_row[col] = value
        formatted_rows.append(new_row)

    return formatted_rows, columns


if __name__ == "__main__":
    print("JSONB Formatter Tests")
    print("=" * 50)

    test_cases = [
        (["Diabetes"], "Simple list"),
        (["Diabetes", "Hypertension"], "Multi-item list"),
        (["A", "B", "C", "D", "E", "F"], "Long list (>5 items)"),
        ({"bp": "140/90", "pulse": 80}, "Simple dict"),
        ({"name": "John", "phone": "555-1234"}, "Dict with multiple keys"),
        (None, "None value"),
        ([], "Empty list"),
        ({}, "Empty dict"),
    ]

    for value, desc in test_cases:
        result = _format_json_value(value)
        print(f"{desc}: {repr(value)} → '{result}'")