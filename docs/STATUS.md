# Implementation status

What exists in the Godot project versus the original plan (`GAME_PLAN.md`, `GAME_LOOPS.md`).

## Built and tested

| Plan item | Status |
|---|---|
| Godot 4 project, GDScript, LAN play, WebSocket netcode, online-ready (direct IP) | Done. Host and clients over WebSocket, dedicated headless host, reconnect-to-seat |
| 2D sim rendered in 3D, captain viewscreen, toon shaders, chunky models | Done |
| Roles: Captain, Helm, Engines, Power, Weapons, Sensors & Comms, Ops, Damage Control | Done, each with a chore and a spicy control |
| Captain can't touch anything; Sensors points the viewscreen; Share to Captain | Done |
| Info asymmetry enforced server-side (filtered per-station snapshots) | Done and tested |
| Cosmoteer-style module grid, thrusters with real torque, fires, breaches-as-thrust, conduits, hidden faults | Done |
| Everything repairable; find-then-fix; Damage Control; zap/isolate handoff; quick fixes at your post | Done and tested |
| Chaos Director (telegraphs, max 3 critical, graceful degradation) | Done |
| Pudding (mood, escapes, eats wiring, snacks/pats/music) | Done |
| Story: Hegemony, Overlord's Temper, Admiral Thrupp's demotions (persisted), IGOR, Free Lanes | Done |
| The Run: sector map, jump ritual, misjumps, fuel, pit stop budget meeting, hull persistence, 4 endings | Done |
| 15 encounter types incl. Customs, odd jobs (cake/ducks/bees), mines, bastion with weak spot, docking, finales | Done, all beaten by bots in the soak tests |
| Black Box: event ticker, blame, replay, awards, Hegemony victory broadcast on failure | Done |
| AI crew with personalities, hot-swap in both directions, Order Wheel, AI captain | Done |
| Party modifiers: Glass Ship, Dampers Broken, Pudding Mode, EMP, Crew Rotation, Jargon | Done |
| Two-Point-style UI kit, IGOR's PA subtitles + TTS, procedural sound | Done |
| Headless test suite incl. networking and UI smoke tests | Done (`scripts/run_tests.sh`) |

## Not built (deliberately deferred)

* **Crew vs Crew PvP** (two ships in one arena) and **The Mole** social-deduction mode. The world holds a single ship,
  so this needs a multi-ship refactor.
* **Online relay / lobby server.** Online play works by direct IP (port-forward or VPN), with no matchmaking or NAT punching.
* **Voice orders** (keyword grammar or LLM interpreter). The Order Wheel and text cards cover that need for now.
* Extra hulls (ice-cream van, hearse...), hats and avatar customization, and web export of station clients for tablets.
* Real audio assets and music (sound is synthesized; IGOR speaks through the OS text-to-speech).
* Tuning with real people. All balance numbers were set by simulation with AI crews. Expect to retune with humans
  (the playtest targets in `GAME_LOOPS.md` section 13 are the thing to measure).
