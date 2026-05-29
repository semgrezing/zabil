-- AlterTable: add pinned field to notes
ALTER TABLE "notes" ADD COLUMN "pinned" BOOLEAN NOT NULL DEFAULT false;

-- CreateIndex
CREATE INDEX "notes_pinned_idx" ON "notes"("pinned");
