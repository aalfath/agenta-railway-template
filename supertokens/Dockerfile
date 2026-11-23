# SuperTokens core (Agenta's sign-in backend), official image pinned by version and digest.
# It keeps its tables in the Railway Postgres default database (POSTGRESQL_CONNECTION_URI).
FROM supertokens/supertokens-postgresql:11.4.9@sha256:e026858aea4bcda93557f8683078e3ca5dc32b4405d24d271ca326802635849d
# Listen on IPv6 too (Railway's private network) and keep both JVMs small for a 0.5 GB service.
ENV SUPERTOKENS_HOST=:: \
    JAVA_TOOL_OPTIONS="-Xmx160m -Xss512k -XX:MaxMetaspaceSize=96m -XX:ReservedCodeCacheSize=32m -XX:+UseSerialGC -XX:ActiveProcessorCount=1"
