"""Station hero props: a ship's wheel, the throttle, gauges, the periscope, radar, big buttons, lamps."""
import math
import os
from ink import SVG, Pen, P, darker, lighter, rrect, ellipse, circle, spline, path_d, INK, brush_d, wobble, resample

LAYOUT = {}


def wheel(out):
    """Ship's wheel, 400x400, centred. Spoke 0 points up and carries a red ribbon so you can see the turn."""
    W = 400
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 6, 1.0, 31)
    wood, wood2 = P("brown"), lighter("brown", 0.25)
    # handles (behind the rim)
    for i in range(8):
        a = -math.pi / 2 + i * math.tau / 8
        ca, sa = math.cos(a), math.sin(a)
        inner, outer = 120, 190
        # spoke shaft from hub to beyond the rim
        perp = (-sa, ca)
        pts = [(c + ca * 40 + perp[0] * 9, c + sa * 40 + perp[1] * 9), (c + ca * 150 + perp[0] * 9, c + sa * 150 + perp[1] * 9),
               (c + ca * 150 - perp[0] * 9, c + sa * 150 - perp[1] * 9), (c + ca * 40 - perp[0] * 9, c + sa * 40 - perp[1] * 9)]
        pen.shape(pts, wood2, w=5)
        # turned handle: a stack of bulbs
        hx, hy = c + ca * 168, c + sa * 168
        pen.shape(ellipse(hx, hy, 22, 15, 36, a), wood2, w=5, shade=(-3, -3, 0.25))
        hx2, hy2 = c + ca * 192, c + sa * 192
        pen.shape(ellipse(hx2, hy2, 12, 10, 28, a), "red" if i == 0 else wood2, w=4.5)
    # the rim: a thick wooden ring
    outer = circle(c, c, 140, 120)
    inner = circle(c, c, 112, 100)
    qo = wobble(outer, 1.0, True, 5)
    qi = wobble(inner, 1.0, True, 6)
    svg.path(path_d(qo) + " " + path_d(list(reversed(qi))), wood)
    # wood grain on the rim
    for r in (122, 131):
        svg.path(brush_d(wobble(circle(c, c, r, 100), 1.2, True, r), True, 1.6, 0.5, r), darker("brown", 0.3), 0.6)
    svg.path(brush_d(qo, True, 6, 0.3, 7), INK)
    svg.path(brush_d(qi, True, 5, 0.3, 8), INK)
    # spokes over the rim
    for i in range(8):
        a = -math.pi / 2 + i * math.tau / 8
        ca, sa = math.cos(a), math.sin(a)
        pen.line([(c + ca * 46, c + sa * 46), (c + ca * 110, c + sa * 110)], w=14, ink=wood2, wob=0.2, taper=1.0)
        pen.line([(c + ca * 46 + -sa * 8, c + sa * 46 + ca * 8), (c + ca * 112 + -sa * 8, c + sa * 112 + ca * 8)], w=3.5, taper=1.0)
        pen.line([(c + ca * 46 - -sa * 8, c + sa * 46 - ca * 8), (c + ca * 112 - -sa * 8, c + sa * 112 - ca * 8)], w=3.5, taper=1.0)
    # brass hub
    pen.shape(circle(c, c, 50), "gold", w=6, shade=(-6, -6, 0.25))
    pen.shape(circle(c, c, 22), darker("gold", 0.15), w=4.5)
    pen.shine(c - 18, c - 22, 14, 6, -0.6, 0.5)
    svg.save(os.path.join(out, "prop_wheel.svg"))


def throttle(out):
    """Brass throttle plate with a slot (200x440) and a red T-handle (220x90)."""
    W, H = 200, 440
    svg = SVG(W, H)
    pen = Pen(svg, 6, 1.0, 41)
    pen.shape(rrect(10, 10, W - 26, H - 26, 30), "gold", shadow=(6, 7, INK, 0.85), shade=(-10, -10, 0.18))
    for x, y in ((34, 34), (W - 50, 34), (34, H - 50), (W - 50, H - 50)):
        pen.shape(circle(x, y, 7), darker("gold", 0.2), w=3)
        pen.line([(x - 4, y - 4), (x + 4, y + 4)], w=2.2)
    # slot
    pen.shape(rrect(W / 2 - 22, 50, 44, H - 116, 22), INK, w=0)
    pen.shape(rrect(W / 2 - 22, 50, 44, H - 116, 22), None, w=5)
    # notches
    for i in range(11):
        y = 62 + i * (H - 140) / 10
        L = 30 if i % 5 == 0 else 16
        pen.line([(W / 2 + 32, y), (W / 2 + 32 + L, y)], w=4 if i % 5 == 0 else 3)
        pen.line([(W / 2 - 32, y), (W / 2 - 32 - L, y)], w=4 if i % 5 == 0 else 3)
    svg.save(os.path.join(out, "prop_throttle.svg"))
    LAYOUT["throttle"] = {"slot_top": 62, "slot_bottom": H - 78, "w": W, "h": H}
    # handle
    W2, H2 = 220, 90
    svg = SVG(W2, H2)
    pen = Pen(svg, 5.5, 0.8, 43)
    pen.shape(rrect(84, 12, 52, 62, 12), "steel", w=5, shade=(-4, -4, 0.2))
    pen.shape(rrect(8, 22, W2 - 22, 42, 21), "red", shadow=(0, 5, INK, 0.85), shade=(-4, -5, 0.2))
    pen.shine(46, 32, 22, 4, 0.0, 0.5)
    svg.save(os.path.join(out, "prop_throttle_handle.svg"))


def gauge(out):
    """A round brass gauge, 300x300. The arc runs from 225 deg (min) to -45 deg (max), clockwise via the top."""
    W = 300
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 6, 0.8, 51)
    pen.shape(circle(c, c, 138), "gold", w=6, shade=(-8, -8, 0.22), shadow=(5, 6, INK, 0.85))
    pen.shape(circle(c, c, 112), "cream", w=5)
    # zones: green, yellow, red along the arc
    a0, a1 = math.radians(135), math.radians(405)

    def arc(r0, r1, f0, f1, col):
        aa, bb = a0 + (a1 - a0) * f0, a0 + (a1 - a0) * f1
        o = [(c + r1 * math.cos(aa + (bb - aa) * k / 30), c + r1 * math.sin(aa + (bb - aa) * k / 30)) for k in range(31)]
        i = [(c + r0 * math.cos(bb - (bb - aa) * k / 30), c + r0 * math.sin(bb - (bb - aa) * k / 30)) for k in range(31)]
        svg.path(path_d(o + i), P(col))

    arc(84, 100, 0.0, 0.6, "green")
    arc(84, 100, 0.6, 0.8, "mustard")
    arc(84, 100, 0.8, 1.0, "red")
    for k in range(21):
        a = a0 + (a1 - a0) * k / 20
        L = 22 if k % 5 == 0 else 12
        pen.line([(c + 104 * math.cos(a), c + 104 * math.sin(a)), (c + (104 - L) * math.cos(a), c + (104 - L) * math.sin(a))],
                 w=4.5 if k % 5 == 0 else 3, taper=1.0, wob=0.2)
    svg.save(os.path.join(out, "prop_gauge.svg"))
    LAYOUT["gauge"] = {"a0": 135, "a1": 405, "r": 112}
    # needle (pivot at 20,120 of a 40x140 sprite, pointing up)
    svg = SVG(40, 140)
    pen = Pen(svg, 3.5, 0.3, 53)
    pen.shape([(20, 8), (28, 112), (20, 126), (12, 112)], "red", w=3.5)
    pen.shape(circle(20, 120, 13), INK, w=0)
    pen.shape(circle(20, 120, 6), "gold", w=2)
    svg.save(os.path.join(out, "prop_needle.svg"))


def bezel(out, name, ring_col, inner_r, ticks=0, screws=6):
    """A round frame with a transparent middle: periscope, radar, dials. 500x500."""
    W = 500
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 7, 1.0, len(name) * 13)
    outer = wobble(circle(c, c, 236, 140), 1.0, True, 3)
    inner = wobble(circle(c, c, inner_r, 140), 0.8, True, 4)
    svg.path(path_d([(x + 6, y + 8) for x, y in outer]) + " " + path_d(list(reversed(inner))), INK, 0.85)
    svg.path(path_d(outer) + " " + path_d(list(reversed(inner))), P(ring_col))
    # shading crescent on the ring
    svg.clip_begin(outer)
    svg.path(path_d([(x + 10, y + 12) for x, y in circle(c, c, 236, 100)]) + " " + path_d(list(reversed(circle(c - 6, c - 6, 236, 100)))),
             darker(ring_col, 0.2), 0.0)
    svg.clip_end()
    svg.path(brush_d(outer, True, 7, 0.3, 11), INK)
    svg.path(brush_d(inner, True, 7, 0.3, 12), INK)
    for k in range(screws):
        a = -math.pi / 2 + k * math.tau / screws + math.pi / screws
        x, y = c + (inner_r + 236) / 2 * math.cos(a), c + (inner_r + 236) / 2 * math.sin(a)
        pen.shape(circle(x, y, 9), darker(ring_col, 0.15), w=3.5)
        pen.line([(x - 5, y - 5), (x + 5, y + 5)], w=2.5)
    for k in range(ticks):
        a = -math.pi / 2 + k * math.tau / ticks
        L = 14 if k % (ticks // 4) == 0 else 7
        pen.line([(c + (inner_r + 4) * math.cos(a), c + (inner_r + 4) * math.sin(a)),
                  (c + (inner_r + 4 + L) * math.cos(a), c + (inner_r + 4 + L) * math.sin(a))], w=4, taper=1.0, wob=0.1)
    pen.shine(c - 140, c - 150, 50, 14, -0.75, 0.35)
    svg.save(os.path.join(out, name + ".svg"))
    LAYOUT[name] = {"inner": inner_r}


def bigbutton(out, name, col):
    """A big round arcade button in a brass collar, 240x240, plus a pressed version."""
    for down in (False, True):
        W = 240
        c = W / 2
        svg = SVG(W, W)
        pen = Pen(svg, 6.5, 1.0, len(name) * 7 + down)
        pen.shape(circle(c, c + 6, 108), "gold", shadow=(4, 8, INK, 0.85), shade=(-8, -8, 0.22))
        pen.shape(circle(c, c + 6, 86), darker("gold", 0.35), w=5)
        dy = 10 if down else 0
        if not down:
            pen.shape(ellipse(c, c + 12, 78, 74, 64), darker(col, 0.35), w=5)
        pen.shape(ellipse(c, c - 4 + dy, 78, 72, 64), P(col), w=6, shade=(-6, -8, 0.18))
        pen.shine(c - 30, c - 34 + dy, 26, 10, -0.5, 0.55)
        svg.save(os.path.join(out, "%s%s.svg" % (name, "_down" if down else "")))


def lamp(out):
    for col in ("green", "red", "mustard", "off"):
        svg = SVG(64, 64)
        pen = Pen(svg, 4, 0.5, 61)
        pen.shape(circle(32, 32, 27), "steel", w=4)
        f = "#5a5248" if col == "off" else P(col)
        if col != "off":
            svg.path(path_d(circle(32, 32, 30)), lighter(col, 0.4), 0.35)
        pen.shape(circle(32, 32, 18), f, w=3.5)
        pen.shine(26, 25, 6, 3.5, -0.6, 0.7 if col != "off" else 0.25)
        svg.save(os.path.join(out, "lamp_%s.svg" % col))


def thermometer(out):
    """Glass tube + bulb (90x320). The middle is see-through so the engine can draw the mercury behind it."""
    W, H = 90, 320
    svg = SVG(W, H)
    pen = Pen(svg, 5, 0.7, 71)
    tube = rrect(30, 10, 30, 250, 15)
    bulb = circle(45, 272, 30)
    pen.shape(rrect(30, 10, 30, 250, 15), None, w=5)
    pen.shape(bulb, None, w=5.5)
    for k in range(9):
        y = 30 + k * 26
        pen.line([(62, y), (74 if k % 2 == 0 else 69, y)], w=3.5, taper=1.0, wob=0.1)
    pen.shine(38, 120, 3, 60, 0.0, 0.45)
    svg.save(os.path.join(out, "prop_thermo.svg"))
    LAYOUT["thermo"] = {"tube": [30, 10, 30, 250], "bulb": [45, 272, 30]}


def knob(out):
    """A brass knob with grip ridges and a pointer, 160x160 (pointer up)."""
    W = 160
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 5.5, 0.6, 81)
    ridges = []
    for k in range(48):
        a = k * math.tau / 48
        r = 70 if k % 2 == 0 else 64
        ridges.append((c + r * math.cos(a), c + r * math.sin(a)))
    pen.shape(ridges, "gold", wob=0.3, shadow=(4, 6, INK, 0.85), shade=(-6, -6, 0.22))
    pen.shape(circle(c, c, 46), lighter("gold", 0.15), w=4.5)
    pen.shape([(c - 8, 12), (c + 8, 12), (c + 6, 50), (c - 6, 50)], "red", w=3.5)
    pen.shine(c - 22, c - 24, 16, 6, -0.6, 0.5)
    svg.save(os.path.join(out, "prop_knob.svg"))


def build(out):
    wheel(out)
    throttle(out)
    gauge(out)
    bezel(out, "prop_scope", "steel", 196, 0, 8)
    bezel(out, "prop_radar", "olive", 200, 36, 6)
    bezel(out, "prop_dial", "gold", 200, 24, 4)
    for n, col in (("bigbtn_red", "red"), ("bigbtn_green", "green"), ("bigbtn_blue", "blue"), ("bigbtn_mustard", "mustard"),
                   ("bigbtn_purple", "purple")):
        bigbutton(out, n, col)
    lamp(out)
    thermometer(out)
    knob(out)
    return {"props": LAYOUT}
