"""World objects, drawn top-down with the nose pointing UP (the engine rotates them).

Also the ship cutaway used by the Engineer and the captain's ship board; its room rectangles go to layout.json.
"""
import math
import os
from ink import SVG, Pen, P, darker, lighter, rrect, ellipse, circle, spline, path_d, INK, brush_d, wobble

LAYOUT = {}
SH = (-6, -7, 0.2)


def save(svg, out, name):
    svg.save(os.path.join(out, name + ".svg"))


def eye_pair(pen, cx, cy, dx, r, look=(0.0, -0.4), lid=0.0):
    pen.pie_eye(cx - dx, cy, r * 0.8, r, look=look, lid=lid)
    pen.pie_eye(cx + dx, cy, r * 0.8, r, look=look, lid=lid)


def our_ship(out):
    """The Second Opinion: a garbage hauler with ideas above its station. 200x260."""
    W, H = 200, 260
    svg = SVG(W, H)
    pen = Pen(svg, 5.5, 1.0, 101)
    # engine pods at the back
    for s in (-1, 1):
        x = W / 2 + s * 62
        pen.shape(rrect(x - 20, 168, 40, 70, 16), "steel", w=5, shade=(-4, -4, 0.2))
        pen.shape(ellipse(x, 240, 16, 8, 24), INK, w=0)
    # hull
    body = [(W / 2 - 66, 222), (W / 2 - 74, 120), (W / 2 - 56, 46), (W / 2, 14), (W / 2 + 56, 46), (W / 2 + 74, 120), (W / 2 + 66, 222),
            (W / 2, 236)]
    pen.blob(body, "orange", w=6, shade=SH, shadow=None)
    # stripe
    pen.blob([(W / 2 - 70, 150), (W / 2, 140), (W / 2 + 70, 150), (W / 2 + 68, 168), (W / 2, 158), (W / 2 - 68, 168)], "mustard", w=4)
    # cab with windscreen
    pen.blob([(W / 2 - 34, 70), (W / 2, 44), (W / 2 + 34, 70), (W / 2 + 30, 96), (W / 2 - 30, 96)], "sky", w=4.5, shade=(-3, -3, 0.2))
    pen.shine(W / 2 - 12, 62, 10, 4, -0.5, 0.6)
    # bin lid hatch
    pen.shape(rrect(W / 2 - 36, 176, 72, 40, 8), "green", w=4.5, shade=(-3, -3, 0.2))
    pen.line([(W / 2 - 30, 196), (W / 2 + 30, 196)], w=3)
    # rivets
    for x, y in ((W / 2 - 52, 110), (W / 2 + 52, 110), (W / 2 - 56, 200), (W / 2 + 56, 200)):
        pen.dot(x, y, 3)
    save(svg, out, "ship_ours")
    # the turret is a separate sprite so it can swivel (pivot at 30,60 of 60x100)
    svg = SVG(60, 100)
    pen = Pen(svg, 4.5, 0.4, 103)
    pen.shape(rrect(24, 4, 12, 56, 5), "steel", w=4)
    pen.shape(circle(30, 64, 24), "red", w=5, shade=(-3, -3, 0.2))
    pen.shine(22, 56, 6, 3, -0.6, 0.5)
    save(svg, out, "ship_turret")
    LAYOUT["ship_ours"] = {"w": W, "h": H, "turret": [W / 2, 128], "turret_pivot": [30, 64]}


def cutaway(out):
    """Top-down cutaway of the ship for the Engineer and the captain's ship board. 720x420, nose to the RIGHT."""
    W, H = 720, 420
    svg = SVG(W, H)
    pen = Pen(svg, 7, 1.2, 111)
    hull = [(40, 140), (90, 60), (300, 40), (560, 60), (680, 150), (700, 210), (680, 270), (560, 360), (300, 380), (90, 360), (40, 280)]
    pen.blob(hull, "orange", w=8, shadow=(7, 9, INK, 0.85), shade=(-10, -12, 0.15))
    # rooms: id -> rect (x, y, w, h), floor colour
    rooms = {
        "engine_p": ([70, 90, 120, 90], "steel"),
        "engine_s": ([70, 240, 120, 90], "steel"),
        "reactor": ([200, 160, 130, 100], "mustard"),
        "pen": ([200, 70, 130, 80], "pink"),
        "tractor": ([200, 270, 130, 80], "lilac"),
        "gun": ([340, 70, 120, 90], "red"),
        "shield": ([340, 260, 120, 90], "purple"),
        "sensors": ([340, 170, 120, 80], "green"),
        "bridge": ([470, 140, 140, 140], "blue"),
    }
    for rid, (r, col) in rooms.items():
        x, y, w, h = r
        q = pen.shape(rrect(x, y, w, h, 14), lighter(col, 0.45), w=5)
        # floor tiles
        svg.clip_begin(q)
        for gx in range(int(x), int(x + w), 22):
            svg.path(brush_d([(gx, y), (gx, y + h)], False, 1.4, 0.2, gx), darker(col, 0.15), 0.35)
        for gy in range(int(y), int(y + h), 22):
            svg.path(brush_d([(x, gy), (x + w, gy)], False, 1.4, 0.2, gy), darker(col, 0.15), 0.35)
        svg.clip_end()
    # corridors (doors) as little gaps drawn as cream bars
    for (x, y, w, h) in ((190, 120, 12, 24), (190, 276, 12, 24), (330, 200, 12, 24), (460, 200, 12, 24), (262, 150, 24, 12),
                         (262, 258, 24, 12), (390, 160, 24, 12), (390, 248, 24, 12)):
        svg.path(path_d(rrect(x, y, w, h, 3)), P("cream"))
    # nozzles at the back
    for y in (135, 285):
        pen.shape(rrect(14, y - 22, 40, 44, 10), "steel", w=5)
    save(svg, out, "ship_cutaway")
    LAYOUT["cutaway"] = {"w": W, "h": H, "rooms": {k: v[0] for k, v in rooms.items()}}


def ring(out):
    """A life-ring waypoint (red and white), 160x160."""
    W = 160
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 6, 1.0, 121)
    pen.shape(circle(c, c, 70), "white", w=0)
    for k in range(4):
        a0 = k * math.tau / 4 + math.tau / 16
        pts = [(c + 70 * math.cos(a0 + (math.tau / 8) * t / 10), c + 70 * math.sin(a0 + (math.tau / 8) * t / 10)) for t in range(11)]
        pts += [(c + 40 * math.cos(a0 + (math.tau / 8) * (10 - t) / 10), c + 40 * math.sin(a0 + (math.tau / 8) * (10 - t) / 10)) for t in range(11)]
        svg.path(path_d(pts), P("red"))
    svg.path(brush_d(wobble(circle(c, c, 70, 90), 1, True, 3), True, 6, 0.3, 4), INK)
    svg.path(brush_d(wobble(circle(c, c, 40, 70), 1, True, 5), True, 5, 0.3, 6), INK)
    pen.shine(c - 34, c - 44, 12, 4, -0.7, 0.6)
    save(svg, out, "obj_ring")


def buoy(out):
    W = 120
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 5, 1, 131)
    pen.shape(circle(c, c, 44), "mustard", w=5.5, shade=SH)
    pen.blob([(c - 44, c - 6), (c, c - 14), (c + 44, c - 6), (c + 44, c + 10), (c, c + 2), (c - 44, c + 10)], "white", w=4)
    pen.shape(circle(c, c - 30, 12), "red", w=4)
    pen.shine(c - 4, c - 34, 4, 2.5)
    eye_pair(pen, c, c + 18, 12, 8, (0.0, 0.0))
    save(svg, out, "obj_buoy")


def target(out):
    """Practice target balloon: a bullseye with a grumpy face, 130x130."""
    W = 130
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 5, 1, 141)
    for r, col in ((58, "red"), (44, "white"), (30, "red"), (16, "white")):
        pen.shape(circle(c, c, r), col, w=4.5 if r == 58 else 3)
    pen.line([(c - 18, c - 12), (c - 6, c - 8)], w=3.5)
    pen.line([(c + 6, c - 8), (c + 18, c - 12)], w=3.5)
    save(svg, out, "obj_target")


def junk(out):
    """Practice junk: a dented tin can, 90x90."""
    svg = SVG(90, 90)
    pen = Pen(svg, 4.5, 1.2, 151)
    pen.blob([(20, 24), (45, 14), (70, 24), (72, 66), (45, 78), (18, 66)], "grey2", w=5, shade=SH)
    pen.shape(ellipse(45, 22, 25, 9, 32), lighter("grey2", 0.3), w=4)
    pen.line([(24, 44), (42, 50), (66, 42)], w=2.5)
    pen.blob([(26, 52), (45, 48), (64, 52), (62, 62), (28, 62)], "red", w=3)
    save(svg, out, "obj_junk")


def skip(out):
    """The skip (a dumpster) with Pudding peeking out. 220x160, top-down-ish."""
    W, H = 220, 160
    svg = SVG(W, H)
    pen = Pen(svg, 6, 1, 161)
    pen.blob([(20, 40), (110, 30), (200, 40), (190, 140), (110, 148), (30, 140)], "green", w=6, shade=SH)
    pen.blob([(30, 46), (110, 38), (190, 46), (186, 64), (110, 58), (34, 64)], darker("green", 0.2), w=4)
    for x in (70, 150):
        pen.line([(x, 70), (x, 132)], w=4)
    for x, y in ((20, 80), (200, 80)):
        pen.shape(rrect(x - 8, y - 14, 16, 28, 6), "steel", w=4)
    # pudding peeking from under the lid
    pen.blob([(84, 44), (110, 20), (138, 44), (110, 52)], "pink", w=4)
    pen.dot(102, 38, 3)
    pen.dot(118, 38, 3)
    save(svg, out, "obj_skip")


def pudding_small(out):
    svg = SVG(90, 80)
    pen = Pen(svg, 4.5, 1, 171)
    pts = [(45 + (36 + (5 if i % 2 else 0)) * math.cos(i * math.tau / 12), 44 + (30 + (4 if i % 2 else 0)) * math.sin(i * math.tau / 12))
           for i in range(12)]
    pen.blob(pts, "pink", w=4.5, shade=(-5, -5, 0.15))
    pen.pie_eye(36, 40, 6, 8)
    pen.pie_eye(54, 40, 6, 8)
    pen.line([(40, 54), (45, 58), (50, 54)], w=2.5)
    save(svg, out, "obj_pudding")


def drone(out):
    """Hegemony drone: a round body with one angry eye and four rotors. 120x120."""
    W = 120
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 5, 1, 181)
    for k in range(4):
        a = math.tau / 8 + k * math.tau / 4
        x, y = c + 40 * math.cos(a), c + 40 * math.sin(a)
        pen.line([(c, c), (x, y)], w=6)
        pen.shape(ellipse(x, y, 16, 5, 20, a + 1.2), "grey2", w=3.5)
    pen.shape(circle(c, c, 30), "steel", w=5.5, shade=SH)
    pen.shape(circle(c, c, 20), "white", w=4)
    pen.pie_eye(c, c, 14, 14, look=(0.0, -0.5), white=False, pupil=0.6)
    pen.line([(c - 18, c - 22), (c + 18, c - 14)], w=5)
    pen.blob([(c - 12, c - 34), (c, c - 44), (c + 12, c - 34)], "rose", w=3.5)
    save(svg, out, "obj_drone")


def grabber(out):
    """Grabber drone: claws out. 130x130."""
    W = 130
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 5, 1, 191)
    for s in (-1, 1):
        pen.line([(c + s * 20, c - 10), (c + s * 36, c - 40), (c + s * 22, c - 56)], w=7)
        pen.line([(c + s * 36, c - 40), (c + s * 46, c - 58)], w=6)
    pen.shape(circle(c, c + 6, 32), "rose", w=5.5, shade=SH)
    eye_pair(pen, c, c, 12, 10, (0.0, -0.5), 0.2)
    pen.line([(c - 14, c + 20), (c, c + 16), (c + 14, c + 20)], w=4)
    save(svg, out, "obj_grabber")


def mine(out):
    """A mine with a face and a fizzing fuse. 120x120."""
    W = 120
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 5, 1, 201)
    for k in range(8):
        a = k * math.tau / 8
        pen.shape([(c + 30 * math.cos(a - 0.25), c + 30 * math.sin(a - 0.25)), (c + 50 * math.cos(a), c + 50 * math.sin(a)),
                   (c + 30 * math.cos(a + 0.25), c + 30 * math.sin(a + 0.25))], "steel", w=4)
    pen.shape(circle(c, c, 34), "night2", w=5.5, shade=SH)
    eye_pair(pen, c, c - 2, 12, 9, (0.0, 0.0), 0.3)
    pen.line([(c - 12, c + 18), (c, c + 12), (c + 12, c + 18)], w=3.5, ink="#fffaf0")
    pen.shine(c - 16, c - 20, 8, 4, -0.6, 0.35)
    save(svg, out, "obj_mine")


def cruiser(out):
    """Hegemony cruiser: big, grey, pompous, magenta trim, and an angry bow face. 240x380 (nose up).
    Its weak spot is the exhaust vent at the back."""
    W, H = 240, 380
    svg = SVG(W, H)
    pen = Pen(svg, 7, 1.4, 211)
    c = W / 2
    hull = [(c - 90, 330), (c - 104, 200), (c - 80, 80), (c, 14), (c + 80, 80), (c + 104, 200), (c + 90, 330), (c, 356)]
    pen.blob(hull, "steel", w=7, shade=(-10, -12, 0.2))
    pen.blob([(c - 70, 120), (c, 90), (c + 70, 120), (c + 66, 140), (c, 112), (c - 66, 140)], "rose", w=4.5)
    for y in (180, 250):
        for s in (-1, 1):
            pen.shape(circle(c + s * 52, y, 20), darker("steel", 0.15), w=4.5)
            pen.shape(rrect(c + s * 52 - 5, y - 40, 10, 34, 4), INK, w=0)
    # angry face on the bow
    eye_pair(pen, c, 70, 22, 15, (0.0, -0.3), 0.35)
    pen.line([(c - 42, 46), (c - 8, 60)], w=6.5)
    pen.line([(c + 8, 60), (c + 42, 46)], w=6.5)
    # the weak spot: a glowing vent at the back
    pen.shape(rrect(c - 30, 310, 60, 34, 10), "mustard", w=5)
    for x in (-16, 0, 16):
        pen.line([(c + x, 314), (c + x, 340)], w=3)
    save(svg, out, "obj_cruiser")
    LAYOUT["obj_cruiser"] = {"w": W, "h": H, "weak": [c, 327]}


def patrol(out):
    W, H = 150, 190
    svg = SVG(W, H)
    pen = Pen(svg, 5.5, 1.2, 221)
    c = W / 2
    pen.blob([(c - 50, 160), (c - 60, 90), (c, 14), (c + 60, 90), (c + 50, 160), (c, 176)], "steel", w=6, shade=SH)
    pen.blob([(c - 40, 110), (c, 96), (c + 40, 110), (c + 38, 124), (c, 110), (c - 38, 124)], "rose", w=4)
    eye_pair(pen, c, 62, 14, 10, (0.0, -0.4), 0.3)
    pen.line([(c - 26, 44), (c - 6, 52)], w=5)
    pen.line([(c + 6, 52), (c + 26, 44)], w=5)
    save(svg, out, "obj_patrol")


def station(out, name, col, flag):
    """A space station (customs, the diner, Haven). 260x260."""
    W = 260
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 6, 1.2, 231 + len(name))
    for k in range(4):
        a = k * math.tau / 4
        pen.line([(c, c), (c + 100 * math.cos(a), c + 100 * math.sin(a))], w=12, ink=P("steel"))
        pen.line([(c, c), (c + 100 * math.cos(a), c + 100 * math.sin(a))], w=3)
        pen.shape(rrect(c + 100 * math.cos(a) - 20, c + 100 * math.sin(a) - 20, 40, 40, 10), "grey2", w=4.5)
    pen.shape(circle(c, c, 62), col, w=6.5, shade=SH)
    pen.shape(circle(c, c, 30), "cream", w=5)
    pen.line([(c, c - 30), (c, c - 92)], w=4)
    pen.shape([(c, c - 92), (c + 34, c - 82), (c, c - 70)], flag, w=3.5)
    save(svg, out, name)


def asteroid(out):
    svg = SVG(130, 130)
    pen = Pen(svg, 5.5, 2.5, 241)
    pen.blob([(30, 40), (64, 16), (104, 34), (114, 76), (88, 112), (40, 108), (16, 74)], "tan", w=6, shade=(-8, -9, 0.25))
    for x, y, r in ((50, 50, 10), (80, 74, 14), (46, 86, 7)):
        pen.shape(circle(x, y, r), darker("tan", 0.2), w=3.5)
    save(svg, out, "obj_rock")


def pod(out):
    svg = SVG(90, 120)
    pen = Pen(svg, 5, 1, 251)
    pen.shape(rrect(18, 10, 54, 96, 27), "cream", w=5, shade=SH)
    pen.shape(circle(45, 40, 14), "sky", w=4)
    pen.shine(40, 35, 4, 2.5)
    pen.line([(20, 74), (70, 74)], w=3)
    save(svg, out, "obj_pod")


def unknown(out):
    """An unscanned contact: an ink smudge with a question mark. 110x110."""
    W = 110
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 4.5, 3.0, 261)
    pts = [(c + (36 + (6 if k % 2 else 0)) * math.cos(k * math.tau / 10), c + (34 + (5 if k % 2 else 0)) * math.sin(k * math.tau / 10))
           for k in range(10)]
    pen.blob(pts, "grey2", w=5)
    pen.line([(c - 14, c - 12), (c - 8, c - 24), (c + 8, c - 24), (c + 14, c - 12), (c, c), (c, c + 10)], w=7, wob=0.3, taper=0.8)
    pen.dot(c, c + 22, 5)
    save(svg, out, "obj_unknown")


def puff(out):
    """Cartoon explosion cloud with a star burst. 220x220."""
    W = 220
    c = W / 2
    svg = SVG(W, W)
    pen = Pen(svg, 6, 1.5, 271)
    star = []
    for k in range(16):
        a = k * math.tau / 16
        r = 100 if k % 2 == 0 else 52
        star.append((c + r * math.cos(a), c + r * math.sin(a)))
    pen.shape(star, "yellow", w=5)
    cloud = []
    for k in range(10):
        a = k * math.tau / 10
        r = 62 if k % 2 == 0 else 50
        cloud.append((c + r * math.cos(a), c + r * math.sin(a)))
    pen.blob(cloud, "orange", w=5.5, shade=(-8, -8, 0.2))
    pen.blob([(c - 24, c - 6), (c, c - 26), (c + 26, c - 4), (c + 6, c + 22)], "white", w=4)
    save(svg, out, "fx_puff")
    # smoke puff
    svg = SVG(120, 120)
    pen = Pen(svg, 4.5, 1.5, 273)
    cloud = [(60 + (44 if k % 2 == 0 else 34) * math.cos(k * math.tau / 10), 60 + (40 if k % 2 == 0 else 32) * math.sin(k * math.tau / 10))
             for k in range(10)]
    pen.blob(cloud, "grey2", w=4.5, shade=(-6, -6, 0.15))
    save(svg, out, "fx_smoke")


def flame(out):
    """A cartoon fire (for rooms on fire). 100x120."""
    svg = SVG(100, 120)
    pen = Pen(svg, 4.5, 1.2, 281)
    pen.blob([(50, 8), (78, 56), (84, 92), (50, 114), (16, 92), (22, 56), (36, 64)], "orange", w=5)
    pen.blob([(50, 46), (66, 78), (64, 100), (50, 108), (36, 100), (34, 78)], "yellow", w=3.5)
    save(svg, out, "fx_flame")


def spark(out):
    svg = SVG(60, 60)
    pen = Pen(svg, 3.5, 0.4, 291)
    pts = []
    for k in range(8):
        a = k * math.tau / 8 - math.pi / 2
        r = 26 if k % 2 == 0 else 9
        pts.append((30 + r * math.cos(a), 30 + r * math.sin(a)))
    pen.shape(pts, "yellow", w=3.5)
    save(svg, out, "fx_star")


def build(out):
    our_ship(out)
    cutaway(out)
    ring(out)
    buoy(out)
    target(out)
    junk(out)
    skip(out)
    pudding_small(out)
    drone(out)
    grabber(out)
    mine(out)
    cruiser(out)
    patrol(out)
    station(out, "obj_customs", P("steel"), P("rose"))
    station(out, "obj_haven", P("teal"), P("mustard"))
    station(out, "obj_diner", P("pink"), P("red"))
    asteroid(out)
    pod(out)
    unknown(out)
    puff(out)
    flame(out)
    spark(out)
    return {"things": LAYOUT}
