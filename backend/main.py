import os
import json
from queue import Queue
from pathlib import Path
from threading import Thread
from typing import Any

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from langchain_openai import ChatOpenAI

from backend.core.db_registry import (
    database_ids,
    get_connection,
    get_schemas,
    init_registry,
    list_databases,
)
from backend.core.nl2sql_pipeline import GraphState, run_pipeline
from backend.core.profiler import ProfileCache, profile_database

load_dotenv()

OPENROUTER_API_KEY = os.getenv("OPENAI_API_KEY")
OPENROUTER_BASE_URL = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
LLM_MODEL = os.getenv("LLM_MODEL", "meta-llama/llama-3.3-70b-instruct")
LLM_TEMPERATURE = float(os.getenv("LLM_TEMPERATURE", "0.2"))
LLM_MAX_TOKENS = int(os.getenv("LLM_MAX_TOKENS", "1024"))
PROFILE_CACHE_DIR = os.getenv("PROFILE_CACHE_DIR", "profile_cache")
DEFAULT_CORS_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:3001",
    "http://localhost:5173",
]

_profile_caches: dict[str, ProfileCache] = {}
_NUMERIC_TOKENS = ("int", "numeric", "decimal", "real", "double", "serial", "float")
_CLARIFICATION_TEXT_HINTS = (
    "no specific",
    "not enough",
    "please clarify",
    "unclear",
    "not clear",
    "criteria",
    "provide more",
    "insufficient",
)


def build_llm_client() -> ChatOpenAI:
    return ChatOpenAI(
        model=LLM_MODEL,
        api_key=OPENROUTER_API_KEY,
        base_url=OPENROUTER_BASE_URL,
        temperature=LLM_TEMPERATURE,
        max_tokens=LLM_MAX_TOKENS,
    )


def get_cors_origins() -> list[str]:
    raw = os.getenv("CORS_ALLOW_ORIGINS", "").strip()
    if not raw:
        return DEFAULT_CORS_ORIGINS
    origins = [origin.strip() for origin in raw.split(",") if origin.strip()]
    return origins or DEFAULT_CORS_ORIGINS


def _cache_path_for(db_id: str) -> str:
    return str(Path(PROFILE_CACHE_DIR) / f"{db_id}.json")


def _resolve_db_id(request: dict) -> str:
    db_id = (request.get("db_id") or request.get("db_type") or "").strip()
    if not db_id:
        raise HTTPException(status_code=400, detail="db_id is required")
    if db_id not in database_ids():
        raise HTTPException(status_code=404, detail=f"Unknown db_id: {db_id!r}")
    return db_id


def get_or_build_profile(db_id: str, force_refresh: bool = False) -> ProfileCache:
    if not force_refresh and db_id in _profile_caches:
        return _profile_caches[db_id]

    conn = get_connection(db_id)
    try:
        cache = profile_database(
            conn,
            force_refresh=force_refresh,
            cache_path=_cache_path_for(db_id),
        )
    finally:
        conn.close()

    _profile_caches[db_id] = cache
    return cache


def _is_numeric_type(data_type: str) -> bool:
    lowered = (data_type or "").lower()
    return any(token in lowered for token in _NUMERIC_TOKENS)


def _trim_schema(table_name: str) -> str:
    return table_name.split(".", 1)[1] if "." in table_name else table_name


def _build_clarification_suggestions(
    question: str, result: dict[str, Any], profile_cache: ProfileCache | None
) -> list[str]:
    tables = []
    if profile_cache is not None:
        tables = sorted(
            profile_cache.tables.values(),
            key=lambda table: table.row_count,
            reverse=True,
        )
    table = tables[0] if tables else None

    if table is not None:
        text_columns = [
            col.name
            for col in table.columns.values()
            if not _is_numeric_type(col.data_type)
        ]
        numeric_columns = [
            col.name for col in table.columns.values() if _is_numeric_type(col.data_type)
        ]
        display_table = _trim_schema(table.name)

        suggestions = [f"Show total rows in {display_table}"]

        if text_columns:
            suggestions.append(
                f"Show top 10 {text_columns[0].replace('_', ' ')} in {display_table}"
            )
        else:
            suggestions.append(f"Show first 10 rows from {display_table}")

        if numeric_columns and text_columns:
            suggestions.append(
                f"Show average {numeric_columns[0].replace('_', ' ')} by {text_columns[0].replace('_', ' ')} in {display_table}"
            )
        elif numeric_columns:
            suggestions.append(
                f"Show max and min {numeric_columns[0].replace('_', ' ')} in {display_table}"
            )
        else:
            suggestions.append(f"Show count grouped by table in this database")
        return suggestions[:3]

    question_text = (question or "").strip()
    if question_text:
        return [
            f"Show top 10 results related to {question_text}",
            f"Count records related to {question_text}",
            f"List sample records for {question_text}",
        ]

    return [
        "Show top 10 records",
        "Count rows by category",
        "List first 10 rows from the main table",
    ]


def _looks_like_clarification_payload(data: list[dict], columns: list[str]) -> bool:
    if not data or len(data) != 1 or len(columns) != 1:
        return False

    column_name = (columns[0] or "").strip().lower()
    if column_name not in {"message", "note", "info", "hint"}:
        return False

    value = data[0].get(columns[0])
    if value is None:
        return False

    value_text = str(value).strip().lower()
    if not value_text:
        return False
    return any(hint in value_text for hint in _CLARIFICATION_TEXT_HINTS)


def _finalize_query_result(
    result: dict[str, Any], question: str, profile_cache: ProfileCache | None
) -> dict:
    if result.get("is_query") == False:
        return {
            "response_type": "conversation",
            "message": result.get("conversation_response", "Hello! How can I help you?"),
        }

    suggestions = _build_clarification_suggestions(question, result, profile_cache)
    if result.get("error"):
        return {
            "response_type": "query",
            "sql_query": result.get("sql_query", ""),
            "error": result["error"],
            "graph_spec": result.get(
                "graph_spec", {"chart_type": "none", "x_key": "", "y_keys": []}
            ),
            "needs_clarification": True,
            "suggested_inputs": suggestions,
        }

    data = result.get("data", [])
    summary = (result.get("summary") or "").strip()
    if not summary:
        summary = (
            "I couldn't find any matching records for that question."
            if not data
            else "I found results for your question. See the table below."
        )

    columns = result.get("columns", [])
    has_data = bool(data)
    needs_clarification = (not has_data) or _looks_like_clarification_payload(
        data, columns
    )
    return {
        "response_type": "query",
        "sql_query": result.get("sql_query", ""),
        "columns": columns,
        "data": data,
        "summary": summary,
        "graph_hint": result.get("graph_hint", "auto"),
        "graph_spec": result.get(
            "graph_spec", {"chart_type": "none", "x_key": "", "y_keys": []}
        ),
        "needs_clarification": needs_clarification,
        "suggested_inputs": suggestions if needs_clarification else [],
    }


def _format_sse_event(event_name: str, payload: dict) -> str:
    return f"event: {event_name}\ndata: {json.dumps(payload, ensure_ascii=True, default=str)}\n\n"


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
    try:
        init_registry()
        ids = database_ids()
        print(f"Database registry loaded: {len(ids)} database(s) [{', '.join(ids)}]")
    except Exception as e:
        print(f"Warning: could not load database registry: {e}")


@app.on_event("shutdown")
async def shutdown_event():
    pass


@app.get("/api/databases")
def get_databases():
    try:
        return {"databases": list_databases()}
    except Exception as e:
        return {"databases": [], "error": str(e)}


@app.get("/api/databases/{db_id}/schemas")
def get_database_schemas(db_id: str):
    if db_id not in database_ids():
        raise HTTPException(status_code=404, detail=f"Unknown db_id: {db_id!r}")
    try:
        return {"db_id": db_id, "schemas": get_schemas(db_id)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/profile")
def get_profile(db_id: str):
    if db_id not in database_ids():
        raise HTTPException(status_code=404, detail=f"Unknown db_id: {db_id!r}")
    try:
        cache = get_or_build_profile(db_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return {
        "db_id": db_id,
        "generated_at": cache.generated_at,
        "expires_in_seconds": cache.expires_in_seconds,
        "table_count": len(cache.tables),
        "tables": list(cache.tables.keys()),
        "row_counts": {name: table.row_count for name, table in cache.tables.items()},
    }


@app.get("/api/suggestions")
def get_suggestions(db_id: str, question: str = ""):
    if db_id not in database_ids():
        raise HTTPException(status_code=404, detail=f"Unknown db_id: {db_id!r}")

    try:
        cache = get_or_build_profile(db_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    suggestions = _build_clarification_suggestions(
        question=question.strip(),
        result={},
        profile_cache=cache,
    )
    return {
        "db_id": db_id,
        "suggested_inputs": suggestions[:3],
    }


@app.post("/api/refresh-profile")
def refresh_profile(request: dict):
    db_id = _resolve_db_id(request)
    try:
        cache = get_or_build_profile(db_id, force_refresh=True)
        return {
            "status": "refreshed",
            "db_id": db_id,
            "table_count": len(cache.tables),
            "generated_at": cache.generated_at,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def _parse_conversation_history(request: dict) -> list[dict]:
    """Extract and validate conversation_history from the request body."""
    raw = request.get("conversation_history")
    if not isinstance(raw, list):
        return []
    cleaned = []
    for turn in raw:
        if not isinstance(turn, dict):
            continue
        q = str(turn.get("question", "")).strip()
        if not q:
            continue
        cleaned.append({
            "question": q,
            "sql": str(turn.get("sql", "")).strip(),
            "summary": str(turn.get("summary", "")).strip(),
        })
    return cleaned[-10:]  # cap to last 10 turns


@app.post("/api/query")
def process_query(request: dict):
    question = (request.get("question") or "").strip()
    if not question:
        raise HTTPException(status_code=400, detail="question is required")

    db_id = _resolve_db_id(request)
    force_refresh = bool(request.get("refresh_profile", False))
    history = _parse_conversation_history(request)

    try:
        cache = get_or_build_profile(db_id, force_refresh=force_refresh)
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to load profile cache: {e}"
        )

    initial_state = GraphState(
        question=question,
        db_id=db_id,
        llm_builder=build_llm_client,
        schema="",
        sql_query="",
        result="",
        iteration=0,
        columns=[],
        data=[],
        summary="",
        graph_hint="none",
        graph_spec={"chart_type": "none", "x_key": "", "y_keys": []},
        profile_cache=cache,
        force_refresh=force_refresh,
        cache_path=_cache_path_for(db_id),
        is_query=True,
        conversation_response="",
        conversation_history=history or None,
    )

    result = run_pipeline(question, initial_state)

    return _finalize_query_result(result, question=question, profile_cache=cache)


@app.post("/api/query/stream")
def process_query_stream(request: dict):
    question = (request.get("question") or "").strip()
    if not question:
        raise HTTPException(status_code=400, detail="question is required")

    db_id = _resolve_db_id(request)
    force_refresh = bool(request.get("refresh_profile", False))

    done_sentinel = object()
    event_queue: Queue = Queue()

    def push_progress(
        step_id: str, label: str, status: str = "completed", meta: dict | None = None
    ) -> None:
        event_queue.put(
            (
                "progress",
                {
                    "step_id": step_id,
                    "label": label,
                    "status": status,
                    "meta": meta or {},
                },
            )
        )

    history = _parse_conversation_history(request)

    def worker() -> None:
        try:
            cache = get_or_build_profile(db_id, force_refresh=force_refresh)
            push_progress("schema_profile_loaded", "Schema/profile loaded")

            initial_state = GraphState(
                question=question,
                db_id=db_id,
                llm_builder=build_llm_client,
                schema="",
                sql_query="",
                result="",
                iteration=0,
                columns=[],
                data=[],
                summary="",
                graph_hint="none",
                graph_spec={"chart_type": "none", "x_key": "", "y_keys": []},
                profile_cache=cache,
                force_refresh=force_refresh,
                cache_path=_cache_path_for(db_id),
                progress_callback=push_progress,
                is_query=True,
                conversation_response="",
                conversation_history=history or None,
            )

            result = run_pipeline(question, initial_state)
            final_payload = _finalize_query_result(
                result, question=question, profile_cache=cache
            )
            event_queue.put(("result", final_payload))
        except Exception as e:
            event_queue.put(("error", {"error": str(e)}))
        finally:
            event_queue.put(done_sentinel)

    def event_stream():
        Thread(target=worker, daemon=True).start()
        while True:
            item = event_queue.get()
            if item is done_sentinel:
                break
            event_name, payload = item
            yield _format_sse_event(event_name, payload)

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "Connection": "keep-alive"},
    )


@app.get("/")
def root():
    return {
        "message": "NL2SQL API with Shared Pipeline",
        "version": "3.0.0",
        "endpoints": {
            "databases": "/api/databases (GET)",
            "schemas": "/api/databases/{db_id}/schemas (GET)",
            "profile": "/api/profile?db_id=... (GET)",
            "suggestions": "/api/suggestions?db_id=... (GET)",
            "refresh_profile": "/api/refresh-profile (POST {db_id})",
            "query": "/api/query (POST {question, db_id})",
            "query_stream": "/api/query/stream (POST {question, db_id})",
        },
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
