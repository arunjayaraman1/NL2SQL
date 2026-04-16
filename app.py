"""
NL2SQL - Natural Language to SQL Converter using LangGraph

This module provides a pipeline that converts natural language questions
into SQL queries and executes them against a PostgreSQL database.

Flow: Question → Fetch Schema → Generate SQL → Execute Query → Results
With Retry Loop: If SQL execution fails, retry up to 3 times with error feedback.
"""

import os
import sys
import argparse
from typing import TypedDict, Optional

import psycopg2
from dotenv import load_dotenv
from langchain_nvidia_ai_endpoints import ChatNVIDIA

from langgraph.graph import END, StateGraph

from sql_prompt import build_sql_generation_prompt, build_profiled_schema_prompt
from profiler import profile_database, ProfileCache

# Load environment variables from .env file
load_dotenv()

NVIDIA_MODEL = os.getenv("NVIDIA_MODEL", "google/gemma-2-2b-it")
NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY")
NVIDIA_TEMPERATURE = float(os.getenv("NVIDIA_TEMPERATURE", "0.2"))
NVIDIA_TOP_P = float(os.getenv("NVIDIA_TOP_P", "0.7"))
NVIDIA_MAX_TOKENS = int(os.getenv("NVIDIA_MAX_TOKENS", "1024"))


def build_llm_client() -> ChatNVIDIA:
    return ChatNVIDIA(
        model=NVIDIA_MODEL,
        api_key=NVIDIA_API_KEY,
        temperature=NVIDIA_TEMPERATURE,
        top_p=NVIDIA_TOP_P,
        max_tokens=NVIDIA_MAX_TOKENS,
    )


# =============================================================================
# STATE DEFINITION
# =============================================================================


class GraphState(TypedDict):
    """
    Defines the shape of data that flows through the LangGraph workflow.

    LangGraph uses this TypedDict to:
    - Enforce type safety across all nodes
    - Track the state as it passes from one node to the next
    - Enable automatic state updates after each node completes

    Each field is populated by a specific node in the workflow:
    """

    question: str  # Input: User's natural language question
    schema: str  # Output of fetch_schema: Database table/column info
    sql_query: str  # Output of generate_sql: LLM-generated SQL
    result: str  # Output of execute_sql: Query results or error
    iteration: int  # Track retry attempts
    profile_cache: Optional[ProfileCache]  # Profiling metadata cache


# =============================================================================
# DATABASE CONNECTION
# =============================================================================


def get_db_connection():
    """
    Creates and returns a new PostgreSQL connection using .env credentials.
    """
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
    )


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================


def is_retryable_error(error_msg: str) -> bool:
    """
    Check if the SQL error is retryable (can be fixed by rewriting SQL).

    Retryable errors include:
    - Column/table doesn't exist
    - Syntax errors
    - Invalid operators
    - Type mismatches

    Non-retryable errors include:
    - Permission denied
    - Connection failures
    - Authentication errors
    """
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
        "relation",
    ]

    for pattern in retryable:
        if pattern in error_lower:
            return True

    return False


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


# =============================================================================
# NODE 1: FETCH DATABASE SCHEMA
# =============================================================================


def fetch_schema(state: GraphState) -> GraphState:
    """
    NODE 1: Fetches the database schema from PostgreSQL with profiling metadata.

    Uses the profiler module to extract statistical metadata including:
    - Null counts and percentages
    - Distinct value counts
    - Sample values
    - Min/Max for numeric and date columns
    - Primary key and foreign key relationships
    """
    conn = get_db_connection()

    try:
        profile_cache = profile_database(
            conn, force_refresh=state.get("force_refresh", False)
        )
        state["profile_cache"] = profile_cache

        from profiler import format_profiled_schema

        state["schema"] = format_profiled_schema(profile_cache)

    finally:
        conn.close()

    return state


# =============================================================================
# NODE 2: GENERATE SQL QUERY
# =============================================================================


def generate_sql(state: GraphState) -> GraphState:
    """
    NODE 2: Generates SQL query from natural language using LLM.
    Uses profiled schema for enhanced accuracy.
    """
    llm = build_llm_client()

    if state.get("profile_cache"):
        prompt = build_profiled_schema_prompt(state["profile_cache"], state["question"])
    else:
        prompt = build_sql_generation_prompt(state["schema"], state["question"])

    response = llm.invoke(prompt)
    state["sql_query"] = response.content.strip()

    return state


# =============================================================================
# NODE 3: EXECUTE SQL QUERY (with Retry Loop)
# =============================================================================


def execute_sql(state: GraphState) -> GraphState:
    """
    NODE 3: Executes the SQL query with retry loop.

    If SQL execution fails:
    1. Check if error is retryable
    2. If yes, ask LLM to fix the SQL using error feedback
    3. Retry up to max_iterations times
    4. Return result or final error
    """
    max_iterations = 3
    current_iteration = 0

    # Initialize iteration counter in state
    if "iteration" not in state:
        state["iteration"] = 0

    while current_iteration < max_iterations:
        sql = state["sql_query"].strip()

        # Remove markdown code blocks
        if sql.startswith("```"):
            sql = sql.split("```")[1]
            sql = sql.strip()
            if sql.startswith("sql"):
                sql = sql[3:].strip()

        # Security check - only allow SELECT queries
        if not sql.upper().startswith("SELECT"):
            state["result"] = "Error: Only SELECT queries are allowed"
            return state

        try:
            # Execute SQL
            conn = get_db_connection()
            cursor = conn.cursor()

            cursor.execute(sql)
            rows = cursor.fetchall()

            if not rows:
                state["result"] = "No results found"
            else:
                columns = [desc[0] for desc in cursor.description]
                result_lines = [", ".join(columns)]
                for row in rows:
                    result_lines.append(", ".join(str(v) for v in row))
                state["result"] = "\n".join(result_lines)

            cursor.close()
            conn.close()

            # Success - exit retry loop
            return state

        except Exception as e:
            error_msg = str(e)
            current_iteration += 1
            state["iteration"] = current_iteration

            # Check if error is retryable
            if not is_retryable_error(error_msg) or current_iteration >= max_iterations:
                # Non-retryable error or max iterations reached
                state["result"] = (
                    f"Error executing SQL (attempt {current_iteration}/{max_iterations}): {error_msg}"
                )
                return state

            # Try to fix the SQL
            print(f"\n[Retry {current_iteration}] SQL Error: {error_msg}")
            print(f"[Retry {current_iteration}] Attempting to fix...")

            fixed_sql = fix_sql_with_error(sql, error_msg, state["schema"])
            state["sql_query"] = fixed_sql

    # Should not reach here, but just in case
    state["result"] = f"Error: Max iterations ({max_iterations}) exceeded"
    return state


# =============================================================================
# LANGGRAPH WORKFLOW DEFINITION
# =============================================================================


def run_pipeline(question: str, initial_state: GraphState = None) -> dict:
    """
    Builds and executes the complete LangGraph workflow with retry support.
    """
    # Create workflow
    workflow = StateGraph(GraphState)

    # Add nodes
    workflow.add_node("fetch_schema", fetch_schema)
    workflow.add_node("generate_sql", generate_sql)
    workflow.add_node("execute_sql", execute_sql)

    # Define flow
    workflow.set_entry_point("fetch_schema")
    workflow.add_edge("fetch_schema", "generate_sql")
    workflow.add_edge("generate_sql", "execute_sql")
    workflow.add_edge("execute_sql", END)

    # Compile
    compiled = workflow.compile()

    if initial_state is None:
        initial_state = GraphState(
            question=question,
            schema="",
            sql_query="",
            result="",
            iteration=0,
            profile_cache=None,
        )

    if "profile_cache" not in initial_state:
        initial_state["profile_cache"] = None

    # Execute
    final_state = compiled.invoke(initial_state)

    return final_state


# =============================================================================
# MAIN ENTRY POINT
# =============================================================================


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="NL2SQL - Natural Language to SQL Converter"
    )
    parser.add_argument(
        "--refresh-profile",
        action="store_true",
        help="Force refresh the database profile cache before querying",
    )
    parser.add_argument(
        "--profile-only",
        action="store_true",
        help="Only refresh the profile cache, then exit",
    )
    parser.add_argument("question", nargs="?", help="Your natural language question")

    args = parser.parse_args()

    if args.refresh_profile or args.profile_only:
        print("=" * 60)
        print("NL2SQL - Database Profiling")
        print("=" * 60)
        print("\nRefreshing profile cache...")

        conn = get_db_connection()
        try:
            profile_cache = profile_database(conn, force_refresh=True)
            from profiler import format_profiled_schema

            print(f"\nSuccessfully profiled {len(profile_cache.tables)} tables:")
            for table_name, table in profile_cache.tables.items():
                print(
                    f"  - {table_name}: {table.row_count} rows, {table.column_count} columns"
                )

            print("\nFormatted schema preview:")
            print(format_profiled_schema(profile_cache)[:500] + "...")

            print(
                f"\nProfile cache saved. Expires in {profile_cache.expires_in_seconds} seconds."
            )
        finally:
            conn.close()

        if args.profile_only:
            sys.exit(0)

        if not args.question:
            print("\nProfile refreshed. Run again with a question.")
            sys.exit(0)

    print("=" * 60)
    print("NL2SQL - Natural Language to SQL Converter")
    print("With Retry Support (max 3 iterations per query)")
    print("=" * 60)

    question = args.question if args.question else input("\nEnter your question: ")

    print("\nProcessing...")

    initial_state = GraphState(
        question=question,
        schema="",
        sql_query="",
        result="",
        iteration=0,
        profile_cache=None,
        force_refresh=args.refresh_profile,
    )

    result = run_pipeline(question, initial_state)

    print("\n--- Generated SQL ---")
    print(result["sql_query"])

    print("\n--- Results ---")
    print(result["result"])

    if result.get("iteration", 0) > 0:
        print(f"\n(Completed in {result['iteration']} attempt(s))")
