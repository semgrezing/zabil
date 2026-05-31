-- AddColumn deleted_at to group_chat_messages
ALTER TABLE group_chat_messages ADD COLUMN deleted_at TIMESTAMPTZ;

-- AddColumn deleted_at to personal_messages
ALTER TABLE personal_messages ADD COLUMN deleted_at TIMESTAMPTZ;
