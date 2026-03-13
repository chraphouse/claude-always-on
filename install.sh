#!/bin/bash
set -euo pipefail

# ============================================================
# Claude Always-On Agent — Installer
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="$HOME"
CONFIG_DIR="$HOME/.claude-always-on"
CONFIG_FILE="$CONFIG_DIR/config.env"

echo "============================================"
echo "  Claude Always-On Agent — Setup"
echo "============================================"
echo ""

# ----------------------------------------------------------
# 1. Check prerequisites
# ----------------------------------------------------------
echo "Checking prerequisites..."

if ! command -v python3 &>/dev/null; then
    echo "Error: python3 not found. Install Python 3.10+ first."
    exit 1
fi

if ! command -v claude &>/dev/null; then
    echo "Error: claude CLI not found. Install Claude Code first:"
    echo "  https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi

if ! command -v tmux &>/dev/null; then
    echo "tmux not found. Installing..."
    if command -v brew &>/dev/null; then
        brew install tmux
    else
        echo "Error: tmux not found and Homebrew not available. Install tmux manually."
        exit 1
    fi
fi

PYTHON_PATH="$(which python3)"
echo "  python3: $PYTHON_PATH"
echo "  claude:  $(which claude)"
echo "  tmux:    $(which tmux)"
echo ""

# ----------------------------------------------------------
# 2. Configuration
# ----------------------------------------------------------
mkdir -p "$CONFIG_DIR"

if [ -f "$CONFIG_FILE" ]; then
    echo "Existing config found at $CONFIG_FILE"
    read -p "Use existing config? (y/n): " USE_EXISTING
    if [ "$USE_EXISTING" != "y" ]; then
        rm "$CONFIG_FILE"
    fi
fi

if [ ! -f "$CONFIG_FILE" ]; then
    # Check if user pre-created config.env in the repo
    if [ -f "$SCRIPT_DIR/config.env" ]; then
        cp "$SCRIPT_DIR/config.env" "$CONFIG_FILE"
        echo "Using config.env from repo directory."
    else
        echo "Let's configure your email settings."
        echo ""

        # Agent email
        read -p "Agent email (the one Claude will monitor): " AGENT_EMAIL
        read -sp "App password for $AGENT_EMAIL: " AGENT_APP_PASSWORD
        echo ""

        # Personal email
        read -p "Your personal email (where you send instructions from): " PERSONAL_EMAIL

        # Auto-detect server settings
        DOMAIN="${AGENT_EMAIL##*@}"
        case "$DOMAIN" in
            yahoo.com|yahoo.co.*|ymail.com)
                IMAP_SERVER="imap.mail.yahoo.com"
                SMTP_SERVER="smtp.mail.yahoo.com"
                SMTP_PORT=465
                ;;
            gmail.com|googlemail.com)
                IMAP_SERVER="imap.gmail.com"
                SMTP_SERVER="smtp.gmail.com"
                SMTP_PORT=465
                ;;
            outlook.com|hotmail.com|live.com)
                IMAP_SERVER="outlook.office365.com"
                SMTP_SERVER="smtp.office365.com"
                SMTP_PORT=587
                ;;
            *)
                echo ""
                echo "Could not auto-detect servers for $DOMAIN."
                read -p "IMAP server: " IMAP_SERVER
                read -p "SMTP server: " SMTP_SERVER
                read -p "SMTP port (465 for SSL, 587 for TLS): " SMTP_PORT
                ;;
        esac

        IMAP_PORT=993

        echo "Detected servers: IMAP=$IMAP_SERVER, SMTP=$SMTP_SERVER"

        # Check interval
        read -p "Check interval in seconds [180]: " CHECK_INTERVAL
        CHECK_INTERVAL="${CHECK_INTERVAL:-180}"

        # Write config
        cat > "$CONFIG_FILE" <<EOF
# Claude Always-On Agent Configuration
AGENT_EMAIL="$AGENT_EMAIL"
AGENT_APP_PASSWORD="$AGENT_APP_PASSWORD"
PERSONAL_EMAIL="$PERSONAL_EMAIL"
IMAP_SERVER="$IMAP_SERVER"
IMAP_PORT=$IMAP_PORT
SMTP_SERVER="$SMTP_SERVER"
SMTP_PORT=$SMTP_PORT
CHECK_INTERVAL=$CHECK_INTERVAL
CHECK_FOLDERS="INBOX,Bulk"
MAX_BODY_LENGTH=2000
EOF
        echo ""
        echo "Config saved to $CONFIG_FILE"
    fi
fi

# Load config for template substitution
source "$CONFIG_FILE"

# ----------------------------------------------------------
# 3. Install scripts
# ----------------------------------------------------------
echo ""
echo "Installing scripts..."

mkdir -p "$HOME_DIR/scripts"
mkdir -p "$HOME_DIR/email-queue/processed"
mkdir -p "$HOME_DIR/logs"

cp "$SCRIPT_DIR/scripts/email_utils.py" "$HOME_DIR/scripts/email_utils.py"
cp "$SCRIPT_DIR/scripts/email_watcher.py" "$HOME_DIR/scripts/email_watcher.py"
chmod +x "$HOME_DIR/scripts/email_utils.py"
chmod +x "$HOME_DIR/scripts/email_watcher.py"

echo "  Installed ~/scripts/email_utils.py"
echo "  Installed ~/scripts/email_watcher.py"

# ----------------------------------------------------------
# 4. Test email connection
# ----------------------------------------------------------
echo ""
echo "Testing email connection..."

if python3 "$HOME_DIR/scripts/email_utils.py" check 2>/dev/null; then
    echo "  Email connection works!"
else
    echo "  Warning: Email check failed. Verify your credentials in $CONFIG_FILE"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
fi

# ----------------------------------------------------------
# 5. Install LaunchAgents
# ----------------------------------------------------------
echo ""
echo "Installing LaunchAgents..."

LAUNCH_AGENTS_DIR="$HOME_DIR/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS_DIR"

# Email watcher
WATCHER_PLIST="$LAUNCH_AGENTS_DIR/com.claude.email-watcher.plist"
sed -e "s|__PYTHON_PATH__|$PYTHON_PATH|g" \
    -e "s|__HOME__|$HOME_DIR|g" \
    -e "s|__CHECK_INTERVAL__|${CHECK_INTERVAL:-180}|g" \
    "$SCRIPT_DIR/templates/email-watcher.plist" > "$WATCHER_PLIST"

launchctl unload "$WATCHER_PLIST" 2>/dev/null || true
launchctl load "$WATCHER_PLIST"
echo "  Loaded com.claude.email-watcher (every ${CHECK_INTERVAL:-180}s)"

# Claude agent
AGENT_PLIST="$LAUNCH_AGENTS_DIR/com.claude.agent.plist"
sed -e "s|__HOME__|$HOME_DIR|g" \
    "$SCRIPT_DIR/templates/claude-agent.plist" > "$AGENT_PLIST"

echo "  Installed com.claude.agent (load on next boot or run: launchctl load $AGENT_PLIST)"

# ----------------------------------------------------------
# 6. Update CLAUDE.md
# ----------------------------------------------------------
echo ""
echo "Updating CLAUDE.md..."

CLAUDE_MD="$HOME_DIR/CLAUDE.md"
SNIPPET=$(cat "$SCRIPT_DIR/templates/CLAUDE.md.snippet")

if [ -f "$CLAUDE_MD" ]; then
    if grep -q "24/7 Agent Mode" "$CLAUDE_MD" 2>/dev/null; then
        echo "  CLAUDE.md already has 24/7 Agent Mode section — skipping."
    else
        echo "" >> "$CLAUDE_MD"
        echo "$SNIPPET" >> "$CLAUDE_MD"
        echo "  Appended 24/7 Agent Mode section to ~/CLAUDE.md"
    fi
else
    echo "# Claude Agent" > "$CLAUDE_MD"
    echo "" >> "$CLAUDE_MD"
    echo "$SNIPPET" >> "$CLAUDE_MD"
    echo "  Created ~/CLAUDE.md with 24/7 Agent Mode section"
fi

# ----------------------------------------------------------
# 7. macOS hardening (optional)
# ----------------------------------------------------------
echo ""
read -p "Harden macOS for always-on operation? (disable sleep, auto-restart on power failure) (y/n): " HARDEN

if [ "$HARDEN" = "y" ]; then
    echo "  Disabling sleep..."
    sudo pmset -a sleep 0 displaysleep 0 disksleep 0 2>/dev/null || echo "  Warning: Could not disable sleep (need sudo)"

    echo "  Enabling auto-restart on power failure..."
    sudo pmset -a autorestart 1 2>/dev/null || echo "  Warning: Could not enable auto-restart (need sudo)"

    echo "  Enabling Wake on LAN..."
    sudo pmset -a womp 1 2>/dev/null || echo "  Warning: Could not enable WoL (need sudo)"
fi

# ----------------------------------------------------------
# 8. Done
# ----------------------------------------------------------
echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "What's running:"
echo "  - Email watcher: checking every ${CHECK_INTERVAL:-180}s (LaunchAgent)"
echo "  - Email queue:   ~/email-queue/"
echo "  - Logs:          ~/logs/email-watcher.log"
echo ""
echo "Next steps:"
echo "  1. Start Claude:  claude --dangerously-skip-permissions"
echo "     (or reboot — it auto-starts in tmux)"
echo "  2. Send an email to $AGENT_EMAIL from $PERSONAL_EMAIL"
echo "  3. Claude will read it and email you back!"
echo ""
echo "To uninstall:  ./uninstall.sh"
echo ""
