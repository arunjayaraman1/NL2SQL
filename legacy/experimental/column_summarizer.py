"""
LLM-based Column Summarization for NL2SQL

Generates semantic descriptions for database columns using LLM.
This helps the SQL generation LLM understand column meaning beyond just data types.

Features:
- Automatic column summarization using LLM
- Caching for performance (24 hour TTL)
- Batch processing to minimize API calls
- Fallback rules for common column patterns
"""

from __future__ import annotations

import json
import logging
import os
import re
from dataclasses import dataclass, asdict, field
from datetime import datetime
from pathlib import Path
from typing import Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

CACHE_FILE = os.getenv("COLUMN_SUMMARY_CACHE_FILE", "column_summary_cache.json")
DEFAULT_TTL = int(os.getenv("COLUMN_SUMMARY_TTL", "86400"))  # 24 hours


@dataclass
class ColumnSummary:
    short_label: str
    description: str
    inferred_type: str  # "identifier", "name", "metric", "date", "status", "text"
    confidence: float

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> ColumnSummary:
        return cls(**data)


@dataclass
class ColumnSummaryCache:
    database_hash: str
    generated_at: str
    expires_in_seconds: int
    summaries: dict[str, dict[str, ColumnSummary]] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "database_hash": self.database_hash,
            "generated_at": self.generated_at,
            "expires_in_seconds": self.expires_in_seconds,
            "summaries": {
                table: {col: summary.to_dict() for col, summary in cols.items()}
                for table, cols in self.summaries.items()
            },
        }

    @classmethod
    def from_dict(cls, data: dict) -> cls:
        summaries = {
            table: {col: ColumnSummary.from_dict(s) for col, s in cols.items()}
            for table, cols in data["summaries"].items()
        }
        return cls(
            database_hash=data["database_hash"],
            generated_at=data["generated_at"],
            expires_in_seconds=data["expires_in_seconds"],
            summaries=summaries,
        )


SUMMARIZE_PROMPT = """You are a database expert. Analyze this column and provide a semantic description.

Column: {column_name}
Table: {table_name}
Data type: {data_type}
Null percentage: {null_pct}%
Distinct values: {distinct_count}
Sample values: {samples}
Range: {min_val} to {max_val}
Primary key: {is_pk}
Foreign key: {is_fk}

Output JSON with these exact fields:
{{
  "short_label": "2-3 word label (e.g., Employee ID, Department, Salary)",
  "description": "1-2 sentence description of what this column represents",
  "inferred_type": "one of: identifier, name, metric, date, status, boolean, text, email, phone, foreign_key",
  "confidence": number between 0.0 and 1.0
}}"""


FALLBACK_RULES = {
    r"^id$": {
        "short_label": "ID",
        "description": "Unique identifier",
        "inferred_type": "identifier",
        "confidence": 1.0,
    },
    r"_?id$": {
        "short_label": "ID",
        "description": "Unique identifier for this record",
        "inferred_type": "identifier",
        "confidence": 0.9,
    },
    r"^name$": {
        "short_label": "Name",
        "description": "Name of the entity",
        "inferred_type": "name",
        "confidence": 0.9,
    },
    r"first_?name$": {
        "short_label": "First Name",
        "description": "Person's given name",
        "inferred_type": "name",
        "confidence": 1.0,
    },
    r"last_?name$": {
        "short_label": "Last Name",
        "description": "Person's family name",
        "inferred_type": "name",
        "confidence": 1.0,
    },
    r"email$": {
        "short_label": "Email",
        "description": "Email address",
        "inferred_type": "email",
        "confidence": 1.0,
    },
    r"phone$": {
        "short_label": "Phone",
        "description": "Phone number",
        "inferred_type": "phone",
        "confidence": 1.0,
    },
    r"salary$": {
        "short_label": "Salary",
        "description": "Monetary salary amount",
        "inferred_type": "metric",
        "confidence": 1.0,
    },
    r"amount$": {
        "short_label": "Amount",
        "description": "Monetary or quantity amount",
        "inferred_type": "metric",
        "confidence": 0.9,
    },
    r"count$": {
        "short_label": "Count",
        "description": "Number/count of items",
        "inferred_type": "metric",
        "confidence": 0.9,
    },
    r"total$": {
        "short_label": "Total",
        "description": "Total sum of values",
        "inferred_type": "metric",
        "confidence": 0.9,
    },
    r"date$": {
        "short_label": "Date",
        "description": "Date value",
        "inferred_type": "date",
        "confidence": 0.9,
    },
    r"_?date$": {
        "short_label": "Date",
        "description": "Date when something occurred",
        "inferred_type": "date",
        "confidence": 0.9,
    },
    r"hire_?date$": {
        "short_label": "Hire Date",
        "description": "Date when employee was hired",
        "inferred_type": "date",
        "confidence": 1.0,
    },
    r"created_?at$": {
        "short_label": "Created At",
        "description": "Timestamp when record was created",
        "inferred_type": "date",
        "confidence": 1.0,
    },
    r"updated_?at$": {
        "short_label": "Updated At",
        "description": "Timestamp when record was last updated",
        "inferred_type": "date",
        "confidence": 1.0,
    },
    r"status$": {
        "short_label": "Status",
        "description": "Current status of the record",
        "inferred_type": "status",
        "confidence": 0.9,
    },
    r"is_?active$": {
        "short_label": "Active Status",
        "description": "Whether the record is currently active",
        "inferred_type": "boolean",
        "confidence": 1.0,
    },
    r"is_": {
        "short_label": "Boolean Flag",
        "description": "Boolean indicator",
        "inferred_type": "boolean",
        "confidence": 0.9,
    },
    r"_?type$": {
        "short_label": "Type",
        "description": "Type or category classification",
        "inferred_type": "status",
        "confidence": 0.8,
    },
    r"title$": {
        "short_label": "Title",
        "description": "Job or position title",
        "inferred_type": "name",
        "confidence": 0.9,
    },
    r"description$": {
        "short_label": "Description",
        "description": "Text description",
        "inferred_type": "text",
        "confidence": 0.9,
    },
    r"balance$": {
        "short_label": "Balance",
        "description": "Remaining balance (days, money, etc)",
        "inferred_type": "metric",
        "confidence": 0.9,
    },
    r"used$": {
        "short_label": "Used",
        "description": "Amount or count used",
        "inferred_type": "metric",
        "confidence": 0.8,
    },
    r"department$": {
        "short_label": "Department",
        "description": "Organizational department",
        "inferred_type": "name",
        "confidence": 0.9,
    },
    r"_?id$": {
        "short_label": "Reference ID",
        "description": "Foreign key reference",
        "inferred_type": "foreign_key",
        "confidence": 0.8,
    },
}


def apply_fallback_rules(
    column_name: str, data_type: str, samples: list[str]
) -> Optional[ColumnSummary]:
    """Apply fallback rules for common column patterns."""
    column_lower = column_name.lower()

    for pattern, result in FALLBACK_RULES.items():
        if re.search(pattern, column_lower):
            return ColumnSummary(
                short_label=result["short_label"],
                description=result["description"],
                inferred_type=result["inferred_type"],
                confidence=result["confidence"],
            )

    return None


def build_summarize_prompt(
    column_name: str,
    table_name: str,
    data_type: str,
    null_pct: float,
    distinct_count: int,
    samples: list[str],
    min_val: Optional[str],
    max_val: Optional[str],
    is_pk: bool,
    is_fk: bool,
    related_table: Optional[str] = None,
) -> str:
    """Build the prompt for LLM summarization."""
    samples_str = ", ".join(str(s) for s in samples[:5])

    related_info = ""
    if is_fk and related_table:
        related_info = f"Referenced table: {related_table}"

    return SUMMARIZE_PROMPT.format(
        column_name=column_name,
        table_name=table_name,
        data_type=data_type,
        null_pct=null_pct,
        distinct_count=distinct_count,
        samples=samples_str,
        min_val=min_val or "N/A",
        max_val=max_val or "N/A",
        is_pk="Yes" if is_pk else "No",
        is_fk=related_info or "No",
    )


def parse_llm_response(response: str) -> Optional[ColumnSummary]:
    """Parse LLM response to extract column summary."""
    try:
        json_match = re.search(r"\{[^}]+\}", response, re.DOTALL)
        if json_match:
            data = json.loads(json_match.group())
            return ColumnSummary(
                short_label=data.get("short_label", "Unknown"),
                description=data.get("description", "No description"),
                inferred_type=data.get("inferred_type", "text"),
                confidence=float(data.get("confidence", 0.5)),
            )
    except (json.JSONDecodeError, KeyError, ValueError) as e:
        logger.warning(f"Failed to parse LLM response: {e}")

    return None


def get_llm_client():
    """Get LLM client for summarization (OpenRouter via OpenAI-compatible API)."""
    try:
        from langchain_openai import ChatOpenAI

        return ChatOpenAI(
            model=os.getenv("LLM_MODEL", "meta-llama/llama-3.3-70b-instruct"),
            api_key=os.getenv("OPENAI_API_KEY"),
            base_url=os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1"),
            temperature=0.3,
            max_tokens=256,
        )
    except ImportError:
        logger.warning("langchain-openai not available, using fallback rules only")
        return None


def summarize_column_with_llm(
    column_name: str,
    table_name: str,
    data_type: str,
    null_pct: float,
    distinct_count: int,
    samples: list[str],
    min_val: Optional[str],
    max_val: Optional[str],
    is_pk: bool,
    is_fk: bool,
    related_table: Optional[str] = None,
) -> ColumnSummary:
    """Summarize a single column using LLM or fallback rules."""
    logger.info(f"Summarizing column: {table_name}.{column_name}")

    fallback = apply_fallback_rules(column_name, data_type, samples)
    if fallback and fallback.confidence >= 0.95:
        logger.info(f"Using high-confidence fallback for {column_name}")
        return fallback

    llm = get_llm_client()
    if llm is None:
        if fallback:
            return fallback
        return ColumnSummary(
            short_label=column_name.replace("_", " ").title(),
            description=f"Column {column_name}",
            inferred_type="text",
            confidence=0.3,
        )

    try:
        prompt = build_summarize_prompt(
            column_name,
            table_name,
            data_type,
            null_pct,
            distinct_count,
            samples,
            min_val,
            max_val,
            is_pk,
            is_fk,
            related_table,
        )

        response = llm.invoke(prompt)
        result = parse_llm_response(response.content)

        if result:
            return result

    except Exception as e:
        logger.warning(f"LLM summarization failed for {column_name}: {e}")

    if fallback:
        return fallback

    return ColumnSummary(
        short_label=column_name.replace("_", " ").title(),
        description=f"Column containing {data_type} values",
        inferred_type="text",
        confidence=0.3,
    )


def load_summary_cache(path: str = CACHE_FILE) -> Optional[ColumnSummaryCache]:
    """Load summary cache from file."""
    cache_path = Path(path)
    if not cache_path.exists():
        return None

    try:
        with open(cache_path, "r") as f:
            data = json.load(f)
        return ColumnSummaryCache.from_dict(data)
    except (json.JSONDecodeError, KeyError, TypeError) as e:
        logger.warning(f"Failed to load summary cache: {e}")
        return None


def save_summary_cache(cache: ColumnSummaryCache, path: str = CACHE_FILE) -> None:
    """Save summary cache to file."""
    cache_path = Path(path)
    cache_path.parent.mkdir(parents=True, exist_ok=True)

    with open(cache_path, "w") as f:
        json.dump(cache.to_dict(), f, indent=2)


def is_cache_valid(cache: ColumnSummaryCache, current_hash: str) -> bool:
    """Check if cache is valid."""
    if cache.database_hash != current_hash:
        return False

    generated = datetime.fromisoformat(cache.generated_at)
    age_seconds = (datetime.utcnow() - generated).total_seconds()

    return age_seconds < cache.expires_in_seconds


def summarize_table_columns(
    table_name: str, columns: dict, db_hash: str, force_refresh: bool = False
) -> dict[str, ColumnSummary]:
    """Summarize all columns in a table."""
    cache = load_summary_cache()
    current_cache = cache.summaries.get(table_name, {}) if cache else {}

    if not force_refresh and cache and is_cache_valid(cache, db_hash):
        return current_cache

    summaries = {}
    for col_name, col_data in columns.items():
        if not force_refresh and col_name in current_cache:
            summaries[col_name] = current_cache[col_name]
            continue

        summary = summarize_column_with_llm(
            column_name=col_name,
            table_name=table_name,
            data_type=col_data.get("data_type", "unknown"),
            null_pct=col_data.get("null_percentage", 0),
            distinct_count=col_data.get("distinct_count", 0),
            samples=col_data.get("samples", []),
            min_val=col_data.get("min_value"),
            max_val=col_data.get("max_value"),
            is_pk=col_data.get("is_primary_key", False),
            is_fk=col_data.get("foreign_key") is not None,
            related_table=col_data.get("foreign_key", "").split(".")[0]
            if col_data.get("foreign_key")
            else None,
        )
        summaries[col_name] = summary

    return summaries


def summarize_database_columns(
    profile_tables: dict, db_hash: str, force_refresh: bool = False
) -> ColumnSummaryCache:
    """Summarize all columns in all tables."""
    cache = load_summary_cache()

    if not force_refresh and cache and is_cache_valid(cache, db_hash):
        logger.info("Using cached column summaries")
        return cache

    logger.info(f"Generating column summaries for {len(profile_tables)} tables")

    all_summaries = {}
    for table_name, table_data in profile_tables.items():
        columns = {}
        for col_name, col_data in table_data.get("columns", {}).items():
            columns[col_name] = col_data

        table_summaries = summarize_table_columns(
            table_name, columns, db_hash, force_refresh
        )
        all_summaries[table_name] = table_summaries

    result = ColumnSummaryCache(
        database_hash=db_hash,
        generated_at=datetime.utcnow().isoformat(),
        expires_in_seconds=DEFAULT_TTL,
        summaries=all_summaries,
    )

    save_summary_cache(result)
    logger.info(f"Column summaries saved to {CACHE_FILE}")

    return result


def format_column_summary_for_schema(summary: ColumnSummary) -> str:
    """Format column summary for schema display."""
    return f"[{summary.short_label}] {summary.description}"


def get_column_summary(
    table_name: str, column_name: str, cache: ColumnSummaryCache = None
) -> Optional[ColumnSummary]:
    """Get summary for a specific column."""
    if cache is None:
        cache = load_summary_cache()

    if cache and table_name in cache.summaries:
        return cache.summaries[table_name].get(column_name)

    return None


if __name__ == "__main__":
    print("=" * 60)
    print("Column Summarizer Test")
    print("=" * 60)

    test_cases = [
        ("id", "employees", "integer", 0, 25, [1, 2, 3], "1", "25", True, False, None),
        (
            "email",
            "employees",
            "varchar",
            0,
            25,
            ["john@corp.com"],
            None,
            None,
            False,
            False,
            None,
        ),
        (
            "hire_date",
            "employees",
            "date",
            0,
            20,
            ["2020-01-15"],
            "2020-01-15",
            "2024-06-30",
            False,
            False,
            None,
        ),
        (
            "department_id",
            "employees",
            "integer",
            5,
            5,
            [1, 2, 3],
            "1",
            "5",
            False,
            True,
            "departments",
        ),
        (
            "salary",
            "employees",
            "numeric",
            8,
            20,
            [50000, 75000],
            "30000",
            "150000",
            False,
            False,
            None,
        ),
    ]

    for col in test_cases:
        result = summarize_column_with_llm(*col)
        print(f"\n{col[1]}.{col[0]}:")
        print(f"  Label: {result.short_label}")
        print(f"  Description: {result.description}")
        print(f"  Type: {result.inferred_type}")
        print(f"  Confidence: {result.confidence}")
