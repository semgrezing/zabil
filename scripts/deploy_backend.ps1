$pw = '5tfpFqfdLdjMmlMf'
$ha = 'root@130.49.151.52'
$plink = 'C:\Program Files\PuTTY\plink.exe'
$pscp  = 'C:\Program Files\PuTTY\pscp.exe'
$loc = 'M:\zabil\backend'
$rem = '/opt/collab/backend'

Write-Host "1. Sozdaem direktorii na servere..."
& $plink -pw $pw -batch $ha "mkdir -p $rem/src/modules/calendar $rem/prisma/migrations/20260601100000_migrate_content_to_delta $rem/prisma/migrations/20260601120000_add_calendar_models && echo DIRS_OK"

Write-Host "2. Kopiruyem src fajly..."
& $pscp -pw $pw -batch "$loc\src\app.ts" "${ha}:${rem}/src/app.ts"
& $pscp -pw $pw -batch "$loc\src\config\env.ts" "${ha}:${rem}/src/config/env.ts"
& $pscp -pw $pw -batch "$loc\src\modules\notes\service.ts" "${ha}:${rem}/src/modules/notes/service.ts"
& $pscp -pw $pw -batch "$loc\src\modules\calendar\schema.ts" "${ha}:${rem}/src/modules/calendar/schema.ts"
& $pscp -pw $pw -batch "$loc\src\modules\calendar\service.ts" "${ha}:${rem}/src/modules/calendar/service.ts"
& $pscp -pw $pw -batch "$loc\src\modules\calendar\routes.ts" "${ha}:${rem}/src/modules/calendar/routes.ts"

Write-Host "3. Kopiruyem Prisma..."
& $pscp -pw $pw -batch "$loc\prisma\schema.prisma" "${ha}:${rem}/prisma/schema.prisma"
& $pscp -pw $pw -batch "$loc\prisma\migrations\20260601100000_migrate_content_to_delta\migration.sql" "${ha}:${rem}/prisma/migrations/20260601100000_migrate_content_to_delta/migration.sql"
& $pscp -pw $pw -batch "$loc\prisma\migrations\20260601120000_add_calendar_models\migration.sql" "${ha}:${rem}/prisma/migrations/20260601120000_add_calendar_models/migration.sql"

Write-Host "4. Rebuilding docker container..."
& $plink -pw $pw -batch $ha "cd /opt/collab && docker compose build backend 2>&1 | tail -10 && docker compose up -d backend && docker compose ps backend"

Write-Host "5. Proverka health..."
Start-Sleep -Seconds 12
Invoke-RestMethod -Uri 'https://api.achiemvemer.ru/health' -TimeoutSec 15
