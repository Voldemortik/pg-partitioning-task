-- Додатково (поза завданням): обслуговування, без якого завдання 4 з часом зламається.

-- 25-го числа створювати партицію на наступний місяць,
-- інакше нові рядки почнуть потрапляти в t1_default.
SELECT cron.schedule('t1_next_partition', '0 0 25 * *',
    $$CALL t1_create_partition((now() + interval '1 month')::date)$$);

-- Журнал pg_cron росте на ~46 тис. рядків за добу - зберігати лише останню добу.
SELECT cron.schedule('cron_log_cleanup', '0 * * * *',
    $$DELETE FROM cron.job_run_details WHERE end_time < now() - interval '1 day'$$);
