"""Painted UI textures for Legend of Lion Turtle ("Scroll & Ink").

Generates every UI texture as a PNG in project/assets/ui/paint/. The result
is deterministic (fixed seeds). Run from the repo root:
    python3 tools/paint/gen_textures.py
Needs numpy, scipy and Pillow.
"""
import os, math
import numpy as np
from scipy import ndimage as ndi
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "project", "assets", "ui", "paint")
os.makedirs(OUT, exist_ok=True)

def hexc(h):
    h = h.lstrip("#"); return np.array([int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4)])

def save(name, rgb, a=None):
    rgb = np.clip(rgb, 0, 1)
    if a is None:
        img = Image.fromarray((rgb * 255 + 0.5).astype(np.uint8), "RGB")
    else:
        if rgb.ndim == 2:
            rgb = np.repeat(rgb[..., None], 3, axis=2)
        arr = np.dstack([rgb, np.clip(a, 0, 1)[..., None]])
        img = Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA")
    img.save(os.path.join(OUT, name), optimize=True)
    print("wrote", name, img.size)

def fbm(h, w, rng, scales=(64, 32, 16, 8, 4), weights=None, wrap=False, aniso=(1.0, 1.0)):
    out = np.zeros((h, w))
    weights = weights or [1.0 / (i + 1) for i in range(len(scales))]
    mode = "wrap" if wrap else "reflect"
    for s, wt in zip(scales, weights):
        n = rng.standard_normal((h, w))
        n = ndi.gaussian_filter(n, (s * aniso[0], s * aniso[1]), mode=mode)
        n /= (n.std() + 1e-9)
        out += n * wt
    out /= sum(weights)
    return out

def norm01(x):
    return (x - x.min()) / (x.max() - x.min() + 1e-9)

def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)

# ---------------------------------------------------------------- paper grain (tile, near-white)
def paper_grain(size=512, seed=1):
    rng = np.random.default_rng(seed)
    mott = fbm(size, size, rng, (48, 20, 8), wrap=True)
    fib_h = fbm(size, size, rng, (1.2,), wrap=True, aniso=(1, 9))
    fib_v = fbm(size, size, rng, (1.2,), wrap=True, aniso=(9, 1))
    fine = rng.standard_normal((size, size))
    fine = ndi.gaussian_filter(fine, 0.6, mode="wrap")
    v = 0.93 + mott * 0.025 + fine * 0.018 - np.clip(fib_h, 1.6, 9) * 0.02 + np.clip(fib_v, 1.8, 9) * 0.012
    # occasional dark specks
    speck = (rng.random((size, size)) > 0.99985).astype(float)
    speck = ndi.gaussian_filter(speck, 0.8, mode="wrap") * 6
    v = v - np.clip(speck, 0, 0.25)
    rgb = np.dstack([v * 1.0, v * 0.992, v * 0.975])
    return np.clip(rgb, 0, 1)

# ---------------------------------------------------------------- parchment panel (9-slice)
def parchment(w=512, h=512, seed=3, margin=40):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    d = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    tear = fbm(h, w, rng, (6, 3, 1.5), weights=[1, 0.6, 0.35]) * 4.0
    inside = d - 9.0 + tear
    alpha = smooth(-0.8, 1.2, inside)
    base = hexc("f3e3ba"); light = hexc("fbf1d4"); edge = hexc("a77c43"); char = hexc("5b3a1d")
    mott = fbm(h, w, rng, (90, 40, 14), weights=[1, 0.7, 0.4])
    stains = np.clip(fbm(h, w, rng, (60, 25)) - 1.1, 0, 2) * 0.5
    t = np.clip(0.45 + mott * 0.18, 0, 1)[..., None]
    rgb = base * (1 - t) + light * t
    rgb = rgb - stains[..., None] * (base - hexc("d8b97c"))
    burn = np.clip(1.0 - inside / 26.0, 0, 1) ** 1.6
    rgb = rgb * (1 - burn[..., None] * 0.85) + edge * burn[..., None] * 0.85
    charm = np.clip(1.0 - inside / 4.0, 0, 1) ** 2
    rgb = rgb * (1 - charm[..., None] * 0.7) + char * charm[..., None] * 0.7
    grain = paper_grain(512, seed + 10)[:h, :w]
    rgb = rgb * (0.55 + 0.45 * grain / grain.mean())
    return rgb, alpha

# ---------------------------------------------------------------- dry-brush stroke (white, alpha = paint)
def brush_stroke(w=1024, h=160, seed=4, bristles=90, dry=1.0, body_h=0.78):
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w))
    x = np.arange(w, dtype=float)
    t = x / (w - 1)
    # envelope: blunt pressed start, full body, flicked dry tail
    env = np.clip(np.minimum(t / 0.05, (1 - t) / 0.22), 0, 1) ** 0.5
    env = 0.35 + 0.65 * env
    cap = np.clip(t / 0.045, 0, 1)
    env = env * np.sqrt(1 - (1 - cap) ** 2)          # rounded, pressed start
    wob = ndi.gaussian_filter1d(rng.standard_normal(w), 40) * 30
    cy = h / 2 + wob - (t - 0.5) * h * 0.06
    half = h * body_h / 2 * env
    for i in range(bristles):
        off = (i + rng.random()) / bristles * 2 - 1           # -1..1 across the brush
        jitter = ndi.gaussian_filter1d(rng.standard_normal(w), 25) * 6
        y = cy + off * half + jitter * env
        load = rng.uniform(0.9, 1.35) - abs(off) ** 3 * 0.35
        decay = rng.uniform(0.15, 0.6) * dry
        ink = load - t * decay * 1.2
        ink += ndi.gaussian_filter1d(rng.standard_normal(w), rng.uniform(8, 20)) * 0.22 * dry
        # each bristle runs dry at its own point: long streaks that thin out and stop
        t_end = 1.0 - abs(rng.normal(0, 0.16)) * dry - abs(off) ** 2 * 0.18 * dry
        ink *= smooth(t_end, t_end - 0.05 - 0.1 * rng.random(), t)
        # a few long skips where the bristle lifts off the paper
        gaps = ndi.gaussian_filter1d(rng.standard_normal(w), rng.uniform(18, 40) * w / 1024 + 3)
        gaps /= gaps.std() + 1e-9
        ink = np.where(gaps < -2.2 + t * 1.4 * dry, ink * 0.15, ink)
        ink = np.where(t < 0.015, ink * smooth(0.0, 0.015, t), ink)
        ink = np.clip(ink, 0, 1.2)
        y0 = np.floor(y).astype(int); fr = y - y0
        ok = (y0 >= 0) & (y0 < h - 1)
        np.add.at(acc, (y0[ok], np.arange(w)[ok]), ink[ok] * (1 - fr[ok]) * 1.6)
        np.add.at(acc, (y0[ok] + 1, np.arange(w)[ok]), ink[ok] * fr[ok] * 1.6)
    acc = ndi.gaussian_filter(acc, (h / bristles * 1.1, 1.6))
    a = 1 - np.exp(-acc * 2.4)
    a *= 0.86 + 0.14 * norm01(fbm(h, w, rng, (2, 1)))
    # slight darker pooling at the start of the stroke (pigment)
    return np.clip(a, 0, 1)

# ---------------------------------------------------------------- sky
def sky(w=1920, h=1080, seed=5):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    v = yy / h
    top = hexc("e9a531"); upper = hexc("f6cf62"); mid = hexc("fbe7a0"); low = hexc("f2b54a")
    def lerp(a, b, t): return a * (1 - t[..., None]) + b * t[..., None]
    rgb = lerp(top, upper, smooth(0.0, 0.35, v))
    rgb = lerp(rgb, mid, smooth(0.35, 0.62, v))
    rgb = lerp(rgb, low, smooth(0.66, 1.0, v))
    # long horizontal brush streaks (dry-brushed sky)
    streak = fbm(h, w, rng, (9, 4, 2), weights=[1, 0.5, 0.25], aniso=(1, 45))
    rgb = rgb * (1 + streak[..., None] * 0.022)
    # painted cloud banks: warmer, darker masses near the top, light wisps lower
    cloud = fbm(h, w, rng, (40, 20, 9), weights=[1, 0.6, 0.3], aniso=(1, 5))
    dark = smooth(0.35, 1.6, cloud) * smooth(0.55, 0.0, v)
    rgb = rgb * (1 - dark[..., None] * 0.42) + hexc("b8651f") * dark[..., None] * 0.42
    wisps = smooth(0.6, 1.8, fbm(h, w, rng, (10, 5), aniso=(1, 10))) * smooth(0.15, 0.4, v) * smooth(0.8, 0.5, v)
    rgb = rgb * (1 - wisps[..., None] * 0.5) + hexc("fff6d6") * wisps[..., None] * 0.5
    # dry-brush marks: short horizontal strokes, lighter and darker
    for i in range(70):
        sw = int(rng.uniform(160, 520)); sh = int(rng.uniform(10, 26))
        st = brush_stroke(sw, sh, seed=int(rng.integers(1e6)), bristles=14, dry=1.4, body_h=0.9)
        x0 = int(rng.uniform(-100, w - 100)); y0 = int(rng.uniform(0, h * 0.85))
        col = hexc("fff4cf") if rng.random() < 0.6 else hexc("d98a2b")
        k = rng.uniform(0.08, 0.22)
        xs = slice(max(0, x0), min(w, x0 + sw)); ys = slice(max(0, y0), min(h, y0 + sh))
        sub = st[ys.start - y0: ys.stop - y0, xs.start - x0: xs.stop - x0][..., None] * k
        rgb[ys, xs] = rgb[ys, xs] * (1 - sub) + col * sub
    grain = paper_grain(512, 9)
    reps = (math.ceil(h / 512), math.ceil(w / 512), 1)
    g = np.tile(grain, reps)[:h, :w]
    rgb = rgb * (0.86 + 0.14 * g / g.mean())
    # vignette
    r = np.sqrt(((xx / w - 0.5) * 1.2) ** 2 + ((yy / h - 0.5)) ** 2)
    vig = smooth(0.45, 0.95, r)
    rgb = rgb * (1 - vig[..., None] * 0.28) + hexc("8a4a17") * vig[..., None] * 0.12
    return rgb

# ---------------------------------------------------------------- sun with brushed rings (white, alpha)
def sun(size=1024, seed=6, disc=150):
    rng = np.random.default_rng(seed)
    c = size / 2
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    dx, dy = xx - c, yy - c
    r = np.sqrt(dx * dx + dy * dy); th = np.arctan2(dy, dx)
    a = np.zeros((size, size))
    # glow
    a = np.maximum(a, np.exp(-((r / (disc * 1.25)) ** 2)) * 0.85)
    a = np.maximum(a, np.exp(-((r / (disc * 2.6)) ** 2)) * 0.35)
    # rings: dry brushed concentric strokes with breaks
    pol = fbm(256, 1024, rng, (1.2, 0.7), aniso=(1, 30), wrap=True)   # (radius, angle) noise
    gaps = fbm(64, 512, rng, (3,), aniso=(1, 6), wrap=True)
    ring_a = np.zeros_like(a)
    rings = [(1.3, 26, 0.8), (1.68, 34, 0.7), (2.15, 20, 0.55), (2.7, 40, 0.5), (3.15, 14, 0.38)]
    ti = ((th + math.pi) / (2 * math.pi) * 1023).astype(int) % 1024
    for k, (rr, wd, op) in enumerate(rings):
        rad = disc * rr
        wob = 6 * np.sin(th * 3 + k) + 4 * np.sin(th * 7 + k * 2)
        band = np.clip(1 - np.abs(r - rad - wob) / (wd / 2), 0, 1) ** 0.6
        ri = np.clip(((r - rad) / wd * 0.5 + 0.5) * 255, 0, 255).astype(int)
        streak = 0.7 + 0.3 * np.tanh(pol[(ri + k * 37) % 256, ti])
        gi = ((th + math.pi) / (2 * math.pi) * 511).astype(int) % 512
        g = gaps[(k * 11) % 64, gi]
        open_ = smooth(-0.9, -0.2, g + 0.3 * k / 5)
        ring_a = np.maximum(ring_a, band * streak * open_ * op)
    a = np.maximum(a, ring_a)
    # disc (crisp painted edge)
    edge = disc + ndi.gaussian_filter1d(rng.standard_normal(1024), 12, mode="wrap")[ti] * 2.0
    a = np.maximum(a, smooth(edge + 1.5, edge - 1.5, r))
    col = np.ones((size, size, 3))
    warm = np.clip((r - disc) / (disc * 2), 0, 1)[..., None]
    col = col * (1 - warm * 0.08) + hexc("fff0b8") * warm * 0.08
    return col, np.clip(a, 0, 1)

# ---------------------------------------------------------------- glittering water
def water(w=1920, h=300, seed=7):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    v = yy / h
    rgb = hexc("f7d27a") * (1 - v[..., None]) + hexc("e6a23c") * v[..., None]
    rip = fbm(h, w, rng, (1.0, 2.0), aniso=(1, 25))
    rgb = rgb * (1 + rip[..., None] * 0.05)
    a = smooth(0, 10, yy)  # soft top edge (meets the horizon line)
    def sparkles(seed2, n):
        r2 = np.random.default_rng(seed2)
        s = np.zeros((h, w))
        ys = (r2.random(n) ** 1.6) * h          # denser near the horizon
        xs = r2.normal(0.5, 0.28, n) * w
        for x, y in zip(xs, ys):
            if 0 <= x < w - 8 and 0 <= y < h - 2:
                ln = int(2 + (y / h) * 7 + r2.random() * 3)
                s[int(y), int(x): int(x) + ln] += r2.uniform(0.5, 1.0)
        s = ndi.gaussian_filter(s, (0.5, 0.8))
        return np.clip(s * 2.2, 0, 1)
    return rgb, a, sparkles(seed + 1, 5200), sparkles(seed + 2, 5200)

# ---------------------------------------------------------------- karst mountains (ink wash, white alpha)
def mountains(w=1920, h=520, seed=8, peaks=9, rough=1.0, haze=True):
    rng = np.random.default_rng(seed)
    x = np.arange(w, dtype=float)
    ridge = np.zeros(w)
    for i in range(peaks):
        px = rng.uniform(-0.05, 1.05) * w
        ph = rng.uniform(0.35, 0.95) * h
        pw = rng.uniform(0.035, 0.09) * w
        shape = ph * np.exp(-np.abs((x - px) / pw) ** rng.uniform(2.8, 4.2))   # steep, round-topped karst towers
        ridge = np.maximum(ridge, shape)
    ridge = np.maximum(ridge, h * 0.22 + ndi.gaussian_filter1d(rng.standard_normal(w), 60) * h * 0.4)
    ridge += ndi.gaussian_filter1d(rng.standard_normal(w), 3) * 3 * rough
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    top = h - ridge
    inside = yy - top[None, :]
    a = smooth(-1.0, 1.5, inside)
    wash = 0.8 + 0.2 * np.tanh(fbm(h, w, rng, (30, 10, 3), aniso=(2, 1)))
    # darker crest, misty base (atmospheric wash)
    crest = smooth(40, 0, inside) * 0.15
    a = a * np.clip(wash + crest, 0, 1)
    if haze:
        a *= 1 - smooth(h * 0.45, h * 1.0, yy) * 0.85
    return np.clip(a, 0, 1)

# ---------------------------------------------------------------- ground ridge with grass (white alpha)
def ground(w=1920, h=220, seed=9):
    rng = np.random.default_rng(seed)
    x = np.arange(w, dtype=float)
    top = h * 0.45 + ndi.gaussian_filter1d(rng.standard_normal(w), 90) * h * 0.9
    top += ndi.gaussian_filter1d(rng.standard_normal(w), 6) * 2
    a = np.zeros((h, w))
    yy = np.arange(h)[:, None]
    a = smooth(-1, 1.5, yy - top[None, :])
    img = Image.fromarray((a * 255).astype(np.uint8), "L")
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    for i in range(900):   # grass blades
        gx = rng.uniform(0, w); gy = top[int(gx) % w] + 2
        ln = rng.uniform(6, 26); lean = rng.uniform(-9, 9)
        d.line([(gx, gy), (gx + lean, gy - ln)], fill=255, width=int(rng.choice([1, 2])))
    a = np.asarray(img).astype(float) / 255
    a = ndi.gaussian_filter(a, 0.5)
    return np.clip(a, 0, 1)

# ---------------------------------------------------------------- lacquered wood rod + knob
def rod(w=512, h=40, seed=10):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    v = (yy + 0.5) / h
    shade = 0.55 + 0.6 * np.sin(np.clip(v, 0, 1) * math.pi) ** 0.8 - smooth(0.6, 1.0, v) * 0.35
    grain = fbm(h, w, rng, (0.8, 2.0), aniso=(1, 40), wrap=True)
    base = hexc("6e4424")
    rgb = base * (shade[..., None]) * (1 + grain[..., None] * 0.12)
    spec = np.exp(-((v - 0.28) / 0.07) ** 2) * 0.45
    rgb = rgb + spec[..., None] * hexc("ffd9a0") * 0.6
    a = smooth(0, 1.2, yy) * smooth(h - 0.5, h - 2, yy)
    return rgb, a

def knob(size=96, seed=11):
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    c = size / 2; r = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / (size * 0.46)
    a = smooth(1.02, 0.96, r)
    lx, ly = (xx - c * 0.72) / size, (yy - c * 0.68) / size
    hl = np.exp(-(lx * lx + ly * ly) / 0.012)
    body = hexc("3a2312") * (1 - r[..., None] * 0.4)
    band = (np.abs(r - 0.78) < 0.08)[..., None]
    rgb = np.where(band, hexc("b98a3c") * (1.1 - r[..., None] * 0.4), body)
    rgb = rgb + hl[..., None] * hexc("fff0c8") * 0.7
    return rgb, a

# ---------------------------------------------------------------- torn ribbon cloth (white, alpha), mapped along a banner
def ribbon(w=1024, h=96, seed=12):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    t = xx / (w - 1)
    width = (1 - t * 0.55)                               # tapers toward the tail
    edge_n = fbm(h, w, rng, (4, 2), aniso=(1, 2)) * 0.06
    dist = np.abs((yy / (h - 1)) * 2 - 1) / width + edge_n
    a = smooth(1.0, 0.94, dist)
    # swallowtail: a V notch cut into the tail, plus two thin tears
    yc = np.abs((yy / (h - 1)) * 2 - 1)
    notch = (t - 0.8) / 0.2                      # 0 at 80%, 1 at the end
    a *= np.where(t > 0.8, smooth(notch * 0.75 - 0.03, notch * 0.75 + 0.03, yc / width), 1.0)
    for ty, t0 in ((0.45, 0.62), (-0.5, 0.7)):
        tear = np.abs(((yy / (h - 1)) * 2 - 1) - ty * width) < 0.025 + (t - t0) * 0.05
        a *= np.where((t > t0) & tear, 0.0, 1.0)
    a *= smooth(1.0, 0.985, t)
    # fold shading in the value channel
    fold = 0.82 + 0.18 * np.tanh(fbm(h, w, rng, (10, 4), aniso=(3, 1)) * 1.5)
    tex = paper_grain(512, 13)
    tile = np.tile(tex, (1, 2, 1))[:h, :w, 0]
    val = fold * (0.9 + 0.1 * tile / tile.mean())
    return np.clip(val, 0, 1), np.clip(a, 0, 1)

# ---------------------------------------------------------------- bamboo pole tile (white value + alpha), vertical repeat
def bamboo(w=24, h=256, seed=14):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    u = (xx + 0.5) / w
    shade = 0.45 + 0.55 * np.sin(u * math.pi) ** 0.7
    hl = np.exp(-((u - 0.32) / 0.08) ** 2) * 0.35
    node = np.exp(-((yy - h * 0.5) / 2.2) ** 2) * 0.55
    val = shade + hl - node
    val *= 0.92 + 0.08 * norm01(fbm(h, w, rng, (0.7,), aniso=(12, 1), wrap=True))
    bulge = np.exp(-((yy - h * 0.5) / 4.0) ** 2) * 0.06
    a = smooth(0.0 - bulge, 0.08 - bulge, u) * smooth(1.0 + bulge, 0.92 + bulge, u)
    return np.clip(val, 0, 1), a

if __name__ == "__main__":
    save("paper_grain.png", paper_grain(512, 1))
    rgb, a = parchment(); save("parchment.png", rgb, a)
    save("brush_stroke.png", np.ones((160, 1024)), brush_stroke())
    save("brush_underline.png", np.ones((40, 512)), brush_stroke(512, 40, seed=21, bristles=30, dry=1.3, body_h=0.5))
    save("brush_wash.png", np.ones((256, 1024)), brush_stroke(1024, 256, seed=33, bristles=140, dry=0.55, body_h=0.92))
    save("brush_button.png", np.ones((84, 480)), brush_stroke(480, 84, seed=5, bristles=48, dry=0.75, body_h=0.82))
    ul = np.zeros((64, 384)); ul[46:62] = brush_stroke(384, 16, seed=22, bristles=12, dry=1.1, body_h=0.7)
    save("button_underline.png", np.ones((64, 384)), ul)
    save("sky.png", sky())
    c, a = sun(); save("sun.png", c, a)
    rgb, a, s1, s2 = water(); save("water.png", rgb, a)
    save("sparkle_a.png", np.ones_like(s1), s1); save("sparkle_b.png", np.ones_like(s2), s2)
    save("mountains_far.png", np.ones((520, 1920)), mountains(seed=8, peaks=11))
    save("mountains_near.png", np.ones((360, 1920)), mountains(1920, 360, seed=18, peaks=6, rough=1.5))
    save("ground.png", np.ones((220, 1920)), ground())
    rgb, a = rod(); save("rod.png", rgb, a)
    rgb, a = knob(); save("knob.png", rgb, a)
    v, a = ribbon(); save("ribbon.png", v, a)
    v, a = bamboo(); save("bamboo.png", v, a)
