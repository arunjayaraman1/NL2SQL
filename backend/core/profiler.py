"""
Database Profiling Layer for NL2SQL

Extracts smart metadata from database tables and columns:
- Null counts and percentages
- Distinct values count
- Sample values (top 5)
- Min/Max for numeric and date columns
- Average length for text columns
- Primary key and foreign key detection

Profiles every non-system schema in the connected database and keys tables by
their fully-qualified name (``schema.table``). Callers can pass a
``cache_path`` so multiple databases each keep their own profile cache file.
"""

from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass, asdict, field
from datetime import datetime
from pathlib import Path
from typing import Optional

import psycopg2
from psycopg2 import sql as _sql


CACHE_FILE = os.getenv("PROFILE_CACHE_FILE", "profile_cache.json")
DEFAULT_EXPIRY = int(os.getenv("PROFILE_CACHE_TTL", "3600"))

# Keep in sync with db_registry.SYSTEM_SCHEMAS.
_SYSTEM_SCHEMAS: tuple[str, ...] = (
    "pg_catalog",
    "information_schema",
    "pg_toast",
    "pg_temp",
)


@dataclass
class ProfileColumn:
    name: str
    data_type: str
    total_count: int
    null_count: int
    null_percentage: float
    distinct_count: int
    samples: list = field(default_factory=list)
    min_value: Optional[str] = None
    max_value: Optional[str] = None
    avg_length: Optional[float] = None
    is_primary_key: bool = False
    foreign_key: Optional[str] = None
    is_json_type: bool = False
    json_keys: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> ProfileColumn:
        return cls(**data)


@dataclass
class ProfileTable:
    """A profiled table. ``name`` is the qualified ``schema.table`` name."""

    name: str
    row_count: int
    column_count: int
    columns: dict[str, ProfileColumn] = field(default_factory=dict)
    schema: str = "public"

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "row_count": self.row_count,
            "column_count": self.column_count,
            "schema": self.schema,
            "columns": {k: v.to_dict() for k, v in self.columns.items()},
        }

    @classmethod
    def from_dict(cls, data: dict) -> ProfileTable:
        columns = {k: ProfileColumn.from_dict(v) for k, v in data["columns"].items()}
        return cls(
            name=data["name"],
            row_count=data["row_count"],
            column_count=data["column_count"],
            schema=data.get("schema", "public"),
            columns=columns,
        )


@dataclass
class ProfileCache:
    database_hash: str
    generated_at: str
    expires_in_seconds: int
    tables: dict[str, ProfileTable] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "database_hash": self.database_hash,
            "generated_at": self.generated_at,
            "expires_in_seconds": self.expires_in_seconds,
            "tables": {k: v.to_dict() for k, v in self.tables.items()},
        }

    @classmethod
    def from_dict(cls, data: dict) -> ProfileCache:
        tables = {k: ProfileTable.from_dict(v) for k, v in data["tables"].items()}
        return cls(
            database_hash=data["database_hash"],
            generated_at=data["generated_at"],
            expires_in_seconds=data["expires_in_seconds"],
            tables=tables,
        )

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2)

    @classmethod
    def from_json(cls, json_str: str) -> ProfileCache:
        return cls.from_dict(json.loads(json_str))


# =============================================================================
# LOW-LEVEL HELPERS
# =============================================================================


def _qualified(schema: str, table: str) -> str:
    return f"{schema}.{table}"


def _ident(schema: str, table: str) -> _sql.Composed:
    return _sql.SQL("{}.{}").format(_sql.Identifier(schema), _sql.Identifier(table))


def get_database_hash(conn: psycopg2.extensions.connection) -> str:
    """Generate a hash based on database name and all user-schema column layouts."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT table_schema, table_name, column_name, data_type
            FROM information_schema.columns
            WHERE table_schema NOT IN %s
              AND table_schema NOT LIKE 'pg_temp_%%'
              AND table_schema NOT LIKE 'pg_toast_%%'
            ORDER BY table_schema, table_name, ordinal_position
            """,
            (_SYSTEM_SCHEMAS,),
        )
        columns = cursor.fetchall()

        cursor.execute("SELECT current_database()")
        db_name = cursor.fetchone()[0]
    finally:
        cursor.close()

    schema_str = json.dumps(
        {
            "database": db_name,
            "schema": [(s, t, c, dt) for s, t, c, dt in columns],
        }
    )
    return hashlib.md5(schema_str.encode()).hexdigest()


def load_profile_cache(path: str = CACHE_FILE) -> Optional[ProfileCache]:
    """Load profile cache from JSON file if it exists."""
    cache_path = Path(path)
    if not cache_path.exists():
        return None

    try:
        with open(cache_path, "r") as f:
            data = json.load(f)
        return ProfileCache.from_dict(data)
    except (json.JSONDecodeError, KeyError, TypeError):
        return None


def save_profile_cache(cache: ProfileCache, path: str = CACHE_FILE) -> None:
    """Save profile cache to JSON file."""
    cache_path = Path(path)
    cache_path.parent.mkdir(parents=True, exist_ok=True)

    with open(cache_path, "w") as f:
        f.write(cache.to_json())


def is_cache_valid(cache: ProfileCache, current_hash: str) -> bool:
    """Check if cache is still valid (not expired and hash matches)."""
    if cache.database_hash != current_hash:
        return False

    generated = datetime.fromisoformat(cache.generated_at)
    age_seconds = (datetime.utcnow() - generated).total_seconds()

    return age_seconds < cache.expires_in_seconds


def get_table_primary_keys(
    conn: psycopg2.extensions.connection, schema: str, table_name: str
) -> set[str]:
    """Get primary key columns for a table."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
               AND tc.table_schema = kcu.table_schema
            WHERE tc.table_schema = %s
              AND tc.table_name = %s
              AND tc.constraint_type = 'PRIMARY KEY'
            """,
            (schema, table_name),
        )
        return {row[0] for row in cursor.fetchall()}
    finally:
        cursor.close()


def get_table_foreign_keys(
    conn: psycopg2.extensions.connection, schema: str, table_name: str
) -> dict[str, str]:
    """Return {column: "schema.table.column"} for foreign keys on a table."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT
                kcu.column_name,
                ccu.table_schema AS referenced_schema,
                ccu.table_name AS referenced_table,
                ccu.column_name AS referenced_column
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
               AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage ccu
                ON tc.constraint_name = ccu.constraint_name
               AND tc.table_schema = ccu.table_schema
            WHERE tc.table_schema = %s
              AND tc.table_name = %s
              AND tc.constraint_type = 'FOREIGN KEY'
            """,
            (schema, table_name),
        )
        return {
            row[0]: f"{row[1]}.{row[2]}.{row[3]}" for row in cursor.fetchall()
        }
    finally:
        cursor.close()


def get_column_type(
    conn: psycopg2.extensions.connection,
    schema: str,
    table_name: str,
    column_name: str,
) -> str:
    """Get the data type of a column."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT data_type
            FROM information_schema.columns
            WHERE table_schema = %s
              AND table_name = %s
              AND column_name = %s
            """,
            (schema, table_name, column_name),
        )
        result = cursor.fetchone()
        return result[0] if result else "unknown"
    finally:
        cursor.close()


# =============================================================================
# PROFILING
# =============================================================================


def profile_column(
    conn: psycopg2.extensions.connection,
    schema: str,
    table_name: str,
    column_name: str,
    primary_keys: set[str],
    foreign_keys: dict[str, str],
) -> ProfileColumn:
    """Profile a single column using aggregate SQL queries (no full-table scan)."""
    data_type = get_column_type(conn, schema, table_name, column_name)
    is_json = _is_json_type(data_type)
    cursor = conn.cursor()
    try:
        # Row counts and distinct count in one pass.
        stmt = _sql.SQL(
            "SELECT COUNT(*), COUNT({col}), COUNT(DISTINCT {col}) FROM {tbl}"
        ).format(col=_sql.Identifier(column_name), tbl=_ident(schema, table_name))
        cursor.execute(stmt)
        total_count, non_null_count, distinct_count = cursor.fetchone()
        null_count = total_count - non_null_count
        null_percentage = round(null_count / total_count * 100, 1) if total_count > 0 else 0.0

        # Top-5 most frequent values.  For JSON columns use a simple LIMIT
        # fetch because GROUP BY on jsonb is expensive and rarely meaningful.
        samples: list[str] = []
        if non_null_count > 0:
            if is_json:
                stmt = _sql.SQL(
                    "SELECT {col}::text FROM {tbl} WHERE {col} IS NOT NULL LIMIT 5"
                ).format(col=_sql.Identifier(column_name), tbl=_ident(schema, table_name))
                cursor.execute(stmt)
                samples = [row[0] for row in cursor.fetchall()]
            else:
                stmt = _sql.SQL("""
                    SELECT {col}, COUNT(*) AS cnt
                    FROM (SELECT {col} FROM {tbl} LIMIT 50000) _s
                    WHERE {col} IS NOT NULL
                    GROUP BY {col}
                    ORDER BY cnt DESC
                    LIMIT 5
                """).format(
                    col=_sql.Identifier(column_name), tbl=_ident(schema, table_name)
                )
                cursor.execute(stmt)
                samples = [str(row[0]) for row in cursor.fetchall()]

        # Range stats via dedicated aggregate queries (avoids fetching all rows).
        min_value: Optional[str] = None
        max_value: Optional[str] = None
        avg_length: Optional[float] = None
        type_lower = data_type.lower()

        if any(t in type_lower for t in ["integer", "numeric", "decimal", "real", "double", "bigint", "smallint", "serial"]):
            stmt = _sql.SQL("SELECT MIN({col}), MAX({col}) FROM {tbl}").format(
                col=_sql.Identifier(column_name), tbl=_ident(schema, table_name)
            )
            cursor.execute(stmt)
            row = cursor.fetchone()
            if row[0] is not None:
                min_value, max_value = str(row[0]), str(row[1])

        elif any(t in type_lower for t in ["date", "time", "timestamp"]):
            stmt = _sql.SQL("SELECT MIN({col}), MAX({col}) FROM {tbl}").format(
                col=_sql.Identifier(column_name), tbl=_ident(schema, table_name)
            )
            cursor.execute(stmt)
            row = cursor.fetchone()
            if row[0] is not None:
                min_v = row[0].date() if hasattr(row[0], "date") else row[0]
                max_v = row[1].date() if hasattr(row[1], "date") else row[1]
                min_value, max_value = str(min_v), str(max_v)

        elif type_lower in ["character varying", "varchar", "character", "char", "text"]:
            stmt = _sql.SQL(
                "SELECT MIN(length({col})), MAX(length({col})), AVG(length({col}))"
                " FROM {tbl} WHERE {col} IS NOT NULL"
            ).format(col=_sql.Identifier(column_name), tbl=_ident(schema, table_name))
            cursor.execute(stmt)
            row = cursor.fetchone()
            if row[0] is not None:
                min_value, max_value = str(row[0]), str(row[1])
                avg_length = round(float(row[2]), 1)

        # JSON key extraction from a small sample.
        json_keys: list[str] = []
        if is_json and non_null_count > 0:
            stmt = _sql.SQL(
                "SELECT {col}::text FROM {tbl} WHERE {col} IS NOT NULL LIMIT 10"
            ).format(col=_sql.Identifier(column_name), tbl=_ident(schema, table_name))
            cursor.execute(stmt)
            json_keys = _extract_json_keys([row[0] for row in cursor.fetchall()])

        return ProfileColumn(
            name=column_name,
            data_type=data_type,
            total_count=total_count,
            null_count=null_count,
            null_percentage=null_percentage,
            distinct_count=distinct_count,
            samples=samples,
            min_value=min_value,
            max_value=max_value,
            avg_length=avg_length,
            is_primary_key=column_name in primary_keys,
            foreign_key=foreign_keys.get(column_name),
            is_json_type=is_json,
            json_keys=json_keys,
        )
    finally:
        cursor.close()


def _extract_json_keys(sampled_values: list, max_keys: int = 20) -> list[str]:
    """Extract all unique top-level keys from JSON/JSONB values."""
    if not sampled_values:
        return []

    all_keys: set[str] = set()
    for val in sampled_values:
        if val is None:
            continue
        try:
            parsed = json.loads(val) if isinstance(val, str) else val
            if isinstance(parsed, dict):
                all_keys.update(parsed.keys())
            elif isinstance(parsed, list) and parsed:
                first_item = parsed[0]
                if isinstance(first_item, dict):
                    all_keys.update(first_item.keys())
        except (json.JSONDecodeError, TypeError):
            continue

        if len(all_keys) >= max_keys:
            break

    return sorted(list(all_keys))[:max_keys]


def _is_json_type(data_type: str) -> bool:
    """Check if data type is JSON or JSONB."""
    if not data_type:
        return False
    return "json" in data_type.lower()


def profile_table(
    conn: psycopg2.extensions.connection, schema: str, table_name: str
) -> ProfileTable:
    """Profile a single table in the given schema."""
    cursor = conn.cursor()
    try:
        count_stmt = _sql.SQL("SELECT COUNT(*) FROM {}").format(
            _ident(schema, table_name)
        )
        cursor.execute(count_stmt)
        row_count = cursor.fetchone()[0]

        cursor.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = %s AND table_name = %s
            ORDER BY ordinal_position
            """,
            (schema, table_name),
        )
        columns = [row[0] for row in cursor.fetchall()]
    finally:
        cursor.close()

    primary_keys = get_table_primary_keys(conn, schema, table_name)
    foreign_keys = get_table_foreign_keys(conn, schema, table_name)

    profiled_columns = {}
    for col_name in columns:
        profiled_columns[col_name] = profile_column(
            conn, schema, table_name, col_name, primary_keys, foreign_keys
        )

    return ProfileTable(
        name=_qualified(schema, table_name),
        row_count=row_count,
        column_count=len(columns),
        columns=profiled_columns,
        schema=schema,
    )


def get_all_tables(
    conn: psycopg2.extensions.connection,
    schemas: Optional[list[str]] = None,
) -> list[tuple[str, str]]:
    """
    Return ``[(schema, table), ...]`` for every user table in the given schemas.

    If ``schemas`` is None, enumerates every non-system schema in the database.
    """
    cursor = conn.cursor()
    try:
        if schemas is None:
            cursor.execute(
                """
                SELECT table_schema, table_name
                FROM information_schema.tables
                WHERE table_type = 'BASE TABLE'
                  AND table_schema NOT IN %s
                  AND table_schema NOT LIKE 'pg_temp_%%'
                  AND table_schema NOT LIKE 'pg_toast_%%'
                ORDER BY table_schema, table_name
                """,
                (_SYSTEM_SCHEMAS,),
            )
        else:
            if not schemas:
                return []
            cursor.execute(
                """
                SELECT table_schema, table_name
                FROM information_schema.tables
                WHERE table_type = 'BASE TABLE'
                  AND table_schema = ANY(%s)
                ORDER BY table_schema, table_name
                """,
                (list(schemas),),
            )
        return [(s, t) for s, t in cursor.fetchall()]
    finally:
        cursor.close()


def profile_database(
    conn: psycopg2.extensions.connection,
    table_names: Optional[list[str]] = None,
    schemas: Optional[list[str]] = None,
    force_refresh: bool = False,
    cache_path: Optional[str] = None,
) -> ProfileCache:
    """
    Profile every (or selected) user tables reachable through ``conn``.

    Args:
        conn: Database connection.
        table_names: Optional qualified table names (``"schema.table"``) to
            restrict profiling to. When None all user tables are profiled.
        schemas: Optional list of schemas to enumerate (ignored when
            ``table_names`` is provided).
        force_refresh: Ignore any on-disk cache and re-profile from scratch.
        cache_path: Where to read/write the profile cache JSON. Defaults to
            the module-level ``CACHE_FILE``.

    Returns:
        A fresh (or cached) :class:`ProfileCache` keyed by ``schema.table``.
    """
    effective_cache_path = cache_path or CACHE_FILE
    current_hash = get_database_hash(conn)

    if not force_refresh:
        cached = load_profile_cache(effective_cache_path)
        if cached and is_cache_valid(cached, current_hash):
            return cached

    targets: list[tuple[str, str]]
    if table_names:
        targets = []
        for qname in table_names:
            if "." in qname:
                schema, table = qname.split(".", 1)
            else:
                schema, table = "public", qname
            targets.append((schema, table))
    else:
        targets = get_all_tables(conn, schemas=schemas)

    tables_profile: dict[str, ProfileTable] = {}
    for schema, table_name in targets:
        key = _qualified(schema, table_name)
        tables_profile[key] = profile_table(conn, schema, table_name)

    cache = ProfileCache(
        database_hash=current_hash,
        generated_at=datetime.utcnow().isoformat(),
        expires_in_seconds=DEFAULT_EXPIRY,
        tables=tables_profile,
    )

    save_profile_cache(cache, effective_cache_path)
    return cache


# =============================================================================
# LLM-FRIENDLY FORMATTING
# =============================================================================


def format_profiled_column(column: ProfileColumn) -> str:
    """Format a single profiled column for the LLM prompt."""
    parts = [column.name]

    parts.append(column.data_type)

    if column.null_percentage == 0:
        parts.append("non-null")
    else:
        parts.append(f"nullable ({column.null_percentage}% null)")

    parts.append(f"{column.distinct_count} unique")

    if column.is_primary_key:
        parts.append("PRIMARY KEY")

    if column.foreign_key:
        parts.append(f"FK\u2192{column.foreign_key}")

    if column.is_json_type and column.json_keys:
        parts.append(f"JSON keys: {column.json_keys}")

    if column.samples:
        if len(column.samples) <= 3:
            samples_str = str(column.samples)
        else:
            samples_str = (
                f"[{column.samples[0]}, {column.samples[1]}, {column.samples[2]}...]"
            )
        parts.append(f"sample: {samples_str}")

    if column.min_value is not None and column.max_value is not None:
        parts.append(f"range: [{column.min_value}, {column.max_value}]")

    if column.avg_length is not None:
        parts.append(f"avg_len={column.avg_length}")

    return " | ".join(parts)


def format_profiled_schema(
    cache: ProfileCache, table_names: Optional[list[str]] = None
) -> str:
    """
    Format the profiled schema for use in LLM prompts.

    Tables are rendered using their fully qualified names (``schema.table``).

    Args:
        cache: The profile cache.
        table_names: Optional list of qualified table names to include; if
            omitted, includes every table in the cache.
    """
    lines: list[str] = []

    if table_names:
        keys: list[str] = []
        for name in table_names:
            if name in cache.tables:
                keys.append(name)
            elif "." not in name:
                # Accept legacy unqualified names by probing every schema.
                for key in cache.tables:
                    if key.endswith(f".{name}"):
                        keys.append(key)
    else:
        keys = list(cache.tables.keys())

    for key in keys:
        if key not in cache.tables:
            continue

        table = cache.tables[key]
        lines.append(
            f"\nTable: {table.name} ({table.row_count} rows, {table.column_count} columns)"
        )

        for _, column in table.columns.items():
            lines.append(f"  - {format_profiled_column(column)}")

    return "\n".join(lines)


if __name__ == "__main__":
    print("Testing profiler...")

    conn = psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
    )

    print("Profiling database...")
    cache = profile_database(conn, force_refresh=True)
    print(f"Profiled {len(cache.tables)} tables")

    print("\nFormatted schema:")
    print(format_profiled_schema(cache))

    conn.close()
