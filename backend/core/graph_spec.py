from __future__ import annotations

from datetime import datetime
from typing import Any, Optional


ALLOWED_CHART_TYPES = {"bar", "line", "pie", "none"}
NONE_GRAPH_SPEC = {"chart_type": "none", "x_key": "", "y_keys": []}


def _to_float(value: Any) -> Optional[float]:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        text = value.strip().replace(",", "")
        if not text:
            return None
        try:
            return float(text)
        except Exception:
            return None
    return None


def _is_date_like(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    text = value.strip()
    if not text:
        return False
    if "T" in text and text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        datetime.fromisoformat(text)
        return True
    except Exception:
        return False


def _is_temporal_column(column: str, values: list[Any]) -> bool:
    name = column.lower()
    if any(token in name for token in ("date", "time", "month", "year", "day")):
        return True
    sample = [v for v in values if v is not None][:20]
    if not sample:
        return False
    hits = sum(1 for value in sample if _is_date_like(value))
    return hits >= max(1, int(len(sample) * 0.6))


def _is_numeric_column(values: list[Any]) -> bool:
    sample = [v for v in values if v is not None][:50]
    if not sample:
        return False
    numeric_hits = sum(1 for value in sample if _to_float(value) is not None)
    return numeric_hits >= max(1, int(len(sample) * 0.7))


def _looks_like_identifier(column: str, values: list[Any]) -> bool:
    name = column.lower()
    if name == "id" or name.endswith("_id"):
        return True

    sample = [v for v in values if v is not None][:100]
    if len(sample) < 3:
        return False
    numeric_values = [_to_float(value) for value in sample]
    if any(value is None for value in numeric_values):
        return False
    unique_ratio = len(set(numeric_values)) / len(numeric_values)
    return unique_ratio >= 0.95


def _column_values(data: list[dict], column: str) -> list[Any]:
    return [row.get(column) for row in data]


def validate_graph_spec(
    graph_spec: Any, columns: list[str], data: list[dict]
) -> Optional[dict[str, Any]]:
    if not isinstance(graph_spec, dict):
        return None

    chart_type = str(graph_spec.get("chart_type", "")).strip().lower()
    x_key = str(graph_spec.get("x_key", "")).strip()
    raw_y_keys = graph_spec.get("y_keys") or []
    if isinstance(raw_y_keys, str):
        raw_y_keys = [raw_y_keys]
    y_keys = [str(key).strip() for key in raw_y_keys if str(key).strip()]

    if chart_type not in ALLOWED_CHART_TYPES:
        return None
    if chart_type == "none":
        return dict(NONE_GRAPH_SPEC)

    if x_key not in columns:
        return None

    valid_y_keys: list[str] = []
    for key in y_keys:
        if key not in columns:
            continue
        values = _column_values(data, key)
        if _is_numeric_column(values):
            valid_y_keys.append(key)

    # Stable de-duplication.
    valid_y_keys = list(dict.fromkeys(valid_y_keys))
    if not valid_y_keys:
        return None

    if chart_type == "pie":
        valid_y_keys = valid_y_keys[:1]

    return {"chart_type": chart_type, "x_key": x_key, "y_keys": valid_y_keys}


def build_fallback_graph_spec(columns: list[str], data: list[dict]) -> dict[str, Any]:
    if not data or not columns:
        return dict(NONE_GRAPH_SPEC)

    numeric_columns: list[str] = []
    temporal_columns: list[str] = []
    categorical_columns: list[str] = []

    for column in columns:
        values = _column_values(data, column)
        if _is_numeric_column(values):
            numeric_columns.append(column)
        else:
            categorical_columns.append(column)
        if _is_temporal_column(column, values):
            temporal_columns.append(column)

    if not numeric_columns:
        return dict(NONE_GRAPH_SPEC)

    x_candidates = [c for c in columns if c not in numeric_columns]
    x_key = x_candidates[0] if x_candidates else ""
    if not x_key:
        return dict(NONE_GRAPH_SPEC)

    filtered_numeric = [
        column
        for column in numeric_columns
        if not _looks_like_identifier(column, _column_values(data, column))
    ]
    if not filtered_numeric:
        return dict(NONE_GRAPH_SPEC)

    chart_type = "bar"
    if x_key in temporal_columns:
        chart_type = "line"
    elif len(filtered_numeric) == 1:
        distinct_x = len({str(row.get(x_key)) for row in data if row.get(x_key) is not None})
        if 2 <= distinct_x <= 8:
            chart_type = "pie"

    y_keys = filtered_numeric[:3]
    if chart_type == "pie":
        y_keys = y_keys[:1]

    return {"chart_type": chart_type, "x_key": x_key, "y_keys": y_keys}
