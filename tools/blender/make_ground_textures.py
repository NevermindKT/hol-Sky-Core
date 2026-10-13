import bpy, sys, os
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
out_dir = args[0]
SIZE = 256


def periodic_noise(rng, cells):
    grid = rng.random((cells, cells))
    xs = np.arange(SIZE) / SIZE * cells
    i0 = np.floor(xs).astype(int)
    f = xs - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    a = grid[np.ix_(i0, i0)]
    b = grid[np.ix_(i0, i1)]
    c = grid[np.ix_(i1, i0)]
    d = grid[np.ix_(i1, i1)]
    fy, fx = f[:, None], f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(rng, base_cells, octaves):
    total = np.zeros((SIZE, SIZE))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += periodic_noise(rng, base_cells * 2 ** o) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def strokes(rng, img, count, length, colors, jitter):
    for _ in range(count):
        x, y = rng.uniform(0, SIZE), rng.uniform(0, SIZE)
        ang = rng.uniform(0, np.pi)
        n = int(rng.uniform(*length))
        col = np.array(colors[rng.integers(len(colors))]) * rng.uniform(1 - jitter, 1 + jitter)
        for s in range(n):
            xi = int(x + np.cos(ang) * s) % SIZE
            yi = int(y + np.sin(ang) * s) % SIZE
            img[yi, xi] = col


def mix(a, b, t):
    return a * (1 - t[..., None]) + b * t[..., None]


def meadow():
    rng = np.random.default_rng(31)
    patches = fbm(rng, 4, 4)
    detail = fbm(rng, 16, 2)
    grass = np.array([0.21, 0.23, 0.09])
    dry = np.array([0.24, 0.22, 0.10])
    img = mix(np.broadcast_to(grass, (SIZE, SIZE, 3)), np.broadcast_to(dry, (SIZE, SIZE, 3)), np.clip((patches - 0.55) * 3.0, 0, 1))
    img = img * (0.85 + 0.3 * detail)[..., None]
    strokes(rng, img, 4200, (2, 5), [(0.28, 0.32, 0.12), (0.24, 0.27, 0.10), (0.33, 0.33, 0.14), (0.15, 0.16, 0.07), (0.18, 0.14, 0.07)], 0.12)
    speck = rng.random((SIZE, SIZE))
    img[speck < 0.03] *= 0.7
    return img


def forest():
    rng = np.random.default_rng(47)
    patches = fbm(rng, 4, 4)
    detail = fbm(rng, 16, 2)
    litter = np.array([0.13, 0.10, 0.06])
    moss = np.array([0.12, 0.14, 0.06])
    img = mix(np.broadcast_to(litter, (SIZE, SIZE, 3)), np.broadcast_to(moss, (SIZE, SIZE, 3)), np.clip((patches - 0.5) * 3.0, 0, 1))
    img = img * (0.8 + 0.4 * detail)[..., None]
    strokes(rng, img, 3200, (3, 7), [(0.19, 0.13, 0.07), (0.16, 0.11, 0.06), (0.09, 0.07, 0.04), (0.21, 0.17, 0.09)], 0.15)
    strokes(rng, img, 500, (1, 3), [(0.15, 0.17, 0.07)], 0.15)
    return img


def shoulder():
    rng = np.random.default_rng(59)
    patches = fbm(rng, 4, 4)
    detail = fbm(rng, 16, 2)
    dirt = np.array([0.20, 0.18, 0.15])
    packed = np.array([0.25, 0.23, 0.19])
    img = mix(np.broadcast_to(dirt, (SIZE, SIZE, 3)), np.broadcast_to(packed, (SIZE, SIZE, 3)), np.clip((patches - 0.4) * 2.0, 0, 1))
    img = img * (0.85 + 0.3 * detail)[..., None]
    yy, xx = np.mgrid[-6:7, -6:7]
    for _ in range(1100):
        cx, cy = rng.integers(0, SIZE, 2)
        r = rng.uniform(1.8, 5.5)
        squash = rng.uniform(0.6, 1.0)
        tone = rng.uniform(0.26, 0.42)
        col = np.array([tone, tone * 0.97, tone * 0.9])
        d = (xx / r) ** 2 + (yy / (r * squash)) ** 2
        for (dy, dx) in zip(*np.nonzero(d <= 1.0)):
            oy, ox = dy - 6, dx - 6
            shade = 1.15 - 0.45 * (oy / max(r * squash, 1.0) + 1.0) * 0.5
            img[(cy + oy) % SIZE, (cx + ox) % SIZE] = col * shade
        for (dy, dx) in zip(*np.nonzero((d > 1.0) & (d <= 1.5))):
            oy, ox = dy - 6, dx - 6
            if oy >= 0:
                img[(cy + oy) % SIZE, (cx + ox) % SIZE] *= 0.75
    strokes(rng, img, 300, (2, 4), [(0.20, 0.22, 0.09), (0.16, 0.17, 0.07)], 0.12)
    return img


def save(name, rgb, gain=1.0):
    rgb = rgb * gain
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones((SIZE, SIZE, 1))], axis=-1)
    img = bpy.data.images.new(name, SIZE, SIZE, alpha=False)
    img.pixels = rgba[::-1].reshape(-1).tolist()
    img.filepath_raw = os.path.join(out_dir, name + ".png")
    img.file_format = 'PNG'
    img.save()
    print("GROUND", name, np.round(rgb.reshape(-1, 3).mean(axis=0), 3))


os.makedirs(out_dir, exist_ok=True)
save("psx_meadow", meadow(), 1.15)
save("psx_forest", forest(), 1.3)
save("psx_shoulder", shoulder(), 1.2)
