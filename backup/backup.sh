#!/bin/sh
# Бэкап базы заявок: архив с датой, хранится 7 последних. На сервере — по cron раз в сутки.
set -e
name="/backups/leads-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$name" -C /data .
ls -1t /backups/leads-*.tar.gz | tail -n +8 | xargs -r rm --
echo "backup: $name ($(wc -c < "$name") байт), всего архивов: $(ls /backups/leads-*.tar.gz | wc -l)"
