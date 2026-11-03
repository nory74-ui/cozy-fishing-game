"""
Procedural Stylized 3D Model: White Lighthouse (糸島・野北白灯台)
Tool: Blender 5.2 LTS via Headless Python
Exports: assets/models/fbx/nogita_lighthouse.fbx
"""

import bpy
import bmesh
from mathutils import Vector, Matrix
import math
import os

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_lighthouse():
    clear_scene()
    
    mat_white = bpy.data.materials.new(name="M_LighthouseWhite")
    mat_white.use_nodes = True
    b_w = mat_white.node_tree.nodes.get("Principled BSDF")
    if b_w:
        b_w.inputs['Base Color'].default_value = (0.95, 0.95, 0.97, 1.0)
        b_w.inputs['Roughness'].default_value = 0.45

    mat_red = bpy.data.materials.new(name="M_LighthouseRed")
    mat_red.use_nodes = True
    b_r = mat_red.node_tree.nodes.get("Principled BSDF")
    if b_r:
        b_r.inputs['Base Color'].default_value = (0.85, 0.18, 0.15, 1.0)
        b_r.inputs['Roughness'].default_value = 0.40

    mat_dark = bpy.data.materials.new(name="M_LighthouseRail")
    mat_dark.use_nodes = True
    b_d = mat_dark.node_tree.nodes.get("Principled BSDF")
    if b_d:
        b_d.inputs['Base Color'].default_value = (0.22, 0.22, 0.24, 1.0)
        b_d.inputs['Roughness'].default_value = 0.50

    root_obj = bpy.data.objects.new("Lighthouse_Root", None)
    bpy.context.scene.collection.objects.link(root_obj)

    # 1. 白いタワー本体 (Tapered Tower)
    bpy.ops.mesh.primitive_cone_add(radius1=0.88, radius2=0.62, depth=4.2, location=(0, 0, 2.1))
    tower = bpy.context.active_object
    tower.data.materials.append(mat_white)
    tower.parent = root_obj

    # 2. 展望デッキ・踊り場 (Observation Deck)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.98, depth=0.18, location=(0, 0, 4.2))
    deck = bpy.context.active_object
    deck.data.materials.append(mat_dark)
    deck.parent = root_obj

    # 手すり (Railing)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.92, minor_radius=0.035, location=(0, 0, 4.5))
    rail = bpy.context.active_object
    rail.data.materials.append(mat_dark)
    rail.parent = root_obj

    # 3. ランタンハウス (Lantern House - 赤)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.52, depth=0.85, location=(0, 0, 4.72))
    lantern = bpy.context.active_object
    lantern.data.materials.append(mat_red)
    lantern.parent = root_obj

    # 4. ドーム屋根 (Dome Roof)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=0.54, location=(0, 0, 5.15))
    dome = bpy.context.active_object
    dome.scale = (1.0, 1.0, 0.55)
    dome.data.materials.append(mat_red)
    dome.parent = root_obj

    # 頂上避雷針 (Spire)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=0.6, location=(0, 0, 5.6))
    spire = bpy.context.active_object
    spire.data.materials.append(mat_dark)
    spire.parent = root_obj

    # 全メッシュ結合
    bpy.ops.object.select_all(action='DESELECT')
    for child in root_obj.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root_obj.children[0]
    bpy.ops.object.join()
    
    lh_obj = bpy.context.active_object
    lh_obj.name = "NogitaLighthouse3D"
    lh_obj.parent = None
    bpy.data.objects.remove(root_obj)
    
    # ピボットを底面に設定
    bbox = [lh_obj.matrix_world @ Vector(corner) for corner in lh_obj.bound_box]
    min_z = min(v.z for v in bbox)
    center_x = sum(v.x for v in bbox) / 8.0
    center_y = sum(v.y for v in bbox) / 8.0
    bpy.context.scene.cursor.location = Vector((center_x, center_y, min_z))
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.scene.cursor.location = Vector((0, 0, 0))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    output_fbx = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/nogita_lighthouse.fbx"
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
    print(f"[Success] Generated Nogita Lighthouse FBX: {output_fbx}")

if __name__ == "__main__":
    create_lighthouse()
