# GitHub Push Setup for Production

This document explains how to configure automated git pushes to GitHub from production servers, particularly when running as a non-interactive user (e.g., `notes` user).

## Overview

The export scripts (`exportAndPushToGitHub.sh`, `exportAndPushCSVToGitHub.sh`) need to push changes to the `OSM-Notes-Data` repository. In production, this typically runs as the `notes` user via cron, which requires special configuration.

## Option 1: SSH Keys (Recommended)

### Setup Steps

1. **Generate SSH key for the `notes` user** (if not exists):

```bash
# Switch to notes user
sudo su - notes

# Generate SSH key (if doesn't exist)
ssh-keygen -t ed25519 -C "notes@production-server" -f ~/.ssh/id_ed25519_github
# Press Enter to accept default location
# Optionally set a passphrase (or leave empty for automated use)

# Start SSH agent
eval "$(ssh-agent -s)"

# Add key to agent
ssh-add ~/.ssh/id_ed25519_github
```

2. **Add public key to GitHub**:

```bash
# Display public key
cat ~/.ssh/id_ed25519_github.pub
```

Then:
- Go to GitHub → Settings → SSH and GPG keys
- Click "New SSH key"
- Paste the public key content
- Save

3. **Test SSH connection**:

```bash
ssh -T git@github.com
# Should see: "Hi OSMLatam! You've successfully authenticated..."
```

4. **Configure git to use SSH**:

```bash
cd ~/github/OSM-Notes-Data

# Check current remote URL
git remote -v

# If using HTTPS, switch to SSH
git remote set-url origin git@github.com:OSMLatam/OSM-Notes-Data.git

# Verify
git remote -v
```

5. **Test push**:

```bash
# Make a test change
echo "# Test" >> README.md
git add README.md
git commit -m "Test push"
git push origin main
```

## Option 2: Personal Access Token (PAT)

### Setup Steps

1. **Create Personal Access Token on GitHub**:

- Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
- Click "Generate new token (classic)"
- Name: `OSM-Notes-Data-Auto-Push`
- Expiration: Set appropriate expiration (or no expiration for automation)
- Scopes: Check `repo` (full control of private repositories)
- Generate token
- **Copy the token immediately** (you won't see it again)

2. **Configure git credential helper**:

```bash
# Switch to notes user
sudo su - notes

# Configure credential helper to store token
git config --global credential.helper store

# Or use cache (temporary, expires after 15 minutes)
# git config --global credential.helper cache
```

3. **Store credentials** (one-time setup):

```bash
cd ~/github/OSM-Notes-Data

# This will prompt for username and password
# Username: your-github-username
# Password: paste the Personal Access Token (not your GitHub password)
git push origin main

# Credentials are now stored in ~/.git-credentials
```

4. **Alternative: Set credentials in URL** (less secure):

```bash
# Set remote URL with token embedded
git remote set-url origin https://YOUR_TOKEN@github.com/OSMLatam/OSM-Notes-Data.git
```

**Security Note**: This method stores credentials in plain text. Use with caution.

## Option 3: Deploy Key (Read-Write)

For repository-specific access:

1. **Generate deploy key**:

```bash
sudo su - notes
ssh-keygen -t ed25519 -C "notes-deploy-key" -f ~/.ssh/deploy_key_osm_notes_data
```

2. **Add to GitHub**:

- Go to repository → Settings → Deploy keys
- Click "Add deploy key"
- Title: `Production Server - notes user`
- Key: Paste `~/.ssh/deploy_key_osm_notes_data.pub`
- **Check "Allow write access"** (important!)
- Add key

3. **Configure SSH**:

```bash
# Create/edit SSH config
cat >> ~/.ssh/config << 'EOF'
Host github-osm-notes-data
  HostName github.com
  User git
  IdentityFile ~/.ssh/deploy_key_osm_notes_data
  IdentitiesOnly yes
EOF

# Set permissions
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/deploy_key_osm_notes_data
```

4. **Update remote URL**:

```bash
cd ~/github/OSM-Notes-Data
git remote set-url origin git@github-osm-notes-data:OSMLatam/OSM-Notes-Data.git
```

5. **Test**:

```bash
ssh -T git@github-osm-notes-data
git push origin main
```

## Verification

After setup, test the export script:

```bash
# As notes user
sudo su - notes
cd ~/github/OSM-Notes-Analytics
./bin/dwh/exportAndPushCSVToGitHub.sh
```

## Troubleshooting

### "Permission denied (publickey)"

- Verify SSH key is added to GitHub
- Check SSH connection: `ssh -T git@github.com`
- Verify key is loaded: `ssh-add -l`

### "Authentication failed"

- Verify Personal Access Token is valid and has `repo` scope
- Check credential helper: `git config --global credential.helper`
- Try clearing credentials: `git credential reject https://github.com`

### "Repository not found"

- Verify repository exists and user has access
- Check remote URL: `git remote -v`
- Verify SSH key or token has correct permissions

### Cron job fails silently

- Check cron logs: `/var/log/cron` or `journalctl -u cron`
- Add logging to cron job:
  ```bash
  0 3 1 * * /path/to/exportAndPushCSVToGitHub.sh >> /var/log/osm-csv-export.log 2>&1
  ```

## Security Best Practices

1. **Use SSH keys** when possible (more secure than tokens)
2. **Use deploy keys** for repository-specific access
3. **Set token expiration** if using PAT
4. **Restrict token scopes** to minimum required (`repo` only)
5. **Rotate credentials** periodically
6. **Monitor access** in GitHub → Settings → Security → Access log

## Production Checklist

- [ ] SSH key or PAT configured for `notes` user
- [ ] Git remote URL configured correctly
- [ ] Test push successful: `git push origin main`
- [ ] Export script tested: `./bin/dwh/exportAndPushCSVToGitHub.sh`
- [ ] Cron job configured with logging
- [ ] Monitoring/alerting for failed pushes

## Related Documentation

- [Cron Configuration](../etc/cron.example)
- [Export Scripts](../bin/dwh/README.md)
- [GitHub Actions Setup](./CI_CD_Guide.md)

