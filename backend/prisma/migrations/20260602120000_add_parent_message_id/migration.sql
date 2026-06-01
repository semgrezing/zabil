-- AlterTable: group_chat_messages
ALTER TABLE "group_chat_messages" ADD COLUMN "parent_message_id" TEXT;

-- AddForeignKey: group_chat_messages
ALTER TABLE "group_chat_messages" ADD CONSTRAINT "group_chat_messages_parent_message_id_fkey" FOREIGN KEY ("parent_message_id") REFERENCES "group_chat_messages"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AlterTable: personal_messages
ALTER TABLE "personal_messages" ADD COLUMN "parent_message_id" TEXT;

-- AddForeignKey: personal_messages
ALTER TABLE "personal_messages" ADD CONSTRAINT "personal_messages_parent_message_id_fkey" FOREIGN KEY ("parent_message_id") REFERENCES "personal_messages"("id") ON DELETE SET NULL ON UPDATE CASCADE;
