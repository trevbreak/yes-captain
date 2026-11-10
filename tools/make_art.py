#!/usr/bin/env python3
"""Generates every piece of art in assets/art (SVG) for the hand-inked cartoon look.

    python3 tools/make_art.py

chars.py   crew and cast portraits
uikit.py   9-sliced panels, buttons, ribbons, chips, bars (+ slices.json)
props.py   station hero props: ship's wheel, throttle, gauges, scope, radar, big buttons, lamps
things.py  our ship, the ship cutaway (+ rooms.json), enemies and objects, effects
icons.py   white silhouette icons (tinted in-engine)
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import chars  # noqa: E402
import uikit  # noqa: E402

OUT = os.path.join(HERE, "..", "assets", "art")
# what gets line boil (everything that is a character or a thing; not the 9-sliced UI frames or the icons)
BOILED = ("portrait_", "prop_wheel", "prop_throttle", "prop_scope", "prop_radar", "prop_dial", "prop_gauge", "prop_knob", "ship_ours",
          "obj_", "bigbtn_", "doodad_")
BUTTON_COLOURS = ["red", "orange", "mustard", "green", "teal", "blue", "navy", "purple", "pink", "cream", "paper2", "steel", "ink", "lilac"]


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in glob.glob(os.path.join(OUT, "*.svg")) + glob.glob(os.path.join(OUT, "*.svg.import")):
        os.remove(f)
    chars.build(OUT)
    slices = uikit.build(OUT, BUTTON_COLOURS)
    extra = {}
    for mod in ("props", "things", "icons"):
        try:
            m = __import__(mod)
        except ImportError:
            continue
        r = m.build(OUT)
        if isinstance(r, dict):
            extra.update(r)
    with open(os.path.join(OUT, "slices.json"), "w") as f:
        json.dump(slices, f, indent=1)
    if extra:
        with open(os.path.join(OUT, "layout.json"), "w") as f:
            json.dump(extra, f, indent=1)
    # line boil: draw the characters, props and objects twice more with a slightly different hand; the game
    # cycles the three versions so the ink shimmers like a hand-drawn cartoon (see Art.live)
    import shutil
    import tempfile
    import ink
    for frame in (1, 2):
        ink.BOIL = frame
        tmp = tempfile.mkdtemp()
        chars.build(tmp)
        for mod in ("props", "things"):
            __import__(mod).build(tmp)
        for f in glob.glob(os.path.join(tmp, "*.svg")):
            base = os.path.basename(f)[:-4]
            if base.startswith(BOILED):
                shutil.copy(f, os.path.join(OUT, "%s.b%d.svg" % (base, frame)))
        shutil.rmtree(tmp)
    ink.BOIL = 0
    # the game rasterizes the raw SVGs itself (ui/art.gd), so tell Godot to export them untouched
    for f in glob.glob(os.path.join(OUT, "*.svg")):
        with open(f + ".import", "w") as imp:
            imp.write('[remap]\n\nimporter="keep"\n')
    print("art:", len(glob.glob(os.path.join(OUT, "*.svg"))), "svgs")


if __name__ == "__main__":
    main()
