# iRestora PLUS – Docker Setup

## Prerequisites

- **Docker** and **Docker Compose**
- **Linux (Ubuntu 24):**  
  `sudo apt update && sudo apt install -y docker.io docker-compose-plugin && sudo systemctl enable --now docker`
- **Mac:** Install [Docker Desktop](https://docker.com/products/docker-desktop) and start it.

---

## Production

### 1. Deploy

From the project root:

```bash
chmod +x deploy.sh
./deploy.sh
```

- Creates `.env` from `.env.docker` if missing.
- Builds images, starts app, web, db, redis.
- Waits for MySQL, fixes permissions.
- Prints URL when ready.

### 2. Access

- **App (installer):** `http://localhost:80/install` or `http://YOUR_SERVER_IP:80/install`
- **Health:** `http://localhost:80/health`

### 3. After installation (required)

1. Open **`index.php`** in the project root.
2. Find line: `define('ENVIRONMENT', 'is_install');`
3. Change to: `define('ENVIRONMENT', 'production');`
4. Save.  
   (If you use production Docker without dev mount, rebuild and redeploy so the image has this change:  
   `docker compose build app && docker compose up -d app web`.)

### 4. Use the app

- Open `http://localhost:80` (or your server IP).  
- You should see the login page instead of the installer.

### 5. Optional production steps

- Set strong passwords in `.env`: `DB_PASSWORD`, `MYSQL_ROOT_PASSWORD`, `REDIS_PASSWORD`.
- For HTTPS: add certificates under `docker/nginx/ssl/` and adjust nginx config.
- Backups:  
  `docker compose exec db mysqldump -u irestora -pYOUR_PASSWORD irestora_db > backup.sql`

---

## Development

### 1. Deploy (dev mode)

From the project root:

```bash
chmod +x deploy.sh
./deploy.sh --dev
```

- Uses `docker-compose.yml` + `docker-compose.dev.yml`.
- Mounts project into the container (code changes apply without rebuild).
- PHP: `display_errors` on, opcache revalidates every 1s.
- Containers use `restart: "no"`.

### 2. Access

- **App (installer):** `http://localhost:80/install`
- **Health:** `http://localhost:80/health`

### 3. After installation (required)

1. Open **`index.php`** in the project root.
2. Change: `define('ENVIRONMENT', 'is_install');` → `define('ENVIRONMENT', 'production');`
3. Save.  
   In dev mode the project is mounted, so the change is live immediately (no rebuild).

### 4. Use the app

- Open `http://localhost:80` for the login page.

### 5. Development workflow

- Edit PHP/code on the host; changes are reflected in the container.
- Logs: `docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f`
- Stop: `docker compose -f docker-compose.yml -f docker-compose.dev.yml down`

---

## Troubleshooting

### "Site can't be reached" on port 8090

If you use **WEB_PORT=8090** (e.g. because port 80 is used by another app), the server firewall may block port 8090. Open it:

**Ubuntu/Debian (ufw):**
```bash
sudo ufw allow 8090/tcp
sudo ufw reload
sudo ufw status
```

**Firewalld (RHEL/CentOS):**
```bash
sudo firewall-cmd --permanent --add-port=8090/tcp
sudo firewall-cmd --reload
```

**Cloud (AWS/GCP/Azure):** Open port 8090 in the instance/VM security group or network rules.

Then try again: `http://YOUR_SERVER_IP:8090`

---

## Summary

| Step | Production | Development |
|------|------------|------------|
| Deploy | `./deploy.sh` | `./deploy.sh --dev` |
| Installer | `http://localhost:80/install` | Same |
| After install | Set `ENVIRONMENT` to `production` in `index.php` | Same (instant in dev) |
| App URL | `http://localhost:80` | Same |

**Important:** After completing the web installer, always set `ENVIRONMENT` to `production` in `index.php`; otherwise the app will keep redirecting to the installer.
