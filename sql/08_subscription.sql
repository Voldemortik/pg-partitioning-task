-- Завдання 7 (другий інстанс): підписка на публікацію T1
-- Перед цим на репліці виконуються 01_table.sql і 03_unique_guid.sql (структура таблиці).

\getenv repl_user REPLICATION_USER
\getenv repl_password REPLICATION_PASSWORD
\getenv primary_host PRIMARY_HOST
\getenv primary_db POSTGRES_DB

\set conninfo 'host=' :primary_host ' port=5432 dbname=' :primary_db ' user=' :repl_user ' password=' :repl_password

CREATE SUBSCRIPTION t1_sub CONNECTION :'conninfo' PUBLICATION t1_pub;
