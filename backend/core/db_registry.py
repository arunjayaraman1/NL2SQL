"""
Database Registry for NL2SQL

Loads a JSON file (default: ./databases.json) that enumerates the PostgreSQL
databases the backend is allowed to connect to. Each entry provides connection
parameters; ${ENV_VAR} placeholders inside the JSON are resolved from the
process environment so secrets can still live in .env.

Example databases.json:

{
  "hr": {
    "label": "HR Database",
    "host": "localhost",
    "port": 5432,
    "dbname": "hr_db",
    "user": "${DB_USER}",
    "password": "${DB_PASSWORD}"
  }
}

Typical flow:
    init_registry()                          # once at startup
    list_databases()                         # for the /api/databases endpoint
    conn = get_connection("hr")              # auto-discovers schemas,
                                             # sets search_path
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Optional

import psycopg2
from psycopg2 import sql as _sql

DEFAULT_CONFIG_PATH = os.getenv("DATABASES_CONFIG", "databases.json")

SYSTEM_SCHEMAS: tuple[str, ...] = (
    "pg_catalog",
    "information_schema",
    "pg_toast",
    "pg_temp",
)

_ENV_REF = re.compile(r"\$\{([^}]+)\}")

_REGISTRY: dict[str, dict] = {}


def _resolve_env(value):
    """Replace ${ENV_VAR} placeholders inside string values with env lookups."""
    if isinstance(value, str):
        return _ENV_REF.sub(lambda m: os.getenv(m.group(1), ""), value)
    return value


def _normalise_entry(db_id: str, cfg: dict) -> dict:
    required = {"host", "dbname", "user"}
    missing = required - cfg.keys()
    if missing:
        raise ValueError(
            f"Database registry entry '{db_id}' is missing fields: {sorted(missing)}"
        )

    resolved = {k: _resolve_env(v) for k, v in cfg.items()}
    resolved.setdefault("port", 5432)
    resolved.setdefault("password", "")
    resolved.setdefault("label", db_id.replace("_", " ").title())
    return resolved


def load_registry(path: Optional[str] = None) -> dict[str, dict]:
    """Read the registry from disk and return the resolved dict."""
    config_path = Path(path or DEFAULT_CONFIG_PATH)
    if not config_path.exists():
        raise FileNotFoundError(
            f"Database registry file not found at {config_path}. "
            "Copy databases.example.json to databases.json and edit it, or set "
            "DATABASES_CONFIG to point at your config file."
        )

    with open(config_path, "r") as f:
        raw = json.load(f)

    if not isinstance(raw, dict) or not raw:
        raise ValueError(
            f"Database registry at {config_path} must be a non-empty JSON object "
            "mapping database ids to connection configs."
        )

    return {db_id: _normalise_entry(db_id, cfg) for db_id, cfg in raw.items()}


def init_registry(path: Optional[str] = None) -> dict[str, dict]:
    """Populate the module-level registry. Safe to call multiple times."""
    global _REGISTRY
    _REGISTRY = load_registry(path)
    return _REGISTRY


def list_databases() -> list[dict]:
    """Return a UI-friendly list of databases for the /api/databases endpoint."""
    if not _REGISTRY:
        init_registry()
    return [
        {
            "id": db_id,
            "name": cfg.get("label", db_id),
            "dbname": cfg["dbname"],
            "host": cfg["host"],
        }
        for db_id, cfg in _REGISTRY.items()
    ]


def database_ids() -> list[str]:
    if not _REGISTRY:
        init_registry()
    return list(_REGISTRY.keys())


def _config_for(db_id: str) -> dict:
    if not _REGISTRY:
        init_registry()
    if db_id not in _REGISTRY:
        raise ValueError(f"Unknown database id: {db_id!r}")
    return _REGISTRY[db_id]


def discover_schemas(conn) -> list[str]:
    """
    Return every non-system schema that contains at least one user table,
    view, or materialised view in the currently connected database.

    Uses pg_namespace/pg_class (not information_schema) so the discovery is
    cheap and independent of search_path.
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT DISTINCT n.nspname
            FROM pg_namespace n
            JOIN pg_class c ON c.relnamespace = n.oid
            WHERE c.relkind IN ('r', 'p', 'v', 'm')
              AND n.nspname NOT IN %s
              AND n.nspname NOT LIKE 'pg_temp_%%'
              AND n.nspname NOT LIKE 'pg_toast_%%'
            ORDER BY n.nspname
            """,
            (SYSTEM_SCHEMAS,),
        )
        return [row[0] for row in cur.fetchall()]


def _apply_search_path(conn, schemas: list[str]) -> None:
    """Set search_path on the given connection using quoted identifiers."""
    # Always include public as a safety net; de-duplicate while preserving order.
    ordered: list[str] = []
    for name in list(schemas) + ["public"]:
        if name and name not in ordered:
            ordered.append(name)

    if not ordered:
        return

    path_ident = _sql.SQL(", ").join(_sql.Identifier(s) for s in ordered)
    stmt = _sql.SQL("SET search_path TO {};").format(path_ident)
    with conn.cursor() as cur:
        cur.execute(stmt)


def get_connection(db_id: str, schemas: Optional[list[str]] = None):
    """
    Return a new psycopg2 connection to the database identified by db_id.

    On success the connection's search_path is set to (schemas or auto-discovered
    non-system schemas) plus public.
    """
    cfg = _config_for(db_id)
    conn = psycopg2.connect(
        host=cfg["host"],
        port=cfg["port"],
        dbname=cfg["dbname"],
        user=cfg["user"],
        password=cfg["password"],
    )
    try:
        resolved_schemas = schemas if schemas is not None else discover_schemas(conn)
        _apply_search_path(conn, resolved_schemas)
    except Exception:
        conn.close()
        raise
    return conn


def get_schemas(db_id: str) -> list[str]:
    """Convenience helper: open a short-lived connection and return its schemas."""
    conn = get_connection(db_id, schemas=[])  # skip setting custom search_path
    try:
        return discover_schemas(conn)
    finally:
        conn.close()
