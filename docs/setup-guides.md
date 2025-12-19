# Complete Setup Guide

This guide walks you through setting up both GitHub repository and server configurations.

## Prerequisites

1. **GitHub CLI** installed and authenticated
   ```bash
   brew install gh  # macOS
   gh auth login
   ```

2. **SSH access** to your Hetzner server
   - SSH key configured
   - Server IP/hostname
   - Username (typically `devops`)

3. **Domain name** pointing to your server
   - DNS A record: `n8n.your-domain.com` → Server IP

## Step 1: GitHub Repository Setup

### Option A: Automated (Recommended)

Run the setup script:

```bash
chmod +x scripts/setup-github.sh
./scripts/setup-github.sh
```

The script will:
- Prompt for all required information
- Generate secure passwords
- Set GitHub Variables
- Set GitHub Secrets
- Display a summary with passwords to save

### Option B: Manual Setup

Go to your GitHub repository → **Settings → Secrets and variables → Actions**

#### Set Variables:

| Variable | Value | Description |
|----------|-------|-------------|
| `DATA_FOLDER` | `/home/devops/n8n-playground` | Base path for application |
| `DOMAIN_NAME` | `mrpitch.rocks` | Your domain |
| `SUBDOMAIN` | `n8n` | Subdomain for n8n |
| `GENERIC_TIMEZONE` | `Europe/Berlin` | Timezone |
| `SSL_EMAIL` | `mrpitch@outlook.com` | Email for SSL |
| `REMOTE_RUNNER_PATH` | `/home/devops/gh-runner` | Runner path |
| `REMOTE_PROJECT_PATH` | `/home/devops/n8n-playground` | Project path |
| `POSTGRES_USER` | `postgres` | PostgreSQL user |
| `POSTGRES_DB` | `postgres` | PostgreSQL database |
| `POSTGRES_N8N_DB` | `n8n` | n8n database name |
| `POSTGRES_N8N_USER` | `n8n` | n8n database user |
| `RUNNER_REPO` | `your-username/n8n-playground` | Repository |
| `RUNNER_LABELS` | `self-hosted,hetzner,linux,docker` | Runner labels |
| `N8N_BASIC_AUTH_ACTIVE` | `false` | Basic auth |
| `N8N_USER_MANAGEMENT_DISABLED` | `false` | User management |

#### Set Secrets:

Generate passwords:
```bash
openssl rand -base64 32  # PostgreSQL password
openssl rand -base64 32  # n8n database password
openssl rand -base64 32  # n8n encryption key
```

| Secret | Value | Description |
|--------|-------|-------------|
| `POSTGRES_PASSWORD` | (generated) | PostgreSQL superuser password |
| `POSTGRES_N8N_PASSWORD` | (generated) | n8n database user password |
| `N8N_ENCRYPTION_KEY` | (generated) | n8n encryption key |
| `RUNNER_REG_PAT` | (GitHub PAT) | Personal Access Token |
| `RUNNER_NAME_SECRET` | (unique name) | Unique runner name |

**Creating GitHub PAT:**
1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with scopes: `repo`, `admin:repo_hook`, `workflow`
3. Copy and save as `RUNNER_REG_PAT` secret

## Step 2: Server Setup

### Option A: Automated (Recommended)

Run the setup script:

```bash
chmod +x scripts/setup-server.sh
./scripts/setup-server.sh
```

The script will:
- Connect to your server
- Install required packages (Docker, jq, curl)
- Create directory structure
- Configure firewall (UFW)
- Set up Docker permissions

### Option B: Manual Setup

Follow the [Server Setup Guide](../docs/server-setup.md) for detailed manual instructions.

**Quick manual setup:**

```bash
# SSH into server
ssh devops@your-server-ip

# Install packages
sudo apt-get update
sudo apt-get install -y curl jq docker.io docker-compose-plugin

# Create directories
mkdir -p ~/n8n-playground/{caddy_config,postgres-init,local_files}
mkdir -p ~/gh-runner

# Configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Add user to docker group
sudo usermod -aG docker $USER
# Logout and login again for group to take effect
```

## Step 3: Deploy GitHub Actions Runner

1. Go to your GitHub repository
2. Navigate to **Actions → Deploy - Runner** workflow
3. Click **Run workflow**
4. Select `start` from the dropdown
5. Click **Run workflow**

This will:
- Install Docker on the server (if needed)
- Set up the GitHub Actions runner
- Register the runner with your repository

**Verify:**
- Go to **Settings → Actions → Runners**
- You should see your runner with "Idle" status

## Step 4: Deploy Application

1. Go to **Actions → Deploy - Production** workflow
2. Click **Run workflow**
3. Click **Run workflow** again

This will:
- Copy deployment files to the server
- Pull Docker images
- Start containers
- Configure SSL certificates

**Verify:**
- Check workflow logs for success
- Access: `https://n8n.your-domain.com`

## Troubleshooting

### GitHub Setup Issues

**Can't authenticate with GitHub CLI:**
```bash
gh auth login
# Follow the prompts
```

**Secrets not set:**
- Check you have admin access to the repository
- Verify the secret names match exactly (case-sensitive)

### Server Setup Issues

**Can't connect via SSH:**
- Verify SSH key is added to server: `ssh-copy-id -i ~/.ssh/id_rsa.pub devops@server-ip`
- Check firewall allows port 22

**Docker permission denied:**
- Add user to docker group: `sudo usermod -aG docker $USER`
- Logout and login again

**Firewall blocking ports:**
```bash
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Deployment Issues

**Runner not appearing:**
- Check runner workflow logs
- Verify `RUNNER_REG_PAT` secret is set correctly
- Check server logs: `sudo journalctl -u gh-runner -f`

**Application not deploying:**
- Check deployment workflow logs
- Verify all GitHub Variables are set
- Check server: `cd ~/n8n-playground && docker compose ps`

## Verification Checklist

- [ ] GitHub Variables set (14 variables)
- [ ] GitHub Secrets set (5 secrets)
- [ ] Server packages installed (Docker, jq, curl)
- [ ] Server directories created
- [ ] Firewall configured (ports 22, 80, 443)
- [ ] GitHub Actions runner deployed and online
- [ ] Application deployed successfully
- [ ] SSL certificate issued (check Caddy logs)
- [ ] n8n accessible at `https://n8n.your-domain.com`

## Next Steps

After successful deployment:

1. **Access n8n**: https://n8n.your-domain.com
2. **Create your first workflow**
3. **Set up backups** (see [Server Setup Guide](../docs/server-setup.md#backup-strategy))
4. **Monitor logs**: `pnpm logs` (local) or `docker compose logs -f` (server)

## Support

- **Documentation**: See `docs/` directory
- **Troubleshooting**: See `docker/TROUBLESHOOTING.md`
- **Issues**: Open an issue on GitHub

