#!/bin/sh
set -eu

CAIRN_PORT=${CAIRN_PORT:-4000}
case "$CAIRN_PORT" in
  *[!0-9]*|'')
    printf '%s\n' 'CAIRN_PORT must be an integer from 1 to 65535.' >&2
    exit 1
    ;;
esac
if ! [ "$CAIRN_PORT" -ge 1 ] 2>/dev/null || ! [ "$CAIRN_PORT" -le 65535 ] 2>/dev/null; then
  printf '%s\n' 'CAIRN_PORT must be an integer from 1 to 65535.' >&2
  exit 1
fi

printf 'url: "http://127.0.0.1:%s"\n' "$CAIRN_PORT" > /opt/cairn/runtime.yml
printf 'Preview URL: http://127.0.0.1:%s\n' "$CAIRN_PORT"
exec bundle _4.0.14_ exec jekyll serve --config _config.yml,/opt/cairn/jekyll-dev.yml,/opt/cairn/runtime.yml --host 0.0.0.0 --port 4000 --livereload --force_polling
