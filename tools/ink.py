"""Hand-inked SVG drawing primitives for the 1930s cartoon look.

Every shape is sampled into a dense polyline, gets a smooth low-frequency wobble (so lines look drawn by hand,
not by a ruler), and is outlined with a variable-width brush stroke (a filled ribbon, so the width can swell
and thin like a real ink brush). ThorVG rasterizes the result in-engine with antialiasing.
"""
import math
import random

INK = "#1d1712"

# ---------------------------------------------------------------- palette (vintage, warm, slightly faded)
PAL = {
    "ink": INK, "paper": "#f2e2c0", "paper2": "#e3cd9f", "paper3": "#d4b985", "cream": "#fbf2dc", "white": "#fffaf0",
    "red": "#c9413a", "red2": "#a5302b", "orange": "#e07b39", "mustard": "#e2a93b", "gold": "#d9a43a",
    "yellow": "#f2cf5b", "teal": "#3f8f86", "blue": "#4a79a8", "sky": "#8fb8c9", "navy": "#2f3e5c",
    "green": "#6f9a4a", "olive": "#8a8b3c", "pink": "#e79a9a", "rose": "#d9737a", "purple": "#7a5a8c",
    "lilac": "#a98fb8", "brown": "#8a5a3b", "tan": "#c79a68", "sand": "#e3c08c", "grey": "#8f8c86",
    "grey2": "#b9b4a8", "steel": "#6d7a86", "night": "#232338", "night2": "#34324f",
}


def P(name):
    return PAL.get(name, name)


def mix(a, b, t):
    a, b = P(a).lstrip("#"), P(b).lstrip("#")
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i:i + 2], 16) for i in (0, 2, 4)]
    return "#" + "".join("%02x" % int(round(ca[i] + (cb[i] - ca[i]) * t)) for i in range(3))


def darker(c, t=0.25):
    return mix(c, INK, t)


def lighter(c, t=0.3):
    return mix(c, "#ffffff", t)


# ---------------------------------------------------------------- sampling

def ellipse(cx, cy, rx, ry, n=72, rot=0.0, a0=0.0, a1=None):
    pts = []
    if a1 is None:
        for i in range(n):
            a = a0 + 2 * math.pi * i / n
            x, y = rx * math.cos(a), ry * math.sin(a)
            pts.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
    else:
        for i in range(n + 1):
            a = a0 + (a1 - a0) * i / n
            x, y = rx * math.cos(a), ry * math.sin(a)
            pts.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
    return pts


def circle(cx, cy, r, n=64):
    return ellipse(cx, cy, r, r, n)


def rrect(x, y, w, h, r, n=8):
    r = min(r, w / 2, h / 2)
    pts = []
    for (cx, cy, a0) in ((x + w - r, y + r, -math.pi / 2), (x + w - r, y + h - r, 0), (x + r, y + h - r, math.pi / 2),
                         (x + r, y + r, math.pi)):
        for i in range(n + 1):
            a = a0 + (math.pi / 2) * i / n
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return resample(pts, True, 3.0)


def spline(ctrl, closed=False, per=10):
    """Catmull-Rom spline through the control points."""
    pts = []
    n = len(ctrl)
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0 = ctrl[(i - 1) % n] if closed else ctrl[max(i - 1, 0)]
        p1 = ctrl[i]
        p2 = ctrl[(i + 1) % n]
        p3 = ctrl[(i + 2) % n] if closed else ctrl[min(i + 2, n - 1)]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            pts.append((x, y))
    if not closed:
        pts.append(ctrl[-1])
    return pts


def resample(pts, closed, step):
    """Evenly re-space a polyline so the wobble and brush look uniform."""
    seq = pts + [pts[0]] if closed else pts
    out = [seq[0]]
    carry = 0.0
    for i in range(len(seq) - 1):
        ax, ay = seq[i]
        bx, by = seq[i + 1]
        seg = math.hypot(bx - ax, by - ay)
        if seg < 1e-9:
            continue
        d = step - carry
        while d <= seg:
            t = d / seg
            out.append((ax + (bx - ax) * t, ay + (by - ay) * t))
            d += step
        carry = seg - (d - step)
    if closed and len(out) > 2 and math.hypot(out[-1][0] - out[0][0], out[-1][1] - out[0][1]) < step * 0.5:
        out.pop()
    if not closed and out[-1] != seq[-1]:
        out.append(seq[-1])
    return out


def length(pts, closed):
    seq = pts + [pts[0]] if closed else pts
    return sum(math.hypot(seq[i + 1][0] - seq[i][0], seq[i + 1][1] - seq[i][1]) for i in range(len(seq) - 1))


def normals(pts, closed):
    n = len(pts)
    out = []
    for i in range(n):
        if closed:
            a, b = pts[(i - 1) % n], pts[(i + 1) % n]
        else:
            a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        l = math.hypot(dx, dy) or 1.0
        out.append((-dy / l, dx / l))
    return out


class Noise1D:
    """Smooth periodic noise: a few sines with random phases. Closed shapes loop seamlessly."""

    def __init__(self, seed, octaves=3, base=2):
        r = random.Random(seed)
        self.terms = [(base * (k + 1) + r.randint(0, 2), r.random() * math.tau, 1.0 / (k + 1)) for k in range(octaves)]
        self.norm = sum(t[2] for t in self.terms)

    def __call__(self, u):
        return sum(math.sin(f * u * math.tau + ph) * a for f, ph, a in self.terms) / self.norm


def wobble(pts, amp=1.4, closed=True, seed=1, waves=None):
    if amp <= 0:
        return list(pts)
    pts = resample(pts, closed, 2.5)
    L = length(pts, closed)
    if waves is None:
        waves = max(2, int(L / 70))
    nz = Noise1D(seed, 3, waves)
    nm = normals(pts, closed)
    out = []
    n = len(pts)
    for i, (p, nn) in enumerate(zip(pts, nm)):
        u = i / n if closed else i / max(1, n - 1)
        d = amp * nz(u)
        out.append((p[0] + nn[0] * d, p[1] + nn[1] * d))
    return out


# ---------------------------------------------------------------- SVG output

def fmt(v):
    return ("%.1f" % v).rstrip("0").rstrip(".")


def path_d(pts, closed=True):
    s = "M" + " L".join("%s %s" % (fmt(x), fmt(y)) for x, y in pts)
    return s + (" Z" if closed else "")


def brush_d(pts, closed, w, var=0.3, seed=1, taper=0.25):
    """A variable-width ink stroke as a filled ribbon path."""
    pts = resample(pts, closed, 2.0)
    n = len(pts)
    if n < 2:
        return ""
    nz = Noise1D(seed + 17, 2, 2)
    nm = normals(pts, closed)
    left, right = [], []
    for i in range(n):
        u = i / n if closed else i / max(1, n - 1)
        ww = w * (1.0 + var * nz(u))
        if not closed:
            e = min(u, 1 - u)
            ww *= taper + (1 - taper) * min(1.0, e / 0.18)
        h = ww / 2
        p, nn = pts[i], nm[i]
        left.append((p[0] + nn[0] * h, p[1] + nn[1] * h))
        right.append((p[0] - nn[0] * h, p[1] - nn[1] * h))
    if closed:
        return path_d(left) + " " + path_d(list(reversed(right)))
    # open stroke: round-ish caps by joining the two sides
    return path_d(left + list(reversed(right)))


class SVG:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.els = []
        self.defs = []
        self._id = 0

    def uid(self, p="c"):
        self._id += 1
        return "%s%d" % (p, self._id)

    def raw(self, s):
        self.els.append(s)

    def path(self, d, fill, opacity=1.0, rule="nonzero", extra=""):
        op = "" if opacity >= 1.0 else ' fill-opacity="%s"' % fmt(opacity)
        self.els.append('<path d="%s" fill="%s"%s fill-rule="%s"%s/>' % (d, P(fill), op, rule, extra))

    def poly(self, pts, fill, opacity=1.0, closed=True):
        self.path(path_d(pts, closed), fill, opacity)

    def clip_begin(self, pts):
        cid = self.uid("clip")
        self.defs.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (cid, path_d(pts)))
        self.els.append('<g clip-path="url(#%s)">' % cid)

    def clip_end(self):
        self.els.append("</g>")

    def group(self, transform):
        self.els.append('<g transform="%s">' % transform)

    def end(self):
        self.els.append("</g>")

    def save(self, path):
        defs = "<defs>%s</defs>" % "".join(self.defs) if self.defs else ""
        s = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s%s</svg>' % (
            self.w, self.h, self.w, self.h, defs, "".join(self.els))
        with open(path, "w") as f:
            f.write(s)


# ---------------------------------------------------------------- the inking brush

class Pen:
    """Draws inked shapes onto an SVG with a consistent hand."""

    def __init__(self, svg, w=5.0, wob=1.2, seed=1):
        self.s, self.w, self.wob, self.seed = svg, w, wob, seed

    def _seed(self):
        self.seed += 7
        return self.seed

    def shape(self, pts, fill=None, w=None, wob=None, ink=INK, shadow=None, hatch=None, closed=True, var=0.3, shade=None):
        """Fill + brush outline. shadow=(dx, dy, colour, opacity) draws a hard offset shadow first."""
        w = self.w if w is None else w
        wob = self.wob if wob is None else wob
        q = wobble(pts, wob, closed, self._seed()) if wob > 0 else resample(pts, closed, 2.5)
        if shadow and closed:
            dx, dy, col, op = shadow
            self.s.path(path_d([(x + dx, y + dy) for x, y in q]), col, op)
        if fill and closed:
            self.s.path(path_d(q), fill)
            if shade:
                # cel shading: a darker crescent on the side away from the light (light comes from top-left)
                dx, dy, t = shade if len(shade) == 3 else (shade[0], shade[1], 0.2)
                xs = [p[0] for p in q]
                ys = [p[1] for p in q]
                cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
                self.s.clip_begin(q)
                self.s.path(path_d(q), darker(fill, t))
                self.s.path(path_d([(cx + (x - cx) * 0.97 + dx, cy + (y - cy) * 0.97 + dy) for x, y in q]), fill)
                self.s.clip_end()
        if hatch and closed:
            self.hatch(q, *hatch)
        if w > 0:
            self.s.path(brush_d(q, closed, w, var, self._seed()), ink)
        return q

    def line(self, pts, w=None, ink=INK, wob=None, taper=0.3, var=0.25, smooth=True):
        w = self.w if w is None else w
        wob = self.wob * 0.6 if wob is None else wob
        q = spline(pts, False, 8) if smooth and len(pts) > 2 else resample(pts, False, 2.0)
        q = wobble(q, wob, False, self._seed()) if wob > 0 else q
        self.s.path(brush_d(q, False, w, var, self._seed(), taper), ink)

    def blob(self, ctrl, fill=None, w=None, wob=None, **kw):
        return self.shape(spline(ctrl, True, 10), fill, w, wob, **kw)

    def dot(self, cx, cy, r, col=INK):
        self.s.path(path_d(circle(cx, cy, r, 28)), col)

    def hatch(self, pts, col=INK, spacing=7.0, angle=-0.7, w=1.6, opacity=0.55):
        """Diagonal hatching clipped to the shape (shade without gradients, like a comic)."""
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        R = math.hypot(max(xs) - min(xs), max(ys) - min(ys)) / 2 + 4
        self.s.clip_begin(pts)
        ca, sa = math.cos(angle), math.sin(angle)
        k = -R
        while k <= R:
            a = (cx + ca * -R - sa * k, cy + sa * -R + ca * k)
            b = (cx + ca * R - sa * k, cy + sa * R + ca * k)
            d = brush_d(wobble([a, b], 0.6, False, self._seed()), False, w, 0.3, self._seed(), 0.5)
            self.s.path(d, col, opacity)
            k += spacing
        self.s.clip_end()

    def shine(self, cx, cy, rx, ry, rot=-0.6, op=0.55):
        """A little white highlight streak."""
        self.s.path(path_d(ellipse(cx, cy, rx, ry, 24, rot)), "#ffffff", op)

    def pie_eye(self, cx, cy, rx, ry, look=(0.0, 0.0), white=True, lid=0.0, wedge=0.0, pupil=0.62, w=None):
        """Rubber-hose pie eye: white oval, big black pupil with a pie-slice cut out. lid 0..1 closes it from the top."""
        w = (self.w * 0.8) if w is None else w
        if white:
            q = self.shape(ellipse(cx, cy, rx, ry, 48), "#fffaf0", w=w, wob=0.5)
        else:
            q = ellipse(cx, cy, rx, ry, 48)
        px, py = cx + look[0] * rx * 0.35, cy + look[1] * ry * 0.3
        prx, pry = rx * pupil, ry * (pupil + 0.12)
        self.s.clip_begin(q)
        self.s.path(path_d(ellipse(px, py, prx, pry, 40)), INK)
        # the pie slice
        a0 = -2.2 + wedge
        cut = [(px, py)] + ellipse(px, py, prx * 1.05, pry * 1.05, 10, 0.0, a0, a0 + 0.75)
        self.s.path(path_d(cut), "#fffaf0")
        if lid > 0:
            top = cy - ry - 2
            lid_y = cy - ry + 2 * ry * lid
            self.s.path(path_d([(cx - rx - 3, top), (cx + rx + 3, top), (cx + rx + 3, lid_y), (cx - rx - 3, lid_y)]), lid_col_default)
        self.s.clip_end()
        if lid > 0:
            lid_y = cy - ry + 2 * ry * lid
            self.line([(cx - rx * 1.05, lid_y + 1), (cx, lid_y + 3), (cx + rx * 1.05, lid_y + 1)], w=w * 1.1)
        return q


lid_col_default = "#c79a68"


def set_lid_colour(c):
    global lid_col_default
    lid_col_default = P(c)
