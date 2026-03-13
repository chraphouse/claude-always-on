# Security Guide

## The #1 Rule

**Run this on a dedicated, isolated machine — never on your personal computer.**

This project gives Claude autonomous, unsupervised access to a machine. That means:
- Full filesystem read/write
- Arbitrary shell command execution
- Network access (HTTP, SSH, etc.)
- Access to any installed apps and credentials on the machine

This is powerful, but it means the machine is the blast radius. Keep that blast radius small.

## Recommended Setup

### Dedicated Mac Mini (Best)
The ideal setup is a cheap/used Mac Mini with:
- Fresh macOS install
- A **new, dummy Apple ID** (not your personal one)
- A **new, dummy user account**
- No iCloud sign-in (or a throwaway iCloud)
- No personal apps (no 1Password, banking, personal email client)
- No SSH keys to production servers
- Only the tools Claude needs installed

### Virtual Machine (Good)
Run macOS in a VM using:
- **UTM** (free, Apple Silicon native)
- **Parallels** or **VMware Fusion**
- Snapshot before installing so you can roll back

### Cloud Mac (Also Good)
- AWS EC2 Mac instances
- MacStadium
- Scaleway Apple Silicon

## What to Put on the Machine

**Yes:**
- Claude Code CLI
- Python, Node.js, Go, etc. (dev tools)
- A dedicated email account for the agent (not your personal email)
- Git + GitHub CLI (with a scoped token if possible)
- Docker (for sandboxed workloads)

**No:**
- Personal iCloud account
- Password managers with real credentials
- SSH keys to production infrastructure
- Browser sessions signed into personal accounts
- Financial apps or banking credentials
- Company VPN credentials
- Real API keys with billing (unless budgeted and monitored)

## Email Account Security

- Create a **new, dedicated email** for the agent (e.g., `my-claude-agent@yahoo.com`)
- Use an **app-specific password**, not your main password
- This email should not be linked to anything sensitive
- You can revoke the app password anytime to cut off access

## Budget & Spending Controls

If you give the agent access to any paid services:
- Set hard spending limits on all accounts
- Use prepaid/virtual cards with low limits
- Monitor spending via email alerts
- Never give access to your primary bank account or credit card

## Network Isolation (Advanced)

For maximum security:
- Put the agent machine on a separate VLAN/subnet
- Use firewall rules to restrict outbound access
- Block access to internal network resources
- Only allow IMAP/SMTP + HTTPS outbound

## Monitoring

Keep an eye on your agent:
- Check `~/logs/email-watcher.log` periodically
- Review `~/email-queue/processed/` to see what was acted on
- Use Screen Sharing / VNC / RustDesk to visually check the machine
- Set up alerts if the agent stops responding to emails

## Incident Response

If something goes wrong:
1. **Kill Claude immediately:** `tmux kill-session -t claude`
2. **Stop the watcher:** `launchctl unload ~/Library/LaunchAgents/com.claude.email-watcher.plist`
3. **Revoke the email app password** from your email provider's security settings
4. **Review logs:** `cat ~/logs/email-watcher.log` and `~/email-queue/processed/`
5. **Rotate any credentials** that were on the machine
6. If the machine is compromised, wipe and reinstall macOS

## Summary

| Risk | Mitigation |
|------|-----------|
| Agent accesses personal data | Use a dedicated machine with no personal accounts |
| Agent spends money | Use prepaid cards with low limits |
| Agent accesses production | Don't put production SSH keys or credentials on the machine |
| Agent sends unwanted emails | It only sends to your configured personal email |
| Someone emails the agent | Only emails from your `PERSONAL_EMAIL` are processed |
| Machine is stolen | Enable FileVault, Find My Mac, remote wipe |
| Agent goes rogue | Kill tmux session, revoke email app password |
