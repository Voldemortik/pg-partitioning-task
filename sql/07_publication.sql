-- Завдання 7 (основний інстанс): логічна реплікація таблиці T1
-- Потрібно wal_level = logical (задано в docker-compose.yml).
-- Логін і пароль користувача реплікації беруться зі змінних оточення.

\getenv repl_user REPLICATION_USER
\getenv repl_password REPLICATION_PASSWORD

CREATE ROLE :"repl_user" LOGIN REPLICATION PASSWORD :'repl_password';
GRANT SELECT ON t1 TO :"repl_user";   -- для початкового копіювання даних

-- publish_via_partition_root: зміни публікуються від імені t1, а не окремих партицій,
-- тому набір партицій на репліці може відрізнятися.
CREATE PUBLICATION t1_pub FOR TABLE t1 WITH (publish_via_partition_root = true);
