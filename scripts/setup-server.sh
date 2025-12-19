#!/bin/bash
set -e

# Server Setup Script for n8n-playground
# This script helps configure your Hetzner/Ubuntu server

echo "🖥️  Server Setup for n8n-playground"
echo "===================================="
echo ""
echo "💡 TIP: To avoid entering your SSH passphrase multiple times,"
echo "   add your key to ssh-agent first: ssh-add $SSH_KEY"
echo "   (See docs/ssh-passphrase-tips.md for details)"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  Running as root. Some commands will be skipped."
    ROOT_MODE=true
else
    ROOT_MODE=false
fi

# Collect information
read -p "Server hostname/IP: " SERVER_HOST
read -p "SSH username (default: devops): " SSH_USER
SSH_USER=${SSH_USER:-devops}

read -p "SSH key path (default: ~/.ssh/id_rsa): " SSH_KEY
SSH_KEY=${SSH_KEY:-~/.ssh/id_rsa}

# Expand tilde
SSH_KEY="${SSH_KEY/#\~/$HOME}"

if [ ! -f "$SSH_KEY" ]; then
    echo "❌ SSH key not found: $SSH_KEY"
    exit 1
fi

echo ""
echo "📋 Server Configuration:"
echo "Host: $SERVER_HOST"
echo "User: $SSH_USER"
echo "SSH Key: $SSH_KEY"
echo ""

read -p "Continue? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Aborted."
    exit 1
fi

# Setup SSH ControlMaster for connection reuse (enter passphrase once)
# Create safe control path (no special chars)
SSH_CONTROL_DIR="/tmp/ssh_control_$$"
mkdir -p "$SSH_CONTROL_DIR" 2>/dev/null || true
chmod 700 "$SSH_CONTROL_DIR" 2>/dev/null || true
SSH_CONTROL_PATH="$SSH_CONTROL_DIR/master_${SSH_USER}_$(echo "$SERVER_HOST" | tr -cd 'a-zA-Z0-9')"
SSH_OPTS="-q -i $SSH_KEY -o ControlMaster=yes -o ControlPath=$SSH_CONTROL_PATH -o ControlPersist=600 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o RequestTTY=no"

# Check if ssh-agent is running and has the key loaded
SSH_KEY_FINGERPRINT=$(ssh-keygen -lf "$SSH_KEY" 2>/dev/null | awk '{print $2}' || echo "")
if [ -n "$SSH_KEY_FINGERPRINT" ] && ssh-add -l 2>/dev/null | grep -q "$SSH_KEY_FINGERPRINT"; then
    echo "✅ SSH key already loaded in ssh-agent (no passphrase needed!)"
    USE_SSH_AGENT=true
else
    echo ""
    echo "💡 TIP: To avoid entering passphrase multiple times, add your key to ssh-agent:"
    echo "   ssh-add $SSH_KEY"
    echo "   (This will cache your passphrase for the current session)"
    echo ""
    USE_SSH_AGENT=false
fi

# Function to setup SSH connection reuse
setup_ssh_connection() {
    echo "🔐 Setting up SSH connection reuse..."
    
    # First, try to use existing connection if available
    if [ -S "$SSH_CONTROL_PATH" ] 2>/dev/null; then
        if ssh -O check $SSH_OPTS "$SSH_USER@$SERVER_HOST" 2>/dev/null; then
            echo "✅ Reusing existing SSH connection"
            return 0
        else
            # Connection exists but is dead, remove it
            rm -f "$SSH_CONTROL_PATH" 2>/dev/null || true
        fi
    fi
    
    # Establish ControlMaster connection by running a simple test command
    # This will create the master connection and cache the passphrase
    echo "   Establishing master connection..."
    if [ "$USE_SSH_AGENT" = "false" ]; then
        echo "   ⚠️  Enter your SSH key passphrase ONCE now (it will be cached for 10 minutes):"
    fi
    
    # Run a simple command to establish the master connection
    # The ControlMaster=yes option will create a persistent connection
    # -q flag suppresses most SSH messages, and we redirect all output
    if ssh $SSH_OPTS -o ConnectTimeout=10 "$SSH_USER@$SERVER_HOST" 'BASH_ENV=/dev/null exec bash -c "true"' > /dev/null 2>&1; then
        # Give ControlMaster a moment to create the socket
        sleep 0.5
        # Verify the master connection socket was created (optional check)
        if [ -S "$SSH_CONTROL_PATH" ] 2>/dev/null; then
            if [ "$USE_SSH_AGENT" = "true" ]; then
                echo "✅ SSH master connection established (using ssh-agent)"
            else
                echo "✅ SSH master connection established (passphrase cached for 10 minutes)"
            fi
        else
            # Socket might not exist immediately, but connection worked
            if [ "$USE_SSH_AGENT" = "true" ]; then
                echo "✅ SSH connection established (using ssh-agent)"
            else
                echo "✅ SSH connection established (passphrase cached for 10 minutes)"
            fi
        fi
        return 0
    else
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            echo "❌ SSH connection timed out"
        else
            echo "❌ Failed to establish SSH connection (exit code: $EXIT_CODE)"
        fi
        echo "   Check your SSH key, passphrase, and server access"
        rm -rf "$SSH_CONTROL_DIR" 2>/dev/null || true
        exit 1
    fi
}

# Function to cleanup SSH connection
cleanup_ssh_connection() {
    if [ -S "$SSH_CONTROL_PATH" ] 2>/dev/null; then
        ssh -O exit $SSH_OPTS "$SSH_USER@$SERVER_HOST" 2>/dev/null || true
    fi
    rm -rf "$SSH_CONTROL_DIR" 2>/dev/null || true
}

# Trap to cleanup on exit
trap cleanup_ssh_connection EXIT INT TERM

# Determine if we need sudo (not needed when connecting as root)
if [ "$SSH_USER" = "root" ]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi

# Function to run command on remote server (reuses connection)
run_remote() {
    # Just run the command - ControlMaster will handle connection reuse automatically
    # Use -n to prevent reading from stdin (prevents hanging)
    # Redirect stdin from /dev/null to ensure non-interactive mode
    ssh $SSH_OPTS -n "$SSH_USER@$SERVER_HOST" "$@" < /dev/null
}

# Function to run sudo command (skips sudo if already root)
run_remote_sudo() {
    if [ "$SSH_USER" = "root" ]; then
        # No sudo needed when connecting as root
        run_remote "$@"
    else
        run_remote "sudo $@"
    fi
}

# Setup SSH connection reuse (user enters passphrase once here)
setup_ssh_connection

echo ""
echo "🔍 Verifying server connection..."
# Use a simple direct SSH call for verification (avoid run_remote which might hang)
if ssh $SSH_OPTS -o ConnectTimeout=5 "$SSH_USER@$SERVER_HOST" 'echo Connection successful' > /dev/null 2>&1; then
    echo "✅ Server connection OK (connection will be reused for all commands)"
else
    echo "❌ Cannot connect to server. Check SSH credentials."
    cleanup_ssh_connection
    exit 1
fi

# Check if passwordless sudo is configured (when not connecting as root)
if [ "$SSH_USER" != "root" ]; then
    echo "🔍 Checking sudo configuration..."
    if ssh $SSH_OPTS -n "$SSH_USER@$SERVER_HOST" 'sudo -n true' < /dev/null 2>/dev/null; then
        echo "✅ Passwordless sudo is configured"
    else
        echo "⚠️  WARNING: Passwordless sudo is not configured for $SSH_USER"
        echo "   The script requires passwordless sudo to run commands."
        echo "   Please run this script as root first to configure the server,"
        echo "   or configure passwordless sudo manually:"
        echo "   echo '$SSH_USER ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/$SSH_USER"
        echo ""
        read -p "Continue anyway? (y/n): " CONTINUE_SUDO
        CONTINUE_SUDO=$(echo "$CONTINUE_SUDO" | tr '[:upper:]' '[:lower:]' | cut -c1)
        if [ "$CONTINUE_SUDO" != "y" ]; then
            echo "Aborted. Please configure passwordless sudo first."
            cleanup_ssh_connection
            exit 1
        fi
    fi
fi
echo ""

echo "📦 Installing required packages..."
echo "Installing curl and jq..."
run_remote_sudo "apt-get update && apt-get install -y curl jq"

echo "Installing Docker..."
run_remote_sudo "apt-get install -y ca-certificates curl gnupg lsb-release"

echo "Adding Docker's official GPG key..."
# Download GPG key first, then process it (avoids TTY issue)
run_remote_sudo "install -m 0755 -d /etc/apt/keyrings"
run_remote "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.gpg"
run_remote_sudo "gpg --dearmor --batch --yes -o /etc/apt/keyrings/docker.gpg /tmp/docker.gpg 2>/dev/null || gpg --dearmor -o /etc/apt/keyrings/docker.gpg /tmp/docker.gpg"
run_remote_sudo "chmod a+r /etc/apt/keyrings/docker.gpg && rm -f /tmp/docker.gpg"

echo "Setting up Docker repository..."
run_remote "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | $SUDO_CMD tee /etc/apt/sources.list.d/docker.list > /dev/null"

echo "Installing Docker Engine and Docker Compose..."
run_remote_sudo "apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"

echo ""
echo "📁 Creating directory structure..."

# Determine the user for directory creation
if [ "$SSH_USER" = "root" ]; then
    TARGET_USER="devops"
    # Create devops user first if connecting as root
    run_remote "id -u devops &>/dev/null || sudo adduser --disabled-password --gecos '' devops"
    run_remote "sudo usermod -aG sudo devops"
    
    # Configure passwordless sudo for devops user (required for automation)
    echo "🔐 Configuring passwordless sudo for devops user..."
    run_remote "echo 'devops ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/devops > /dev/null"
    run_remote "sudo chmod 0440 /etc/sudoers.d/devops"
    echo "✅ Passwordless sudo configured for devops user"
    
    # Copy SSH key to devops user
    echo "🔑 Setting up SSH key for devops user..."
    PUBLIC_KEY_FILE="${SSH_KEY}.pub"
    if [ ! -f "$PUBLIC_KEY_FILE" ]; then
        echo "⚠️  Public key not found: $PUBLIC_KEY_FILE"
        echo "⚠️  You'll need to manually add your SSH key to devops user"
    else
        PUBLIC_KEY=$(cat "$PUBLIC_KEY_FILE")
        run_remote "sudo mkdir -p /home/devops/.ssh"
        run_remote "echo '$PUBLIC_KEY' | sudo tee /home/devops/.ssh/authorized_keys > /dev/null"
        run_remote "sudo chmod 700 /home/devops/.ssh"
        run_remote "sudo chmod 600 /home/devops/.ssh/authorized_keys"
        run_remote "sudo chown -R devops:devops /home/devops/.ssh"
        echo "✅ SSH key copied to devops user"
    fi
    
    # Generate CI/CD SSH key (no passphrase, dedicated for GitHub Actions)
    echo ""
    echo "🔑 Generating CI/CD SSH key for GitHub Actions..."
    echo "   This key will be used by GitHub Actions workflows (no passphrase)"
    
    # Generate key on the server as devops user (skip if already exists)
    run_remote "sudo -u devops test -f /home/devops/.ssh/id_cicd || sudo -u devops ssh-keygen -t ed25519 -f /home/devops/.ssh/id_cicd -N '' -C 'github-actions-cicd-$(date +%Y%m%d)' -q"
    
    # Get the CI/CD public key and add it to authorized_keys (if not already there)
    CICD_PUBLIC_KEY=$(run_remote "sudo cat /home/devops/.ssh/id_cicd.pub")
    if ! run_remote "sudo grep -q 'github-actions-cicd' /home/devops/.ssh/authorized_keys 2>/dev/null"; then
        run_remote "echo '$CICD_PUBLIC_KEY' | sudo tee -a /home/devops/.ssh/authorized_keys > /dev/null"
        echo "✅ CI/CD public key added to authorized_keys"
    else
        echo "✅ CI/CD public key already in authorized_keys"
    fi
    
    # Get the private key to display
    CICD_PRIVATE_KEY=$(run_remote "sudo cat /home/devops/.ssh/id_cicd")
    
    echo "✅ CI/CD SSH key generated"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  IMPORTANT: Add this private key to GitHub Secrets as SSH_KEY:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$CICD_PRIVATE_KEY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Save to local file for convenience
    CICD_KEY_FILE="$HOME/.ssh/${SERVER_HOST//[^a-zA-Z0-9]/_}_cicd_key"
    echo "$CICD_PRIVATE_KEY" > "$CICD_KEY_FILE"
    chmod 600 "$CICD_KEY_FILE"
    echo "💾 Private key also saved to: $CICD_KEY_FILE"
    echo "   You can copy it from there if needed"
    echo ""
    
    run_remote "sudo mkdir -p /home/devops/n8n-playground/{caddy_config,postgres-init,local_files}"
    run_remote "sudo mkdir -p /home/devops/gh-runner"
    run_remote "sudo chown -R devops:devops /home/devops"
else
    # Not root, so no CI/CD key generated
    CICD_KEY_FILE=""
    TARGET_USER="$SSH_USER"
    run_remote "mkdir -p ~/n8n-playground/{caddy_config,postgres-init,local_files}"
    run_remote "mkdir -p ~/gh-runner"
fi

echo ""
echo "🔥 Configuring firewall..."
echo "⚠️  Configuring firewall rules BEFORE enabling to prevent SSH lockout..."

# Check current UFW status
UFW_ENABLED=$(run_remote "sudo ufw status | grep -i 'Status: active' && echo 'yes' || echo 'no'")

# If UFW is enabled, temporarily disable it to configure rules safely
if echo "$UFW_ENABLED" | grep -q "yes"; then
    echo "Firewall is active. Temporarily disabling to configure rules..."
    run_remote "sudo ufw --force disable"
fi

# Configure firewall rules (UFW is now disabled, so no risk of lockout)
# Reset to start fresh (this is safe when UFW is disabled)
run_remote "sudo ufw --force reset || true"

# Set default policies
run_remote "sudo ufw default deny incoming"
run_remote "sudo ufw default allow outgoing"

# CRITICAL: Add SSH rule FIRST before enabling
echo "Adding firewall rules..."
# Add SSH rule and verify command succeeded
if ! run_remote "sudo ufw allow 22/tcp comment 'SSH'" > /dev/null 2>&1; then
    echo "❌ ERROR: Failed to add SSH rule!"
    exit 1
fi
echo "✅ SSH rule added"

run_remote "sudo ufw allow 80/tcp comment 'HTTP'"
run_remote "sudo ufw allow 443/tcp comment 'HTTPS'"

# Note: When UFW is disabled, 'ufw status' doesn't show rules
# But since 'ufw allow' succeeded, the rule is added to the configuration
echo "✅ Firewall rules configured (SSH, HTTP, HTTPS)"

# Now safely enable firewall (SSH rule is already configured)
echo "Enabling firewall with SSH access preserved..."
run_remote "sudo ufw --force enable"

# Final verification - now that UFW is enabled, we can check status
echo ""
echo "Verifying firewall configuration..."
sleep 2  # Give UFW a moment to apply rules
SSH_RULE_VERIFY=$(run_remote "sudo ufw status numbered | grep -E '22.*tcp|22/tcp' || echo 'NOT_FOUND'")
if echo "$SSH_RULE_VERIFY" | grep -q "NOT_FOUND"; then
    echo "⚠️  WARNING: Could not verify SSH rule in firewall status"
    echo "However, the rule was added before enabling, so it should be active."
    echo "Please verify manually: sudo ufw status"
else
    echo "✅ SSH rule verified: $SSH_RULE_VERIFY"
fi

echo ""
echo "Firewall status:"
run_remote "sudo ufw status numbered"
echo "✅ Firewall configured (SSH access preserved)"

echo ""
echo "🐳 Configuring Docker..."

# Determine target user for Docker configuration
if [ "$SSH_USER" = "root" ]; then
    SSH_USER_FOR_DOCKER="devops"
    echo "⚠️  Running as root. Using devops user for Docker configuration."
else
    SSH_USER_FOR_DOCKER="$SSH_USER"
fi

# Add user to docker group
run_remote "sudo usermod -aG docker $SSH_USER_FOR_DOCKER || true"

# Start Docker service
run_remote "sudo systemctl start docker || true"
run_remote "sudo systemctl enable docker || true"

echo "✅ Docker configured"
if [ "$SSH_USER" = "root" ]; then
    echo "⚠️  Created devops user and directories in /home/devops/"
    echo "⚠️  For security, switch to devops user for future operations:"
    echo "   ssh -i $SSH_KEY devops@$SERVER_HOST"
fi

echo ""
echo "🔐 Setting up SSH hardening (LAST STEP - DO THIS AFTER TESTING)..."
echo ""
if [ "$SSH_USER" = "root" ]; then
    echo "⚠️  CRITICAL: Before enabling SSH hardening, you MUST test SSH as devops user!"
    echo "⚠️  Run this command in a NEW terminal window:"
    echo "   ssh -i $SSH_KEY devops@$SERVER_HOST"
    echo ""
    echo "⚠️  Only proceed if the devops SSH connection works!"
    echo ""
    while true; do
        read -p "Have you tested SSH as devops user? (y/n): " TESTED_SSH
        TESTED_SSH=$(echo "$TESTED_SSH" | tr '[:upper:]' '[:lower:]' | cut -c1)  # Normalize: take first char, lowercase
        if [ "$TESTED_SSH" = "y" ]; then
            break
        elif [ "$TESTED_SSH" = "n" ]; then
            echo "⚠️  Skipping SSH hardening. Please test devops SSH first, then run this script again."
            echo ""
            echo "✅ Server setup complete (SSH hardening skipped)!"
            echo ""
            echo "📝 Next steps:"
            echo "1. Test SSH as devops user: ssh -i $SSH_KEY devops@$SERVER_HOST"
            echo "2. If successful, run this script again and enable SSH hardening"
            echo "3. Logout and login again (for Docker group to take effect)"
            echo "4. Run GitHub setup script: ./scripts/setup-github.sh"
            cleanup_ssh_connection
            exit 0
        else
            echo "⚠️  Please enter 'y' for yes or 'n' for no"
        fi
    done
fi

echo "⚠️  This will disable root SSH and password auth. Make sure you can SSH as devops!"
while true; do
    read -p "Configure SSH hardening NOW? (y/n): " HARDEN_SSH
    HARDEN_SSH=$(echo "$HARDEN_SSH" | tr '[:upper:]' '[:lower:]' | cut -c1)  # Normalize: take first char, lowercase
    if [ "$HARDEN_SSH" = "y" ] || [ "$HARDEN_SSH" = "n" ]; then
        break
    else
        echo "⚠️  Please enter 'y' for yes or 'n' for no"
    fi
done

if [ "$HARDEN_SSH" = "y" ]; then
    # Determine which user to allow SSH access
    if [ "$SSH_USER" = "root" ]; then
        ALLOWED_USER="devops"
    else
        ALLOWED_USER="$SSH_USER"
    fi
    
    echo "🔧 Applying SSH hardening configuration..."
    run_remote "sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config"
    run_remote "sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config"
    run_remote "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config"
    run_remote "sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config"
    run_remote "sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config"
    run_remote "sudo sed -i '/^AllowUsers/d' /etc/ssh/sshd_config"  # Remove existing AllowUsers
    run_remote "echo 'AllowUsers $ALLOWED_USER' | sudo tee -a /etc/ssh/sshd_config"
    
    echo ""
    echo "⚠️  SSH config updated to allow only $ALLOWED_USER user"
    echo "⚠️  Testing SSH config before restarting service..."
    
    # Test SSH config without restarting
    if run_remote "sudo sshd -t" 2>/dev/null; then
        echo "✅ SSH config is valid"
        echo ""
        echo "⚠️  IMPORTANT: SSH service will restart."
        echo "⚠️  This will disconnect your current root session!"
        echo "⚠️  Make sure you can connect as $ALLOWED_USER before proceeding!"
        echo ""
        while true; do
            read -p "Continue with SSH restart? (y/n): " RESTART_SSH
            RESTART_SSH=$(echo "$RESTART_SSH" | tr '[:upper:]' '[:lower:]' | cut -c1)  # Normalize
            if [ "$RESTART_SSH" = "y" ] || [ "$RESTART_SSH" = "n" ]; then
                break
            else
                echo "⚠️  Please enter 'y' for yes or 'n' for no"
            fi
        done
        if [ "$RESTART_SSH" = "y" ]; then
            echo "🔄 Restarting SSH service..."
            run_remote "sudo systemctl restart ssh" || echo "⚠️  SSH restart command sent (connection may be lost)"
            echo ""
            echo "✅ SSH hardening applied and service restarted"
            echo "⚠️  Your current root session may be disconnected"
            echo "⚠️  Connect as $ALLOWED_USER: ssh -i $SSH_KEY $ALLOWED_USER@$SERVER_HOST"
        else
            echo "⚠️  SSH config updated but NOT restarted"
            echo "⚠️  Restart manually when ready: sudo systemctl restart ssh"
        fi
    else
        echo "❌ SSH config test failed! Not restarting SSH service."
        echo "⚠️  Please check SSH config manually: sudo sshd -t"
    fi
else
    echo "⚠️  SSH hardening skipped"
fi

echo ""
echo "✅ Server setup complete!"
echo ""
if [ "$SSH_USER" = "root" ]; then
    echo "📝 Important Notes:"
    echo "   - devops user created with SSH key access"
    echo "   - Connect as devops: ssh -i $SSH_KEY devops@$SERVER_HOST"
    if [ "$HARDEN_SSH" = "y" ]; then
        echo "   - SSH hardening enabled - root SSH is now disabled"
    fi
    echo ""
fi
echo "📝 Next steps:"
echo "1. Connect as devops user: ssh -i $SSH_KEY devops@$SERVER_HOST"
echo "2. Logout and login again (for Docker group to take effect)"
if [ "$SSH_USER" = "root" ] && [ -n "${CICD_KEY_FILE:-}" ]; then
    echo "3. Add CI/CD SSH key to GitHub Secrets (see above output)"
    echo "   Key file location: $CICD_KEY_FILE"
    echo "4. Run GitHub setup script: ./scripts/setup-github.sh"
    echo "   (When prompted for SSH key, use the CI/CD key from: $CICD_KEY_FILE)"
    echo "5. Deploy runner via GitHub Actions"
    echo "6. Deploy application via GitHub Actions"
else
    echo "3. Run GitHub setup script: ./scripts/setup-github.sh"
    echo "4. Deploy runner via GitHub Actions"
    echo "5. Deploy application via GitHub Actions"
fi

# Cleanup SSH connection
cleanup_ssh_connection

