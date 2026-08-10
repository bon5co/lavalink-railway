# lavalink-railway

Wrapper image for running [Lavalink](https://lavalink.dev) 4.2.2 as a standalone
Discord audio node on Railway.

Image: `ghcr.io/bon5co/lavalink-railway:4.2.2`

## What this adds to the upstream image

1. **It refuses to boot without a password.** Lavalink accepts an empty
   `lavalink.server.password`, and an empty password is not "authentication
   off" in a way anyone notices: the node answers `401` to a request with no
   `Authorization` header and `200` to a request whose `Authorization` header is
   empty. Measured on the stock image with `LAVALINK_SERVER_PASSWORD=""`:

   ```
   curl -H "Authorization;" .../v4/info   -> 200
   ```

   With a password set, the same request is `403`. The entrypoint exits with a
   message instead of starting an open node.

2. **A working YouTube source.** The plugin jar is baked into the image at
   `youtube-plugin` **1.18.2**, and the built-in YouTube source is disabled
   (upstream deprecated it). On 1.16.0 — the version the marketplace listings
   pin — every YouTube lookup fails:

   ```
   {"loadType":"error","data":{"message":"Something went wrong while looking up the track."}}
   ```

   while the same query on 1.18.2 returns results. Baking the jar also removes
   the boot-time download from `maven.lavalink.dev`, so a deploy does not depend
   on that host being reachable.

3. **Heap sized from the cgroup.** `railway-entrypoint.sh` reads
   `/sys/fs/cgroup/memory.max` and sets `-Xmx` to 70% of it, falling back to
   `-XX:MaxRAMPercentage=70`. A hardcoded `-Xmx768m` applies on every plan size.

4. **A healthcheck that works.** Every authenticated route needs the password,
   so `/metrics` (Prometheus, unauthenticated, `200`) is the only usable HTTP
   healthcheck path. It is enabled in the baked `application.yml`.

5. **`$PORT` is honoured** (`server.port: ${PORT:8080}`), because Railway's HTTP
   healthcheck dials the injected port rather than the port a domain targets.

## Configuration

| Variable | Required | Notes |
|---|---|---|
| `LAVALINK_SERVER_PASSWORD` | yes | Container refuses to start if empty. |
| `PORT` | no | Injected by Railway; defaults to 8080. |
| `JAVA_OPTS` | no | Prepended to the computed heap flags. |

Everything else (sources, filters, buffer sizes, YouTube clients) is baked into
`/opt/Lavalink/application.yml` so the Railway deploy form does not ask for
thirty settings the image already knows. Any of it can still be overridden with
the usual `LAVALINK_SERVER_*` environment variables.

## Local test

```sh
docker build -t lavalink-rw .
docker run --rm -p 8080:8080 -e LAVALINK_SERVER_PASSWORD=strongpw lavalink-rw
curl -H "Authorization: strongpw" 'http://localhost:8080/v4/loadtracks?identifier=ytsearch%3Atest'
```
