# Putting Yes, Captain! on an Unraid server

One container holds everything: the game's web page (served by Caddy) and the game server (Godot, headless)
behind it at `/ws`. Players only need a browser.

> **Status:** the pieces have been tested separately (the web build in a browser against the game server, two
> players in one room). The container image itself had not been built when this was written: the first build
> on your server is its first real test. If a step fails, the build log says which.

## 1. Build the image

Unraid has no "build" button, so use its terminal (the `>_` icon, top right).

```bash
cd /mnt/user/appdata
git clone https://github.com/trevbreak/yes-captain.git yes-captain-src
cd yes-captain-src
git checkout v2-redesign
docker build -f deploy/Dockerfile -t yes-captain .
```

The repository is private, so `git clone` will ask for your GitHub user name and a personal access token.
The build downloads Godot (about 1.3 GB, once), exports the web game, and flies every mission with a robot crew
before it will produce an image. Allow 10 to 15 minutes. If the tests are the thing that fails, you can still
get an image with `docker build --build-arg SKIP_TESTS=1 ...`, but tell me what failed.

Later, to update: `git pull` and run the same `docker build` again, then restart the container.

(Alternative: `.github/workflows/image.yml` builds the image on GitHub and pushes it to
`ghcr.io/trevbreak/yes-captain` whenever `main` changes. Unraid then needs a token to pull a private image.)

## 2. Run it on your own network first

Docker tab, **Add Container**, and fill in by hand (or copy `deploy/unraid-template.xml` to
`/boot/config/plugins/dockerMan/templates-user/` and pick it from the Template list):

| Setting | Value |
|---|---|
| Repository | `yes-captain` (the image you just built) |
| Port | container `80` -> host `8480` |
| Port | container `443` -> host `8443` |
| Path | container `/data` -> `/mnt/user/appdata/yes-captain` |
| Variable `LAN_IP` | the server's address, e.g. `192.168.1.50` (optional: only needed to try voice chat at home) |

Then, from any computer in the house:

* **`http://<server>:8480`** is the game. Type a name, *Find a crew online*, *Open a crew room*, and send the
  other laptops the invite link (or have them open the same address and click JOIN).
* Voice chat does not work on plain `http`: browsers only allow the microphone on `https`. With `LAN_IP` set,
  use **`https://<server>:8443`** instead. The certificate is self-signed, so each browser warns once
  ("Advanced", "Proceed"). Then the host switches *Voice chat* on in the Crew Room.

Or from the terminal, the same thing in one line:

```bash
docker run -d --name yes-captain --restart unless-stopped -p 8480:80 -p 8443:443 \
  -v /mnt/user/appdata/yes-captain:/data -e LAN_IP=192.168.1.50 yes-captain
```

Check it is alive: `curl http://localhost:8480/healthz` prints `ok`, and `docker logs yes-captain` shows
`Yes, Captain! server on port 7777`.

## 3. Open it to the internet

1. Point your name (e.g. `yescaptain.duckdns.org`) at the fixed IP.
2. On the router, forward **TCP 443 -> server:8443** and **TCP 80 -> server:8480**. Port 80 is needed for the
   certificate; Unraid's own web page is not exposed by this, because 8480 and 8443 belong to the container.
3. Edit the container: set `PUBLIC_HOST` to the name, clear `LAN_IP`, apply.
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
| `LAN_IP` | The server's LAN address. Adds self-signed https for testing voice at home. |
| `MAX_ROOMS` | Crew rooms that may be open at once (default 20). |
| `TURN_URL`, `TURN_USER`, `TURN_PASS` | Optional voice relay. |
