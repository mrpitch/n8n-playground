# Avoiding SSH Passphrase Prompts

## Best Solution: Use ssh-agent (Recommended)

**Add your key to ssh-agent before running the setup script:**

```bash
# Add your SSH key to ssh-agent (enter passphrase once)
ssh-add ~/.ssh/id_mrpsrvn8n

# Verify it's loaded
ssh-add -l

# Now run the setup script - no passphrase prompts!
./scripts/setup-server.sh
```

**To make ssh-agent persistent (survives terminal restarts):**

Add this to your `~/.zshrc` or `~/.bashrc`:

```bash
# Start ssh-agent if not running
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_mrpsrvn8n 2>/dev/null
fi
```

## Alternative: ControlMaster (Built into Script)

The setup script now uses SSH ControlMaster to cache your passphrase for 10 minutes. You'll enter it **once** at the beginning, and all subsequent commands will reuse that connection.

## Troubleshooting

**If you're still being asked for passphrase multiple times:**

1. Check if ssh-agent is running:
   ```bash
   ssh-add -l
   ```

2. If not, add your key:
   ```bash
   ssh-add ~/.ssh/id_mrpsrvn8n
   ```

3. Verify the key is loaded:
   ```bash
   ssh-add -l
   ```

4. Check ControlMaster connection:
   ```bash
   ls -la /tmp/ssh_control_*/
   ```

**Note:** The script automatically detects if your key is in ssh-agent and will use it, eliminating all passphrase prompts.

