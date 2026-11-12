# PostgreSQL 18 + pg_cron (розширення для регламентних завдань)
FROM postgres:18

RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-18-cron \
 && rm -rf /var/lib/apt/lists/*
