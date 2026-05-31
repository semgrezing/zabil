-- CreateTable: track which group members have read which group messages
CREATE TABLE "group_message_reads" (
    "id" TEXT NOT NULL,
    "message_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "read_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "group_message_reads_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "group_message_reads_message_id_user_id_key" ON "group_message_reads"("message_id", "user_id");

-- CreateIndex
CREATE INDEX "group_message_reads_user_id_idx" ON "group_message_reads"("user_id");

-- AddForeignKey
ALTER TABLE "group_message_reads" ADD CONSTRAINT "group_message_reads_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "group_chat_messages"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "group_message_reads" ADD CONSTRAINT "group_message_reads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
