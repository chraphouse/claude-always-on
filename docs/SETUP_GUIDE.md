# Setup Guide

Step-by-step instructions for setting up Claude Always-On Agent on your Mac.

> **Before you start:** Read [SECURITY.md](./SECURITY.md). This project must run on a **dedicated, isolated machine** — not your personal computer. Use a Mac Mini with a fresh install and dummy account, a VM, or a cloud Mac. See the security guide for full details.

## Prerequisites

### 0. Prepare a Dedicated Machine

This is the most important step. You need a machine that:
- Has a **fresh macOS install** with a **dummy user account**
- Is **NOT signed into** your personal iCloud, email, or any sensitive accounts
- Has **no SSH keys** to production servers
- Has **no password managers** with real credentials

Good options: spare Mac Mini, UTM/Parallels VM, AWS EC2 Mac, MacStadium.


### 1. Install Claude Code CLI

Follow the official instructions: https://docs.anthropic.com/en/docs/claude-code

Verify it's installed:
```bash
claude --version
```

### 2. Install Python 3.10+

macOS comes with Python, but you may need a newer version:
```bash
# Via Homebrew
brew install python@3.12

# Verify
python3 --version
```

### 3. Install tmux

```bash
brew install tmux
```

### 4. Set Up an Email Account

You need an email account that Claude will monitor. **We recommend creating a dedicated email** rather than using your primary one.

#### Yahoo Mail (Recommended — easy app password setup)
1. Create or use a Yahoo account
2. Go to **Account Info** → **Account Security**
3. Enable **Two-Step Verification** if not already enabled
4. Click **Generate app password**
5. Select "Other App", name it "Claude Agent"
6. Save the 16-character password

#### Gmail
1. Enable **2-Step Verification** at https://myaccount.google.com/security
2. Go to **App Passwords** (search in Google Account settings)
3. Generate a password for "Mail" on "Mac"
4. Save the 16-character password

#### Other Providers
Any provider with IMAP + SMTP works. You'll need:
- IMAP server address + port (usually 993)
- SMTP server address + port (usually 465 or 587)
- An app-specific password

## Installation

### Quick Install

```bash
git clone https://github.com/chraphouse/claude-always-on.git
cd claude-always-on
chmod +x install.sh uninstall.sh
./install.sh
```

The installer will interactively ask for your email credentials and configure everything.

### Manual Install

If you prefer to configure first:

```bash
git clone https://github.com/chraphouse/claude-always-on.git
cd claude-always-on

# Copy and edit config
cp config.example.env config.env
nano config.env  # Fill in your details

# Run installer (it will use your config.env)
./install.sh
```

## Post-Install Verification

### Check the email watcher is running
```bash
launchctl list | grep email-watcher
# Should show: <PID>  0  com.claude.email-watcher
```

### Check logs
```bash
cat ~/logs/email-watcher.log
# Should show: "No new emails." (if no emails pending)
```

### Test sending an email
```bash
python3 ~/scripts/email_utils.py send "Test" "Hello from Claude agent!"
# Check your personal email for the test message
```

### Test receiving an email
1. Send an email **from your personal email** to the agent email
2. Wait up to 3 minutes (or run manually):
   ```bash
   python3 ~/scripts/email_utils.py check
   ```
3. You should see the email content printed

## Starting Claude

### Manual start
```bash
claude --dangerously-skip-permissions
```

### Auto-start on boot
The installer creates a LaunchAgent that starts Claude in a tmux session on login. To activate it:
```bash
launchctl load ~/Library/LaunchAgents/com.claude.agent.plist
```

To attach to the running session:
```bash
tmux attach -t claude
```

## Troubleshooting

### Email watcher not running
```bash
# Check status
launchctl list | grep email-watcher

# View logs
cat ~/logs/email-watcher.log

# Restart
launchctl unload ~/Library/LaunchAgents/com.claude.email-watcher.plist
launchctl load ~/Library/LaunchAgents/com.claude.email-watcher.plist
```

### Emails not being received
1. Check spam/bulk folder settings in config.env (`CHECK_FOLDERS`)
2. Verify the "From" email matches `PERSONAL_EMAIL` exactly
3. Test IMAP connection manually:
   ```bash
   python3 -c "
   import imaplib, ssl
   ctx = ssl.create_default_context()
   m = imaplib.IMAP4_SSL('imap.mail.yahoo.com', 993, ssl_context=ctx)
   m.login('your-email@yahoo.com', 'your-app-password')
   print('Login OK')
   m.select('INBOX')
   print('INBOX selected')
   "
   ```

### Claude not starting in tmux
```bash
# Check if tmux session exists
tmux list-sessions

# Manually create one
tmux new-session -d -s claude "claude --dangerously-skip-permissions"

# Attach
tmux attach -t claude
```

### Config file not found
The scripts look for config in two places:
1. `<repo>/config.env` (development)
2. `~/.claude-always-on/config.env` (installed)

Make sure one of these exists.
