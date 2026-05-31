-- Add persistent checklist section key to support multiple checklist blocks in one note
ALTER TABLE "note_checklist_items"
ADD COLUMN "section_id" TEXT NOT NULL DEFAULT 'main';

CREATE INDEX "note_checklist_items_note_id_section_id_position_idx"
ON "note_checklist_items"("note_id", "section_id", "position");
