#!/usr/bin/env python3
"""Planer Sync-Server – läuft auf dem Raspberry Pi.

Braucht nur Python 3 (keine weiteren Pakete). Speichert alles in data/planer.db.
Start:  python3 server.py
"""
import hmac
import json
import os
import secrets
import sqlite3
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DATA_DIR = Path(os.environ.get("PLANER_DATA", Path(__file__).resolve().parent / "data"))
PORT = int(os.environ.get("PLANER_PORT", "8788"))
HOST = os.environ.get("PLANER_HOST", "0.0.0.0")
MAX_BODY = 20 * 1024 * 1024

DATA_DIR.mkdir(parents=True, exist_ok=True)
DB_PATH = DATA_DIR / "planer.db"
TOKEN_PATH = DATA_DIR / "token.txt"
LOCK = threading.Lock()


def load_token() -> str:
    env = os.environ.get("PLANER_TOKEN")
    if env:
        return env.strip()
    if not TOKEN_PATH.exists():
        TOKEN_PATH.write_text(secrets.token_urlsafe(24) + "\n")
        os.chmod(TOKEN_PATH, 0o600)
    return TOKEN_PATH.read_text().strip()


TOKEN = load_token()


def db() -> sqlite3.Connection:
    con = sqlite3.connect(DB_PATH, timeout=30)
    con.execute("PRAGMA journal_mode=WAL")
    return con


def init_db() -> None:
    with db() as con:
        con.execute(
            """CREATE TABLE IF NOT EXISTS records (
                   id TEXT PRIMARY KEY,
                   kind TEXT NOT NULL,
                   data TEXT NOT NULL,
                   updated_at INTEGER NOT NULL,
                   deleted INTEGER NOT NULL DEFAULT 0,
                   rev INTEGER NOT NULL
               )"""
        )
        con.execute("CREATE INDEX IF NOT EXISTS records_rev ON records(rev)")


def row_to_record(row) -> dict:
    return {"id": row[0], "kind": row[1], "data": row[2],
            "updatedAt": row[3], "deleted": bool(row[4])}


def sync(since: int, changes: list) -> dict:
    """Übernimmt Änderungen (neuester Zeitstempel gewinnt) und liefert alles Neue zurück."""
    accepted = set()
    rejected = set()
    with LOCK:
        con = db()
        try:
            rev = con.execute("SELECT COALESCE(MAX(rev), 0) FROM records").fetchone()[0]
            for c in changes:
                cid, kind, data = str(c["id"]), str(c["kind"]), str(c["data"])
                updated, deleted = int(c["updatedAt"]), 1 if c.get("deleted") else 0
                row = con.execute("SELECT updated_at FROM records WHERE id = ?", (cid,)).fetchone()
                if row is not None and row[0] > updated:
                    rejected.add(cid)
                    continue
                rev += 1
                con.execute(
                    """INSERT INTO records (id, kind, data, updated_at, deleted, rev)
                       VALUES (?, ?, ?, ?, ?, ?)
                       ON CONFLICT(id) DO UPDATE SET kind = excluded.kind, data = excluded.data,
                           updated_at = excluded.updated_at, deleted = excluded.deleted,
                           rev = excluded.rev""",
                    (cid, kind, data, updated, deleted, rev),
                )
                accepted.add(cid)
            con.commit()
            rows = con.execute(
                "SELECT id, kind, data, updated_at, deleted FROM records WHERE rev > ?", (since,)
            ).fetchall()
            out = [row_to_record(r) for r in rows if r[0] not in accepted]
            sent = {r["id"] for r in out}
            for cid in rejected - sent:
                r = con.execute(
                    "SELECT id, kind, data, updated_at, deleted FROM records WHERE id = ?", (cid,)
                ).fetchone()
                out.append(row_to_record(r))
            return {"rev": rev, "changes": out}
        finally:
            con.close()


class Handler(BaseHTTPRequestHandler):
    server_version = "Planer/1.0"

    def reply(self, status: int, body: dict) -> None:
        raw = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def authorized(self) -> bool:
        given = self.headers.get("Authorization", "")
        return hmac.compare_digest(given.encode(), f"Bearer {TOKEN}".encode())

    def do_GET(self):
        if self.path == "/health":
            self.reply(200, {"ok": True})
        else:
            self.reply(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/sync":
            return self.reply(404, {"error": "not found"})
        if not self.authorized():
            return self.reply(401, {"error": "unauthorized"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length > MAX_BODY:
                return self.reply(413, {"error": "too large"})
            body = json.loads(self.rfile.read(length) or b"{}")
            result = sync(int(body.get("since", 0)), list(body.get("changes", [])))
        except (ValueError, KeyError, TypeError) as e:
            return self.reply(400, {"error": str(e)})
        self.reply(200, result)

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    init_db()
    print(f"Planer Sync-Server läuft auf Port {PORT}")
    print(f"Daten:  {DB_PATH}")
    print(f"Token:  {TOKEN}", flush=True)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
