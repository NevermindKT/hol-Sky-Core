import bpy, bmesh, sys, os, math, random
import numpy as np
from mathutils import Vector, noise

args = sys.argv[sys.argv.index("--") + 1:]
out_glb, tex_dir, preview = args[0], args[1], args[2]
SIZE = 128


def periodic_noise(rng, cells, size=SIZE):
    grid = rng.random((cells, cells))
    xs = np.arange(size) / size * cells
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


def fbm(rng, octaves):
    total = np.zeros((SIZE, SIZE))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += periodic_noise(rng, 4 * 2 ** o) * amp
        norm += amp
        amp *= 0.55
    return total / norm


def rock_texture(seed, moss):
    rng = np.random.default_rng(seed)
    base = fbm(rng, 5)
    detail = fbm(rng, 3)
    pits = np.clip((periodic_noise(rng, 16) - 0.62) * 4.0, 0.0, 1.0)
    speck = rng.random((SIZE, SIZE))
    light = 0.2 + 0.2 * base + 0.08 * (detail - 0.5)
    light -= pits * 0.07
    light += (speck > 0.94) * 0.05 - (speck < 0.06) * 0.05
    warm = np.stack([light * 1.06, light * 1.0, light * 0.9], axis=-1)
    if moss:
        m = fbm(rng, 4)
        mask = np.clip((m - 0.48) * 6.0, 0.0, 1.0)[..., None]
        moss_col = np.stack([0.13 + 0.06 * detail, 0.18 + 0.08 * detail, 0.08 + 0.03 * detail], axis=-1)
        warm = warm * (1 - mask) + moss_col * mask
    rgba = np.concatenate([np.clip(warm, 0, 1), np.ones((SIZE, SIZE, 1))], axis=-1)
    return rgba


def save_image(name, rgba, path):
    img = bpy.data.images.new(name, SIZE, SIZE, alpha=False)
    img.pixels = rgba[::-1].reshape(-1).tolist()
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    return img


def make_material(name, img):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.95
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.15
    return mat


def make_stone(name, seed, subdiv, scale, roughness, flat_bottom, material, x):
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    off = Vector((rnd.uniform(-50, 50), rnd.uniform(-50, 50), rnd.uniform(-50, 50)))
    for v in bm.verts:
        n = v.co.normalized()
        d = noise.fractal(n * 0.8 + off, 0.5, 2.0, 2) * roughness
        d += noise.noise(n * 2.0 + off) * roughness * 0.15
        v.co = n * (1.0 + d)
        v.co.x *= scale[0]
        v.co.y *= scale[1]
        v.co.z *= scale[2]
    min_z = min(v.co.z for v in bm.verts)
    cut = min_z + (scale[2] * 2.0) * flat_bottom
    for v in bm.verts:
        if v.co.z < cut:
            v.co.z = cut + (v.co.z - cut) * 0.15
    min_z = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z -= min_z
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    if subdiv > 2:
        mesh_tmp = bpy.data.meshes.new(name + "_tmp")
        bm.to_mesh(mesh_tmp)
        tmp = bpy.data.objects.new(name + "_tmp", mesh_tmp)
        bpy.context.scene.collection.objects.link(tmp)
        mod = tmp.modifiers.new("dec", 'DECIMATE')
        mod.ratio = 0.68
        dg = bpy.context.evaluated_depsgraph_get()
        bm.free()
        bm = bmesh.new()
        bm.from_mesh(tmp.evaluated_get(dg).to_mesh())
        bpy.data.objects.remove(tmp)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        f.smooth = False
        nrm = f.normal
        ax = max(range(3), key=lambda i: abs(nrm[i]))
        for loop in f.loops:
            c = loop.vert.co
            p = (c.y, c.z) if ax == 0 else ((c.x, c.z) if ax == 1 else (c.x, c.y))
            loop[uv].uv = (p[0] * 0.5, p[1] * 0.5)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    tris = len(bm.faces)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = (x, 0.0, 0.0)
    mesh.materials.append(material)
    bpy.context.scene.collection.objects.link(obj)
    dims = obj.dimensions
    print("STONE", name, tris, "tris", tuple(round(d, 2) for d in dims))
    return obj


bpy.ops.wm.read_factory_settings(use_empty=True)
os.makedirs(tex_dir, exist_ok=True)
plain = make_material("stone_plain", save_image("stone_plain", rock_texture(11, False), os.path.join(tex_dir, "stone_plain.png")))
mossy = make_material("stone_mossy", save_image("stone_mossy", rock_texture(23, True), os.path.join(tex_dir, "stone_mossy.png")))

STONES = [
    ("stone01", 1, 2, (0.55, 0.45, 0.35), 0.25, 0.18, plain),
    ("stone02", 2, 2, (0.8, 0.6, 0.45), 0.3, 0.2, mossy),
    ("stone03", 3, 2, (0.5, 0.45, 0.5), 0.3, 0.15, plain),
    ("stone04", 4, 3, (1.3, 1.0, 0.8), 0.28, 0.22, mossy),
    ("stone05", 5, 3, (1.6, 0.9, 0.55), 0.3, 0.18, plain),
    ("stone06", 6, 2, (0.9, 0.35, 0.3), 0.22, 0.1, mossy),
]
objs = []
for i, (name, seed, subdiv, scale, rough, flat, mat) in enumerate(STONES):
    objs.append(make_stone(name, seed, subdiv, scale, rough, flat, mat, i * 4.0))

bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB', export_yup=True, export_apply=True, export_animations=False)

scene = bpy.context.scene
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (10.0, -16.0, 5.0)
cam.rotation_euler = (math.radians(75), 0, math.radians(0))
cam_data.lens = 28
scene.camera = cam
sun_data = bpy.data.lights.new("sun", 'SUN')
sun_data.energy = 3.0
sun = bpy.data.objects.new("sun", sun_data)
sun.rotation_euler = (math.radians(50), math.radians(20), math.radians(30))
scene.collection.objects.link(sun)
scene.world = bpy.data.worlds.new("w")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.25, 0.27, 0.3, 1)
scene.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 960
scene.render.resolution_y = 400
scene.render.filepath = preview
bpy.ops.render.render(write_still=True)
