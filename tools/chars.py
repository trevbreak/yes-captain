"""Rubber-hose cartoon animal portraits for the crew and cast (256x256 SVG).

Each portrait is a sunburst badge with the character's head and shoulders. Faces use pie-cut eyes, a little
cel shading (darker crescent bottom-right, light from the top-left) and a brush outline.
"""
import math
import os
import random
from ink import SVG, Pen, P, mix, darker, lighter, ellipse, circle, spline, path_d, rrect, INK, set_lid_colour

S = 256
CX, CY = 128, 128
FR = 120  # frame radius
SH = (-9, -10, 0.2)  # standard head shading


def frame_begin(svg, pen, col):
    """Sunburst badge background, clipped to a circle."""
    base = P(col)
    q = pen.shape(circle(CX, CY, FR, 96), base, w=0)
    svg.clip_begin(q)
    rays = 18
    for i in range(0, rays, 2):
        a0 = i * math.tau / rays
        a1 = (i + 1) * math.tau / rays
        svg.path(path_d([(CX, CY + 40), (CX + 260 * math.cos(a0), CY + 40 + 260 * math.sin(a0)),
                         (CX + 260 * math.cos(a1), CY + 40 + 260 * math.sin(a1))]), lighter(base, 0.2))
    return q


def frame_end(svg, pen):
    svg.clip_end()
    pen.shape(circle(CX, CY, FR, 96), None, w=7, wob=0.8)


def shoulders(pen, col, y=210, rx=94, shade=True):
    return pen.blob([(CX - rx, 300), (CX - rx + 6, y + 20), (CX - 44, y - 4), (CX + 44, y - 4), (CX + rx - 6, y + 20), (CX + rx, 300)],
                    col, w=6, shade=(-12, -8, 0.18) if shade else None)


def cheeks(pen, x, y, r=10, col="rose"):
    pen.s.path(path_d(ellipse(x, y, r, r * 0.65, 24)), P(col), 0.5)


def smile(pen, x0, x1, y, depth=8, w=4.5):
    pen.line([(x0, y), ((x0 + x1) / 2, y + depth), (x1, y)], w=w)


def buttons(pen, xs, y, col="gold", r=5):
    for x in xs:
        pen.shape(circle(x, y, r, 24), col, w=2.5, wob=0.3)


# ================================================================ the crew

def captain(svg, pen):
    """Captain Mo Pennywhistle: a walrus in a captain's hat."""
    q = frame_begin(svg, pen, "navy")
    shoulders(pen, "navy")
    pen.blob([(CX - 30, 206), (CX, 236), (CX + 30, 206), (CX, 216)], "white", w=4)
    buttons(pen, (CX - 22, CX + 22), 236)
    skin = "tan"
    set_lid_colour(skin)
    pen.blob([(CX - 76, 134), (CX - 68, 88), (CX, 64), (CX + 68, 88), (CX + 76, 134), (CX + 60, 186), (CX, 202), (CX - 60, 186)], skin, w=6,
             shade=SH)
    for s in (-1, 1):
        pen.blob([(CX + s * 14, 164), (CX + s * 26, 164), (CX + s * 24, 214), (CX + s * 17, 224), (CX + s * 12, 202)], "white", w=4,
                 shade=(-2, -2, 0.1))
    for s in (-1, 1):
        pen.shape(ellipse(CX + s * 22, 156, 28, 22, 48), lighter(skin, 0.35), w=5)
        for dx, dy in ((-6, -4), (4, -6), (8, 4), (-2, 6), (-10, 6)):
            pen.dot(CX + s * 22 + dx * s, 156 + dy, 1.8)
    pen.blob([(CX - 54, 152), (CX - 32, 136), (CX, 142), (CX + 32, 136), (CX + 54, 152), (CX + 42, 164), (CX + 20, 152), (CX, 158),
              (CX - 20, 152), (CX - 42, 164)], "brown", w=4.5, shade=(-3, -4, 0.2))
    pen.blob([(CX - 14, 130), (CX, 121), (CX + 14, 130), (CX + 9, 140), (CX - 9, 140)], INK, w=3)
    pen.shine(CX - 4, 127, 4.5, 2.2)
    pen.pie_eye(CX - 23, 106, 12, 15, look=(0.3, 0.2))
    pen.pie_eye(CX + 23, 106, 12, 15, look=(0.3, 0.2))
    pen.line([(CX - 36, 88), (CX - 23, 82), (CX - 10, 88)], w=5.5)
    pen.line([(CX + 10, 88), (CX + 23, 82), (CX + 36, 88)], w=5.5)
    pen.blob([(CX - 64, 76), (CX - 68, 48), (CX - 32, 24), (CX + 32, 24), (CX + 68, 48), (CX + 64, 76)], "white", w=5.5, shade=(-6, -4, 0.12))
    pen.shape([(CX - 64, 68), (CX + 64, 68), (CX + 62, 84), (CX - 62, 84)], "navy", w=4.5)
    pen.blob([(CX - 58, 82), (CX, 76), (CX + 58, 82), (CX + 46, 98), (CX, 94), (CX - 46, 98)], INK, w=3)
    pen.shine(CX - 26, 90, 10, 2.5, 0.0, 0.35)
    pen.blob([(CX, 40), (CX + 12, 53), (CX, 67), (CX - 12, 53)], "gold", w=3.5)
    frame_end(svg, pen)


def helm(svg, pen):
    """Dex Wheelwright: a duck in a sailor cap."""
    q = frame_begin(svg, pen, "blue")
    shoulders(pen, "white")
    pen.blob([(CX - 52, 206), (CX, 230), (CX + 52, 206), (CX + 30, 238), (CX, 246), (CX - 30, 238)], "red", w=4.5)
    set_lid_colour("white")
    pen.blob([(CX - 60, 128), (CX - 54, 84), (CX, 60), (CX + 54, 84), (CX + 60, 128), (CX + 44, 182), (CX, 196), (CX - 44, 182)], "white",
             w=6, shade=(-9, -10, 0.12))
    # lower bill then upper bill (a big orange duck bill that sticks out)
    pen.blob([(CX - 36, 164), (CX, 158), (CX + 36, 164), (CX + 26, 184), (CX, 190), (CX - 26, 184)], darker("orange", 0.15), w=4.5)
    pen.blob([(CX - 50, 150), (CX - 36, 136), (CX, 134), (CX + 36, 136), (CX + 50, 150), (CX + 44, 166), (CX, 162), (CX - 44, 166)],
             "orange", w=5, shade=(-4, -5, 0.15))
    pen.dot(CX - 9, 145, 2.4)
    pen.dot(CX + 9, 145, 2.4)
    pen.shine(CX - 22, 143, 10, 3, -0.15, 0.5)
    pen.pie_eye(CX - 20, 108, 14, 19, look=(0.4, 0.0))
    pen.pie_eye(CX + 20, 108, 14, 19, look=(0.4, 0.0))
    pen.line([(CX - 32, 84), (CX - 18, 80), (CX - 8, 86)], w=4.5)
    pen.line([(CX + 8, 84), (CX + 20, 78), (CX + 32, 82)], w=4.5)
    cheeks(pen, CX - 42, 134)
    cheeks(pen, CX + 42, 134)
    svg.group("rotate(-10 128 66)")
    pen.blob([(CX - 50, 76), (CX - 44, 50), (CX, 38), (CX + 44, 50), (CX + 50, 76), (CX, 82)], "white", w=5, shade=(-5, -4, 0.12))
    pen.shape([(CX - 48, 70), (CX + 48, 70), (CX + 46, 84), (CX - 46, 84)], "blue", w=4.5)
    svg.end()
    for dx in (0, 12):
        pen.blob([(CX + 44 + dx, 80), (CX + 54 + dx, 86), (CX + 50 + dx, 110), (CX + 42 + dx, 106)], "blue", w=3.5)
    pen.line([(CX + 2, 42), (CX + 8, 26), (CX + 20, 30)], w=4)
    frame_end(svg, pen)


def engines(svg, pen):
    """Big Sal Throttleby: a bulldog with goggles on her forehead."""
    q = frame_begin(svg, pen, "orange")
    shoulders(pen, "orange")
    pen.shape(rrect(CX - 50, 206, 22, 60, 6), darker("orange", 0.2), w=3.5)
    pen.shape(rrect(CX + 28, 206, 22, 60, 6), darker("orange", 0.2), w=3.5)
    buttons(pen, (CX - 39, CX + 39), 224, "mustard", 5)
    skin = "sand"
    set_lid_colour(skin)
    # ears
    for s in (-1, 1):
        pen.blob([(CX + s * 52, 78), (CX + s * 80, 70), (CX + s * 86, 98), (CX + s * 66, 104)], "brown", w=5)
    # head with jowls
    pen.blob([(CX - 70, 122), (CX - 62, 80), (CX, 64), (CX + 62, 80), (CX + 70, 122), (CX + 78, 168), (CX + 50, 196), (CX, 200),
              (CX - 50, 196), (CX - 78, 168)], skin, w=6, shade=SH)
    # muzzle
    pen.blob([(CX - 50, 156), (CX - 40, 134), (CX, 128), (CX + 40, 134), (CX + 50, 156), (CX + 38, 186), (CX, 192), (CX - 38, 186)],
             lighter(skin, 0.4), w=5)
    # underbite: lower lip with two fangs
    pen.blob([(CX - 34, 172), (CX, 166), (CX + 34, 172), (CX + 28, 188), (CX, 194), (CX - 28, 188)], darker("rose", 0.1), w=4.5)
    for s in (-1, 1):
        pen.shape([(CX + s * 22, 174), (CX + s * 12, 174), (CX + s * 18, 158)], "white", w=3, wob=0.3)
    # nose
    pen.blob([(CX - 20, 142), (CX, 132), (CX + 20, 142), (CX + 14, 154), (CX - 14, 154)], INK, w=3)
    pen.shine(CX - 6, 139, 6, 2.5)
    # droopy eyes
    pen.pie_eye(CX - 24, 110, 12, 13, look=(0.0, 0.3), lid=0.38)
    pen.pie_eye(CX + 24, 110, 12, 13, look=(0.0, 0.3), lid=0.38)
    # brow wrinkles
    pen.line([(CX - 18, 88), (CX, 84), (CX + 18, 88)], w=3.5)
    # goggles on forehead
    pen.line([(CX - 68, 76), (CX - 40, 72)], w=7, ink=P("brown"))
    pen.line([(CX + 40, 72), (CX + 68, 76)], w=7, ink=P("brown"))
    for s in (-1, 1):
        pen.shape(circle(CX + s * 21, 70, 19), "mustard", w=4.5)
        pen.shape(circle(CX + s * 21, 70, 12), "sky", w=3, shade=(-3, -3, 0.25))
        pen.shine(CX + s * 21 - 4, 66, 4, 2.2)
    frame_end(svg, pen)


def weapons(svg, pen):
    """Rhoda 'Boom' Blastworth: a ginger cat with an eyepatch and a bandana."""
    q = frame_begin(svg, pen, "red")
    shoulders(pen, "red2")
    pen.shape(rrect(CX - 6, 206, 12, 60, 4), INK, w=0)
    skin = "orange"
    set_lid_colour(skin)
    # ears
    for s in (-1, 1):
        pen.shape([(CX + s * 30, 72), (CX + s * 72, 34), (CX + s * 68, 96)], skin, w=5.5)
        pen.shape([(CX + s * 40, 76), (CX + s * 64, 50), (CX + s * 62, 88)], "pink", w=0)
    pen.blob([(CX - 68, 128), (CX - 60, 84), (CX, 66), (CX + 60, 84), (CX + 68, 128), (CX + 54, 176), (CX, 194), (CX - 54, 176)], skin, w=6,
             shade=SH)
    # tabby stripes on forehead
    for dx in (-14, 0, 14):
        pen.line([(CX + dx, 70), (CX + dx * 1.1, 84)], w=4.5, ink=darker(skin, 0.35))
    # white muzzle
    pen.blob([(CX - 40, 158), (CX - 24, 138), (CX, 146), (CX + 24, 138), (CX + 40, 158), (CX + 24, 180), (CX, 184), (CX - 24, 180)],
             "cream", w=4.5)
    pen.shape([(CX - 9, 142), (CX + 9, 142), (CX, 152)], "rose", w=3, wob=0.3)
    pen.line([(CX - 16, 162), (CX, 168), (CX + 20, 158)], w=4)
    for s in (-1, 1):
        for k in (-1, 0, 1):
            pen.line([(CX + s * 34, 156 + k * 6), (CX + s * 66, 150 + k * 10)], w=2.2, taper=0.2)
    # one eye, one eyepatch
    pen.pie_eye(CX + 24, 116, 13, 17, look=(-0.3, 0.1), lid=0.15)
    pen.blob([(CX - 40, 106), (CX - 24, 96), (CX - 8, 106), (CX - 12, 126), (CX - 36, 126)], INK, w=3)
    pen.line([(CX - 66, 92), (CX - 30, 100), (CX + 10, 96), (CX + 64, 86)], w=3.5)
    pen.line([(CX + 10, 96), (CX + 24, 92), (CX + 40, 94)], w=4.5)
    # red bandana with dots and a knot
    pen.blob([(CX - 62, 82), (CX - 46, 56), (CX, 46), (CX + 46, 56), (CX + 62, 82), (CX, 74)], "red", w=5, shade=(-4, -4, 0.15))
    for dx, dy in ((-30, 66), (0, 58), (28, 66), (-12, 70), (14, 72)):
        pen.dot(CX + dx, dy, 3.2, "#fffaf0")
    pen.blob([(CX + 60, 78), (CX + 82, 70), (CX + 84, 92)], "red", w=4)
    pen.blob([(CX + 62, 84), (CX + 76, 106), (CX + 66, 110)], "red", w=4)
    frame_end(svg, pen)


def sensors(svg, pen):
    """Ozzy Squint: an owl in headphones, one eye permanently squinting at the radar."""
    q = frame_begin(svg, pen, "green")
    shoulders(pen, "brown")
    for x, y in ((CX - 24, 224), (CX, 236), (CX + 24, 224), (CX - 12, 250), (CX + 12, 250)):
        pen.line([(x - 6, y - 4), (x, y + 3), (x + 6, y - 4)], w=3, ink=P("sand"))
    skin = "brown"
    set_lid_colour(lighter("brown", 0.45))
    # ear tufts
    for s in (-1, 1):
        pen.shape([(CX + s * 30, 72), (CX + s * 66, 30), (CX + s * 62, 84)], skin, w=5)
    pen.blob([(CX - 70, 126), (CX - 62, 82), (CX, 62), (CX + 62, 82), (CX + 70, 126), (CX + 56, 178), (CX, 198), (CX - 56, 178)], skin,
             w=6, shade=SH)
    # facial disc
    for s in (-1, 1):
        pen.shape(circle(CX + s * 26, 118, 33), lighter("brown", 0.45), w=4.5)
    # headphones
    pen.line([(CX - 70, 112), (CX - 64, 60), (CX, 46), (CX + 64, 60), (CX + 70, 112)], w=9, ink=P("steel"), wob=0.3)
    for s in (-1, 1):
        pen.shape(rrect(CX + s * 72 - 12, 98, 24, 40, 10), "green", w=4.5)
    # eyes: one wide, one squinting
    pen.pie_eye(CX - 26, 118, 21, 23, look=(0.2, 0.0), lid=0.48)
    pen.pie_eye(CX + 26, 118, 21, 23, look=(0.2, 0.0))
    # beak
    pen.shape([(CX - 10, 140), (CX + 10, 140), (CX, 162)], "mustard", w=3.5)
    frame_end(svg, pen)


def shields(svg, pen):
    """Nana Fluffington: a turtle granny in a knitted beanie and spectacles."""
    q = frame_begin(svg, pen, "purple")
    # shell behind the shoulders
    pen.blob([(CX - 110, 270), (CX - 100, 196), (CX, 176), (CX + 100, 196), (CX + 110, 270)], "olive", w=6)
    for x in (-60, 0, 60):
        pen.shape([(CX + x - 18, 200), (CX + x + 18, 200), (CX + x + 26, 216), (CX + x + 18, 232), (CX + x - 18, 232), (CX + x - 26, 216)],
                  None, w=3.5)
    shoulders(pen, "lilac", y=214, rx=84)
    buttons(pen, (CX,), 236, "pink", 5)
    buttons(pen, (CX,), 254, "pink", 5)
    skin = "green"
    set_lid_colour(skin)
    pen.blob([(CX - 62, 128), (CX - 56, 86), (CX, 68), (CX + 56, 86), (CX + 62, 128), (CX + 48, 178), (CX, 196), (CX - 48, 178)], skin, w=6,
             shade=SH)
    cheeks(pen, CX - 40, 150, 11)
    cheeks(pen, CX + 40, 150, 11)
    pen.dot(CX - 6, 140, 2.2)
    pen.dot(CX + 6, 140, 2.2)
    smile(pen, CX - 24, CX + 24, 160, 10)
    # spectacles
    for s in (-1, 1):
        pen.pie_eye(CX + s * 22, 118, 11, 13, look=(0.0, 0.1))
        pen.shape(circle(CX + s * 22, 118, 19), None, w=4)
    pen.line([(CX - 4, 116), (CX, 112), (CX + 4, 116)], w=4)
    # beanie with ribs and a pompom
    pen.blob([(CX - 62, 98), (CX - 58, 62), (CX, 38), (CX + 58, 62), (CX + 62, 98), (CX, 90)], "rose", w=5.5, shade=(-5, -4, 0.15))
    pen.shape([(CX - 64, 86), (CX + 64, 86), (CX + 62, 104), (CX - 62, 104)], darker("rose", 0.15), w=4.5)
    for x in range(-50, 60, 14):
        pen.line([(CX + x, 88), (CX + x, 102)], w=2.5)
    pen.blob([(CX - 16, 36), (CX - 10, 18), (CX + 10, 16), (CX + 18, 34), (CX, 44)], "pink", w=4.5)
    frame_end(svg, pen)


def engineer(svg, pen):
    """Gus Spanner: a raccoon in a hard hat and overalls."""
    q = frame_begin(svg, pen, "mustard")
    shoulders(pen, "steel")
    pen.shape(rrect(CX - 40, 210, 80, 60, 10), "blue", w=4.5)
    buttons(pen, (CX - 28, CX + 28), 220, "mustard", 5)
    skin = "grey"
    set_lid_colour(skin)
    for s in (-1, 1):
        pen.shape(circle(CX + s * 56, 76, 20), skin, w=5)
        pen.shape(circle(CX + s * 56, 76, 10), INK, w=0)
    pen.blob([(CX - 70, 130), (CX - 60, 86), (CX, 68), (CX + 60, 86), (CX + 70, 130), (CX + 52, 176), (CX, 196), (CX - 52, 176)], skin,
             w=6, shade=SH)
    # white brows above the mask
    for s in (-1, 1):
        pen.blob([(CX + s * 8, 92), (CX + s * 30, 84), (CX + s * 52, 96), (CX + s * 30, 98)], "white", w=3)
    # mask
    pen.blob([(CX - 64, 122), (CX - 50, 100), (CX, 112), (CX + 50, 100), (CX + 64, 122), (CX + 40, 136), (CX, 128), (CX - 40, 136)], INK,
             w=3)
    pen.pie_eye(CX - 24, 116, 11, 13, look=(-0.3, 0.0))
    pen.pie_eye(CX + 24, 116, 11, 13, look=(-0.3, 0.0))
    # muzzle and grin
    pen.blob([(CX - 34, 160), (CX - 20, 138), (CX, 134), (CX + 20, 138), (CX + 34, 160), (CX + 18, 182), (CX, 186), (CX - 18, 182)], "white",
             w=4.5)
    pen.blob([(CX - 10, 140), (CX, 136), (CX + 10, 140), (CX, 150)], INK, w=2)
    pen.blob([(CX - 18, 160), (CX, 164), (CX + 18, 160), (CX + 10, 176), (CX, 178), (CX - 10, 176)], darker("rose", 0.2), w=3.5)
    pen.shape(rrect(CX - 7, 160, 14, 9, 2), "white", w=2.5, wob=0.2)
    # hard hat
    pen.blob([(CX - 60, 80), (CX - 54, 50), (CX, 32), (CX + 54, 50), (CX + 60, 80)], "mustard", w=5.5, shade=(-6, -4, 0.15))
    pen.blob([(CX - 76, 82), (CX, 74), (CX + 76, 82), (CX + 70, 94), (CX, 88), (CX - 70, 94)], darker("mustard", 0.1), w=4.5)
    pen.line([(CX, 36), (CX, 76)], w=4)
    pen.shine(CX - 28, 52, 10, 4, -0.7, 0.45)
    frame_end(svg, pen)


# ================================================================ the cast

def igor(svg, pen):
    """IGOR: a tin robot from the Foundry, deeply unimpressed."""
    q = frame_begin(svg, pen, "steel")
    shoulders(pen, darker("steel", 0.15))
    pen.shape(rrect(CX - 24, 204, 48, 30, 6), "grey2", w=4)
    for x in (-12, 0, 12):
        pen.dot(CX + x, 219, 3, "red")
    metal = "grey2"
    set_lid_colour(darker(metal, 0.1))
    # neck
    pen.shape(rrect(CX - 18, 180, 36, 30, 4), darker(metal, 0.2), w=4)
    # antenna
    pen.line([(CX, 56), (CX, 26)], w=5)
    pen.shape(circle(CX, 22, 10), "red", w=4)
    pen.shine(CX - 3, 19, 3.5, 2)
    # ear bolts
    for s in (-1, 1):
        pen.shape(rrect(CX + s * 74 - 10, 104, 20, 40, 6), darker(metal, 0.15), w=4.5)
    # head
    pen.shape(rrect(CX - 70, 52, 140, 136, 30), metal, w=6, shade=(-10, -10, 0.18))
    for x, y in ((-56, 66), (56, 66), (-56, 174), (56, 174)):
        pen.dot(CX + x, y, 3.5)
    # one big lens eye, half-lidded and unimpressed
    pen.shape(circle(CX, 108, 34), darker(metal, 0.25), w=5)
    pen.pie_eye(CX, 108, 25, 25, look=(0.0, 0.2), lid=0.42, pupil=0.5)
    # grille mouth
    pen.shape(rrect(CX - 34, 150, 68, 22, 6), INK, w=3)
    for x in range(-24, 30, 10):
        pen.line([(CX + x, 154), (CX + x, 168)], w=2.5, ink=P("grey2"), wob=0)
    frame_end(svg, pen)


def pudding(svg, pen):
    """Pudding: the Overlord's beloved pet. A pink blob. Perfect."""
    q = frame_begin(svg, pen, "lilac")
    pts = []
    for i in range(14):
        a = i * math.tau / 14
        r = 84 + (8 if i % 2 else 0)
        pts.append((CX + r * math.cos(a), 150 + r * 0.82 * math.sin(a)))
    set_lid_colour("pink")
    pen.blob(pts, "pink", w=6, shade=(-12, -12, 0.15))
    pen.pie_eye(CX - 24, 138, 12, 15, look=(0.0, 0.3))
    pen.pie_eye(CX + 24, 138, 12, 15, look=(0.0, 0.3))
    cheeks(pen, CX - 48, 162, 12, "rose")
    cheeks(pen, CX + 48, 162, 12, "rose")
    smile(pen, CX - 12, CX + 12, 166, 7, 4)
    pen.shine(CX - 40, 106, 16, 7, -0.5, 0.5)
    frame_end(svg, pen)


def thrupp(svg, pen):
    """Admiral Thrupp: a pompous toad in a bicorne, covered in medals he awarded himself."""
    q = frame_begin(svg, pen, "grey")
    shoulders(pen, "steel")
    pen.line([(CX - 80, 214), (CX + 60, 270)], w=16, ink=P("rose"), wob=0.4)
    for s in (-1, 1):
        pen.blob([(CX + s * 50, 206), (CX + s * 92, 212), (CX + s * 96, 228), (CX + s * 54, 226)], "gold", w=4)
        for k in range(4):
            pen.line([(CX + s * (60 + k * 9), 226), (CX + s * (60 + k * 9), 240)], w=3, ink=P("gold"))
    for i, x in enumerate((-34, -18, -2)):
        pen.shape(circle(CX + x, 240, 7), ["gold", "red", "gold"][i], w=3)
    skin = "olive"
    set_lid_colour(skin)
    # wide flat head, bulging eyes on top
    for s in (-1, 1):
        pen.shape(circle(CX + s * 34, 92, 24), skin, w=5.5, shade=(-4, -4, 0.15))
    pen.blob([(CX - 82, 140), (CX - 70, 100), (CX, 92), (CX + 70, 100), (CX + 82, 140), (CX + 66, 186), (CX, 200), (CX - 66, 186)], skin, w=6,
             shade=SH)
    pen.pie_eye(CX - 34, 94, 15, 16, look=(0.1, 0.2), lid=0.3)
    pen.pie_eye(CX + 34, 94, 15, 16, look=(0.1, 0.2), lid=0.3)
    # big frown and double chin
    pen.line([(CX - 54, 160), (CX - 20, 150), (CX + 20, 150), (CX + 54, 160)], w=5.5)
    pen.line([(CX - 30, 182), (CX, 188), (CX + 30, 182)], w=3)
    pen.dot(CX - 8, 130, 2.5)
    pen.dot(CX + 8, 130, 2.5)
    # bicorne
    pen.blob([(CX - 92, 70), (CX - 40, 34), (CX, 22), (CX + 40, 34), (CX + 92, 70), (CX, 62)], INK, w=4)
    pen.line([(CX - 86, 68), (CX, 58), (CX + 86, 68)], w=4.5, ink=P("gold"))
    pen.shape(circle(CX, 46, 11), "rose", w=3.5)
    frame_end(svg, pen)


def overlord(svg, pen):
    """The Overlord: a grumpy bear in a crown and monocle. Loves Pudding more than the empire."""
    q = frame_begin(svg, pen, "purple")
    shoulders(pen, "purple")
    pen.blob([(CX - 90, 214), (CX - 40, 200), (CX + 40, 200), (CX + 90, 214), (CX + 60, 236), (CX - 60, 236)], "white", w=4.5)
    for x, y in ((-60, 220), (-24, 214), (12, 216), (48, 222), (-40, 228), (30, 228)):
        pen.line([(CX + x, y - 3), (CX + x, y + 4)], w=3)
    skin = "brown"
    set_lid_colour(skin)
    for s in (-1, 1):
        pen.shape(circle(CX + s * 58, 82, 22), skin, w=5)
        pen.shape(circle(CX + s * 58, 82, 11), lighter(skin, 0.35), w=0)
    pen.blob([(CX - 72, 130), (CX - 64, 88), (CX, 70), (CX + 64, 88), (CX + 72, 130), (CX + 56, 180), (CX, 200), (CX - 56, 180)], skin, w=6,
             shade=SH)
    pen.blob([(CX - 36, 160), (CX - 26, 138), (CX, 134), (CX + 26, 138), (CX + 36, 160), (CX + 22, 184), (CX, 188), (CX - 22, 184)],
             lighter(skin, 0.4), w=4.5)
    pen.blob([(CX - 14, 144), (CX, 136), (CX + 14, 144), (CX, 154)], INK, w=2.5)
    pen.line([(CX - 16, 172), (CX, 166), (CX + 16, 172)], w=4)
    pen.pie_eye(CX - 24, 114, 11, 13, look=(0.2, 0.2), lid=0.25)
    pen.pie_eye(CX + 24, 114, 11, 13, look=(0.2, 0.2), lid=0.25)
    pen.line([(CX - 40, 96), (CX - 12, 102)], w=6)
    pen.line([(CX + 12, 102), (CX + 40, 96)], w=6)
    pen.shape(circle(CX + 24, 114, 19), None, w=4, ink=P("gold"))
    pen.line([(CX + 42, 120), (CX + 56, 150), (CX + 50, 190)], w=2.5, ink=P("gold"))
    # crown
    pen.shape([(CX - 46, 82), (CX - 52, 40), (CX - 26, 60), (CX, 28), (CX + 26, 60), (CX + 52, 40), (CX + 46, 82)], "gold", w=5,
              shade=(-4, -3, 0.15))
    for x, c in ((-26, "red"), (0, "teal"), (26, "red")):
        pen.shape(circle(CX + x, 72, 5.5), c, w=2.5)
    frame_end(svg, pen)


def gristle(svg, pen):
    """Ma Gristle: a pig who runs the greasiest diner in the Free Lanes."""
    q = frame_begin(svg, pen, "teal")
    shoulders(pen, "cream")
    pen.shape(rrect(CX - 46, 214, 92, 60, 12), "white", w=4.5)
    skin = "pink"
    set_lid_colour(skin)
    for s in (-1, 1):
        pen.blob([(CX + s * 40, 80), (CX + s * 80, 72), (CX + s * 76, 112), (CX + s * 56, 104)], darker(skin, 0.1), w=5)
    pen.blob([(CX - 66, 130), (CX - 60, 88), (CX, 70), (CX + 60, 88), (CX + 66, 130), (CX + 54, 178), (CX, 198), (CX - 54, 178)], skin, w=6,
             shade=SH)
    pen.shape(ellipse(CX, 146, 26, 18, 40), darker(skin, 0.12), w=5)
    pen.shape(ellipse(CX - 9, 146, 4.5, 7, 16), INK, w=0)
    pen.shape(ellipse(CX + 9, 146, 4.5, 7, 16), INK, w=0)
    pen.blob([(CX - 30, 172), (CX, 182), (CX + 30, 172), (CX + 18, 188), (CX, 192), (CX - 18, 188)], "red", w=4)
    pen.pie_eye(CX - 26, 114, 11, 14, look=(0.2, 0.0))
    pen.pie_eye(CX + 26, 114, 11, 14, look=(0.2, 0.0))
    for s in (-1, 1):
        pen.line([(CX + s * 20, 98), (CX + s * 30, 94), (CX + s * 40, 98)], w=3)
        for k in range(3):
            pen.line([(CX + s * (34 + k * 4), 104 - k * 3), (CX + s * (40 + k * 5), 100 - k * 4)], w=2.2)
    cheeks(pen, CX - 44, 156, 11)
    cheeks(pen, CX + 44, 156, 11)
    # headscarf with dots and a knot on top
    pen.blob([(CX - 64, 96), (CX - 58, 60), (CX, 44), (CX + 58, 60), (CX + 64, 96), (CX, 82)], "red", w=5.5, shade=(-5, -4, 0.15))
    for dx, dy in ((-36, 72), (-12, 60), (12, 60), (36, 72), (0, 76)):
        pen.dot(CX + dx, dy, 3.5, "#fffaf0")
    pen.blob([(CX - 22, 46), (CX - 34, 24), (CX - 6, 36)], "red", w=4)
    pen.blob([(CX + 22, 46), (CX + 34, 24), (CX + 6, 36)], "red", w=4)
    frame_end(svg, pen)


ALL = {"captain": captain, "helm": helm, "engines": engines, "weapons": weapons, "sensors": sensors, "shields": shields,
       "engineer": engineer, "igor": igor, "pudding": pudding, "thrupp": thrupp, "overlord": overlord, "gristle": gristle}


def build(out):
    os.makedirs(out, exist_ok=True)
    for i, (name, fn) in enumerate(ALL.items()):
        svg = SVG(S, S)
        pen = Pen(svg, 5.5, 1.3, seed=100 + i * 37)
        fn(svg, pen)
        svg.save(os.path.join(out, "portrait_%s.svg" % name))


if __name__ == "__main__":
    import sys
    build(sys.argv[1] if len(sys.argv) > 1 else "/tmp/art2")
    print("ok")
