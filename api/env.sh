#!/bin/sh
# Derives Agenta's settings from the few Railway references every Agenta service gets,
# so the template stays short. Sourced by the start scripts of api, the workers, cron and
# services. Anything already set wins.
#   DATABASE_URL       ${{Postgres.DATABASE_URL}}
#   REDIS_URL          ${{Redis.REDIS_URL}}
#   AGENTA_PUBLIC_URL  https://${{gateway.RAILWAY_PUBLIC_DOMAIN}}
#   API_HOST, RUNNER_HOST, SEAWEEDFS_HOST, SUPERTOKENS_HOST_INTERNAL   private domains
export AGENTA_LICENSE=oss
if [ -n "${DATABASE_URL:-}" ]; then
  _pg_rest="${DATABASE_URL#*://}"   # user:pass@host:port/db
  _pg_base="${_pg_rest%/*}"         # user:pass@host:port
  export POSTGRES_URI_CORE="${POSTGRES_URI_CORE:-postgresql+asyncpg://${_pg_base}/agenta_oss_core}"
  export POSTGRES_URI_TRACING="${POSTGRES_URI_TRACING:-postgresql+asyncpg://${_pg_base}/agenta_oss_tracing}"
  # SuperTokens keeps its tables in Railway's default database, which exists from the start.
  export POSTGRES_URI_SUPERTOKENS="${POSTGRES_URI_SUPERTOKENS:-${DATABASE_URL}}"
fi
if [ -n "${REDIS_URL:-}" ]; then
  export REDIS_URI="${REDIS_URI:-${REDIS_URL}/0}"
  export REDIS_URI_VOLATILE="${REDIS_URI_VOLATILE:-${REDIS_URL}/0}"
  export REDIS_URI_DURABLE="${REDIS_URI_DURABLE:-${REDIS_URL}/0}"
fi
if [ -n "${AGENTA_PUBLIC_URL:-}" ]; then
  export AGENTA_WEB_URL="${AGENTA_WEB_URL:-${AGENTA_PUBLIC_URL}}"
  export AGENTA_API_URL="${AGENTA_API_URL:-${AGENTA_PUBLIC_URL}/api}"
  export AGENTA_SERVICES_URL="${AGENTA_SERVICES_URL:-${AGENTA_PUBLIC_URL}/services}"
fi
if [ -n "${API_HOST:-}" ]; then
  export AGENTA_API_INTERNAL_URL="${AGENTA_API_INTERNAL_URL:-http://${API_HOST}:8000/api}"
  export AGENTA_STORE_JWT_ISSUER="${AGENTA_STORE_JWT_ISSUER:-http://${API_HOST}:8000/api}"
fi
if [ -n "${RUNNER_HOST:-}" ]; then
  export AGENTA_RUNNER_INTERNAL_URL="${AGENTA_RUNNER_INTERNAL_URL:-http://${RUNNER_HOST}:8765}"
fi
if [ -n "${SEAWEEDFS_HOST:-}" ]; then
  export AGENTA_STORE_ENDPOINT_URL="${AGENTA_STORE_ENDPOINT_URL:-http://${SEAWEEDFS_HOST}:8333}"
fi
if [ -n "${SUPERTOKENS_HOST_INTERNAL:-}" ]; then
  export SUPERTOKENS_URI_CORE="${SUPERTOKENS_URI_CORE:-http://${SUPERTOKENS_HOST_INTERNAL}:3567}"
  export SUPERTOKENS_CONNECTION_URI="${SUPERTOKENS_CONNECTION_URI:-${SUPERTOKENS_URI_CORE}}"
fi
export AGENTA_STORE_BUCKET="${AGENTA_STORE_BUCKET:-agenta-store}"
export ALEMBIC_CFG_PATH_CORE="${ALEMBIC_CFG_PATH_CORE:-/app/oss/databases/postgres/migrations/core/alembic.ini}"
export ALEMBIC_CFG_PATH_TRACING="${ALEMBIC_CFG_PATH_TRACING:-/app/oss/databases/postgres/migrations/tracing/alembic.ini}"
# One proxy (the gateway) plus Railway's edge append to X-Forwarded-For.
export AGENTA_ACCESS_TRUSTED_PROXY_HOPS="${AGENTA_ACCESS_TRUSTED_PROXY_HOPS:-2}"
# Only the owner may create organisations (upstream allowlist); others need an invite.
if [ -n "${AGENTA_ADMIN_EMAIL:-}" ]; then
  export AGENTA_ACCESS_ALLOWED_OWNER_EMAILS="${AGENTA_ACCESS_ALLOWED_OWNER_EMAILS:-$AGENTA_ADMIN_EMAIL}"
fi
# Keep Python's allocator and thread pools small inside a 0.5 GB / 1 vCPU service.
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
export PYTHONUNBUFFERED=1
# Use the model price list bundled with LiteLLM instead of downloading it at every start.
export LITELLM_LOCAL_MODEL_COST_MAP="${LITELLM_LOCAL_MODEL_COST_MAP:-True}"
