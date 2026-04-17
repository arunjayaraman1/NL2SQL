FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY backend/requirements.txt ./backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

COPY backend ./backend
COPY sql_prompt.py ./sql_prompt.py
COPY hr_examples.py ./hr_examples.py
COPY profiler.py ./profiler.py
COPY validator.py ./validator.py
COPY column_summarizer.py ./column_summarizer.py
COPY schema_linker.py ./schema_linker.py
COPY literal_matcher.py ./literal_matcher.py
COPY query_logger.py ./query_logger.py

EXPOSE 8000

CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
