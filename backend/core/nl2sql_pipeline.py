"""
Shared NL2SQL pipeline used by both FastAPI and CLI.

Flow:
  fetch_schema -> generate_sql -> execute_sql

The pipeline is DB-aware (db_id) and uses db_registry.get_connection so it
works with multi-database configuration.
"""

from __future__ import annotations

from typing import Any, Callable, Optional, TypedDict

from langgraph.graph import END, StateGraph

from .db_registry import get_connection
from .profiler import ProfileCache, format_profiled_schema, profile_database
from .schema_linker import link_schema
from .sql_prompt import (
    build_profiled_schema_prompt,
    build_sql_generation_prompt,
    build_two_pass_prompt,
)
from .validator import validate_sql


class GraphState(TypedDict, total=False):
    question: str
    db_id: str
    llm_builder: Callable[[], Any]

    schema: str
    sql_query: str
    result: str
    iteration: int
    error: str

    columns: list[str]
    data: list[dict]
    summary: str
    graph_hint: str

    profile_cache: Optional[ProfileCache]
    summary_cache: Optional[Any]
    force_refresh: bool
    cache_path: Optional[str]


def _strip_sql_fences(sql: str) -> str:
    sql = (sql or "").strip()
    if sql.startswith("```"):
        sql = sql.split("```")[1].strip()
        if sql.lower().startswith("sql"):
            sql = sql[3:].strip()
    return sql


def is_retryable_error(error_msg: str) -> bool:
    error_lower = error_msg.lower()

    non_retryable = [
        "permission denied",
        "must be superuser",
        "must be owner",
        "connection refused",
        "could not connect",
        "password authentication failed",
    ]
    if any(p in error_lower for p in non_retryable):
        return False

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
        "aggregate",
        "group by",
    ]
    return any(p in error_lower for p in retryable)


def _llm_invoke(state: GraphState, prompt: str) -> str:
    llm_builder = state.get("llm_builder")
    if not callable(llm_builder):
        raise RuntimeError("Pipeline state must include a callable llm_builder")
    llm = llm_builder()
    response = llm.invoke(prompt)
    return _strip_sql_fences(response.content)


def fix_sql_with_error(state: GraphState, sql: str, error_msg: str, schema: str) -> str:
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
    return _llm_invoke(state, prompt)


def generate_summary(question: str, columns: list[str], data: list[dict]) -> str:
    if not data:
        return "No results found."

    if len(data) == 1:
        row = data[0]
        parts = [f"{col}: {row.get(col, 'N/A')}" for col in columns]
        return f"Result: {', '.join(parts)}"

    return f"Found {len(data)} records."


def fetch_schema(state: GraphState) -> GraphState:
    """Node 1: fetch or build profiled schema text."""
    if state.get("profile_cache") is not None and state.get("schema"):
        return state

    db_id = state.get("db_id")
    if not db_id:
        state["error"] = "db_id is required in pipeline state"
        return state

    conn = get_connection(db_id)
    try:
        profile_cache = profile_database(
            conn,
            force_refresh=state.get("force_refresh", False),
            cache_path=state.get("cache_path"),
        )
    finally:
        conn.close()

    state["profile_cache"] = profile_cache
    state["schema"] = format_profiled_schema(profile_cache)
    return state


def generate_sql(state: GraphState) -> GraphState:
    """Node 2: generate SQL, then refine with schema linking + validator."""
    question = state.get("question", "")

    if state.get("profile_cache"):
        prompt = build_profiled_schema_prompt(
            state["profile_cache"],
            question,
            summary_cache=state.get("summary_cache"),
        )
    else:
        prompt = build_sql_generation_prompt(state.get("schema", ""), question)

    initial_sql = _llm_invoke(state, prompt)

    if state.get("profile_cache"):
        filtered_schema, _ = link_schema(
            initial_sql, state["profile_cache"], state.get("summary_cache")
        )
        refined_prompt = build_two_pass_prompt(initial_sql, filtered_schema, question)
        sql = _llm_invoke(state, refined_prompt)
    else:
        sql = initial_sql

    validation_result = validate_sql(sql, question)
    state["sql_query"] = validation_result.sql
    return state


def execute_sql(state: GraphState) -> GraphState:
    """Node 3: execute SQL with retry loop."""
    db_id = state.get("db_id")
    if not db_id:
        state["error"] = "db_id is required in pipeline state"
        state["result"] = state["error"]
        return state

    max_iterations = 3
    current_iteration = 0
    state.setdefault("iteration", 0)

    while current_iteration < max_iterations:
        sql = _strip_sql_fences(state.get("sql_query", ""))

        if not sql.upper().startswith("SELECT"):
            state["error"] = "Only SELECT queries are allowed"
            state["result"] = f"Error: {state['error']}"
            state["columns"] = []
            state["data"] = []
            state["summary"] = "No results found."
            state["graph_hint"] = "none"
            return state

        try:
            conn = get_connection(db_id)
            try:
                cursor = conn.cursor()
                try:
                    cursor.execute(sql)
                    rows = cursor.fetchall()
                    columns = [desc[0] for desc in cursor.description] if rows else []
                finally:
                    cursor.close()
            finally:
                conn.close()

            if not rows:
                state["columns"] = []
                state["data"] = []
                state["summary"] = "No results found."
                state["graph_hint"] = "none"
                state["result"] = "No results found"
                return state

            data = [dict(zip(columns, row)) for row in rows]
            state["columns"] = columns
            state["data"] = data
            state["summary"] = generate_summary(state.get("question", ""), columns, data)
            state["graph_hint"] = "auto"
            state["result"] = state["summary"]
            return state

        except Exception as e:
            error_msg = str(e)
            current_iteration += 1
            state["iteration"] = current_iteration

            if not is_retryable_error(error_msg) or current_iteration >= max_iterations:
                state["error"] = (
                    f"SQL Error (attempt {current_iteration}/{max_iterations}): {error_msg}"
                )
                state["result"] = state["error"]
                state.setdefault("columns", [])
                state.setdefault("data", [])
                state.setdefault("summary", "No results found.")
                state.setdefault("graph_hint", "none")
                return state

            state["sql_query"] = fix_sql_with_error(
                state, sql, error_msg, state.get("schema", "")
            )

    state["error"] = f"Error: Max iterations ({max_iterations}) exceeded"
    state["result"] = state["error"]
    state.setdefault("columns", [])
    state.setdefault("data", [])
    state.setdefault("summary", "No results found.")
    state.setdefault("graph_hint", "none")
    return state


def run_pipeline(question: str, initial_state: Optional[GraphState] = None) -> GraphState:
    """Build and execute the LangGraph workflow."""
    workflow = StateGraph(GraphState)
    workflow.add_node("fetch_schema", fetch_schema)
    workflow.add_node("generate_sql", generate_sql)
    workflow.add_node("execute_sql", execute_sql)

    workflow.set_entry_point("fetch_schema")
    workflow.add_edge("fetch_schema", "generate_sql")
    workflow.add_edge("generate_sql", "execute_sql")
    workflow.add_edge("execute_sql", END)

    compiled = workflow.compile()

    if initial_state is None:
        initial_state = GraphState(
            question=question,
            schema="",
            sql_query="",
            result="",
            iteration=0,
            columns=[],
            data=[],
            summary="",
            graph_hint="none",
            profile_cache=None,
        )

    initial_state["question"] = question
    return compiled.invoke(initial_state)
