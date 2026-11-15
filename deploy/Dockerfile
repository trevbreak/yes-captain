# syntax=docker/dockerfile:1
# Yes, Captain! in one container: the browser build, served by Caddy, and the game server behind /ws.
#
#   docker build -f deploy/Dockerfile -t yes-captain .
#   docker run -p 8480:80 yes-captain          then open http://<this machine>:8480
#
ARG GODOT_VERSION=4.7.2

# ---------------------------------------------------------------- build: export the web game
FROM debian:bookworm-slim AS build
ARG GODOT_VERSION
ARG TARGETARCH
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip brotli \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /opt
RUN case "${TARGETARCH}" in arm64) A=arm64 ;; *) A=x86_64 ;; esac \
 && curl -fsSL -o godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.${A}.zip" \
 && unzip -q godot.zip && mv "Godot_v${GODOT_VERSION}-stable_linux.${A}" /usr/local/bin/godot && chmod +x /usr/local/bin/godot && rm godot.zip
# only the web templates are needed out of the 1.2 GB bundle
RUN T="/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" && mkdir -p "$T" \
 && curl -fsSL -o tpl.tpz "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
 && unzip -q -j tpl.tpz templates/web_nothreads_release.zip templates/web_nothreads_debug.zip templates/version.txt -d "$T" \
 && rm tpl.tpz
WORKDIR /src
COPY . .
RUN rm -rf export .godot && scripts/build_web.sh
# a robot crew flies every mission and the room server is exercised before the image is allowed to exist
ARG SKIP_TESTS=""
RUN if [ -z "$SKIP_TESTS" ]; then NOWINDOW=1 NONET=1 scripts/run_tests.sh quick; fi
RUN cd export/web && for f in index.wasm index.pck index.js; do gzip -9 -k "$f"; brotli -q 9 -k "$f"; done
RUN rm -rf /src/export/web/.gitkeep /src/docs/screenshots /src/.git

# ---------------------------------------------------------------- run
FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates tini curl \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --home /data --shell /usr/sbin/nologin captain
# IGOR's voice: Piper (MIT licence, runs offline on the CPU) with a British voice. The game server runs it
# for each new line and caches the result (net/tts_server.gd). It says one line now, so a broken install
# fails the build instead of a game night.
ARG TARGETARCH
ARG PIPER_VERSION=2023.11.14-2
ARG PIPER_VOICE=en/en_GB/alan/medium/en_GB-alan-medium
RUN case "${TARGETARCH}" in arm64) A=aarch64 ;; *) A=x86_64 ;; esac \
 && curl -fsSL "https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_linux_${A}.tar.gz" | tar -xz -C /opt \
 && curl -fsSL -o /opt/piper/voice.onnx "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/${PIPER_VOICE}.onnx" \
 && curl -fsSL -o /opt/piper/voice.onnx.json "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/${PIPER_VOICE}.onnx.json" \
 && echo "IGOR is online." | LD_LIBRARY_PATH=/opt/piper /opt/piper/piper --model /opt/piper/voice.onnx --output_file /tmp/igor.wav \
 && test -s /tmp/igor.wav && rm /tmp/igor.wav
COPY --from=caddy:2 /usr/bin/caddy /usr/bin/caddy
COPY --from=build /usr/local/bin/godot /usr/local/bin/godot
COPY --from=build /src/export/web /srv/web
COPY --from=build /src /app
COPY deploy/entrypoint.sh /entrypoint.sh
RUN rm -rf /app/export && chmod +x /entrypoint.sh && mkdir -p /data /config
ENV PUBLIC_HOST="" \
    LAN_IP="" \
    TLS_HOST="" TLS_CERT="/certs/certificate_bundle.pem" \
    HTTPS_PORT="8443" \
    MAX_ROOMS="20" \
    TURN_URL="" TURN_USER="" TURN_PASS="" \
    XDG_DATA_HOME=/data XDG_CONFIG_HOME=/config HOME=/data
VOLUME /data
EXPOSE 80 443
HEALTHCHECK --interval=30s --timeout=4s --start-period=20s CMD ["curl", "-fsS", "http://127.0.0.1/healthz"]
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
