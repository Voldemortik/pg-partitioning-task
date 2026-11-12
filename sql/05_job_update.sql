-- Завдання 5: регламентне завдання - кожні 3 секунди оновлювати стан з 0 на 1
-- Парна секунда запуску - оновлюються парні айді, непарна - непарні.

-- Нових (стан = 0) рядків завжди мало, частковий індекс робить їх пошук миттєвим.
CREATE INDEX IF NOT EXISTS t1_pending_idx ON t1 (id) WHERE status = 0;

-- Повертає кількість оновлених рядків.
CREATE OR REPLACE FUNCTION t1_confirm_operations() RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
    v_parity  integer := floor(extract(second FROM clock_timestamp()))::integer % 2;
    v_updated integer;
BEGIN
    UPDATE t1
    SET status = 1
    WHERE status = 0
      AND id % 2 = v_parity;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated;
END;
$$;

SELECT cron.schedule('t1_update', '3 seconds', 'SELECT t1_confirm_operations()');
