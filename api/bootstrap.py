#!/usr/bin/env python
"""First-boot helper for the Agenta API on Railway.

--migrate  Wait for Postgres, take an advisory lock (polled, so overlapping Railway deploys
           never run migrations twice), create Agenta's databases, keep the store's RSA
           web-identity key in Postgres (generated once), run upstream's migration runner,
           and write the key to /tmp/agenta-store-key.pem for the start script.
--owner    After the API answers /health, create the owner account once from
           AGENTA_ADMIN_EMAIL / AGENTA_ADMIN_PASSWORD through Agenta's admin API.
"""
import asyncio, json, os, subprocess, sys, time, urllib.error, urllib.request

LOCK_ID = 7300431  # arbitrary, fixed
KV = "railway_agenta_kv"


def log(msg):
    print(f"[railway-bootstrap] {msg}", flush=True)


async def connect(retries=90):
    import asyncpg
    url = os.environ["DATABASE_URL"]
    last = None
    for _ in range(retries):
        try:
            return await asyncpg.connect(url, timeout=10)
        except Exception as exc:  # Postgres still starting
            last = exc
            await asyncio.sleep(2)
    raise SystemExit(f"Postgres not reachable: {last}")


async def kv_get(conn, key):
    return await conn.fetchval(f"SELECT v FROM {KV} WHERE k = $1", key)


async def kv_set(conn, key, value):
    await conn.execute(
        f"INSERT INTO {KV}(k, v) VALUES ($1, $2) ON CONFLICT (k) DO NOTHING", key, value
    )


async def migrate():
    conn = await connect()
    try:
        waited = 0
        while not await conn.fetchval("SELECT pg_try_advisory_lock($1)", LOCK_ID):
            if waited == 0:
                log("another deploy holds the migration lock; waiting")
            await asyncio.sleep(3)
            waited += 3
            if waited > 900:
                raise SystemExit("timed out waiting for the migration lock")
        for db in ("agenta_oss_core", "agenta_oss_tracing"):
            if not await conn.fetchval("SELECT 1 FROM pg_database WHERE datname = $1", db):
                log(f"creating database {db}")
                await conn.execute(f'CREATE DATABASE "{db}"')
        await conn.execute(f"CREATE TABLE IF NOT EXISTS {KV} (k text PRIMARY KEY, v text NOT NULL)")
        pem = await kv_get(conn, "store_jwt_private_key")
        if not pem:
            from cryptography.hazmat.primitives import serialization
            from cryptography.hazmat.primitives.asymmetric import rsa
            key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
            pem = key.private_bytes(
                serialization.Encoding.PEM,
                serialization.PrivateFormat.PKCS8,
                serialization.NoEncryption(),
            ).decode()
            await kv_set(conn, "store_jwt_private_key", pem)
            pem = await kv_get(conn, "store_jwt_private_key")
            log("generated the store web-identity key")
        fd = os.open("/tmp/agenta-store-key.pem", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as fh:
            fh.write(pem)
        log("running database migrations")
        t0 = time.time()
        with open("/tmp/migrations.log", "w") as out:
            rc = subprocess.call(
                [sys.executable, "-m", "oss.databases.postgres.migrations.runner"],
                stdout=out, stderr=subprocess.STDOUT,
            )
        if rc != 0:
            with open("/tmp/migrations.log") as fh:
                sys.stdout.write("".join(fh.readlines()[-60:]))
            raise SystemExit(f"migrations failed (exit {rc})")
        log(f"migrations done in {time.time() - t0:.0f}s")
    finally:
        try:
            await conn.execute("SELECT pg_advisory_unlock_all()")
        finally:
            await conn.close()


def http(method, url, body=None, headers=None, timeout=30):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read().decode(errors="replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode(errors="replace")


def wait_http(urls, what, tries=300, delay=2):
    """Return the first URL that answers 200 (tries * delay seconds at most)."""
    for _ in range(tries):
        for url in urls:
            try:
                if http("GET", url, timeout=5)[0] == 200:
                    return url
            except Exception:
                pass
        time.sleep(delay)
    raise SystemExit(f"{what} did not answer; owner account not created")


def ensure_owner(base, email, password):
    """Create the owner (user, sign-in identity, organisation) once. Repairs a half-created
    owner (Agenta user without a SuperTokens identity) instead of reporting success."""
    auth = {"Authorization": "Access " + os.environ["AGENTA_AUTH_KEY"]}
    identity = {"method": "email:password", "subject": email, "password": password}
    payload = {"accounts": {"owner": {
        "user": {"email": email},
        "user_identities": [identity],
        "options": {"seed_defaults": True, "create_identities": True},
    }}}
    status, text = http("POST", base + "/admin/simple/accounts/", payload, auth, timeout=120)
    if status == 200:
        try:
            errors = json.loads(text).get("errors")
        except Exception:
            errors = None
        if not errors:
            return "created"
        log(f"owner account created with errors, repairing: {json.dumps(errors)[:300]}")
    elif status != 409:
        raise RuntimeError(f"HTTP {status} {text[:300]}")
    # The user exists: make sure it can sign in with the generated password.
    status, text = http("POST", base + "/admin/simple/accounts/users/identities/",
                        {"user_ref": {"email": email}, "user_identity": identity}, auth, timeout=60)
    if status == 200:
        return "sign-in identity added"
    status, text = http("POST", base + "/admin/simple/accounts/reset-password",
                        {"user_identities": [identity]}, auth, timeout=60)
    if status in (200, 204):
        return "already existed; password set"
    raise RuntimeError(f"could not set the owner's password: HTTP {status} {text[:300]}")


async def owner():
    email = (os.environ.get("AGENTA_ADMIN_EMAIL") or "").strip().lower()
    password = os.environ.get("AGENTA_ADMIN_PASSWORD") or ""
    if not email or not password:
        log("AGENTA_ADMIN_EMAIL / AGENTA_ADMIN_PASSWORD not set; skipping the owner account")
        return
    flag = "owner_created:" + email
    conn = await connect()
    try:
        if await kv_get(conn, flag):
            return
    finally:
        await conn.close()
    base = wait_http(["http://127.0.0.1:8000/health", "http://[::1]:8000/health"], "the API")
    base = base.rsplit("/health", 1)[0]
    # On a first deploy SuperTokens' private DNS name may not resolve yet: wait for it.
    st = os.environ.get("SUPERTOKENS_URI_CORE") or os.environ.get("SUPERTOKENS_CONNECTION_URI")
    if st:
        wait_http([st.rstrip("/") + "/hello"], "SuperTokens", tries=200, delay=3)
    last = None
    for attempt in range(10):
        try:
            result = ensure_owner(base, email, password)
            break
        except Exception as exc:
            last = exc
            log(f"owner account attempt {attempt + 1} failed: {exc}")
            time.sleep(10)
    else:
        raise SystemExit(f"owner account not created: {last}")
    conn = await connect()
    try:
        await kv_set(conn, flag, "1")
    finally:
        await conn.close()
    log(f"owner account ready: {email} ({result})")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "--migrate":
        asyncio.run(migrate())
    elif mode == "--owner":
        asyncio.run(owner())
    else:
        raise SystemExit(__doc__)
