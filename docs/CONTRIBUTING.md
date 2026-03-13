# Contributing

Thanks for your interest in Claude Always-On! Here's how to contribute.

## Getting Started

1. Fork the repo
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/claude-always-on.git`
3. Create a branch: `git checkout -b feature/my-feature`
4. Make your changes
5. Test locally (see below)
6. Commit: `git commit -m "feat: description"`
7. Push: `git push origin feature/my-feature`
8. Open a Pull Request

## Testing Locally

```bash
# Copy config
cp config.example.env config.env
# Fill in test email credentials
nano config.env

# Test email check
python3 scripts/email_utils.py check

# Test email send
python3 scripts/email_utils.py send "Test" "Test body"

# Test watcher
python3 scripts/email_watcher.py

# Run installer in dry mode (read through install.sh first)
./install.sh
```

## Areas for Contribution

### High Priority
- **Linux support**: systemd service files instead of LaunchAgents
- **Attachment support**: Send/receive file attachments
- **Multiple sender support**: Accept instructions from multiple email addresses
- **Encrypted config**: Encrypt credentials at rest

### Nice to Have
- Windows support (Task Scheduler)
- Webhook alternative to email (HTTP endpoint)
- Web dashboard for monitoring
- SMS/Telegram/Signal as alternative channels
- Rate limiting and abuse prevention
- Email threading (group related conversations)

## Commit Style

Use conventional commits:
- `feat: add attachment support`
- `fix: handle IMAP timeout gracefully`
- `docs: improve setup guide`
- `refactor: extract config loader`

## Code Style

- Python: Follow PEP 8, use type hints where helpful
- Shell: Use `set -euo pipefail`, quote variables
- Keep it simple — this project's value is in its simplicity
