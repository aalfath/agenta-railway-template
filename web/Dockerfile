# Agenta desktop web app, official OSS image pinned by version and digest.
FROM ghcr.io/agenta-ai/agenta-web:v0.131.0@sha256:6a930e8925b538bf61e8d1bad548102a5e8c612afe1ef38a26a177ba9aa8405b
COPY --chmod=755 start.sh /railway/start.sh
ENV AGENTA_LICENSE=oss
ENTRYPOINT []
CMD ["/railway/start.sh"]
