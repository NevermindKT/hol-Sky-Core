import bpy, sys, os, glob
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[0], args[1]

CATEGORY = {}
for n in [1, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14]:
    CATEGORY[f"tree{n:02d}"] = "conifer"
for n in [2, 3] + list(range(15, 28)):
    CATEGORY[f"tree{n:02d}"] = "deciduous"
for n in [13] + list(range(28, 37)):
    CATEGORY[f"tree{n:02d}"] = "autumn"
for n in range(1, 9):
    CATEGORY[f"bush{n:02d}"] = "bush"


def make_material(name, image_path):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(image_path)
    tex.image.alpha_mode = 'STRAIGHT'
    clip = nt.nodes.new('ShaderNodeMath')
    clip.operation = 'GREATER_THAN'
    clip.inputs[1].default_value = 0.5
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(tex.outputs['Alpha'], clip.inputs[0])
    nt.links.new(clip.outputs[0], bsdf.inputs['Alpha'])
    bsdf.inputs['Roughness'].default_value = 1.0
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.1
    return mat


for fbx in sorted(glob.glob(os.path.join(src, "models", "*.fbx"))):
    name = os.path.splitext(os.path.basename(fbx))[0]
    category = CATEGORY[name]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for o in bpy.context.scene.objects:
        o.select_set(o.type == 'MESH')
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj = meshes[0]
    obj.name = name
    obj.data.name = name
    verts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    min_z = min(v.z for v in verts)
    for v in obj.data.vertices:
        v.co.z -= min_z
    obj.location = (0.0, 0.0, 0.0)
    obj.data.materials.clear()
    obj.data.materials.append(make_material(name, os.path.join(src, "textures", name + ".png")))
    obj.data.calc_loop_triangles()
    lo = Vector((min(v.co.x for v in obj.data.vertices), min(v.co.y for v in obj.data.vertices), min(v.co.z for v in obj.data.vertices)))
    hi = Vector((max(v.co.x for v in obj.data.vertices), max(v.co.y for v in obj.data.vertices), max(v.co.z for v in obj.data.vertices)))
    out_dir = os.path.join(dst, category)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_yup=True, export_apply=True, export_animations=False)
    print("CONVERT", name, category, len(obj.data.loop_triangles), "min", tuple(round(c, 2) for c in lo), "max", tuple(round(c, 2) for c in hi))
