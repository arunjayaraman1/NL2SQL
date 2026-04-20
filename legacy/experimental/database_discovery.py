"""
Database Discovery Module for NL2SQL

Automatically discovers schemas and tables from PostgreSQL.
No manual configuration needed - just create schemas/tables and they're available.
"""

import psycopg2
import logging
from typing import Optional
from dataclasses import dataclass

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

SYSTEM_SCHEMAS = {"pg_catalog", "information_schema", "pg_toast", "pg_temp", "pg_sys"}

CACHE_TTL = 300  # 5 minutes


@dataclass
class DiscoveredSchema:
    name: str
    tables: list
    table_count: int


@dataclass
class DiscoveredDatabases:
    schemas: list[DiscoveredSchema]
    discovered_at: float


class DatabaseDiscovery:
    def __init__(self, conn=None):
        self._conn = conn
        self._cache: Optional[DiscoveredDatabases] = None

    def _get_connection(self):
        import os

        try:
            if self._conn:
                return self._conn
            return psycopg2.connect(
                host=os.getenv("DB_HOST", "localhost"),
                port=os.getenv("DB_PORT", "5432"),
                dbname=os.getenv("DB_NAME"),
                user=os.getenv("DB_USER"),
                password=os.getenv("DB_PASSWORD"),
            )
        except psycopg2.Error as e:
            logger.error(f"Database connection error: {e}")
            raise

    def discover_all_schemas(self) -> list[DiscoveredSchema]:
        """Discover all user schemas (excluding system schemas)."""
        import time

        conn = None
        try:
            conn = self._get_connection()
            cursor = conn.cursor()

            excluded = "', '".join(SYSTEM_SCHEMAS)
            cursor.execute(
                f"""
                SELECT schema_name
                FROM information_schema.schemata
                WHERE schema_name NOT IN ('{excluded}')
                  AND schema_name NOT LIKE 'pg_temp_%'
                  AND schema_name NOT LIKE 'pg_toast_%'
                ORDER BY schema_name
            """
            )

            schemas = []
            for (schema_name,) in cursor.fetchall():
                tables = self._discover_tables(conn, schema_name)
                schemas.append(
                    DiscoveredSchema(
                        name=schema_name, tables=tables, table_count=len(tables)
                    )
                )

            self._cache = DiscoveredDatabases(
                schemas=schemas, discovered_at=time.time()
            )

            return schemas

        finally:
            if cursor:
                cursor.close()
            if conn and not self._conn:
                conn.close()

    def _discover_tables(self, conn, schema_name: str) -> list:
        """Discover all tables in a schema."""
        cursor = conn.cursor()

        try:
            cursor.execute(
                """
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = %s
                  AND table_type = 'BASE TABLE'
                ORDER BY table_name
            """,
                (schema_name,),
            )

            return [row[0] for row in cursor.fetchall()]

        finally:
            cursor.close()

    def get_schemas(self, force_refresh: bool = False) -> list[DiscoveredSchema]:
        """Get schemas, using cache if valid."""
        import time

        if force_refresh:
            return self.discover_all_schemas()

        if self._cache is None:
            return self.discover_all_schemas()

        age = time.time() - self._cache.discovered_at
        if age > CACHE_TTL:
            return self.discover_all_schemas()

        return self._cache.schemas

    def get_tables_for_schema(self, schema_name: str) -> list:
        """Get tables for a specific schema."""
        schemas = self.get_schemas()
        for schema in schemas:
            if schema.name == schema_name:
                return schema.tables
        return []

    def get_all_table_names(self, schema_name: str) -> list:
        """Get fully qualified table names (schema.table)."""
        tables = self.get_tables_for_schema(schema_name)
        return [f"{schema_name}.{table}" for table in tables]


def get_database_discovery(db_conn=None) -> DatabaseDiscovery:
    """Get or create a DatabaseDiscovery instance."""
    return DatabaseDiscovery(db_conn)
