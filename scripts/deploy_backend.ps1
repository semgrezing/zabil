$pw = $env:DEPLOY_SERVER_PASSWORD
if (-not $pw) { throw "Set DEPLOY_SERVER_PASSWORD env var before running" }
$ha = $env:DEPLOY_SERVER_HOST
if (-not $ha) { $ha = 'root@130.49.151.52' }
$plink = 'C:\Program Files\PuTTY\plink.exe'
$pscp  = 'C:\Program Files\PuTTY\pscp.exe'
$loc = 'M:\zabil\backend'
$rem = '/opt/collab/backend'

Write-Host "1. Sozdaem direktorii na servere..."
& $plink -pw $pw -batch $ha "mkdir -p $rem/src/modules/mentions $rem/src/modules/notes $rem/src/modules/chats $rem/prisma/migrations/20260601120000_add_mentions $rem/prisma/migrations/20260601200000_add_note_blocks $rem/prisma/migrations/20260602120000_add_parent_message_id && echo DIRS_OK"

Write-Host "2. Kopiruyem src fajly..."
# Core
& $pscp -pw $pw -batch "$loc\src\app.ts"                                       "${ha}:${rem}/src/app.ts"
& $pscp -pw $pw -batch "$loc\src\config\env.ts"                                "${ha}:${rem}/src/config/env.ts"
# Chats (reply system + mentions)
& $pscp -pw $pw -batch "$loc\src\modules\chats\service.ts"                     "${ha}:${rem}/src/modules/chats/service.ts"
& $pscp -pw $pw -batch "$loc\src\modules\chats\routes.ts"                      "${ha}:${rem}/src/modules/chats/routes.ts"
# Notes (mentions parsing + blocks)
& $pscp -pw $pw -batch "$loc\src\modules\notes\service.ts"                     "${ha}:${rem}/src/modules/notes/service.ts"
& $pscp -pw $pw -batch "$loc\src\modules\notes\routes.ts"                      "${ha}:${rem}/src/modules/notes/routes.ts"
& $pscp -pw $pw -batch "$loc\src\modules\notes\block-service.ts"               "${ha}:${rem}/src/modules/notes/block-service.ts"
& $pscp -pw $pw -batch "$loc\src\modules\notes\block-routes.ts"                "${ha}:${rem}/src/modules/notes/block-routes.ts"
& $pscp -pw $pw -batch "$loc\src\modules\notes\block-schema.ts"                "${ha}:${rem}/src/modules/notes/block-schema.ts"
# Mentions
& $pscp -pw $pw -batch "$loc\src\modules\mentions\service.ts"                  "${ha}:${rem}/src/modules/mentions/service.ts"
& $pscp -pw $pw -batch "$loc\src\modules\mentions\routes.ts"                   "${ha}:${rem}/src/modules/mentions/routes.ts"

Write-Host "3. Kopiruyem Prisma schema + migrations..."
& $pscp -pw $pw -batch "$loc\prisma\schema.prisma"                             "${ha}:${rem}/prisma/schema.prisma"
& $pscp -pw $pw -batch "$loc\prisma\migrations\20260601120000_add_mentions\migration.sql" "${ha}:${rem}/prisma/migrations/20260601120000_add_mentions/migration.sql"
& $pscp -pw $pw -batch "$loc\prisma\migrations\20260601200000_add_note_blocks\migration.sql" "${ha}:${rem}/prisma/migrations/20260601200000_add_note_blocks/migration.sql"
& $pscp -pw $pw -batch "$loc\prisma\migrations\20260602120000_add_parent_message_id\migration.sql" "${ha}:${rem}/prisma/migrations/20260602120000_add_parent_message_id/migration.sql"

Write-Host "4. Prisma generate + migrate deploy..."
& $plink -pw $pw -batch $ha "cd $rem && npx prisma generate && npx prisma migrate deploy && echo MIGRATE_OK"

Write-Host "5. Rebuilding docker container..."
& $plink -pw $pw -batch $ha "cd /opt/collab && docker compose build backend 2>&1 | tail -10 && docker compose up -d backend && docker compose ps backend"

Write-Host "6. Proverka health..."
Start-Sleep -Seconds 12
Invoke-RestMethod -Uri 'https://api.achiemvemer.ru/health' -TimeoutSec 15
