"""
NL2SQL - Natural Language to SQL Converter using LangGraph

This module provides a pipeline that converts natural language questions
into SQL queries and executes them against a PostgreSQL database.

Flow: Question → Fetch Schema → Generate SQL → Execute Query → Results
With Retry Loop: If SQL execution fails, retry up to 3 times with error feedback.
"""

import os
from typing import TypedDict

import psycopg2
from dotenv import load_dotenv
from langchain_groq import ChatGroq
from langgraph.graph import END, StateGraph

from sql_prompt import build_sql_generation_prompt

# Load environment variables from .env file
load_dotenv()

GROQ_MODEL = os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")


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


# =============================================================================
# NODE 1: FETCH DATABASE SCHEMA
# =============================================================================


def fetch_schema(state: GraphState) -> GraphState:
    """
    NODE 1: Fetches the database schema from PostgreSQL.

    Queries information_schema to get all tables and columns
    from the public schema.
    """
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
    for table, column, dtype in columns:
        if table != current_table:
            schema_lines.append(f"\nTable: {table}")
            current_table = table
        schema_lines.append(f"  - {column} ({dtype})")

    state["schema"] = "\n".join(schema_lines)

    cursor.close()
    conn.close()

    return state


# =============================================================================
# NODE 2: GENERATE SQL QUERY
# =============================================================================


def generate_sql(state: GraphState) -> GraphState:
    """
    NODE 2: Generates SQL query from natural language using LLM.
    """
    llm = ChatGroq(model=GROQ_MODEL, temperature=0, api_key=os.getenv("GROQ_API_KEY"))

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


def run_pipeline(question: str) -> dict:
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

    # Initial state
    initial_state = GraphState(
        question=question,
        schema="",
        sql_query="",
        result="",
        iteration=0,
    )

    # Execute
    final_state = compiled.invoke(initial_state)

    return final_state


# =============================================================================
# MAIN ENTRY POINT
# =============================================================================


if __name__ == "__main__":
    print("=" * 60)
    print("NL2SQL - Natural Language to SQL Converter")
    print("With Retry Support (max 3 iterations per query)")
    print("=" * 60)

    # Get question from user
    question = input("\nEnter your question: ")

    print("\nProcessing...")

    # Run the pipeline
    result = run_pipeline(question)

    # Display results
    print("\n--- Generated SQL ---")
    print(result["sql_query"])

    print("\n--- Results ---")
    print(result["result"])

    # Show iteration count if retries were used
    if result.get("iteration", 0) > 0:
        print(f"\n(Completed in {result['iteration']} attempt(s))")
