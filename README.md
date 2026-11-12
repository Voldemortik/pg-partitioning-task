# PostgreSQL: партиціонування, регламентні завдання, реплікація

Тестове завдання на PostgreSQL 18: партиціонована таблиця операцій, генерація даних, фонові завдання `pg_cron`, матеріалізоване представлення із сумами та логічна реплікація на другий інстанс.

Усе піднімається однією командою: два контейнери, 100 000 рядків, робочі завдання і реплікація.

## Швидкий старт

```bash
git clone <url>
cd pg-partitioning-task
cp .env.example .env
docker compose up -d --build
```

Через 10–20 секунд обидва інстанси готові:

| Інстанс | Порт на хості | Що на ньому |
|---------|---------------|-------------|
| `primary` | 5433 | таблиця, дані, завдання pg_cron, представлення, публікація |
| `replica` | 5434 | копія таблиці, підписка |

SQL-скрипти виконуються автоматично при першому запуску, у порядку номерів. Щоб почати з нуля: `docker compose down -v`.

## Відповідність пунктам завдання

| № | Завдання | Файл | Як вирішено |
|---|----------|------|-------------|
| 1 | Партиціонована таблиця T1 | [sql/01_table.sql](sql/01_table.sql) | Таблиця `t1`, `PARTITION BY RANGE (op_guid)`, помісячні партиції, межі обчислює `uuid7_floor()` |
| 2 | Генерація даних | [sql/02_generate_data.sql](sql/02_generate_data.sql) | Процедура `t1_generate(rows, days)`: 100 000 рядків за останні 120 днів |
| 3 | Унікальність гуід операції | [sql/03_unique_guid.sql](sql/03_unique_guid.sql) | `PRIMARY KEY (op_guid)` + `CHECK`, що гуід має версію 7 |
| 4 | Вставка кожні 5 секунд зі станом 0 | [sql/04_job_insert.sql](sql/04_job_insert.sql) | Функція `t1_add_operation()`, завдання pg_cron `t1_insert` |
| 5 | Оновлення стану 0 → 1 кожні 3 секунди | [sql/05_job_update.sql](sql/05_job_update.sql) | Функція `t1_confirm_operations()`, завдання pg_cron `t1_update` |
| 6 | Матеріалізоване представлення сум | [sql/06_matview.sql](sql/06_matview.sql) | `t1_totals` + тригер рівня оператора з `REFRESH ... CONCURRENTLY` |
| 7 | Реплікація на інший інстанс | [sql/07_publication.sql](sql/07_publication.sql), [sql/08_subscription.sql](sql/08_subscription.sql) | Логічна реплікація: публікація на `primary`, підписка на `replica` |
| — | Обслуговування (додатково) | [sql/09_maintenance_jobs.sql](sql/09_maintenance_jobs.sql) | Створення партиції на наступний місяць, очищення журналу pg_cron |

## Структура таблиці

| Поле завдання | Колонка | Тип |
|---------------|---------|-----|
| гуід операції | `op_guid` | `uuid`, за замовчуванням `uuidv7()`, первинний ключ |
| дата | `op_date` | `timestamptz`, обчислювана з гуіда (`GENERATED ALWAYS ... STORED`) |
| айді | `id` | `bigint`, identity |
| сума | `amount` | `numeric(14,2)` |
| стан | `status` | `smallint`: 0 — нова, 1 — підтверджена |
| повідомлення | `message` | `jsonb`: `account`, `client_id`, `op_type` (`online` / `offline`) |

## Перевірка

Підключення до інстансів:

```bash
docker compose exec primary sh -c 'psql -U $POSTGRES_USER -d $POSTGRES_DB'
docker compose exec replica sh -c 'psql -U $POSTGRES_USER -d $POSTGRES_DB'
```

Запити для перевірки на `primary`:

```sql
-- 1-2. Рядки по партиціях і діапазон дат
SELECT tableoid::regclass AS partition, count(*), min(op_date)::date, max(op_date)::date
FROM t1 GROUP BY 1 ORDER BY 1;

-- 3. Дублікат гуіда відхиляється (очікується помилка duplicate key)
INSERT INTO t1 (op_guid, amount, message)
SELECT op_guid, 1, t1_random_message() FROM t1 LIMIT 1;

-- 4-5. Завдання pg_cron і їхні запуски за останню хвилину
SELECT j.jobname, d.status, count(*) AS runs
FROM cron.job_run_details d JOIN cron.job j USING (jobid)
WHERE d.start_time > now() - interval '1 minute'
GROUP BY 1, 2 ORDER BY 1;

-- 4-5. Останні операції: нові мають стан 0, через кілька секунд - 1
SELECT id, op_date, amount, status FROM t1 ORDER BY op_guid DESC LIMIT 5;

-- 6. Суми по клієнту і типу операції
SELECT * FROM t1_totals ORDER BY client_id, op_type LIMIT 6;

-- 7. Стан реплікації
SELECT application_name, state, replay_lsn FROM pg_stat_replication;
```

Запит для порівняння `primary` і `replica` (результат має збігатися з точністю до останніх секунд):

```sql
SELECT count(*) AS row_count, sum(amount) AS total FROM t1;
```

