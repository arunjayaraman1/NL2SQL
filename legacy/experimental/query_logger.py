import json
import time
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Optional
from contextlib import contextmanager

import psycopg2


@dataclass
class QueryLogEntry:
    id: Optional[int] = None
    question: str = ""
    sql_query: Optional[str] = None
    db_type: str = "hr"
    success: bool = False
    error_message: Optional[str] = None
    columns: Optional[list] = None
    row_count: Optional[int] = None
    execution_time_ms: Optional[int] = None
    use_schema_linking: bool = True
    use_retry: bool = True
    retry_count: int = 0
    created_at: Optional[datetime] = None
    session_id: Optional[str] = None
    user_id: Optional[str] = None


class QueryLogger:
    def __init__(self, db_conn=None):
        self._initial_conn = db_conn

    def _get_connection(self):
        import os

        return psycopg2.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=os.getenv("DB_PORT", "5432"),
            dbname=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
        )

    def _ensure_table(self, cursor):
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS query_logs (
                id SERIAL PRIMARY KEY,
                question TEXT NOT NULL,
                sql_query TEXT,
                db_type VARCHAR(50) DEFAULT 'hr',
                success BOOLEAN DEFAULT FALSE,
                error_message TEXT,
                columns JSONB,
                row_count INTEGER,
                execution_time_ms INTEGER,
                use_schema_linking BOOLEAN DEFAULT TRUE,
                use_retry BOOLEAN DEFAULT TRUE,
                retry_count INTEGER DEFAULT 0,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                session_id VARCHAR(255),
                user_id VARCHAR(255)
            )
        """)
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_query_logs_created_at 
            ON query_logs(created_at DESC)
        """)
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_query_logs_db_type 
            ON query_logs(db_type)
        """)

    def log_query(
        self,
        question: str,
        sql_query: Optional[str] = None,
        db_type: str = "hr",
        success: bool = False,
        error_message: Optional[str] = None,
        columns: Optional[list] = None,
        row_count: Optional[int] = None,
        execution_time_ms: Optional[int] = None,
        use_schema_linking: bool = True,
        use_retry: bool = True,
        retry_count: int = 0,
        session_id: Optional[str] = None,
        user_id: Optional[str] = None,
    ) -> Optional[int]:
        conn = self._get_connection()
        cursor = conn.cursor()

        try:
            self._ensure_table(cursor)

            cursor.execute(
                """
                INSERT INTO query_logs (
                    question, sql_query, db_type, success, error_message,
                    columns, row_count, execution_time_ms,
                    use_schema_linking, use_retry, retry_count,
                    session_id, user_id
                ) VALUES (
                    %s, %s, %s, %s, %s,
                    %s, %s, %s,
                    %s, %s, %s,
                    %s, %s
                )
                RETURNING id
                """,
                (
                    question,
                    sql_query,
                    db_type,
                    success,
                    error_message,
                    json.dumps(columns) if columns else None,
                    row_count,
                    execution_time_ms,
                    use_schema_linking,
                    use_retry,
                    retry_count,
                    session_id,
                    user_id,
                ),
            )

            log_id = cursor.fetchone()[0]
            conn.commit()
            return log_id

        except Exception as e:
            conn.rollback()
            print(f"[QueryLogger] Error logging query: {e}")
            return None
        finally:
            cursor.close()
            conn.close()

    def update_log(
        self,
        log_id: int,
        sql_query: Optional[str] = None,
        success: bool = False,
        error_message: Optional[str] = None,
        columns: Optional[list] = None,
        row_count: Optional[int] = None,
        execution_time_ms: Optional[int] = None,
        retry_count: int = 0,
    ) -> bool:
        conn = self._get_connection()
        cursor = conn.cursor()

        try:
            cursor.execute(
                """
                UPDATE query_logs SET
                    sql_query = COALESCE(%s, sql_query),
                    success = %s,
                    error_message = COALESCE(%s, error_message),
                    columns = COALESCE(%s, columns),
                    row_count = COALESCE(%s, row_count),
                    execution_time_ms = COALESCE(%s, execution_time_ms),
                    retry_count = %s
                WHERE id = %s
                """,
                (
                    sql_query,
                    success,
                    error_message,
                    json.dumps(columns) if columns else None,
                    row_count,
                    execution_time_ms,
                    retry_count,
                    log_id,
                ),
            )
            conn.commit()
            return cursor.rowcount > 0

        except Exception as e:
            conn.rollback()
            print(f"[QueryLogger] Error updating log: {e}")
            return False
        finally:
            cursor.close()
            conn.close()

    def get_recent_logs(
        self,
        limit: int = 50,
        offset: int = 0,
        db_type: Optional[str] = None,
        success: Optional[bool] = None,
        session_id: Optional[str] = None,
    ) -> list[QueryLogEntry]:
        conn = self._get_connection()
        cursor = conn.cursor()

        try:
            query = "SELECT * FROM query_logs WHERE 1=1"
            params = []

            if db_type:
                query += " AND db_type = %s"
                params.append(db_type)

            if success is not None:
                query += " AND success = %s"
                params.append(success)

            if session_id:
                query += " AND session_id = %s"
                params.append(session_id)

            query += " ORDER BY created_at DESC LIMIT %s OFFSET %s"
            params.extend([limit, offset])

            cursor.execute(query, params)
            rows = cursor.fetchall()

            return [self._row_to_entry(row) for row in rows]

        finally:
            cursor.close()
            conn.close()

    def get_log_by_id(self, log_id: int) -> Optional[QueryLogEntry]:
        conn = self._get_connection()
        cursor = conn.cursor()

        try:
            cursor.execute("SELECT * FROM query_logs WHERE id = %s", (log_id,))
            row = cursor.fetchone()

            if row:
                return self._row_to_entry(row)
            return None

        finally:
            cursor.close()
            conn.close()

    def get_stats(
        self,
        db_type: Optional[str] = None,
        days: int = 7,
    ) -> dict:
        conn = self._get_connection()
        cursor = conn.cursor()

        try:
            base_query = """
                FROM query_logs 
                WHERE created_at >= NOW() - INTERVAL '%s days'
            """
            params = [days]

            if db_type:
                base_query += " AND db_type = %s"
                params.append(db_type)

            cursor.execute(f"SELECT COUNT(*) {base_query}", params)
            total = cursor.fetchone()[0]

            cursor.execute(f"SELECT COUNT(*) {base_query} AND success = TRUE", params)
            successful = cursor.fetchone()[0]

            cursor.execute(f"SELECT AVG(execution_time_ms) {base_query}", params)
            avg_time = cursor.fetchone()[0] or 0

            cursor.execute(
                f"SELECT date_trunc('day', created_at) as day, COUNT(*) "
                f"{base_query} "
                f"GROUP BY day ORDER BY day DESC",
                params,
            )
            daily_counts = [
                {"date": str(row[0].date()), "count": row[1]}
                for row in cursor.fetchall()
            ]

            cursor.execute(
                f"SELECT question, COUNT(*) as cnt "
                f"{base_query} "
                f"GROUP BY question ORDER BY cnt DESC LIMIT 10",
                params,
            )
            top_questions = [
                {"question": row[0], "count": row[1]} for row in cursor.fetchall()
            ]

            return {
                "total_queries": total,
                "successful_queries": successful,
                "failed_queries": total - successful,
                "success_rate": round(
                    (successful / total * 100) if total > 0 else 0, 2
                ),
                "avg_execution_time_ms": round(avg_time, 2),
                "period_days": days,
                "daily_counts": daily_counts,
                "top_questions": top_questions,
            }

        finally:
            cursor.close()
            conn.close()

    def _row_to_entry(self, row) -> QueryLogEntry:
        return QueryLogEntry(
            id=row[0],
            question=row[1],
            sql_query=row[2],
            db_type=row[3],
            success=row[4],
            error_message=row[5],
            columns=json.loads(row[6]) if row[6] else None,
            row_count=row[7],
            execution_time_ms=row[8],
            use_schema_linking=row[9],
            use_retry=row[10],
            retry_count=row[11],
            created_at=row[12],
            session_id=row[13],
            user_id=row[14],
        )

    def clear_old_logs(self, days: int = 30) -> int:
        conn = self._get_connection()
        cursor = conn.cursor()

        try:
            cursor.execute(
                """
                DELETE FROM query_logs 
                WHERE created_at < NOW() - INTERVAL '%s days'
                """,
                (days,),
            )
            deleted = cursor.rowcount
            conn.commit()
            return deleted

        except Exception as e:
            conn.rollback()
            print(f"[QueryLogger] Error clearing logs: {e}")
            return 0
        finally:
            cursor.close()
            conn.close()


@contextmanager
def timed_query_log(logger: QueryLogger, **kwargs):
    start_time = time.time()
    log_id = None

    try:
        log_id = logger.log_query(**kwargs)
        yield log_id
    finally:
        execution_time = int((time.time() - start_time) * 1000)

        if log_id:
            logger.update_log(log_id, execution_time_ms=execution_time)
