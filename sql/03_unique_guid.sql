-- Завдання 3: унікальність по полю "гуід операції"
-- Унікальний індекс на партиціонованій таблиці мусить містити ключ партиціонування.
-- Тут ключ партиціонування - сам гуід, тому PRIMARY KEY (op_guid) унікальний на всю таблицю.
-- Скрипт виконується і на основному інстансі, і на репліці (первинний ключ потрібен для реплікації UPDATE).

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 't1_pkey' AND conrelid = 't1'::regclass) THEN
        ALTER TABLE t1 ADD CONSTRAINT t1_pkey PRIMARY KEY (op_guid);
    END IF;

    -- Гуід іншої версії (наприклад, випадковий v4) не містить часу і зламав би розкладку по партиціях.
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 't1_guid_is_v7' AND conrelid = 't1'::regclass) THEN
        ALTER TABLE t1 ADD CONSTRAINT t1_guid_is_v7 CHECK (uuid_extract_version(op_guid) = 7);
    END IF;
END;
$$;
