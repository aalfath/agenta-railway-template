#!/bin/sh
# Railway start script for the Agenta desktop web app.
# Writes the runtime config (__env.js) from AGENTA_PUBLIC_URL through upstream's entrypoint,
# then runs the Next.js server on [::]:3000 (Railway's private network is IPv6).
set -u
export AGENTA_LICENSE=oss
if [ -n "${AGENTA_PUBLIC_URL:-}" ]; then
  export AGENTA_WEB_URL="${AGENTA_WEB_URL:-$AGENTA_PUBLIC_URL}"
  export AGENTA_API_URL="${AGENTA_API_URL:-$AGENTA_PUBLIC_URL/api}"
  export AGENTA_SERVICES_URL="${AGENTA_SERVICES_URL:-$AGENTA_PUBLIC_URL/services}"
fi
if [ -n "${API_HOST:-}" ]; then
  export AGENTA_API_INTERNAL_URL="${AGENTA_API_INTERNAL_URL:-http://${API_HOST}:8000/api}"
fi
export PORT=3000 HOSTNAME=::
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=256}"
/app/entrypoint.sh node /app/oss/server.js
code=$?
echo "[railway] web exited with $code" >&2
[ "$code" -eq 0 ] && code=1
exit "$code"
