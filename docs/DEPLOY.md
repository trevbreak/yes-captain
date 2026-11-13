# Putting Yes, Captain! on an Unraid server

One container holds everything: the game's web page (served by Caddy) and the game server (Godot, headless)
behind it at `/ws`. Players only need a browser.

> **Status:** deployed and loading on the Unraid server (2026-11-10) from the image GitHub builds. Voice chat
> has not been tried with real microphones yet.

**The game only runs over https, with a certificate the browser fully trusts.** Browsers refuse to start it on
plain `http` (except on `localhost`). And clicking through a certificate warning is not enough: some browsers
(Safari in particular) never extend that exception to the game's live connection, and Chrome's exception lapses
whenever the certificate changes, which Caddy's own self-signed ones do every few hours. Either way the
symptom is "Could not reach the server" on *Find a crew online*.

So at home the container borrows **Unraid's own myunraid.net certificate** (a real Let's Encrypt one) and serves
the game at `https://192-168-0-6.<hash>.myunraid.net:8443`. Every other address sends visitors there.

## 1. The image

Every push to `main` or `v2-redesign` makes GitHub build `ghcr.io/trevbreak/yes-captain:latest`
(`.github/workflows/image.yml`: it exports the web game and flies every mission with a robot crew first).
To update the server afterwards: Docker tab, `yes-captain`, **force update**.

The package is currently public on GitHub, so the server pulls it without a login. The image contains the
game's source. To close it, make the package private and run `docker login ghcr.io` on the server with a token.

To build on the server instead: clone the repo there and `docker build -f deploy/Dockerfile -t yes-captain .`

## 2. Run it on your own network first

Docker tab, **Add Container**, and fill in by hand (or copy `deploy/unraid-template.xml` to
`/boot/config/plugins/dockerMan/templates-user/` and pick it from the Template list):

| Setting | Value |
|---|---|
| Repository | `ghcr.io/trevbreak/yes-captain:latest` |
| Port | container `80` -> host `8480` |
| Port | container `443` -> host `8443` |
| Path | container `/data` -> `/mnt/user/appdata/yes-captain` |
| Path | container `/certs` -> `/boot/config/ssl/certs`, **read only** (Unraid's certificate) |
| Variable `TLS_HOST` | the myunraid.net name of Unraid's own web page, e.g. `192-168-0-6.<hash>.myunraid.net` |
| Variable `LAN_IP` | the server's address, e.g. `192.168.0.6` (a fallback with a self-signed certificate) |

Then, from any computer in the house, open **`http://<server>:8480`**: it sends you to the trusted address.
Type a name, *Find a crew online*, *Open a crew room*, and send the other laptops the invite link. For voice,
the host switches *Voice chat* on in the Crew Room.

The certificate file holds Unraid's private key too. It is mounted read only, and only the web server inside
the container (running as root) can read it; the game server runs as an unprivileged user. Unraid renews the
certificate every couple of months; the container notices within a minute and reloads it.

If Unraid's *Use SSL/TLS* setting has no myunraid.net certificate provisioned, leave `TLS_HOST` empty: the game
then falls back to `https://<server>:8443` with a self-signed certificate, which works in Chrome after clicking
through the warning, but not reliably elsewhere.

Or from the terminal, the same thing in one line:

```bash
docker run -d --name yes-captain --restart unless-stopped -p 8480:80 -p 8443:443 \
  -v /mnt/user/appdata/yes-captain:/data -v /boot/config/ssl/certs:/certs:ro \
  -e TLS_HOST=192-168-0-6.<hash>.myunraid.net -e LAN_IP=192.168.0.6 ghcr.io/trevbreak/yes-captain:latest
```

Check it is alive: `curl http://<server>:8480/healthz` prints `ok`, and `docker logs yes-captain` shows
`Yes, Captain! server on port 7777`.

## 3. Open it to the internet

1. Point your name (e.g. `yescaptain.duckdns.org`) at the fixed IP.
2. On the router, forward **TCP 443 -> server:8443** and **TCP 80 -> server:8480**. Port 80 is needed for the
   certificate; Unraid's own web page is not exposed by this, because 8480 and 8443 belong to the container.
3. Edit the container: set `PUBLIC_HOST` to the name and `HTTPS_PORT` to `443` (the port the outside world
   uses), clear `LAN_IP`, apply.
4. Open `https://<the name>`. The first visit takes a few seconds while Caddy fetches the certificate. It
   renews by itself and lives in the `/data` folder.

What is exposed: one web server and one game server, both inside the container. The game server runs as an
unprivileged user, keeps no accounts and stores nothing about players. Limits: `MAX_ROOMS` crew rooms
(default 20), 10 people per room, and a cap on messages per second from any one player.

### If some friends can't hear each other

Voice goes directly between players' browsers. A minority of home routers block that. The fix is a relay
(a `coturn` container, UDP 3478 forwarded) and three settings on this container: `TURN_URL`, `TURN_USER`,
`TURN_PASS`. Not needed until somebody actually hits the problem.

## Settings

| Variable | Meaning |
|---|---|
| `PUBLIC_HOST` | Your domain name. Turns on real https. |
| `LAN_IP` | The server's LAN address. Switches on self-signed https for playing at home. |
| `TLS_HOST` | A name you already have a trusted certificate for (Unraid's myunraid.net name). Visitors are sent there. |
| `TLS_CERT` | That certificate: one PEM with chain and key (default `/certs/certificate_bundle.pem`). |
| `HTTPS_PORT` | The port https is reached on from outside the container (default 8443; 443 with a domain). |
| `MAX_ROOMS` | Crew rooms that may be open at once (default 20). |
| `TURN_URL`, `TURN_USER`, `TURN_PASS` | Optional voice relay. |
