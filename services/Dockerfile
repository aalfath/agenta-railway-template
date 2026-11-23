# Agenta services (playground and workflow runtime), official OSS image pinned by version and digest.
FROM ghcr.io/agenta-ai/agenta-services:v0.131.0@sha256:1d2760754709c3c5a7a8e3e24d493cd3ed3a97c18c908468b5f27cbcdc59eeaf
COPY --chmod=755 env.sh start.sh serve.py /railway/
ENV AGENTA_LICENSE=oss
ENTRYPOINT []
CMD ["/railway/start.sh"]
