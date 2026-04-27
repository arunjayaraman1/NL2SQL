# NL2SQL — End-to-End System Analysis

## Project Structure

```
/NL2SQL/
├── app.py                              # CLI entry point
├── backend/
│   ├── main.py                         # FastAPI application (481 lines)
│   └── core/
│       ├── nl2sql_pipeline.py          # LangGraph pipeline orchestration (685 lines)
│       ├── profiler.py                 # Database schema profiling & caching (709 lines)
│       ├── schema_linker.py            # Two-pass schema linking (295 lines)
│       ├── sql_prompt.py               # Prompt builders for LLM (333 lines)
│       ├── validator.py                # SQL validation & intent detection (507 lines)
│       ├── graph_spec.py               # Chart recommendation logic (165 lines)
│       ├── db_registry.py              # Multi-database config & connections (206 lines)
│       └── hr_examples.py              # Few-shot examples for prompting
├── frontend/src/
│   ├── App.jsx                         # Main React chat interface (367 lines)
│   └── components/ChatMessage.jsx      # Message rendering & charts (370+ lines)
├── docker/db/init/                     # SQL initialization scripts
│   ├── 02-hr_schema.sql
│   ├── pharma_schema.sql               # Contains JSONB columns
│   ├── medical_schema.sql
│   └── amazon_marketplace.sql
├── docker-compose.yml
├── databases.json                      # Database registry
└── .env                                # Secrets (OpenRouter API key, DB creds)
```

---

## API Routes (backend/main.py)

| Route | Method | Purpose |
|-------|--------|---------|
| `/api/databases` | GET | List configured databases |
| `/api/databases/{db_id}/schemas` | GET | Get schemas for a database |
| `/api/profile?db_id=X` | GET | Get profile cache metadata |
| `/api/suggestions?db_id=X` | GET | Get sample query suggestions |
| `/api/refresh-profile` | POST | Force rebuild profile cache |
| `/api/query` | POST | Execute query (non-streaming) |
| `/api/query/stream` | POST | Execute query with SSE streaming |

### SSE Streaming Pattern

The `/api/query/stream` endpoint:
1. Creates an inter-thread `Queue`
2. Spawns a worker thread that runs the pipeline and pushes `progress` events
3. Main thread reads from queue and emits SSE events:
   - `event: progress\ndata: {"step_id": "...", "label": "...", "status": "completed"}`
   - `event: result\ndata: {...full response...}`
   - `event: error\ndata: {...}`

---

## LangGraph Pipeline (nl2sql_pipeline.py)

### GraphState Fields

```python
class GraphState(TypedDict, total=False):
    # Input
    question: str
    db_id: str
    llm_builder: Callable[[], Any]      # Factory returning ChatOpenAI instance

    # Intermediate
    schema: str                          # Formatted schema text for LLM
    sql_query: str                       # Generated SQL
    iteration: int                       # Retry counter (max 3)
    error: str

    # Output
    result: str
    columns: list[str]
    data: list[dict]
    summary: str
    graph_hint: str                      # "auto" or "none"
    graph_spec: dict[str, Any]          # {chart_type, x_key, y_keys}

    # Classification
    is_query: bool
    conversation_response: str

    # Config
    profile_cache: Optional[ProfileCache]
    force_refresh: bool
    cache_path: Optional[str]
    progress_callback: Optional[ProgressCallback]
```

### DAG Structure

```
         classify_input
         /             \
   (is_query)      (conversation)
        |                |
  fetch_schema    respond_conversation
        |                |
  generate_sql           |
        |                |
  execute_sql            |
         \              /
               END
```

### Node Summary

| Node | Purpose | Progress Event Emitted |
|------|---------|----------------------|
| `classify_input` | LLM classifies: database query vs chat | — |
| `respond_conversation` | Handle greetings/help messages | `conversation_response` |
| `fetch_schema` | Load/build profile cache, format schema | `schema_profile_loaded` |
| `generate_sql` | Two-pass SQL generation + validation | `sql_drafted`, `schema_linking_complete`, `sql_validated` |
| `execute_sql` | Run SQL with retry, generate summary+chart | `query_executed`, `summary_generated`, `chart_recommendation_generated` |

---

## Schema Profiling & Caching (profiler.py)

### What Gets Profiled Per Column

```
ProfileColumn:
  name, data_type
  total_count, null_count, null_percentage
  distinct_count
  samples          — top 5 most frequent values
  min_value, max_value   — numeric/date columns only
  avg_length       — text columns only
  is_primary_key, foreign_key
  is_json_type     — True if data_type contains "json"
  json_keys        — auto-extracted top-level JSONB keys
```

### Cache Invalidation

```python
# MD5 hash of current schema layout
current_hash = get_database_hash(conn)

# Cache is valid if hash matches AND not expired (default 1hr)
if cached.database_hash == current_hash and not expired:
    return cached  # Cache hit
```

Cache stored at: `profile_cache/{db_id}.json`

### Schema Formatted for LLM

```
Table: hr.employees (100 rows, 8 columns)
  - id: integer | non-null | 100 unique | PRIMARY KEY | sample: [1, 2, 3] | range: [1, 100]
  - name: text | non-null | 98 unique | sample: ['Alice', 'Bob'] | avg_len=12.5
  - department_id: integer | FK→hr.departments.id | 10 unique | sample: [1, 2, 3]
  - medical_history: jsonb | nullable (5% null) | JSON keys: [conditions, surgeries] | sample: [...]
```

---

## Standard (Non-JSONB) Query Path

### Full Step-by-Step Example: "How many employees per department?"

**Step 1 — classify_input:**
- LLM prompt: `Classify as "query" or "conversation". Input: "How many employees per department?"`
- LLM output: `"query"`
- Result: `is_query = True` → routes to `fetch_schema`

**Step 2 — fetch_schema:**
- Calls `get_connection(db_id)` via `db_registry`
- Calls `profile_database(conn)` — returns cached or freshly-built `ProfileCache`
- Calls `format_profiled_schema(cache)` → sets `state["schema"]`
- Emits: `schema_profile_loaded`

**Step 3 — generate_sql:**

JSONB detection:
```python
jsonb_enabled = _should_enable_jsonb_querying(profile_cache)
# → False (no JSON columns in HR database)
```

Pass 1 — SQL generation:
```python
prompt = build_profiled_schema_prompt(profile_cache, question, enable_jsonb_querying=False)
initial_sql = llm.invoke(prompt)
# → "SELECT d.name, COUNT(e.id) FROM employees e JOIN departments d ON e.department_id = d.id GROUP BY d.name"
```
Emits: `sql_drafted`

Pass 2 — Schema linking:
```python
filtered_schema, used_tables = link_schema(initial_sql, profile_cache)
# used_tables = {"employees", "departments"}
# filtered_schema = only employees + departments tables
```
Emits: `schema_linking_complete`

Pass 2 — Refinement:
```python
refined_prompt = build_two_pass_prompt(initial_sql, filtered_schema, question)
sql = llm.invoke(refined_prompt)
# → "SELECT d.name, COUNT(e.id) AS employee_count FROM employees e JOIN departments d ON e.department_id = d.id GROUP BY d.name ORDER BY employee_count DESC"
```

Validation:
```python
result = validate_sql(sql, question)
# Detected intents: ["aggregation", "joining", "ordering"]
# Checks: GROUP BY ✓, JOIN ✓, ORDER BY ✓
# Auto-fixes if needed
```
Emits: `sql_validated`

**Step 4 — execute_sql:**

```python
cursor.execute(sql)
rows = cursor.fetchall()
columns = [desc[0] for desc in cursor.description]  # ["name", "employee_count"]
data = [dict(zip(columns, row)) for row in rows]
# [{"name": "Engineering", "employee_count": 30}, {"name": "Sales", "employee_count": 25}, ...]
```
Emits: `query_executed`

Combined summary + chart (single LLM call):
```python
summary, graph_spec = generate_summary_and_graph_spec(state, question, columns, data)
# summary: "There are 4 departments with 100 employees total. Engineering has the most with 30."
# graph_spec: {"chart_type": "bar", "x_key": "name", "y_keys": ["employee_count"], "source": "llm"}
```
Emits: `summary_generated`, `chart_recommendation_generated`

**Final Response:**
```json
{
  "response_type": "query",
  "sql_query": "SELECT d.name, COUNT(e.id) AS employee_count ...",
  "columns": ["name", "employee_count"],
  "data": [{"name": "Engineering", "employee_count": 30}, ...],
  "summary": "There are 4 departments with 100 employees total...",
  "graph_hint": "auto",
  "graph_spec": {"chart_type": "bar", "x_key": "name", "y_keys": ["employee_count"]}
}
```

---

## JSONB Query Path

### Detection

```python
def _should_enable_jsonb_querying(profile_cache) -> bool:
    for table in profile_cache.tables.values():
        for column in table.columns.values():
            if "json" in str(column.data_type).lower():
                return True
    return False
```

Returns `True` if **any** column in **any** table has `jsonb` or `json` data type.

### JSONB Auto-Discovery (profiler.py)

During profiling, JSONB columns get their top-level keys extracted from sample values:

```python
is_json = _is_json_type(data_type)          # "json" in data_type.lower()
if is_json and samples:
    json_keys = _extract_json_keys(samples[:10])   # Parse top-level keys
```

This feeds into the schema text shown to the LLM:
```
- allergies: jsonb | nullable (2% null) | JSON keys: [drug_allergies, food_allergies, environmental_allergies, severity]
- medical_history: jsonb | nullable (3% null) | JSON keys: [conditions, surgeries, family_history, current_medications]
```

### JSONB Prompt Injection (sql_prompt.py)

When `enable_jsonb_querying=True`, this block is appended to the prompt:

```
PostgreSQL JSONB hints for nested JSON and arrays:

NESTED JSON ACCESS:
- Use column->'key' to extract nested values (returns JSONB)
- Use column->>'key' to extract nested values as text
- Use column->0 or column->-1 to access array elements by index

JSONB ARRAY FILTERING:
- Find patients with Diabetes: WHERE medical_history->'conditions' @> '["Diabetes"]'::jsonb
- Non-empty surgeries: WHERE jsonb_array_length(medical_history->'surgeries') > 0
- Penicillin allergy: WHERE allergies->'drug_allergies' @> '["Penicillin"]'::jsonb
- Key existence: WHERE column ? 'key_name'

IMPORTANT - Array Containment Syntax:
- ALWAYS cast comparison value to JSONB: column @> '["search_term"]'::jsonb
- Do NOT use: column = '["search_term"]' (that's text comparison)
```

### Full JSONB Example: "Find patients with Penicillin allergy"

**Profile (pharma db):**
```
Table: pharma.patients (500 rows)
  - allergies: jsonb | JSON keys: [drug_allergies, food_allergies, environmental_allergies]
```

**Pass 1 SQL (with JSONB hints):**
```sql
SELECT first_name, last_name, allergies
FROM patients
WHERE allergies->'drug_allergies' @> '["Penicillin"]'::jsonb
```

**Pass 2 Refinement:** SQL is confirmed valid — no changes needed.

**Validation:** No special intent detected. SQL passes.

**Execution Result:**
```json
[
  {"first_name": "Alice", "last_name": "Smith", "allergies": "{\"drug_allergies\": [\"Penicillin\"]}"},
  {"first_name": "Bob", "last_name": "Jones", "allergies": "{\"drug_allergies\": [\"Penicillin\", \"Sulfa\"]}"}
]
```

**Summary:** `"Found 2 patients with Penicillin allergies."`
**Graph spec:** `{"chart_type": "none", ...}` (not chartable — raw text/JSONB data)

### JSONB vs Standard: Difference Summary

| Aspect | Standard | JSONB |
|--------|----------|-------|
| `_should_enable_jsonb_querying` | `False` | `True` |
| Prompt additions | None | JSONB syntax hints block |
| Schema display | Normal columns | + `JSON keys: [...]` |
| SQL operators used | `=`, `LIKE`, `BETWEEN` | `->`, `->>`, `@>`, `?`, `jsonb_array_length()` |
| Chart output | Often chartable | Usually `"none"` (unstructured data) |

---

## SQL Generation Deep Dive

### Two-Pass Strategy

```
Pass 1: Full schema → Generate initial SQL
                          ↓
              extract_tables_from_sql(initial_sql)
                          ↓
Pass 2: Filtered schema (only used tables) → Refine SQL
```

**Why:** Providing a 50-table schema to an LLM increases hallucination risk. Filtering to 2-3 relevant tables dramatically improves accuracy.

### Intent Detection & Validation (validator.py)

Detected intents from question keywords:

| Intent | Keywords | SQL requirement |
|--------|----------|-----------------|
| `aggregation` | count, total, sum, avg, how many | `GROUP BY` |
| `ordering` | order, sorted, top, highest, lowest | `ORDER BY` |
| `limiting` | top N, first N, only N | `LIMIT N` |
| `filtering` | where, filter, only, having | `WHERE` |
| `joining` | with, including, along with | `JOIN` |
| `null_handling` | no X, empty, missing | `IS NULL` |
| `date_range` | before, after, between, since | Date comparison |
| `subquery` | more than average, exceeds | Subquery |

Auto-fixes applied when safe (LIMIT, ORDER BY). GROUP BY is flagged but not auto-fixed (requires column context).

---

## Summary + Chart Generation (generate_summary_and_graph_spec)

Single LLM call replacing two sequential calls. Combined prompt returns:

```json
{
  "summary": "1-2 sentence plain-text answer",
  "graph_spec": {
    "chart_type": "bar|line|pie|none",
    "x_key": "column_name",
    "y_keys": ["numeric_column"]
  }
}
```

**Fallback hierarchy (per field, independent):**

```
LLM call success + valid JSON
  └─ summary field valid?    → use LLM summary
                             → else: generate_summary() heuristic
  └─ graph_spec valid?       → validate_graph_spec() → use LLM spec
                             → else: build_fallback_graph_spec() heuristic
LLM call fails entirely      → both heuristics
```

**Heuristic chart selection (graph_spec.py):**
- Any temporal (date/time) x-axis → `line`
- Single numeric metric + 2-8 distinct x values → `pie`
- Everything else → `bar`
- No numeric columns → `none`

---

## Frontend Architecture

### Progress Steps (App.jsx:5-13)

```javascript
const PROGRESS_STEPS = [
  { step_id: 'schema_profile_loaded', label: 'Schema/profile loaded' },
  { step_id: 'sql_drafted',           label: 'SQL drafted' },
  { step_id: 'schema_linking_complete', label: 'Schema linking complete' },
  { step_id: 'sql_validated',         label: 'SQL validated' },
  { step_id: 'query_executed',        label: 'Query executed' },
  { step_id: 'summary_generated',     label: 'Summary generated' },
  { step_id: 'chart_recommendation_generated', label: 'Chart recommendation generated' },
]
```

Each step transitions `pending → completed` as SSE events arrive.

### Chart Rendering (ChatMessage.jsx)

Library: `react-chartjs-2` (Chart.js wrapper)

Frontend validates graph_spec independently (does not blindly trust backend):
```javascript
const validateGraphSpec = (graphSpec, columns, data) => {
  // Checks chart_type ∈ {bar, line, pie, none}
  // Checks x_key ∈ columns
  // Checks y_keys ∈ columns AND numeric
  // Falls back to buildHeuristicGraphSpec() if invalid
}
```

### Result Features
- Paginated data table with sortable columns
- CSV export: `query-results-{id}.csv`
- JSON export: `query-results-{id}.json`
- Clarification suggestions (click-to-run)
- SQL query display (collapsible)

---

## Docker Services

| Service | Hostname | Port | Image |
|---------|----------|------|-------|
| `db` | `db` | 5432 | `postgres:16-alpine` |
| `backend` | `nl2sql-backend` | 8000 | Custom FastAPI |
| `frontend` | `nl2sql-frontend` | 3001 | Custom React (nginx) |

**Important:** Backend containers must use `"host": "db"` in `databases.json` — NOT `localhost`. `localhost` inside Docker refers to the container itself.

---

## LLM Configuration

```python
# ChatOpenAI via OpenRouter (OpenAI-compatible API proxy)
ChatOpenAI(
    model="meta-llama/llama-3.3-70b-instruct",  # default
    api_key=OPENROUTER_API_KEY,
    base_url="https://openrouter.ai/api/v1",
    temperature=0.2,
    max_tokens=1024,
)
```

### LLM Call Count Per Query

| Scenario | LLM Calls |
|----------|-----------|
| Conversation (greeting/help) | 1 (classification) |
| Query, profile cached, no retry | 4 (classify + SQL pass1 + SQL pass2 + summary+chart) |
| Query, no profile cache | 4 (same — profiling doesn't use LLM) |
| Query with 1 retry | 5 (+ 1 fix_sql call) |
| Query with 2 retries | 6 |

---

## Key Design Decisions

1. **Two-pass SQL**: Full schema → extract used tables → focused schema → refine SQL. Reduces hallucination significantly.
2. **JSONB auto-detection**: Zero config — the profiler discovers JSON columns and automatically enables the JSONB prompt hints.
3. **Profile caching**: Profiling queries every column statistic; this is expensive (~seconds per table). Cache persists to disk and invalidates on schema change (hash-based).
4. **Retry logic**: Up to 3 SQL attempts. Uses `is_retryable_error()` to distinguish fixable (syntax errors, wrong column names) from fatal (connection refused, auth failure) errors.
5. **Combined summary+chart**: Single LLM call for both — halves the final-step latency.
6. **Dual-layer chart validation**: Backend validates, frontend re-validates independently. Neither trusts the LLM output blindly.
7. **Heuristic fallbacks everywhere**: No single LLM failure breaks the response — profiling heuristics, summary heuristics, and chart heuristics all exist.
