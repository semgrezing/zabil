-- Migrate existing plain text content to Quill Delta JSON format.
-- Plain text "Hello world" becomes [{"insert":"Hello world\n"}]
-- Empty content becomes [{"insert":"\n"}]
-- Already-converted rows (starting with [{"insert") are skipped.

UPDATE notes
SET content = '[{"insert":"\\n"}]'
WHERE content IS NULL OR content = '';

UPDATE notes
SET content = concat(
  '[{"insert":',
  to_jsonb(content || E'\n')::text,
  '}]'
)
WHERE content IS NOT NULL
  AND content != ''
  AND content NOT LIKE '[{"insert"%';
