# Troubleshooting Guide

## PostgreSQL Authentication Failed

If you see `password authentication failed for user "n8n"`, it means the PostgreSQL database and user haven't been created yet.

### Solution 1: Recreate PostgreSQL Volume (Recommended for first-time setup)

This will delete all PostgreSQL data, so only use this if you don't have important data:

```bash
# Stop all containers
pnpm stop

# Remove the PostgreSQL volume
docker volume rm docker_postgres_data

# Start again - the init script will run
pnpm start
```

### Solution 2: Manually Create Database (If volume already exists)

If you already have data in PostgreSQL, manually create the database and user:

```bash
# Connect to PostgreSQL container
pnpm shell:postgres

# Or manually:
docker compose -f docker/docker-compose.yml exec postgres psql -U postgres
```

Then run these SQL commands (replace passwords with your actual passwords from .env):

```sql
CREATE DATABASE n8n;
CREATE USER n8n WITH ENCRYPTED PASSWORD 'your_postgres_n8n_password_from_env';
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
ALTER DATABASE n8n OWNER TO n8n;
\q
```

Then restart n8n:
```bash
pnpm restart
```

### Solution 3: Check Your .env File

Make sure your `.env` file has the correct PostgreSQL passwords:

```bash
# Check if passwords are set
grep POSTGRES_N8N_PASSWORD .env

# Should show something like:
# POSTGRES_N8N_PASSWORD=your_password_here
```

## Permissions Warning

The permissions warning is fixed by setting `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true` in docker-compose.yml (already added).

If you still see the warning, restart the container:
```bash
pnpm restart
```

## Container Restart Loop

If n8n keeps restarting:

1. **Check logs:**
   ```bash
   pnpm logs:n8n
   ```

2. **Common causes:**
   - PostgreSQL authentication failed (see above)
   - Missing environment variables in .env
   - Wrong database credentials

3. **Verify PostgreSQL is running:**
   ```bash
   pnpm status
   # Should show postgres as "healthy"
   ```

4. **Check PostgreSQL logs:**
   ```bash
   pnpm logs:postgres
   ```

## Verify Database Creation

To verify the database and user were created:

```bash
# Connect to PostgreSQL
pnpm shell:postgres

# List databases
\l

# Should show "n8n" database

# List users
\du

# Should show "n8n" user

# Exit
\q
```

## Reset Everything

If you want to start completely fresh:

```bash
# Stop everything
pnpm stop

# Remove all volumes (WARNING: This deletes all data!)
pnpm cleanup

# Start fresh
pnpm start
```

