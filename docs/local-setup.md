# Local Development Setup Guide

This guide explains how to configure n8n for local development vs production deployment.

## Quick Setup for Local Development

1. **Create/Update your `.env` file** in the project root with local settings:

```bash
# Local Development Configuration
N8N_HOST=localhost
N8N_PROTOCOL=http
WEBHOOK_URL=http://localhost:5678/
NODE_ENV=development
N8N_SECURE_COOKIE=false

# PostgreSQL Configuration (use simple passwords for local)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=localdev123
POSTGRES_DB=postgres
POSTGRES_N8N_DB=n8n
POSTGRES_N8N_USER=n8n
POSTGRES_N8N_PASSWORD=localdev123

# n8n Security Configuration
N8N_ENCRYPTION_KEY=local-dev-key-change-in-production
N8N_BASIC_AUTH_ACTIVE=false
N8N_USER_MANAGEMENT_DISABLED=false

# Optional - not needed for local
GENERIC_TIMEZONE=Europe/Berlin
```

2. **Install pnpm** (if not already installed):
   ```bash
   npm install -g pnpm
   # or using corepack (Node.js 16.10+)
   corepack enable
   corepack prepare pnpm@latest --activate
   ```

3. **Start the services**:

```bash
pnpm start
# or
cd docker && docker compose --env-file ../.env up -d
```

4. **Access n8n**: http://localhost:5678

## Production Setup (Server)

1. **Update your `.env` file** with production settings:

```bash
# Production Configuration
DOMAIN_NAME=mrpitch.rocks
SUBDOMAIN=n8n
SSL_EMAIL=mrpitch@outlook.com

# DO NOT set N8N_HOST, N8N_PROTOCOL, or WEBHOOK_URL
# They will automatically use: https://n8n.mrpitch.rocks

# PostgreSQL Configuration (use STRONG passwords!)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=STRONG_PRODUCTION_PASSWORD
POSTGRES_DB=postgres
POSTGRES_N8N_DB=n8n
POSTGRES_N8N_USER=n8n
POSTGRES_N8N_PASSWORD=STRONG_PRODUCTION_PASSWORD

# n8n Security Configuration
N8N_ENCRYPTION_KEY=STRONG_PRODUCTION_ENCRYPTION_KEY
N8N_BASIC_AUTH_ACTIVE=false
N8N_USER_MANAGEMENT_DISABLED=false
GENERIC_TIMEZONE=Europe/Berlin
```

2. **Deploy via GitHub Actions** - the workflow will handle deployment automatically

3. **Access n8n**: https://n8n.mrpitch.rocks (via Caddy with SSL)

## Configuration Modes Explained

### Local Development Mode

When you set these variables in `.env`:
- `N8N_HOST=localhost`
- `N8N_PROTOCOL=http`
- `WEBHOOK_URL=http://localhost:5678/`
- `NODE_ENV=development`
- `N8N_SECURE_COOKIE=false`

**Result:**
- n8n runs in development mode
- Accessible directly at http://localhost:5678
- No Caddy reverse proxy needed
- HTTP instead of HTTPS
- Less strict security (for development only)

### Production Mode

When you DON'T set `N8N_HOST`, `N8N_PROTOCOL`, or `WEBHOOK_URL`, and instead set:
- `DOMAIN_NAME=mrpitch.rocks`
- `SUBDOMAIN=n8n`

**Result:**
- n8n runs in production mode
- Accessible via Caddy reverse proxy at https://n8n.mrpitch.rocks
- Automatic SSL certificates via Let's Encrypt
- Full security headers and rate limiting
- HTTPS only

## Environment Variable Priority

The docker-compose.yml uses this priority:

1. **If `N8N_HOST` is set** → Use that value (local development)
2. **If `N8N_HOST` is NOT set** → Use `${SUBDOMAIN}.${DOMAIN_NAME}` (production)

Same logic applies to:
- `N8N_PROTOCOL` (defaults to `https` if not set)
- `WEBHOOK_URL` (defaults to `https://${SUBDOMAIN}.${DOMAIN_NAME}/` if not set)
- `NODE_ENV` (defaults to `production` if not set)
- `N8N_SECURE_COOKIE` (defaults to `true` if not set)

## Troubleshooting

### Can't access localhost:5678

1. Check containers are running:
   ```bash
   pnpm status
   ```

2. Check n8n logs:
   ```bash
   pnpm logs:n8n
   ```

3. Verify `.env` has local settings:
   ```bash
   grep N8N_HOST .env
   # Should show: N8N_HOST=localhost
   ```

4. Restart containers:
   ```bash
   pnpm restart
   ```

### Switching between local and production

Simply update your `.env` file:

**For local:** Add/keep the local overrides
**For production:** Remove the local overrides and set DOMAIN_NAME/SUBDOMAIN

Then restart:
```bash
pnpm restart
```

## Available Commands

```bash
pnpm start              # Start all services
pnpm stop               # Stop all services
pnpm restart            # Restart all services
pnpm logs               # View all logs
pnpm logs:n8n           # View n8n logs only
pnpm logs:postgres      # View PostgreSQL logs only
pnpm logs:caddy         # View Caddy logs only
pnpm status             # Check container status
pnpm cleanup            # Remove everything (including volumes)
pnpm shell:n8n          # Open shell in n8n container
pnpm shell:postgres     # Open PostgreSQL shell
```

