-- Query Logs Table
-- Tracks all NL2SQL queries, their SQL, execution results, and metadata

CREATE TABLE IF NOT EXISTS query_logs (
    id SERIAL PRIMARY KEY,
    
    -- Query identification
    question TEXT NOT NULL,
    sql_query TEXT,
    
    -- Database context
    db_type VARCHAR(50) DEFAULT 'hr',
    
    -- Execution results
    success BOOLEAN DEFAULT FALSE,
    error_message TEXT,
    
    -- Response data (stored as JSON for flexibility)
    columns JSONB,
    row_count INTEGER,
    execution_time_ms INTEGER,
    
    -- Metadata
    use_schema_linking BOOLEAN DEFAULT TRUE,
    use_retry BOOLEAN DEFAULT TRUE,
    retry_count INTEGER DEFAULT 0,
    
    -- Generated fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Optional user context (for future auth integration)
    session_id VARCHAR(255),
    user_id VARCHAR(255)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_query_logs_created_at ON query_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_query_logs_db_type ON query_logs(db_type);
CREATE INDEX IF NOT EXISTS idx_query_logs_success ON query_logs(success);
CREATE INDEX IF NOT EXISTS idx_query_logs_session ON query_logs(session_id);

-- Comments
COMMENT ON TABLE query_logs IS 'Stores all NL2SQL query logs with execution metadata';
COMMENT ON COLUMN query_logs.question IS 'Original natural language question from user';
COMMENT ON COLUMN query_logs.sql_query IS 'Generated SQL query (may be NULL on error)';
COMMENT ON COLUMN query_logs.success IS 'Whether the query executed successfully';
COMMENT ON COLUMN query_logs.error_message IS 'Error message if query failed';
COMMENT ON COLUMN query_logs.execution_time_ms IS 'Total execution time in milliseconds';
