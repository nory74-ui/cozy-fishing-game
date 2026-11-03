"""
Procedural Stylized 3D Model: Concrete Tetrapod (野北海岸のテトラポッド)
Tool: Blender 5.2 LTS via Headless Python
Exports: assets/models/fbx/nogita_tetrapod.fbx
"""

import bpy
import bmesh
from mathutils import Vector, Matrix
import math
import os

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_tetrapod():
    clear_scene()
    
    mat_conc = bpy.data.materials.new(name="M_TetraConcrete")
    mat_conc.use_nodes = True
    bsdf = mat_conc.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.70, 0.71, 0.73, 1.0)
        bsdf.inputs['Roughness'].default_value = 0.88

    root_obj = bpy.data.objects.new("Tetra_Root", None)
    bpy.context.scene.collection.objects.link(root_obj)

    # 正四面体の4頂点方向
    dirs = [
        Vector((0, 0, 1.0)),
        Vector((math.sqrt(8/9), 0, -1/3)),
        Vector((-math.sqrt(2/9), math.sqrt(2/3), -1/3)),
        Vector((-math.sqrt(2/9), -math.sqrt(2/3), -1/3))
    ]
    
    # 中央ノード
    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.45, location=(0, 0, 0))
    center_sphere = bpy.context.active_object
    center_sphere.data.materials.append(mat_conc)
    center_sphere.parent = root_obj

    # 4本の円錐脚
    for d in dirs:
        bpy.ops.mesh.primitive_cone_add(radius1=0.42, radius2=0.24, depth=0.95, location=d * 0.48)
        leg = bpy.context.active_object
        leg.data.materials.append(mat_conc)
        # 向きを合わせる
        rot = Vector((0, 0, 1)).rotation_difference(d)
        leg.rotation_euler = rot.to_euler()
        leg.parent = root_obj
        
        # 脚の先端丸めキャップ
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.24, location=d * 0.95)
        cap = bpy.context.active_object
        cap.data.materials.append(mat_conc)
        cap.parent = root_obj

    # 全メッシュ結合
    bpy.ops.object.select_all(action='DESELECT')
    for child in root_obj.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root_obj.children[0]
    bpy.ops.object.join()
    
    tp_obj = bpy.context.active_object
    tp_obj.name = "NogitaTetrapod3D"
    tp_obj.parent = None
    bpy.data.objects.remove(root_obj)
    
    # ピボットを底面に設定
    bbox = [tp_obj.matrix_world @ Vector(corner) for corner in tp_obj.bound_box]
    min_z = min(v.z for v in bbox)
    center_x = sum(v.x for v in bbox) / 8.0
    center_y = sum(v.y for v in bbox) / 8.0
    bpy.context.scene.cursor.location = Vector((center_x, center_y, min_z))
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.scene.cursor.location = Vector((0, 0, 0))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    output_fbx = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/nogita_tetrapod.fbx"
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
    print(f"[Success] Generated Nogita Tetrapod FBX: {output_fbx}")

if __name__ == "__main__":
    create_tetrapod()
