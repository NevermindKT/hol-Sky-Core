import bpy, bmesh, sys, os, math, random
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
out_glb, tex_path, preview = args[0], args[1], args[2]
TILE = 128
ATLAS = TILE * 2

TILES = {
    "short": dict(seed=1, blades=150, height=(0.45, 0.8), width=(2.2, 3.4), lean=0.25, base=(0.16, 0.12, 0.06), tip=(0.40, 0.44, 0.18), heads=0),
    "tall": dict(seed=2, blades=110, height=(0.6, 0.98), width=(2.0, 3.0), lean=0.35, base=(0.14, 0.12, 0.06), tip=(0.34, 0.42, 0.16), heads=0),
    "dry": dict(seed=3, blades=130, height=(0.4, 0.85), width=(2.2, 3.2), lean=0.3, base=(0.18, 0.13, 0.07), tip=(0.50, 0.43, 0.22), heads=0),
    "seed": dict(seed=4, blades=120, height=(0.45, 0.9), width=(2.0, 3.0), lean=0.3, base=(0.16, 0.12, 0.06), tip=(0.38, 0.42, 0.18), heads=9),
}
TILE_UV = {"short": (0, 0), "tall": (1, 0), "dry": (0, 1), "seed": (1, 1)}


def draw_tile(cfg):
    rng = np.random.default_rng(cfg["seed"])
    rgb = np.zeros((TILE, TILE, 3))
    alpha = np.zeros((TILE, TILE))
    margin = 3
    for b in range(cfg["blades"]):
        x0 = rng.uniform(margin + 4, TILE - margin - 4)
        h = rng.uniform(*cfg["height"]) * (TILE - margin)
        lean = rng.uniform(-cfg["lean"], cfg["lean"]) * h
        bend = rng.uniform(0.3, 1.0) * np.sign(lean) * h * 0.15
        w0 = rng.uniform(*cfg["width"])
        shade = rng.uniform(0.75, 1.15)
        hue = rng.uniform(-0.02, 0.02)
        steps = int(h * 2)
        for s in range(steps):
            t = s / steps
            cx = x0 + lean * t + bend * t * t
            cy = TILE - 1 - t * h
            w = max(w0 * (1.0 - t) ** 0.8, 0.6)
            col = np.array(cfg["base"]) * (1 - t ** 0.7) + np.array(cfg["tip"]) * t ** 0.7
            col = col * shade + np.array([hue, 0.0, -hue])
            xa, xb = int(math.floor(cx - w * 0.5)), int(math.ceil(cx + w * 0.5))
            yi = int(round(cy))
            if yi < margin or yi >= TILE:
                continue
            for xi in range(max(xa, margin), min(xb, TILE - margin)):
                rgb[yi, xi] = col
                alpha[yi, xi] = 1.0
    for k in range(cfg["heads"]):
        x0 = rng.uniform(margin + 6, TILE - margin - 6)
        top = rng.uniform(margin + 2, TILE * 0.35)
        for y in range(int(top), TILE):
            xi = int(round(x0 + (y - top) * 0.04))
            rgb[y, xi] = (0.10, 0.11, 0.05)
            alpha[y, xi] = 1.0
        for y in range(int(top), int(top) + 10):
            for xi in range(int(x0) - 1, int(x0) + 2):
                if margin <= xi < TILE - margin:
                    rgb[y, xi] = np.array((0.38, 0.33, 0.20)) * rng.uniform(0.8, 1.1)
                    alpha[y, xi] = 1.0
    grain = rng.uniform(0.85, 1.12, (TILE, TILE, 1))
    rgb = np.clip(rgb * grain, 0, 1)
    return np.concatenate([rgb, alpha[..., None]], axis=-1)


def build_atlas():
    atlas = np.zeros((ATLAS, ATLAS, 4))
    for name, cfg in TILES.items():
        tx, ty = TILE_UV[name]
        atlas[ty * TILE:(ty + 1) * TILE, tx * TILE:(tx + 1) * TILE] = draw_tile(cfg)
    a = atlas[..., 3:]
    filled = atlas[..., :3].copy()
    mask = a[..., 0] > 0
    for _ in range(4):
        acc = np.zeros_like(filled)
        cnt = np.zeros(mask.shape)
        for ax in (0, 1):
            for d in (-1, 1):
                sm = np.roll(mask, d, axis=ax)
                acc += np.roll(filled, d, axis=ax) * sm[..., None]
                cnt += sm
        grow = (~mask) & (cnt > 0)
        filled[grow] = acc[grow] / cnt[grow][:, None]
        mask = mask | grow
    return np.concatenate([filled, a], axis=-1)


def save_atlas(rgba, path):
    img = bpy.data.images.new("grass_atlas", ATLAS, ATLAS, alpha=True)
    img.pixels = rgba[::-1].reshape(-1).tolist()
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    img.alpha_mode = 'STRAIGHT'
    return img


def make_material(img):
    mat = bpy.data.materials.new("grass")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    clip = nt.nodes.new('ShaderNodeMath')
    clip.operation = 'GREATER_THAN'
    clip.inputs[1].default_value = 0.5
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(tex.outputs['Alpha'], clip.inputs[0])
    nt.links.new(clip.outputs[0], bsdf.inputs['Alpha'])
    bsdf.inputs['Roughness'].default_value = 1.0
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.05
    return mat


def make_clump(name, tile, cards, width, height, seed, material, x):
    rnd = random.Random(seed)
    tx, ty = TILE_UV[tile]
    u0, u1 = tx * 0.5 + 0.004, tx * 0.5 + 0.496
    v0, v1 = (1 - ty) * 0.5, (1 - ty) * 0.5 + 0.5
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for c in range(cards):
        ang = math.pi * c / min(cards, 3) + rnd.uniform(-0.25, 0.25)
        if c >= 3:
            ox, oy = rnd.uniform(-0.3, 0.3) * width, rnd.uniform(-0.3, 0.3) * width
        else:
            ox, oy = 0.0, 0.0
        w = width * rnd.uniform(0.85, 1.1) * 0.5
        h = height * rnd.uniform(0.85, 1.1)
        dx, dy = math.cos(ang) * w, math.sin(ang) * w
        flip = rnd.random() < 0.5
        tilt = math.radians(rnd.uniform(28.0, 42.0)) * (1 if c % 2 == 0 else -1)
        nx, ny = -math.sin(ang) * math.sin(tilt) * h, math.cos(ang) * math.sin(tilt) * h
        th = h * math.cos(tilt)
        vs = [bm.verts.new((ox - dx, oy - dy, 0.0)), bm.verts.new((ox + dx, oy + dy, 0.0)),
              bm.verts.new((ox + dx + nx, oy + dy + ny, th)), bm.verts.new((ox - dx + nx, oy - dy + ny, th))]
        f = bm.faces.new(vs)
        ua, ub = (u1, u0) if flip else (u0, u1)
        for loop, coord in zip(f.loops, [(ua, v0), (ub, v0), (ub, v1), (ua, v1)]):
            loop[uv].uv = coord
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    tris = len(bm.faces)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    mesh.normals_split_custom_set([(0.0, 0.0, 1.0)] * len(mesh.loops))
    obj = bpy.data.objects.new(name, mesh)
    obj.location = (x, 0.0, 0.0)
    mesh.materials.append(material)
    bpy.context.scene.collection.objects.link(obj)
    print("GRASS", name, tile, tris, "tris", tuple(round(d, 2) for d in obj.dimensions))


bpy.ops.wm.read_factory_settings(use_empty=True)
os.makedirs(os.path.dirname(tex_path), exist_ok=True)
material = make_material(save_atlas(build_atlas(), tex_path))

CLUMPS = [
    ("grass01", "short", 2, 0.9, 0.42, 1),
    ("grass02", "tall", 3, 0.8, 0.7, 2),
    ("grass03", "dry", 3, 0.9, 0.5, 3),
    ("grass04", "seed", 4, 1.0, 0.6, 4),
    ("grass05", "short", 6, 1.3, 0.45, 5),
    ("grass06", "tall", 3, 1.1, 0.55, 6),
]
for i, (name, tile, cards, width, height, seed) in enumerate(CLUMPS):
    make_clump(name, tile, cards, width, height, seed, material, i * 3.0)

bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB', export_yup=True, export_apply=True, export_animations=False)

scene = bpy.context.scene
plane = bpy.data.meshes.new("ground")
pbm = bmesh.new()
bmesh.ops.create_grid(pbm, x_segments=1, y_segments=1, size=12.0)
pbm.to_mesh(plane)
pbm.free()
ground = bpy.data.objects.new("ground", plane)
ground.location = (7.5, 0.0, 0.0)
gm = bpy.data.materials.new("ground")
gm.use_nodes = True
next(n for n in gm.node_tree.nodes if n.type == 'BSDF_PRINCIPLED').inputs['Base Color'].default_value = (0.05, 0.035, 0.02, 1)
plane.materials.append(gm)
scene.collection.objects.link(ground)
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (7.5, -5.5, 1.6)
cam.rotation_euler = (math.radians(78), 0, 0)
cam_data.lens = 22
scene.camera = cam
sun_data = bpy.data.lights.new("sun", 'SUN')
sun_data.energy = 3.0
sun = bpy.data.objects.new("sun", sun_data)
sun.rotation_euler = (math.radians(45), math.radians(15), math.radians(30))
scene.collection.objects.link(sun)
scene.world = bpy.data.worlds.new("w")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.25, 0.27, 0.3, 1)
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
scene.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in engines else 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 960
scene.render.resolution_y = 360
scene.render.filepath = preview
bpy.ops.render.render(write_still=True)
