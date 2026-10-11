# YES, CAPTAIN!

A LAN-party **bridge simulator** in the spirit of *Artemis* and *EmptyEpsilon*, with the
panicky teamwork of *Overcooked*, the slapstick of *Cosmoteer*, and the look of *Two Point Hospital*.

> One captain can see out the window and can't touch anything.
> Everyone else can touch everything and can't see out the window.
> The ship is held together with tape, parts keep breaking, the ship's robot thinks you are all idiots,
> and the galaxy's evil Overlord wants his pet back.

You are Sanitation Crew 7 of the Grubb's Landing Waste Authority. You collected a skip that was
warm and purring. Inside: **Pudding**, the beloved pet of Supreme Overlord Malgrim the Magnificent.
Now the entire Hegemony fleet is hunting a garbage truck (carefully: Pudding must not be harmed).

Built with **Godot 4** (developed on 4.7.2, GDScript only, Compatibility renderer).

---

## Run it

```bash
godot --path .          # or open the folder in the Godot editor and press Play
```

On the title screen:

| Button | What it does |
|---|---|
| **Host a game** | You are the captain. Friends join over the LAN (shows your IP and port 7777). |
| **Solo with IGOR's robot relatives** | You captain, AI crew (with personalities) run every station. Great for learning. |
| **Join** | Type the host's IP. Pick a seat in the lobby. |

A dedicated host (no player, e.g. on a TV box) is also supported:

```bash
godot --headless --path . -- --server --port=7777
```

The first player to join becomes the admin and can launch the game.

**Networking:** WebSocket over TCP port 7777 (open it in your firewall). It works across the internet with a
port-forward or a VPN such as Tailscale. There is no built-in voice chat: shouting across the room is the game
(online crews should use Discord).

## How a session flows

1. **Title screen**: host, play solo with a robot crew, or join by IP.
2. **Crew Room, step 1 "Choose a mission"**: The Run (story campaign) or Shift Work (any single mission), plus house
   rules (party modifiers, robot personality, ship name).
3. **Crew Room, step 2 "Pick your role"**: seven persona cards (Captain Mo Pennywhistle, Dex Wheelwright, Big Sal
   Throttleby, Pip Voltaire, Rhoda 'Boom' Blastworth, Ozzy Squint, Nana Fluffington; Gus Spanner runs Damage Control).
   Take one or several. Under each card you choose what fills it when no human does: a robot personality or nobody.
4. **Mission briefing**: before *every* encounter. A narrator (Thrupp, Ma Gristle, IGOR...) sets the scene, "The Plan"
   lists the numbered steps, and "Your Job" gives a tip for each seat you hold. Everyone presses **I'M READY**, then a
   3-second countdown launches the mission. The host or captain can **Launch now**.
5. **Mission**: the objective tracker at the top shows the current step and ticks steps off as you go.
6. **Debrief** (Black Box replay, what happened, crew awards), then the sector map and jump ritual, then the next briefing.

## How to play

Seven seats. **Nobody sees the whole picture.** Players can take several seats and tab between them with `1`-`7`.
Each station is built around one simple chore that drifts if you ignore it, one "spicy" control behind a flip-up
safety cover, and things that break.

| Seat | You see | You control | Chore | Spicy control |
|---|---|---|---|---|
| **Captain** | The 3D window, objectives on a sticky note, enemy comms, the sector map, the Overlord's Temper | **Nothing.** Accept/decline shared screens, order AI crew, approve spending, say "Punch it" | Telling people things | Order Wheel (`O`) |
| **Helm** | Compass, spin, waypoint bearing | Yaw (`A`/`D`), strafe (`Q`/`E`), trim | Trim drift | Emergency Roll |
| **Engines** | Speed, heat, mixture | Two throttles (`W`/`S`), boost, dampers | Fuel mixture | Dampers OFF |
| **Power** | Reactor and conduits | Power pips, coolant pump (`Space`), isolate conduits, jump capacitor | Reactor heat | Overclock |
| **Weapons** | A narrow gun scope only | Turret aim/load/fire (`Space`, `L`, `T`), torpedoes, target lock | Loading and heat | Torpedoes (they can't read) |
| **Sensors** | The only radar | Scans, comms tuning, **the captain's viewscreen direction**, ping, decoy beacons | Comms drift, stale scans | Active Ping |
| **Ops** | Shields, Pudding, cargo | Shield facings, tractor beam, cargo, repair bot, Pudding care | Pudding's mood | Jettison |
| **Damage Control** (`F`) | The ship's module grid | Anyone can come here to fix things | | |

Things that make it funny:

* **The ship is a grid of physical modules.** Thrusters push from where they actually are, so losing the port engine
  *spins* the ship. Fires spread, hull breaches vent like thrusters, conduits get cut, Pudding eats the wiring.
* **Everything is repairable**, so the cost is attention. Easy faults can be fixed from your own screen. Fires,
  breaches, failed modules and conduits need **Damage Control**, which means leaving your post.
* Conduit splices **zap you** unless Power **isolates** the conduit first (shout at Power).
* **Share to Captain**: any station can offer its screen. It appears on the captain's bridge as a clipboard.
* The **Chaos Director** keeps it Overcooked-busy but fair: every failure telegraphs first, at most three critical
  failures at once, every failure has an owner and a fix.
* **IGOR**, the ship's robot from the Foundry, narrates everything in the third person. He thinks robots are superior.
* The **Black Box** replays disasters after every encounter and hands out awards.

### Modes

* **The Run**: a roguelite journey (about 15 min "quick" or about 45 min "full") across a sector map. Jump ritual
  (Helm coordinates, Power capacitor, Engines speed window, Ops cargo, Captain "Punch it"), 15 kinds of encounter,
  pit stops at Ma Gristle's diner where the crew lobbies the captain for upgrades, the Overlord's **Temper** rising
  as you go, Admiral Thrupp being demoted every time you escape, and four endings.
* **Shift Work**: pick any single encounter, with par times and instant retry.
* **Party modifiers** (lobby): Glass Ship, Dampers Broken, Pudding Mode, EMP Storms (inverted controls), Crew Rotation,
  Jargon Mode.
* **AI crew** with personalities (Eager, Literal, Nervous, Sleepy, Know-it-all...) fill empty seats, and an **AI captain**
  can lead them, or lead *you* with text-card orders. Humans can take over a bot's seat mid-flight, and bots take over
  when a human leaves.

## Project layout

```
sim/        pure game rules (no nodes): Ship (modules, thrusters, power, damage), World (entities, AI,
            projectiles), Intents (every control), Snapshots (per-station filtered views), Director, Encounters
net/        GameHost (authoritative: phases, ritual, bots, Black Box hooks) and Net (WebSocket glue autoload)
bots/       Bot (AI crew with personalities) and BotCaptain
run/        RunState (sector map, upgrades, Thrupp's rank) and BlackBox (replay, awards)
captain/    the 3D viewscreen (toon shaders, models) and the bridge UI
stations/   one UI per station + damage control
ui/         the design system (UIK), widgets, persona cards, menu, Crew Room, briefing, in-game shell, phase
            screens, style guide and the automated LayoutCheck
assets/     bundled fonts and generated SVG art (crew portraits, icons, the ship)
tools/      make_art.py (generates the SVG art) and artboard.gd (renders it all to one PNG for review)
content/    IGOR's lines and procedurally generated sound effects
tests/      headless tests (see below)
docs/       the design docs: plan, story, game loops, art direction, status
```

Design notes worth knowing:

* The world is **simulated in 2D and rendered in 3D**.
* The host is **authoritative**. Clients only send intents. The host sends each seat only what that seat may know
  (the Helm snapshot literally contains no contact list), and a test checks that.
* Bots use the same intent API and the same filtered views as humans.

## Tests

```bash
scripts/run_tests.sh          # everything (~2 min)
scripts/run_tests.sh quick    # skip the long campaigns
```

Covers: physics and damage, every human flow (repair, zap/isolate, tracing, share-to-captain, authorization, jump
ritual, pit stop, game over), party modifiers, an AI captain + AI crew beating **every encounter** and complete
campaigns, the chaos director on overdrive, a networked host + remote client (including an information-leak check),
UI smoke tests that open every screen and press every control, and a **layout check** of every screen at 1280x720,
1440x900 and 1920x1080 (this one opens a window; set `NOWINDOW=1` to skip it on a headless machine).

Debug flags for the main scene (after `--`): `--solo`, `--host`, `--join=IP`, `--server`, `--port=N`,
`--autotest=<encounter>`, `--aicrew`, `--seat=<seat>`, `--shots=<dir>` (screenshots), `--speed=N` (fast-forward),
`--layoutcheck` (visits every screen and reports off-screen, clipped, overflowing or overlapping controls; exit code
is the number of issues), `--styleguide` (shows every UI component).

## Notes

* Fonts are bundled: Fredoka (headings) and Nunito (body), both SIL Open Font License (`assets/fonts/`). Portraits and
  icons are SVGs generated by `tools/make_art.py` (run `python3 tools/make_art.py` to regenerate them). Sound effects
  are synthesized at startup, and IGOR's voice uses the OS text-to-speech (toggle it in the menus).
* The setting is original. It is *inspired* by Star Wars but uses none of its IP (see `docs/STORY.md`).
* See `docs/STATUS.md` for what is built and what is deliberately left for later.
