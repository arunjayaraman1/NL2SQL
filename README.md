# NL2SQL - Natural Language to SQL Converter (HR Database)

A full-stack application that converts natural language questions into SQL queries with interactive visualizations. Uses React, FastAPI, PostgreSQL (HR Database), and NVIDIA LLM.

---

## Features

- **Natural Language to SQL**: Ask questions in plain English, get SQL results
- **Database Profiling Layer**: Smart metadata extraction (null counts, distinct values, samples, min/max, FK detection) cached for performance
- **Conversation UI**: Multi-turn chat interface with sticky input
- **Interactive Charts**: Bar, Line, and Pie charts using Chart.js
- **Natural Language Summary**: Aggregated insights from query results
- **Retry Loop**: Automatic SQL error recovery (up to 3 attempts)
- **Error Handling**: Clear error messages for invalid queries
- **Docker Ready**: Full stack deployment with Docker Compose

---

## Prerequisites

- Python 3.8+
- Node.js 18+
- PostgreSQL (local or Docker)
- Docker & Docker Compose (optional)
- NVIDIA API Key

---

## Project Structure

```
NL2SQL/
├── app.py                     # CLI pipeline with LangGraph
├── sql_prompt.py              # Shared NL→SQL prompt builder
├── profiler.py                # Database profiling module
├── profile_cache.json         # Cached profile data (auto-generated, gitignored)
├── hr_schema.sql              # HR Database schema (17 tables)
├── hr_examples.py              # Few-shot examples (5 examples)
├── backend/
│   ├── main.py                # FastAPI server
│   └── requirements.txt       # Python dependencies
├── frontend/
│   ├── src/
│   │   ├── App.jsx            # Main React component
│   │   ├── components/        # UI components
│   │   └── index.css           # Tailwind styles
│   └── package.json            # Node dependencies
├── docker-compose.yml          # Docker full stack
├── docker/
│   └── db/init/
│       └── 02-hr_schema.sql   # HR schema for Docker
└── .env.example                # Environment template
```

---

## Installation

### Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Frontend Setup

```bash
cd frontend
npm install
```

### Environment Configuration

```bash
cp .env.example .env
```

Edit `.env` with your credentials:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=hr_db
DB_USER=postgres
DB_PASSWORD=your_password
NVIDIA_API_KEY=your_nvidia_api_key
NVIDIA_MODEL=google/gemma-2-2b-it
NVIDIA_TEMPERATURE=0.2
NVIDIA_TOP_P=0.7
NVIDIA_MAX_TOKENS=1024
PROFILE_CACHE_TTL=3600
```

---

## Database Setup (HR Database)

### Option 1: Local PostgreSQL

```bash
# Create HR database
createdb hr_db -U postgres

# Load HR schema
psql -U postgres -d hr_db -f ../hr_schema.sql
```

### Option 2: Docker (Recommended)

```bash
# Build and start all services
docker-compose up -d

# Verify container is running
docker ps

# Verify HR tables exist
docker exec -it nl2sql-db psql -U postgres -d hr_db -c "\dt"
```

Expected output: 17 tables including `employees`, `departments`, `jobs`, `leave_requests`, etc.

---

## Running the Application

### Without Docker

**Terminal 1 - Backend (Port 8000)**

```bash
cd backend
python main.py
# or: uvicorn main:app --reload --port 8000
```

**Terminal 2 - Frontend (Port 3000)**

```bash
cd frontend
npm run dev
```

### With Docker

```bash
docker-compose up --build
```

Services:
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- PostgreSQL: localhost:5432

---

## Access the Application

Open your browser to: **http://localhost:3000**

---

## Sample Questions to Try

| Question | Expected Result |
|----------|-----------------|
| List all employees | Table with 25 employees |
| How many employees in each department | Bar Chart |
| What is the average salary by department | Bar Chart |
| Show leave balances | Table with vacation/leave data |
| Show top 5 highest paid employees | Bar Chart |
| Employees hired after January 2023 | Filtered table |
| Count employees by status | Bar Chart |
| List employees with no phone number | Filtered table |

---

## API Endpoints

### Query Endpoint

```bash
POST /api/query
{
  "question": "How many employees in each department?",
  "db_type": "hr",
  "use_retry": true
}
```

### Profile Endpoints

```bash
# Get cached profile metadata
GET /api/profile

# Force refresh profile cache
POST /api/refresh-profile

# List available databases
GET /api/databases
```

### CLI Options

```bash
# Query with cached profile
python app.py "How many employees in each department?"

# Refresh profile cache
python app.py --refresh-profile

# Refresh cache and exit
python app.py --profile-only
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     User Interface                                  │
│                   (React + Chart.js)                                 │
│                      Port 3000                                      │
└─────────────────────────────────────────────────────────────────────┘
                            │
                            ▼ POST /api/query
┌─────────────────────────────────────────────────────────────────────┐
│                        FastAPI Backend                              │
│                     (backend/main.py)                               │
│                         Port 8000                                   │
├─────────────────────────────────────────────────────────────────────┤
│  1. Load Profile Cache    → Cached metadata from profiler.py        │
│  2. Filter by db_type    → Only relevant tables                     │
│  3. Format Schema        → Enriched schema with stats              │
│  4. NVIDIA LLM           → Generate SQL with few-shots             │
│  5. execute_sql()        → Run against PostgreSQL                   │
│  6. generate_summary()   → Create NL insights                      │
│  7. Retry Loop           → Fix errors (max 3x)                      │
└─────────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      PostgreSQL Database                            │
│                         (hr_db)                                    │
│                         Port 5432                                  │
└─────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. User enters natural language question
2. Backend loads cached profile metadata (or profiles fresh if needed)
3. Schema + user question + 5 few-shot examples → sent to NVIDIA LLM
4. LLM generates SQL query
5. SQL executes against PostgreSQL (hr_db)
6. Results returned with chart recommendations
7. Frontend displays table + auto-detected chart

---

## Database Profiling Layer

The system automatically extracts smart metadata from the database:

### What is Profiled

| Metric | Description |
|--------|-------------|
| **Null counts** | Percentage of NULL values per column |
| **Distinct values** | Number of unique values |
| **Sample values** | Top 5 most frequent values |
| **Min/Max** | Range for numeric and date columns |
| **Primary Keys** | Auto-detected from schema |
| **Foreign Keys** | Auto-detected relationships |

### Schema Format

The profiled schema includes rich metadata:

```sql
Table: employees (25 rows, 12 columns)
  - id: integer | non-null | 25 unique | PRIMARY KEY | sample: [1, 2, 3, 4, 5]
  - first_name: varchar | non-null | 25 unique | avg_len=5.2 | sample: ["John", "Jane", "Mike"]
  - department_id: integer | nullable (5% null) | 5 unique | FK→departments.id | sample: [1, 2, 3, 4, 5]
  - hire_date: date | non-null | 25 unique | range: [2020-01-15, 2024-06-30]
  - salary: numeric | nullable (8% null) | 20 unique | range: [30000, 150000]
```

### Caching

| Setting | Default | Environment Variable |
|---------|---------|---------------------|
| Cache TTL | 1 hour | `PROFILE_CACHE_TTL` |
| Cache file | `profile_cache.json` | `PROFILE_CACHE_FILE` |

Force refresh:
- API: `POST /api/refresh-profile`
- CLI: `python app.py --refresh-profile`

---

## Graph Auto-Detection

Chart.js automatically selects visualization based on result structure:

| Pattern | Graph Type |
|---------|------------|
| Date column + numeric values | Line Chart |
| Multiple numeric columns | Grouped Bar Chart |
| Single category + numeric (any size) | Bar Chart |
| Default | Bar Chart |

---

## Features Detail

### Conversation UI
- Messages accumulate (not replaced)
- Each query has numbered badge (1, 2, 3...)
- Message-specific graph toggle
- "New Question" button scrolls to input
- Clear Chat button to reset

### Natural Language Summary
- Aggregated statistics (total, average, min, max)
- Top item identification
- Contextual insights per query

### Database Profiling
- Automatic metadata extraction on startup
- Cached for performance (1 hour default)
- Includes null counts, distinct values, samples, min/max
- Auto-detects primary keys and foreign keys

### Retry Loop
- Automatically retries on SQL errors
- Analyzes error type (retryable vs non-retryable)
- Max 3 attempts per query
- Non-retryable: permission denied, connection failed

### Error Handling

| Error Type | Behavior |
|------------|----------|
| Table not found | Retry with LLM fix |
| Syntax error | Retry with fix |
| Permission denied | Stop, show error |
| Connection failed | Stop, show error |

---

## Troubleshooting

### Backend won't start
- Check PostgreSQL is running
- Verify `.env` credentials are correct
- Ensure NVIDIA API key is valid

### Frontend won't load
- Ensure backend is running on port 8000
- Check no other process uses port 3000

### Graph not displaying
- Data may not be suitable for visualization
- Try questions that return counts or aggregations

### Docker: Database not found

```bash
# Stop and reset volume
docker-compose down -v

# Restart
docker-compose up -d
```

### Docker: Permission denied
- Ensure `.env` has correct `DB_USER` and `DB_PASSWORD`

### Refresh profile cache

```bash
# Via API
curl -X POST http://localhost:8000/api/refresh-profile

# Via CLI
docker exec -it nl2sql-backend python app.py --refresh-profile
```

---

## Files Overview

| File | Description |
|------|-------------|
| `sql_prompt.py` | NL→SQL prompt: few-shots (5), dialect hints, profiled schema support |
| `profiler.py` | Database profiling with caching, FK detection, stats extraction |
| `hr_schema.sql` | HR database schema (17 tables) |
| `hr_examples.py` | Few-shot examples (5 diverse patterns) |
| `backend/main.py` | FastAPI server with NL2SQL pipeline, profile endpoints |
| `frontend/src/App.jsx` | React UI with Chart.js |
| `app.py` | CLI alternative with LangGraph |
| `.env` | Database and API credentials |

---

## Quick Reference Commands

```bash
# Start locally (need PostgreSQL running)
cd backend && python main.py  # Terminal 1
cd frontend && npm run dev    # Terminal 2

# Start with Docker
docker-compose up --build

# Reset Docker database
docker-compose down -v
docker-compose up -d

# Verify API
curl http://localhost:8000/

# Check database tables
docker exec -it nl2sql-db psql -U postgres -d hr_db -c "\dt"

# Refresh profile cache
curl -X POST http://localhost:8000/api/refresh-profile

# View profile metadata
curl http://localhost:8000/api/profile | jq
```

---

## License

Private Project
