#!/usr/bin/env bash
# Проверка стенда: поднять, постучаться как браузер и как форма, сделать бэкап, прогнать бота в контейнере.
# Любая непрошедшая проверка останавливает скрипт с кодом 1.
set -euo pipefail
cd "$(dirname "$0")"
URL=https://localhost:8448
check() { # check "описание" команда… — команда должна завершиться успешно
    local name=$1; shift
    if "$@"; then printf '  ✓ %s\n' "$name"; else printf '  ✗ %s\n' "$name"; exit 1; fi
}
count() { curl -sk $URL/api/leads/count | tr -dc 0-9; }

echo "▶ docker compose up --build"
docker compose up -d --build --wait >/dev/null 2>&1
check "контейнеры подняты: nginx, api" test "$(docker compose ps --format '{{.Service}}' | sort | tr '\n' ' ')" = "api nginx "
check "HTTP → HTTPS (301)" test "$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' http://localhost:8088/)" = "301 $URL/"
check "сайт по HTTPS отдаёт лендинг" grep -q '<title>Ровно' <(curl -sk $URL/)
headers=$(curl -skI $URL/)
check "заголовки безопасности: HSTS, nosniff, X-Frame-Options" \
    bash -c 'for h in strict-transport-security x-content-type-options x-frame-options; do grep -qi "^$h" <<<"$1" || exit 1; done' _ "$headers"
check "gzip для CSS/JS" grep -qi '^content-encoding: gzip' <(curl -skI -H 'Accept-Encoding: gzip' $URL/styles.css)
check "API жив: /api/health" test "$(curl -sk $URL/api/health)" = '{"status": "ok"}'

before=$(count)
# имя латиницей: Git Bash на Windows перекодирует кириллицу в аргументах в cp1251
post() { curl -sk -o /dev/null -w '%{http_code}' -X POST $URL/api/lead -H 'Content-Type: application/json' -d "$1"; }
check "заявка сохраняется в SQLite (201)" test "$(post '{"name":"Test","phone":"+7 900 123-45-67"}')" = 201
check "пустая заявка отклонена (422)" test "$(post '{"name":""}')" = 422
check "битый запрос не роняет API (400)" test "$(printf '{"name":"\xd2"}' | curl -sk -o /dev/null -w '%{http_code}' -X POST $URL/api/lead --data-binary @-)" = 400
after=$(count)
check "в базе +1 заявка ($before → $after)" test "$after" -eq $((before + 1))
docker compose restart api >/dev/null 2>&1
docker compose up -d --wait >/dev/null 2>&1
check "после перезапуска API заявки на месте ($after)" test "$(count)" = "$after"

backup=$(docker compose run --rm -T backup 2>/dev/null)
check "${backup#backup: }" test -n "$backup"

docker compose --profile bot build bot >/dev/null 2>&1
sim=$(docker compose --profile bot run --rm --no-deps -T -e PYTHONIOENCODING=utf-8 bot python -m tests.simulate 2>/dev/null)
check "бот в Docker: 5 сценариев прошли" test "$(grep -c '^ok' <<<"$sim")" = 5

echo "▶ всё работает"
