# YES, CAPTAIN — Game Plan (overview)

A LAN-party bridge simulator in the spirit of Empty Epsilon and Artemis, with the busy, silly
energy of Overcooked, Golf With Your Friends, and Meccha Chameleon, the breakable-ship slapstick
of Cosmoteer, and the look and humour of Two Point Hospital.

> **The pitch:** One captain can see out the window and can't touch anything.
> Everyone else can touch everything and can't see out the window.
> The ship is held together with tape, parts keep breaking, the ship's robot thinks you're
> all idiots, and the galaxy's evil Overlord wants his pet back.

> **Implementation:** the game described here is built. See [../README.md](../README.md) to run it and [STATUS.md](STATUS.md) for what is done and what was deferred.

## Document map

| Doc | What's in it |
|---|---|
| **GAME_PLAN.md** (this) | Decisions, pillars, roles summary, tech, phases, risks |
| [STORY.md](STORY.md) | Premise, factions, characters, campaign arc, the Overlord's Temper, IGOR's voice guide, IP guardrails |
| [GAME_LOOPS.md](GAME_LOOPS.md) | Every loop from seconds to weeks, station loops, the breakable ship, the Chaos Director, encounters, AI crew, modes, playtest targets |
| [ART_DIRECTION.md](ART_DIRECTION.md) | The Two Point-in-space look: palette, shapes, captain view, station UI kit, VFX, audio |

---

## 1. Decisions so far

| Topic | Decision |
|---|---|
| **Engine** | Godot 4.7, GDScript (C# can't export to web) |
| **Devices** | **Laptops and PCs are the primary target.** Tablets work and phones are best-effort. Not a mobile game. |
| **Play** | **LAN-first, but online-ready from day one.** The netcode doesn't assume LAN, and real online play arrives in a later phase. |
| **Testing** | **Build AI crew early.** One person can play captain with a bot crew, so the dynamic gets tested before friends are needed, and humans drop in to replace bots. |
| **Art** | Chunky low poly, rounded, warm and saturated: Theme Hospital and Two Point Hospital in space |
| **Ship damage** | Cosmoteer-style modular ship. Parts break with physical consequences (one engine out means you spin), but **every part is fully repairable mid-flight**. The crew has to find and fix it. |
| **Pacing** | Overcooked-busy: always something to do. A Chaos Director keeps it "almost in control". |
| **Setting** | Original. A garbage-hauler crew accidentally collects **Pudding**, the evil Overlord's beloved pet, and the whole Hegemony fleet hunts them but can't harm the pet. Inspired by Star Wars, no IP. |
| **Ship AI** | **IGOR**: a deadpan robot from the Foundry who talks about himself in the third person, tells stories about robot culture, and thinks the humans are hopeless. He's the game's PA announcer and tutorial voice. |

## 2. Pillars

1. **Nobody has the whole picture.** Talking is the game.
2. **Split single actions across people.** Comedy lives in the gap between them.
3. **Always busy, almost in control.** Chores drift, parts break, and requests collide, and
   the Chaos Director stops it tipping into helplessness.
4. **Break it, find it, fix it.** Breakdowns are temporary problems that pull people off their
   posts, which causes the next problem.
5. **Failure is a spectacle.** Visible damage, the Black Box replay, awards, and fast retries.
6. **Learnable in 60 seconds.** Every station has 3–5 core controls, a chore, and one spicy
   control behind a flip-up cover.
7. **The captain is the hub.** They always hold information that nobody else has.

## 3. Roles (details in GAME_LOOPS §3)

| Role | One-liner |
|---|---|
| **Captain** | Sees out the window (on the TV). Holds the objectives, enemy comms, and the map. Touches nothing. |
| **Helm** | Points the ship. Fights drift. Has the Emergency Roll. |
| **Engines** | Speed and per-engine throttles. Watches heat and fuel mixture. Has the Dampers OFF switch. |
| **Power** | Splits the power pips between systems. Keeps the reactor cool. Has Overclock. |
| **Weapons** | Turret arcs and hand-loaded torpedoes. Torpedoes don't care who they hit. |
| **Sensors & Comms** | Has the only map. Scans contacts and tunes comms. Points the captain's viewscreen. |
| **Ops** *(optional)* | Shield facing, tractor beam, ridiculous cargo, repair bots. Has Jettison. |
| **Damage Control** | Not a role but a **shared screen** anyone can tab to. Fixing things there means leaving your post. |

With fewer players, people claim several stations and tab between them, and AI temps can fill
the rest.

---

## 4. Tech plan

### 4.1 Simulate in 2D, render in 3D
- The world is simulated on a **2D plane** with rigid-body Newtonian physics.
- **The ship is a grid of modules** (data-defined). Each thruster applies force at its own
  position, so **asymmetric damage creates real torque**. Spins and drift emerge from the physics
  instead of being scripted. Power flows through conduits on the grid, and fire spreads to
  neighbouring modules.
- The captain sees the world in **low-poly 3D**. Stations are 2D Control-node UIs.

### 4.2 Network architecture (online-ready)
```
          ┌──────────────── HOST (authoritative) ────────────────┐
          │  Sim @ 30 Hz (pure GDScript classes, no nodes)       │
          │  Chaos Director · Encounter scripts · Black Box rec  │
          │  Per-station view filters → snapshots @ 20 Hz        │
          └───────▲───────────────────────────────┬──────────────┘
         intents  │                               │ filtered snapshots
     ┌────────────┼─────────────┬─────────────────┼───────────┐
  Captain 3D   Helm UI     Engines UI   …    Bot (Power)   Bot (Sensors)
  (TV)         (laptop)    (laptop)          (in-process or remote — same API)
```
- **Server-authoritative host**, usually running inside the captain's game. A **headless host**
  mode exists from day one for Crew vs Crew and for online play later.
- **Clients send intents only**, for example `set_control("engines.throttle_port", 0.6)`. The host
  checks that the sender owns that station.
- **Per-station filtered snapshots.** A station only *receives* what that station can know.
  This enforces the information asymmetry, is light on bandwidth, and keeps bots honest.
- **Bots are just clients** using the same intent API and filtered view, so swapping a human
  in for a bot (or a bot in for a human) is seamless.
- **Transport:** `WebSocketMultiplayerPeer`. It works over LAN and internet, in desktop and
  web exports. Clients interpolate snapshots and tolerate around 150 ms of latency from the start,
  so moving online isn't a rewrite.
- **Joining:** room code plus IP/QR shown on the TV, with optional LAN auto-discovery.
  Reconnecting puts a player back in their seat.
- **The online path later:** host port-forward first, then a tiny relay/lobby server, then
  Steam networking if the game ever ships there. **No built-in voice chat.** Online crews use Discord.

### 4.3 Project layout
```
yes_captain/
  project.godot
  sim/          # rules + state: rigid body, module grid, thrusters, power graph, damage, fire
  director/     # Chaos Director
  net/          # host, client, lobby, intents, snapshot filters, reconnect
  bots/         # bot client, personalities, order parser, competent-temp soak tester
  captain/      # 3D viewscreen, diegetic window UI, share clipboard, bridge cam
  stations/     # helm/ engines/ power/ weapons/ sensors/ ops/ damage_control/
  ui_kit/       # rounded Two Point-style controls: levers, dials, candy buttons, covers
  encounters/   # data-driven encounters (.tres + small trigger scripts + layout scenes)
  run/          # sector map, jump ritual, pit stop, overlord temper, save
  blackbox/     # recorder, replay, highlight detector, awards
  content/      # ships (module layouts), models, audio, IGOR & Thrupp lines
  tests/        # GUT/gdUnit4 for sim/, director/, bots/
```

### 4.4 Tuning & testing infrastructure (built early, pays off forever)
- All tunables (thrust, damage, chore drift, director thresholds) live in `.tres` resources.
- A **God station** on the host can see everything, spawn things, break modules on demand,
  and skip encounters.
- **Headless soak tests:** crews of Competent Temp bots run every encounter repeatedly to prove
  it's solvable and to tune the Chaos Director.
- The **Black Box log doubles as telemetry**: idle time, requests, open faults, and retry time
  (playtest targets in GAME_LOOPS §13).

---

## 5. Build phases

The first goal is to prove the dynamic is funny with bots, then with people, before building
content. The duration estimates assume part-time work.

### Phase 0: Napkin test (an evening, optional)
Paper prototype one encounter with a "captain" who sees a drawing and crew who each hold one
paper control. Check whether people laugh.

### Phase 1: Skeleton you can play alone (~2 weeks)
- Godot project, sim core (rigid body plus a module grid with per-thruster forces), host and
  client over WebSocket, room code, and station claiming and tabbing.
- Greybox 3D captain view, and ugly-but-working **Helm, Engines, and Power** stations.
- **Bot crew v0** (Competent Temp) plus the captain's **Order Wheel**.
- A first breakage: an engine fails and the ship spins, with a Damage Control repair.
- ✅ **Done when:** you can captain a bot crew solo, an engine fails, the ship spins, and a
  friend on another laptop can take over a bot's station mid-flight.

### Phase 2: "Bin Day" vertical slice (~4 weeks)
- All five core stations, each with its chore and spicy control. Ops merged into Power.
- The damage model: module stages, telegraphs, conduits, fire, breaches-as-thrust, the
  find-and-fix loop, and UI damage overlays.
- **Chaos Director v1.**
- **Four encounters**, one from each of Precision, Stealth & Bluff, Combat (grabber drones), and
  Ritual (The Jump), on a mini sector map. That's Act I of the story.
- **Bot personalities** (Eager, Literal, Nervous, Sleepy) and the Black Box v1 micro-reel.
- A first pass of the **Two Point art kit**: UI kit, one ship, Pudding, grabber drones, and the captain's window.
- ✅ **LAN playtest with mixed humans and bots.** Measure the playtest targets and count laughs.
  **Don't move on until it's funny.**

### Phase 3: The Run (~4–5 weeks)
- All three acts, Thrupp and his demotions, the Overlord's Temper, Pudding's Mood, Pit Stop budget meetings,
  and Hull Integrity across the run.
- The Ops station, ridiculous cargo and odd jobs, boarding pods, the Bastion cruiser, the
  finale, and the endings.
- IGOR and Thrupp lines, the full Black Box with awards ceremony, and the session loop
  (captain's hat passing).
- **Time-boxed spike (1 week): voice orders.** Try the keyword grammar first and the LLM
  interpreter second, and keep whichever is fun.

### Phase 4: Party & PvP (~3 weeks)
- Shift Work (party course) with stars and modifiers, Crew vs Crew on a headless host, and The Mole.

### Phase 5: Online (~2–3 weeks)
- Relay/lobby server, reconnection hardening, bots dropping in for absent players, and
  latency testing over real internet.

### Phase 6: Polish
- Audio pass, VFX, more hulls and hats, accessibility (colour-blind modes, shake toggle),
  web-export station clients for tablets, and the bot captain.

---

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| **Chaos becomes helplessness** | The Chaos Director's hard rules: telegraphs, a maximum of 3 critical faults, slow cascades, and graceful degradation. Every part is repairable. Playtest targets are tracked. |
| **The captain is bored or passive** | Exclusive info every encounter (sticky-note objectives, comms, map, wanted posters), the route discussion, and the budget meeting. With bots, they also have the Order Wheel. |
| **Crew routes around the captain** | Fine when it happens, but every encounter has at least one fact only the captain knows. |
| **Stations are too complex** | 3–5 controls plus a chore plus one spicy control. IGOR 60-second tutorials. Damage Control tasks are one-verb minigames. |
| **Bots aren't fun or are too dumb to test with** | Competent Temp is a reliable baseline. Personalities are just tuned error models on top of it. |
| **Emergent physics makes the ship unflyable** | Tunable RCS authority, per-hull stability, and director caps. Dampers ON gives arcade-like recovery. |
| **LAN or online networking pain** | WebSocket from day one, room codes, reconnect, and testing on Windows and Mac early. |
| **Scope creep** | The Phase 2 gate: nothing new until the slice gets laughs. |

## 7. Open questions

1. **Ops at launch:** five core crew plus an optional Ops station (the current plan), or six core?
2. **Human Game Master role** (like Empty Epsilon), with someone live-playing Thrupp and
   inspectors? It's cheap to add after Phase 2 using the God station.
3. **Bot captain:** the current plan has it in Phase 6. Should it come earlier, so 2–3
   people can test crew stations without anyone captaining?
4. **Voice orders for bots:** keyword grammar is cheap and reliable, while an LLM is funnier but
   adds latency and cost. The plan is a spike in Phase 3, unless you want it earlier.
