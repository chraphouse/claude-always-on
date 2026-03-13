#!/usr/bin/env python3
"""Email utilities for Claude Always-On Agent — send and receive emails."""

import smtplib
import imaplib
import email
import os
import ssl
import sys
import json
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.header import decode_header
from pathlib import Path


def load_config():
    """Load configuration from config.env file."""
    config = {}
    config_path = Path(__file__).parent.parent / "config.env"

    # Also check ~/scripts/ location (installed path)
    if not config_path.exists():
        config_path = Path.home() / ".claude-always-on" / "config.env"

    if not config_path.exists():
        print(f"Error: config.env not found at {config_path}")
        print("Run install.sh first or copy config.example.env to config.env")
        sys.exit(1)

    with open(config_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, value = line.partition("=")
                config[key.strip()] = value.strip().strip('"')

    return config


CONFIG = load_config()

AGENT_EMAIL = CONFIG["AGENT_EMAIL"]
AGENT_APP_PASSWORD = CONFIG["AGENT_APP_PASSWORD"]
PERSONAL_EMAIL = CONFIG["PERSONAL_EMAIL"]
IMAP_SERVER = CONFIG.get("IMAP_SERVER", "imap.mail.yahoo.com")
SMTP_SERVER = CONFIG.get("SMTP_SERVER", "smtp.mail.yahoo.com")
SMTP_PORT = int(CONFIG.get("SMTP_PORT", "465"))
IMAP_PORT = int(CONFIG.get("IMAP_PORT", "993"))
CHECK_FOLDERS = CONFIG.get("CHECK_FOLDERS", "INBOX,Bulk").split(",")
MAX_BODY_LENGTH = int(CONFIG.get("MAX_BODY_LENGTH", "2000"))


def send_email(subject: str, body: str, to_email: str = PERSONAL_EMAIL):
    """Send an email via SMTP."""
    msg = MIMEMultipart()
    msg["From"] = AGENT_EMAIL
    msg["To"] = to_email
    msg["Subject"] = subject

    msg.attach(MIMEText(body, "plain"))

    context = ssl.create_default_context()
    with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT, context=context) as server:
        server.login(AGENT_EMAIL, AGENT_APP_PASSWORD)
        server.sendmail(AGENT_EMAIL, to_email, msg.as_string())

    print(f"Email sent to {to_email}: {subject}")


def check_emails(unseen_only=True, max_results=10):
    """Check inbox and spam folders for emails from the personal email."""
    results = []

    context = ssl.create_default_context()
    with imaplib.IMAP4_SSL(IMAP_SERVER, IMAP_PORT, ssl_context=context) as mail:
        mail.login(AGENT_EMAIL, AGENT_APP_PASSWORD)

        for folder in CHECK_FOLDERS:
            folder = folder.strip()
            try:
                mail.select(folder)
            except Exception:
                continue

            criteria = f'(FROM "{PERSONAL_EMAIL}")'
            if unseen_only:
                criteria = f'(UNSEEN FROM "{PERSONAL_EMAIL}")'

            status, messages = mail.search(None, criteria)
            if status != "OK":
                continue

            msg_ids = messages[0].split()
            for msg_id in msg_ids[-max_results:]:
                status, msg_data = mail.fetch(msg_id, "(RFC822)")
                if status != "OK":
                    continue

                raw_email = msg_data[0][1]
                msg = email.message_from_bytes(raw_email)

                subject = ""
                raw_subject = msg["Subject"]
                if raw_subject:
                    decoded = decode_header(raw_subject)
                    subject = decoded[0][0]
                    if isinstance(subject, bytes):
                        subject = subject.decode(decoded[0][1] or "utf-8")

                date = msg["Date"]

                body = ""
                if msg.is_multipart():
                    for part in msg.walk():
                        if part.get_content_type() == "text/plain":
                            payload = part.get_payload(decode=True)
                            if payload:
                                body = payload.decode(errors="replace")
                            break
                else:
                    payload = msg.get_payload(decode=True)
                    if payload:
                        body = payload.decode(errors="replace")

                results.append({
                    "id": msg_id.decode(),
                    "folder": folder,
                    "subject": subject,
                    "date": date,
                    "body": body.strip()[:MAX_BODY_LENGTH]
                })

    return results


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: email_utils.py send|check [args]")
        print("  send <subject> <body>  - Send an email to your personal address")
        print("  check [--all]          - Check for new emails (--all includes read)")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "send":
        subject = sys.argv[2] if len(sys.argv) > 2 else "Test"
        body = sys.argv[3] if len(sys.argv) > 3 else "Test email from Claude agent"
        send_email(subject, body)

    elif cmd == "check":
        emails = check_emails(unseen_only="--all" not in sys.argv)
        if emails:
            print(json.dumps(emails, indent=2))
        else:
            print("No new emails.")

    elif cmd == "check-all":
        emails = check_emails(unseen_only=False)
        print(json.dumps(emails, indent=2))
