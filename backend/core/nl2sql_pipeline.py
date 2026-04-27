"""
Shared NL2SQL pipeline used by both FastAPI and CLI.

Flow:
  fetch_schema -> generate_sql -> execute_sql

The pipeline is DB-aware (db_id) and uses db_registry.get_connection so it
works with multi-database configuration.
"""

from __future__ import annotations

import json
import re
from typing import Any, Callable, Optional, TypedDict

from langgraph.graph import END, StateGraph

from .db_registry import get_connection
from .graph_spec import build_fallback_graph_spec, validate_graph_spec
from .jsonb_formatter import format_results as format_jsonb_results
from .profiler import ProfileCache, format_profiled_schema, profile_database
from .schema_linker import link_schema
from .sql_prompt import (
    build_classification_prompt,
    build_profiled_schema_prompt,
    build_sql_generation_prompt,
    build_two_pass_prompt,
)
from .validator import validate_sql, validate_sql_with_execution


ProgressCallback = Callable[[str, str, str, dict[str, Any]], None]


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
    graph_spec: dict[str, Any]

    is_query: bool
    conversation_response: str

    conversation_history: Optional[list[dict]]  # [{question, sql, summary}]
    profile_cache: Optional[ProfileCache]
    summary_cache: Optional[Any]
    force_refresh: bool
    cache_path: Optional[str]
    progress_callback: Optional[ProgressCallback]


def _emit_progress(
    state: GraphState,
    step_id: str,
    label: str,
    status: str = "completed",
    meta: Optional[dict[str, Any]] = None,
) -> None:
    callback = state.get("progress_callback")
    if not callable(callback):
        return
    try:
        callback(step_id, label, status, meta or {})
    except Exception:
        # Progress updates should never break pipeline execution.
        pass


def _strip_sql_fences(sql: str) -> str:
    sql = (sql or "").strip()
    if sql.startswith("```"):
        sql = sql.split("```")[1].strip()
        if sql.lower().startswith("sql"):
            sql = sql[3:].strip()
    return sql


def _strip_markdown_fences(text: str) -> str:
    text = (text or "").strip()
    if text.startswith("```") and text.endswith("```"):
        lines = text.splitlines()
        if len(lines) >= 3:
            core = "\n".join(lines[1:-1]).strip()
            if core.lower().startswith(("text\n", "markdown\n")):
                core = core.split("\n", 1)[1].strip()
            return core
    return text


def classify_input(state: GraphState) -> GraphState:
    """Node 0: classify input as query or conversation using LLM."""
    llm_builder = state.get("llm_builder")
    if not callable(llm_builder):
        state["is_query"] = True
        state["conversation_response"] = ""
        return state

    question = state.get("question", "")
    prompt = build_classification_prompt(question)

    try:
        llm = llm_builder()
        response = llm.invoke(prompt)
        intent = response.content.strip().lower()

        if "query" in intent:
            state["is_query"] = True
            state["conversation_response"] = ""
        else:
            state["is_query"] = False
            state["conversation_response"] = _build_conversation_response(question)
    except Exception:
        state["is_query"] = True
        state["conversation_response"] = ""

    return state


def _build_conversation_response(question: str) -> str:
    q_lower = question.lower().strip()

    greetings = ["hi", "hello", "hey", "greetings", "hi there", "hello!"]
    if q_lower in greetings or any(g in q_lower for g in greetings):
        return "Hello! I'm here to help you query your database. Ask me anything like 'show me all customers' or 'count employees by department'."

    help_keywords = ["help", "what can you do", "how does this work", "commands"]
    if any(k in q_lower for k in help_keywords):
        return "I can help you query your database using natural language. Try questions like 'show all tables', 'list customers from Boston', or 'count orders by status'."

    return "I can help you query your database. Just ask me questions like 'show me all patients' or 'find employees in Engineering'."


def respond_conversation(state: GraphState) -> GraphState:
    """Node: handle conversational input (non-query)."""
    response = state.get("conversation_response", "Hello! How can I help you?")
    state["result"] = response
    state["summary"] = response
    state["graph_hint"] = "none"
    state["graph_spec"] = {"chart_type": "none", "x_key": "", "y_keys": []}
    state["columns"] = []
    state["data"] = []
    _emit_progress(state, "conversation_response", "Conversation response")
    return state


def _should_enable_jsonb_querying(
    profile_cache: Optional[ProfileCache], question: str = ""
) -> bool:
    """Return True only when the question is likely about a JSON/JSONB column.

    Collects all JSON column names and their extracted top-level keys from the
    profile cache, then checks whether any of those terms appear in the
    question.  This avoids injecting JSONB hints for purely relational queries
    on databases that happen to have a JSON column somewhere.
    """
    if profile_cache is None:
        return False

    json_terms: list[str] = []
    for table in profile_cache.tables.values():
        for col_name, column in table.columns.items():
            data_type = str(getattr(column, "data_type", "")).lower()
            if "json" in data_type:
                json_terms.append(col_name.lower())
                for key in getattr(column, "json_keys", []):
                    json_terms.append(str(key).lower())

    if not json_terms:
        return False

    if not question:
        return True

    q_lower = question.lower()
    return any(term in q_lower for term in json_terms)


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


def fix_sql_with_error(state: GraphState, sql: str, error_msg: str, schema: str, suggested_fix: str = None) -> str:
    fix_hint = f"\nSuggested fix: {suggested_fix}" if suggested_fix else ""
    prompt = f"""You are a PostgreSQL SQL expert. The following SQL query has an error:

Original SQL:
{sql}

Error Message:
{error_msg}{fix_hint}

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
        return "I couldn't find any matching records for that question."

    if len(data) == 1:
        row = data[0]
        parts = [f"{col}: {row.get(col, 'N/A')}" for col in columns]
        return f"I found one matching row: {', '.join(parts)}."

    return f"I found {len(data)} matching rows."


def _build_summary_payload(columns: list[str], data: list[dict]) -> str:
    max_rows = 8
    max_columns = 12
    max_payload_chars = 3000

    selected_columns = columns[:max_columns]
    sampled_rows = []
    for row in data[:max_rows]:
        sampled_rows.append({column: row.get(column) for column in selected_columns})

    payload = {
        "row_count": len(data),
        "included_row_count": len(sampled_rows),
        "included_columns": selected_columns,
        "rows": sampled_rows,
    }
    payload_text = json.dumps(payload, ensure_ascii=True, default=str)
    if len(payload_text) > max_payload_chars:
        payload_text = payload_text[: max_payload_chars - 3] + "..."
    return payload_text


def generate_conversational_summary(
    state: GraphState, question: str, columns: list[str], data: list[dict]
) -> str:
    llm_builder = state.get("llm_builder")
    if not callable(llm_builder):
        raise RuntimeError("Pipeline state must include a callable llm_builder")

    payload_text = _build_summary_payload(columns, data)
    prompt = f"""You summarize SQL query results for end users.

User question:
{question}

Result metadata:
- row_count: {len(data)}
- columns: {columns}

Result sample (JSON, possibly truncated):
{payload_text}

Write a direct natural-language answer in 1-2 short sentences.
Rules:
- Answer the question directly.
- If the question can be answered with yes/no from these results, start with Yes or No.
- Use only the provided result data.
- Do not mention SQL, query generation, or assumptions.
- Plain text only (no markdown, no bullet points)."""
    llm = llm_builder()
    response = llm.invoke(prompt)
    summary = _strip_markdown_fences(str(getattr(response, "content", "")).strip())
    summary = " ".join(summary.split())
    if not summary:
        raise RuntimeError("Empty summary from LLM")
    return summary


def _extract_json_object(text: str) -> Optional[dict[str, Any]]:
    raw = (text or "").strip()
    if not raw:
        return None
    try:
        parsed = json.loads(raw)
        return parsed if isinstance(parsed, dict) else None
    except Exception:
        pass

    match = re.search(r"\{[\s\S]*\}", raw)
    if not match:
        return None

    candidate = match.group(0)
    try:
        parsed = json.loads(candidate)
        return parsed if isinstance(parsed, dict) else None
    except Exception:
        return None


def generate_graph_spec(
    state: GraphState, question: str, columns: list[str], data: list[dict]
) -> dict[str, Any]:
    fallback = build_fallback_graph_spec(columns, data)
    fallback["source"] = "heuristic"

    llm_builder = state.get("llm_builder")
    if not callable(llm_builder):
        return fallback

    prompt = f"""You pick a chart spec from SQL results.

Return JSON only with this shape:
{{
  "chart_type": "bar|line|pie|none",
  "x_key": "<column name>",
  "y_keys": ["<numeric column>"]
}}

Question:
{question}

Columns:
{columns}

Result sample JSON:
{_build_summary_payload(columns, data)}

Rules:
- Use only listed columns.
- y_keys must be numeric columns only.
- Use line for time-series trends, bar for categorical comparisons, pie for small part-to-whole.
- Prefer a single metric for pie charts.
- If data is not chartable, return chart_type "none" with empty keys.
- Output plain JSON only.
"""
    try:
        llm = llm_builder()
        response = llm.invoke(prompt)
        parsed = _extract_json_object(str(getattr(response, "content", "")))
        validated = validate_graph_spec(parsed, columns, data) if parsed else None
        if validated:
            validated["source"] = "llm"
            return validated
    except Exception:
        pass
    return fallback


def generate_summary_and_graph_spec(
    state: GraphState, question: str, columns: list[str], data: list[dict]
) -> tuple[str, dict[str, Any]]:
    summary_fallback = generate_summary(question, columns, data)
    spec_fallback = build_fallback_graph_spec(columns, data)
    spec_fallback["source"] = "heuristic"

    llm_builder = state.get("llm_builder")
    if not callable(llm_builder):
        return summary_fallback, spec_fallback

    payload_text = _build_summary_payload(columns, data)
    prompt = f"""You analyze SQL query results and return a JSON object with two fields.

Return ONLY valid JSON with this exact shape:
{{
  "summary": "<1-2 sentence plain-text answer>",
  "graph_spec": {{
    "chart_type": "bar|line|pie|none",
    "x_key": "<column name or empty string>",
    "y_keys": ["<numeric column>"]
  }}
}}

User question:
{question}

Result metadata:
- row_count: {len(data)}
- columns: {columns}

Result sample (JSON, possibly truncated):
{payload_text}

Rules for summary:
- Answer the question directly in 1-2 short sentences.
- If the question can be answered with yes/no, start with Yes or No.
- Use only the provided result data.
- Do not mention SQL, query generation, or assumptions.
- Plain text only (no markdown, no bullet points).

Rules for graph_spec:
- Use only listed columns for x_key and y_keys.
- y_keys must be numeric columns only.
- Use line for time-series trends, bar for categorical comparisons, pie for small part-to-whole.
- Prefer a single metric for pie charts.
- If data is not chartable, return chart_type "none" with empty string x_key and empty y_keys array.

Output plain JSON only — no markdown fences, no explanation outside the JSON object."""

    summary = summary_fallback
    graph_spec = spec_fallback
    try:
        llm = llm_builder()
        response = llm.invoke(prompt)
        raw = str(getattr(response, "content", ""))
        parsed = _extract_json_object(raw)
        if parsed:
            raw_summary = " ".join(str(parsed.get("summary", "")).split()).strip()
            raw_summary = _strip_markdown_fences(raw_summary)
            if raw_summary:
                summary = raw_summary
            raw_spec = parsed.get("graph_spec")
            if isinstance(raw_spec, dict):
                validated = validate_graph_spec(raw_spec, columns, data)
                if validated:
                    validated["source"] = "llm"
                    graph_spec = validated
    except Exception:
        pass

    return summary, graph_spec


def fetch_schema(state: GraphState) -> GraphState:
    """Node 1: fetch or build profiled schema text."""
    if state.get("profile_cache") is not None and state.get("schema"):
        _emit_progress(state, "schema_profile_loaded", "Schema/profile loaded")
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
    _emit_progress(state, "schema_profile_loaded", "Schema/profile loaded")
    return state


def generate_sql(state: GraphState) -> GraphState:
    """Node 2: generate SQL, then refine with schema linking + validator."""
    question = state.get("question", "")
    history = state.get("conversation_history") or []

    jsonb_enabled = _should_enable_jsonb_querying(state.get("profile_cache"), question)

    if state.get("profile_cache"):
        prompt = build_profiled_schema_prompt(
            state["profile_cache"],
            question,
            summary_cache=state.get("summary_cache"),
            enable_jsonb_querying=jsonb_enabled,
            conversation_history=history,
        )
    else:
        prompt = build_sql_generation_prompt(
            state.get("schema", ""),
            question,
            enable_jsonb_querying=jsonb_enabled,
            conversation_history=history,
        )

    initial_sql = _llm_invoke(state, prompt)
    _emit_progress(state, "sql_drafted", "SQL drafted")

    if state.get("profile_cache"):
        filtered_schema, _ = link_schema(
            initial_sql, state["profile_cache"], state.get("summary_cache")
        )
        _emit_progress(state, "schema_linking_complete", "Schema linking complete")
        refined_prompt = build_two_pass_prompt(
            initial_sql,
            filtered_schema,
            question,
            enable_jsonb_querying=jsonb_enabled,
            conversation_history=history,
        )
        sql = _llm_invoke(state, refined_prompt)
    else:
        _emit_progress(state, "schema_linking_complete", "Schema linking complete")
        sql = initial_sql

    db_id = state.get("db_id")
    if db_id and state.get("profile_cache"):
        conn = get_connection(db_id)
        try:
            validation_result = validate_sql_with_execution(sql, question, conn)
            if not validation_result.is_valid and validation_result.suggested_fix:
                state["_validation_error"] = validation_result.execution_error
                state["_error_type"] = validation_result.error_type
                state["_suggested_fix"] = validation_result.suggested_fix
        finally:
            conn.close()
    else:
        validation_result = validate_sql(sql, question)

    state["sql_query"] = validation_result.sql
    _emit_progress(state, "sql_validated", "SQL validated")
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
            state["summary"] = "I couldn't find any matching records for that question."
            state["graph_hint"] = "none"
            state["graph_spec"] = {"chart_type": "none", "x_key": "", "y_keys": []}
            _emit_progress(
                state,
                "query_executed",
                "Query executed",
                status="failed",
                meta={"reason": "Only SELECT queries are allowed"},
            )
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
                state["summary"] = "I couldn't find any matching records for that question."
                state["graph_hint"] = "none"
                state["graph_spec"] = {"chart_type": "none", "x_key": "", "y_keys": []}
                _emit_progress(state, "query_executed", "Query executed")
                _emit_progress(state, "summary_generated", "Summary generated")
                _emit_progress(
                    state,
                    "chart_recommendation_generated",
                    "Chart recommendation generated",
                )
                state["result"] = state["summary"]
                return state

            data = [dict(zip(columns, row)) for row in rows]

            profile_cache = state.get("profile_cache")
            if profile_cache:
                data, columns = format_jsonb_results(data, columns, profile_cache)

            state["columns"] = columns
            state["data"] = data
            _emit_progress(state, "query_executed", "Query executed")
            question = state.get("question", "")
            summary, graph_spec = generate_summary_and_graph_spec(
                state, question, columns, data
            )
            state["summary"] = summary
            _emit_progress(state, "summary_generated", "Summary generated")
            state["graph_spec"] = graph_spec
            _emit_progress(
                state, "chart_recommendation_generated", "Chart recommendation generated"
            )
            state["graph_hint"] = (
                "auto" if graph_spec.get("chart_type") != "none" else "none"
            )
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
                state.setdefault(
                    "summary", "I couldn't find any matching records for that question."
                )
                state.setdefault("graph_hint", "none")
                state.setdefault(
                    "graph_spec", {"chart_type": "none", "x_key": "", "y_keys": []}
                )
                _emit_progress(
                    state,
                    "query_executed",
                    "Query executed",
                    status="failed",
                    meta={"reason": error_msg},
                )
                return state

            state["sql_query"] = fix_sql_with_error(
                state, sql, error_msg, state.get("schema", ""), state.get("_suggested_fix")
            )

    state["error"] = f"Error: Max iterations ({max_iterations}) exceeded"
    state["result"] = state["error"]
    state.setdefault("columns", [])
    state.setdefault("data", [])
    state.setdefault("summary", "I couldn't find any matching records for that question.")
    state.setdefault("graph_hint", "none")
    state.setdefault("graph_spec", {"chart_type": "none", "x_key": "", "y_keys": []})
    return state


def run_pipeline(question: str, initial_state: Optional[GraphState] = None) -> GraphState:
    """Build and execute the LangGraph workflow."""
    workflow = StateGraph(GraphState)
    workflow.add_node("classify_input", classify_input)
    workflow.add_node("fetch_schema", fetch_schema)
    workflow.add_node("generate_sql", generate_sql)
    workflow.add_node("execute_sql", execute_sql)
    workflow.add_node("respond_conversation", respond_conversation)

    workflow.set_entry_point("classify_input")

    def route_by_classification(state: GraphState) -> str:
        if state.get("is_query", True):
            return "fetch_schema"
        return "respond_conversation"

    workflow.add_conditional_edges(
        "classify_input",
        route_by_classification,
        {
            "fetch_schema": "fetch_schema",
            "respond_conversation": "respond_conversation",
        }
    )
    workflow.add_edge("fetch_schema", "generate_sql")
    workflow.add_edge("generate_sql", "execute_sql")
    workflow.add_edge("execute_sql", END)
    workflow.add_edge("respond_conversation", END)

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
            graph_spec={"chart_type": "none", "x_key": "", "y_keys": []},
            profile_cache=None,
            is_query=True,
            conversation_response="",
        )

    initial_state["question"] = question
    return compiled.invoke(initial_state)
