# YES, CAPTAIN — Art Direction

**One line:** *Two Point Hospital in space.* Rounded, chunky, toy-like, warm, and deadpan-silly.
The game is low-fidelity on purpose: readable at a glance on a TV across a noisy room.

**References:** Theme Hospital, Two Point Hospital and Campus (roundness, palette, PA-announcer
humour, readable UI), Overcooked (clarity under chaos), and Cosmoteer (modular ship readability).

---

## 1. Principles

1. **Round everything.** No sharp corners on UI, ships, or characters. Bevelled, pill-shaped,
   squishy. Even the explosions are puffy cartoon clouds.
2. **Toys, not machines.** Ships look like bath toys and die-cast models, with chunky proportions
   and visible bolts. Each module on the hull is visibly a separate block, so damage reads at a glance.
3. **Warm and saturated, never black.** Space is a deep plum-navy, not pure black, and
   everything sits on a friendly colour palette.
4. **Readability over detail.** Every important state (on fire, broken, powered, targeted) is
   readable from 3 metres away on the TV, through colour plus icon plus animation. Never colour alone.
5. **Squash, stretch, and wobble.** Buttons squish when pressed, gauges wobble, and the bridge-cam
   crew bounce. Things feel physical and slightly unreliable.
6. **Deadpan details.** The humour is in the props and signage: sticky notes, Hegemony
   posters, fuzzy dice, a "Days Since Last Incident: 0" sign on the bridge.

---

## 2. Palette (first pass)

| Role | Name | Hex |
|---|---|---|
| Space background | Plum Night | `#2B2350` |
| Space accent (nebula) | Dusty Lilac | `#7A6FB0` |
| **Free Lanes** primary | Tangerine | `#F28C38` |
| Free Lanes secondary | Mint | `#6CD4B0` |
| Free Lanes accent | Butter | `#F6D365` |
| Friendly / info | Sky Teal | `#3FB6C8` |
| Warning | Mustard | `#E8B23A` |
| Danger / fire | Coral Red | `#F2545B` |
| **Hegemony** primary | Gunmetal | `#4A4E5A` |
| Hegemony trim (decorative only) | Pompous Gold | `#CFA13A` |
| Hegemony banners | Regime Magenta | `#C2367A` |
| UI panel | Cream | `#FFF6E5` |
| UI ink / outlines | Ink | `#2E2A3A` |

- **The Free Lanes are warm and colourful. The Hegemony is gunmetal with gaudy gold trim and
  magenta banners.** Faction is readable from colour alone.
- **Broken states use a wobble animation plus an icon**, not only red, for colour-blind
  readability. We'll run a colour-blind check before Phase 3.

---

## 3. Shapes & models

- **Low poly with smooth shading.** Mostly 200–2,000 triangles per object. Ships are built from
  **chunky module blocks** matching the gameplay grid (GAME_LOOPS §4). An engine *looks* like a
  separate engine, so when it's on fire you know which one.
- **Free Lanes ships** have caravan and food-truck silhouettes: rounded boxes, porthole windows,
  hand-painted numbers, tape patches, and mismatched panels.
- **Hegemony ships** are pompous and gaudy: chunky gunmetal fortresses with gold trim,
  banners, and the Overlord's portrait everywhere. Big ships have his face sculpted on the prow.
  Grabber drones are round with oversized claw arms, and snatch pods have a pet carrier built in.
  The Magnificence is a giant golden bust of the Overlord's head.
- **Pudding** is the cutest model in the game: a round, fluffy, slightly glowing beanbag with
  huge eyes and tiny legs. Its Mood shows on its body: it puffs up when anxious and glows red in PANIC.
- **IGOR** has no body. He's a boxy speaker grille with a single camera eye, mounted in the
  captain's window frame and on each station's panel. The eye swivels to look at whoever he's insulting.
- **Damage states are visible on the model:** smoke puffs (rattling), sparks (faulted), cartoon
  fire (failed), and a **duct-tape patch decal** once repaired (it stays for the rest of the run).
- **Characters** (bridge cam, Pit Stop, Awards Ceremony) are Two Point-style: big heads, small
  round bodies, simple faces, and big hats.

### Godot technical notes
- **Toon-ish shading:** a simple 2–3 band ramp shader with a soft rim light, plus inverted-hull
  outlines in Ink colour on ships and props.
- **Space background:** a gradient skybox with puffy nebula sprites and big chunky planets
  (low-poly spheres with banded textures). No photoreal starfields.
- **Modelling:** Blender → glTF, plus Godot CSG for quick greybox modules in early phases.
- **Performance target:** a 5-year-old laptop's integrated GPU runs the captain view at 60 fps.

---

## 4. The captain's view (the TV screen)

This view is shown on a TV to the whole room, so it's designed as a stage set.
- **A rounded bridge-window frame** surrounds the 3D space view, with bolts, a slightly grubby glass
  edge, fuzzy dice hanging from the top, and a tiny desk plant.
- **Diegetic UI** is stuck to the window frame:
  - The **mission objective on a sticky note**, which flaps when the ship turns hard.
  - The **Overlord's Temper** as a little propaganda screen in the corner showing his face,
    getting redder at each level.
  - **IGOR's eye** in the frame, which swivels and squints at the crew.
  - A **small CRT telly** for comms (Thrupp, inspectors, Ma Gristle), with static when Sensors
    has the frequency wrong.
  - **Bridge cam:** a small inset showing the crew's bobblehead avatars at their stations.
    They tumble when the ship is hit, and their station lights up when they're busy.
  - **Shared station screens** slide in as a clipboard held up in front of the window.
- **Hull Integrity** is shown as a big chunky dial, like a car fuel gauge.
- **When the reactor scrams** the window goes dark with red emergency lighting and only the
  sticky note glows.

---

## 5. Station UIs (laptops first)

- **Target:** 1280×720 landscape minimum, scaling up to 1080p and beyond. Mouse and keyboard
  first, with keyboard shortcuts for everything. Touch works on tablets because everything is chunky.
  Phones are best-effort.
- **The look is a 70s and 80s appliance control panel** that went through the Two Point
  filter: cream panels with rounded corners and thick ink outlines, and chunky toggles, big candy
  buttons, sliding levers, and analog dials with wobbly needles.
- **Each station has its own accent colour**, matching its avatar's uniform: Helm Sky Teal,
  Engines Tangerine, Power Butter, Weapons Coral, Sensors Mint, Ops Lilac.
- **The spicy control is always behind a flip-up safety cover.** Flipping the cover is half
  the fun, and it gives others a warning half-second ("Who opened the cover?!").
- **Damage overlays on the UI:** a crack across part of the screen, a lever that pops off
  (click to stick it back), flickering readouts, and a coffee splash.
- **Fonts** (all free and open-licensed Google Fonts):
  - **Fredoka** for headings and big buttons (round and friendly).
  - **Nunito** for body text and labels.
  - **Space Mono** for numeric readouts (a slightly technical counterpoint).

---

## 6. Motion & VFX

- **Snappy and bouncy:** UI elements overshoot then settle (an elastic ease). Nothing linear.
- **Cartoon explosions:** puffy white-then-orange cloud balls with a ring pop. Laser bolts are
  fat capsules. Grabber drones leave claw scratches and gold Hegemony crest stickers on the hull.
- **Screen shake** goes on the captain's view and, gently, on station UIs when the ship is hit.
  It can be turned down in accessibility settings.
- **Ridiculous cargo is physical** when it spills: rubber ducks, cake tiers, and goats drift
  through space ragdoll-style, visible on the captain's view.

---

## 7. Audio direction (so the look has a voice)

- **Music:** jaunty lounge brass and muzak between encounters, bouncy funk-brass in combat, and
  Free Lanes pirate radio in the Pit Stop. It should never sound orchestral or epic.
- **IGOR** has a Theme Hospital PA chime ("bing-bong") before every announcement, slightly
  flat, as if installed by a robot who disapproves of chimes. He's dry, slow, and completely
  unimpressed, voiced by a human or TTS with a consistent voice. See the voice rules in STORY.md §3.
- **UI sounds** are chunky physical clicks, clunks, and springy levers. The spicy-control cover
  makes a satisfying *clack*.
- **Hegemony audio** is an out-of-tune marching band, pompous fanfares that cut off mid-note,
  and a cymbal crash on every hit.

---

## 8. What to avoid

- Gritty or realistic sci-fi: no greebles, dark metal, or lens-flare spam.
- Sharp, aggressive silhouettes, including for the enemy (they're gaudy and pompous, not daggers).
- Any lookalike of the IP we're drawing inspiration from (see STORY.md §7).
- Tiny text, low contrast, or colour-only information.
