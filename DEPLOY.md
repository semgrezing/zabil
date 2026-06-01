# Deploy Guide

## Quick reference

When asking Claude to deploy, say: **"задеплой бэкенд"** or **"полный деплой"**.

---

## 1. Bump version (Flutter)

In `collab_notes_app/pubspec.yaml`, increment:
- **patch** (1.25.0 -> 1.25.1) for bug fixes
- **minor** (1.25.0 -> 1.26.0) for new features
- **build number** always increment (+28 -> +29)

```
version: 1.26.0+29
```

## 2. Commit & push

```powershell
cd M:\zabil
git add -A
git commit -m "feat: description of changes (v1.26.0)"
git push origin <branch>
```

## 3. Deploy backend to API server

### Option A: Universal deploy script

```powershell
powershell -ExecutionPolicy Bypass -File scripts\deploy_backend.ps1
```

### Option B: Manual step-by-step

Server: `root@130.49.151.52`, path: `/opt/collab/backend`

```powershell
$env:DEPLOY_SERVER_PASSWORD = '<server-password>'  # set once per session
$pw = $env:DEPLOY_SERVER_PASSWORD
$ha = 'root@130.49.151.52'
$plink = 'C:\Program Files\PuTTY\plink.exe'
$pscp  = 'C:\Program Files\PuTTY\pscp.exe'
$loc = 'M:\zabil\backend'
$rem = '/opt/collab/backend'
```

**a) Create directories on server:**
```powershell
& $plink -pw $pw -batch $ha "mkdir -p $rem/src/modules/chats $rem/prisma/migrations/<migration_name>"
```

**b) Copy changed files:**
```powershell
& $pscp -pw $pw -batch "$loc\src\modules\chats\service.ts"  "${ha}:${rem}/src/modules/chats/service.ts"
& $pscp -pw $pw -batch "$loc\src\modules\chats\routes.ts"   "${ha}:${rem}/src/modules/chats/routes.ts"
& $pscp -pw $pw -batch "$loc\prisma\schema.prisma"          "${ha}:${rem}/prisma/schema.prisma"
# + migration SQL files
```

**c) Run migration & rebuild:**
```powershell
& $plink -pw $pw -batch $ha "cd $rem && npx prisma generate && npx prisma migrate deploy"
& $plink -pw $pw -batch $ha "cd /opt/collab && docker compose build backend && docker compose up -d backend"
```

**d) Health check:**
```powershell
Start-Sleep -Seconds 12
Invoke-RestMethod -Uri 'https://api.achiemvemer.ru/health' -TimeoutSec 15
```

## 4. Build & publish app release (optional)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\publish_release.ps1 -Platform android
```

For both platforms:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\publish_release.ps1
```

To register in API (enables auto-update):
```powershell
$env:RELEASE_API_BASE_URL = 'https://api.achiemvemer.ru'
$env:RELEASE_API_TOKEN = '<jwt-access-token>'
powershell -ExecutionPolicy Bypass -File scripts\publish_release.ps1 -Notes 'Changelog text'
```

## 5. Verify

- `https://api.achiemvemer.ru/health` should return `{ status: "ok" }`
- Open app, check new features work
- Check server logs: `& $plink -pw $pw -batch $ha "cd /opt/collab && docker compose logs backend --tail 30"`

## Common issues

| Problem | Fix |
|---------|-----|
| Migration fails | Check SQL syntax, ensure column doesn't already exist |
| Docker build fails | Check `& $plink ... "cd /opt/collab && docker compose logs backend --tail 50"` |
| Health check fails | Wait longer (up to 30s), then check logs |
| `prisma generate` fails | Ensure schema.prisma was copied first |

## File locations

| What | Where |
|------|-------|
| Backend source | `M:\zabil\backend\src\` |
| Prisma schema | `M:\zabil\backend\prisma\schema.prisma` |
| Migrations | `M:\zabil\backend\prisma\migrations\` |
| Flutter app | `M:\zabil\collab_notes_app\` |
| Deploy script | `M:\zabil\scripts\deploy_backend.ps1` |
| Release script | `M:\zabil\scripts\publish_release.ps1` |
| Server backend | `/opt/collab/backend/` |
