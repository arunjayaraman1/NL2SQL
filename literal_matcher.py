"""
Literal Matching Layer for NL2SQL

Pre-indexes column values to match user terms (e.g., "Fresno County") to
the correct column in the database. This helps the LLM generate accurate
WHERE clauses for specific values.

Features:
- Index distinct values from text columns
- Build inverted index for fast lookup
- Match user terms to columns
- Provide literal hints for prompts
"""

from __future__ import annotations

import hashlib
import json
import os
import re
from collections import defaultdict
from dataclasses import dataclass, asdict, field
from datetime import datetime
from pathlib import Path
from typing import Optional

import psycopg2


CACHE_FILE = os.getenv("LITERAL_CACHE_FILE", "literal_cache.json")
DEFAULT_EXPIRY = int(os.getenv("LITERAL_CACHE_TTL", "86400"))
MAX_VALUES_PER_COLUMN = int(os.getenv("LITERAL_MAX_VALUES", "10000"))


@dataclass
class ColumnLiterals:
    table: str
    column: str
    values: list[str] = field(default_factory=list)
    value_to_normalized: dict[str, str] = field(default_factory=dict)
    normalized_to_values: dict[str, list[str]] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "table": self.table,
            "column": self.column,
            "values": self.values,
            "value_to_normalized": self.value_to_normalized,
            "normalized_to_values": self.normalized_to_values,
        }

    @classmethod
    def from_dict(cls, data: dict) -> ColumnLiterals:
        return cls(
            table=data["table"],
            column=data["column"],
            values=data["values"],
            value_to_normalized=data["value_to_normalized"],
            normalized_to_values=data["normalized_to_values"],
        )


@dataclass
class LiteralMatch:
    table: str
    column: str
    matched_value: str
    match_type: str
    confidence: float


@dataclass
class LiteralCache:
    database_hash: str
    generated_at: str
    expires_in_seconds: int
    literals: dict[str, dict[str, ColumnLiterals]] = field(default_factory=dict)
    inverted_index: dict[str, list[dict]] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "database_hash": self.database_hash,
            "generated_at": self.generated_at,
            "expires_in_seconds": self.expires_in_seconds,
            "literals": {
                t: {c: v.to_dict() for c, v in cols.items()}
                for t, cols in self.literals.items()
            },
            "inverted_index": self.inverted_index,
        }

    @classmethod
    def from_dict(cls, data: dict) -> LiteralCache:
        literals = {}
        for t, cols in data["literals"].items():
            literals[t] = {c: ColumnLiterals.from_dict(v) for c, v in cols.items()}

        return cls(
            database_hash=data["database_hash"],
            generated_at=data["generated_at"],
            expires_in_seconds=data["expires_in_seconds"],
            literals=literals,
            inverted_index=data["inverted_index"],
        )

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2)

    @classmethod
    def from_json(cls, json_str: str) -> LiteralCache:
        return cls.from_dict(json.loads(json_str))


def _normalize_value(value: str) -> str:
    """Normalize a value for matching: lowercase, remove extra spaces."""
    return re.sub(r"\s+", " ", value.lower().strip())


def _tokenize(text: str) -> list[str]:
    """Tokenize text into searchable chunks."""
    text = text.lower()
    tokens = re.findall(r"[a-z0-9]+", text)
    return tokens


def get_database_hash(conn: psycopg2.extensions.connection) -> str:
    """Get database hash (reuse from profiler if available)."""
    try:
        from profiler import get_database_hash as profiler_hash

        return profiler_hash(conn)
    except ImportError:
        cursor = conn.cursor()
        cursor.execute("SELECT current_database()")
        db_name = cursor.fetchone()[0]
        cursor.execute("""
            SELECT table_name, column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public'
            ORDER BY table_name, ordinal_position
        """)
        columns = cursor.fetchall()
        schema_str = json.dumps(
            {"database": db_name, "schema": [(t, c, dt) for t, c, dt in columns]}
        )
        cursor.close()
        return hashlib.md5(schema_str.encode()).hexdigest()


def load_literal_cache(path: str = CACHE_FILE) -> Optional[LiteralCache]:
    """Load literal cache from JSON file."""
    cache_path = Path(path)
    if not cache_path.exists():
        return None

    try:
        with open(cache_path, "r") as f:
            data = json.load(f)
        return LiteralCache.from_dict(data)
    except (json.JSONDecodeError, KeyError, TypeError):
        return None


def save_literal_cache(cache: LiteralCache, path: str = CACHE_FILE) -> None:
    """Save literal cache to JSON file."""
    cache_path = Path(path)
    cache_path.parent.mkdir(parents=True, exist_ok=True)

    with open(cache_path, "w") as f:
        f.write(cache.to_json())


def is_cache_valid(cache: LiteralCache, current_hash: str) -> bool:
    """Check if cache is still valid."""
    if cache.database_hash != current_hash:
        return False

    generated = datetime.fromisoformat(cache.generated_at)
    age_seconds = (datetime.utcnow() - generated).total_seconds()

    return age_seconds < cache.expires_in_seconds


def get_text_columns(
    conn: psycopg2.extensions.connection, table_name: str
) -> list[str]:
    """Get text-based columns for a table."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = %s
                AND table_schema = 'public'
                AND data_type IN ('character varying', 'varchar', 'character', 'char', 'text')
            ORDER BY ordinal_position
        """,
            (table_name,),
        )
        return [row[0] for row in cursor.fetchall()]
    finally:
        cursor.close()


def index_column_values(
    conn: psycopg2.extensions.connection,
    table_name: str,
    column_name: str,
) -> Optional[ColumnLiterals]:
    """Index distinct values from a text column."""
    cursor = conn.cursor()
    try:
        cursor.execute(
            f"""
            SELECT DISTINCT "{column_name}"
            FROM "{table_name}"
            WHERE "{column_name}" IS NOT NULL
            ORDER BY "{column_name}"
            LIMIT %s
        """,
            (MAX_VALUES_PER_COLUMN,),
        )

        rows = cursor.fetchall()
        if not rows:
            return None

        literals = ColumnLiterals(table=table_name, column=column_name)

        for row in rows:
            value = str(row[0])
            if not value.strip():
                continue

            literals.values.append(value)
            normalized = _normalize_value(value)
            literals.value_to_normalized[value] = normalized

            if normalized not in literals.normalized_to_values:
                literals.normalized_to_values[normalized] = []
            literals.normalized_to_values[normalized].append(value)

        return literals if literals.values else None

    finally:
        cursor.close()


def build_inverted_index(
    literals: dict[str, dict[str, ColumnLiterals]],
) -> dict[str, list[dict]]:
    """Build inverted index for fast term lookup."""
    inverted_index: dict[str, list[dict]] = defaultdict(list)

    for table_name, columns in literals.items():
        for column_name, col_literals in columns.items():
            for value in col_literals.values:
                tokens = _tokenize(value)

                for token in tokens:
                    if len(token) < 2:
                        continue

                    entry = {
                        "table": table_name,
                        "column": column_name,
                        "value": value,
                        "token": token,
                    }

                    if entry not in inverted_index[token]:
                        inverted_index[token].append(entry)

                    full_match = _normalize_value(value)
                    if full_match not in inverted_index:
                        inverted_index[full_match].append(entry)

    return dict(inverted_index)


def index_database(
    conn: psycopg2.extensions.connection,
    table_names: list[str] = None,
    force_refresh: bool = False,
) -> LiteralCache:
    """
    Index all text columns in the database.

    Args:
        conn: Database connection
        table_names: Optional list of tables to index
        force_refresh: If True, ignore cache and index fresh

    Returns:
        LiteralCache with indexed values
    """
    cache_path = Path(CACHE_FILE)
    current_hash = get_database_hash(conn)

    if not force_refresh:
        cached = load_literal_cache(CACHE_FILE)
        if cached and is_cache_valid(cached, current_hash):
            return cached

    if table_names is None:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
            ORDER BY table_name
        """)
        table_names = [row[0] for row in cursor.fetchall()]
        cursor.close()

    literals: dict[str, dict[str, ColumnLiterals]] = {}

    for table_name in table_names:
        text_columns = get_text_columns(conn, table_name)
        if not text_columns:
            continue

        table_literals: dict[str, ColumnLiterals] = {}
        for column_name in text_columns:
            col_literals = index_column_values(conn, table_name, column_name)
            if col_literals:
                table_literals[column_name] = col_literals

        if table_literals:
            literals[table_name] = table_literals

    inverted_index = build_inverted_index(literals)

    cache = LiteralCache(
        database_hash=current_hash,
        generated_at=datetime.utcnow().isoformat(),
        expires_in_seconds=DEFAULT_EXPIRY,
        literals=literals,
        inverted_index=inverted_index,
    )

    save_literal_cache(cache, CACHE_FILE)
    return cache


def match_terms_in_question(
    question: str,
    cache: LiteralCache,
    min_confidence: float = 0.5,
) -> list[LiteralMatch]:
    """
    Find literal values from the question that match indexed column values.

    Args:
        question: User's natural language question
        cache: Literal cache with indexed values
        min_confidence: Minimum confidence threshold

    Returns:
        List of LiteralMatch objects
    """
    matches: list[LiteralMatch] = []
    question_lower = question.lower()

    for table_name, columns in cache.literals.items():
        for column_name, col_literals in columns.items():
            for value in col_literals.values:
                value_lower = value.lower()

                if value_lower in question_lower:
                    confidence = 1.0
                    match_type = "exact"

                    if len(value) > 3:
                        tokens = _tokenize(value)
                        matched_tokens = sum(1 for t in tokens if t in question_lower)
                        confidence = matched_tokens / len(tokens)
                        match_type = "partial" if confidence < 1.0 else "exact"
                    else:
                        confidence = 0.8
                        match_type = "short_exact"

                    if confidence >= min_confidence:
                        matches.append(
                            LiteralMatch(
                                table=table_name,
                                column=column_name,
                                matched_value=value,
                                match_type=match_type,
                                confidence=confidence,
                            )
                        )

    matches.sort(key=lambda m: m.confidence, reverse=True)
    return matches


def get_column_values_for_hint(
    cache: LiteralCache,
    table_names: list[str] = None,
    max_values_per_column: int = 3,
) -> str:
    """
    Generate a hint string with sample values from indexed columns.

    Args:
        cache: Literal cache
        table_names: Optional filter for tables
        max_values_per_column: Max sample values per column

    Returns:
        Formatted hint string
    """
    if not cache.literals:
        return ""

    lines = ["\nKnown values in the database:"]

    tables_to_include = table_names if table_names else list(cache.literals.keys())

    for table_name in tables_to_include:
        if table_name not in cache.literals:
            continue

        table_lines = [f"  {table_name}:"]
        has_values = False

        for column_name, col_literals in cache.literals[table_name].items():
            if col_literals.values:
                has_values = True
                samples = col_literals.values[:max_values_per_column]
                samples_str = ", ".join(f"'{v}'" for v in samples)
                if len(col_literals.values) > max_values_per_column:
                    samples_str += f" (and {len(col_literals.values) - max_values_per_column} more)"
                table_lines.append(f"    {column_name}: {samples_str}")

        if has_values:
            lines.extend(table_lines)

    return "\n".join(lines)


def format_literal_hints(matches: list[LiteralMatch]) -> str:
    """Format matched literals as hints for the prompt."""
    if not matches:
        return ""

    lines = ["\nReferenced values in the question:"]
    for match in matches:
        lines.append(
            f"  '{match.matched_value}' -> {match.table}.{match.column} "
            f"(confidence: {match.confidence:.0%})"
        )

    return "\n".join(lines)


if __name__ == "__main__":
    print("Testing literal matcher...")

    conn = psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
    )

    print("Indexing database literals...")
    cache = index_database(conn, force_refresh=True)

    total_values = sum(
        len(col.values)
        for table_cols in cache.literals.values()
        for col in table_cols.values()
    )
    print(f"Indexed {total_values} values across {len(cache.literals)} tables")

    test_questions = [
        "Show employees in the Sales department",
        "Find employees who report to John Smith",
    ]

    for q in test_questions:
        matches = match_terms_in_question(q, cache)
        print(f"\nQuestion: {q}")
        if matches:
            for m in matches:
                print(f"  -> {m.table}.{m.column} = '{m.matched_value}'")
        else:
            print("  (no matches)")

    conn.close()
