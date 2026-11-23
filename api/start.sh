#!/bin/sh
# Railway start script for every service built from the Agenta API image.
# AGENTA_ROLE picks what this service runs: api (default), worker-streams, worker-queues, cron.
#   api: create Agenta's databases, the store signing key and run migrations (bootstrap.py,
#        under a polled Postgres advisory lock so overlapping deploys never migrate twice),
#        start gunicorn on [::]:8000 (Railway's private network is IPv6), then create the
#        owner account once from AGENTA_ADMIN_EMAIL / AGENTA_ADMIN_PASSWORD.
# Any exit is non-zero, so Railway's ON_FAILURE restart policy always brings it back.
set -u
. /railway/env.sh
: "${AGENTA_AUTH_KEY:?AGENTA_AUTH_KEY is required}"
: "${AGENTA_CRYPT_KEY:?AGENTA_CRYPT_KEY is required}"
ROLE="${AGENTA_ROLE:-api}"

fail() { echo "[railway] $ROLE exited with $1" >&2; [ "$1" -eq 0 ] && exit 1; exit "$1"; }

case "$ROLE" in
  api)
    : "${AGENTA_SERVICES_INTERNAL_KEY:?AGENTA_SERVICES_INTERNAL_KEY is required}"
    export SCRIPT_NAME=/api
    python /railway/bootstrap.py --migrate || fail $?
    AGENTA_STORE_JWT_PRIVATE_KEY="$(cat /tmp/agenta-store-key.pem)"
    export AGENTA_STORE_JWT_PRIVATE_KEY
    rm /tmp/agenta-store-key.pem
    W="${AGENTA_API_WORKERS:-1}"
    if [ "$W" -le 1 ]; then
      # One process (no gunicorn master) keeps the API about 60 MB lighter at 0.5 GB.
      python /railway/serve.py 8000 entrypoints.routers:app --timeout-keep-alive 620 --log-level info &
    else
      gunicorn entrypoints.routers:app \
        --bind "[::]:8000" \
        --worker-class entrypoints.uvicorn_worker.DrainingUvicornWorker \
        --workers "$W" \
        --max-requests 100000 --max-requests-jitter 10000 \
        --timeout 60 --graceful-timeout 30 \
        --log-level info --access-logfile - --error-logfile - &
    fi
    GPID=$!
    ( python /railway/bootstrap.py --owner || echo "[railway] owner bootstrap failed; see above" >&2 ) &
    wait "$GPID"
    fail $?
    ;;
  worker-streams)
    python -m entrypoints.worker_streams
    fail $?
    ;;
  worker-queues)
    python -m entrypoints.worker_queues
    fail $?
    ;;
  cron)
    # Upstream's cron scripts call http://api:8000; point them at the API's private domain.
    mkdir -p /tmp/crons
    for f in queries triggers gateways; do
      sed "s#http://api:8000#http://${API_HOST:-api.railway.internal}:8000#g" "/$f.sh" > "/tmp/crons/$f.sh"
    done
    sed -e 's#sh /queries.sh#sh /tmp/crons/queries.sh#' -e 's#sh /triggers.sh#sh /tmp/crons/triggers.sh#' \
        -e 's#sh /gateways.sh#sh /tmp/crons/gateways.sh#' /app/crontab > /tmp/crons/crontab
    /usr/local/bin/supercronic -quiet /tmp/crons/crontab
    fail $?
    ;;
  *)
    echo "[railway] unknown AGENTA_ROLE=$ROLE" >&2; exit 2 ;;
esac
