"""API для заявок с сайта: POST /api/lead сохраняет заявку в SQLite, GET /api/health — для проверки живости.

Только стандартная библиотека: меньше зависимостей — меньше обновлять на сервере.
"""
import json
import re
import sqlite3
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DB = "/data/leads.sqlite"


def db() -> sqlite3.Connection:
    con = sqlite3.connect(DB)
    con.execute("CREATE TABLE IF NOT EXISTS leads (id INTEGER PRIMARY KEY, created TEXT, name TEXT, phone TEXT, comment TEXT)")
    return con


class Handler(BaseHTTPRequestHandler):
    def reply(self, code: int, data: dict) -> None:
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path == "/api/health":
            return self.reply(200, {"status": "ok"})
        if self.path == "/api/leads/count":
            with db() as con:
                return self.reply(200, {"count": con.execute("SELECT COUNT(*) FROM leads").fetchone()[0]})
        self.reply(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path != "/api/lead":
            return self.reply(404, {"error": "not found"})
        try:
            data = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        except (json.JSONDecodeError, UnicodeDecodeError):  # кривой запрос — ответ 400, а не падение воркера
            return self.reply(400, {"error": "bad json"})
        if not isinstance(data, dict):
            return self.reply(400, {"error": "bad json"})
        name = str(data.get("name", "")).strip()[:100]
        phone = re.sub(r"\D", "", str(data.get("phone", "")))
        if not name or len(phone) not in (10, 11):
            return self.reply(422, {"error": "нужны имя и телефон"})
        with db() as con:
            cur = con.execute("INSERT INTO leads (created, name, phone, comment) VALUES (?, ?, ?, ?)",
                              (datetime.now().isoformat(timespec="seconds"), name, "+7" + phone[-10:], str(data.get("comment", ""))[:1000]))
        self.reply(201, {"id": cur.lastrowid})

    def log_message(self, fmt, *args) -> None:  # без персональных данных в логах
        print(f"{self.command} {self.path} {args[1] if len(args) > 1 else ''}", flush=True)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8000), Handler).serve_forever()
