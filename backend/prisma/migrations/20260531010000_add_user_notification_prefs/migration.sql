-- Migration: add per-user notification preferences
ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "note_push_enabled" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "checklist_push_enabled" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "release_push_enabled" BOOLEAN NOT NULL DEFAULT true;