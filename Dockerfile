FROM ghcr.io/lavalink-devs/lavalink:4.2.2-alpine

USER root

# Baked, not fetched at boot. Lavalink's PluginManager downloads a declared
# plugin from maven.lavalink.dev on every container start, so a deploy depends
# on that host being up; and every listing in this category pins
# youtube-plugin 1.16.0, on which every YouTube lookup fails with a
# FriendlyException ("Something went wrong while looking up the track").
ADD --chmod=644 https://maven.lavalink.dev/releases/dev/lavalink/youtube/youtube-plugin/1.18.2/youtube-plugin-1.18.2.jar \
    /opt/Lavalink/plugins/youtube-plugin-1.18.2.jar

COPY application.yml /opt/Lavalink/application.yml
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh

# `ADD --chmod=644` applies that mode to the directory it creates as well, which
# leaves plugins/ non-traversable and silently loads no plugins at all.
RUN chmod 0755 /opt/Lavalink/plugins \
    && chmod 0644 /opt/Lavalink/application.yml /opt/Lavalink/plugins/*.jar \
    && chmod 0755 /usr/local/bin/railway-entrypoint.sh

USER lavalink
WORKDIR /opt/Lavalink

ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
