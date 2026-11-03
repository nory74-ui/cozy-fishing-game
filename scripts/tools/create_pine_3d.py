"""
Procedural Stylized 3D Model: Japanese Black Pine Tree (糸島・野北の黒松)
Tool: Blender 5.2 LTS via Headless Python
Exports: assets/models/fbx/nogita_black_pine.fbx
"""

import bpy
import bmesh
from mathutils import Vector, Matrix, Euler
import math
import os

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_material(name, color, roughness=0.8):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (color[0], color[1], color[2], 1.0)
        bsdf.inputs['Roughness'].default_value = roughness
    return mat

def create_pine():
    clear_scene()
    
    mat_trunk = create_material("M_PineTrunk", (0.34, 0.24, 0.16), 0.9) # 荒々しい松の樹皮
    mat_leaves = create_material("M_PineNeedles", (0.16, 0.42, 0.18), 0.75) # 深い緑の松葉

    root_obj = bpy.data.objects.new("Pine_Root", None)
    bpy.context.scene.collection.objects.link(root_obj)

    # 1. ねじれながら海風に傾く幹 (Twisted Trunk)
    cur_pos = Vector((0, 0, 0))
    lean_dir = Vector((-0.42, -0.15, 0.9)).normalized()
    segments = 7
    for s in range(segments):
        t = float(s) / segments
        r_bottom = (1.0 - t) * 0.45 + 0.18
        r_top = (1.0 - (t + 0.14)) * 0.45 + 0.18
        h = 0.75
        
        bpy.ops.mesh.primitive_cylinder_add(radius=r_bottom, depth=h, location=cur_pos + Vector((0, 0, h * 0.5)))
        cyl = bpy.context.active_object
        cyl.data.materials.append(mat_trunk)
        cyl.parent = root_obj
        
        cur_pos += Vector((lean_dir.x * 0.28, lean_dir.y * 0.15, h * 0.95))

    # 2. 放射状の大枝 (Gnarled Branches)
    branch_specs = [
        (Vector((-1.8, 0.4, 0.3)), 1.5, 0.45),
        (Vector((-1.4, -1.2, 0.2)), 1.4, 0.42),
        (Vector((-2.2, -0.2, 0.1)), 1.7, 0.48),
        (Vector((-0.8, 1.2, 0.5)), 1.3, 0.40),
        (Vector((-1.0, -0.9, 0.7)), 1.2, 0.38),
        (Vector((-0.3, 0.2, 1.1)), 1.1, 0.35)
    ]
    for b_off, r_leaf, h_leaf in branch_specs:
        # 枝
        bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=b_off.length, location=cur_pos + b_off * 0.5)
        branch = bpy.context.active_object
        branch.data.materials.append(mat_trunk)
        branch.parent = root_obj
        
        # 枝先の扇状・雲状の豊かな松葉キャノピー
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=r_leaf, location=cur_pos + b_off)
        crown = bpy.context.active_object
        crown.scale = (1.3, 1.2, 0.42)
        crown.data.materials.append(mat_leaves)
        crown.parent = root_obj

    # 全メッシュ結合
    bpy.ops.object.select_all(action='DESELECT')
    for child in root_obj.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root_obj.children[0]
    bpy.ops.object.join()
    
    pine_obj = bpy.context.active_object
    pine_obj.name = "NogitaBlackPine3D"
    pine_obj.parent = None
    bpy.data.objects.remove(root_obj)
    
    # ピボットを根元接地位置に設定
    bbox = [pine_obj.matrix_world @ Vector(corner) for corner in pine_obj.bound_box]
    min_z = min(v.z for v in bbox)
    center_x = sum(v.x for v in bbox) / 8.0
    center_y = sum(v.y for v in bbox) / 8.0
    bpy.context.scene.cursor.location = Vector((center_x, center_y, min_z))
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.scene.cursor.location = Vector((0, 0, 0))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    output_fbx = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/nogita_black_pine.fbx"
    os.makedirs(os.path.dirname(output_fbx), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=output_fbx,
        use_selection=False,
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_ALL',
        bake_space_transform=True,
        axis_forward='-Z',
        axis_up='Y'
    )
    print(f"[Success] Generated Nogita Black Pine FBX: {output_fbx}")

if __name__ == "__main__":
    create_pine()
