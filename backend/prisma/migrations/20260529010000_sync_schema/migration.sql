-- Sync database schema with Prisma schema.
-- The DB was originally created via `prisma db push` with an older schema.
-- Many columns were added to the Prisma schema without migrations.

-- groups: add is_personal and avatar_url
ALTER TABLE "groups" ADD COLUMN IF NOT EXISTS "is_personal" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "groups" ADD COLUMN IF NOT EXISTS "avatar_url" TEXT;

-- notes: add color_label, pinned, deleted_at
ALTER TABLE "notes" ADD COLUMN IF NOT EXISTS "color_label" TEXT;
ALTER TABLE "notes" ADD COLUMN IF NOT EXISTS "pinned" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "notes" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMPTZ;
ALTER TABLE "notes" ADD COLUMN IF NOT EXISTS "archived" BOOLEAN NOT NULL DEFAULT false;

-- group_chat_messages: add image fields
ALTER TABLE "group_chat_messages" ADD COLUMN IF NOT EXISTS "image_url" TEXT;
ALTER TABLE "group_chat_messages" ADD COLUMN IF NOT EXISTS "image_mime_type" TEXT;
ALTER TABLE "group_chat_messages" ADD COLUMN IF NOT EXISTS "image_size" INTEGER;
ALTER TABLE "group_chat_messages" ADD COLUMN IF NOT EXISTS "image_compressed" BOOLEAN;

-- personal_messages: add image fields and read_at
ALTER TABLE "personal_messages" ADD COLUMN IF NOT EXISTS "image_url" TEXT;
ALTER TABLE "personal_messages" ADD COLUMN IF NOT EXISTS "image_mime_type" TEXT;
ALTER TABLE "personal_messages" ADD COLUMN IF NOT EXISTS "image_size" INTEGER;
ALTER TABLE "personal_messages" ADD COLUMN IF NOT EXISTS "image_compressed" BOOLEAN;
ALTER TABLE "personal_messages" ADD COLUMN IF NOT EXISTS "read_at" TIMESTAMPTZ;

-- Create tables that may not exist yet

-- device_tokens
CREATE TABLE IF NOT EXISTS "device_tokens" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "device_tokens_user_id_token_key" ON "device_tokens"("user_id", "token");
CREATE INDEX IF NOT EXISTS "device_tokens_user_id_idx" ON "device_tokens"("user_id");
DO $$ BEGIN
    ALTER TABLE "device_tokens" ADD CONSTRAINT "device_tokens_user_id_fkey"
        FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- app_releases
CREATE TABLE IF NOT EXISTS "app_releases" (
    "id" TEXT NOT NULL,
    "version" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "download_url" TEXT NOT NULL,
    "sha256" TEXT,
    "file_size" INTEGER,
    "mandatory" BOOLEAN NOT NULL DEFAULT false,
    "min_supported_version" TEXT,
    "notes" TEXT,
    "released_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "app_releases_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "app_releases_platform_version_key" ON "app_releases"("platform", "version");
CREATE INDEX IF NOT EXISTS "app_releases_platform_released_at_idx" ON "app_releases"("platform", "released_at");

-- avatar_history
CREATE TABLE IF NOT EXISTS "avatar_history" (
    "id" TEXT NOT NULL,
    "entity_type" TEXT NOT NULL,
    "entity_id" TEXT NOT NULL,
    "avatar_url" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "avatar_history_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "avatar_history_entity_type_entity_id_created_at_idx"
    ON "avatar_history"("entity_type", "entity_id", "created_at");

-- note_checklist_items
CREATE TABLE IF NOT EXISTS "note_checklist_items" (
    "id" TEXT NOT NULL,
    "note_id" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "completed" BOOLEAN NOT NULL DEFAULT false,
    "position" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "note_checklist_items_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "note_checklist_items_note_id_position_idx" ON "note_checklist_items"("note_id", "position");
DO $$ BEGIN
    ALTER TABLE "note_checklist_items" ADD CONSTRAINT "note_checklist_items_note_id_fkey"
        FOREIGN KEY ("note_id") REFERENCES "notes"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- note_images
CREATE TABLE IF NOT EXISTS "note_images" (
    "id" TEXT NOT NULL,
    "note_id" TEXT NOT NULL,
    "filename" TEXT NOT NULL,
    "original_name" TEXT NOT NULL,
    "mime_type" TEXT NOT NULL,
    "file_size" INTEGER NOT NULL,
    "path" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "note_images_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "note_images_note_id_idx" ON "note_images"("note_id");
DO $$ BEGIN
    ALTER TABLE "note_images" ADD CONSTRAINT "note_images_note_id_fkey"
        FOREIGN KEY ("note_id") REFERENCES "notes"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Indexes on notes columns
CREATE INDEX IF NOT EXISTS "notes_archived_idx" ON "notes"("archived");
CREATE INDEX IF NOT EXISTS "notes_pinned_idx" ON "notes"("pinned");
CREATE INDEX IF NOT EXISTS "notes_deleted_at_idx" ON "notes"("deleted_at");
