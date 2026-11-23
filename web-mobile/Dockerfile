# Agenta mobile web app (served at /m; signed-out visitors land here), official OSS image pinned by version and digest.
FROM ghcr.io/agenta-ai/agenta-web-mobile:v0.131.0@sha256:7d450d4a3d89776e1567c45e9901422d4f0f3ae254d403634c0c0b0cae24458f
COPY --chmod=755 start.sh /railway/start.sh
ENV AGENTA_LICENSE=oss
ENTRYPOINT []
CMD ["/railway/start.sh"]
