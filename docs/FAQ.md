# FAQ

## General

### What happens if my Mac loses power?
If you enabled the "harden macOS" option during install, your Mac will automatically restart when power returns. The LaunchAgents will start the email watcher and Claude automatically. Any emails you sent during downtime are queued and processed on startup.

### Does this work on Linux?
Not yet — the LaunchAgents are macOS-specific. A Linux version using systemd would be straightforward to add. PRs welcome!

### Does this work on Intel Macs?
Yes. The installer detects your Python path automatically. The only difference is Homebrew lives at `/usr/local/` instead of `/opt/homebrew/`.

### Can I use this with multiple email accounts?
Currently it monitors one email account. You could run multiple instances with different config files, but that's not officially supported yet.

### Is my email password safe?
Your app password is stored in `~/.claude-always-on/config.env` with standard file permissions. It's never committed to git. We recommend using an **app-specific password** (not your main password) so you can revoke it anytime.

## Email

### My emails aren't being picked up
1. **Check the sender matches:** Only emails from `PERSONAL_EMAIL` are processed
2. **Check spam folder:** Make sure `CHECK_FOLDERS` includes `Bulk` (Yahoo) or `[Gmail]/Spam` (Gmail)
3. **Check the watcher is running:** `launchctl list | grep email-watcher`
4. **Check logs:** `cat ~/logs/email-watcher.log`
5. **Test manually:** `python3 ~/scripts/email_utils.py check`

### Can I send instructions from multiple email addresses?
Currently only one `PERSONAL_EMAIL` is supported. You could modify `email_watcher.py` to accept a list, or just send from the configured address.

### How long can my email instructions be?
Email bodies are truncated to 2000 characters by default. Change `MAX_BODY_LENGTH` in config.env for longer instructions.

### Can Claude send me attachments?
The current `email_utils.py` sends plain text only. Adding attachment support would require extending the `send_email` function to use `MIMEBase`.

## Claude

### Claude isn't starting automatically
1. Check the LaunchAgent is loaded: `launchctl list | grep claude.agent`
2. Check logs: `cat ~/logs/claude-agent.log`
3. Verify Claude is installed: `which claude`
4. Try manually: `tmux new-session -d -s claude "claude --dangerously-skip-permissions"`

### Can I interact with Claude directly while it's in always-on mode?
Yes! Attach to the tmux session:
```bash
tmux attach -t claude
```
You can type commands directly. The email loop runs in the background and won't interfere.

### The 3-day cron expiry — will I lose the loop?
The in-session `/loop` auto-expires after 3 days. However, if Claude's session restarts (crash, reboot), it re-reads CLAUDE.md and sets up a fresh loop. So in practice, the loop is always active as long as Claude is running.

### How do I give Claude access to purchase things?
Include your budget and any card details in CLAUDE.md or tell Claude via email. Always set clear spending limits.

## Maintenance

### How do I update the scripts?
```bash
cd ~/path/to/claude-always-on
git pull
./install.sh  # Re-run installer — it will use existing config
```

### How do I change the check interval?
Edit `~/.claude-always-on/config.env` and change `CHECK_INTERVAL`, then:
```bash
launchctl unload ~/Library/LaunchAgents/com.claude.email-watcher.plist
launchctl load ~/Library/LaunchAgents/com.claude.email-watcher.plist
```

### How do I see what emails were processed?
```bash
ls ~/email-queue/processed/
cat ~/email-queue/processed/<filename>.json
```

### How do I completely remove this?
```bash
cd ~/path/to/claude-always-on
./uninstall.sh
```
