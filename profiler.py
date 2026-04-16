"""
Database Profiling Layer for NL2SQL

Extracts smart metadata from database tables and columns:
- Null counts and percentages
- Distinct values count
- Sample values (top 5)
- Min/Max for numeric and date columns
- Average length for text columns
- Primary key and foreign key detection

Supports caching to avoid re-profiling on every query.
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


CACHE_FILE = os.getenv("PROFILE_CACHE_FILE", "profile_cache.json")
DEFAULT_EXPIRY = int(os.getenv("PROFILE_CACHE_TTL", "3600"))


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

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> ProfileColumn:
        return cls(**data)


@dataclass
class ProfileTable:
    name: str
    row_count: int
    column_count: int
    columns: dict[str, ProfileColumn] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "row_count": self.row_count,
            "column_count": self.column_count,
            "columns": {k: v.to_dict() for k, v in self.columns.items()},
        }

    @classmethod
    def from_dict(cls, data: dict) -> ProfileTable:
        columns = {k: ProfileColumn.from_dict(v) for k, v in data["columns"].items()}
        return cls(
            name=data["name"],
            row_count=data["row_count"],
            column_count=data["column_count"],
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


def get_database_hash(conn: psycopg2.extensions.connection) -> str:
    """Generate a hash based on database name and all table schemas."""
    cursor = conn.cursor()

    cursor.execute("""
        SELECT table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'public'
        ORDER BY table_name, ordinal_position
    """)
    columns = cursor.fetchall()

    cursor.execute("SELECT current_database()")
    db_name = cursor.fetchone()[0]

    schema_str = json.dumps(
        {"database": db_name, "schema": [(t, c, dt) for t, c, dt in columns]}
    )

    cursor.close()
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
    conn: psycopg2.extensions.connection, table_name: str
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
            WHERE tc.table_name = %s
                AND tc.constraint_type = 'PRIMARY KEY'
                AND tc.table_schema = 'public'
        """,
            (table_name,),
        )
        return {row[0] for row in cursor.fetchall()}
    finally:
        cursor.close()


def get_table_foreign_keys(
    conn: psycopg2.extensions.connection, table_name: str
) -> dict[str, str]:
    """Get foreign key mappings for a table. Returns {column: referenced_table.column}."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT
                kcu.column_name,
                ccu.table_name AS referenced_table,
                ccu.column_name AS referenced_column
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
            JOIN information_schema.constraint_column_usage ccu
                ON tc.constraint_name = ccu.constraint_name
            WHERE tc.table_name = %s
                AND tc.constraint_type = 'FOREIGN KEY'
                AND tc.table_schema = 'public'
        """,
            (table_name,),
        )
        return {row[0]: f"{row[1]}.{row[2]}" for row in cursor.fetchall()}
    finally:
        cursor.close()


def get_column_type(
    conn: psycopg2.extensions.connection, table_name: str, column_name: str
) -> str:
    """Get the data type of a column."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT data_type
            FROM information_schema.columns
            WHERE table_name = %s
                AND column_name = %s
                AND table_schema = 'public'
        """,
            (table_name, column_name),
        )
        result = cursor.fetchone()
        return result[0] if result else "unknown"
    finally:
        cursor.close()


def profile_column(
    conn: psycopg2.extensions.connection,
    table_name: str,
    column_name: str,
    primary_keys: set[str],
    foreign_keys: dict[str, str],
) -> ProfileColumn:
    """Profile a single column."""
    cursor = conn.cursor()
    data_type = get_column_type(conn, table_name, column_name)

    try:
        cursor.execute(f'SELECT "{column_name}" FROM "{table_name}"')
        all_values = [row[0] for row in cursor.fetchall()]

        total_count = len(all_values)
        non_null_values = [v for v in all_values if v is not None]
        null_count = total_count - len(non_null_values)
        null_percentage = (null_count / total_count * 100) if total_count > 0 else 0

        distinct_values = set(non_null_values)
        distinct_count = len(distinct_values)

        samples = []
        if distinct_count > 0:
            value_counts: dict = {}
            for v in non_null_values:
                value_counts[v] = value_counts.get(v, 0) + 1
            sorted_values = sorted(
                value_counts.items(), key=lambda x: x[1], reverse=True
            )
            samples = [str(v[0]) for v in sorted_values[:5]]

        min_value = None
        max_value = None
        avg_length = None

        if non_null_values:
            type_lower = data_type.lower()

            if any(
                t in type_lower
                for t in ["integer", "numeric", "decimal", "real", "double"]
            ):
                numeric_values = [float(v) for v in non_null_values if _is_numeric(v)]
                if numeric_values:
                    min_value = str(min(numeric_values))
                    max_value = str(max(numeric_values))

            elif any(t in type_lower for t in ["date", "time", "timestamp"]):
                date_values = [v for v in non_null_values if isinstance(v, (datetime,))]
                if date_values:
                    min_value = (
                        str(min(date_values).date())
                        if hasattr(min(date_values), "date")
                        else str(min(date_values))
                    )
                    max_value = (
                        str(max(date_values).date())
                        if hasattr(max(date_values), "date")
                        else str(max(date_values))
                    )

            if type_lower in [
                "character varying",
                "varchar",
                "character",
                "char",
                "text",
            ]:
                str_values = [str(v) for v in non_null_values if v is not None]
                if str_values:
                    lengths = [len(v) for v in str_values]
                    avg_length = sum(lengths) / len(lengths)
                    if len(lengths) == 1:
                        min_value = str(lengths[0])
                        max_value = str(lengths[0])
                    else:
                        min_value = str(min(lengths))
                        max_value = str(max(lengths))

        is_pk = column_name in primary_keys
        fk = foreign_keys.get(column_name)

        return ProfileColumn(
            name=column_name,
            data_type=data_type,
            total_count=total_count,
            null_count=null_count,
            null_percentage=round(null_percentage, 1),
            distinct_count=distinct_count,
            samples=samples,
            min_value=min_value,
            max_value=max_value,
            avg_length=round(avg_length, 1) if avg_length else None,
            is_primary_key=is_pk,
            foreign_key=fk,
        )

    finally:
        cursor.close()


def _is_numeric(value) -> bool:
    """Check if a value can be converted to float."""
    try:
        float(value)
        return True
    except (TypeError, ValueError):
        return False


def profile_table(
    conn: psycopg2.extensions.connection, table_name: str
) -> ProfileTable:
    """Profile a single table."""
    cursor = conn.cursor()

    cursor.execute(f'SELECT COUNT(*) FROM "{table_name}"')
    row_count = cursor.fetchone()[0]

    cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = %s AND table_schema = 'public'
        ORDER BY ordinal_position
    """,
        (table_name,),
    )
    columns = [row[0] for row in cursor.fetchall()]
    cursor.close()

    primary_keys = get_table_primary_keys(conn, table_name)
    foreign_keys = get_table_foreign_keys(conn, table_name)

    profiled_columns = {}
    for col_name in columns:
        profiled_columns[col_name] = profile_column(
            conn, table_name, col_name, primary_keys, foreign_keys
        )

    return ProfileTable(
        name=table_name,
        row_count=row_count,
        column_count=len(columns),
        columns=profiled_columns,
    )


def get_all_tables(conn: psycopg2.extensions.connection) -> list[str]:
    """Get list of all tables in public schema."""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        ORDER BY table_name
    """)
    tables = [row[0] for row in cursor.fetchall()]
    cursor.close()
    return tables


def profile_database(
    conn: psycopg2.extensions.connection,
    table_names: list[str] = None,
    force_refresh: bool = False,
) -> ProfileCache:
    """
    Profile the entire database or specific tables.

    Args:
        conn: Database connection
        table_names: Optional list of tables to profile. If None, profiles all tables.
        force_refresh: If True, ignore cache and profile fresh.

    Returns:
        ProfileCache with all profiled tables
    """
    cache_path = Path(CACHE_FILE)
    current_hash = get_database_hash(conn)

    if not force_refresh:
        cached = load_profile_cache(CACHE_FILE)
        if cached and is_cache_valid(cached, current_hash):
            return cached

    tables_to_profile = table_names or get_all_tables(conn)
    tables_profile: dict[str, ProfileTable] = {}

    for table_name in tables_to_profile:
        tables_profile[table_name] = profile_table(conn, table_name)

    cache = ProfileCache(
        database_hash=current_hash,
        generated_at=datetime.utcnow().isoformat(),
        expires_in_seconds=DEFAULT_EXPIRY,
        tables=tables_profile,
    )

    save_profile_cache(cache, CACHE_FILE)
    return cache


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

    if column.samples:
        if len(column.samples) <= 3:
            samples_str = str(column.samples)
        else:
            samples_str = (
                f"[{column.samples[0]}, {column.samples[1]}, {column.samples[2]}...]"
            )
        parts.append(f"sample: {samples_str}")

    if column.min_value is not None and column.max_value is not None:
        if column.avg_length is not None:
            parts.append(f"range: [{column.min_value}, {column.max_value}]")
        else:
            parts.append(f"range: [{column.min_value}, {column.max_value}]")

    if column.avg_length is not None:
        parts.append(f"avg_len={column.avg_length}")

    return " | ".join(parts)


def format_profiled_schema(cache: ProfileCache, table_names: list[str] = None) -> str:
    """
    Format the profiled schema for use in LLM prompts.

    Args:
        cache: The profile cache
        table_names: Optional list of tables to include. If None, includes all.

    Returns:
        Formatted schema string
    """
    lines = []

    tables_to_include = table_names if table_names else list(cache.tables.keys())

    for table_name in tables_to_include:
        if table_name not in cache.tables:
            continue

        table = cache.tables[table_name]
        lines.append(
            f"\nTable: {table.name} ({table.row_count} rows, {table.column_count} columns)"
        )

        for col_name, column in table.columns.items():
            lines.append(f"  - {format_profiled_column(column)}")

    return "\n".join(lines)


def format_profiled_schema_for_db_type(cache: ProfileCache, db_type: str = None) -> str:
    """Format schema for a specific database type (filters tables by db_type)."""
    if db_type is None:
        return format_profiled_schema(cache)

    from backend.main import AVAILABLE_DATABASES

    if db_type not in AVAILABLE_DATABASES:
        return format_profiled_schema(cache)

    allowed_tables = set(AVAILABLE_DATABASES[db_type]["tables"])
    return format_profiled_schema(cache, table_names=list(allowed_tables))


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
