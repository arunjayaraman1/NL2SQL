import os
import sys
import json
import subprocess
from pathlib import Path
from typing import TypedDict

_ROOT = Path(__file__).resolve().parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

import psycopg2
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from sql_prompt import build_sql_generation_prompt

load_dotenv()

GROQ_MODEL = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")
DEFAULT_CORS_ORIGINS = ["http://localhost:3000", "http://localhost:5173"]


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
    from langchain_groq import ChatGroq

    llm = ChatGroq(model=GROQ_MODEL, temperature=0, api_key=os.getenv("GROQ_API_KEY"))

    prompt = build_sql_generation_prompt(schema, question)

    response = llm.invoke(prompt)
    sql = response.content.strip()

    # Remove markdown code blocks
    if sql.startswith("```"):
        sql = sql.split("```")[1]
        sql = sql.strip()
        if sql.startswith("sql"):
            sql = sql[3:].strip()

    return sql


def fix_sql_with_error(sql: str, error_msg: str, schema: str) -> str:
    """
    Ask the LLM to fix the SQL query based on the error message.
    """
    from langchain_groq import ChatGroq

    llm = ChatGroq(model=GROQ_MODEL, temperature=0, api_key=os.getenv("GROQ_API_KEY"))

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


@app.get("/api/databases")
def get_databases():
    """Return available databases/table groups."""
    return {"databases": get_available_databases()}


@app.post("/api/query")
def process_query(request: dict):
    question = request.get("question", "")
    db_type = request.get("db_type", "hr")  # Default to HR database
    use_retry = request.get("use_retry", True)

    schema = fetch_schema(db_type)

    if use_retry:
        # Use retry loop (new behavior)
        result = generate_sql_with_retry(schema, question, max_iterations=3)

        if "error" in result:
            return {"sql_query": result["sql_query"], "error": result["error"]}

        return {
            "sql_query": result["sql_query"],
            "columns": result["columns"],
            "data": result["data"],
            "summary": result.get("summary", ""),
            "graph_hint": result["graph_hint"],
        }
    else:
        # No retry (old behavior for backward compatibility)
        sql = generate_sql(schema, question)
        result = execute_sql_direct(sql)

        if "error" in result:
            return {"sql_query": sql, "error": result["error"]}

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
