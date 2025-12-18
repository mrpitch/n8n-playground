-- Create n8n database and user
CREATE DATABASE n8n;
CREATE USER n8n WITH ENCRYPTED PASSWORD '${POSTGRES_N8N_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
ALTER DATABASE n8n OWNER TO n8n;

-- Create AI agent memory database and user (optional)
-- Uncomment and set password in .env if you want to use this
-- CREATE DATABASE ai_agent_memory;
-- CREATE USER ai_agent WITH ENCRYPTED PASSWORD '${POSTGRES_AI_PASSWORD}';
-- GRANT ALL PRIVILEGES ON DATABASE ai_agent_memory TO ai_agent;
-- ALTER DATABASE ai_agent_memory OWNER TO ai_agent;

-- Enable pgvector extension for vector storage (useful for AI embeddings)
-- Note: Requires pgvector extension to be installed in the PostgreSQL image
-- You may need to use a custom image or install it manually
-- CREATE EXTENSION IF NOT EXISTS vector;

