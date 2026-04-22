# NL2SQL

Natural-language to SQL assistant with a React chat UI, FastAPI backend, PostgreSQL database, and OpenRouter-based LLM generation.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Tech Stack](#tech-stack)
3. [Architecture & How It Works](#architecture--how-it-works)
4. [Model Configuration](#model-configuration)
5. [Adding a New Database](#adding-a-new-database)
6. [Adding Schema & Tables](#adding-schema--tables)
7. [Database Schema Examples](#database-schema-examples)
8. [API Reference](#api-reference)
9. [CLI Usage](#cli-usage)
10. [Troubleshooting](#troubleshooting)

---

## Project Overview

NL2SQL converts natural language questions into SQL queries and executes them against PostgreSQL databases. It features:

- **Multi-database support**: Configure multiple databases in `databases.json`
- **Smart profiling**: Automatic table/column analysis with sample values
- **JSONB handling**: Extract keys from JSON columns when explicitly requested
- **Schema linking**: Two-pass SQL validation
- **Auto-retry**: Fix SQL errors automatically (up to 3 attempts)
- **Chart recommendations**: Automatic visualization hints

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | React 18, Vite, Axios, TailwindCSS |
| Backend | FastAPI, Uvicorn, LangGraph |
| LLM | OpenRouter via `langchain-openai` |
| Database | PostgreSQL 16 |
| Infra | Docker Compose |

---

## Architecture & How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                      Frontend (React)                         │
│                   http://localhost:3001                      │
└──────────────────────┬────────────────────────────────────────┘
                       │
                       │ POST /api/query { question, db_id }
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend (FastAPI)                          │
│                   http://localhost:8000                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  fetch_env  │─▶│ generate_sql │─▶│ execute_sql │       │
│  │  (LangGraph) │  │             │  │             │       │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
│        │                 │                 │                    │
│        ▼                 ▼                 ▼                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  profiler  │  │ sql_prompt │  │  validator │       │
│  │            │  │            │  │            │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└──────────────────────┬────────────────────────────────────────┘
                       │
                       │ psycopg2
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│               PostgreSQL (Docker: nl2sql-db)                   │
│                    localhost:5432                              │
└─────────────────────────────────────────────────────────────────┘
```

### Pipeline Flow

1. **Frontend loads** databases from `GET /api/databases`
2. **User selects DB** and sends question to `POST /api/query`
3. **Backend resolves** `db_id` and builds pipeline state
4. **LangGraph executes**:
   - **fetch_schema**: Load/refresh profile cache, format profiled schema
   - **generate_sql**: Build prompt, call LLM, schema linking, validate SQL
   - **execute_sql**: Run SELECT, retry on error, generate summary/chart hint
5. **Response**: Returns SQL, columns, data, summary, chart spec

---

## Model Configuration

### Environment Variables (`.env`)

```bash
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=hr_db
DB_USER=newpage
DB_PASSWORD=postgres

# OpenRouter LLM Configuration
LLM_MODEL=qwen/qwen3-235b-a22b-2507
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
OPENAI_API_KEY=sk-or-v1-...  # Required: your OpenRouter API key
LLM_TEMPERATURE=0.2
LLM_MAX_TOKENS=1024

# Cache Settings
PROFILE_CACHE_TTL=3600
PROFILE_CACHE_DIR=profile_cache
```

### Available Models

Popular OpenRouter models:

| Model | Context | Best For |
|-------|---------|---------|
| `qwen/qwen3-235b-a22b-2507` | 32K | Large schemas, complex queries |
| `meta-llama/llama-3.3-70b-instruct` | 8K | Balanced performance |
| `openai/gpt-4o` | 128K | Best accuracy, higher cost |
| `google/gemini-2.0-flash-exp` | 1M | Fast, large context |

### Switching Models

Edit `LLM_MODEL` in `.env`:

```bash
LLM_MODEL=meta-llama/llama-3.3-70b-instruct
```

Or set via environment variable at runtime:

```bash
LLM_MODEL=openai/gpt-4o python app.py --db-id hr "Show employees"
```

---

## Adding a New Database

### Step 1: Edit `databases.json`

Add a new entry to `databases.json`:

```json
{
  "hr": {
    "label": "HR Database",
    "host": "db",
    "port": 5432,
    "dbname": "hr_db",
    "user": "${DB_USER}",
    "password": "${DB_PASSWORD}"
  },
  "my_database": {
    "label": "My Custom Database",
    "host": "db",
    "port": 5432,
    "dbname": "my_db",
    "user": "${DB_USER}",
    "password": "${DB_PASSWORD}"
  }
}
```

### Connection Hosts

| Environment | Host Value | Example |
|-------------|-----------|---------|
| Docker compose | `"db"` | Backend container resolves to PostgreSQL |
| Local development | `"localhost"` | Direct connection to local PostgreSQL |

### Step 2: Add Init SQL Files

Create SQL files in `docker/db/init/`:

```
docker/db/init/
├── 01-create-my_db.sql      # Create database (optional)
├── NN-my_schema.sql         # Schema + tables
└── NN-my_data.sql          # Seed data
```

### Step 3: Update `docker-compose.yml`

Add volume mounts for your SQL files:

```yaml
services:
  db:
    volumes:
      # Existing
      - ./docker/db/init/02-hr_schema.sql:/docker-entrypoint-initdb.d/02-hr_schema.sql:ro
      # New database
      - ./docker/db/init/01-create-my_db.sql:/docker-entrypoint-initdb.d/01-create-my_db.sql:ro
      - ./docker/db/init/03-my_schema.sql:/docker-entrypoint-initdb.d/03-my_schema.sql:ro
      - ./docker/db/init/04-my_data.sql:/docker-entrypoint-initdb.d/04-my_data.sql:ro
```

### File Naming Convention

- `01-create-{dbname}.sql` - Create database if needed
- Schema files run alphabetically; use prefix `02-`, `03-`, etc.
- Init scripts run in lexicographic order

### Environment Variable Placeholders

Use `${VAR_NAME}` in `databases.json`:

```json
{
  "db": {
    "user": "${DB_USER}",
    "password": "${DB_PASSWORD}"
  }
}
```

Variables are resolved from the process environment at runtime.

---

## Adding Schema & Tables

### Step 1: Create Schema SQL File

```sql
-- docker/db/init/03-my_schema.sql
-- My Custom Schema

DROP SCHEMA IF EXISTS myschema CASCADE;
CREATE SCHEMA myschema;
SET search_path TO myschema, public;

-- Companies table
CREATE TABLE companies (
    company_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    industry TEXT,
    founded_year INTEGER,
    metadata JSONB  -- JSONB column
);

-- Employees table with foreign key
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT UNIQUE,
    company_id INTEGER REFERENCES companies(company_id),
    hire_date DATE,
    profile JSONB  -- JSONB: {skills: [], certifications: [], emergency_contact: {}}
);

-- Indexes
CREATE INDEX idx_employees_company ON employees(company_id);
CREATE INDEX idx_employees_email ON employees(email);

-- JSONB GIN index for efficient querying
CREATE INDEX idx_employees_profile ON employees USING GIN(profile);
```

### Key Points

1. **Use unique prefix**: `03-` ensures it runs after `01-` / `02-` files
2. **JSONB columns**: Use `JSONB` type for flexible structured data
3. **GIN indexes**: Create `USING GIN(column)` for JSONB query optimization
4. **Foreign keys**: Reference other tables with `REFERENCES table(col)`

### Step 2: Create Seed Data

```sql
-- docker/db/init/04-my_data.sql

-- Insert companies
INSERT INTO companies (name, industry, founded_year, metadata) VALUES
('Acme Corp', 'Technology', 2020, '{"headquarters": "NYC", "employees": 500}'),
('Beta Inc', 'Healthcare', 2018, '{"headquarters": "Boston", "employees": 200}')
ON CONFLICT DO NOTHING;

-- Generate 100 employees using generate_series
INSERT INTO employees (first_name, last_name, email, company_id, hire_date, profile)
SELECT
    'Employee_' || i,
    'Lastname_' || i,
    'emp' || i || '@acme.com',
    (i % 2) + 1,
    '2020-01-01'::date + (random() * 1000)::int,
    jsonb_build_object(
        'skills', ARRAY['Python', 'SQL'],
        'certifications', ARRAY['AWS'],
        'emergency_contact', jsonb_build_object('name', 'Contact ' || i, 'phone', '555-' || i)
    )
FROM generate_series(1, 100) i
ON CONFLICT DO NOTHING;
```

### Using `generate_series` for Test Data

Generate multiple rows efficiently:

```sql
-- 50 companies
INSERT INTO companies (name, industry, founded_year)
SELECT
    'Company_' || i,
    (ARRAY['Tech', 'Healthcare', 'Finance', 'Retail'])[floor(random()*4)+1],
    2000 + floor(random()*25)
FROM generate_series(1, 50) i;

-- 500 employees
INSERT INTO employees (first_name, last_name, company_id, profile)
SELECT
    'First_' || i,
    'Last_' || i,
    floor(random()*50)+1,
    jsonb_build_object('skills', ARRAY[(ARRAY['SQL', 'Python', 'Java'])[floor(random()*3)+1]])
FROM generate_series(1, 500) i;
```

### Step 3: Add Database Entry

```json
// databases.json
{
  "my_database": {
    "label": "My Custom Database",
    "host": "db",
    "port": 5432,
    "dbname": "my_db",
    "user": "${DB_USER}",
    "password": "${DB_PASSWORD}"
  }
}
```

### Step 4: Rebuild Database

```bash
# Stop, remove volume, rebuild
docker compose down -v
docker compose up --build

# Or connect directly to recreate
psql -h localhost -U postgres -d my_db -f docker/db/init/03-my_schema.sql
```

---

## Database Schema Examples

### HR Database

Available databases include `hr`:

| Table | Description | Rows |
|-------|------------|------|
| `hr.departments` | Company departments | 10 |
| `hr.jobs` | Job titles/levels | 40 |
| `hr.employees` | Employee records | 100 |
| `hr.salaries` | Salary history | 500+ |
| `hr.bonuses` | Annual bonuses | 100 |

### Pharma Database (JSONB Testing)

The Pharma database is designed for testing JSONB functionality:

| Table | JSONB Columns |
|-------|--------------|
| `manufacturers` | `certifications`, `facility_details`, `quality_standards` |
| `drugs` | `active_ingredients`, `inactive_ingredients`, `warnings`, `storage_requirements`, `contraindications`, `dosage_guidelines` |
| `patients` | `medical_history`, `emergency_contact`, `allergies`, `preferred_pharmacy`, `payment_method` |
| `doctors` | `specializations`, `availability`, `contact_preferences`, `credentials`, `practice_details` |
| `pharmacies` | `operating_hours`, `services`, `contact_info`, `accepted_insurance`, `delivery_zones` |
| `insurance_plans` | `coverage_details`, `prior_auth_requirements`, `network_info`, `formulary`, `plan_exclusions` |
| `prescriptions` | `prescriber_notes`, `patient_instructions`, `fill_history`, `authorization_details`, `interaction_check` |
| `prescription_items` | `dispense_notes`, `substitution_history`, `inventory_allocation` |
| `claims` | `claim_data`, `adjustment_notes`, `appeal_details`, `reimbursement_details` |
| `clinical_trials` | `inclusion_criteria_jsonb`, `exclusion_criteria_jsonb`, `sites`, `endpoints`, `arm_details`, `enrollment_data`, `safety_data`, `study_results` |
| `adverse_events` | `event_description`, `patient_narrative`, `severity_assessment`, `investigation_notes`, `regulatory_reporting`, `relatedness` |
| `inventories` | `stock_alerts`, `supplier_info`, `tracking_details`, `pricing_adjustments` |
| `sales` | `transaction_metadata`, `payment_details`, `loyalty_points`, `receipt_details`, `return_info` |
| `drug_interactions` | `interaction_severity`, `mechanism_of_action`, `clinical_guidance`, `literature_references`, `patient_education` |
| `patient_visits` | `vital_signs`, `chief_complaints`, `assessment_notes`, `follow_up_plan`, `prescriptions_written`, `lab_results`, `billing_details` |

**Statistics**:
- 15 tables
- 40+ JSONB columns
- ~1300+ rows of test data
- Comprehensive healthcare/pharmacy domain

### Sample JSONB Queries

```sql
-- Get patients with specific drug allergy
SELECT first_name, last_name, allergies
FROM patients
WHERE allergies->>'drug_allergies' @> '["Penicillin"]'::jsonb;

-- Find drugs with specific active ingredient
SELECT brand_name, active_ingredients
FROM drugs
WHERE active_ingredients @> '[{"name": "Atorvastatin"}]'::jsonb;

-- Extract specific JSON field
SELECT
    first_name,
    emergency_contact->>'phone' as emergency_phone
FROM patients;
```

---

## API Reference

### `GET /api/databases`

Returns configured database list.

```bash
curl http://localhost:8000/api/databases
```

Response:
```json
{
  "databases": [
    { "id": "hr", "name": "HR Database", "dbname": "hr_db", "host": "db" },
    { "id": "pharma", "name": "Pharma Database", "dbname": "pharma_db", "host": "db" }
  ]
}
```

### `GET /api/databases/{db_id}/schemas`

Returns discovered schemas for a database.

```bash
curl http://localhost:8000/api/databases/hr/schemas
```

Response:
```json
{
  "db_id": "hr",
  "schemas": ["hr", "public"]
}
```

### `GET /api/profile?db_id={db_id}`

Returns profile metadata cache stats.

```bash
curl "http://localhost:8000/api/profile?db_id=hr"
```

Response:
```json
{
  "db_id": "hr",
  "generated_at": "2025-04-22T10:30:00",
  "expires_in_seconds": 3600,
  "table_count": 5,
  "tables": ["hr.departments", "hr.employees", "hr.jobs", "hr.salaries", "hr.bonuses"],
  "row_counts": { "hr.departments": 10, "hr.employees": 100 }
}
```

### `POST /api/refresh-profile`

Force refresh the profile cache.

```bash
curl -X POST http://localhost:8000/api/refresh-profile \
  -H "Content-Type: application/json" \
  -d '{ "db_id": "hr" }'
```

Response:
```json
{
  "status": "refreshed",
  "db_id": "hr",
  "table_count": 5,
  "generated_at": "2025-04-22T10:35:00"
}
```

### `POST /api/query`

Execute a natural language query.

```bash
curl -X POST http://localhost:8000/api/query \
  -H "Content-Type: application/json" \
  -d '{
    "question": "How many employees are in each department?",
    "db_id": "hr"
  }'
```

Response:
```json
{
  "sql_query": "SELECT ...",
  "columns": ["department", "count"],
  "data": [
    { "department": "Engineering", "count": 25 },
    { "department": "Sales", "count": 30 }
  ],
  "summary": "Found 4 departments with employees.",
  "graph_hint": "auto",
  "graph_spec": {
    "chart_type": "bar",
    "x_key": "department",
    "y_keys": ["count"]
  }
}
```

### `POST /api/query/stream`

Stream query progress with SSE.

```bash
curl -X POST http://localhost:8000/api/query/stream \
  -H "Content-Type: application/json" \
  -d '{
    "question": "Show top 5 employees by salary",
    "db_id": "hr"
  }'
```

Progress events:
```
event: progress
data: {"step_id": "schema_profile_loaded", "label": "Schema/profile loaded", "status": "completed"}

event: progress
data: {"step_id": "sql_drafted", "label": "SQL drafted", "status": "completed"}

event: result
data: {"sql_query": "...", "columns": [...], "data": [...]}
```

---

## CLI Usage

Use `app.py` for command-line queries:

```bash
python app.py --db-id hr "Show top 5 employees by salary"
```

### Flags

| Flag | Description |
|------|-------------|
| `--db-id <id>` | Database ID (required) |
| `--refresh-profile` | Force refresh profile cache |
| `--profile-only` | Show profile without querying |

### Examples

```bash
# Basic query
python app.py --db-id hr "Total employees per department"

# With profile refresh
python app.py --db-id pharma --refresh-profile "Show patients with allergies"

# Show only schema profile
python app.py --db-id hr --profile-only
```

---

## Troubleshooting

### Database Connection Issues

**Error**: `pg_isready: could not connect to server`

```bash
# Check if PostgreSQL is running
docker compose ps

# Restart database
docker compose restart db
```

### `/api/query` Fails

**Error**: Connection refused to database

- Verify `databases.json` host is `"db"` (Docker) or `"localhost"` (local)
- Check `databases.json` has correct `dbname`
- Ensure credentials in `.env` match PostgreSQL user

### Profile Cache Issues

**Problem**: Schema not updating

```bash
# Force refresh
curl -X POST http://localhost:8000/api/refresh-profile \
  -H "Content-Type: application/json" \
  -d '{ "db_id": "your_db" }'
```

Or use CLI:
```bash
python app.py --db-id your_db --refresh-profile "query"
```

### Viewing Logs

```bash
# Backend logs
docker compose logs -f backend

# Database logs
docker compose logs -f db

# All services
docker compose logs -f
```

### Accessing PostgreSQL Directly

```bash
# Connect to database
docker compose exec db psql -U postgres -d hr_db

# List tables
docker compose exec db psql -U postgres -d hr_db -c "\dt"

# Query directly
docker compose exec db psql -U postgres -d hr_db -c "SELECT COUNT(*) FROM hr.employees"
```

---

## Runtime Structure

```
NL2SQL/
├── app.py                        # CLI entry point
├── backend/
│   ├── main.py                  # FastAPI app
│   └── core/
│       ├── db_registry.py        # DB registry + connections
│       ├── nl2sql_pipeline.py  # LangGraph pipeline
│       ├── profiler.py          # DB profiling + cache
│       ├── schema_linker.py     # Two-pass linking
│       ├── sql_prompt.py     # Prompt builder
│       └── validator.py      # SQL validation
├── frontend/
│   └── src/App.jsx             # React chat UI
├── docker-compose.yml
├── databases.json               # DB registry (gitignored)
├── .env                     # Environment (gitignored)
└── docker/db/init/          # SQL init scripts
    ├── 02-hr_schema.sql
    └── pharma_schema.sql
```

---

## Running the Project

### Docker (Recommended)

```bash
docker compose up --build
```

Services:
- Frontend: `http://localhost:3001`
- Backend: `http://localhost:8000`
- PostgreSQL: `localhost:5432`

### Local Development

**Backend**:
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
uvicorn backend.main:app --reload --port 8000
```

**Frontend**:
```bash
cd frontend
npm install
npm run dev
```

### Configuration

1. Copy environment template:
   ```bash
   cp .env.example .env
   ```

2. Create database registry:
   ```bash
   cp databases.example.json databases.json
   ```

3. Update credentials in `.env` and `databases.json`

---

## License

Private project.