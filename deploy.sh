#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DEV_MODE=false
[[ "${1:-}" = "--dev" ]] && DEV_MODE=true

if $DEV_MODE; then
    echo "iRestora PLUS - Development deploy"
    COMPOSE_FILES="-f docker-compose.yml -f docker-compose.dev.yml"
    export APP_ENV=development
else
    echo "iRestora PLUS - Production deploy"
    COMPOSE_FILES="-f docker-compose.yml"
    export APP_ENV=production
fi

if ! command -v docker &>/dev/null; then
    echo -e "${RED}Docker not found.${NC}"
    echo "  Linux (Ubuntu 24): sudo apt update && sudo apt install -y docker.io docker-compose-plugin && sudo systemctl enable --now docker"
    echo "  Mac: install Docker Desktop from https://docker.com/products/docker-desktop"
    exit 1
fi

if ! docker info &>/dev/null; then
    echo -e "${RED}Docker daemon is not running.${NC}"
    echo "  Mac: start Docker Desktop from Applications."
    echo "  Linux: sudo systemctl start docker"
    exit 1
fi

if docker compose version &>/dev/null; then
    COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
    COMPOSE="docker-compose"
else
    echo -e "${RED}Docker Compose not found. Install: sudo apt install -y docker-compose-plugin${NC}"
    exit 1
fi

if [ ! -f .env ]; then
    [ -f .env.docker ] && cp .env.docker .env && echo -e "${GREEN}.env created from .env.docker${NC}"
fi

[ -f .env ] || { echo -e "${RED}Missing .env. Copy .env.docker to .env and set values.${NC}"; exit 1; }
tr -d '\r' < .env > .env.tmp 2>/dev/null && mv .env.tmp .env
set +H 2>/dev/null || true
set -a
source .env 2>/dev/null || true
set +a

mkdir -p docker/nginx/ssl docker/mysql/init application/cache application/logs uploads frequent_changing
for f in docker/mysql/init/*.sh; do [ -f "$f" ] && tr -d '\r' < "$f" > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f"; done
chmod +x docker/mysql/init/*.sh 2>/dev/null || true

if $DEV_MODE; then
    echo -e "${YELLOW}Building images (dev)...${NC}"
    $COMPOSE $COMPOSE_FILES build app
else
    echo -e "${YELLOW}Building images (production)...${NC}"
    $COMPOSE $COMPOSE_FILES build --no-cache
fi

echo -e "${YELLOW}Starting services...${NC}"
$COMPOSE $COMPOSE_FILES up -d

echo -e "${YELLOW}Waiting for DB shared-mariadb (up to 60s)...${NC}"
for i in $(seq 1 60); do
    if docker run --rm --network shared-db-net busybox nc -z shared-mariadb 3306 2>/dev/null; then
        echo -e "${GREEN}DB ready${NC}"
        break
    fi
    [ "$i" -eq 60 ] && { echo -e "${RED}DB did not become ready. Ensure shared-mariadb is on network shared-db-net: docker network connect shared-db-net shared-mariadb${NC}"; exit 1; }
    sleep 1
done

$COMPOSE $COMPOSE_FILES exec -T app chown -R www-data:www-data /var/www/html/application/cache /var/www/html/application/logs /var/www/html/uploads /var/www/html/frequent_changing 2>/dev/null || true
$COMPOSE $COMPOSE_FILES exec -T app chmod -R 775 /var/www/html/application/cache /var/www/html/uploads /var/www/html/frequent_changing 2>/dev/null || true
$COMPOSE $COMPOSE_FILES exec -T app chmod -R o+rX /var/www/html 2>/dev/null || true

echo ""
echo -e "${GREEN}Server is ready.${NC}"
HOST="$([ -n "$DOCKER_HOST" ] && echo 'localhost' || (hostname -I 2>/dev/null | awk '{print $1}') || echo 'localhost')"
echo "  Mode:    $([ "$DEV_MODE" = true ] && echo 'development' || echo 'production')"
echo "  HTTP:    http://${HOST}:${WEB_PORT:-80}"
echo "  Install: http://${HOST}:${WEB_PORT:-80}/install"
echo "  App:     irestora_app | Web: irestora_web | DB: shared-mariadb (external) | Redis: irestora_redis"
echo "  Logs:    $COMPOSE $COMPOSE_FILES logs -f"
if $DEV_MODE; then
    echo ""
    echo -e "${YELLOW}Development: code changes in ./ are live (no rebuild).${NC}"
fi
