# Agenta API image (FastAPI + gunicorn, workers, cron), the official OSS image pinned by
# version and digest. One image backs four Railway services; AGENTA_ROLE picks the process.
FROM ghcr.io/agenta-ai/agenta-api:v0.131.0@sha256:67640276a83b20f326be82cad9dfb8c60f098e9f51c2c0a1416eab20d7a07518
COPY --chmod=755 env.sh start.sh bootstrap.py /railway/
ENV AGENTA_LICENSE=oss
ENTRYPOINT []
CMD ["/railway/start.sh"]
