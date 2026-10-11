# YES, CAPTAIN! v2 — Simple first, deeper every mission

This replaces the v1 mechanics list. v1 had about forty controls across eight screens, all switched on from the
first minute. v2 starts every player with **one control**, and each mission adds **one** new dynamic, introduced by
IGOR in the briefing.

## 1. The core idea

* **The Captain sees the whole picture and touches nothing.** They see the mission goals, a map of the area, a
  board showing every ship system, and what every crew member is doing right now. Their only tool is their voice.
* **The crew each see one thing in depth.** Helm only sees a compass. Weapons only sees down the gun barrel.
  Engines sees the throttle and the heat, but not where the ship is going.
* The game is the gap between the two. The captain spots "Engines at full throttle, the reactor will overload in
  6 seconds" and shouts it. Engines can't see the reactor; the Engineer can't see the throttle.

## 2. Seats

| Seat | Persona | Hero control (mission 1) | Added later |
|---|---|---|---|
| Captain | Captain Mo Pennywhistle (walrus) | none: voice only | |
| Helm | Dex Wheelwright (duck) | Ship's wheel (stays where you leave it) | Barrel roll (M7) |
| Engines | Big Sal Throttleby (bulldog) | Throttle lever (stays where you leave it) | Heat (M3), Boost (M7) |
| Weapons | Rhoda "Boom" Blastworth (cat) | Turret aim + FIRE | Heat (M3), Torpedoes (M6) |
| Sensors | Ozzy Squint (owl) | Radar: click a blip, hold SCAN | Comms dial (M5), weak spots (M6) |
| Shields | Nana Fluffington (turtle) | Shield dial: point it at the danger | Tractor beam (M2), Pudding (M4) |
| Engineer | Gus Spanner (raccoon) | Ship cutaway: click a broken part, hold REPAIR | Power routing + overload (M8) |

Players can hold several seats and switch with 1-7. Robots fill empty seats.

## 3. The career: one new thing per mission

| # | Mission | New dynamic | What it teaches |
|---|---|---|---|
| 1 | Driving Lesson | (the basics) | Fly through rings, scan buoys, shoot the targets, block practice junk, fix what IGOR loosens |
| 2 | Bin Day | **Tractor beam** (Shields) | Haul a skip aboard. Inside the skip: Pudding, the Overlord's pet |
| 3 | Running Hot | **Heat** (Engines, Weapons) | Full throttle or non-stop firing overheats the part and breaks it |
| 4 | Pet Sitting | **Pudding's mood** (Shields) | Loud things upset Pudding. Upset Pudding escapes and chews things |
| 5 | Customs | **Comms dial** (Sensors) | Tune in the hail to hear the passcode; the captain reads it back |
| 6 | The Big One | **Torpedoes + weak spots** (Weapons, Sensors) | Deep-scan the cruiser to find its weak spot, line up, torpedo it |
| 7 | Hot Pursuit | **Boost + barrel roll** (Engines, Helm) | Outrun a patrol: boost (hot!) and roll to dodge |
| 8 | Brownout | **Power routing + overload** (Engineer) | The reactor can't feed everything at full. Engines at full throttle while the guns fire trips the breaker |
| 9 | Grabbers | **Grabber drones** (everyone) | Drones latch on; spin hard to shake them, shield them off, shoot them |
| 10 | Run to Haven | (everything) | The finale |

Each mission is replayable from the Crew Room once unlocked. Progress is saved.

## 4. What the captain sees (the Captain's Table)

1. **The chart:** a top-down paper chart of the area. It shows our ship, the goal markers, contacts (a "?" until
   Sensors scans them, then a labelled drawing), incoming shots, and the arc our shield is facing.
2. **Goals:** the mission steps, with the current one highlighted.
3. **The ship board:** a cutaway of the ship with a stamp on each system: OK, HOT, BROKEN, ON FIRE, NO POWER, plus hull,
   speed and reactor load.
4. **The crew board:** each crew member's face plus a live line ("Throttle 100%", "Turning hard left",
   "Gun at 92° and HOT") and a warning bubble when their area is in trouble.
5. **Forecasts:** "Reactor overload in 6s", "Port engine will overheat in 4s". These are the captain's cues.

The captain has no buttons apart from the menu.

## 5. What each station sees (deliberately narrow)

* **Helm:** compass and heading only. No map. "Turn to 090!"
* **Engines:** speed, throttle, engine heat, the two engines' status. Doesn't know where we're going.
* **Weapons:** the view down the turret (a narrow cone), aim angle, gun heat. Needs to be told where to look.
* **Sensors:** a radar with blips; scanning reveals what a blip is (that goes to the captain's chart too).
* **Shields:** our ship with the shield arc around it, and hit flashes. Needs to be told where the danger is.
* **Engineer:** the cutaway with the exact damage, and later the reactor and power routing.

## 6. Cut from v1

Trim, fuel mixture, two throttles, strafe, dampers, coolant pump, vent, conduits/zap/isolate, hidden faults,
jump ritual and capacitor, sector map roguelite, pit stop shop, forms, wishlist, share-to-captain, order wheel,
viewscreen direction, decoys, active ping, internal scan, two turrets, stow/track, cargo securing, repair bot,
jettison, party modifiers (glass ship, EMP, jargon, crew rotation), the 3D window.

## 7. Look: a hand-inked 1930s cartoon

* Paper and ink: cream paper, thick hand-drawn black ink outlines with varying width, flat vintage colours, film
  grain and a vignette over everything.
* Characters are rubber-hose cartoon animals with pie-cut eyes.
* Fewer, bigger controls: every station has a hero prop (a ship's wheel, a brass throttle, a periscope) and very
  little else.
* All art is generated as SVG by `tools/make_art.py` and rasterized in-engine. There is no 3D.
* Type: Luckiest Guy (headings, Apache 2.0) and Patrick Hand (body, OFL).

## 8. Briefings

Before every mission IGOR talks the crew through it, voiced with text-to-speech and subtitled. There are three short
pages: what's happening, the plan (numbered steps), and **"NEW TODAY"**, which shows the one new dynamic and whose
station it is on. Then everyone readies up.
