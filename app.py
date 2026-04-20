"""
CLI wrapper for the shared NL2SQL pipeline.

This file now delegates execution to nl2sql_pipeline.run_pipeline so CLI and
FastAPI share the same accuracy path.
"""

import argparse
import os
from pathlib import Path

from dotenv import load_dotenv
from langchain_openai import ChatOpenAI

from backend.core.db_registry import database_ids, get_connection, init_registry
from backend.core.nl2sql_pipeline import GraphState, run_pipeline
from backend.core.profiler import format_profiled_schema, profile_database

load_dotenv()

OPENROUTER_API_KEY = os.getenv("OPENAI_API_KEY")
OPENROUTER_BASE_URL = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
LLM_MODEL = os.getenv("LLM_MODEL", "meta-llama/llama-3.3-70b-instruct")
LLM_TEMPERATURE = float(os.getenv("LLM_TEMPERATURE", "0.2"))
LLM_MAX_TOKENS = int(os.getenv("LLM_MAX_TOKENS", "1024"))
PROFILE_CACHE_DIR = os.getenv("PROFILE_CACHE_DIR", "profile_cache")


def build_llm_client() -> ChatOpenAI:
    return ChatOpenAI(
        model=LLM_MODEL,
        api_key=OPENROUTER_API_KEY,
        base_url=OPENROUTER_BASE_URL,
        temperature=LLM_TEMPERATURE,
        max_tokens=LLM_MAX_TOKENS,
    )


def _cache_path_for(db_id: str) -> str:
    return str(Path(PROFILE_CACHE_DIR) / f"{db_id}.json")


if __name__ == "__main__":
    init_registry()
    available_db_ids = database_ids()

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
    parser.add_argument(
        "--db-id",
        default=available_db_ids[0] if available_db_ids else "hr",
        help=f"Database id from registry ({', '.join(available_db_ids)})",
    )
    parser.add_argument("question", nargs="?", help="Your natural language question")

    args = parser.parse_args()

    if args.db_id not in available_db_ids:
        raise SystemExit(
            f"Unknown db_id={args.db_id!r}. Available: {', '.join(available_db_ids)}"
        )

    if args.refresh_profile or args.profile_only:
        print("=" * 60)
        print(f"NL2SQL - Database Profiling ({args.db_id})")
        print("=" * 60)
        print("\nRefreshing profile cache...")

        conn = get_connection(args.db_id)
        try:
            profile_cache = profile_database(
                conn,
                force_refresh=True,
                cache_path=_cache_path_for(args.db_id),
            )
            print(f"\nSuccessfully profiled {len(profile_cache.tables)} tables:")
            for table_name, table in profile_cache.tables.items():
                print(
                    f"  - {table_name}: {table.row_count} rows, {table.column_count} columns"
                )

            print("\nFormatted schema preview:")
            print(format_profiled_schema(profile_cache)[:500] + "...")
        finally:
            conn.close()

        if args.profile_only:
            raise SystemExit(0)

        if not args.question:
            print("\nProfile refreshed. Run again with a question.")
            raise SystemExit(0)

    print("=" * 60)
    print("NL2SQL - Natural Language to SQL Converter")
    print("With Shared Pipeline (schema linking + validation + retry)")
    print("=" * 60)

    question = args.question if args.question else input("\nEnter your question: ")
    print("\nProcessing...")

    initial_state = GraphState(
        question=question,
        db_id=args.db_id,
        llm_builder=build_llm_client,
        schema="",
        sql_query="",
        result="",
        iteration=0,
        columns=[],
        data=[],
        summary="",
        graph_hint="none",
        profile_cache=None,
        force_refresh=args.refresh_profile,
        cache_path=_cache_path_for(args.db_id),
    )

    result = run_pipeline(question, initial_state)

    print("\n--- Generated SQL ---")
    print(result.get("sql_query", ""))

    print("\n--- Results ---")
    if result.get("error"):
        print(result["error"])
    elif result.get("data"):
        cols = result.get("columns", [])
        print(", ".join(cols))
        for row in result["data"]:
            print(", ".join(str(row.get(col, "")) for col in cols))
    else:
        print(result.get("result", "No results found"))

    if result.get("iteration", 0) > 0:
        print(f"\n(Completed in {result['iteration']} attempt(s))")
