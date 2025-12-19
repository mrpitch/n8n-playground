#!/bin/bash
set -e

# GitHub Repository Setup Script
# This script helps configure GitHub Secrets and Variables for the n8n-playground deployment

echo "🔧 GitHub Repository Setup for n8n-playground"
echo "=============================================="
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    echo "Install it from: https://cli.github.com/"
    echo "Or run: brew install gh"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

# Get repository info
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "📦 Repository: $REPO"
echo ""

# Function to set a secret
set_secret() {
    local name=$1
    local description=$2
    local value=$3
    
    if [ -z "$value" ]; then
        echo "⚠️  Skipping $name (no value provided)"
        return
    fi
    
    echo "$value" | gh secret set "$name" --repo "$REPO"
    echo "✅ Set secret: $name"
}

# Function to set a variable
set_variable() {
    local name=$1
    local description=$2
    local value=$3
    
    if [ -z "$value" ]; then
        echo "⚠️  Skipping $name (no value provided)"
        return
    fi
    
    gh variable set "$name" --body "$value" --repo "$REPO"
    echo "✅ Set variable: $name"
}

# Collect information
echo "Please provide the following information:"
echo ""

read -p "Server IP/Hostname: " SERVER_HOST
read -p "SSH Username (default: devops): " SSH_USER
SSH_USER=${SSH_USER:-devops}

echo "💡 CI/CD SSH Key:"
echo "   The setup-server.sh script should have generated a CI/CD key"
echo "   Look for a file like: ~/.ssh/{SERVER_HOST}_cicd_key"
echo ""
read -p "SSH Private Key Path (CI/CD key or default: ~/.ssh/id_rsa): " SSH_KEY_PATH
SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_rsa}
SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "⚠️  SSH key not found: $SSH_KEY_PATH"
    echo "   If you ran setup-server.sh, look for the CI/CD key file it created"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        echo "Aborted."
        exit 1
    fi
    SSH_KEY_CONTENT=""
else
    SSH_KEY_CONTENT=$(cat "$SSH_KEY_PATH")
fi

read -p "Domain name (e.g., mrpitch.rocks): " DOMAIN_NAME
read -p "Subdomain for n8n (default: n8n): " SUBDOMAIN
SUBDOMAIN=${SUBDOMAIN:-n8n}

read -p "SSL Email (default: mrpitch@outlook.com): " SSL_EMAIL
SSL_EMAIL=${SSL_EMAIL:-mrpitch@outlook.com}

read -p "Remote project path (default: /home/devops/n8n-playground): " REMOTE_PROJECT_PATH
REMOTE_PROJECT_PATH=${REMOTE_PROJECT_PATH:-/home/devops/n8n-playground}

read -p "Remote runner path (default: /home/devops/gh-runner): " REMOTE_RUNNER_PATH
REMOTE_RUNNER_PATH=${REMOTE_RUNNER_PATH:-/home/devops/gh-runner}

read -p "Timezone (default: Europe/Berlin): " GENERIC_TIMEZONE
GENERIC_TIMEZONE=${GENERIC_TIMEZONE:-Europe/Berlin}

read -p "GitHub repository (owner/repo, default: auto-detect): " RUNNER_REPO
RUNNER_REPO=${RUNNER_REPO:-$REPO}

read -p "Runner labels (comma-separated, default: self-hosted,hetzner,linux,docker): " RUNNER_LABELS
RUNNER_LABELS=${RUNNER_LABELS:-self-hosted,hetzner,linux,docker}

echo ""
echo "🔐 Generating secure passwords..."
POSTGRES_PASSWORD=$(openssl rand -base64 32)
POSTGRES_N8N_PASSWORD=$(openssl rand -base64 32)
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
RUNNER_NAME=$(openssl rand -hex 8 | sed 's/\(.*\)/hetzner-n8n-\1/')

echo "✅ Generated passwords"
echo ""

read -p "GitHub Personal Access Token (PAT) for runner registration: " RUNNER_REG_PAT
if [ -z "$RUNNER_REG_PAT" ]; then
    echo "⚠️  PAT not provided. You'll need to set RUNNER_REG_PAT manually."
fi
echo ""

echo ""
echo "📝 Setting GitHub Variables..."
echo ""

# Set Variables
set_variable "DATA_FOLDER" "Base path for application data" "$REMOTE_PROJECT_PATH"
set_variable "DOMAIN_NAME" "Primary domain" "$DOMAIN_NAME"
set_variable "SUBDOMAIN" "Subdomain for n8n" "$SUBDOMAIN"
set_variable "GENERIC_TIMEZONE" "Timezone for n8n" "$GENERIC_TIMEZONE"
set_variable "SSL_EMAIL" "Email for Let's Encrypt" "$SSL_EMAIL"
set_variable "REMOTE_RUNNER_PATH" "Runner installation path" "$REMOTE_RUNNER_PATH"
set_variable "REMOTE_PROJECT_PATH" "Application deployment path" "$REMOTE_PROJECT_PATH"
set_variable "POSTGRES_USER" "PostgreSQL superuser" "postgres"
set_variable "POSTGRES_DB" "PostgreSQL default database" "postgres"
set_variable "POSTGRES_N8N_DB" "n8n database name" "n8n"
set_variable "POSTGRES_N8N_USER" "n8n database user" "n8n"
set_variable "RUNNER_REPO" "GitHub repository" "$RUNNER_REPO"
set_variable "RUNNER_LABELS" "Runner labels" "$RUNNER_LABELS"
set_variable "N8N_BASIC_AUTH_ACTIVE" "Enable basic auth" "false"
set_variable "N8N_USER_MANAGEMENT_DISABLED" "Disable user management" "false"

echo ""
echo "🔒 Setting GitHub Secrets..."
echo ""

# Set SSH Secrets (required for workflows)
echo "Setting SSH secrets..."
if [ -n "$SSH_KEY_CONTENT" ]; then
    echo "$SSH_KEY_CONTENT" | gh secret set "SSH_KEY" --repo "$REPO"
    echo "✅ Set secret: SSH_KEY"
else
    echo "⚠️  SSH_KEY not set (key file not found or skipped)"
    echo "   You'll need to set SSH_KEY secret manually in GitHub"
fi

echo "$SERVER_HOST" | gh secret set "SSH_HOST" --repo "$REPO"
echo "✅ Set secret: SSH_HOST"

echo "$SSH_USER" | gh secret set "SSH_USER" --repo "$REPO"
echo "✅ Set secret: SSH_USER"

# Set Application Secrets
set_secret "POSTGRES_PASSWORD" "PostgreSQL superuser password" "$POSTGRES_PASSWORD"
set_secret "POSTGRES_N8N_PASSWORD" "n8n database user password" "$POSTGRES_N8N_PASSWORD"
set_secret "N8N_ENCRYPTION_KEY" "n8n encryption key" "$N8N_ENCRYPTION_KEY"
set_secret "RUNNER_REG_PAT" "GitHub PAT for runner" "$RUNNER_REG_PAT"
set_secret "RUNNER_NAME_SECRET" "Unique runner name" "$RUNNER_NAME"

echo ""
echo "✅ GitHub configuration complete!"
echo ""
echo "📋 Summary:"
echo "==========="
echo "Repository: $REPO"
echo "SSH Host: $SERVER_HOST"
echo "SSH User: $SSH_USER"
echo "Domain: $SUBDOMAIN.$DOMAIN_NAME"
echo "Server Path: $REMOTE_PROJECT_PATH"
echo ""
echo "⚠️  IMPORTANT: Save these passwords securely:"
echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
echo "POSTGRES_N8N_PASSWORD=$POSTGRES_N8N_PASSWORD"
echo "N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY"
echo ""
echo "📝 Next steps:"
echo "1. Set up your server (see scripts/setup-server.sh)"
echo "2. Deploy the runner (GitHub Actions → Deploy - Runner)"
echo "3. Deploy the application (GitHub Actions → Deploy - Production)"

