"""
Schema Linking Module for NL2SQL

Implements two-pass schema linking:
1. Pass 1: Generate SQL with full schema
2. Pass 2: Extract used tables/columns, then refine SQL with filtered schema

This improves accuracy by giving the LLM a focused view of only relevant tables/columns.
"""

from __future__ import annotations

import re
import logging
from typing import Set, Dict, Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def extract_tables_from_sql(sql: str) -> Set[str]:
    """
    Extract table names from a SQL query.

    Args:
        sql: SQL query string

    Returns:
        Set of table names found in FROM and JOIN clauses
    """
    tables: Set[str] = set()

    sql_upper = sql.upper()

    from_pattern = r"FROM\s+(\w+)"
    for match in re.finditer(from_pattern, sql_upper, re.IGNORECASE):
        tables.add(match.group(1).lower())

    join_patterns = [
        r"JOIN\s+(\w+)",
        r"INNER\s+JOIN\s+(\w+)",
        r"LEFT\s+JOIN\s+(\w+)",
        r"RIGHT\s+JOIN\s+(\w+)",
        r"LEFT\s+OUTER\s+JOIN\s+(\w+)",
        r"RIGHT\s+OUTER\s+JOIN\s+(\w+)",
    ]

    for pattern in join_patterns:
        for match in re.finditer(pattern, sql_upper, re.IGNORECASE):
            tables.add(match.group(1).lower())

    return tables


def extract_columns_from_sql(sql: str) -> Dict[str, Set[str]]:
    """
    Extract column names grouped by table from SQL query.

    Args:
        sql: SQL query string

    Returns:
        Dict mapping table names to sets of column names
    """
    columns: Dict[str, Set[str]] = {}

    skip_words = {
        "AND",
        "OR",
        "AS",
        "ON",
        "IN",
        "NOT",
        "NULL",
        "TRUE",
        "FALSE",
        "IS",
        "LIKE",
        "ILIKE",
        "BETWEEN",
        "COUNT",
        "SUM",
        "AVG",
        "MIN",
        "MAX",
        "DISTINCT",
        "ORDER",
        "GROUP",
        "BY",
        "HAVING",
        "LIMIT",
        "OFFSET",
        "WHERE",
        "SELECT",
        "FROM",
        "JOIN",
        "INNER",
        "LEFT",
        "RIGHT",
        "OUTER",
        "FULL",
        "CROSS",
        "CASE",
        "WHEN",
        "THEN",
        "ELSE",
        "END",
        "ASC",
        "DESC",
        "UNION",
        "ALL",
    }

    qualified_pattern = r"(\w+)\.(\w+)"
    for match in re.finditer(qualified_pattern, sql, re.IGNORECASE):
        table = match.group(1).lower()
        column = match.group(2).lower()

        if table not in columns:
            columns[table] = set()
        columns[table].add(column)

    aggregate_pattern = r"(COUNT|SUM|AVG|MIN|MAX)\s*\(\s*(\w+)\s*\)"
    for match in re.finditer(aggregate_pattern, sql, re.IGNORECASE):
        func = match.group(1).lower()
        expr = match.group(2).lower()

        if "." in expr:
            parts = expr.split(".")
            table = parts[0]
            col = parts[1]
        else:
            continue

        if table not in columns:
            columns[table] = set()
        columns[table].add(col)

    unqualified_pattern = r"(WHERE|AND|OR|=|<|>|<=|>=|!=)\s+([\w\.]+)"
    for match in re.finditer(unqualified_pattern, sql, re.IGNORECASE):
        expr = match.group(2).lower()
        if "." in expr:
            parts = expr.split(".")
            table = parts[0]
            col = parts[1]
            if table.upper() not in skip_words:
                if table not in columns:
                    columns[table] = set()
                columns[table].add(col)

    return columns


def build_linked_schema(
    profile_cache, used_tables: Set[str], column_summaries: Optional[dict] = None
) -> str:
    """
    Build a filtered schema string with only the used tables.

    Args:
        profile_cache: ProfileCache with full database schema
        used_tables: Set of table names used in the query
        column_summaries: Optional dict of column summaries

    Returns:
        Formatted schema string with only relevant tables
    """
    lines = []

    for table_name in sorted(used_tables):
        table_key = table_name.lower()
        if table_key not in profile_cache.tables:
            continue

        table = profile_cache.tables[table_key]
        lines.append(f"\nTable: {table.name}")

        for col_name, col in table.columns.items():
            parts = [f"  - {col_name}: {col.data_type}"]

            if col.null_percentage == 0:
                parts.append("non-null")
            else:
                parts.append(f"nullable ({col.null_percentage}% null)")

            parts.append(f"{col.distinct_count} unique")

            if col.is_primary_key:
                parts.append("PRIMARY KEY")

            if col.foreign_key:
                parts.append(f"FK→{col.foreign_key}")

            if col.samples and len(col.samples) <= 3:
                parts.append(f"sample: {col.samples}")

            if col.min_value and col.max_value:
                if col.avg_length:
                    parts.append(f"range: [{col.min_value}, {col.max_value}]")
                else:
                    parts.append(f"range: [{col.min_value}, {col.max_value}]")

            lines.append(" | ".join(parts))

            if column_summaries and column_summaries.summaries.get(table.name, {}).get(
                col_name
            ):
                summary = column_summaries.summaries[table.name][col_name]
                lines.append(f"      [{summary.short_label}] {summary.description}")

    return "\n".join(lines)


def link_schema(
    initial_sql: str, profile_cache, column_summaries: Optional[dict] = None
) -> tuple[str, str]:
    """
    Perform two-pass schema linking.

    Pass 1: SQL was already generated with full schema
    Pass 2: Extract used tables, build filtered schema

    Args:
        initial_sql: SQL generated in pass 1
        profile_cache: Full database profile cache
        column_summaries: Optional column summaries

    Returns:
        Tuple of (filtered_schema, used_tables)
    """
    used_tables = extract_tables_from_sql(initial_sql)

    logger.info(f"Schema linking: extracted tables: {used_tables}")

    filtered_schema = build_linked_schema(profile_cache, used_tables, column_summaries)

    return filtered_schema, used_tables


def validate_schema_references(sql: str, available_tables: Set[str]) -> list[str]:
    """
    Validate that all table references in SQL exist in the database.

    Args:
        sql: SQL query string
        available_tables: Set of valid table names

    Returns:
        List of error messages for invalid references
    """
    errors = []
    used_tables = extract_tables_from_sql(sql)

    for table in used_tables:
        if table not in available_tables:
            errors.append(f"Table '{table}' not found in database")

    return errors


if __name__ == "__main__":
    test_sqls = [
        "SELECT e.first_name, e.last_name FROM employees e JOIN departments d ON e.department_id = d.id WHERE d.name = 'Engineering'",
        "SELECT d.name, COUNT(e.id) FROM departments d LEFT JOIN employees e ON d.id = e.department_id GROUP BY d.id, d.name",
        "SELECT first_name, last_name, salary FROM employees WHERE salary > 50000 ORDER BY salary DESC LIMIT 5",
    ]

    print("=" * 60)
    print("Schema Linker Test")
    print("=" * 60)

    for sql in test_sqls:
        tables = extract_tables_from_sql(sql)
        columns = extract_columns_from_sql(sql)

        print(f"\nSQL: {sql[:80]}...")
        print(f"Tables: {tables}")
        print(f"Columns: {columns}")
        print("-" * 40)
