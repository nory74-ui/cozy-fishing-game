"""
Procedural Stylized 3D Model: Swimming Sea Fish (玄界灘の泳ぐ魚)
Tool: Blender 5.2 LTS via Headless Python
Exports: assets/models/fbx/swimming_sea_fish.fbx
"""

import bpy
import bmesh
from mathutils import Vector, Matrix
import math
import os

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_fish():
    clear_scene()
    
    mat_back = bpy.data.materials.new(name="M_FishBack")
    mat_back.use_nodes = True
    b_b = mat_back.node_tree.nodes.get("Principled BSDF")
    if b_b:
        b_b.inputs['Base Color'].default_value = (0.15, 0.42, 0.55, 1.0) # 背中の青緑
        b_b.inputs['Roughness'].default_value = 0.35

    mat_belly = bpy.data.materials.new(name="M_FishBelly")
    mat_belly.use_nodes = True
    b_l = mat_belly.node_tree.nodes.get("Principled BSDF")
    if b_l:
        b_l.inputs['Base Color'].default_value = (0.85, 0.90, 0.92, 1.0) # 腹部の銀白
        b_l.inputs['Roughness'].default_value = 0.30

    mat_fin = bpy.data.materials.new(name="M_FishFin")
    mat_fin.use_nodes = True
    b_f = mat_fin.node_tree.nodes.get("Principled BSDF")
    if b_f:
        b_f.inputs['Base Color'].default_value = (0.75, 0.85, 0.88, 0.7)
        b_f.inputs['Roughness'].default_value = 0.40

    root_obj = bpy.data.objects.new("Fish_Root", None)
    bpy.context.scene.collection.objects.link(root_obj)

    # 1. 魚体 (Streamlined Body)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=0.35, location=(0, 0, 0))
    body = bpy.context.active_object
    body.scale = (0.35, 1.25, 0.55) # 左右に薄く、前後に長い流線型
    body.data.materials.append(mat_back)
    body.parent = root_obj

    # 2. 尾ビレ (Caudal Fin)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=0.03, location=(0, -0.52, 0))
    tail = bpy.context.active_object
    tail.scale = (0.3, 1.0, 1.8)
    tail.rotation_euler = (0, math.radians(90), 0)
    tail.data.materials.append(mat_fin)
    tail.parent = root_obj

    # 3. 背ビレ (Dorsal Fin)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=0.02, location=(0, 0.05, 0.22))
    dorsal = bpy.context.active_object
    dorsal.scale = (0.3, 1.2, 0.8)
    dorsal.rotation_euler = (0, math.radians(90), 0)
    dorsal.data.materials.append(mat_fin)
    dorsal.parent = root_obj

    # 4. 胸ビレ (Pectoral Fins)
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.02, location=(side * 0.14, 0.15, -0.05))
        pec = bpy.context.active_object
        pec.scale = (0.3, 1.0, 0.6)
        pec.rotation_euler = (math.radians(20), math.radians(side * 45), 0)
        pec.data.materials.append(mat_fin)
        pec.parent = root_obj

    # 全メッシュ結合
    bpy.ops.object.select_all(action='DESELECT')
    for child in root_obj.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root_obj.children[0]
    bpy.ops.object.join()
    
    fish_obj = bpy.context.active_object
    fish_obj.name = "SwimmingFish3D"
    fish_obj.parent = None
    bpy.data.objects.remove(root_obj)
    
    # トランスフォーム適用
    bpy.ops.object.origin_set(type='ORIGIN_CENTER_OF_MASS')
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    output_fbx = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/swimming_sea_fish.fbx"
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
    print(f"[Success] Generated Swimming Fish FBX: {output_fbx}")

if __name__ == "__main__":
    create_fish()
