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


def format_enhanced_schema(
    profile_cache, summary_cache=None, table_names: list[str] = None
) -> str:
    """
    Format enhanced schema with LLM column summaries.

    Args:
        profile_cache: ProfileCache from profiler module
        summary_cache: Optional ColumnSummaryCache from column_summarizer
        table_names: Optional list of tables to include

    Returns:
        Formatted schema string with column summaries
    """
    from profiler import format_profiled_schema as _format_base

    base_schema = _format_base(profile_cache, table_names)

    if summary_cache is None:
        return base_schema

    lines = base_schema.split("\n")
    enhanced_lines = []

    for i, line in enumerate(lines):
        enhanced_lines.append(line)

        if line.strip().startswith("Table:"):
            table_name = line.split(":")[1].split("(")[0].strip()
            continue

        if line.strip().startswith("- "):
            column_match = line.split(":")[0] if ":" in line else None
            if column_match:
                col_name = column_match.replace("-", "").strip()

                if table_name and summary_cache.summaries.get(table_name, {}).get(
                    col_name
                ):
                    summary = summary_cache.summaries[table_name][col_name]
                    enhanced_lines.append(
                        f"      [{summary.short_label}] {summary.description}"
                    )

    return "\n".join(enhanced_lines)


def get_intent_hints(question: str) -> str:
    """
    Get intent-based hints for the prompt.
    Imported from validator.py at runtime to avoid circular imports.
    """
    from validator import build_intent_hints

    return build_intent_hints(question)


def get_literal_hints(question: str, literal_cache=None) -> str:
    """
    Get literal value hints for the prompt.
    Matches user terms to indexed column values.
    """
    if literal_cache is None:
        return ""

    try:
        from literal_matcher import match_terms_in_question, format_literal_hints

        matches = match_terms_in_question(question, literal_cache)
        return format_literal_hints(matches)
    except ImportError:
        return ""


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
    literal_cache=None,
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
    intent_hints = get_intent_hints(question)
    literal_hints = get_literal_hints(question, literal_cache)

    intent_block = f"\n{intent_hints}\n" if intent_hints else ""
    literal_block = f"\n{literal_hints}\n" if literal_hints else ""

    return f"""You are a PostgreSQL SQL expert. Given the database schema below and a user question, output a single SELECT query that answers the question.
{intent_block}{literal_block}{dialect_block}Below are example questions and valid SQL for this same kind of schema (tables and relationships like in the schema section):

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
    summary_cache=None,
    include_dialect_hints: bool | None = None,
) -> str:
    """
    Build the user prompt for SQL generation using profiled schema.

    Args:
        profile_cache: ProfileCache from profiler module
        question: User's natural language question
        summary_cache: Optional ColumnSummaryCache from column_summarizer
        include_dialect_hints: Whether to include PostgreSQL dialect hints
    """
    if include_dialect_hints is None:
        include_dialect_hints = _dialect_hints_enabled()

    dialect_block = ""
    if include_dialect_hints:
        dialect_block = f"{POSTGRES_HINTS}\n\n"

    few_shots = _format_few_shots()
    profiled_schema = format_enhanced_schema(profile_cache, summary_cache)
    intent_hints = get_intent_hints(question)
    intent_block = f"\n{intent_hints}\n" if intent_hints else ""

    return f"""You are a PostgreSQL SQL expert. Given the database schema below and a user question, output a single SELECT query that answers the question.
{intent_block}{dialect_block}Below are example questions and valid SQL for this same kind of schema (tables and relationships like in the schema section):
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


def build_two_pass_prompt(
    initial_sql: str,
    filtered_schema: str,
    question: str,
) -> str:
    """
    Build prompt for second pass with filtered schema (Schema Linking).

    Pass 1 generated SQL with full schema. Now we provide:
    - The initial SQL
    - Only the relevant tables/columns (filtered schema)
    - The original question

    The LLM can then verify and refine the SQL against the focused schema.

    Args:
        initial_sql: SQL generated in pass 1
        filtered_schema: Schema containing only used tables/columns
        question: Original user question

    Returns:
        Prompt string for second pass
    """
    return f"""You previously generated this SQL for the user's question:

Question: {question}

Initial SQL:
{initial_sql}

Now you have a FILTERED schema containing ONLY the tables and columns that were actually used in the query above.
Use this focused schema to verify and refine the SQL if needed.

Filtered schema (only relevant tables/columns):
{filtered_schema}

Instructions:
- Review the initial SQL against the filtered schema above
- Fix any issues with table or column names
- Ensure JOIN conditions and relationships are correct
- Make any improvements needed
- Output ONLY the corrected SQL statement
- Do NOT include explanations, markdown, or anything other than the SQL

SQL:"""
