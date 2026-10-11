"""White silhouette icons (64x64), slightly hand-wobbled. Tinted in-engine (usually ink)."""
import math
import os
from ink import SVG, Pen, rrect, ellipse, circle, spline, path_d, brush_d, wobble, resample

WHITE = "#ffffff"


def _new():
    svg = SVG(64, 64)
    return svg, Pen(svg, 0, 0.6, 5)


def fill(pen, pts, wob=0.5):
    pen.shape(pts, WHITE, w=0, wob=wob)


def stroke(svg, pts, w=6, closed=False):
    svg.path(brush_d(wobble(resample(pts, closed, 2), 0.4, closed, len(pts)), closed, w, 0.15, 3, 0.9), WHITE)


def ring(svg, cx, cy, r, w):
    svg.path(brush_d(wobble(circle(cx, cy, r, 60), 0.4, True, 9), True, w, 0.1, 4), WHITE)


def build(out):
    I = {}

    def mk(name, fn):
        svg, pen = _new()
        fn(svg, pen)
        svg.save(os.path.join(out, "icon_%s.svg" % name))

    mk("captain", lambda s, p: (fill(p, [(8, 34), (12, 18), (32, 10), (52, 18), (56, 34)]), fill(p, rrect(6, 34, 52, 10, 4)),
                                fill(p, [(14, 44), (50, 44), (44, 54), (20, 54)])))

    def wheel(s, p):
        ring(s, 32, 32, 17, 6)
        for k in range(8):
            a = k * math.tau / 8
            stroke(s, [(32 + 6 * math.cos(a), 32 + 6 * math.sin(a)), (32 + 29 * math.cos(a), 32 + 29 * math.sin(a))], 5)
        fill(p, circle(32, 32, 7))
    mk("helm", wheel)
    mk("engines", lambda s, p: (fill(p, [(32, 4), (46, 26), (50, 42), (42, 58), (22, 58), (14, 42), (20, 28), (28, 34)]),))

    def cross(s, p):
        ring(s, 32, 32, 18, 6)
        for a, b in (((32, 4), (32, 20)), ((32, 44), (32, 60)), ((4, 32), (20, 32)), ((44, 32), (60, 32))):
            stroke(s, [a, b], 6)
        fill(p, circle(32, 32, 4))
    mk("weapons", cross)

    def dish(s, p):
        fill(p, [(10, 20), (44, 54), (34, 58), (16, 50), (8, 36)])
        stroke(s, [(26, 36), (44, 18)], 5)
        fill(p, circle(46, 16, 6))
        stroke(s, [(26, 50), (20, 60), (40, 60)], 5)
    mk("sensors", dish)
    mk("shields", lambda s, p: (fill(p, spline([(32, 4), (54, 12), (52, 36), (32, 60), (12, 36), (10, 12)], True, 8)),))

    def wrench(s, p):
        stroke(s, [(14, 50), (40, 24)], 10)
        fill(p, spline([(36, 12), (48, 6), (58, 16), (52, 28), (40, 30), (34, 22)], True, 6))
        fill(p, circle(14, 50, 8))
    mk("engineer", wrench)
    mk("check", lambda s, p: stroke(s, [(10, 34), (26, 50), (54, 16)], 9))
    mk("x", lambda s, p: (stroke(s, [(14, 14), (50, 50)], 9), stroke(s, [(50, 14), (14, 50)], 9)))
    mk("star", lambda s, p: fill(p, [(32 + (28 if k % 2 == 0 else 12) * math.cos(-math.pi / 2 + k * math.pi / 5),
                                      34 + (28 if k % 2 == 0 else 12) * math.sin(-math.pi / 2 + k * math.pi / 5)) for k in range(10)]))

    def warn(s, p):
        fill(p, [(32, 6), (58, 54), (6, 54)], 0.3)
    mk("warning", warn)
    mk("fire", lambda s, p: fill(p, spline([(32, 4), (46, 24), (52, 42), (32, 60), (12, 42), (20, 26), (28, 32)], True, 6)))

    def clock(s, p):
        ring(s, 32, 32, 24, 6)
        stroke(s, [(32, 18), (32, 32), (42, 38)], 5)
    mk("clock", clock)
    mk("heart", lambda s, p: fill(p, spline([(32, 20), (44, 8), (58, 18), (54, 36), (32, 56), (10, 36), (6, 18), (20, 8)], True, 6)))
    mk("bolt", lambda s, p: fill(p, [(38, 4), (14, 36), (30, 36), (24, 60), (50, 26), (34, 26)]))

    def thermo(s, p):
        fill(p, rrect(26, 6, 12, 40, 6))
        fill(p, circle(32, 48, 11))
    mk("thermo", thermo)
    mk("pudding", lambda s, p: fill(p, [(32 + (24 + (4 if k % 2 else 0)) * math.cos(k * math.tau / 12),
                                         34 + (20 + (3 if k % 2 else 0)) * math.sin(k * math.tau / 12)) for k in range(12)]))

    def menu(s, p):
        for y in (16, 32, 48):
            stroke(s, [(10, y), (54, y)], 8)
    mk("menu", menu)
    mk("back", lambda s, p: stroke(s, [(40, 10), (18, 32), (40, 54)], 9))
    mk("play", lambda s, p: fill(p, [(16, 8), (54, 32), (16, 56)], 0.3))

    def crew(s, p):
        fill(p, circle(22, 22, 10))
        fill(p, circle(44, 24, 8))
        fill(p, spline([(4, 56), (10, 38), (34, 38), (40, 56)], True, 4))
        fill(p, spline([(30, 54), (36, 38), (56, 38), (60, 54)], True, 4))
    mk("crew", crew)

    def robot(s, p):
        fill(p, rrect(12, 16, 40, 36, 8))
        stroke(s, [(32, 16), (32, 6)], 4)
        fill(p, circle(32, 6, 4))
    mk("robot", robot)

    def speaker(s, p):
        fill(p, [(8, 24), (20, 24), (34, 10), (34, 54), (20, 40), (8, 40)])
        stroke(s, [(42, 22), (48, 32), (42, 42)], 5)
        stroke(s, [(48, 14), (58, 32), (48, 50)], 5)
    mk("speaker", speaker)

    def flag(s, p):
        stroke(s, [(14, 6), (14, 60)], 6)
        fill(p, [(14, 8), (54, 16), (14, 34)])
    mk("flag", flag)

    def lock(s, p):
        fill(p, rrect(12, 28, 40, 30, 6))
        stroke(s, [(20, 30), (20, 18), (32, 10), (44, 18), (44, 30)], 7)
    mk("lock", lock)

    def eye(s, p):
        fill(p, spline([(4, 32), (32, 14), (60, 32), (32, 50)], True, 6))
    mk("eye", eye)

    def question(s, p):
        stroke(s, [(20, 20), (26, 10), (40, 10), (46, 20), (32, 32), (32, 42)], 9)
        fill(p, circle(32, 54, 6))
    mk("question", question)

    def shield_hit(s, p):
        fill(p, [(32 + (28 if k % 2 == 0 else 13) * math.cos(k * math.tau / 14), 32 + (28 if k % 2 == 0 else 13) * math.sin(k * math.tau / 14))
                 for k in range(14)])
    mk("boom", shield_hit)

    def scan(s, p):
        ring(s, 28, 28, 16, 7)
        stroke(s, [(40, 40), (56, 56)], 10)
    mk("scan", scan)

    def tractor(s, p):
        fill(p, rrect(22, 4, 20, 14, 4))
        fill(p, [(24, 18), (40, 18), (56, 58), (8, 58)], 0.3)
    mk("tractor", tractor)

    def torpedo(s, p):
        fill(p, rrect(10, 24, 40, 16, 8))
        fill(p, [(46, 22), (58, 32), (46, 42)])
        fill(p, [(10, 24), (4, 16), (16, 24)])
        fill(p, [(10, 40), (4, 48), (16, 40)])
    mk("torpedo", torpedo)
    def mapicon(s, p):
        fill(p, [(6, 14), (22, 8), (42, 14), (58, 8), (58, 50), (42, 56), (22, 50), (6, 56)], 0.4)
    mk("map", mapicon)
    mk("up", lambda s, p: fill(p, [(32, 8), (56, 44), (8, 44)], 0.3))
    mk("down", lambda s, p: fill(p, [(8, 20), (56, 20), (32, 56)], 0.3))
    return None
