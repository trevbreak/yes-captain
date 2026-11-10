#!/bin/sh
# Starts the game server (Godot, headless) and Caddy in front of it.
#   PUBLIC_HOST  a domain name pointing at this server: Caddy fetches a real certificate (needs ports 80 + 443)
#   LAN_IP       this server's address on your network: adds https with a self-signed certificate,
#                so voice chat can be tried at home before the game is on the internet
#   MAX_ROOMS    how many crew rooms may be open at once (default 20)
#   TURN_URL, TURN_USER, TURN_PASS   optional voice relay for players behind awkward routers
set -u

WEB=/srv/web
CADDYFILE=/config/Caddyfile
mkdir -p /config /data /tmp/captain
chown captain /tmp/captain

# what the page needs to know (voice relay)
if [ -n "${TURN_URL:-}" ]; then
	printf 'window.YC_ICE = [{ urls: "%s", username: "%s", credential: "%s" }];\n' "$TURN_URL" "${TURN_USER:-}" "${TURN_PASS:-}" > "$WEB/config.js"
else
	echo 'window.YC_ICE = [];' > "$WEB/config.js"
fi

{
	echo '{'
	echo '	admin off'
	# browsers reaching us by bare IP send no server name: tell Caddy which certificate to offer them
	[ -n "${LAN_IP:-}" ] && echo "	default_sni ${LAN_IP}"
	echo '}'
	echo '(game) {'
	echo '	root * /srv/web'
	echo '	@ws path /ws'
	echo '	reverse_proxy @ws 127.0.0.1:7777'
	echo '	respond /healthz "ok" 200'
	echo '	header {'
	echo '		X-Content-Type-Options nosniff'
	echo '		Referrer-Policy no-referrer'
	echo '		Permissions-Policy "microphone=(self), camera=(), geolocation=()"'
	echo '	}'
	echo '	@page path / /index.html /config.js /voice.js'
	echo '	header @page Cache-Control "no-cache"'
	echo '	file_server {'
	echo '		precompressed br gzip'
	echo '	}'
	echo '}'
	echo 'http:// {'
	echo '	import game'
	echo '}'
	if [ -n "${PUBLIC_HOST:-}" ]; then
		echo "${PUBLIC_HOST} {"
		echo '	import game'
		echo '}'
	fi
	if [ -n "${LAN_IP:-}" ]; then
		echo "https://${LAN_IP} {"
		echo '	tls internal'
		echo '	import game'
		echo '}'
	fi
} > "$CADDYFILE"

echo "Yes, Captain! container starting. PUBLIC_HOST='${PUBLIC_HOST:-}' LAN_IP='${LAN_IP:-}' MAX_ROOMS=${MAX_ROOMS:-20}"

# the game server: if it ever falls over, stand it back up
(
	while true; do
		# the part that reads what strangers send runs without root
		setpriv --reuid=captain --regid=captain --clear-groups \
			env HOME=/tmp/captain XDG_DATA_HOME=/tmp/captain XDG_CONFIG_HOME=/tmp/captain XDG_CACHE_HOME=/tmp/captain \
			godot --headless --path /app scenes/main.tscn -- --server --port=7777
		echo "game server stopped (exit $?), restarting in 2s"
		sleep 2
	done
) &

exec caddy run --config "$CADDYFILE" --adapter caddyfile
