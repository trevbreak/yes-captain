# YES, CAPTAIN! v3 — Online sessions, a stronger loop, a more finished look

Status: built, on the `v2-redesign` branch (2026-11-10). This document is the plan as it was written; the
"What changed while building" list just below says where the result differs. To deploy, see `DEPLOY.md`.

**What changed while building**

* **Glitch fixes became the main idea.** A glitch is not fixed by the Engineer alone: IGOR's manual names
  somebody else who must do something with their own control while the Engineer holds REPAIR. Borrowed from
  Spaceteam (instructions for other people's panels), and it gives the Engineer a constant queue.
* **Radio calls** were added for the same reason: callers only Sensors can hear ask the ship to do silly things
  for a bonus. This is Sensors' constant job, in place of the "contacts fade unless re-scanned" idea, which was
  a chore rather than a joke.
* **Cut:** "the gun can't fire through the shield" (flagged as the riskiest interlock), "crossed wires" (two
  crew swap screens; too many edge cases when players drop), engine wear, job of the day, the Mole, rival crews.
* **The Shift opens after two training missions**, not after all ten, so a new group reaches it in ten minutes.
* **Hats and the sticker album are not built.** Awards are counted in the career file, ready for one.
* **Voice chat is built but untested end to end** (it needs two machines with microphones on https).
* **The container image has not been built yet.** Its parts were tested separately.

---

Original plan, written from a read of the v2 code and screenshots:

The goal: one Docker container on the Unraid server. Anyone who opens the site sees the title card and a board
of open sessions, hosts or joins one, readies up in the Crew Room, and plays in the browser. Alongside that, the
game loop and the art get a proper pass.

## 1. Where v2 stands

What makes this cheaper than it sounds:

* `GameHost` never touches the network and the sim is plain objects, so one server process can run many rooms.
* The host is already authoritative and already filters what each seat may know.
* A headless dedicated host, seat claiming, host hand-over, rejoin and robot fill-in all exist.
* Transport is already WebSocket, which is the only thing a browser can speak.
* Everything is 2D on the Compatibility renderer, which is what Godot's web export wants.

What is in the way:

| Problem | Where | Fix |
|---|---|---|
| One game per process | `net/net.gd` holds a single `host` | A hub that owns many rooms (section 2) |
| Career progress is a global static saved on the host's disk | `run/progress.gd` | Per-room career, kept in the host player's browser |
| Art, fonts and JSON are read as raw files at run time | `ui/art.gd`, `ui/uik.gd` | Export filter must include `*.svg, *.json, *.ttf`, or they vanish from the web build |
| Join is "type an IP" | `ui/menu.gd` | Sessions board; the address comes from the page URL |
| Browser steals **Tab** and **Esc** | Sensors and menu keys | Rebind (e.g. **Q/E** cycle blips, **M** or the button for menu) |
| Browsers block sound until a click | `content/sfx.gd` | Start audio on the title card's first click |
| IGOR's voice depends on the OS voice list | `content/sfx.gd` | Works through the browser's speech API; voices differ per browser, subtitles stay on always |
| Layouts are checked for full windows | `ui/layout_check.gd` | Add browser-shaped sizes (1366x650, 1536x730, 1280x620): a browser loses 100px+ of height to its own chrome |

Not verified yet: an actual web export. Export templates are not installed on this Mac, so phase 0 is a spike
that proves it before anything else is built.

## 2. Online architecture

```
Browser ──https──> fixed IP, ports 443 + 80 forwarded ──> container
                                                          ├─ Caddy: TLS, serves the web build (/)
                                                          └─ /ws ──> Godot headless server :7777
                                                                      Hub ─ Room "PUDD" (GameHost)
                                                                          ─ Room "SKIP" (GameHost)
```

**One container.** Caddy serves the exported game and proxies `/ws` to the Godot server inside the same
container. The server is reached the way it is today: fixed IP and a forwarded port.

**It needs a domain name and HTTPS.** Browsers only allow the microphone on https pages, so voice chat cannot
work on a bare `http://<ip>:port` address. Caddy fetches and renews a free certificate by itself once a name
points at the fixed IP and ports 443 and 80 are forwarded. A free dynamic-DNS name is enough. Without a name the
game still runs over plain http, just with no voice.

**The hub** (new `net/hub.gd`, server only) replaces the single `Net.host`:

* `rooms`: code -> `{GameHost, name, listed, host peer, last activity}`, and peer -> room.
* Client messages before a room: `rooms` (list), `create {name, listed, career}`, `join {code}`.
  Everything already in `GameHost.handle_msg` is routed to the peer's room unchanged.
* Peers on the sessions board get the room list pushed when it changes: name, host, players n/7, mission, phase.
* Room codes are four letters. `https://<site>/?room=PUDD` joins directly, so a host can paste a link.
* Every room is listed on the public board. The room record carries a `listed` flag so invite-only rooms can be
  added later without reworking anything; there is no switch for it in v3.
* Joining a room mid-mission is allowed: you take over a robot's seat. That path already exists.
* Empty rooms close after 2 minutes; idle rooms after 30.

**Crew Room changes** to match the flow asked for:

* Every player has a READY toggle. The host's START lights up when everyone seated is ready (host can override).
* The captain's seat must be held by a human. Without one, nobody has the chart.
* Host can kick. Host leaving hands over to the next player (exists).
* The existing per-mission briefing ready-up stays: it is "I've read it", not "I'm here".

**Career per room.** `Progress` becomes an object owned by the room. The host's browser stores it (IndexedDB via
`user://`) and sends it on create; the server sends back updates when stars are earned. The server stores nothing
about players. New rooms from a first-time host start at mission 1; a veteran's room has everything they unlocked.

**Solo and LAN keep working.** The desktop build still hosts locally through the same `GameHost`, so the existing
tests stay valid. In the browser, "Play with a robot crew" creates a room like any other.

**Because it is on the open internet:**

* Cap rooms (say 20), connections, players per room (7 seats + 3 watching), message size and messages per second.
* Validate every field of every message; names trimmed to 16 characters and stripped of control characters.
* Godot's RPC does not decode objects by default: keep it that way.
* No accounts, no personal data, nothing written to disk except an optional scoreboard file on a volume.
* A new test: two rooms on one server, and proof that nothing from room A reaches a peer in room B.

**Voice chat, per room, on or off.** The host picks in the Crew Room: **"We're in the same room"** (no
microphones) or **"We're remote"** (voice on). Each player has a mute button.

* Built in the browser, not in Godot: a small script in the page connects the players in a room directly to each
  other (WebRTC). The game's own socket carries the handshake, so the hub only forwards a few small messages
  between peers in the same room. Audio never passes through the game server.
* Seven players at most, so a direct mesh is fine.
* Who is talking is known to the page, so the speaker's portrait can flap its mouth.
* Browser build only. The desktop build has no voice.
* The catch: a minority of home networks cannot connect directly. Those pairs need a relay (a `coturn`
  container on the same Unraid box, one more forwarded port). Start without it, add it if a playtest hits it.
* Needs HTTPS (above).

## 3. Docker and Unraid

Files to add: `export_presets.cfg` (a Web preset and a Linux dedicated-server preset), `deploy/Dockerfile`,
`deploy/Caddyfile`, `deploy/entrypoint.sh`, `deploy/unraid-template.xml`, `.github/workflows/image.yml`.

* **Build stage:** download Godot 4.7.2 and its export templates, run the headless tests, export the web build
  and the server pack. Pre-compress the web files (the engine is roughly 35-40 MB raw, around 9 MB compressed).
* **Run stage:** slim Debian, Caddy, the Godot Linux binary, the server pack, the web folder. One exposed port, a
  `/healthz` route, an optional `/data` volume. Settings by environment variable: `MAX_ROOMS`, `PUBLIC_URL`.
* **Image:** GitHub Actions builds `linux/amd64` and pushes to GHCR on every push to `main`. The repo is
  private, so Unraid needs a read-only token to pull, or the image can be built on the server instead.
* **Unraid:** a template XML so it installs from the Docker tab like any other app.
* **Getting it onto the internet:** as today, the fixed IP with ports 443 and 80 forwarded to the container, and
  a name pointing at the IP. A volume keeps Caddy's certificates across restarts. If the security stance changes
  later, a Cloudflare Tunnel can sit in front without touching the game: Caddy then serves plain http to the tunnel.

## 4. The game loop

### What is weak today

1. **Missions are checklists.** Each one is a fixed list of steps done in order. The captain reads the current
   step and a forecast that already says whose face to shout at. That is relaying, not captaining.
2. **Seats have dead time.** Engines sets a lever and waits. Sensors scans three blips and then shows "Idle".
   The Engineer waits for something to break. Several hints literally say "Nothing for you yet".
3. **All talk goes through the captain.** Crew never need each other directly.
4. **Robots solve the game.** With three humans and four robots, the robots do their jobs perfectly and
   silently, so more than half the ship needs no talking at all.
5. **No reason to come back.** Ten missions, about 40 minutes, then it is over. The stars are "finished, hull
   above 60%, under par", the same for every mission.
6. **Balance was tuned by robots**, never by people.

### The principle: add rules, not buttons

This keeps the v2 promise (one new thing per mission, few big controls). Every change below adds talk without
adding a control.

**A. Interlocks between seats.** Small rules that make two crew need each other:

| Rule | Who has to talk |
|---|---|
| The ship turns tighter when it is slow | Helm and Engines |
| A system repairs twice as fast while nobody is using it | Engineer and whoever is using it |
| Scanned targets show a lead marker in the gun scope; unscanned ones are silhouettes | Sensors and Weapons |
| The gun cannot fire through our own shield arc | Weapons and Shields |

Each is introduced by a mission like any other mechanic. Each needs a human playtest; the shield one is the
riskiest and the first to cut.

**B. A captain who decides.** Keep the forecasts (they are the captain's eyes). Add choices only the captain can
see on the chart: an optional cargo pod off the route, a short cut through mines, a second fire while the
Engineer is busy. From mission 3 on, every mission gets at least one moment where two things want the same crew
member at once.

**C. No seat idle for more than ten seconds.**

* *Engines:* rule A1 gives constant trimming from mission 1; heat takes over from mission 3.
* *Sensors:* the chart is only as good as Sensors. Moving contacts fade to a "last seen" ghost on the captain's
  chart unless Sensors keeps them scanned. Sensors becomes a continuous job, like Shields.
* *Engineer:* wear. Systems that work hard show "loose" before they break; tightening one early is quick.
* Remove every "Nothing for you yet" hint; if a step truly has nothing for a seat, the step is wrong.

**D. Small crews without silent robots: paired seats.** No new screens. The Crew Room offers the six stations as
three pairs, and a player who takes a pair flips between its two existing screens:

| Pair | Screens |
|---|---|
| **Pilot** | Helm, Engines |
| **Gunner** | Weapons, Shields |
| **Tech** | Sensors, Engineer |

* Four players crew the whole ship with no robots: Captain, Pilot, Gunner, Tech. Three players leave one pair to
  robots. Five to seven split pairs back into single seats.
* One big FLIP button (and one key) replaces the 1-7 strip for a pair. The sticky wheel, throttle and dials
  already stay where they were left, which is what makes flipping playable.
* You only see the screen you are on, so the captain has to tell you when to flip. That is more talk, not less.
* Most of this exists: a player can already hold several seats and the server already sends only the active one.

**E. Small things for the career missions.**

* The third star becomes **IGOR's dare**, different per mission ("Don't shoot Bernard", "Pudding never
  escapes", "Never go above half throttle"). Par time stays as the second star.
* The debrief offers **SHUFFLE SEATS**, so everyone gets a turn as captain.
* Failing is quick and funny: retry within five seconds, with one line on what did it.

## 5. Sustained fun: why a crew comes back

The career is training. It is the same ten missions every time, and it should be: it teaches. What a crew plays
on every later visit is **the Shift**, and no two shifts are alike. Novelty comes from four layers, each on a
different clock.

### Layer 1, every minute: glitches

The ship is a garbage hauler held together by IGOR's contempt. Things go wrong with it, and each thing that goes
wrong **bends a rule of one existing control**. No new buttons.

| Glitch | What happens | Who knows |
|---|---|---|
| Wheel's on backwards | Left is right | Helm finds out the hard way |
| Drunk compass | Helm's compass reads 90° off | Only the captain can tell |
| Sticky throttle | It creeps back up by itself | Engines |
| Gun pulls left | Shots drift off the crosshair | Weapons |
| Shield dial slipped | The shield sits two hours off where the dial says | The captain sees it on the chart; Shields doesn't |
| Ghosts on the radar | Blips that aren't there | Nobody, until Weapons finds nothing to shoot |
| Chart's upside down | South is up on the captain's chart | The captain, eventually |
| IGOR is rebooting | No forecasts for 20 seconds | The captain goes quiet, then loud |
| Labels fell off | The Engineer's ship drawing has no names | Engineer |
| Pudding is sitting on it | One control is stuck until Pudding is petted or bribed | Whoever's control it is |
| Crossed wires | Two crew swap screens for 30 seconds | Both, at once, loudly |

Why this is the highest-value thing in the plan:

* **The comedy is in who knows.** Either the crew member discovers it and has to convince the captain, or the
  captain sees the symptom and has to work out which meat-brain is lying. That is the game's core idea, applied
  again.
* **It gives the Engineer a real job.** Every glitch is a fault in a room on the ship drawing. The Engineer
  fixes it like any breakage, so there is always a queue and always a choice of what to fix first.
* **Cheap to build.** A glitch is a small object with two hooks: one bends an input on its way into `Intents`,
  one bends a view on its way out of `Snapshots`. Both run on the server, so clients stay simple. Each glitch is
  a few dozen lines, and thirty of them is a deck.
* **They combine.** Backwards wheel is a joke. Backwards wheel in a minefield while the compass is drunk is a
  story people retell.

### Layer 2, every job: jobs built from parts

A job is dealt, not written:

> **a place** x **a task** x **one or two twists**

* **Tasks** (all exist as mission steps today): haul it in, deliver it hot, ride it out, get inspected, sink the
  big one, outrun it, clear the nest, cross the field.
* **Places** change the ground: rock belt, minefield, meteor alley, a fog bank that halves radar range, a
  junkyard full of things worth grabbing, the busy lane outside a Hegemony post.
* **Twists** change one number or rule: Pudding is grumpy today, reactor's down to four bars, Thrupp is
  watching (a patrol shadows you all job), fragile cargo (bumps cost pay), rush order (half the par time).

Eight tasks, six places and a dozen twists is several hundred jobs before any glitch fires.

**A director paces each job** instead of fixed timers. It holds a budget of trouble, spends it in waves, then
backs off so the crew can breathe and laugh. It never stacks more than two crises on one crew member. v1 had one
of these (the Chaos Director); the idea is sound and worked, it was just switched on from minute one.

**Captain's calls.** The director also drops optional things only the captain's chart shows: a distress call
off the route, a drifting pod worth a bonus, a short cut through the mines. The captain has no buttons, so the
choice is made by flying there or not.

**Robots keep it honest.** Every generated job gets flown by robot crews across many seeds in the test suite,
as the ten missions are today. A combination robots cannot finish is thrown out of the deck.

### Layer 3, every sitting: the Shift

About 20 minutes, three jobs, one arc:

1. **The job board.** Three job cards, each showing pay, danger and its twist. The crew argues and the captain
   picks. The safe one pays badly.
2. **Fly it.** Pay comes off for damage, lateness and anything IGOR finds embarrassing.
3. **IGOR found a part.** Between jobs, pick one of two bodged upgrades. Each has a catch: *bigger engine,
   runs hot*; *wider shield, drinks power*; *fast-load torpedoes, gun jams sooner*. No shop, no money to spend,
   one pick. Two picks per shift make each ship different by the last job.
4. **Rent is due.** The depot wants a set amount by the end of the shift. Make rent and the crew keeps its
   berth; miss it and IGOR reads out a formal notice. Either way: awards, a seat shuffle, "one more shift?".

A quota that the whole crew is short of is the strongest "one more go" hook there is for a group, and it turns
the job board into a real decision: the third job is where crews get greedy.

### Layer 4, across weeks: the deck grows

* **One new card per shift.** The v2 rule carried on forever. A finished shift adds exactly one new card to the
  crew's deck (a glitch, a place, a twist, an enemy) and IGOR introduces it at the next briefing, in the same
  "NEW TODAY" slot the career uses. A crew twenty shifts in is playing a much wilder game than a new crew, and
  nobody was ever handed more than one new thing at a time.
* **The logbook.** The awards that already exist (*Duct Tape Hero*, *IGOR's Disappointment*) become stickers
  in an album, kept in the browser. Some are only possible under particular glitches.
* **Hats.** Small drawn hats and ship paint earned by stickers. Pure show, and people do come back for hats.
* **Job of the day.** One seed, the same job for every room, with the day's best crews on the title page. This
  is the only feature that writes to the server's disk.
* The deck belongs to the room's host. A host can deal a **green crew** deck (career cards only) when new
  friends join, so they are not thrown in at shift twenty.

### Later modes, once the above is fun

* **The Mole.** One crew member is secretly on Thrupp's payroll and has to make the shift miss rent without
  being caught. The game already hides what each seat can see, which is exactly what this needs.
* **Rival crews.** Two rooms fly the same job at once; each sees the other's progress on the chart.

### What to build first

Glitches. They need no new screens, no new art beyond a few icons and no new structure, they work inside the
existing ten missions, and they are the thing most likely to make a session feel different from the last. The
Shift comes second, because it needs the job builder and the director under it.

## 6. Art and layout

The direction is right: ink, paper, grain, rubber-hose animals. What stops it reading as finished:

**Bugs visible in the screenshots**

* Luckiest Guy has odd lowercase glyphs, so mixed-case headings render as "HeGemony cRuiseR chaRGinG" and
  "FiRe ToRPeDo". Uppercase every string set in that font, in one place (`UIK.head` / button text).
* "WEAK SPOT" is clipped by the top of the gun scope.
* The NEXT chip and IGOR's line both truncate with "...". Give IGOR two lines; drop the NEXT chip (the mission
  panel already shows it).
* The ship board bars read "ENGINES 0%" and "GUN 0%" with no hint that they mean heat.
* The 1-7 seat switcher takes a quarter of the bottom bar even when you hold one seat. Hide it then.

**From "panels with props" to "a place"**

* **Each station is a desk.** Today the hero prop floats on a blank cream panel with a lot of empty paper (Helm
  is the clearest case). Draw each station as a console: the wheel on a wooden binnacle, the throttle in a brass
  quadrant, bolts, pipes, a mug, a note taped on by IGOR. The prop stays the only thing you touch.
* **Each station has its colour.** A wash of the seat colour on the desk, so you know whose screen you are
  looking at from across a room or in a shared screen.
* **The captain's chart is a chart.** Swap the graph-paper grid for an inked sea chart: compass rose, hand
  lettering, coffee ring, contacts as little drawings, a dashed pencil line for our wake.
* **The crew have faces.** Portraits get four expressions (calm, busy, panic, cheer) driven by state. The
  captain's crew board becomes a row of reacting faces. Each station shows its own character in the corner.

**Motion, which is most of the Cuphead feel**

* **Line boil.** `tools/make_art.py` already wobbles the outlines. Emit three wobble variants of the hero props
  and portraits and cycle them at 8 frames a second. Nothing else gives as much "hand-drawn" per hour of work.
* Squash and stretch on every button press and on hits; a short screen shake on damage.
* Iris-in and iris-out between briefing, mission and debrief. A title card for each mission.
* An animated title screen: the ship bobbing, Pudding peeking out of the skip.

**Sound**

* One looping ragtime or hot-jazz bed that speeds up as the hull drops, in place of silence.
* Keep the synth clicks for controls; replace boom, alarm and hit with fuller ones.

**Web load**

* A themed loading card (paper, the ship, a progress bar) instead of Godot's default.
* Rasterizing roughly 370 SVGs at run time may be slow in a browser. If the spike shows that, bake them to PNG
  at build time.

## 7. Order of work

| Phase | What | Done when |
|---|---|---|
| 0 | **Web spike.** Install templates, add the Web preset, fix what breaks (file filters, keys, audio, IGOR's voice). | A browser tab joins a desktop-hosted game and plays a mission |
| 1 | **Rooms.** Hub, per-room career, sessions board, Crew Room ready/start/kick, paired seats, invite links, limits, the cross-room leak test. | Two rooms run side by side on one server; all tests pass |
| 2 | **Container.** Dockerfile, Caddy with its own certificate, GitHub Actions image, Unraid template. | Friends play from a public https address |
| 3 | **Voice.** Per-room on/off, mute, talking portraits. | Three remote players hear each other |
| 4 | **First human playtest.** The bug list in section 6, browser layout sizes, the loading card. | A real session of 3+ people, notes taken |
| 5 | **Glitches and interlocks.** The glitch hooks, a first deck of ten, the seat interlocks, no dead time. Inside the existing missions. | The same mission plays differently twice running |
| 6 | **The Shift.** Job builder, director, job board, rent, bodged upgrades, robot soak tests for dealt jobs. | A 20-minute shift with three dealt jobs |
| 7 | **The deck grows.** One card per shift, logbook stickers, hats, green-crew deck. | A crew has a reason to play a fifth shift |
| 8 | **Look.** Desks, chart, expressions, line boil, transitions, music. Can run alongside 5 to 7. | New README screenshots |
| 9 | Job of the day, the Mole, rival crews. | Only if wanted after playtests |

Online goes first on purpose. Every balance number in the game was set by robots, so the loop work from phase 5
on should be steered by real sessions, and real sessions need phases 0 to 2.

## 8. Decided

* **Reaching the internet:** fixed IP and port forwarding, as today. A tunnel can be added later.
* **Sessions:** all listed on the public board. Invite-only is kept possible, not built.
* **Small crews:** paired seats that flip between two existing screens. No merged screens.
* **Voice:** built in, switched on or off per room.
* **Priority:** a loop that stays new: glitches, dealt jobs, the Shift, a deck that grows.
* **Server name:** a free dynamic-DNS name (DuckDNS or similar, e.g. `yescaptain.duckdns.org`) pointing at the
  fixed IP. The name goes into the container as `PUBLIC_HOST`; Caddy gets the certificate from it. Because the
  IP is fixed, the name is set once and needs no updater. Trev registers the name; it is needed by phase 2.

## 9. Still open

1. **Rent and upgrades (layer 3):** in, or keep the Shift to "three dealt jobs and a score" at first?
