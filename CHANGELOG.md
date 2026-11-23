# Changelog

## v0.131.0 (2026-11-23)

- First release of the template: Agenta v0.131.0 OSS (api, workers, cron, services, web, web-mobile,
  SuperTokens 11.4.9, nginx 1.30.7 gateway) with Railway Postgres and Redis.
- Owner account created on first boot from `AGENTA_ADMIN_EMAIL` and a generated password; only the owner
  may create organisations.
- Upstream's built-in PostHog key removed: analytics are off unless `POSTHOG_API_KEY` is set.
- Deploy on Railway button.
