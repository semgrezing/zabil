-- AddColumn is_admin to users
ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT false;

-- AddColumn telegram_id to users
ALTER TABLE users ADD COLUMN telegram_id TEXT;
ALTER TABLE users ADD CONSTRAINT users_telegram_id_key UNIQUE (telegram_id);
