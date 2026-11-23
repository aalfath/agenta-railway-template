# Agenta API image (FastAPI + gunicorn, workers, cron), the official OSS image pinned by
# version and digest. One image backs four Railway services; AGENTA_ROLE picks the process.
FROM ghcr.io/agenta-ai/agenta-api:v0.131.0@sha256:67640276a83b20f326be82cad9dfb8c60f098e9f51c2c0a1416eab20d7a07518
# Upstream falls back to its own PostHog project key when POSTHOG_API_KEY is unset, so a
# self-hosted instance would send usage events to Agenta. Remove the fallback: analytics stay
# off unless the deployer sets POSTHOG_API_KEY. The grep fails the build if upstream changes it.
USER root
RUN grep -q 'or "phc_' /app/oss/src/utils/env.py \
 && sed -i -E 's/or "phc_[A-Za-z0-9]+"/or None/' /app/oss/src/utils/env.py \
 && ! grep -q '"phc_' /app/oss/src/utils/env.py
COPY --chmod=755 env.sh start.sh serve.py bootstrap.py /railway/
USER 10001
ENV AGENTA_LICENSE=oss
ENTRYPOINT []
CMD ["/railway/start.sh"]
