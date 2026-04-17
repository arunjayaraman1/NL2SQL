# NL2SQL - Natural Language to SQL Converter

A full-stack application that converts natural language questions into SQL queries. Uses **React 18** (Vite), **FastAPI**, **PostgreSQL** (HR Database), and **OpenRouter LLM**.

---

## Features

### Core Features
- **Natural Language to SQL**: Ask questions in plain English, get SQL results
- **Clean Chat UI**: AI chatbot-style interface with typing indicators
- **SQL Display**: Shows generated SQL with syntax highlighting
- **Results Table**: Displays query results with all rows visible

### Enhanced NL2SQL Features
- **Schema Linking**: Two-pass SQL generation (extract → filter → refine)
- **SQL Validation**: Auto-detects missing clauses (ORDER BY, LIMIT, GROUP BY)
- **Literal Matching**: Maps user terms to database values (e.g., "Sales" → departments.name)
- **Column Summarization**: LLM-generated semantic descriptions for columns
- **Intent Hints**: Dynamically adds hints based on query patterns
- **Query Logging**: Tracks all queries with execution metadata and analytics

### Performance & Caching
- **Database Profiling**: Cached metadata (null counts, FK/PK detection, stats)
- **Column Summaries**: Cached semantic descriptions (24-hour TTL)
- **Literal Index**: Pre-indexed values for fast term matching
- **Retry Loop**: Automatic SQL error recovery (up to 3 attempts)

### Deployment
- **Docker Ready**: Full stack deployment with Docker Compose
- **React Frontend**: Vite build with Tailwind CSS
- **FastAPI Backend**: Async API with caching

---

## Prerequisites

- Python 3.10+
- Node.js 18+
- PostgreSQL (local or Docker)
- Docker & Docker Compose
- OpenRouter API Key (https://openrouter.ai/keys)

---

## Project Structure

```
NL2SQL/
├── sql_prompt.py              # NL→SQL prompt builder with hints
├── profiler.py                # Database profiling with caching
├── column_summarizer.py      # LLM column summarization
├── schema_linker.py           # Two-pass schema linking
├── literal_matcher.py         # Literal value matching
├── validator.py               # SQL validation layer
├── query_logger.py            # Query logging and analytics
├── hr_examples.py             # Few-shot examples (5)
├── backend/
│   ├── main.py                # FastAPI server
│   └── requirements.txt       # Python dependencies
├── frontend/                  # React 18 + Vite
│   ├── src/
│   │   ├── App.jsx           # Main app component
│   │   ├── main.jsx          # Entry point
│   │   ├── index.css          # Tailwind styles
│   │   └── components/
│   │       └── ChatMessage.jsx # Chat message component
│   ├── package.json
│   ├── vite.config.js
│   ├── index.html
│   └── nginx.conf
├── docker-compose.yml         # Docker full stack
└── .env                      # Environment variables
```

---

## Installation

### Environment Configuration

```bash
cp .env.example .env
```

Edit `.env` with your credentials:

```env
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=hr_db
DB_USER=postgres
DB_PASSWORD=your_password

# OpenRouter LLM Configuration
OPENAI_API_KEY=your_openrouter_api_key
LLM_MODEL=meta-llama/llama-3.3-70b-instruct
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
LLM_TEMPERATURE=0.2
LLM_MAX_TOKENS=1024

# Cache settings
PROFILE_CACHE_TTL=3600
COLUMN_CACHE_TTL=86400
LITERAL_CACHE_TTL=86400
```

### Docker Setup (Recommended)

```bash
# Build and start all services
docker-compose up --build

# Verify containers
docker ps
```

Services:
- Frontend: http://localhost:3001
- Backend API: http://localhost:8000
- PostgreSQL: localhost:5432

### Local Development

**Backend:**
```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python main.py
```

**Frontend:**
```bash
cd frontend
npm install
npm run dev
```

---

## API Endpoints

### Query Endpoints

```bash
# Main query endpoint
POST /api/query
{
  "question": "How many employees in each department?",
  "db_type": "hr",
  "use_retry": true,
  "use_schema_linking": false
}
```

### Cache Endpoints

```bash
# Get/refresh profile cache
GET  /api/profile
POST /api/refresh-profile

# Get/refresh column summaries
GET  /api/column-summaries
POST /api/refresh-summaries

# Get/refresh literal index
GET  /api/literals
POST /api/refresh-literals

# Match terms in question to database values
POST /api/match-literals
{"question": "Show employees in Sales"}
```

### Other Endpoints

```bash
# List available databases
GET /api/databases
```

### Query Logs Endpoints

```bash
# Get recent query logs
GET /api/logs
GET /api/logs?limit=20&offset=0&success=true&db_type=hr

# Get specific log by ID
GET /api/logs/{log_id}

# Get query statistics
GET /api/logs/stats
GET /api/logs/stats?days=30&db_type=hr

# Clear old logs
DELETE /api/logs/clear?days=30
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    User Interface (React 18)                      │
│                    http://localhost:3001                        │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼ nginx proxy
┌─────────────────────────────────────────────────────────────────┐
│                       FastAPI Backend                            │
│                      (backend/main.py)                          │
│                         Port 8000                                │
├─────────────────────────────────────────────────────────────────┤
│  Caches (loaded on startup):                                     │
│  ├── Profile Cache (1h)    → stats, FK/PK, null counts        │
│  ├── Column Summaries (24h) → LLM semantic descriptions        │
│  └── Literal Index (24h)   → pre-indexed values                 │
├─────────────────────────────────────────────────────────────────┤
│  Pipeline:                                                       │
│  1. Load/refresh caches                                         │
│  2. Match literal terms in question                            │
│  3. Build enhanced schema (profiled + summarized)              │
│  4. Generate SQL with LLM                                       │
│  5. Validate SQL (auto-fix missing clauses)                     │
│  6. Execute against PostgreSQL                                  │
│  7. Generate summary                                            │
│  8. Retry on error (max 3x)                                    │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      PostgreSQL (hr_db)                          │
│                         Port 5432                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Enhanced Features Detail

### 1. Schema Linking (Two-Pass)

Pass 1: Generate SQL with full schema
Pass 2: Extract used tables, filter schema, refine SQL

This reduces hallucinations by focusing the LLM on only relevant tables.

### 2. SQL Validation

Auto-detects and fixes missing clauses:
- Missing `ORDER BY` when user asks for "top" or "bottom"
- Missing `LIMIT` when user asks for "top N"
- Missing `GROUP BY` for aggregation queries
- Missing `HAVING` when filtering aggregated results

### 3. Literal Matching

Pre-indexes column values for fast lookup:
- "Sales" → matches `departments.name`
- "John Smith" → matches `employees.first_name`, `employees.last_name`

Provides hints to LLM for accurate WHERE clauses.

### 4. Column Summarization

LLM generates semantic descriptions for columns:
- `[ID] Unique identifier for each employee`
- `[Status] Employment status (active/terminated/on_leave)`

Fallback rules for common column patterns.

### 5. Query Logging

All queries are logged with metadata for analytics and debugging:
- Question, SQL, success/failure status
- Execution time, row count, retry count
- Session ID for multi-turn conversations
- Statistics: success rate, avg execution time, top questions

---

## Sample Questions

| Question | SQL Pattern |
|----------|-------------|
| How many employees in each department? | GROUP BY + COUNT |
| Show top 5 highest paid employees | ORDER BY + LIMIT |
| List employees in Sales department | JOIN + WHERE |
| Average salary by job title | GROUP BY + AVG |
| Employees hired after January 2024 | WHERE + date |
| Count by status | GROUP BY + COUNT |

---

## Troubleshooting

### Backend startup delay

First startup takes 3-5 minutes because:
1. Column summarization calls LLM for each column
2. Literal indexing scans text columns

After first run, caches are used and startup is instant.

### Backend not responding

```bash
# Check backend logs
docker-compose logs backend

# Wait for "Application startup complete" message
# Then test API
curl http://localhost:8000/api/databases
```

### 502 Bad Gateway (nginx)

Backend is still starting. Wait for startup to complete.

### Refresh caches

```bash
# Refresh all caches
curl -X POST http://localhost:8000/api/refresh-profile
curl -X POST http://localhost:8000/api/refresh-summaries
curl -X POST http://localhost:8000/api/refresh-literals
```

### Docker database reset

```bash
docker-compose down -v
docker-compose up -d
```

---

## Quick Reference Commands

```bash
# Start with Docker
docker-compose up --build

# Check API health
curl http://localhost:8000/api/databases

# Test query
curl -X POST http://localhost:8000/api/query \
  -H "Content-Type: application/json" \
  -d '{"question": "How many employees?"}'

# Check profile
curl http://localhost:8000/api/profile | jq

# View literal matches
curl -X POST http://localhost:8000/api/match-literals \
  -H "Content-Type: application/json" \
  -d '{"question": "Show Sales employees"}'

# Docker logs
docker-compose logs -f backend
```

---

## Files Overview

| File | Description |
|------|-------------|
| `sql_prompt.py` | Prompt builder with intent hints, dialect hints |
| `profiler.py` | Database profiling with caching |
| `column_summarizer.py` | LLM column summarization with fallbacks |
| `schema_linker.py` | Two-pass schema linking |
| `literal_matcher.py` | Literal value indexing and matching |
| `validator.py` | SQL validation with auto-fix |
| `query_logger.py` | Query logging and analytics |
| `backend/main.py` | FastAPI server with all endpoints |
| `frontend/src/App.jsx` | React main app component |
| `frontend/src/components/ChatMessage.jsx` | Chat message component |

---

## License

Private Project
