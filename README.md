# NL2SQL

Natural-language to SQL assistant with a React chat UI, FastAPI backend, PostgreSQL data source, and OpenRouter-based LLM generation.

## Project Analysis (Current State)

- **Architecture is now unified**: both API and CLI use the same shared pipeline in `backend/core/nl2sql_pipeline.py`.
- **Multi-database flow is active**: database options come from `databases.json` through `backend/core/db_registry.py`, and users can select DBs in the UI.
- **Schema discovery is dynamic**: PostgreSQL schemas are discovered automatically and applied to `search_path` per selected database.
- **Core runtime is cleanly separated**: production modules are under `backend/core`; optional modules were moved to `legacy/experimental`.
- **Some legacy docs drift existed**: old README sections referenced removed modules/endpoints and outdated payload fields (`db_type`); this README fixes that.

## Tech Stack

- **Frontend**: React 18, Vite, Axios, TailwindCSS
- **Backend**: FastAPI, Uvicorn, LangGraph
- **LLM**: OpenRouter via `langchain-openai` (`ChatOpenAI`)
- **Database**: PostgreSQL 16
- **Infra**: Docker Compose

## Runtime Structure

```text
NL2SQL/
├── app.py                        # CLI entry point (uses shared pipeline)
├── backend/
│   ├── main.py                   # FastAPI app and API routes
│   ├── requirements.txt
│   └── core/
│       ├── db_registry.py        # DB registry + schema discovery + connections
│       ├── nl2sql_pipeline.py    # LangGraph pipeline (fetch_schema -> generate -> execute)
│       ├── profiler.py           # DB profiling + cache
│       ├── schema_linker.py      # Two-pass schema linking
│       ├── sql_prompt.py         # Prompt builder
│       ├── validator.py          # SQL validation/autofix
│       └── hr_examples.py        # Few-shot examples
├── frontend/
│   ├── src/App.jsx               # Chat app + DB selector
│   └── src/components/ChatMessage.jsx
├── docker-compose.yml
├── databases.example.json
├── databases.json                # local DB registry (gitignored)
├── docker/db/init/02-hr_schema.sql
└── legacy/
    ├── data/                     # archived SQL/data assets
    └── experimental/             # optional non-runtime modules
```

## How It Works

1. Frontend loads databases from `GET /api/databases`.
2. User chooses a database and sends a question to `POST /api/query`.
3. Backend resolves `db_id` and loads/refreshes profile cache for that database.
4. Shared pipeline runs:
   - fetch schema/profile context
   - generate SQL (with prompt + schema linking + validator)
   - execute SQL with retry logic (SELECT only)
5. Response returns SQL, tabular results, and summary text.

## Prerequisites

- Docker + Docker Compose (recommended)
- Or local: Python 3.11+ and Node 18+
- OpenRouter API key

## Configuration

1. Copy environment template:

```bash
cp .env.example .env
```

2. Create database registry file:

```bash
cp databases.example.json databases.json
```

3. Update credentials:

- `.env` contains shared DB creds and model settings.
- `databases.json` maps logical DB IDs (`hr`, `sales`, etc.) to actual PostgreSQL connections.

### Important Env Notes

- Backend currently reads API key from `OPENAI_API_KEY`.
- Keep `DATABASES_CONFIG` pointing to your registry file (Docker uses `/app/databases.json`).

## Run with Docker (Recommended)

```bash
docker compose up --build
```

Services:

- Frontend: `http://localhost:3001`
- Backend: `http://localhost:8000`
- PostgreSQL: `localhost:5432`

## Local Development

### Backend

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
uvicorn backend.main:app --reload --port 8000
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

## API Reference

### `GET /api/databases`

Returns configured DB list for UI selector.

### `GET /api/databases/{db_id}/schemas`

Returns discovered schemas for the selected DB.

### `GET /api/profile?db_id=...`

Returns profile metadata/cache stats for one DB.

### `POST /api/refresh-profile`

Request body:

```json
{ "db_id": "hr" }
```

### `POST /api/query`

Request body:

```json
{ "question": "How many employees are in each department?", "db_id": "hr" }
```

Response shape:

```json
{
  "sql_query": "SELECT ...",
  "columns": ["col1", "col2"],
  "data": [{ "col1": "v1", "col2": "v2" }],
  "summary": "Found 10 records.",
  "graph_hint": "auto"
}
```

## CLI Usage

`app.py` uses the same backend pipeline:

```bash
python app.py --db-id hr "Show top 5 employees by salary"
```

Useful flags:

- `--refresh-profile`
- `--profile-only`
- `--db-id <id>`

## Troubleshooting

- If `/api/databases` works but `/api/query` fails, verify `databases.json` host values (`db` for Docker network, not `localhost` inside backend container).
- If backend cannot start, confirm `databases.json` exists and `DATABASES_CONFIG` points to it.
- For container logs:

```bash
docker compose logs -f backend
```

## License

Private project.
