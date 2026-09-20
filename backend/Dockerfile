FROM python:3.12-slim

WORKDIR /app

# System deps for psycopg's C extension build step, in case the binary wheel
# isn't available for this platform/arch.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN pip install --no-cache-dir -e . --no-deps

EXPOSE 8000

# No --reload — that's a dev-only flag (file-watching has no purpose in a
# built container, and costs the memory/CPU to run the watcher for nothing).
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
