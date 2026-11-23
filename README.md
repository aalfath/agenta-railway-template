[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/agenta?utm_medium=integration&utm_source=button&utm_campaign=agenta)

# Agenta on Railway

One-click Railway template for [Agenta](https://github.com/Agenta-AI/agenta) **v0.131.0** (open-source edition, MIT),
the open-source LLMOps workspace: prompt playground, prompt management, evaluations and LLM observability.

Every service builds from this repository, so a version bump merged here reaches everyone who deployed the
template as an "update available" notice in Railway. Each Dockerfile starts from Agenta's official image
pinned by version **and** digest.

## Services

| Service | Folder | What it does |
|---|---|---|
| `gateway` | `gateway/` | nginx 1.30.7: the one public URL. `/` web app, `/m` mobile app, `/api` API, `/services` playground runtime. Health `/healthz`. |
| `web` | `web/` | Agenta web app (Next.js). |
| `web-mobile` | `web-mobile/` | Agenta mobile web app at `/m` (signed-out visitors land on its sign-in page). |
| `api` | `api/` | FastAPI backend (single uvicorn process at one worker). Creates the databases, runs migrations under a Postgres lock, creates the owner account on first boot. Health `/health`. |
| `worker-streams`, `worker-queues` | `api/` | Background workers (trace ingestion, evaluations), same image, `AGENTA_ROLE` picks the process. |
| `cron` | `api/` | Scheduled evaluation and trigger refreshes (supercronic). |
| `services` | `services/` | Playground and workflow runtime that calls your LLM provider. Health `/health`. |
| `supertokens` | `supertokens/` | SuperTokens core, the sign-in backend. Health `/hello`. |
| `Postgres` | Railway Postgres | Agenta core, tracing and SuperTokens data (volume). |
| `Redis` | Railway Redis | Caches, streams and queues (volume). |

## After deploy

1. Open the `gateway` service's URL and sign in with your `AGENTA_ADMIN_EMAIL` and the generated
   `AGENTA_ADMIN_PASSWORD` (the `api` service's Variables tab).
2. Add an LLM provider key under **Settings → Model hub** (OpenAI, Anthropic, Gemini, Mistral, Groq or any
   OpenAI-compatible endpoint), then open the playground.
3. To trace your app, create an API key under **Settings → API keys** and point the SDK at
   `https://YOUR-DOMAIN` (`ag.init(host=..., api_key=...)`).

## Variables

You fill in one value: **`AGENTA_ADMIN_EMAIL`** on `api`, the owner account's email. Everything else is
generated (`${{secret()}}`) or wired with Railway references:

- `AGENTA_ADMIN_PASSWORD` (api): the owner's generated password. Read it in the `api` service's Variables tab.
- `AGENTA_AUTH_KEY`, `AGENTA_CRYPT_KEY`, `AGENTA_SERVICES_INTERNAL_KEY`: generated once on `api`, referenced by the other services.
- `AGENTA_PUBLIC_URL`: `https://${{gateway.RAILWAY_PUBLIC_DOMAIN}}`.
- `DATABASE_URL`, `REDIS_URL`, `API_HOST`, `SUPERTOKENS_HOST_INTERNAL`, …: references to the other services' private domains.

Only the owner email may create an organisation; other people who sign up see nothing until you invite them.
LLM provider keys (OpenAI, Anthropic, any OpenAI-compatible endpoint) are added in Agenta under
**Settings → Model hub**, so the template asks for none.

## Memory

Every service runs inside Railway's 0.5 GB / 1 vCPU per-service limit (Free plan). Measured on Railway with
traces ingested and a playground run: api about 450 MB, worker-queues 330 MB, worker-streams 310 MB,
services 230 MB, supertokens 225 MB, web and web-mobile 130 MB each. The API is the tightest; on Hobby or
higher give it 1 GB and set `AGENTA_API_WORKERS=2` (or `AGENTA_SERVICES_WORKERS`) for more throughput.
Every start script exits non-zero when its process stops, so Railway's on-failure restart brings it back.

## Not included

- **Agent runner** (`agenta-runner`, used by "agents" that run tools in a sandbox): its image is 4.9 GB,
  above the 4 GB image limit of Railway's Free and Trial plans, and its durable workspace needs FUSE, which
  Railway containers don't have. Prompt playground, evaluations and observability don't need it.
- **SeaweedFS object store**: only the agent runner's file mounts use it.
- Analytics: upstream sends usage events to Agenta's PostHog unless told otherwise; this template removes that
  default, so nothing is sent unless you set `POSTHOG_API_KEY`.
- Email (SMTP/SendGrid), Google/GitHub sign-in and Composio tools: optional, set upstream's variables on
  `api`, `web` and `web-mobile` if you want them.

## Updates

Merges to `main` bump the pinned images. Railway shows deployers an update notice; read `CHANGELOG.md` first,
then apply it. `api` runs any new migrations on start.
