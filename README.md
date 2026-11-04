# Сайт, API и бот на сервере: Docker + nginx + HTTPS

Готовый стенд для публикации проекта: лендинг, API для заявок, Telegram-бот и бэкапы — запускается одной командой и проверяется скриптом.

```
браузер ──HTTPS──▶ nginx ──▶ статика лендинга (кэш, gzip)
                     └─/api/──▶ API заявок (Python) ──▶ SQLite ──▶ бэкапы
Telegram ◀──────────────────── бот (aiogram) в отдельном контейнере
```

| Что | Где |
|---|---|
| HTTP → HTTPS, TLS 1.2/1.3, HSTS, nosniff, X-Frame-Options, gzip, кэш статики | [nginx/site.conf](nginx/site.conf) |
| API заявок: проверка имени и телефона, SQLite, кривой запрос → 400, а не падение | [api/app.py](api/app.py) |
| Бэкап базы с ротацией (7 архивов) | [backup/backup.sh](backup/backup.sh) |
| Бот из [telegram-bots-demo](https://github.com/grozeser/telegram-bots-demo) с автоперезапуском | [docker-compose.yml](docker-compose.yml) |

## Запуск и проверка

```bash
docker compose up -d --build --wait   # сайт: https://localhost:8448
./check.sh
```

Последний прогон `check.sh` — 13 проверок, все прошли: [docs/check.txt](docs/check.txt).

Локально используется самоподписанный сертификат. На сервере: домен, сертификат Let's Encrypt через certbot (location `/.well-known/acme-challenge/` уже в конфиге), порты 80/443, токен бота в `.env`, бэкап по cron (`docker compose run --rm backup`). Выпуск сертификата на реальном домене в этом репозитории не проверялся — для него нужен домен.

Стенд ожидает рядом две папки: `../remont-landing` ([лендинг](https://github.com/grozeser/remont-landing)) и `../bots-demo` ([боты](https://github.com/grozeser/telegram-bots-demo)) — склонируйте их с такими именами.
