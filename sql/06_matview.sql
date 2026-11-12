-- Завдання 6: поточна загальна сума по "айді клієнта" і "типу операції"
-- в матеріалізованому представленні, з оновленням при зміні стану з 0 на 1.
-- У суму входять лише підтверджені операції (стан = 1).

CREATE MATERIALIZED VIEW IF NOT EXISTS t1_totals AS
SELECT (message->>'client_id')::bigint AS client_id,
       message->>'op_type'             AS op_type,
       sum(amount)                     AS total_amount,
       count(*)                        AS operations
FROM t1
WHERE status = 1
GROUP BY 1, 2;

-- Унікальний індекс потрібен для REFRESH ... CONCURRENTLY (читачі не блокуються).
CREATE UNIQUE INDEX IF NOT EXISTS t1_totals_pkey ON t1_totals (client_id, op_type);

-- Оновлює представлення, лише якщо оператор справді перевів хоча б один рядок з 0 в 1.
CREATE OR REPLACE FUNCTION t1_refresh_totals() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM old_rows o
        JOIN new_rows n USING (op_guid)
        WHERE o.status = 0 AND n.status = 1
    ) THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY t1_totals;
    END IF;
    RETURN NULL;
END;
$$;

-- Тригер рівня оператора: одне оновлення представлення на один UPDATE, а не на кожен рядок.
-- З перехідними таблицями не можна вказати "UPDATE OF status", тому перехід 0 -> 1 перевіряється у функції.
CREATE OR REPLACE TRIGGER t1_status_confirmed
AFTER UPDATE ON t1
REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
FOR EACH STATEMENT
EXECUTE FUNCTION t1_refresh_totals();
