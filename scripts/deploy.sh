#!/bin/bash
# Production deployment script for Ubuntu 24.04 VPS
# Run once on a fresh VPS
set -e

echo "=== Collab Notes — Initial Deployment ==="

# 1. Install Docker
apt update
apt install -y docker.io docker-compose-plugin curl

# 2. Enable Docker on boot
systemctl enable docker
systemctl start docker

# 3. Clone repo (adjust URL)
# git clone https://github.com/youruser/collab-notes.git /opt/collab-notes
# cd /opt/collab-notes

# 4. Copy env
cp .env.example .env
echo "⚠️  Edit .env with your real secrets before continuing"
echo "   nano .env"
read -p "Press Enter when .env is ready..."

# 5. Start postgres first
docker compose up -d postgres
sleep 5

# 6. Run migrations
docker compose run --rm backend npx prisma migrate deploy

# 7. Start all services
docker compose up -d

echo "=== Services started ==="
docker compose ps

# 8. Setup Let's Encrypt (replace yourdomain.com)
echo ""
echo "=== Setting up SSL ==="
echo "Run the following to get SSL certificate:"
echo ""
echo "  docker run --rm \\"
echo "    -v \$(pwd)/certbot/conf:/etc/letsencrypt \\"
echo "    -v \$(pwd)/certbot/www:/var/www/certbot \\"
echo "    certbot/certbot certonly \\"
echo "    --webroot -w /var/www/certbot \\"
echo "    -d api.yourdomain.com \\"
echo "    --email your@email.com \\"
echo "    --agree-tos --no-eff-email"
echo ""
echo "Then update nginx/app.conf with your domain and restart:"
echo "  docker compose restart nginx"

# 9. Setup backup cron
echo ""
echo "=== Setting up daily backup ==="
chmod +x scripts/backup.sh
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/collab-notes/scripts/backup.sh >> /var/log/collab-backup.log 2>&1") | crontab -

echo ""
echo "✅ Deployment complete!"
echo "   API: https://api.yourdomain.com/health"
