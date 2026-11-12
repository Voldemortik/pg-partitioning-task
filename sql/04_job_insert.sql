-- Завдання 4: регламентне завдання - кожні 5 секунд додавати запис зі станом 0

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Гуід (uuidv7), дата (now), айді - значення за замовчуванням.
CREATE OR REPLACE FUNCTION t1_add_operation() RETURNS uuid
LANGUAGE sql VOLATILE AS $$
    INSERT INTO t1 (amount, status, message)
    VALUES (round((random() * 9990 + 10)::numeric, 2), 0, t1_random_message())
    RETURNING op_guid;
$$;

SELECT cron.schedule('t1_insert', '5 seconds', 'SELECT t1_add_operation()');
