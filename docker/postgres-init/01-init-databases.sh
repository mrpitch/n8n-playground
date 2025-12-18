#!/bin/bash
set -e

# This script runs in the PostgreSQL container during initialization
# It has access to environment variables from docker-compose.yml

# Wait for PostgreSQL to be ready
until psql -U "${POSTGRES_USER:-postgres}" -d postgres -c '\q' 2>/dev/null; do
  >&2 echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

# Create n8n database and user
psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER:-postgres}" <<-EOSQL
    CREATE DATABASE ${POSTGRES_N8N_DB:-n8n};
    CREATE USER ${POSTGRES_N8N_USER:-n8n} WITH ENCRYPTED PASSWORD '${POSTGRES_N8N_PASSWORD}';
    GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_N8N_DB:-n8n} TO ${POSTGRES_N8N_USER:-n8n};
    ALTER DATABASE ${POSTGRES_N8N_DB:-n8n} OWNER TO ${POSTGRES_N8N_USER:-n8n};
EOSQL

echo "Database ${POSTGRES_N8N_DB:-n8n} and user ${POSTGRES_N8N_USER:-n8n} created successfully"

