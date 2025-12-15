# Server Setup Guide

This guide covers the recommended production setup for deploying the n8n-playground application with a self-hosted GitHub Actions runner.

## Directory Structure

### Overview

```
/home/devops/
├── gh-runner/                    # GitHub Actions runner installation
│   ├── runner.env                # Runner configuration (secrets)
│   └── register-and-run.sh       # Runner bootstrap script
│
└── n8n-playground/               # Application deployment
    ├── docker-compose.yml        # Docker Compose configuration
    ├── .env                      # Application environment (secrets)
    ├── caddy_config/             # Caddy reverse proxy configuration
    │   └── Caddyfile             # Caddy configuration file
    └── local_files/              # n8n local file storage
```

### Why This Structure?

- **Everything in `/home/devops`**: Both runner and application live in the user's home directory for maximum simplicity.
- **No sudo needed** for file operations: User already owns everything in their home directory.
- **Minimal sudo requirements**: Only needed for systemd service management (runner), not for deployments or file operations.
- **Simpler permissions**: One user owns everything, no need for a dedicated deploy user.
- **Easy backups**: Everything important is in one location.

## Initial Server Setup

### Prerequisites

- Ubuntu 20.04+ or Debian 11+ server
- Root or sudo access
- SSH access configured
- Domain name pointing to your server

### 1. Create Directory Structure

```bash
# SSH into your server
ssh user@your-server

# Create directories in home (no sudo needed!)
mkdir -p ~/gh-runner
mkdir -p ~/n8n-playground
mkdir -p ~/n8n-playground/caddy_config
mkdir -p ~/n8n-playground/local_files
chmod 755 ~/gh-runner ~/n8n-playground
```

**Note:** All directories are created in your home directory, so you naturally own them. No sudo required!

### Configure Minimal Sudo Access

The devops user needs sudo for two purposes:
1. **Systemd operations** - Managing the runner service
2. **Package management** - Installing Docker, jq, curl, and dependencies

Configure passwordless sudo for these specific commands only:

#### 1. Runner Systemd Permissions

```bash
# Create restricted sudoers file for runner systemd operations
echo "devops ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/systemd/system/gh-runner.service" | sudo tee /etc/sudoers.d/devops-runner
echo "devops ALL=(ALL) NOPASSWD: /bin/systemctl daemon-reload" | sudo tee -a /etc/sudoers.d/devops-runner
echo "devops ALL=(ALL) NOPASSWD: /bin/systemctl * gh-runner" | sudo tee -a /etc/sudoers.d/devops-runner

# Set correct permissions
sudo chmod 0440 /etc/sudoers.d/devops-runner
```

#### 2. Package Management Permissions

```bash
# Create sudoers file for package management (Docker, jq, curl installation)
sudo tee /etc/sudoers.d/devops-packages << 'EOF'
# Allow apt-get update
devops ALL=(ALL) NOPASSWD: /usr/bin/apt-get update

# Allow installing specific package combinations
devops ALL=(ALL) NOPASSWD: /usr/bin/apt-get install -y ca-certificates curl gnupg
devops ALL=(ALL) NOPASSWD: /usr/bin/apt-get install -y jq
devops ALL=(ALL) NOPASSWD: /usr/bin/apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow Docker setup commands
devops ALL=(ALL) NOPASSWD: /usr/bin/install -m 0755 -d /etc/apt/keyrings
devops ALL=(ALL) NOPASSWD: /usr/bin/gpg --dearmor
devops ALL=(ALL) NOPASSWD: /usr/sbin/usermod -aG docker *

# Allow Docker service management
devops ALL=(ALL) NOPASSWD: /bin/systemctl start docker
devops ALL=(ALL) NOPASSWD: /bin/systemctl status docker
EOF

# Set correct permissions
sudo chmod 0440 /etc/sudoers.d/devops-packages
```

#### 3. Verify Configuration

```bash
# Verify syntax is correct (IMPORTANT!)
sudo visudo -c

# Should output:
# /etc/sudoers.d/devops-runner: parsed OK
# /etc/sudoers.d/devops-packages: parsed OK

# Test permissions (as devops user)
sudo -l

# Test specific commands (should not ask for password)
sudo systemctl status gh-runner || echo "Service not yet created - this is expected"
sudo apt-get update
```

**Replace `devops`** with your actual SSH username if different.

**Security Note:** These permissions follow the principle of least privilege - only specific commands are allowed, not full root access. The devops user cannot run arbitrary sudo commands.

### 2. Configure GitHub Secrets

In your GitHub repository, go to **Settings → Secrets and variables → Actions** and add:

| Variable Name | Description | Example |
|---------------|-------------|---------|
| `REMOTE_RUNNER_PATH` | Runner installation path | `/home/devops/gh-runner` |
| `REMOTE_PROJECT_PATH` | Application deployment path | `/home/devops/n8n-playground` |
| `DATA_FOLDER` | Base path for application data | `/home/devops/n8n-playground` |
| `DOMAIN_NAME` | Primary domain | `example.com` |
| `SUBDOMAIN` | Subdomain for n8n | `n8n` |
| `GENERIC_TIMEZONE` | Timezone for n8n | `UTC` or `America/New_York` |
| `SSL_EMAIL` | Email for Let's Encrypt (Caddy) | `admin@example.com` |
| `RUNNER_REPO` | GitHub repository | `owner/repo` |
| `RUNNER_LABELS` | Runner labels (comma-separated) | `self-hosted,hetzner,linux,docker` |
| `RUNNER_REG_PAT` | Personal Access Token (Secret) | `ghp_xxxxxxxxxxxxx` |
| `RUNNER_NAME_SECRET` | Unique runner name (Secret) | `hetzner-n8n-runner` |

**Note:** Since the runner is on the same server, we no longer need SSH secrets (`SSH_HOST`, `SSH_USER`, `SSH_KEY`) for deployment. The workflow uses direct file operations instead.

#### Creating the Personal Access Token (PAT)

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with these scopes:
   - `repo` (Full control of private repositories)
   - `admin:repo_hook` (Full control of repository hooks)
   - `workflow` (Update GitHub Action workflows)
3. Copy the token and save it as `RUNNER_REG_PAT` secret

## Deploying the Runner

### First-Time Setup

1. Go to your GitHub repository
2. Navigate to **Actions** → **Deploy - Runner** workflow
3. Click **Run workflow**
4. Select `start` from the dropdown
5. Click **Run workflow**

This will:
- Install Docker (if not present)
- Upload runner scripts to `/home/devops/gh-runner` (or your SSH user's home)
- Create and start the `gh-runner.service` systemd service
- Register the runner with GitHub

### Verify Runner Status

Check your repository's **Settings → Actions → Runners**. You should see your runner listed with a green "Idle" status.

On the server:
```bash
# Check systemd service
sudo systemctl status gh-runner

# Check Docker container
docker ps | grep runner

# View logs
sudo journalctl -u gh-runner -f
```

## Deploying the Application

### First Deployment

After the runner is set up, trigger the main deployment:

1. Push to `main` branch (via pull request), or
2. Go to **Actions** → **03 - Deploy - Production** → **Run workflow**

The workflow will:
1. Checkout the repository code
2. Prepare deployment bundle with `docker-compose.yml` and `.env` file
3. **Deploy directly on the server** (no SSH needed!):
   - Copy deployment files to `/home/devops/n8n-playground`
   - Pull latest Docker images (`caddy:latest` and `docker.n8n.io/n8nio/n8n`)
   - Run `docker compose` commands directly
   - Update containers with new images

**Key Advantage:** Since the runner is on the same server, deployment uses direct file operations instead of SSH, making it faster and more reliable.

**Note:** This project uses pre-built images from Docker Hub and n8n's official registry, so no build step is required. Caddy automatically handles SSL certificate provisioning via Let's Encrypt.

## File Permissions and Security

### Recommended Permissions

```bash
# Runner directory
/home/devops/gh-runner/                      devops:devops 755
/home/devops/gh-runner/runner.env            devops:devops 600  # Contains secrets!
/home/devops/gh-runner/register-and-run.sh   devops:devops 755

# Application directory
/home/devops/n8n-playground/                    devops:devops 755
/home/devops/n8n-playground/.env                devops:devops 600  # Contains secrets!
/home/devops/n8n-playground/docker-compose.yml  devops:devops 644
/home/devops/n8n-playground/caddy_config/       devops:devops 755
/home/devops/n8n-playground/caddy_config/Caddyfile devops:devops 644
/home/devops/n8n-playground/local_files/         devops:devops 755
```

**Note:** Replace `devops` with your actual SSH username (e.g., `ubuntu`, `admin`). Everything lives in your home directory, so you naturally own it all. No permission issues!

### Security Best Practices

1. **Minimal sudo**: Only needed for systemd operations (runner service management), not for any file operations or deployments
2. **Single user ownership**: One user owns everything, simplifying permissions and reducing complexity
3. **Protect secrets**: All `.env` files should be `600` (owner read/write only)
3. **Docker socket**: The runner has access to Docker socket for building images
4. **Firewall**: Configure UFW or iptables to only allow ports 22 (SSH), 80 (HTTP), 443 (HTTPS)
5. **SSH hardening**: 
   - Disable password authentication
   - Use key-based authentication only
   - Consider changing SSH port from default 22

### Example UFW Setup

```bash
# Enable UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH, HTTP, HTTPS
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

## Migrating from /opt to Home Directory

If you have an existing deployment in `/opt/n8n-playground` and want to move it to `/home/devops/n8n-playground` for simpler permissions:

### Migration Steps

```bash
# 1. Stop running containers at old location
cd /opt/n8n-playground
docker compose down

# 2. Copy everything to home directory (use Docker to avoid sudo!)
docker run --rm \
  -v /opt/n8n-playground:/source:ro \
  -v /home/devops:/target \
  alpine cp -a /source /target/n8n-playground

# 3. Take ownership (no sudo needed in your home!)
chown -R devops:devops ~/n8n-playground

# 4. Test at new location
cd ~/n8n-playground
docker compose up -d

# 5. Verify everything works
docker compose ps
docker compose logs
curl http://localhost

# 6. Update GitHub variable
# Go to: Settings → Secrets and variables → Actions → Variables
# Update: REMOTE_PROJECT_PATH=/home/devops/n8n-playground
# Update: DATA_FOLDER=/home/devops/n8n-playground

# 7. Clean up old location (only after verification!)
# You'll need sudo or root access to remove /opt/n8n-playground
sudo rm -rf /opt/n8n-playground
sudo userdel -r deploy  # Remove deploy user if no longer needed
```

### Important Notes

- **Docker volumes** (like `caddy_data`, `n8n_data`) are stored separately in `/var/lib/docker/volumes/` and will work automatically
- No configuration changes needed in `docker-compose.yml` - all paths are relative
- Always verify the new location works before deleting the old one
- Update your `REMOTE_PROJECT_PATH` and `DATA_FOLDER` GitHub variables to the new path

## Maintenance

### Viewing Application Logs

```bash
# SSH into server
ssh user@your-server

# View all service logs
cd ~/n8n-playground
docker compose logs -f

# View specific service
docker compose logs -f caddy
docker compose logs -f n8n
```

### Restarting Services

```bash
# Restart application
cd ~/n8n-playground
docker compose restart

# Restart specific service
docker compose restart caddy
docker compose restart n8n

# Restart runner
sudo systemctl restart gh-runner
```

### Updating Application

Push changes to `main` branch or manually trigger the workflow. The deployment will:
1. Pull new images
2. Stop old containers
3. Start new containers
4. Keep volumes intact (data persists)

### Backup Strategy

```bash
# Create backup directory
mkdir -p ~/backups

# Backup application configuration (no sudo needed!)
tar -czf ~/backups/n8n-playground-config-$(date +%Y%m%d).tar.gz \
  ~/n8n-playground/docker-compose.yml \
  ~/n8n-playground/.env \
  ~/n8n-playground/caddy_config

# Backup Docker volumes
docker run --rm \
  -v caddy_data:/data \
  -v ~/backups:/backup \
  alpine tar -czf /backup/caddy_data-$(date +%Y%m%d).tar.gz -C /data .

docker run --rm \
  -v n8n_data:/data \
  -v ~/backups:/backup \
  alpine tar -czf /backup/n8n_data-$(date +%Y%m%d).tar.gz -C /data .

# Backup application files (if using bind mounts)
tar -czf ~/backups/n8n-playground-files-$(date +%Y%m%d).tar.gz \
  ~/n8n-playground/local_files 2>/dev/null || echo "No local_files directory"
```

### Monitoring

```bash
# Check container health
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Check disk usage
df -h
docker system df

# Check Docker logs for errors
docker compose logs --tail=100 | grep -i error

# Check Caddy SSL certificate status
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# Check Caddy logs for SSL certificate information
docker compose logs caddy | grep -i certificate
```

## Troubleshooting

### Runner Not Appearing in GitHub

```bash
# Check service status
sudo systemctl status gh-runner

# Check logs
sudo journalctl -u gh-runner -n 50

# Restart service
sudo systemctl restart gh-runner

# Check Docker container
docker ps -a | grep runner
```

### Runner Setup: Sudo Password Required Error

If you get `sudo: a password is required` error when running the runner workflow:

**Cause:** Your SSH user doesn't have passwordless sudo configured for required operations.

**Solution:** Follow the "Configure Minimal Sudo Access" section in the Initial Server Setup. You need both:
1. **Runner systemd permissions** (`/etc/sudoers.d/devops-runner`)
2. **Package management permissions** (`/etc/sudoers.d/devops-packages`)

Quick check:
```bash
# Verify both files exist
sudo ls -la /etc/sudoers.d/devops-*

# Check your sudo permissions
sudo -l

# If files are missing, follow the setup instructions in "Configure Minimal Sudo Access"
```

Then re-run the workflow in GitHub Actions.

### Application Not Accessible

```bash
# Check if containers are running
cd ~/n8n-playground
docker compose ps

# Check Caddy logs
docker compose logs caddy

# Check n8n logs
docker compose logs n8n

# Verify ports are open
sudo netstat -tlnp | grep -E '(80|443)'

# Test Caddy configuration
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile
```

### SSL Certificate Issues

Caddy automatically handles SSL certificates via Let's Encrypt. If you encounter issues:

```bash
# Check Caddy logs for certificate errors
docker compose logs caddy | grep -i certificate

# Verify Caddyfile configuration
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# Check Caddy data volume (certificates are stored here)
docker volume inspect n8n-playground_caddy_data

# Reload Caddy configuration
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# If certificates are stuck, you can force renewal by restarting Caddy
docker compose restart caddy
```

**Note:** Caddy automatically provisions and renews SSL certificates. Make sure:
- Your domain DNS points to the server
- Ports 80 and 443 are open in the firewall
- The email in `SSL_EMAIL` variable is valid (for Let's Encrypt notifications)

### Disk Space Issues

```bash
# Clean up unused Docker resources
docker system prune -a --volumes

# Remove old images
docker image prune -a

# Check what's using space
docker system df -v
```

## Rollback Procedure

If a deployment fails:

```bash
# SSH into server
ssh user@your-server
cd ~/n8n-playground

# Pull previous image version (if using tagged versions)
docker pull docker.n8n.io/n8nio/n8n:PREVIOUS_TAG

# Or restore from backup
# Restore docker-compose.yml and .env from backup
cp ~/backups/n8n-playground-config-YYYYMMDD.tar.gz /tmp/
cd /tmp && tar -xzf n8n-playground-config-YYYYMMDD.tar.gz
cp docker-compose.yml ~/n8n-playground/
cp .env ~/n8n-playground/

# Restart
docker compose down
docker compose up -d
```

**Note:** Since this project uses `latest` tags, rollback typically means restoring the previous `docker-compose.yml` and `.env` files from backup, or checking out a previous git commit and redeploying.

## Alternative Locations (Reference)

If you prefer a different location than `/home/devops`, consider:

### `/opt/n8n-playground`
- **Purpose**: Standard Linux location for optional third-party software
- **Best for**: Professional/enterprise setups, multi-tenant servers
- **Pros**: Follows FHS standards, clear separation from user data
- **Cons**: Requires dedicated user or sudo for deployments

### `/srv/n8n-playground`
- **Purpose**: FHS standard for "site-specific data"
- **Best for**: Web services, HTTP-served content
- **Pros**: Semantically correct for web apps
- **Cons**: Less common in practice, similar sudo requirements as /opt

**Important:** If you change the location, update the `DATA_FOLDER` and `REMOTE_PROJECT_PATH` GitHub variables accordingly.

## Summary

This production setup provides:
- ✅ Everything in user's home directory for maximum simplicity
- ✅ No sudo needed for deployments or file operations
- ✅ Minimal sudo requirements (only for runner's systemd service)
- ✅ Single user owns everything - no permission complexity
- ✅ **No SSH needed for deployment** - runner is on the same server
- ✅ **Direct file operations** - faster and more reliable than SSH
- ✅ Easy to manage, backup, and scale
- ✅ Automated deployment via GitHub Actions
- ✅ Persistent data handling via Docker volumes (`caddy_data`, `n8n_data`)
- ✅ **Automatic SSL certificate provisioning** via Caddy (Let's Encrypt)
- ✅ **No separate certbot container** - Caddy handles SSL automatically

### Deployment Architecture

The deployment workflow is simplified because:
- **Runner and application are on the same server** - no network overhead
- **Direct file operations** - `cp` commands instead of SCP
- **Direct Docker commands** - no SSH connection needed
- **Faster execution** - no SSH handshake or network latency
- **More reliable** - fewer failure points (no SSH connection issues)

### Key Differences from Traditional Setups

- **Caddy instead of Nginx**: Caddy automatically handles SSL certificates, no certbot needed
- **Pre-built images**: Uses official `caddy:latest` and `docker.n8n.io/n8nio/n8n` images
- **Simplified configuration**: Caddyfile is easier to configure than Nginx configs
- **Automatic HTTPS**: Caddy provisions and renews SSL certificates automatically

For questions or issues, check the GitHub repository or open an issue.

