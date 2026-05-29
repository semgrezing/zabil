#!/bin/bash
# Daily PostgreSQL backup script
# Add to crontab: 0 2 * * * /opt/collab-notes/backup.sh

set -e

BACKUP_DIR="/opt/collab-notes/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/db_${TIMESTAMP}.sql.gz"
KEEP_DAYS=7

mkdir -p "$BACKUP_DIR"

# Create backup
docker compose -f /opt/collab-notes/docker-compose.yml exec -T postgres \
  pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip > "$BACKUP_FILE"

echo "✅ Backup created: $BACKUP_FILE"

# Remove backups older than KEEP_DAYS
find "$BACKUP_DIR" -name "db_*.sql.gz" -mtime +${KEEP_DAYS} -delete

echo "✅ Old backups cleaned (kept last ${KEEP_DAYS} days)"
