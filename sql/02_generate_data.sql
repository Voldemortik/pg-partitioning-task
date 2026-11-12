-- Завдання 2: генерація тестових даних (100 тис.+ рядків за останні ~4 місяці)

-- Випадкове "повідомлення": 1000 клієнтів, до 3 рахунків у кожного, тип online/offline.
CREATE OR REPLACE FUNCTION t1_random_message() RETURNS jsonb
LANGUAGE sql VOLATILE AS $$
    SELECT jsonb_build_object(
        'account',   'UA' || lpad((c.client_id * 10 + random(1, 3))::text, 27, '0'),
        'client_id', c.client_id,
        'op_type',   CASE WHEN random() < 0.5 THEN 'online' ELSE 'offline' END)
    FROM (SELECT random(1, 1000) AS client_id) c;
$$;

-- Вставляє p_rows рядків з випадковою датою за останні p_days днів.
-- Гуід будується з випадкової дати (op_date обчислюється з гуіда): uuidv7(зсув) дає UUID v7 з міткою часу "зараз + зсув",
-- тому рядок потрапляє в партицію свого місяця.
-- Історичні операції вважаються підтвердженими (стан = 1).
CREATE OR REPLACE PROCEDURE t1_generate(p_rows integer DEFAULT 100000, p_days integer DEFAULT 120)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO t1 (op_guid, amount, status, message)
    SELECT uuidv7(d.op_date - clock_timestamp()),
           round((random() * 9990 + 10)::numeric, 2),
           1,
           t1_random_message()
    FROM (
        SELECT now() - random() * make_interval(days => p_days) AS op_date
        FROM generate_series(1, p_rows)
        ORDER BY 1
    ) d;
END;
$$;

CALL t1_generate();
ANALYZE t1;
