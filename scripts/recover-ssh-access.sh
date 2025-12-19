#!/bin/bash
set -e

# SSH Access Recovery Script
# Use this if you're locked out after SSH hardening

echo "🔓 SSH Access Recovery Script"
echo "=============================="
echo ""
echo "This script helps recover SSH access if hardening or firewall locked you out."
echo ""
echo "Common causes:"
echo "  - Firewall (UFW) blocking SSH"
echo "  - SSH hardening (AllowUsers, PermitRootLogin)"
echo ""
echo "Options:"
echo "1. If you have Hetzner Console access, use that (RECOMMENDED)"
echo "2. If you can still connect, this script will fix firewall/SSH config"
echo ""

read -p "Server hostname/IP: " SERVER_HOST
read -p "SSH key path (default: ~/.ssh/id_rsa): " SSH_KEY
SSH_KEY=${SSH_KEY:-~/.ssh/id_rsa}
SSH_KEY="${SSH_KEY/#\~/$HOME}"

if [ ! -f "$SSH_KEY" ]; then
    echo "❌ SSH key not found: $SSH_KEY"
    exit 1
fi

echo ""
echo "Attempting to connect as root..."
if ssh -i "$SSH_KEY" "root@$SERVER_HOST" "echo 'Root access OK'" 2>/dev/null; then
    echo "✅ Root access still works!"
    echo ""
    echo "Checking firewall and SSH configuration..."
    ssh -i "$SSH_KEY" "root@$SERVER_HOST" << 'EOF'
        # Backup current configs
        sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
        
        echo "Checking firewall status..."
        UFW_STATUS=$(sudo ufw status | grep -i 'Status: active' || echo 'inactive')
        echo "Firewall status: $UFW_STATUS"
        
        # Fix firewall - ensure SSH is allowed
        if echo "$UFW_STATUS" | grep -q "active"; then
            echo "Firewall is active. Checking SSH rule..."
            if ! sudo ufw status | grep -q "22/tcp"; then
                echo "⚠️  SSH rule missing! Adding SSH rule..."
                sudo ufw allow 22/tcp
                sudo ufw reload
                echo "✅ SSH rule added to firewall"
            else
                echo "✅ SSH rule exists in firewall"
            fi
        else
            echo "Firewall is inactive"
        fi
        
        # Fix SSH hardening
        echo ""
        echo "Checking SSH configuration..."
        if grep -q "PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null || grep -q "^AllowUsers" /etc/ssh/sshd_config 2>/dev/null; then
            echo "SSH hardening detected. Reverting..."
            sudo sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
            sudo sed -i '/^AllowUsers/d' /etc/ssh/sshd_config
            
            # Test config
            if sudo sshd -t; then
                echo "✅ SSH config is valid"
                echo "⚠️  Restarting SSH service..."
                sudo systemctl restart ssh
                echo "✅ SSH service restarted"
                echo "✅ SSH hardening reverted"
            else
                echo "❌ SSH config test failed!"
                echo "Restoring backup..."
                sudo cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config 2>/dev/null || true
                exit 1
            fi
        else
            echo "✅ SSH config is permissive (no hardening detected)"
        fi
EOF
    echo ""
    echo "✅ SSH hardening reverted. Root access restored."
    echo ""
    echo "📝 Next steps:"
    echo "1. Test root SSH: ssh -i $SSH_KEY root@$SERVER_HOST"
    echo "2. Test devops SSH: ssh -i $SSH_KEY devops@$SERVER_HOST"
    echo "3. Re-run setup-server.sh and enable SSH hardening AFTER testing devops access"
elif ssh -i "$SSH_KEY" "devops@$SERVER_HOST" "echo 'Devops access OK'" 2>/dev/null; then
    echo "✅ Devops access works! SSH hardening is active."
    echo ""
    echo "You can continue using devops user for all operations."
    echo "To revert SSH hardening (if needed), connect via Hetzner Console"
    echo "or use this script with root access."
else
    echo "❌ Cannot connect as root or devops!"
    echo ""
    echo "🔧 Recovery via Hetzner Console (REQUIRED):"
    echo ""
    echo "1. Log into Hetzner Cloud Console: https://console.hetzner.cloud"
    echo "2. Open your server (IP: $SERVER_HOST)"
    echo "3. Click 'Console' tab (browser-based terminal)"
    echo "4. Run these commands to fix firewall and SSH:"
    echo ""
    echo "   # Fix firewall - allow SSH first"
    echo "   sudo ufw allow 22/tcp"
    echo "   sudo ufw reload"
    echo ""
    echo "   # Check firewall status"
    echo "   sudo ufw status"
    echo ""
    echo "   # If still locked out, temporarily disable firewall"
    echo "   sudo ufw disable"
    echo ""
    echo "   # Fix SSH config (if SSH hardening was applied)"
    echo "   sudo sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config"
    echo "   sudo sed -i '/^AllowUsers/d' /etc/ssh/sshd_config"
    echo "   sudo systemctl restart ssh"
    echo ""
    echo "5. Try connecting again:"
    echo "   ssh -i $SSH_KEY root@$SERVER_HOST"
    echo "   ssh -i $SSH_KEY devops@$SERVER_HOST"
    echo ""
    exit 1
fi

