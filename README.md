# NL2SQL - Natural Language to SQL Converter (HR Database)

A full-stack application that converts natural language questions into SQL queries with interactive visualizations. Uses React, FastAPI, PostgreSQL (HR Database), and Groq LLM.

---

## Features

- **Natural Language to SQL**: Ask questions in plain English, get SQL results
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
- Groq API Key (free at https://console.groq.com)

---

## Project Structure

```
NL2SQL/
├── app.py                     # CLI pipeline with LangGraph
├── sql_prompt.py              # Shared NL→SQL prompt builder
├── hr_schema.sql            # HR Database schema (17 tables)
├── hr_examples.py           # Few-shot examples for HR queries
├── backend/
│   ├── main.py             # FastAPI server
│   └── requirements.txt    # Python dependencies
├── frontend/
│   ├── src/
│   │   ├── App.jsx         # Main React component
│   │   ├── components/    # UI components
│   │   └── index.css       # Tailwind styles
│   └── package.json       # Node dependencies
├── docker-compose.yml      # Docker full stack
├── docker/
│   └── db/init/
│       └── 02-hr_schema.sql  # HR schema for Docker
└── .env.example           # Environment template

Legacy files (previous version):
├── school_data.sql         # School database schema
├── README.md              # Previous version documentation
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
GROQ_API_KEY=your_groq_api_key
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

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     User Interface                     │
│                   (React + Chart.js)                │
│                      Port 3000                      │
└─────────────────────────────────────────────────────┘
                           │
                           ▼ POST /api/query
┌─────────────────────────────────────────────────────┐
│                   FastAPI Backend                     │
│                (backend/main.py)                   │
│                      Port 8000                     │
├─────────────────────────────────────────────────────┤
│  1. fetch_schema()     → Query information_schema  │
│  2. build_prompt()      → Combine schema + Q      │
│  3. Groq LLM            → Generate SQL           │
│  4. execute_sql()      → Run against PostgreSQL │
│  5. generate_summary() → Create NL insights     │
│  6. Retry Loop         → Fix errors (max 3x)     │
└─────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────┐
│                  PostgreSQL Database               │
│                     (hr_db)                       │
│                     Port 5432                     │
└─────────────────────────────────────────────────────┘
```

### Data Flow

1. User enters natural language question
2. Backend fetches database schema from `information_schema`
3. Schema + user question + examples → sent to Groq LLM
4. LLM generates SQL query
5. SQL executes against PostgreSQL (hr_db)
6. Results returned with chart recommendations
7. Frontend displays table + auto-detected chart

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
- Ensure Groq API key is valid

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

---


## Files Overview

| File | Description |
|------|-------------|
| `sql_prompt.py` | NL→SQL prompt: few-shots, dialect hints |
| `hr_schema.sql` | HR database schema (17 tables) |
| `hr_examples.py` | Programmatic few-shot examples |
| `backend/main.py` | FastAPI server with NL2SQL pipeline |
| `frontend/src/App.jsx` | React UI with Chart.js |
| `app.py` | CLI alternative with LangGraph |
| `.env` | Database and API credentials |

---

## Legacy: School Database (Previous Version)

The original project used a **School Database** with tables like `students`, `teachers`, `courses`, etc.

**If you need to switch back:**

1. Update `docker-compose.yml`:
```yaml
POSTGRES_DB: ${DB_NAME:-school_db}
volumes:
  - ./docker/db/init/01-school_data.sql:/docker-entrypoint-initdb.d/01-school_data.sql:ro
```

2. Restart Docker:
```bash
docker-compose down -v
docker-compose up -d
```

**Previous sample questions:**
- "List all students"
- "How many students are in each grade?"
- "Count of students by attendance status"

---

## Credits

- **React** - UI Framework
- **Chart.js** - Visualization (via react-chartjs-2)
- **FastAPI** - Backend API
- **LangGraph** - Workflow orchestration (CLI)
- **Groq** - LLM for SQL generation
- **psycopg2** - PostgreSQL connectivity
- **Tailwind CSS** - Styling
- **Docker** - Containerization

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
```

---

## License
 
Private Project