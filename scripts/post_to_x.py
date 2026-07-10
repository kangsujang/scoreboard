#!/usr/bin/env python3
"""Post due items from AppStore/sns_queue.json to X (Twitter) via API v2.

Reads X_API_KEY / X_API_KEY_SECRET / X_ACCESS_TOKEN / X_ACCESS_TOKEN_SECRET
from .env in the repo root. Posts at most one due "x" item per run (run via
cron/schedule for periodic posting), then marks it posted in the queue file.
"""
import base64
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

REPO_ROOT = Path(__file__).resolve().parent.parent
ENV_PATH = REPO_ROOT / ".env"
QUEUE_PATH = REPO_ROOT / "AppStore" / "sns_queue.json"
TWEET_ENDPOINT = "https://api.twitter.com/2/tweets"


def load_env(path: Path) -> dict:
    env = {}
    if not path.exists():
        return env
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        env[key.strip()] = value.strip()
    return env


def percent_encode(value: str) -> str:
    return quote(str(value), safe="~")


def oauth1_header(method: str, url: str, params: dict, creds: dict) -> str:
    oauth_params = {
        "oauth_consumer_key": creds["X_API_KEY"],
        "oauth_nonce": uuid.uuid4().hex,
        "oauth_signature_method": "HMAC-SHA1",
        "oauth_timestamp": str(int(time.time())),
        "oauth_token": creds["X_ACCESS_TOKEN"],
        "oauth_version": "1.0",
    }
    all_params = {**oauth_params, **params}
    sorted_params = sorted(all_params.items())
    param_str = "&".join(
        f"{percent_encode(k)}={percent_encode(v)}" for k, v in sorted_params
    )
    base_str = "&".join(
        [method.upper(), percent_encode(url), percent_encode(param_str)]
    )
    signing_key = (
        f"{percent_encode(creds['X_API_KEY_SECRET'])}&"
        f"{percent_encode(creds['X_ACCESS_TOKEN_SECRET'])}"
    )
    signature = base64.b64encode(
        hmac.new(signing_key.encode(), base_str.encode(), hashlib.sha1).digest()
    ).decode()
    oauth_params["oauth_signature"] = signature

    header = "OAuth " + ", ".join(
        f'{percent_encode(k)}="{percent_encode(v)}"'
        for k, v in sorted(oauth_params.items())
    )
    return header


def post_tweet(text: str, creds: dict) -> dict:
    body = json.dumps({"text": text}).encode("utf-8")
    auth_header = oauth1_header("POST", TWEET_ENDPOINT, {}, creds)
    req = urllib.request.Request(
        TWEET_ENDPOINT,
        data=body,
        method="POST",
        headers={
            "Authorization": auth_header,
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8")
        raise RuntimeError(f"X API error {e.code}: {detail}") from e


def main() -> int:
    creds = load_env(ENV_PATH)
    required = [
        "X_API_KEY",
        "X_API_KEY_SECRET",
        "X_ACCESS_TOKEN",
        "X_ACCESS_TOKEN_SECRET",
    ]
    missing = [k for k in required if not creds.get(k)]
    if missing:
        print(f"Missing credentials in .env: {', '.join(missing)}", file=sys.stderr)
        return 1

    if not QUEUE_PATH.exists():
        print(f"Queue file not found: {QUEUE_PATH}", file=sys.stderr)
        return 1

    queue = json.loads(QUEUE_PATH.read_text())
    now = datetime.now(timezone.utc)

    due_item = None
    for item in queue:
        if item.get("platform") != "x" or item.get("status") != "pending":
            continue
        scheduled_at = datetime.fromisoformat(item["scheduled_at"])
        if scheduled_at <= now:
            due_item = item
            break

    if due_item is None:
        print("No due items to post.")
        return 0

    print(f"Posting {due_item['id']}...")
    result = post_tweet(due_item["text"], creds)
    tweet_id = result.get("data", {}).get("id")

    due_item["status"] = "posted"
    due_item["posted_at"] = now.isoformat()
    due_item["tweet_id"] = tweet_id
    QUEUE_PATH.write_text(json.dumps(queue, ensure_ascii=False, indent=2) + "\n")

    print(f"Posted {due_item['id']} as tweet {tweet_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
