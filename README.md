# n8n Playground

A production-ready, secure n8n automation platform deployment with PostgreSQL database, comprehensive security measures, and automated CI/CD pipeline for Hetzner cloud servers.

## 🎯 What is This?

This project provides a complete, secure setup for self-hosting [n8n](https://n8n.io/) - a powerful workflow automation platform. It includes:

- **n8n** - Workflow automation platform
- **PostgreSQL** - Production-grade database (replaces SQLite)
- **Caddy** - Reverse proxy with automatic SSL/TLS certificates
- **Security Hardening** - Comprehensive security headers, rate limiting, encryption
- **CI/CD Pipeline** - Automated deployment via GitHub Actions
- **Self-Hosted Runner** - GitHub Actions runner on your Hetzner server

## ✨ Features

- 🔒 **Maximum Security**: Security headers, rate limiting, encryption, network isolation
- 🗄️ **PostgreSQL Database**: Scalable, production-ready database with automatic initialization
- 🔐 **Automatic SSL**: Caddy handles Let's Encrypt certificates automatically
- 🚀 **Automated Deployment**: GitHub Actions workflow for seamless deployments
- 🏠 **Local & Production**: Easy switching between local development and production
- 📦 **Docker Compose**: Simple, reproducible deployment
- 🔄 **Health Checks**: Automatic service health monitoring
- 📊 **Multiple Databases**: Support for n8n and AI agent memory databases

## 📁 Project Structure

```
n8n-playground/
├── docker/                      # Docker configuration
│   ├── docker-compose.yml      # Main compose file
│   ├── caddy_config/           # Caddy reverse proxy config
│   │   └── Caddyfile          # Security headers, rate limiting
│   ├── postgres-init/          # PostgreSQL initialization
│   │   ├── 01-init-databases.sh  # Database/user creation script
│   │   └── 01-init-databases.sql # SQL initialization (optional)
│   ├── local_files/            # n8n local file storage
│   ├── README.md               # Docker-specific documentation
│   └── TROUBLESHOOTING.md      # Troubleshooting guide
│
├── docs/                        # Comprehensive documentation
│   ├── server-setup.md         # Production server setup guide
│   ├── local-setup.md          # Local development guide
│   ├── setup-guides.md         # Complete setup guide
│   └── cursor-rules-guide.md   # Cursor IDE rules guide
│
├── scripts/                     # Setup automation scripts
│   ├── setup-github.sh         # GitHub configuration script
│   └── setup-server.sh         # Server configuration script
│
├── .github/
│   └── workflow/
│       └── deploy.yml          # GitHub Actions deployment workflow
│
├── example.env                  # Environment variables template
├── package.json                # pnpm scripts for easy management
└── README.md                   # This file
```

## 🚀 Quick Start

### Local Development

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/n8n-playground.git
   cd n8n-playground
   ```

2. **Create `.env` file** (copy from `example.env`):
   ```bash
   cp example.env .env
   ```

3. **Configure for local development** - Edit `.env`:
   ```bash
   # Local Development Configuration
   N8N_HOST=localhost
   N8N_PROTOCOL=http
   WEBHOOK_URL=http://localhost:5678/
   NODE_ENV=development
   N8N_SECURE_COOKIE=false

   # PostgreSQL (use simple passwords for local)
   POSTGRES_PASSWORD=localdev123
   POSTGRES_N8N_PASSWORD=localdev123
   N8N_ENCRYPTION_KEY=local-dev-key-change-in-production
   ```

4. **Install pnpm** (if not already installed):
   ```bash
   npm install -g pnpm
   # or using corepack (Node.js 16.10+)
   corepack enable
   corepack prepare pnpm@latest --activate
   ```

5. **Start services**:
   ```bash
   pnpm start
   ```

6. **Access n8n**: http://localhost:5678

### Production Deployment

#### Prerequisites

Before deploying, ensure you have:

1. **GitHub CLI** installed and authenticated:
   ```bash
   brew install gh  # macOS
   gh auth login
   ```

2. **SSH access** to your Hetzner server:
   - SSH key configured
   - Server IP/hostname
   - Username (typically `devops`)

3. **Domain name** pointing to your server:
   - DNS A record: `n8n.your-domain.com` → Server IP

#### Automated Setup (Recommended)

1. **Configure GitHub** (automated):
   ```bash
   chmod +x scripts/setup-github.sh
   ./scripts/setup-github.sh
   ```
   This script will:
   - Prompt for all required information
   - Generate secure passwords automatically
   - Set GitHub Variables and Secrets
   - Display a summary with passwords to save

2. **Configure Server** (automated):
   ```bash
   chmod +x scripts/setup-server.sh
   ./scripts/setup-server.sh
   ```
   This script will:
   - Connect to your server via SSH
   - Install required packages (Docker, jq, curl)
   - Create directory structure
   - Configure firewall (UFW)
   - Set up Docker permissions

3. **Deploy GitHub Actions Runner**:
   - Go to **Actions → Deploy - Runner** workflow
   - Click **Run workflow** → Select `start` → **Run workflow**
   - Verify runner appears in **Settings → Actions → Runners**

4. **Deploy Application**:
   - Go to **Actions → Deploy - Production** workflow
   - Click **Run workflow** → **Run workflow**
   - Check workflow logs for success

5. **Access n8n**: https://n8n.your-domain.com

#### Manual Setup

For manual setup instructions, see:
- **[Complete Setup Guide](docs/setup-guides.md)** - Step-by-step manual setup
- **[Server Setup Guide](docs/server-setup.md)** - Detailed server configuration
- **[Local Development Guide](docs/local-setup.md)** - Local development setup

## 🛠️ Available Commands

```bash
# Start services
pnpm start

# Stop services
pnpm stop

# Restart services
pnpm restart

# View logs
pnpm logs              # All services
pnpm logs:n8n         # n8n only
pnpm logs:postgres    # PostgreSQL only
pnpm logs:caddy       # Caddy only

# Check status
pnpm status

# Clean up (removes volumes - WARNING: deletes data!)
pnpm cleanup

# Access containers
pnpm shell:n8n        # Shell in n8n container
pnpm shell:postgres   # PostgreSQL shell
```

## 🔧 Configuration

### Environment Variables

The project uses environment variables to configure both local and production environments. See `example.env` for all available options.

**Key Variables:**

| Variable | Local | Production | Description |
|----------|-------|------------|-------------|
| `N8N_HOST` | `localhost` | (unset) | n8n hostname |
| `N8N_PROTOCOL` | `http` | (unset, defaults to `https`) | Protocol |
| `WEBHOOK_URL` | `http://localhost:5678/` | (unset, auto-generated) | Webhook base URL |
| `DOMAIN_NAME` | (optional) | `your-domain.com` | Production domain |
| `SUBDOMAIN` | (optional) | `n8n` | Subdomain for n8n |
| `POSTGRES_PASSWORD` | Simple password | Strong password | PostgreSQL superuser password |
| `POSTGRES_N8N_PASSWORD` | Simple password | Strong password | n8n database user password |
| `N8N_ENCRYPTION_KEY` | Dev key | Strong key | n8n encryption key |

**Generate secure passwords:**
```bash
# PostgreSQL password
openssl rand -base64 32

# n8n encryption key
openssl rand -base64 32
```

### Switching Between Local and Production

Simply update your `.env` file:

**For Local:**
- Set `N8N_HOST=localhost`, `N8N_PROTOCOL=http`, etc.
- Use simple passwords

**For Production:**
- Remove local overrides (or leave them unset)
- Set `DOMAIN_NAME` and `SUBDOMAIN`
- Use strong passwords
- Deploy via GitHub Actions

## 🔒 Security Features

This setup implements maximum security measures:

### Application Security
- ✅ **PostgreSQL** with separate database and user
- ✅ **Encryption keys** for sensitive n8n data
- ✅ **Secure cookies** (HTTPS-only in production)
- ✅ **Network isolation** via Docker networks
- ✅ **Health checks** for all services

### Web Security (Caddy)
- ✅ **HSTS** (HTTP Strict Transport Security) with preload
- ✅ **Content Security Policy** (CSP)
- ✅ **X-Frame-Options** (clickjacking protection)
- ✅ **X-Content-Type-Options** (MIME sniffing protection)
- ✅ **Rate Limiting** (50 requests/minute per IP)
- ✅ **Automatic SSL/TLS** via Let's Encrypt

### Server Security
- ✅ **SSH hardening** (key-based auth only, root disabled)
- ✅ **Firewall** (UFW) configuration
- ✅ **Fail2ban** for intrusion prevention
- ✅ **Minimal sudo** permissions
- ✅ **File permissions** (600 for secrets)

See [Server Setup Guide - Security](docs/server-setup.md#security-best-practices) for complete security configuration.

## 📚 Documentation

### Quick References
- **[Complete Setup Guide](docs/setup-guides.md)** - Step-by-step setup for GitHub and server
- **[Local Setup Guide](docs/local-setup.md)** - Local development setup and troubleshooting
- **[Server Setup Guide](docs/server-setup.md)** - Complete production deployment guide
- **[Docker README](docker/README.md)** - Docker-specific documentation
- **[Troubleshooting](docker/TROUBLESHOOTING.md)** - Common issues and solutions

### Detailed Guides

#### [Complete Setup Guide](docs/setup-guides.md)
Comprehensive guide covering:
- Prerequisites and requirements
- GitHub repository configuration (automated & manual)
- Server setup (automated & manual)
- Deployment steps
- Troubleshooting common issues
- Verification checklist

#### [Server Setup Guide](docs/server-setup.md)
Complete guide for production deployment including:
- Initial server setup and hardening
- GitHub Actions runner configuration
- Automated deployment pipeline
- Security best practices
- Backup and monitoring strategies
- Troubleshooting common issues

#### [Local Setup Guide](docs/local-setup.md)
Guide for local development including:
- Environment configuration
- Switching between local/production modes
- Troubleshooting local issues
- Available pnpm commands

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Internet                              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Caddy (Reverse Proxy)                      │
│  • Automatic SSL/TLS (Let's Encrypt)                   │
│  • Security Headers                                     │
│  • Rate Limiting                                        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                    n8n Container                        │
│  • Workflow Automation Platform                         │
│  • Port 5678                                            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              PostgreSQL Container                        │
│  • Database: n8n                                        │
│  • User: n8n (separate credentials)                     │
│  • Health Checks                                        │
└─────────────────────────────────────────────────────────┘
```

### Components

- **Caddy**: Reverse proxy with automatic SSL certificate management
- **n8n**: Workflow automation platform (accessible on port 5678 locally)
- **PostgreSQL**: Production database with automatic initialization
- **Docker Network**: Isolated network for secure service communication

## 🔄 Deployment

### Complete Setup Process

The deployment process consists of four main steps:

#### Step 1: GitHub Repository Configuration

Configure GitHub Variables and Secrets. You can use the automated script or set them manually:

**Automated (Recommended):**
```bash
./scripts/setup-github.sh
```

**Manual Setup:**
Go to your repository → **Settings → Secrets and variables → Actions**

**Required Variables:**
- `DATA_FOLDER` - Base path (`/home/devops/n8n-playground`)
- `DOMAIN_NAME` - Your domain (`mrpitch.rocks`)
- `SUBDOMAIN` - Subdomain (`n8n`)
- `GENERIC_TIMEZONE` - Timezone (`Europe/Berlin`)
- `SSL_EMAIL` - Email for SSL (`mrpitch@outlook.com`)
- `REMOTE_RUNNER_PATH` - Runner path (`/home/devops/gh-runner`)
- `REMOTE_PROJECT_PATH` - Project path (`/home/devops/n8n-playground`)
- `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_N8N_DB`, `POSTGRES_N8N_USER`
- `RUNNER_REPO`, `RUNNER_LABELS`
- `N8N_BASIC_AUTH_ACTIVE`, `N8N_USER_MANAGEMENT_DISABLED`

**Required Secrets:**
- `POSTGRES_PASSWORD` - Generate with: `openssl rand -base64 32`
- `POSTGRES_N8N_PASSWORD` - Generate with: `openssl rand -base64 32`
- `N8N_ENCRYPTION_KEY` - Generate with: `openssl rand -base64 32`
- `RUNNER_REG_PAT` - GitHub Personal Access Token
- `RUNNER_NAME_SECRET` - Unique runner name

See [Complete Setup Guide](docs/setup-guides.md#step-1-github-repository-setup) for detailed instructions.

#### Step 2: Server Configuration

Set up your Hetzner/Ubuntu server:

**Automated (Recommended):**
```bash
./scripts/setup-server.sh
```

**Manual Setup:**
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
# Logout and login again
```

See [Complete Setup Guide](docs/setup-guides.md#step-2-server-setup) for detailed instructions.

#### Step 3: Deploy GitHub Actions Runner

1. Go to **Actions → Deploy - Runner** workflow
2. Click **Run workflow** → Select `start` → **Run workflow**
3. Verify runner appears in **Settings → Actions → Runners** with "Idle" status

#### Step 4: Deploy Application

1. Go to **Actions → Deploy - Production** workflow
2. Click **Run workflow** → **Run workflow**
3. Check workflow logs for success
4. Access: `https://n8n.your-domain.com`

### Automated Deployment (GitHub Actions)

The deployment workflow automatically:

1. Checks out the repository
2. Prepares deployment bundle (docker-compose.yml, Caddyfile, etc.)
3. Copies files to the server
4. Pulls latest Docker images
5. Restarts containers with new configuration

**Requirements:**
- Self-hosted GitHub Actions runner on your server
- GitHub Secrets/Variables configured (see Step 1 above)

### Manual Deployment

```bash
# On your server
cd ~/n8n-playground
git pull
docker compose pull
docker compose up -d
```

### Verification Checklist

After deployment, verify:

- [ ] GitHub Variables set (14 variables)
- [ ] GitHub Secrets set (5 secrets)
- [ ] Server packages installed (Docker, jq, curl)
- [ ] Server directories created
- [ ] Firewall configured (ports 22, 80, 443)
- [ ] GitHub Actions runner deployed and online
- [ ] Application deployed successfully
- [ ] SSL certificate issued (check Caddy logs)
- [ ] n8n accessible at `https://n8n.your-domain.com`

## 🗄️ Database Management

### PostgreSQL Setup

The PostgreSQL container automatically creates:
- Database: `n8n` (configurable via `POSTGRES_N8N_DB`)
- User: `n8n` (configurable via `POSTGRES_N8N_USER`)
- Proper permissions and ownership

### Creating Additional Databases

For AI agent memory or other purposes:

```bash
# Connect to PostgreSQL
pnpm shell:postgres

# Create database
CREATE DATABASE ai_agent_memory;
CREATE USER ai_agent WITH ENCRYPTED PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE ai_agent_memory TO ai_agent;
```

### Backups

See [Server Setup Guide - Backup Strategy](docs/server-setup.md#backup-strategy) for automated backup procedures.

## 🐛 Troubleshooting

### Common Issues

**n8n container restarting:**
- Check PostgreSQL connection (see [Troubleshooting Guide](docker/TROUBLESHOOTING.md))
- Verify database/user exists
- Check password matches `.env` file

**Can't access localhost:5678:**
- Verify containers are running: `pnpm status`
- Check n8n logs: `pnpm logs:n8n`
- Ensure `.env` has local development settings

**SSL certificate issues:**
- Verify DNS points to your server
- Check ports 80/443 are open
- Review Caddy logs: `pnpm logs:caddy`

**GitHub setup issues:**
- Can't authenticate: Run `gh auth login`
- Secrets not set: Verify admin access and exact secret names (case-sensitive)
- See [Complete Setup Guide - Troubleshooting](docs/setup-guides.md#troubleshooting)

**Server setup issues:**
- Can't connect via SSH: Verify SSH key is added (`ssh-copy-id`)
- Docker permission denied: Add user to docker group and logout/login
- Firewall blocking: Check UFW status and allow required ports
- See [Complete Setup Guide - Troubleshooting](docs/setup-guides.md#troubleshooting)

**Deployment issues:**
- Runner not appearing: Check workflow logs and `RUNNER_REG_PAT` secret
- Application not deploying: Verify all GitHub Variables are set
- Check server logs: `cd ~/n8n-playground && docker compose ps`

See **[Troubleshooting Guide](docker/TROUBLESHOOTING.md)** and **[Complete Setup Guide](docs/setup-guides.md#troubleshooting)** for detailed solutions.

## 🔐 Security Best Practices

1. **Never commit `.env` files** - Already in `.gitignore`
2. **Rotate secrets regularly** - Especially after exposure
3. **Use strong passwords** - Generate with `openssl rand -base64 32`
4. **Keep Docker images updated** - Regular `docker compose pull`
5. **Monitor logs** - Check for suspicious activity
6. **Enable firewall** - UFW configuration (see [Server Setup Guide](docs/server-setup.md#example-ufw-setup))
7. **Use GitHub Secrets** - Never hardcode secrets in workflows

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

- **Documentation**: See `docs/` directory for detailed guides
- **Issues**: Open an issue on GitHub
- **n8n Documentation**: https://docs.n8n.io/

## 🙏 Acknowledgments

- [n8n](https://n8n.io/) - Workflow automation platform
- [Caddy](https://caddyserver.com/) - Web server with automatic HTTPS
- [PostgreSQL](https://www.postgresql.org/) - Advanced open-source database
- [Hetzner Cloud](https://www.hetzner.com/cloud) - Cloud hosting provider

---

**Made with ❤️ for secure, self-hosted automation**
