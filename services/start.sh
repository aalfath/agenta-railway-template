#!/bin/sh
# Railway start script for Agenta services (completion/chat/agent workflows behind /services).
set -u
. /railway/env.sh
: "${AGENTA_AUTH_KEY:?AGENTA_AUTH_KEY is required}"
: "${AGENTA_SERVICES_INTERNAL_KEY:?AGENTA_SERVICES_INTERNAL_KEY is required}"
export SCRIPT_NAME=/services
W="${AGENTA_SERVICES_WORKERS:-1}"
if [ "$W" -le 1 ]; then
  python /railway/serve.py 8080 entrypoints.main:app --timeout-keep-alive 620 --log-level info
else
  gunicorn entrypoints.main:app \
    --bind "[::]:8080" \
    --worker-class uvicorn.workers.UvicornWorker \
    --workers "$W" \
    --max-requests 10000 --max-requests-jitter 1000 \
    --timeout 60 --graceful-timeout 30 \
    --log-level info --access-logfile - --error-logfile -
fi
code=$?
echo "[railway] services exited with $code" >&2
[ "$code" -eq 0 ] && code=1
exit "$code"
