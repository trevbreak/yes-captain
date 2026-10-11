"""Hand-inked UI pieces, drawn so they can be 9-sliced in-engine (UIK.InkBox).

Every piece is drawn at 1x in SVG units. The engine rasterizes at 2x for crispness and slices with the margins in
SLICES (also 1x units), which make_art writes to assets/art/slices.json.
"""
import os
from ink import SVG, Pen, P, darker, lighter, rrect, ellipse, circle, path_d, INK, brush_d, wobble, spline

SLICES = {}
SHADOW = 0.85


def _save(svg, out, name, margins, content=None):
    svg.save(os.path.join(out, name + ".svg"))
    SLICES[name] = {"m": margins, "c": content or margins}


def panel(out, name, fill, seed=3, r=22, shadow=(5, 6), ink_w=5.5):
    """A paper card. 160x160 with the card inset so the hard shadow fits."""
    W = 160
    svg = SVG(W, W)
    pen = Pen(svg, ink_w, 1.0, seed)
    q = rrect(8, 8, W - 22, W - 22, r)
    pen.shape(q, P(fill), shadow=(shadow[0], shadow[1], INK, SHADOW) if shadow else None)
    # a few paper fibres so big cards don't look flat
    _save(svg, out, name, [44, 44, 50, 50], [20, 16, 24, 22])


def well(out, name="well", fill="paper2", seed=5):
    W = 120
    svg = SVG(W, W)
    pen = Pen(svg, 4.0, 0.8, seed)
    q = pen.shape(rrect(6, 6, W - 12, W - 12, 16), P(fill))
    # inner shadow along the top edge
    svg.clip_begin(q)
    svg.path(path_d(rrect(6, 6, W - 12, 14, 8)), darker(fill, 0.25), 0.35)
    svg.clip_end()
    pen.shape(rrect(6, 6, W - 12, W - 12, 16), None, w=4.0)
    _save(svg, out, name, [30, 30, 30, 30], [16, 14, 16, 14])


def button(out, name, fill, state="normal", seed=7):
    """Chunky cartoon button: colour body, darker lip, white shine, hard shadow. 140x84."""
    W, H = 140, 84
    svg = SVG(W, H)
    pen = Pen(svg, 4.8, 0.9, seed)
    f = P(fill)
    if state == "hover":
        f = lighter(f, 0.15)
    if state == "disabled":
        f = "#c9bfae"
    dy = 5 if state == "pressed" else 0
    sh = None if state == "pressed" else (0, 6, INK, SHADOW)
    q = rrect(6, 6 + dy, W - 12, H - 20, 20)
    qq = pen.shape(q, f, w=0, shadow=sh)
    svg.clip_begin(qq)
    svg.path(path_d(rrect(0, H - 30 + dy, W, 30, 0)), darker(f, 0.2))
    svg.path(path_d(ellipse(40, 20 + dy, 24, 5, 24, -0.08)), "#ffffff", 0.45 if state != "disabled" else 0.2)
    svg.path(path_d(ellipse(70, 19 + dy, 4, 4, 12)), "#ffffff", 0.45 if state != "disabled" else 0.2)
    svg.clip_end()
    pen.shape(q, None, w=4.8)
    _save(svg, out, name, [30, 30, 30, 34], [18, 12, 18, 16 if state != "pressed" else 11])


def ribbon(out, name, fill, seed=11):
    """A title banner with folded tails. 220x64 (stretches horizontally)."""
    W, H = 220, 74
    svg = SVG(W, H)
    pen = Pen(svg, 4.5, 0.9, seed)
    f = P(fill)
    # tails
    for s in (0, 1):
        x0 = 4 if s == 0 else W - 4
        sgn = 1 if s == 0 else -1
        pts = [(x0, 20), (x0 + sgn * 34, 20), (x0 + sgn * 34, 66), (x0, 66), (x0 + sgn * 12, 43)]
        pen.shape(pts, darker(f, 0.25), w=4)
    body = rrect(20, 6, W - 40, 52, 6)
    pen.shape(body, f, shadow=(0, 5, INK, SHADOW))
    svg.path(path_d(rrect(28, 11, W - 56, 5, 2)), "#ffffff", 0.3)
    _save(svg, out, name, [46, 22, 46, 24], [40, 10, 40, 17])


def chip(out, name, fill, seed=13):
    W, H = 80, 40
    svg = SVG(W, H)
    pen = Pen(svg, 3.5, 0.6, seed)
    pen.shape(rrect(3, 3, W - 6, H - 8, 16), P(fill), shadow=(0, 3, INK, SHADOW))
    _save(svg, out, name, [20, 16, 20, 18], [12, 4, 12, 7])


def bar(out, seed=17):
    """Progress bar track + fill (fill is tinted in-engine, so it is white)."""
    W, H = 100, 36
    svg = SVG(W, H)
    pen = Pen(svg, 4.0, 0.6, seed)
    pen.shape(rrect(3, 3, W - 6, H - 8, 13), P("paper2"), shadow=(0, 3, INK, SHADOW))
    _save(svg, out, "bar_track", [18, 14, 18, 16], [6, 6, 6, 8])
    svg = SVG(W, H)
    pen = Pen(svg, 0, 0.6, seed + 1)
    q = pen.shape(rrect(3, 3, W - 6, H - 8, 13), "#ffffff", w=0)
    svg.clip_begin(q)
    svg.path(path_d(rrect(0, 20, W, 20, 0)), "#000000", 0.18)
    svg.path(path_d(rrect(12, 7, W - 24, 4, 2)), "#ffffff", 0.6)
    svg.clip_end()
    _save(svg, out, "bar_fill", [16, 12, 16, 14], [0, 0, 0, 0])


def tab(out, name, fill, seed=19):
    """A file-folder tab for station headers (attached to the top of a panel)."""
    W, H = 160, 56
    svg = SVG(W, H)
    pen = Pen(svg, 4.5, 0.8, seed)
    pts = spline([(6, H + 6), (10, 18), (24, 6), (W - 24, 6), (W - 10, 18), (W - 6, H + 6)], False, 8)
    pen.shape(pts + [(W - 6, H + 6), (6, H + 6)], P(fill))
    _save(svg, out, name, [30, 24, 30, 10], [22, 8, 22, 4])


def build(out, palette_buttons):
    os.makedirs(out, exist_ok=True)
    panel(out, "panel", "cream")
    panel(out, "panel_paper", "paper", seed=4)
    panel(out, "panel_dark", "night2", seed=6)
    panel(out, "panel_small", "cream", seed=8, r=16, shadow=(3, 4), ink_w=4.5)
    well(out)
    well(out, "well_dark", "night", 9)
    for col in palette_buttons:
        for st in ("normal", "hover", "pressed", "disabled"):
            button(out, "btn_%s_%s" % (col, st), col, st, seed=7 + len(col))
        ribbon(out, "ribbon_%s" % col, col, seed=11 + len(col))
        chip(out, "chip_%s" % col, col, seed=13 + len(col))
    bar(out)
    return SLICES
