import os
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
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


@app.post("/api/query")
def process_query(request: dict):
    question = (request.get("question") or "").strip()
    if not question:
        raise HTTPException(status_code=400, detail="question is required")

    db_id = _resolve_db_id(request)
    force_refresh = bool(request.get("refresh_profile", False))

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
        profile_cache=cache,
        force_refresh=force_refresh,
        cache_path=_cache_path_for(db_id),
    )

    result = run_pipeline(question, initial_state)

    if result.get("error"):
        return {
            "sql_query": result.get("sql_query", ""),
            "error": result["error"],
        }

    return {
        "sql_query": result.get("sql_query", ""),
        "columns": result.get("columns", []),
        "data": result.get("data", []),
        "summary": result.get("summary", ""),
        "graph_hint": result.get("graph_hint", "auto"),
    }


@app.get("/")
def root():
    return {
        "message": "NL2SQL API with Shared Pipeline",
        "version": "3.0.0",
        "endpoints": {
            "databases": "/api/databases (GET)",
            "schemas": "/api/databases/{db_id}/schemas (GET)",
            "profile": "/api/profile?db_id=... (GET)",
            "refresh_profile": "/api/refresh-profile (POST {db_id})",
            "query": "/api/query (POST {question, db_id})",
        },
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
