
FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    clickhouse-connect \
    "psycopg[binary]" \
    python-dotenv

COPY preprocessing/main.py ./preprocessing/main.py

CMD ["python", "-u", "preprocessing/main.py"]
