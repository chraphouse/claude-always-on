#!/bin/bash
set -euo pipefail

echo "============================================"
echo "  Claude Always-On Agent — Uninstall"
echo "============================================"
echo ""

HOME_DIR="$HOME"
LAUNCH_AGENTS_DIR="$HOME_DIR/Library/LaunchAgents"

# Unload LaunchAgents
echo "Stopping LaunchAgents..."

WATCHER_PLIST="$LAUNCH_AGENTS_DIR/com.claude.email-watcher.plist"
if [ -f "$WATCHER_PLIST" ]; then
    launchctl unload "$WATCHER_PLIST" 2>/dev/null || true
    rm "$WATCHER_PLIST"
    echo "  Removed com.claude.email-watcher"
fi

AGENT_PLIST="$LAUNCH_AGENTS_DIR/com.claude.agent.plist"
if [ -f "$AGENT_PLIST" ]; then
    launchctl unload "$AGENT_PLIST" 2>/dev/null || true
    rm "$AGENT_PLIST"
    echo "  Removed com.claude.agent"
fi

# Remove scripts
echo ""
echo "Removing scripts..."
rm -f "$HOME_DIR/scripts/email_utils.py"
rm -f "$HOME_DIR/scripts/email_watcher.py"
echo "  Removed ~/scripts/email_utils.py"
echo "  Removed ~/scripts/email_watcher.py"

# Ask about data
echo ""
read -p "Remove email queue? (~/email-queue/) (y/n): " REMOVE_QUEUE
if [ "$REMOVE_QUEUE" = "y" ]; then
    rm -rf "$HOME_DIR/email-queue"
    echo "  Removed ~/email-queue/"
fi

read -p "Remove config? (~/.claude-always-on/) (y/n): " REMOVE_CONFIG
if [ "$REMOVE_CONFIG" = "y" ]; then
    rm -rf "$HOME_DIR/.claude-always-on"
    echo "  Removed ~/.claude-always-on/"
fi

read -p "Remove logs? (~/logs/email-watcher.log) (y/n): " REMOVE_LOGS
if [ "$REMOVE_LOGS" = "y" ]; then
    rm -f "$HOME_DIR/logs/email-watcher.log"
    rm -f "$HOME_DIR/logs/claude-agent.log"
    echo "  Removed log files"
fi

echo ""
echo "Note: The 24/7 Agent Mode section in ~/CLAUDE.md was NOT removed."
echo "Edit ~/CLAUDE.md manually to remove it if desired."
echo ""
echo "Uninstall complete."
