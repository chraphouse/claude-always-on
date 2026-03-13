# Claude Always-On Agent

Turn your Mac into a 24/7 Claude agent that you control via email. Send it tasks from your phone, get results back automatically.

> **IMPORTANT: Security Warning**
>
> This project runs Claude with `--dangerously-skip-permissions`, giving it **full, unsupervised access** to the machine — file system, shell, network, installed apps, everything. **Do NOT run this on a machine with personal accounts, sensitive data, or production credentials.**
>
> **You MUST use a dedicated, isolated machine:**
> - A Mac Mini / old laptop with a **fresh macOS install and a dummy user account**
> - A **virtual machine** (UTM, Parallels, VMware)
> - A **cloud Mac** (AWS EC2 Mac, MacStadium)
>
> **Do NOT run this on:**
> - Your daily driver laptop
> - A machine signed into your personal iCloud, 1Password, banking, etc.
> - A machine with SSH keys that have access to production servers
> - Any machine where an autonomous agent could cause real damage
>
> Think of this machine as a **sandboxed worker** — it should have only what the agent needs and nothing you'd regret it accessing.

## What It Does

- Checks your email every 3 minutes for instructions
- Queues emails to disk so nothing is lost during restarts
- Claude acts on instructions and emails you back with results
- Survives reboots, crashes, and session restarts automatically
- Hourly progress updates on long tasks, immediate delivery on completion

## Architecture

```
You (phone/laptop)
  │
  │  email
  ▼
┌─────────────────────────────┐
│  Email Watcher (launchd)    │  ← runs every 3 min, independent of Claude
│  Queues to ~/email-queue/   │
└─────────────┬───────────────┘
              │
              ▼
┌─────────────────────────────┐
│  Claude Code (tmux session) │  ← auto-starts on boot
│  Processes queue + live     │
│  check loop every 3 min    │
│  Emails results back to you │
└─────────────────────────────┘
```

## Requirements

- macOS (Apple Silicon or Intel)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- An email account with IMAP/SMTP access (Yahoo, Gmail app password, etc.)
- Python 3.10+

## Quick Start

```bash
git clone https://github.com/chraphouse/claude-always-on.git
cd claude-always-on
./install.sh
```

The installer will prompt you for:
1. Your **agent email** (the one Claude monitors) + app password
2. Your **personal email** (where you send instructions from & receive updates)
3. IMAP/SMTP server details (auto-detected for Yahoo and Gmail)

## Manual Setup

If you prefer to set things up yourself:

1. Copy config and fill in your details:
   ```bash
   cp config.example.env config.env
   nano config.env
   ```

2. Run the installer:
   ```bash
   ./install.sh
   ```

## What Gets Installed

| Component | Location | Purpose |
|-----------|----------|---------|
| Email utilities | `~/scripts/email_utils.py` | Send & receive emails |
| Email watcher | `~/scripts/email_watcher.py` | Queue emails to disk |
| Watcher LaunchAgent | `~/Library/LaunchAgents/com.claude.email-watcher.plist` | Run watcher every 3 min |
| Claude LaunchAgent | `~/Library/LaunchAgents/com.claude.agent.plist` | Auto-start Claude in tmux |
| Email queue | `~/email-queue/` | Pending + processed emails |
| Logs | `~/logs/` | Watcher and agent logs |
| CLAUDE.md snippet | Appended to `~/CLAUDE.md` | Startup instructions for Claude |

## How to Use

Once installed, just **send an email** to your agent email address from your personal email. Examples:

- *"Create a Python script that scrapes HN front page and save it to ~/projects/"*
- *"Check if my website is up and email me the status"*
- *"Research the best Node.js ORMs and send me a comparison"*
- *"Fix the bug in ~/projects/myapp/server.js — the /api/users endpoint returns 500"*

Claude will email you back with results, progress updates, or questions.

## Configuration

### Email Check Interval

Edit the LaunchAgent plist to change the interval (default 180 seconds):

```bash
# Change to 5 minutes (300 seconds)
sed -i '' 's/<integer>180</<integer>300</' ~/Library/LaunchAgents/com.claude.email-watcher.plist
launchctl unload ~/Library/LaunchAgents/com.claude.email-watcher.plist
launchctl load ~/Library/LaunchAgents/com.claude.email-watcher.plist
```

### Uninstall

```bash
./uninstall.sh
```

## Email Provider Setup

### Yahoo Mail
1. Go to Account Security → Generate app password
2. Use `imap.mail.yahoo.com` / `smtp.mail.yahoo.com`

### Gmail
1. Enable 2FA, then go to App Passwords → Generate
2. Use `imap.gmail.com` / `smtp.gmail.com`

### Other Providers
Any provider with IMAP + SMTP access works. You'll need:
- IMAP server + port (usually 993 for SSL)
- SMTP server + port (usually 465 for SSL or 587 for TLS)
- An app-specific password (if 2FA is enabled)

## Resilience

The system is designed to never lose an email:

- **Mac crashes?** Auto-restarts, LaunchAgents reload, Claude starts in tmux
- **Claude session dies?** tmux LaunchAgent restarts it, queued emails are processed on startup
- **Network blip?** Watcher retries on next 3-min cycle, emails stay unread until fetched
- **Power outage?** macOS auto-restart on power failure + everything above

## Security

**Read [docs/SECURITY.md](docs/SECURITY.md) before deploying.** Key points:

- Use a **dedicated machine** with a fresh macOS install and dummy account
- Never run on a machine with personal iCloud, banking, password managers, or production credentials
- Use a **dedicated email account** for the agent (not your personal email)
- If giving the agent spending access, use **prepaid/virtual cards with low limits**
- To kill the agent instantly: `tmux kill-session -t claude`

## Documentation

- [Setup Guide](docs/SETUP_GUIDE.md) — Step-by-step installation
- [Architecture](docs/ARCHITECTURE.md) — System design & data flow
- [Security](docs/SECURITY.md) — Isolation requirements & best practices
- [FAQ](docs/FAQ.md) — Common questions & troubleshooting
- [Contributing](docs/CONTRIBUTING.md) — How to contribute

## License

MIT
