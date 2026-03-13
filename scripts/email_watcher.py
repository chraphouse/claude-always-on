#!/usr/bin/env python3
"""
Persistent email watcher — runs independently of Claude via launchd.
Checks for new emails and queues them to ~/email-queue/.
Claude picks up queued emails on startup or during its check loop.
"""

import imaplib
import email
import ssl
import json
import os
import sys
import hashlib
from email.header import decode_header
from datetime import datetime
from pathlib import Path


def load_config():
    """Load configuration from config.env file."""
    config = {}
    for search_path in [
        Path(__file__).parent.parent / "config.env",
        Path.home() / ".claude-always-on" / "config.env",
    ]:
        if search_path.exists():
            with open(search_path) as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        key, _, value = line.partition("=")
                        config[key.strip()] = value.strip().strip('"')
            return config

    print("Error: config.env not found")
    sys.exit(1)


CONFIG = load_config()

AGENT_EMAIL = CONFIG["AGENT_EMAIL"]
AGENT_APP_PASSWORD = CONFIG["AGENT_APP_PASSWORD"]
PERSONAL_EMAIL = CONFIG["PERSONAL_EMAIL"]
IMAP_SERVER = CONFIG.get("IMAP_SERVER", "imap.mail.yahoo.com")
IMAP_PORT = int(CONFIG.get("IMAP_PORT", "993"))
CHECK_FOLDERS = CONFIG.get("CHECK_FOLDERS", "INBOX,Bulk").split(",")
MAX_BODY_LENGTH = int(CONFIG.get("MAX_BODY_LENGTH", "2000"))
QUEUE_DIR = Path.home() / "email-queue"
SEEN_FILE = QUEUE_DIR / ".seen_ids"


def load_seen_ids():
    """Load set of already-processed email message IDs."""
    if SEEN_FILE.exists():
        return set(line.strip() for line in SEEN_FILE.read_text().splitlines() if line.strip())
    return set()


def save_seen_id(msg_hash):
    """Append a processed email hash to the seen file."""
    with open(SEEN_FILE, "a") as f:
        f.write(msg_hash + "\n")


def check_and_queue():
    """Check for unseen emails and queue any new ones to disk."""
    QUEUE_DIR.mkdir(parents=True, exist_ok=True)
    (QUEUE_DIR / "processed").mkdir(exist_ok=True)
    seen_ids = load_seen_ids()
    new_count = 0

    context = ssl.create_default_context()
    with imaplib.IMAP4_SSL(IMAP_SERVER, IMAP_PORT, ssl_context=context) as mail:
        mail.login(AGENT_EMAIL, AGENT_APP_PASSWORD)

        for folder in CHECK_FOLDERS:
            folder = folder.strip()
            try:
                mail.select(folder)
            except Exception:
                continue

            criteria = f'(UNSEEN FROM "{PERSONAL_EMAIL}")'
            status, messages = mail.search(None, criteria)
            if status != "OK":
                continue

            msg_ids = messages[0].split()
            for msg_id in msg_ids:
                status, msg_data = mail.fetch(msg_id, "(RFC822)")
                if status != "OK":
                    continue

                raw_email = msg_data[0][1]
                msg = email.message_from_bytes(raw_email)

                # Extract subject
                subject = ""
                raw_subject = msg["Subject"]
                if raw_subject:
                    decoded = decode_header(raw_subject)
                    subject = decoded[0][0]
                    if isinstance(subject, bytes):
                        subject = subject.decode(decoded[0][1] or "utf-8")

                date = msg["Date"]
                message_id = msg.get("Message-ID", "")

                # Extract body
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

                # Deduplicate
                msg_hash = hashlib.sha256(
                    f"{message_id}{subject}{date}".encode()
                ).hexdigest()[:16]

                if msg_hash in seen_ids:
                    continue

                # Queue the email
                email_data = {
                    "hash": msg_hash,
                    "folder": folder,
                    "subject": subject,
                    "date": date,
                    "body": body.strip()[:MAX_BODY_LENGTH],
                    "queued_at": datetime.now().isoformat()
                }

                queue_file = QUEUE_DIR / f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{msg_hash}.json"
                queue_file.write_text(json.dumps(email_data, indent=2))

                save_seen_id(msg_hash)
                new_count += 1
                print(f"Queued: {subject} ({msg_hash})")

    if new_count == 0:
        print("No new emails.")
    else:
        print(f"Queued {new_count} new email(s).")


if __name__ == "__main__":
    check_and_queue()
