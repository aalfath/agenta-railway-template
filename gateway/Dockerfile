# Agenta gateway: one public URL for the web app (/), mobile app (/m), API (/api) and
# services (/services). Official nginx image pinned by version and digest.
FROM nginx:1.30.7-alpine@sha256:caf4e1e032a20f9c3c5e28fc7f25ffd768ad8677b4975c54193075997b3a97e3
COPY default.conf.template /etc/nginx/templates/default.conf.template
# The official entrypoint renders the template with these variables and writes the
# container's own DNS resolver (Railway's private DNS) into NGINX_LOCAL_RESOLVERS.
ENV PORT=8080 \
    NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1 \
    NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE=1 \
    NGINX_ENVSUBST_FILTER="^(PORT|API_HOST|SERVICES_HOST|WEB_HOST|WEB_MOBILE_HOST|NGINX_LOCAL_RESOLVERS)$"
