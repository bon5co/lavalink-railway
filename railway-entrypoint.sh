#!/bin/sh
# Railway entrypoint for Lavalink.
#
# Two jobs, both of which the marketplace listings get wrong:
#
#  1. Refuse to boot without a password. Lavalink accepts an empty
#     `lavalink.server.password`, and an empty password is not "auth off" in a
#     way anyone notices — the node answers 401 to a request with no
#     Authorization header and 200 to a request whose Authorization header is
#     empty. Any stranger who sends `Authorization:` owns the node.
#
#  2. Size the JVM heap from the container's cgroup memory limit. The JVM reads
#     the cgroup itself, but only when nothing else pins the heap; a hardcoded
#     -Xmx (768m is what the leading listing publishes) applies on every plan
#     size, so a 8 GB service still OOM-kills its players under load.
set -e

if [ -z "${LAVALINK_SERVER_PASSWORD:-}" ]; then
    echo "[railway-entrypoint] FATAL: LAVALINK_SERVER_PASSWORD is empty." >&2
    echo "[railway-entrypoint] An empty password lets any caller that sends an" >&2
    echo "[railway-entrypoint] empty Authorization header use this node. Set a" >&2
    echo "[railway-entrypoint] password in the service variables and redeploy." >&2
    exit 1
fi

mem_max=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo max)
case "$mem_max" in
    ''|max|*[!0-9]*) mem_mb="" ;;
    *) mem_mb=$((mem_max / 1024 / 1024)) ;;
esac

# Ignore an implausible limit (an unconstrained cgroup reports a number near
# 2^63) and fall back to the JVM's own container awareness.
if [ -n "$mem_mb" ] && [ "$mem_mb" -gt 128 ] && [ "$mem_mb" -lt 262144 ]; then
    heap_mb=$((mem_mb * 70 / 100))
    JAVA_OPTS="-Xmx${heap_mb}m -Xms$((heap_mb / 4))m -XX:+UseG1GC ${JAVA_OPTS:-}"
    echo "[railway-entrypoint] cgroup memory=${mem_mb}MiB heap=${heap_mb}MiB"
else
    JAVA_OPTS="-XX:MaxRAMPercentage=70 -XX:+UseG1GC ${JAVA_OPTS:-}"
    echo "[railway-entrypoint] no usable cgroup memory limit; MaxRAMPercentage=70"
fi

echo "[railway-entrypoint] port=${PORT:-8080} plugins=$(ls /opt/Lavalink/plugins 2>/dev/null | tr '\n' ' ')"

# shellcheck disable=SC2086
exec java $JAVA_OPTS -jar /opt/Lavalink/Lavalink.jar
