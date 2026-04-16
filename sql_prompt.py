"""
Shared NL→SQL prompt builder for CLI (app.py) and FastAPI (backend/main.py).

Uses HR schema examples from hr_examples.py.
Set NL2SQL_INCLUDE_DIALECT_HINTS=false to omit the PostgreSQL hints block.
"""

from __future__ import annotations

import os
from typing import TypedDict

from hr_examples import FEW_SHOT_EXAMPLES, get_few_shot_examples


def format_profiled_schema(cache, table_names: list[str] = None) -> str:
    """
    Format profiled schema for LLM prompts.
    This function is imported from profiler.py at runtime to avoid circular imports.
    """
    from profiler import format_profiled_schema as _format

    return _format(cache, table_names)


class FewShotExample(TypedDict):
    question: str
    sql: str


def _load_examples() -> list[FewShotExample]:
    """Load few-shot examples from hr_examples module."""
    return get_few_shot_examples()


POSTGRES_HINTS = """PostgreSQL dialect (target database):
- Use standard SQL and PostgreSQL-supported syntax only.
- Prefer explicit INNER JOIN / LEFT JOIN rather than comma joins.
- For case-insensitive partial text match on user phrases, consider ILIKE with wildcards; use = for exact matches.
- Quoted identifiers ("MixedCase") are case-sensitive; unquoted names are folded to lower case.
- Dates are DATE or TIMESTAMP; compare DATE columns to date literals like '2023-10-15'.
- When the user asks for the top N rows, add LIMIT N (e.g. LIMIT 10).
- Use COALESCE for handling NULL values with defaults.
- For complex aggregations, use HAVING after GROUP BY.
"""


def _dialect_hints_enabled() -> bool:
    return os.getenv("NL2SQL_INCLUDE_DIALECT_HINTS", "true").lower() not in (
        "0",
        "false",
        "no",
    )


def _format_few_shots() -> str:
    """Format few-shot examples as a string for the prompt."""
    examples = _load_examples()
    parts: list[str] = []
    for i, ex in enumerate(examples, start=1):
        parts.append(f"Example {i}\nQuestion: {ex['question']}\nSQL:\n{ex['sql']}\n")
    return "\n".join(parts).rstrip()


def build_sql_generation_prompt(
    schema: str,
    question: str,
    *,
    include_dialect_hints: bool | None = None,
) -> str:
    """
    Build the full user prompt for SQL generation.

    If include_dialect_hints is None, NL2SQL_INCLUDE_DIALECT_HINTS controls inclusion (default on).
    """
    if include_dialect_hints is None:
        include_dialect_hints = _dialect_hints_enabled()

    dialect_block = ""
    if include_dialect_hints:
        dialect_block = f"{POSTGRES_HINTS}\n\n"

    few_shots = _format_few_shots()

    return f"""You are a PostgreSQL SQL expert. Given the database schema below and a user question, output a single SELECT query that answers the question.

{dialect_block}Below are example questions and valid SQL for this same kind of schema (tables and relationships like in the schema section):

{few_shots}

Current database schema (authoritative; use only these tables and columns):
{schema}

User question:
{question}

Rules:
- Output a single SELECT statement only. No WITH unless needed for clarity.
- Use only tables and columns from the schema above.
- Do not add any SQL clauses (ORDER BY, GROUP BY, HAVING, LIMIT, WHERE conditions, etc.) unless explicitly requested by the user.
- Keep the query minimal - do exactly what is asked, nothing more.
- Do not include explanations, markdown code fences, or comments outside the SQL.
- Do not output anything before or after the SQL statement.

SQL:"""


# Also export for backward compatibility with app.py
FEW_SHOT_EXAMPLES = _load_examples()


def build_profiled_schema_prompt(
    profile_cache,
    question: str,
    *,
    include_dialect_hints: bool | None = None,
) -> str:
    """
    Build the user prompt for SQL generation using profiled schema.

    Args:
        profile_cache: ProfileCache from profiler module
        question: User's natural language question
        include_dialect_hints: Whether to include PostgreSQL dialect hints
    """
    if include_dialect_hints is None:
        include_dialect_hints = _dialect_hints_enabled()

    dialect_block = ""
    if include_dialect_hints:
        dialect_block = f"{POSTGRES_HINTS}\n\n"
    few_shots = _format_few_shots()
    profiled_schema = format_profiled_schema(profile_cache)
    return f"""You are a PostgreSQL SQL expert. Given the database schema below and a user question, output a single SELECT query that answers the question.
{dialect_block}Below are example questions and valid SQL for this same kind of schema (tables and relationships like in the schema section):
{few_shots}
Current database schema (authoritative; use only these tables and columns):
{profiled_schema}
User question:
{question}
Rules:
- Output a single SELECT statement only. No WITH unless needed for clarity.
- Use only tables and columns from the schema above.
- Do not add any SQL clauses (ORDER BY, GROUP BY, HAVING, LIMIT, WHERE conditions, etc.) unless explicitly requested by the user.
- Keep the query minimal - do exactly what is asked, nothing more.
- Do not include explanations, markdown code fences, or comments outside the SQL.
- Do not output anything before or after the SQL statement. 
SQL:"""
