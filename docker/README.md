# n8n Docker Setup

This directory contains the Docker Compose configuration for running n8n with PostgreSQL.

## Quick Start

### Local Development

1. Copy `example.env` to `.env` in the project root (or create one in `docker/`):
   ```bash
   cp ../example.env ../.env
   ```

2. Update `.env` with local development settings:
   ```bash
   # Local Development Configuration
   N8N_HOST=localhost
   N8N_PROTOCOL=http
   WEBHOOK_URL=http://localhost:5678/
   NODE_ENV=development
   N8N_SECURE_COOKIE=false
   
   # PostgreSQL (use local passwords)
   POSTGRES_PASSWORD=your_local_password
   POSTGRES_N8N_PASSWORD=your_local_n8n_password
   N8N_ENCRYPTION_KEY=your_local_encryption_key
   ```

3. Start the services:
   ```bash
   cd docker
   docker compose --env-file ../.env up -d
   ```

4. Access n8n at: http://localhost:5678

**Note:** Caddy is not needed for local development. You can access n8n directly on port 5678.

### Production (Server/Hetzner)

1. Configure `.env` with production settings:
   ```bash
   # Production Configuration
   DOMAIN_NAME=mrpitch.rocks
   SUBDOMAIN=n8n
   SSL_EMAIL=mrpitch@outlook.com
   
   # Leave N8N_HOST, N8N_PROTOCOL, WEBHOOK_URL empty/unset
   # They will default to: https://n8n.mrpitch.rocks
   
   # Use strong production passwords
   POSTGRES_PASSWORD=strong_production_password
   POSTGRES_N8N_PASSWORD=strong_production_password
   N8N_ENCRYPTION_KEY=strong_production_encryption_key
   ```

2. Deploy via GitHub Actions workflow

3. Access n8n at: https://n8n.mrpitch.rocks (via Caddy reverse proxy)

## Configuration Modes

### Local Development Mode

Set these in your `.env`:
- `N8N_HOST=localhost`
- `N8N_PROTOCOL=http`
- `WEBHOOK_URL=http://localhost:5678/`
- `NODE_ENV=development`
- `N8N_SECURE_COOKIE=false`

**Access:** http://localhost:5678 (direct, no Caddy)

### Production Mode

Set these in your `.env`:
- `DOMAIN_NAME=your-domain.com`
- `SUBDOMAIN=n8n`
- `SSL_EMAIL=your-email@example.com`
- Leave `N8N_HOST`, `N8N_PROTOCOL`, `WEBHOOK_URL` empty

**Access:** https://n8n.your-domain.com (via Caddy with SSL)

## Environment Variables

### Required for Both Modes

- `POSTGRES_PASSWORD` - PostgreSQL superuser password
- `POSTGRES_N8N_PASSWORD` - n8n database user password
- `N8N_ENCRYPTION_KEY` - n8n encryption key (generate with: `openssl rand -base64 32`)

### Local Development Only

- `N8N_HOST=localhost`
- `N8N_PROTOCOL=http`
- `WEBHOOK_URL=http://localhost:5678/`
- `NODE_ENV=development`
- `N8N_SECURE_COOKIE=false`

### Production Only

- `DOMAIN_NAME` - Your domain (e.g., `mrpitch.rocks`)
- `SUBDOMAIN` - Subdomain for n8n (e.g., `n8n`)
- `SSL_EMAIL` - Email for Let's Encrypt SSL certificates

## Troubleshooting

### Can't access n8n on localhost:5678

1. Check if containers are running:
   ```bash
   docker compose ps
   ```

2. Check n8n logs:
   ```bash
   docker compose logs n8n
   ```

3. Verify `.env` has local development settings:
   ```bash
   grep N8N_HOST ../.env
   # Should show: N8N_HOST=localhost
   ```

4. Restart containers:
   ```bash
   docker compose down
   docker compose --env-file ../.env up -d
   ```

### Port already in use

If port 5678 is already in use, you can change it in `docker-compose.yml`:
```yaml
ports:
  - "5679:5678"  # Change host port to 5679
```

Then access at: http://localhost:5679

## Directory Structure

```
docker/
├── docker-compose.yml      # Main compose file
├── caddy_config/           # Caddy reverse proxy config (production)
│   └── Caddyfile
├── postgres-init/          # PostgreSQL initialization scripts
│   └── 01-init-databases.sql
├── local_files/            # n8n local file storage
└── README.md              # This file
```

## Commands

```bash
# Start services
docker compose --env-file ../.env up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f n8n
docker compose logs -f postgres

# Restart services
docker compose restart

# Remove everything (including volumes)
docker compose down -v
```

