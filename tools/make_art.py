#!/usr/bin/env python3
"""Generates the game's vector art (SVG): character portraits and UI icons.

Style target: Two Point Hospital / Two Point Museum. Long rounded heads, big friendly noses,
small dot eyes, soft gradient shading, tinted outlines (never pure black), chunky shapes.

Run:  python3 tools/make_art.py      (writes into assets/art/)
"""
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art")
os.makedirs(OUT, exist_ok=True)


def shade(hex_color, f):
    """f < 0 darkens, f > 0 lightens."""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    if f < 0:
        r, g, b = [int(c * (1 + f)) for c in (r, g, b)]
    else:
        r, g, b = [int(c + (255 - c) * f) for c in (r, g, b)]
    return "#%02x%02x%02x" % (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))


SKIN = {
    "light": "#f6cfae",
    "pale": "#fbe0c9",
    "medium": "#e0a87e",
    "tan": "#c98a5e",
    "dark": "#8d5a3c",
    "deep": "#6b4029",
}


def svg_open(w=256, h=256):
    return [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">']


def grad_defs(gid, c, kind="radial"):
    if kind == "radial":
        return (f'<radialGradient id="{gid}" cx="38%" cy="30%" r="75%">'
                f'<stop offset="0" stop-color="{shade(c, 0.28)}"/>'
                f'<stop offset="0.55" stop-color="{c}"/>'
                f'<stop offset="1" stop-color="{shade(c, -0.12)}"/></radialGradient>')
    return (f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{shade(c, 0.22)}"/>'
            f'<stop offset="1" stop-color="{shade(c, -0.10)}"/></linearGradient>')


def portrait(name, p):
    """p: dict of appearance params."""
    bg = p.get("bg", "#33b5d6")
    skin = SKIN.get(p.get("skin", "light"), p.get("skin", "#f6cfae"))
    sk_line = shade(skin, -0.35)
    hair = p.get("hair_color", "#6b3e26")
    hair_line = shade(hair, -0.35)
    uni = p.get("uniform", bg)
    uni_line = shade(uni, -0.35)
    o = svg_open()
    o.append("<defs>")
    o.append(grad_defs("bg", bg))
    o.append(grad_defs("skin", skin))
    o.append(grad_defs("hair", hair))
    o.append(grad_defs("uni", uni, "linear"))
    o.append('<clipPath id="clip"><circle cx="128" cy="128" r="122"/></clipPath>')
    o.append("</defs>")
    # background disc with a soft ring
    o.append('<circle cx="128" cy="128" r="126" fill="#ffffff" opacity="0.95"/>')
    o.append('<circle cx="128" cy="128" r="120" fill="url(#bg)"/>')
    o.append(f'<circle cx="128" cy="128" r="120" fill="none" stroke="{shade(bg, -0.25)}" stroke-width="4"/>')
    o.append('<g clip-path="url(#clip)">')
    # sparkle dots in the background
    for (x, y, r) in [(52, 60, 5), (200, 70, 4), (214, 120, 3), (40, 140, 3)]:
        o.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#ffffff" opacity="0.35"/>')
    o.append('<g transform="translate(128 146) scale(1.16) translate(-128 -128)">')
    hs = p.get("hair", "short")
    # hair behind the head (long styles)
    if hs in ("bob", "long"):
        o.append(f'<path d="M66 118 Q62 60 128 50 Q194 60 190 118 L194 196 Q128 214 62 196 Z" fill="url(#hair)" stroke="{hair_line}" stroke-width="4"/>')
    if hs == "pony":
        o.append(f'<path d="M176 92 Q222 104 214 162 Q206 190 188 196 Q200 150 172 120 Z" fill="url(#hair)" stroke="{hair_line}" stroke-width="4"/>')
    # body / uniform
    o.append(f'<path d="M30 262 Q34 206 86 196 L170 196 Q222 206 226 262 Z" fill="url(#uni)" stroke="{uni_line}" stroke-width="4"/>')
    if p.get("cardigan"):
        o.append(f'<path d="M108 198 L128 262 L148 198" fill="none" stroke="{shade(uni, -0.2)}" stroke-width="10"/>')
        for y in (222, 242):
            o.append(f'<circle cx="138" cy="{y}" r="4" fill="#fff6e5"/>')
    else:
        # collar
        collar = p.get("collar", "#ffffff")
        o.append(f'<path d="M98 196 L128 228 L158 196 L146 192 L128 212 L110 192 Z" fill="{collar}" stroke="{shade(collar, -0.3)}" stroke-width="3"/>')
    # badge with emblem colour
    o.append(f'<rect x="150" y="218" width="40" height="24" rx="8" fill="#fff6e5" stroke="{uni_line}" stroke-width="3"/>')
    o.append(f'<rect x="156" y="224" width="12" height="12" rx="4" fill="{bg}"/>')
    o.append(f'<rect x="172" y="226" width="12" height="3" rx="1.5" fill="{uni_line}"/><rect x="172" y="232" width="9" height="3" rx="1.5" fill="{uni_line}"/>')
    if p.get("pudding_shoulder"):
        o.append(pudding_small(64, 200, 26))
    # neck
    o.append(f'<path d="M110 160 L110 200 Q128 210 146 200 L146 160 Z" fill="{shade(skin, -0.08)}" stroke="{sk_line}" stroke-width="3"/>')
    # ears
    for ex in (74, 182):
        o.append(f'<ellipse cx="{ex}" cy="124" rx="11" ry="15" fill="url(#skin)" stroke="{sk_line}" stroke-width="3"/>')
        o.append(f'<ellipse cx="{ex}" cy="124" rx="5" ry="8" fill="{shade(skin, -0.15)}"/>')
    # head: tall rounded
    o.append(f'<path d="M128 46 Q184 46 184 112 Q184 176 128 180 Q72 176 72 112 Q72 46 128 46 Z" fill="url(#skin)" stroke="{sk_line}" stroke-width="4"/>')
    # hair on top
    if hs == "short":
        o.append(f'<path d="M72 104 Q70 44 128 40 Q188 42 184 104 Q176 76 150 70 Q120 82 96 72 Q80 80 72 104 Z" fill="url(#hair)" stroke="{hair_line}" stroke-width="4"/>')
    elif hs == "spiky":
        o.append(f'<path d="M72 100 L64 66 L88 72 L84 40 L108 58 L116 26 L132 54 L150 24 L158 56 L182 40 L176 70 L196 68 L184 102 Q166 76 128 74 Q92 76 72 100 Z" fill="url(#hair)" stroke="{hair_line}" stroke-width="4" stroke-linejoin="round"/>')
    elif hs == "curly":
        for (cx, cy, r) in [(84, 82, 20), (100, 60, 22), (128, 50, 24), (156, 60, 22), (172, 82, 20), (76, 106, 14), (180, 106, 14)]:
            o.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#hair)" stroke="{hair_line}" stroke-width="4"/>')
        o.append(f'<path d="M86 84 Q128 66 170 84 Q160 96 128 92 Q96 96 86 84 Z" fill="url(#hair)"/>')
    elif hs == "bun":
        o.append(f'<circle cx="128" cy="34" r="22" fill="url(#hair)" stroke="{hair_line}" stroke-width="4"/>')
        o.append(f'<path d="M72 106 Q68 48 128 46 Q188 48 184 106 Q170 74 128 70 Q86 74 72 106 Z" fill="url(#hair)" stroke="{hair_line}" stroke-width="4"/>')
    elif hs in ("bob", "long"):
        o.append(f'<path d="M70 120 Q64 44 128 42 Q192 44 186 120 Q176 82 150 74 Q118 92 86 82 Q74 98 70 120 Z" fill="url(#hair)" stroke="{hair_line}" stroke-width="4"/>')
    elif hs == "pony":
        o.append(f'<path d="M72 104 Q70 46 128 42 Q188 44 184 104 Q170 72 128 70 Q88 72 72 104 Z" fill="url(#hair)" stroke="{hair_line}" stroke-width="4"/>')
    elif hs == "mohawk":
        o.append(f'<path d="M112 70 Q110 22 128 14 Q146 22 144 70 Q128 64 112 70 Z" fill="url(#hair)" stroke="{hair_line}" stroke-width="4"/>')
        o.append(f'<path d="M80 92 Q128 70 176 92" fill="none" stroke="{shade(skin, -0.12)}" stroke-width="6" stroke-linecap="round"/>')
    elif hs == "bald":
        o.append('<ellipse cx="108" cy="70" rx="16" ry="8" fill="#ffffff" opacity="0.45"/>')
    elif hs == "grey_bun":
        o.append(f'<circle cx="128" cy="36" r="20" fill="url(#hair)" stroke="{hair_line}" stroke-width="4"/>')
        o.append(f'<path d="M70 112 Q66 46 128 44 Q190 46 186 112 Q172 78 150 76 Q128 84 106 76 Q84 78 70 112 Z" fill="url(#hair)" stroke="{hair_line}" stroke-width="4"/>')
    # eyebrows
    eb = p.get("brows", "happy")
    bc = hair_line if hs != "bald" else shade(skin, -0.45)
    if eb == "angry":
        o.append(f'<path d="M96 96 L120 104" stroke="{bc}" stroke-width="7" stroke-linecap="round"/><path d="M160 96 L136 104" stroke="{bc}" stroke-width="7" stroke-linecap="round"/>')
    elif eb == "worried":
        o.append(f'<path d="M98 104 L120 96" stroke="{bc}" stroke-width="7" stroke-linecap="round"/><path d="M158 104 L136 96" stroke="{bc}" stroke-width="7" stroke-linecap="round"/>')
    elif eb == "raised":
        o.append(f'<path d="M96 96 Q108 86 122 94" fill="none" stroke="{bc}" stroke-width="7" stroke-linecap="round"/><path d="M134 90 Q148 80 160 92" fill="none" stroke="{bc}" stroke-width="7" stroke-linecap="round"/>')
    else:
        o.append(f'<path d="M96 98 Q108 90 122 97" fill="none" stroke="{bc}" stroke-width="7" stroke-linecap="round"/><path d="M134 97 Q148 90 160 98" fill="none" stroke="{bc}" stroke-width="7" stroke-linecap="round"/>')
    # eyes
    big = p.get("big_eyes", False)
    ry = 14 if big else 12
    for exx in (107, 149):
        o.append(f'<ellipse cx="{exx}" cy="116" rx="{11 if not big else 13}" ry="{ry}" fill="#ffffff" stroke="{sk_line}" stroke-width="2.5"/>')
        o.append(f'<circle cx="{exx + 1}" cy="118" r="{6.5 if not big else 7.5}" fill="#24314a"/>')
        o.append(f'<circle cx="{exx - 2}" cy="114" r="2.6" fill="#ffffff"/>')
    if p.get("eyepatch"):
        o.append(f'<path d="M80 98 L176 122" stroke="#24314a" stroke-width="4"/><ellipse cx="146" cy="116" rx="13" ry="12" fill="#24314a"/>')
    # nose (big friendly Two Point nose)
    o.append(f'<path d="M128 112 Q142 136 138 144 Q132 152 122 148 Q114 144 120 132 Z" fill="{shade(skin, -0.06)}" stroke="{sk_line}" stroke-width="3" stroke-linejoin="round"/>')
    o.append(f'<ellipse cx="124" cy="136" rx="3" ry="5" fill="#ffffff" opacity="0.4"/>')
    # cheeks
    o.append('<ellipse cx="94" cy="142" rx="11" ry="7" fill="#ff7f8a" opacity="0.28"/><ellipse cx="162" cy="142" rx="11" ry="7" fill="#ff7f8a" opacity="0.28"/>')
    # moustache / beard
    if p.get("moustache"):
        mc = p.get("moustache_color", hair)
        o.append(f'<path d="M100 156 Q114 144 128 152 Q142 144 156 156 Q142 162 128 158 Q114 162 100 156 Z" fill="{mc}" stroke="{shade(mc, -0.35)}" stroke-width="3"/>')
    # mouth
    m = p.get("mouth", "smile")
    ml = shade(skin, -0.5)
    if m == "grin":
        o.append(f'<path d="M106 156 Q128 178 150 156 Z" fill="#7a2b34" stroke="{ml}" stroke-width="3" stroke-linejoin="round"/>')
        o.append('<path d="M110 158 L146 158 L144 163 L112 163 Z" fill="#ffffff"/>')
    elif m == "flat":
        o.append(f'<path d="M112 162 L144 162" stroke="{ml}" stroke-width="5" stroke-linecap="round"/>')
    elif m == "worried":
        o.append(f'<path d="M110 166 Q128 154 146 166" fill="none" stroke="{ml}" stroke-width="5" stroke-linecap="round"/>')
    elif m == "smirk":
        o.append(f'<path d="M110 160 Q130 168 148 154" fill="none" stroke="{ml}" stroke-width="5" stroke-linecap="round"/>')
    elif m == "shout":
        o.append(f'<ellipse cx="128" cy="164" rx="14" ry="10" fill="#7a2b34" stroke="{ml}" stroke-width="3"/>')
    else:
        o.append(f'<path d="M104 154 Q128 178 152 154 Q128 166 104 154 Z" fill="#7a2b34" stroke="{ml}" stroke-width="4" stroke-linejoin="round"/>')
    if p.get("smudge"):
        o.append('<ellipse cx="160" cy="150" rx="8" ry="4" fill="#3b3b3b" opacity="0.35"/>')
    if p.get("sweat"):
        o.append('<path d="M176 86 Q184 100 176 106 Q168 100 176 86 Z" fill="#8fd3f4" stroke="#4a9cc4" stroke-width="2"/>')
    # accessories
    acc = p.get("acc", "")
    if acc == "captain_hat":
        o.append('<path d="M66 82 Q66 34 128 30 Q190 34 190 82 Z" fill="#33407e" stroke="#1f2752" stroke-width="4"/>')
        o.append('<rect x="64" y="72" width="128" height="16" rx="6" fill="#f5c84a" stroke="#b48a1e" stroke-width="3"/>')
        o.append('<path d="M60 86 Q128 110 196 86 L196 92 Q128 118 60 92 Z" fill="#1f2752"/>')
        o.append('<circle cx="128" cy="56" r="10" fill="#f5c84a" stroke="#b48a1e" stroke-width="3"/>')
    elif acc == "headset":
        o.append('<path d="M70 110 Q70 36 128 34 Q186 36 186 110" fill="none" stroke="#2b3450" stroke-width="9" stroke-linecap="round"/>')
        o.append('<rect x="60" y="102" width="20" height="34" rx="9" fill="#2b3450"/><rect x="176" y="102" width="20" height="34" rx="9" fill="#2b3450"/>')
        o.append('<path d="M70 132 Q76 160 104 162" fill="none" stroke="#2b3450" stroke-width="5" stroke-linecap="round"/><circle cx="106" cy="162" r="6" fill="#ee5b5b"/>')
    elif acc == "goggles":
        o.append('<path d="M70 86 Q128 72 186 86" stroke="#6b4a2e" stroke-width="9" fill="none"/>')
        for gx in (106, 150):
            o.append(f'<circle cx="{gx}" cy="80" r="16" fill="#8fd3f4" stroke="#6b4a2e" stroke-width="6"/><circle cx="{gx - 5}" cy="75" r="4" fill="#ffffff" opacity="0.8"/>')
    elif acc == "glasses":
        for gx in (110, 146):
            o.append(f'<circle cx="{gx}" cy="116" r="16" fill="#ffffff" fill-opacity="0.15" stroke="#24314a" stroke-width="5"/>')
        o.append('<path d="M126 114 L130 114" stroke="#24314a" stroke-width="5"/>')
    elif acc == "antenna":
        o.append('<path d="M74 92 Q128 60 182 92" stroke="#24314a" stroke-width="6" fill="none"/>')
        o.append('<path d="M100 74 L86 36" stroke="#24314a" stroke-width="4"/><circle cx="86" cy="34" r="8" fill="#4cc9a0" stroke="#2c8a6a" stroke-width="3"/>')
        o.append('<path d="M156 74 L170 36" stroke="#24314a" stroke-width="4"/><circle cx="170" cy="34" r="8" fill="#ee5b5b" stroke="#a83b3b" stroke-width="3"/>')
    elif acc == "bandana":
        o.append('<path d="M70 92 Q128 60 186 92 L186 104 Q128 78 70 104 Z" fill="#ee5b5b" stroke="#a83b3b" stroke-width="3"/>')
        o.append('<path d="M180 96 L204 88 L198 108 Z" fill="#ee5b5b" stroke="#a83b3b" stroke-width="3"/>')
        for dx in (96, 120, 144, 168):
            o.append(f'<circle cx="{dx}" cy="{88 - (12 if 100 < dx < 160 else 4)}" r="3" fill="#ffffff"/>')
    elif acc == "hardhat":
        o.append('<path d="M66 92 Q64 36 128 34 Q192 36 190 92 Z" fill="#f5c84a" stroke="#b48a1e" stroke-width="4"/>')
        o.append('<rect x="56" y="86" width="144" height="12" rx="6" fill="#e0a83a" stroke="#b48a1e" stroke-width="3"/>')
        o.append('<rect x="120" y="40" width="16" height="48" rx="6" fill="#ffe08a"/>')
    elif acc == "hairnet":
        o.append('<path d="M70 104 Q66 40 128 38 Q190 40 186 104" fill="#ffffff" fill-opacity="0.25" stroke="#ffffff" stroke-width="3"/>')
        for i in range(6):
            x = 84 + i * 18
            o.append(f'<path d="M{x} 48 Q{x + 6} 76 {x + 2} 100" stroke="#ffffff" stroke-opacity="0.6" stroke-width="2" fill="none"/>')
    elif acc == "officer_cap":
        o.append('<path d="M64 86 Q60 40 128 34 Q196 40 192 86 Z" fill="#4a4e5a" stroke="#2c2f38" stroke-width="4"/>')
        o.append('<rect x="62" y="76" width="132" height="14" rx="6" fill="#cfa13a" stroke="#8f6c1d" stroke-width="3"/>')
        o.append('<path d="M60 88 Q128 112 196 88 L196 96 Q128 120 60 96 Z" fill="#2c2f38"/>')
        o.append('<path d="M118 50 L128 40 L138 50 L128 60 Z" fill="#c2367a" stroke="#7d1f4d" stroke-width="2"/>')
    elif acc == "crown":
        o.append('<path d="M74 78 L80 30 L102 58 L128 20 L154 58 L176 30 L182 78 Z" fill="#f5c84a" stroke="#b48a1e" stroke-width="4" stroke-linejoin="round"/>')
        for (cx, c) in [(100, "#c2367a"), (128, "#33b5d6"), (156, "#c2367a")]:
            o.append(f'<circle cx="{cx}" cy="66" r="6" fill="{c}" stroke="#ffffff" stroke-width="2"/>')
    o.append("</g></g>")
    o.append("</svg>")
    with open(os.path.join(OUT, f"portrait_{name}.svg"), "w") as fh:
        fh.write("\n".join(o))


def pudding_small(cx, cy, r):
    s = []
    for i in range(10):
        a = i / 10 * math.tau
        s.append(f'<circle cx="{cx + math.cos(a) * r * 0.85:.1f}" cy="{cy + math.sin(a) * r * 0.85:.1f}" r="{r * 0.32:.1f}" fill="#ff9fc2" stroke="#d4668e" stroke-width="2"/>')
    s.append(f'<circle cx="{cx}" cy="{cy}" r="{r * 0.9:.1f}" fill="#ff9fc2"/>')
    for ex in (-0.32, 0.32):
        s.append(f'<circle cx="{cx + ex * r:.1f}" cy="{cy - 0.1 * r:.1f}" r="{r * 0.2:.1f}" fill="#ffffff"/><circle cx="{cx + ex * r + 1:.1f}" cy="{cy - 0.06 * r:.1f}" r="{r * 0.1:.1f}" fill="#24314a"/>')
    s.append(f'<path d="M{cx - 0.2 * r:.1f} {cy + 0.3 * r:.1f} Q{cx} {cy + 0.45 * r:.1f} {cx + 0.2 * r:.1f} {cy + 0.3 * r:.1f}" stroke="#24314a" stroke-width="2.5" fill="none" stroke-linecap="round"/>')
    return "\n".join(s)


def robot_portrait():
    o = svg_open()
    o.append("<defs>")
    o.append(grad_defs("bg", "#2c8a6a"))
    o.append(grad_defs("metal", "#8a93a6"))
    o.append(grad_defs("eye", "#f58b3c"))
    o.append('<clipPath id="clip"><circle cx="128" cy="128" r="122"/></clipPath></defs>')
    o.append('<circle cx="128" cy="128" r="126" fill="#ffffff" opacity="0.95"/><circle cx="128" cy="128" r="120" fill="url(#bg)"/>')
    o.append('<circle cx="128" cy="128" r="120" fill="none" stroke="#1d5c47" stroke-width="4"/>')
    o.append('<g clip-path="url(#clip)">')
    o.append('<path d="M40 262 Q46 210 90 200 L166 200 Q210 210 216 262 Z" fill="#5f6779" stroke="#3b4150" stroke-width="4"/>')
    o.append('<rect x="112" y="176" width="32" height="30" rx="6" fill="#5f6779" stroke="#3b4150" stroke-width="4"/>')
    o.append('<path d="M128 36 L128 14" stroke="#3b4150" stroke-width="6"/><circle cx="128" cy="12" r="9" fill="#ee5b5b" stroke="#a83b3b" stroke-width="3"/>')
    o.append('<rect x="58" y="36" width="140" height="146" rx="34" fill="url(#metal)" stroke="#3b4150" stroke-width="5"/>')
    for i in range(5):
        o.append(f'<rect x="82" y="{140 + i * 8}" width="92" height="4" rx="2" fill="#3b4150" opacity="0.65"/>')
    o.append('<circle cx="128" cy="96" r="38" fill="#3b4150"/><circle cx="128" cy="96" r="30" fill="url(#eye)"/>')
    o.append('<circle cx="128" cy="96" r="12" fill="#24314a"/><circle cx="120" cy="88" r="6" fill="#ffffff" opacity="0.85"/>')
    o.append('<path d="M86 60 L170 60" stroke="#3b4150" stroke-width="7" stroke-linecap="round" opacity="0.6"/>')
    for (x, y) in [(70, 48), (186, 48), (70, 170), (186, 170)]:
        o.append(f'<circle cx="{x}" cy="{y}" r="4" fill="#3b4150"/>')
    o.append("</g></svg>")
    with open(os.path.join(OUT, "portrait_igor.svg"), "w") as fh:
        fh.write("\n".join(o))


def pudding_portrait():
    o = svg_open()
    o.append("<defs>")
    o.append(grad_defs("bg", "#9b86e0"))
    o.append('<clipPath id="clip"><circle cx="128" cy="128" r="122"/></clipPath></defs>')
    o.append('<circle cx="128" cy="128" r="126" fill="#ffffff" opacity="0.95"/><circle cx="128" cy="128" r="120" fill="url(#bg)"/>')
    o.append('<g clip-path="url(#clip)">')
    o.append(pudding_small(128, 140, 78))
    o.append('<ellipse cx="96" cy="176" rx="12" ry="6" fill="#ff7f8a" opacity="0.5"/><ellipse cx="160" cy="176" rx="12" ry="6" fill="#ff7f8a" opacity="0.5"/>')
    o.append("</g></svg>")
    with open(os.path.join(OUT, "portrait_pudding.svg"), "w") as fh:
        fh.write("\n".join(o))


# ---------------------------------------------------------------- icons (white silhouettes, tinted in-game)

def icon(name, body):
    with open(os.path.join(OUT, f"icon_{name}.svg"), "w") as fh:
        fh.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{body}</svg>')


W = 'fill="#ffffff"'
S = 'fill="none" stroke="#ffffff" stroke-linecap="round" stroke-linejoin="round"'

ICONS = {
    "captain": f'<path d="M8 30 Q8 10 32 8 Q56 10 56 30 Z" {W}/><rect x="6" y="28" width="52" height="8" rx="3" {W}/><path d="M6 38 Q32 52 58 38 L58 42 Q32 58 6 42 Z" {W}/>',
    "helm": f'<circle cx="32" cy="32" r="17" {S} stroke-width="6"/><circle cx="32" cy="32" r="5" {W}/>' + "".join(
        f'<path d="M{32 + math.cos(a) * 6:.1f} {32 + math.sin(a) * 6:.1f} L{32 + math.cos(a) * 28:.1f} {32 + math.sin(a) * 28:.1f}" {S} stroke-width="5"/>' for a in [i * math.tau / 8 for i in range(8)]),
    "engines": f'<path d="M32 4 Q46 20 44 34 Q52 30 52 22 Q60 36 54 48 Q46 62 32 62 Q16 62 10 48 Q6 36 14 26 Q14 36 20 38 Q16 20 32 4 Z" {W}/>',
    "power": f'<path d="M36 2 L12 36 L28 36 L22 62 L52 24 L34 24 L42 2 Z" {W}/>',
    "weapons": f'<circle cx="32" cy="32" r="20" {S} stroke-width="6"/><circle cx="32" cy="32" r="5" {W}/><path d="M32 2 L32 16 M32 48 L32 62 M2 32 L16 32 M48 32 L62 32" {S} stroke-width="6"/>',
    "sensors": f'<path d="M10 54 Q10 22 42 22" {S} stroke-width="0"/><path d="M14 50 L34 30" {S} stroke-width="6"/><path d="M8 56 Q4 30 28 20 Q20 44 44 52 Q24 64 8 56 Z" {W}/><path d="M38 14 Q50 14 50 26 M38 4 Q60 4 60 26" {S} stroke-width="5"/>',
    "ops": f'<path d="M32 4 L56 12 Q58 42 32 60 Q6 42 8 12 Z" {W}/>',
    "dc": f'<path d="M44 4 Q58 6 60 20 L50 22 L44 16 L40 22 L46 30 Q36 34 30 28 L10 50 Q6 56 12 58 Q16 60 20 54 L38 34 Q34 26 40 20" {S} stroke-width="0"/><path d="M42 6 Q30 10 34 24 L8 50 Q6 58 14 58 L40 32 Q54 36 58 22 L48 26 L40 22 L38 12 Z" {W}/>',
    "hull": f'<path d="M32 58 Q4 38 6 20 Q8 6 22 6 Q30 6 32 14 Q34 6 42 6 Q56 6 58 20 Q60 38 32 58 Z" {W}/>',
    "fuel": f'<path d="M14 18 L26 6 L50 6 Q56 6 56 12 L56 56 Q56 60 52 60 L16 60 Q12 60 12 56 L12 22 Z" {W}/><rect x="4" y="8" width="12" height="8" rx="3" {W} transform="rotate(-40 10 12)"/><path d="M24 26 L44 46 M44 26 L24 46" stroke="#24314a" stroke-width="5" stroke-linecap="round"/>',
    "scrap": f'<circle cx="32" cy="32" r="13" {S} stroke-width="8"/>' + "".join(
        f'<rect x="28" y="2" width="8" height="12" rx="2" {W} transform="rotate({i * 45} 32 32)"/>' for i in range(8)),
    "temper": f'<circle cx="32" cy="34" r="24" {W}/><path d="M18 26 L28 30 M46 26 L36 30" stroke="#24314a" stroke-width="5" stroke-linecap="round"/><path d="M22 48 Q32 40 42 48" stroke="#24314a" stroke-width="5" fill="none" stroke-linecap="round"/><path d="M12 14 L18 4 L26 12 L32 2 L38 12 L46 4 L52 14 Z" {W}/>',
    "pudding": "".join(f'<circle cx="{32 + math.cos(i / 9 * math.tau) * 20:.1f}" cy="{34 + math.sin(i / 9 * math.tau) * 20:.1f}" r="8" {W}/>' for i in range(9)) + f'<circle cx="32" cy="34" r="20" {W}/><circle cx="25" cy="31" r="4" fill="#24314a"/><circle cx="39" cy="31" r="4" fill="#24314a"/>',
    "check": f'<path d="M10 34 L26 50 L56 14" {S} stroke-width="10"/>',
    "star": f'<path d="M32 4 L40 24 L62 24 L44 38 L50 60 L32 46 L14 60 L20 38 L2 24 L24 24 Z" {W}/>',
    "menu": f'<path d="M10 16 L54 16 M10 32 L54 32 M10 48 L54 48" {S} stroke-width="8"/>',
    "play": f'<path d="M18 8 L56 32 L18 56 Z" {W}/>',
    "crew": f'<circle cx="22" cy="22" r="10" {W}/><circle cx="44" cy="20" r="9" {W}/><path d="M4 56 Q6 36 22 36 Q38 36 40 56 Z" {W}/><path d="M38 34 Q56 32 60 52 L42 52 Q42 40 38 34 Z" {W}/>',
    "map": f'<path d="M32 60 Q12 36 12 24 Q12 4 32 4 Q52 4 52 24 Q52 36 32 60 Z" {W}/><circle cx="32" cy="24" r="8" fill="#24314a"/>',
    "warning": f'<path d="M32 4 L62 58 L2 58 Z" {W}/><path d="M32 22 L32 40" stroke="#24314a" stroke-width="7" stroke-linecap="round"/><circle cx="32" cy="50" r="4" fill="#24314a"/>',
    "fire": f'<path d="M32 2 Q50 22 46 36 Q56 30 54 20 Q64 40 54 52 Q46 62 32 62 Q16 62 10 50 Q4 36 16 26 Q14 38 22 42 Q18 22 32 2 Z" {W}/>',
    "clock": f'<circle cx="32" cy="32" r="24" {S} stroke-width="7"/><path d="M32 18 L32 32 L42 40" {S} stroke-width="6"/>',
    "lock": f'<rect x="12" y="28" width="40" height="30" rx="8" {W}/><path d="M20 28 L20 20 Q20 6 32 6 Q44 6 44 20 L44 28" {S} stroke-width="7"/>',
    "robot": f'<rect x="10" y="14" width="44" height="40" rx="12" {W}/><circle cx="32" cy="32" r="10" fill="#24314a"/><path d="M32 14 L32 4" {S} stroke-width="5"/><circle cx="32" cy="4" r="4" {W}/>',
    "x": f'<path d="M14 14 L50 50 M50 14 L14 50" {S} stroke-width="10"/>',
    "share": f'<rect x="6" y="12" width="40" height="30" rx="6" {W}/><path d="M38 44 L58 30 L58 58 Z" {W}/>',
    "back": f'<path d="M40 8 L16 32 L40 56" {S} stroke-width="10"/>',
}

PERSONAS = {
    "captain": {"bg": "#4b5bbd", "skin": "medium", "hair": "bob", "hair_color": "#5a3622", "uniform": "#33407e", "acc": "captain_hat", "brows": "raised", "mouth": "smirk"},
    "helm": {"bg": "#33b5d6", "skin": "light", "hair": "short", "hair_color": "#d9692b", "uniform": "#2a8fab", "acc": "headset", "mouth": "grin"},
    "engines": {"bg": "#f58b3c", "skin": "dark", "hair": "curly", "hair_color": "#2a1d17", "uniform": "#c86a26", "acc": "goggles", "mouth": "smirk", "smudge": True},
    "power": {"bg": "#f5c84a", "skin": "pale", "hair": "spiky", "hair_color": "#f0e070", "uniform": "#c99a22", "brows": "worried", "mouth": "worried", "big_eyes": True},
    "weapons": {"bg": "#ee5b5b", "skin": "tan", "hair": "mohawk", "hair_color": "#7a2fb8", "uniform": "#b8403f", "acc": "bandana", "mouth": "grin", "brows": "angry"},
    "sensors": {"bg": "#4cc9a0", "skin": "light", "hair": "bald", "hair_color": "#5a3622", "uniform": "#2f9c79", "acc": "antenna", "mouth": "flat", "big_eyes": True},
    "ops": {"bg": "#9b86e0", "skin": "medium", "hair": "grey_bun", "hair_color": "#c9c6d6", "uniform": "#7a64c4", "cardigan": True, "mouth": "smile", "pudding_shoulder": True},
    "dc": {"bg": "#e0a83a", "skin": "deep", "hair": "short", "hair_color": "#1e1612", "uniform": "#b07f22", "acc": "hardhat", "mouth": "grin", "moustache": True},
    "thrupp": {"bg": "#4a4e5a", "skin": "pale", "hair": "short", "hair_color": "#8a7a6a", "uniform": "#3b3f4a", "acc": "officer_cap", "brows": "worried", "mouth": "worried", "moustache": True, "moustache_color": "#8a7a6a", "sweat": True, "collar": "#cfa13a"},
    "overlord": {"bg": "#c2367a", "skin": "light", "hair": "short", "hair_color": "#3a2a1a", "uniform": "#7d1f4d", "acc": "crown", "brows": "angry", "mouth": "shout", "moustache": True, "moustache_color": "#3a2a1a", "collar": "#f5c84a"},
    "gristle": {"bg": "#ff8fb8", "skin": "medium", "hair": "bob", "hair_color": "#b04b2a", "uniform": "#f1e2c2", "acc": "hairnet", "mouth": "grin", "collar": "#ff8fb8"},
}

def ship_art():
    """The Second Opinion: a garbage hauler with ideas above its station. 512x320."""
    o = ['<svg xmlns="http://www.w3.org/2000/svg" width="512" height="320" viewBox="0 0 512 320">', "<defs>"]
    o.append(grad_defs("hull", "#f5883a", "linear"))
    o.append(grad_defs("cab", "#3fc197", "linear"))
    o.append(grad_defs("glass", "#8fd3f4", "linear"))
    o.append(grad_defs("bin", "#5f6779", "linear"))
    o.append('<radialGradient id="flame" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#fff6c8"/><stop offset="0.5" stop-color="#ffd23f"/><stop offset="1" stop-color="#f5883a" stop-opacity="0"/></radialGradient>')
    o.append("</defs>")
    # engine flames
    for y in (176, 236):
        o.append(f'<ellipse cx="44" cy="{y}" rx="44" ry="20" fill="url(#flame)"/>')
    # engine pods
    for y in (176, 236):
        o.append(f'<rect x="54" y="{y - 22}" width="70" height="44" rx="20" fill="#5f6779" stroke="#3b4150" stroke-width="5"/>')
        o.append(f'<rect x="62" y="{y - 14}" width="20" height="28" rx="8" fill="#ffd23f"/>')
    # main body
    o.append('<path d="M100 120 Q100 96 126 96 L340 96 Q372 96 380 126 L392 250 Q394 272 370 272 L126 272 Q100 272 100 248 Z" fill="url(#hull)" stroke="#b5591d" stroke-width="6"/>')
    # stripe and number
    o.append('<rect x="104" y="196" width="282" height="22" fill="#ffd23f" opacity="0.9"/>')
    o.append('<circle cx="170" cy="160" r="30" fill="#fffaf0" stroke="#b5591d" stroke-width="5"/>')
    o.append('<path d="M156 146 L186 146 L166 180" fill="none" stroke="#263150" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>')
    # rivets
    for x in range(120, 380, 26):
        o.append(f'<circle cx="{x}" cy="112" r="3.5" fill="#b5591d"/><circle cx="{x}" cy="258" r="3.5" fill="#b5591d"/>')
    # bins on top
    for i, x in enumerate((140, 206, 272)):
        o.append(f'<rect x="{x}" y="58" width="52" height="40" rx="8" fill="url(#bin)" stroke="#3b4150" stroke-width="4"/>')
        o.append(f'<rect x="{x - 4}" y="50" width="60" height="12" rx="5" fill="#{["3fc197", "f2be33", "9a84e0"][i]}" stroke="#3b4150" stroke-width="3"/>')
    # cab with big window
    o.append('<path d="M330 104 Q336 70 380 70 L430 70 Q470 70 476 120 L482 200 Q484 226 458 226 L360 226 Q332 226 332 200 Z" fill="url(#cab)" stroke="#2a8a6a" stroke-width="6"/>')
    o.append('<path d="M366 92 L428 92 Q452 92 456 124 L458 156 L360 156 L358 116 Q358 92 366 92 Z" fill="url(#glass)" stroke="#2a8a6a" stroke-width="5"/>')
    o.append('<path d="M376 100 L396 100 L376 140 Z" fill="#ffffff" opacity="0.6"/>')
    # Pudding peeking out of the window
    o.append(pudding_small(420, 140, 22))
    # headlight + antenna with a flag
    o.append('<circle cx="472" cy="196" r="12" fill="#fff6c8" stroke="#2a8a6a" stroke-width="4"/>')
    o.append('<path d="M410 70 L414 22" stroke="#3b4150" stroke-width="5" stroke-linecap="round"/><path d="M414 22 L452 32 L414 44 Z" fill="#ec5a5a" stroke="#a83b3b" stroke-width="3"/>')
    # stubby wings / landing feet
    o.append('<path d="M150 272 L132 304 L198 304 L214 272 Z" fill="#5f6779" stroke="#3b4150" stroke-width="5"/>')
    o.append('<path d="M290 272 L276 304 L342 304 L354 272 Z" fill="#5f6779" stroke="#3b4150" stroke-width="5"/>')
    o.append("</svg>")
    with open(os.path.join(OUT, "art_ship.svg"), "w") as fh:
        fh.write("\n".join(o))


if __name__ == "__main__":
    ship_art()
    for k, v in PERSONAS.items():
        portrait(k, v)
    robot_portrait()
    pudding_portrait()
    for k, v in ICONS.items():
        icon(k, v)
    print("wrote", len(PERSONAS) + 2, "portraits and", len(ICONS), "icons to", os.path.abspath(OUT))
