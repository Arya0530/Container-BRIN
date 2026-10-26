
FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    pika \
    clickhouse-connect \
    python-dotenv

COPY raw-writer/main.py ./raw-writer/main.py

CMD ["python", "-u", "raw-writer/main.py"]
