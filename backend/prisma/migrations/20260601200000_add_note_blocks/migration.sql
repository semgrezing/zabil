-- CreateTable
CREATE TABLE "note_blocks" (
    "id" TEXT NOT NULL,
    "note_id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "content" TEXT NOT NULL DEFAULT '{}',
    "position" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "note_blocks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "note_blocks_note_id_position_idx" ON "note_blocks"("note_id", "position");

-- AddForeignKey
ALTER TABLE "note_blocks" ADD CONSTRAINT "note_blocks_note_id_fkey" FOREIGN KEY ("note_id") REFERENCES "notes"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AlterTable
ALTER TABLE "notes" ADD COLUMN "migrated" BOOLEAN NOT NULL DEFAULT false;
