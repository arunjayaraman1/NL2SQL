import os
import sys
import json
import subprocess
from pathlib import Path
from typing import TypedDict, Optional

_ROOT = Path(__file__).resolve().parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

import psycopg2
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from langchain_openai import ChatOpenAI

from sql_prompt import (
    build_sql_generation_prompt,
    build_profiled_schema_prompt,
    build_two_pass_prompt,
)
from profiler import profile_database, load_profile_cache, ProfileCache
from validator import validate_sql
from column_summarizer import (
    summarize_database_columns,
    load_summary_cache,
    ColumnSummaryCache,
)
from schema_linker import link_schema
from literal_matcher import (
    index_database,
    load_literal_cache,
    match_terms_in_question,
    LiteralCache,
)
from query_logger import QueryLogger, QueryLogEntry

load_dotenv()

LLM_MODEL = os.getenv("LLM_MODEL", "meta-llama/llama-3.3-70b-instruct")
LLM_TEMPERATURE = float(os.getenv("LLM_TEMPERATURE", "0.2"))
LLM_MAX_TOKENS = int(os.getenv("LLM_MAX_TOKENS", "1024"))
OPENROUTER_BASE_URL = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
DEFAULT_CORS_ORIGINS = ["http://localhost:3001", "http://localhost:3000"]

_profile_cache: Optional[ProfileCache] = None
_summary_cache: Optional[ColumnSummaryCache] = None
_literal_cache: Optional[LiteralCache] = None
_query_logger: Optional[QueryLogger] = None


def build_llm_client() -> ChatOpenAI:
    return ChatOpenAI(
        model=os.getenv("LLM_MODEL", "meta-llama/llama-3.3-70b-instruct"),
        api_key=os.getenv("OPENAI_API_KEY"),
        base_url=os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1"),
        temperature=float(os.getenv("LLM_TEMPERATURE", "0.2")),
        max_tokens=int(os.getenv("LLM_MAX_TOKENS", "1024")),
    )


def get_cors_origins() -> list[str]:
    """
    Return CORS allowlist from CORS_ALLOW_ORIGINS (comma-separated),
    falling back to local development defaults.
    """
    raw = os.getenv("CORS_ALLOW_ORIGINS", "").strip()
    if not raw:
        return DEFAULT_CORS_ORIGINS

    origins = [origin.strip() for origin in raw.split(",") if origin.strip()]
    return origins or DEFAULT_CORS_ORIGINS


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=get_cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    """Load profile, column summary, and literal caches on application startup."""
    global _profile_cache, _summary_cache, _literal_cache, _query_logger
    try:
        conn = get_db_connection()
        _profile_cache = profile_database(conn)
        print(f"Profile cache loaded: {len(_profile_cache.tables)} tables")

        _summary_cache = summarize_database_columns(
            {name: table.to_dict() for name, table in _profile_cache.tables.items()},
            _profile_cache.database_hash,
        )
        print(f"Column summaries loaded: {len(_summary_cache.summaries)} tables")

        _literal_cache = index_database(conn)
        total_values = sum(
            len(col.values)
            for table_cols in _literal_cache.literals.values()
            for col in table_cols.values()
        )
        print(f"Literal cache loaded: {total_values} values indexed")

        _query_logger = QueryLogger(conn)
        print("Query logger initialized")

        conn.close()
    except Exception as e:
        print(f"Warning: Could not load caches: {e}")


@app.on_event("shutdown")
async def shutdown_event():
    """Clean up on shutdown."""
    pass


# Retry state for tracking
class RetryState(TypedDict):
    question: str
    schema: str
    sql_query: str
    result: str
    iteration: int
    error: str


def get_db_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
    )


AVAILABLE_DATABASES = {
    "hr": {
        "name": "HR Database",
        "tables": [
            "departments",
            "jobs",
            "employees",
            "employees_history",
            "salaries",
            "bonuses",
            "leave_requests",
            "leave_balances",
            "attendance_logs",
            "performance_reviews",
            "training_enrollments",
            "certifications",
            "promotions",
            "terminations",
            "approvals",
            "emergency_contacts",
            "audit_logs",
        ],
    },
    "school": {
        "name": "School Database",
        "tables": [
            "students",
            "teachers",
            "courses",
            "classes",
            "enrollments",
            "attendance",
        ],
    },
}


def get_available_databases():
    """Return list of available databases/table groups."""
    return [
        {
            "id": "hr",
            "name": "HR Database",
            "table_count": len(AVAILABLE_DATABASES["hr"]["tables"]),
        },
        {
            "id": "school",
            "name": "School Database",
            "table_count": len(AVAILABLE_DATABASES["school"]["tables"]),
        },
    ]


def get_db_tables(db_type=None):
    """Get list of tables in the database."""
    conn = get_db_connection()
    cursor = conn.cursor()

    query = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name"
    cursor.execute(query)
    tables = [row[0] for row in cursor.fetchall()]

    cursor.close()
    conn.close()

    if db_type and db_type in AVAILABLE_DATABASES:
        allowed_tables = AVAILABLE_DATABASES[db_type]["tables"]
        tables = [t for t in tables if t in allowed_tables]

    return tables


def fetch_schema(db_type=None):
    """Fetch database schema, optionally filtered by database type."""
    conn = get_db_connection()
    cursor = conn.cursor()

    query = """
        SELECT table_name, column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        ORDER BY table_name, ordinal_position
    """

    cursor.execute(query)
    columns = cursor.fetchall()

    schema_lines = []
    current_table = None

    allowed_tables = None
    if db_type and db_type in AVAILABLE_DATABASES:
        allowed_tables = set(AVAILABLE_DATABASES[db_type]["tables"])

    for table, column, dtype in columns:
        if allowed_tables and table not in allowed_tables:
            continue
        if table != current_table:
            schema_lines.append(f"\nTable: {table}")
            current_table = table
        schema_lines.append(f"  - {column} ({dtype})")

    schema = "\n".join(schema_lines)

    cursor.close()
    conn.close()

    return schema


def is_retryable_error(error_msg: str) -> bool:
    """Check if the error is retryable (can be fixed by rewriting SQL)."""
    error_lower = error_msg.lower()

    # Non-retryable errors
    non_retryable = [
        "permission denied",
        "must be superuser",
        "must be owner",
        "connection refused",
        "could not connect",
        "password authentication failed",
    ]

    for pattern in non_retryable:
        if pattern in error_lower:
            return False

    # Retryable errors (SQL syntax, table/column issues)
    retryable = [
        "does not exist",
        "syntax error",
        "invalid syntax",
        "column",
        "operator does not exist",
        "type mismatch",
        "cannot adapt",
        "division by zero",
        "aggregate",
        "group by",
    ]

    for pattern in retryable:
        if pattern in error_lower:
            return True

    return False


def generate_sql(schema, question):
    llm = build_llm_client()

    prompt = build_sql_generation_prompt(schema, question)

    response = llm.invoke(prompt)
    sql = response.content.strip()

    # Remove markdown code blocks
    if sql.startswith("```"):
        sql = sql.split("```")[1]
        sql = sql.strip()
        if sql.startswith("sql"):
            sql = sql[3:].strip()

    # Validate and auto-fix SQL
    validation_result = validate_sql(sql, question)
    if validation_result.fixes_applied:
        print(f"[Validator] Fixes applied: {validation_result.fixes_applied}")
    if validation_result.issues:
        print(f"[Validator] Issues found: {validation_result.issues}")

    return validation_result.sql


def generate_sql_two_pass(
    schema: str,
    question: str,
    profile_cache: ProfileCache,
    summary_cache: ColumnSummaryCache = None,
    literal_cache: LiteralCache = None,
):
    """
    Generate SQL using two-pass schema linking.

    Pass 1: Generate SQL with full schema
    Pass 2: Extract used tables, build filtered schema, refine SQL

    Args:
        schema: Full schema string
        question: User question
        profile_cache: Profile cache for schema linking
        summary_cache: Optional column summaries
        literal_cache: Optional literal cache for value matching

    Returns:
        Refined SQL query
    """
    import logging

    logger = logging.getLogger(__name__)

    llm = build_llm_client()

    logger.info("[Schema Linking] Pass 1: Generating initial SQL")
    prompt = build_sql_generation_prompt(schema, question, literal_cache=literal_cache)
    response = llm.invoke(prompt)
    initial_sql = response.content.strip()

    # Remove markdown code blocks
    if initial_sql.startswith("```"):
        initial_sql = initial_sql.split("```")[1]
        initial_sql = initial_sql.strip()
        if initial_sql.startswith("sql"):
            initial_sql = initial_sql[3:].strip()

    logger.info(f"[Schema Linking] Initial SQL: {initial_sql[:100]}...")

    logger.info("[Schema Linking] Pass 2: Extracting schema and refining")
    filtered_schema, used_tables = link_schema(
        initial_sql, profile_cache, summary_cache
    )

    logger.info(f"[Schema Linking] Used tables: {used_tables}")

    refined_prompt = build_two_pass_prompt(initial_sql, filtered_schema, question)
    response = llm.invoke(refined_prompt)
    refined_sql = response.content.strip()

    # Remove markdown code blocks
    if refined_sql.startswith("```"):
        refined_sql = refined_sql.split("```")[1]
        refined_sql = refined_sql.strip()
        if refined_sql.startswith("sql"):
            refined_sql = refined_sql[3:].strip()

    logger.info(f"[Schema Linking] Refined SQL: {refined_sql[:100]}...")

    # Validate the refined SQL
    validation_result = validate_sql(refined_sql, question)
    if validation_result.fixes_applied:
        print(f"[Validator] Fixes applied: {validation_result.fixes_applied}")
    if validation_result.issues:
        print(f"[Validator] Issues found: {validation_result.issues}")

    return validation_result.sql


def fix_sql_with_error(sql: str, error_msg: str, schema: str) -> str:
    """
    Ask the LLM to fix the SQL query based on the error message.
    """
    llm = build_llm_client()

    prompt = f"""You are a PostgreSQL SQL expert. The following SQL query has an error:

Original SQL:
{sql}

Error Message:
{error_msg}

Current Database Schema:
{schema}

Instructions:
- Fix the SQL query to resolve the error
- Keep the same intent as the original query
- Do not add any SQL clauses (ORDER BY, GROUP BY, HAVING, LIMIT, etc.) unless explicitly in the original query.
- Keep the query minimal - do exactly what was asked, nothing more.
- Output only the corrected SQL query, no explanation
- Do not use markdown code fences

Corrected SQL:"""

    response = llm.invoke(prompt)
    fixed_sql = response.content.strip()

    # Remove markdown if present
    if fixed_sql.startswith("```"):
        fixed_sql = fixed_sql.split("```")[1]
        fixed_sql = fixed_sql.strip()
        if fixed_sql.startswith("sql"):
            fixed_sql = fixed_sql[3:].strip()

    return fixed_sql


def generate_summary(question: str, columns: list, data: list) -> str:
    """Generate a comprehensive natural language summary with aggregated insights."""
    if not data or len(data) == 0:
        return "No results found."

    if len(data) == 1:
        row = data[0]
        parts = [f"{col}: {row.get(col, 'N/A')}" for col in columns]
        return f"Result: {', '.join(parts)}"

    lines = []
    lines.append(f"Total records: {len(data)}")

    label_cols = []
    value_cols = []

    for col in columns:
        col_lower = col.lower()
        is_numeric = True
        sample_vals = []
        for r in data[:5]:
            v = r.get(col)
            if v is not None:
                sample_vals.append(v)

        if sample_vals:
            try:
                numeric_count = 0
                for v in sample_vals:
                    if isinstance(v, (int, float)):
                        numeric_count += 1
                    elif isinstance(v, str):
                        try:
                            float(v)
                            numeric_count += 1
                        except:
                            pass
                is_numeric = numeric_count / len(sample_vals) > 0.5
            except:
                is_numeric = False

        if is_numeric and (
            "count" in col_lower
            or "sum" in col_lower
            or "salary" in col_lower
            or "amount" in col_lower
            or "balance" in col_lower
            or "score" in col_lower
            or "total" in col_lower
            or "avg" in col_lower
            or "average" in col_lower
            or "min" in col_lower
            or "max" in col_lower
            or "percentage" in col_lower
        ):
            value_cols.append(col)
        else:
            label_cols.append(col)

    if not value_cols:
        return f"Found {len(data)} records."

    for col in value_cols:
        values = []
        for r in data:
            v = r.get(col)
            if v is not None and v != "":
                try:
                    values.append(float(v))
                except:
                    pass

        if not values:
            continue

        col_label = col.replace("_", " ").title()
        total = sum(values)
        avg = total / len(values) if values else 0
        min_val = min(values) if values else 0
        max_val = max(values) if values else 0

        if "count" in col.lower():
            lines.append(f"{col_label}: {int(total)} total")
            lines.append(f"  - Average: {avg:.1f} per group")
            lines.append(f"  - Range: {int(min_val)} to {int(max_val)}")

            if len(values) > 1:
                total_all = sum(values)
                top_items = []
                for r in data:
                    v = r.get(col)
                    if v is not None:
                        label = r.get(label_cols[0]) if label_cols else str(r)
                        top_items.append((label, v))
                top_items.sort(key=lambda x: x[1] if x[1] else 0, reverse=True)
                if top_items:
                    lines.append(f"  - Top: {top_items[0][0]} ({int(top_items[0][1])})")

        elif "sum" in col.lower() or "total" in col.lower():
            lines.append(f"{col_label}: {int(total):,}")
            lines.append(f"  - Average: {avg:.1f}")
            lines.append(f"  - Range: {int(min_val):,} to {int(max_val):,}")

        elif "avg" in col.lower() or "average" in col.lower():
            lines.append(f"{col_label}: {avg:.2f}")
            lines.append(f"  - Range: {min_val:.2f} to {max_val:.2f}")

        elif "percentage" in col.lower():
            lines.append(f"{col_label}: {avg:.1f}% average")
            lines.append(f"  - Range: {min_val:.1f}% to {max_val:.1f}%")

        else:
            lines.append(f"{col_label}: Total {int(total):,}")
            lines.append(f"  - Average: {avg:.1f}")
            lines.append(f"  - Range: {min_val:.0f} to {max_val:.0f}")

    if len(lines) == 1:
        return f"Found {len(data)} records."

    return "\n".join(lines)


def generate_sql_with_retry(
    schema: str, question: str, max_iterations: int = 3
) -> dict:
    """
    Generate SQL with retry loop for error handling.

    Args:
        schema: Database schema
        question: User's natural language question
        max_iterations: Maximum retry attempts (default 3)

    Returns:
        dict with sql_query, columns, data, error (if any)
    """
    iteration = 0
    last_error = None
    current_sql = None

    for iteration in range(max_iterations):
        try:
            # Generate SQL (first try) or fix SQL (retries)
            if iteration == 0:
                current_sql = generate_sql(schema, question)
            else:
                # Fix SQL using the error from previous attempt
                current_sql = fix_sql_with_error(current_sql, last_error, schema)

            # Validate it's a SELECT query
            if not current_sql.strip().upper().startswith("SELECT"):
                return {
                    "sql_query": current_sql,
                    "columns": [],
                    "data": [],
                    "summary": "No results found.",
                    "graph_hint": "none",
                }

            # Try to execute the SQL
            conn = get_db_connection()
            cursor = conn.cursor()

            cursor.execute(current_sql)
            rows = cursor.fetchall()

            if not rows:
                return {
                    "sql_query": current_sql,
                    "columns": [],
                    "data": [],
                    "summary": "No results found.",
                    "graph_hint": "none",
                }

            columns = [desc[0] for desc in cursor.description]
            data = [dict(zip(columns, row)) for row in rows]

            cursor.close()
            conn.close()

            cursor.close()
            conn.close()

            summary = generate_summary(question, columns, data)

            return {
                "sql_query": current_sql,
                "columns": columns,
                "data": data,
                "summary": summary,
                "graph_hint": "auto",
            }

        except Exception as e:
            error_msg = str(e)
            last_error = error_msg

            # Check if error is retryable
            if not is_retryable_error(error_msg) or iteration == max_iterations - 1:
                # Return error if not retryable or max iterations reached
                return {
                    "sql_query": current_sql if current_sql else "",
                    "error": f"SQL Error (attempt {iteration + 1}/{max_iterations}): {error_msg}",
                }

            # Continue to next iteration
            continue

    # Should not reach here, but just in case
    return {
        "sql_query": current_sql if current_sql else "",
        "error": "Max iterations exceeded",
    }


def execute_sql_direct(sql: str) -> dict:
    """
    Execute SQL directly without retry (for backward compatibility).
    """
    if not sql.strip().upper().startswith("SELECT"):
        return {"error": "Only SELECT queries are allowed"}

    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute(sql)
        rows = cursor.fetchall()

        if not rows:
            return {"columns": [], "data": [], "graph_hint": "none"}

        columns = [desc[0] for desc in cursor.description]
        data = [dict(zip(columns, row)) for row in rows]

        cursor.close()
        conn.close()

        summary = generate_summary("", columns, data)

        return {
            "columns": columns,
            "data": data,
            "summary": summary,
            "graph_hint": "auto",
        }

    except Exception as e:
        return {"error": str(e)}


@app.get("/api/profile")
def get_profile():
    """Return current profile metadata."""
    global _profile_cache
    if _profile_cache is None:
        return {"error": "Profile not loaded"}
    return {
        "generated_at": _profile_cache.generated_at,
        "expires_in_seconds": _profile_cache.expires_in_seconds,
        "table_count": len(_profile_cache.tables),
        "tables": list(_profile_cache.tables.keys()),
        "row_counts": {
            name: table.row_count for name, table in _profile_cache.tables.items()
        },
    }


@app.post("/api/refresh-profile")
def refresh_profile():
    """Force refresh the profile cache."""
    global _profile_cache
    try:
        conn = get_db_connection()
        _profile_cache = profile_database(conn, force_refresh=True)
        conn.close()
        return {
            "status": "refreshed",
            "table_count": len(_profile_cache.tables),
            "generated_at": _profile_cache.generated_at,
        }
    except Exception as e:
        return {"error": str(e)}


@app.get("/api/column-summaries")
def get_column_summaries():
    """Return current column summaries."""
    global _summary_cache
    if _summary_cache is None:
        return {"error": "Column summaries not loaded"}

    return {
        "generated_at": _summary_cache.generated_at,
        "expires_in_seconds": _summary_cache.expires_in_seconds,
        "tables": {
            table: {
                column: {
                    "short_label": summary.short_label,
                    "description": summary.description,
                    "inferred_type": summary.inferred_type,
                    "confidence": summary.confidence,
                }
                for column, summary in columns.items()
            }
            for table, columns in _summary_cache.summaries.items()
        },
    }


@app.post("/api/refresh-summaries")
def refresh_summaries():
    """Force refresh the column summaries cache."""
    global _summary_cache, _profile_cache
    try:
        if _profile_cache is None:
            conn = get_db_connection()
            _profile_cache = profile_database(conn)
            conn.close()

        _summary_cache = summarize_database_columns(
            {name: table.to_dict() for name, table in _profile_cache.tables.items()},
            _profile_cache.database_hash,
            force_refresh=True,
        )
        return {
            "status": "refreshed",
            "table_count": len(_summary_cache.summaries),
            "generated_at": _summary_cache.generated_at,
        }
    except Exception as e:
        return {"error": str(e)}


@app.get("/api/literals")
def get_literals():
    """Return current literal index metadata."""
    global _literal_cache
    if _literal_cache is None:
        return {"error": "Literal cache not loaded"}

    total_values = sum(
        len(col.values)
        for table_cols in _literal_cache.literals.values()
        for col in table_cols.values()
    )

    return {
        "generated_at": _literal_cache.generated_at,
        "expires_in_seconds": _literal_cache.expires_in_seconds,
        "table_count": len(_literal_cache.literals),
        "total_values": total_values,
        "tables": {
            table: list(columns.keys())
            for table, columns in _literal_cache.literals.items()
        },
    }


@app.post("/api/refresh-literals")
def refresh_literals():
    """Force refresh the literal cache."""
    global _literal_cache
    try:
        conn = get_db_connection()
        _literal_cache = index_database(conn, force_refresh=True)
        conn.close()

        total_values = sum(
            len(col.values)
            for table_cols in _literal_cache.literals.values()
            for col in table_cols.values()
        )

        return {
            "status": "refreshed",
            "table_count": len(_literal_cache.literals),
            "total_values": total_values,
            "generated_at": _literal_cache.generated_at,
        }
    except Exception as e:
        return {"error": str(e)}


@app.post("/api/match-literals")
def match_literals(request: dict):
    """Match terms in a question against indexed literals."""
    global _literal_cache

    if _literal_cache is None:
        return {"error": "Literal cache not loaded"}

    question = request.get("question", "")
    if not question:
        return {"error": "No question provided"}

    try:
        from literal_matcher import match_terms_in_question

        matches = match_terms_in_question(question, _literal_cache)
        return {
            "question": question,
            "matches": [
                {
                    "table": m.table,
                    "column": m.column,
                    "matched_value": m.matched_value,
                    "match_type": m.match_type,
                    "confidence": m.confidence,
                }
                for m in matches
            ],
        }
    except Exception as e:
        return {"error": str(e)}


@app.get("/api/databases")
def get_databases():
    """Return available databases/table groups."""
    return {"databases": get_available_databases()}


@app.get("/api/logs")
def get_query_logs(
    limit: int = 50,
    offset: int = 0,
    db_type: str = None,
    success: bool = None,
    session_id: str = None,
):
    """Return recent query logs with optional filtering."""
    global _query_logger

    if _query_logger is None:
        return {"error": "Query logger not initialized"}

    try:
        success_filter = None
        if success is not None:
            success_filter = success.lower() in ("true", "1", "yes")

        logs = _query_logger.get_recent_logs(
            limit=min(limit, 100),
            offset=offset,
            db_type=db_type,
            success=success_filter,
            session_id=session_id,
        )

        return {
            "logs": [
                {
                    "id": log.id,
                    "question": log.question,
                    "sql_query": log.sql_query,
                    "db_type": log.db_type,
                    "success": log.success,
                    "error_message": log.error_message,
                    "row_count": log.row_count,
                    "execution_time_ms": log.execution_time_ms,
                    "created_at": log.created_at.isoformat()
                    if log.created_at
                    else None,
                    "retry_count": log.retry_count,
                }
                for log in logs
            ],
            "limit": limit,
            "offset": offset,
            "count": len(logs),
        }
    except Exception as e:
        return {"error": str(e)}


@app.get("/api/logs/{log_id}")
def get_query_log(log_id: int):
    """Get a specific query log by ID."""
    global _query_logger

    if _query_logger is None:
        return {"error": "Query logger not initialized"}

    log = _query_logger.get_log_by_id(log_id)
    if log is None:
        return {"error": "Log not found"}

    return {
        "id": log.id,
        "question": log.question,
        "sql_query": log.sql_query,
        "db_type": log.db_type,
        "success": log.success,
        "error_message": log.error_message,
        "columns": log.columns,
        "row_count": log.row_count,
        "execution_time_ms": log.execution_time_ms,
        "use_schema_linking": log.use_schema_linking,
        "use_retry": log.use_retry,
        "retry_count": log.retry_count,
        "created_at": log.created_at.isoformat() if log.created_at else None,
        "session_id": log.session_id,
        "user_id": log.user_id,
    }


@app.get("/api/logs/stats")
def get_query_stats(db_type: str = None, days: int = 7):
    """Get query statistics for a time period."""
    global _query_logger

    if _query_logger is None:
        return {"error": "Query logger not initialized"}

    try:
        stats = _query_logger.get_stats(db_type=db_type, days=days)
        return stats
    except Exception as e:
        return {"error": str(e)}


@app.delete("/api/logs/clear")
def clear_old_logs(days: int = 30):
    """Clear query logs older than specified days."""
    global _query_logger

    if _query_logger is None:
        return {"error": "Query logger not initialized"}

    try:
        deleted = _query_logger.clear_old_logs(days=days)
        return {"status": "cleared", "deleted_count": deleted, "older_than_days": days}
    except Exception as e:
        return {"error": str(e)}


@app.post("/api/query")
def process_query(request: dict):
    global _profile_cache, _summary_cache, _literal_cache, _query_logger

    question = request.get("question", "")
    db_type = request.get("db_type", "hr")
    use_retry = request.get("use_retry", True)
    use_schema_linking = request.get("use_schema_linking", False)
    session_id = request.get("session_id")

    import time

    start_time = time.time()
    retry_count = 0
    log_id = None

    if _query_logger:
        log_id = _query_logger.log_query(
            question=question,
            db_type=db_type,
            use_schema_linking=use_schema_linking,
            use_retry=use_retry,
            session_id=session_id,
        )

    if _profile_cache is None:
        try:
            conn = get_db_connection()
            _profile_cache = profile_database(conn)
            conn.close()
        except Exception as e:
            return {"error": f"Failed to load profile cache: {e}"}

    if _summary_cache is None:
        try:
            _summary_cache = summarize_database_columns(
                {
                    name: table.to_dict()
                    for name, table in _profile_cache.tables.items()
                },
                _profile_cache.database_hash,
            )
        except Exception as e:
            print(f"Warning: Could not load column summaries: {e}")

    if _literal_cache is None:
        try:
            conn = get_db_connection()
            _literal_cache = index_database(conn)
            conn.close()
        except Exception as e:
            print(f"Warning: Could not load literal cache: {e}")

    filtered_tables = None
    if db_type and db_type in AVAILABLE_DATABASES:
        filtered_tables = AVAILABLE_DATABASES[db_type]["tables"]

    from sql_prompt import format_enhanced_schema

    schema = format_enhanced_schema(
        _profile_cache, _summary_cache, table_names=filtered_tables
    )

    if use_schema_linking:
        sql = generate_sql_two_pass(
            schema, question, _profile_cache, _summary_cache, _literal_cache
        )
    else:
        sql = generate_sql(schema, question)

    retry_count = 0
    current_sql = sql
    last_error = None

    if use_retry:
        for iteration in range(3):
            try:
                conn = get_db_connection()
                cursor = conn.cursor()
                cursor.execute(current_sql)
                rows = cursor.fetchall()
                cursor.close()
                conn.close()

                if not rows:
                    execution_time = int((time.time() - start_time) * 1000)
                    if _query_logger and log_id:
                        _query_logger.update_log(
                            log_id,
                            sql_query=current_sql,
                            success=True,
                            execution_time_ms=execution_time,
                            retry_count=retry_count,
                        )
                    return {
                        "sql_query": current_sql,
                        "columns": [],
                        "data": [],
                        "summary": "No results found.",
                        "graph_hint": "none",
                    }

                columns = (
                    [desc[0] for desc in cursor.description]
                    if iteration == 0
                    else columns
                )
                data = [dict(zip(columns, row)) for row in rows]

                execution_time = int((time.time() - start_time) * 1000)
                summary = generate_summary(question, columns, data)

                if _query_logger and log_id:
                    _query_logger.update_log(
                        log_id,
                        sql_query=current_sql,
                        success=True,
                        columns=columns,
                        row_count=len(data),
                        execution_time_ms=execution_time,
                        retry_count=retry_count,
                    )

                return {
                    "sql_query": current_sql,
                    "columns": columns,
                    "data": data,
                    "summary": summary,
                    "graph_hint": "auto",
                }

            except Exception as e:
                last_error = str(e)
                retry_count = iteration + 1

                non_retryable = [
                    "permission denied",
                    "must be superuser",
                    "connection refused",
                ]
                if (
                    any(p in last_error.lower() for p in non_retryable)
                    or iteration == 2
                ):
                    execution_time = int((time.time() - start_time) * 1000)
                    if _query_logger and log_id:
                        _query_logger.update_log(
                            log_id,
                            sql_query=current_sql,
                            success=False,
                            error_message=last_error,
                            execution_time_ms=execution_time,
                            retry_count=retry_count,
                        )
                    return {
                        "sql_query": current_sql,
                        "error": f"SQL Error: {last_error}",
                    }

                current_sql = fix_sql_with_error(current_sql, last_error, schema)

    else:
        result = execute_sql_direct(sql)

        if "error" in result:
            execution_time = int((time.time() - start_time) * 1000)
            if _query_logger and log_id:
                _query_logger.update_log(
                    log_id,
                    sql_query=sql,
                    success=False,
                    error_message=result["error"],
                    execution_time_ms=execution_time,
                )
            return {"sql_query": sql, "error": result["error"]}

        execution_time = int((time.time() - start_time) * 1000)
        if _query_logger and log_id:
            _query_logger.update_log(
                log_id,
                sql_query=sql,
                success=True,
                columns=result["columns"],
                row_count=len(result["data"]),
                execution_time_ms=execution_time,
            )

        return {
            "sql_query": sql,
            "columns": result["columns"],
            "data": result["data"],
            "summary": result.get("summary", ""),
            "graph_hint": result["graph_hint"],
        }


@app.get("/")
def root():
    return {
        "message": "NL2SQL API with Retry Support",
        "version": "1.0.0",
        "endpoints": {
            "query": "/api/query (POST)",
        },
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
