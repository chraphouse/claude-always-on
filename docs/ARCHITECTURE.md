# Architecture

## Overview

Claude Always-On is a two-layer system that ensures your Claude agent never misses an email instruction, even through crashes and reboots.

```
┌──────────────────────────────────────────────────────────┐
│                    YOUR DEVICE                           │
│                  (phone, laptop)                         │
│                                                         │
│    You send an email to the agent email address          │
└────────────────────────┬─────────────────────────────────┘
                         │
                    IMAP/SMTP
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│                    YOUR MAC                              │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Layer 1: Email Watcher (launchd)               │    │
│  │  ─────────────────────────────────              │    │
│  │  • Runs every 3 min via macOS LaunchAgent       │    │
│  │  • Independent of Claude — pure Python          │    │
│  │  • Checks IMAP for unseen emails from you       │    │
│  │  • Deduplicates via SHA-256 hash                │    │
│  │  • Queues new emails as JSON to ~/email-queue/  │    │
│  │  • Survives: reboots, Claude crashes, anything  │    │
│  └──────────────────────┬──────────────────────────┘    │
│                         │                                │
│                    JSON files                            │
│                    on disk                               │
│                         │                                │
│                         ▼                                │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Layer 2: Claude Code (tmux session)            │    │
│  │  ─────────────────────────────────              │    │
│  │  • Auto-starts in tmux via LaunchAgent          │    │
│  │  • On startup: processes ~/email-queue/*.json   │    │
│  │  • Runs /loop 3m for live email checking        │    │
│  │  • Acts on instructions autonomously            │    │
│  │  • Emails results back via SMTP                 │    │
│  │  • Sends hourly progress updates                │    │
│  └─────────────────────────────────────────────────┘    │
│                                                         │
└──────────────────────────────────────────────────────────┘
```

## Components

### email_watcher.py
**Purpose:** Persistent, independent email checking that never goes down.

- Runs as a macOS LaunchAgent (launchd), not as part of Claude
- Checks IMAP server for unseen emails from the configured personal email
- Scans both Inbox and Bulk/spam folders
- Deduplicates using SHA-256 hash of Message-ID + Subject + Date
- Writes each new email as a timestamped JSON file to `~/email-queue/`
- Maintains a `.seen_ids` file to avoid reprocessing

### email_utils.py
**Purpose:** Email send/receive library used by Claude during sessions.

- `send_email(subject, body)` — sends via SMTP SSL
- `check_emails(unseen_only)` — checks IMAP for new messages
- CLI interface: `email_utils.py send|check|check-all`
- Config loaded from `config.env`

### LaunchAgents

#### com.claude.email-watcher.plist
- Runs `email_watcher.py` every N seconds (default: 180)
- Starts at login (`RunAtLoad`)
- Logs to `~/logs/email-watcher.log`

#### com.claude.agent.plist
- Starts Claude in a tmux session named "claude"
- Starts at login (`RunAtLoad`)
- Claude reads CLAUDE.md on startup, which tells it to process the queue and start the loop

### CLAUDE.md Snippet
Instructions appended to `~/CLAUDE.md` that tell Claude to:
1. Process any queued emails in `~/email-queue/`
2. Start the `/loop 3m` email check
3. Send an "I'm online" notification

## Data Flow

### Normal operation (Claude is running)
```
Email arrives → IMAP server
  → email_watcher.py queues to ~/email-queue/ (belt)
  → Claude /loop checks directly via email_utils.py (suspenders)
  → Claude acts on instruction
  → Claude emails result back
```

### Recovery (Claude was down)
```
Email arrives → IMAP server
  → email_watcher.py queues to ~/email-queue/
  [time passes, Claude restarts]
  → Claude reads CLAUDE.md startup instructions
  → Claude processes ~/email-queue/*.json
  → Claude moves processed to ~/email-queue/processed/
  → Claude emails result back
```

## File Layout

```
~/
├── scripts/
│   ├── email_utils.py          # Send/receive email library
│   └── email_watcher.py        # Standalone email queue daemon
├── email-queue/
│   ├── 20260313_143022_abc123.json   # Pending email
│   ├── .seen_ids               # Dedup tracking
│   └── processed/              # Completed emails
├── logs/
│   ├── email-watcher.log       # Watcher output
│   └── claude-agent.log        # Claude tmux output
├── Library/LaunchAgents/
│   ├── com.claude.email-watcher.plist
│   └── com.claude.agent.plist
├── .claude-always-on/
│   └── config.env              # Email credentials & settings
└── CLAUDE.md                   # Includes 24/7 startup instructions
```

## Security Considerations

- **Credentials** are stored in `~/.claude-always-on/config.env` (not in the repo)
- `config.env` is in `.gitignore` — never committed
- App passwords are used (not primary passwords)
- Only emails from the configured `PERSONAL_EMAIL` are processed
- Email bodies are truncated to prevent abuse (default 2000 chars)
