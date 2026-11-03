"""
Procedural Stylized 3D Character Model: Mike the Cat (Companion)
Reference: User-provided character sheet (Front / Side / Back views)
Tool: Blender 5.2 LTS via Headless Python
Exports: assets/models/fbx/mike_companion.fbx
"""

import bpy
import bmesh
from mathutils import Vector, Matrix, Euler
import math
import os

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_material(name, color, roughness=0.7):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (color[0], color[1], color[2], 1.0)
        bsdf.inputs['Roughness'].default_value = roughness
    return mat

def create_mike():
    clear_scene()
    
    # マテリアルパレット
    mat_white = create_material("M_WhiteFur", (0.96, 0.96, 0.94), 0.75) # 白毛
    mat_calico_orange = create_material("M_CalicoOrange", (0.88, 0.48, 0.18), 0.75) # 茶トラ斑
    mat_calico_black = create_material("M_CalicoBlack", (0.18, 0.16, 0.15), 0.8) # 黒斑
    mat_pink = create_material("M_PinkInner", (0.95, 0.65, 0.68), 0.5) # 耳・肉球・鼻
    mat_eyes = create_material("M_EyesGold", (0.95, 0.70, 0.10), 0.2) # 琥珀色の瞳
    mat_pupil = create_material("M_Pupil", (0.05, 0.05, 0.05), 0.1) # 瞳孔
    mat_hat = create_material("M_Hat", (0.58, 0.48, 0.32), 0.75) # 探検帽
    mat_bandana = create_material("M_Bandana", (0.95, 0.95, 0.92), 0.85) # 首バンダナ
    mat_bell = create_material("M_BellGold", (0.98, 0.82, 0.15), 0.25) # 黄金の鈴

    root_obj = bpy.data.objects.new("Mike_Root", None)
    bpy.context.scene.collection.objects.link(root_obj)

    # 1. 頭部 (Head)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=16, radius=0.28, location=(0, 0, 0.48))
    head = bpy.context.active_object
    head.name = "Head"
    head.scale = (1.10, 1.0, 0.95)
    head.data.materials.append(mat_white)
    head.parent = root_obj

    # 頭の三毛模様（茶色と黒の頭頂パッチ）
    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.18, location=(0.10, 0.02, 0.60))
    patch_orange = bpy.context.active_object
    patch_orange.scale = (0.9, 0.9, 0.6)
    patch_orange.data.materials.append(mat_calico_orange)
    patch_orange.parent = root_obj

    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.15, location=(-0.11, 0.02, 0.60))
    patch_black = bpy.context.active_object
    patch_black.scale = (0.8, 0.8, 0.6)
    patch_black.data.materials.append(mat_calico_black)
    patch_black.parent = root_obj

    # 2. 耳 (Ears)
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cone_add(radius1=0.09, depth=0.18, location=(side * 0.18, 0.02, 0.68))
        ear = bpy.context.active_object
        ear.rotation_euler = (math.radians(-10), math.radians(side * 22), 0)
        ear.data.materials.append(mat_calico_orange if side == 1 else mat_calico_black)
        ear.parent = root_obj
        # 耳の内側ピンク
        bpy.ops.mesh.primitive_cone_add(radius1=0.06, depth=0.14, location=(side * 0.18, -0.02, 0.68))
        ear_in = bpy.context.active_object
        ear_in.rotation_euler = (math.radians(-15), math.radians(side * 22), 0)
        ear_in.data.materials.append(mat_pink)
        ear_in.parent = root_obj

    # 3. 顔立ち (Eyes, Nose, Cheeks)
    # 瞳
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=10, radius=0.055, location=(side * 0.11, -0.22, 0.48))
        eye = bpy.context.active_object
        eye.data.materials.append(mat_eyes)
        eye.parent = root_obj
        # 瞳孔
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=8, radius=0.035, location=(side * 0.11, -0.25, 0.48))
        pupil = bpy.context.active_object
        pupil.data.materials.append(mat_pupil)
        pupil.parent = root_obj

    # 鼻
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.032, location=(0, -0.26, 0.44))
    nose = bpy.context.active_object
    nose.data.materials.append(mat_pink)
    nose.parent = root_obj

    # 4. 探検帽子 (Hat)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=12, radius=0.22, location=(0, 0.02, 0.66))
    hat = bpy.context.active_object
    hat.scale = (1.1, 1.15, 0.55)
    hat.data.materials.append(mat_hat)
    hat.parent = root_obj

    bpy.ops.mesh.primitive_cylinder_add(radius=0.34, depth=0.025, location=(0, 0.02, 0.62))
    hat_brim = bpy.context.active_object
    hat_brim.data.materials.append(mat_hat)
    hat_brim.parent = root_obj

    # 5. 白い首バンダナ ＆ 黄金の鈴 (Bandana & Golden Bell)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.18, minor_radius=0.04, location=(0, 0, 0.32))
    bandana = bpy.context.active_object
    bandana.data.materials.append(mat_bandana)
    bandana.parent = root_obj

    # 黄金の鈴 (Bell)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=10, radius=0.055, location=(0, -0.18, 0.28))
    bell = bpy.context.active_object
    bell.data.materials.append(mat_bell)
    bell.parent = root_obj

    # 6. ぽってりした胴体 (Body / Torso)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=14, radius=0.26, location=(0, 0.04, 0.22))
    body = bpy.context.active_object
    body.scale = (1.05, 1.15, 1.15)
    body.data.materials.append(mat_white)
    body.parent = root_obj

    # 背中の三毛パッチ
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=10, radius=0.18, location=(0.06, 0.16, 0.24))
    back_orange = bpy.context.active_object
    back_orange.data.materials.append(mat_calico_orange)
    back_orange.parent = root_obj

    # 7. 手足 (Paws)
    # 前足（招き猫ポーズ：左手を可愛く上げている）
    # 左手（上げ手）
    bpy.ops.mesh.primitive_cylinder_add(radius=0.065, depth=0.22, location=(-0.18, -0.12, 0.36))
    paw_l = bpy.context.active_object
    paw_l.rotation_euler = (math.radians(-45), 0, math.radians(-30))
    paw_l.data.materials.append(mat_white)
    paw_l.parent = root_obj

    # 肉球パッド
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=8, radius=0.04, location=(-0.24, -0.19, 0.44))
    pad = bpy.context.active_object
    pad.data.materials.append(mat_pink)
    pad.parent = root_obj

    # 右手（接地）
    bpy.ops.mesh.primitive_cylinder_add(radius=0.065, depth=0.20, location=(0.14, -0.12, 0.12))
    paw_r = bpy.context.active_object
    paw_r.data.materials.append(mat_white)
    paw_r.parent = root_obj

    # 後ろ足（座り姿）
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=10, radius=0.10, location=(side * 0.16, 0.10, 0.10))
        hind = bpy.context.active_object
        hind.scale = (1.1, 1.3, 0.8)
        hind.data.materials.append(mat_calico_orange if side == -1 else mat_white)
        hind.parent = root_obj

    # 8. 愛らしいしっぽ (Tail - 立ち上がりカーブ)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=0.32, location=(0, 0.25, 0.24))
    tail = bpy.context.active_object
    tail.rotation_euler = (math.radians(35), 0, 0)
    tail.data.materials.append(mat_calico_orange)
    tail.parent = root_obj

    # 全メッシュを1つのオブジェクトに結合
    bpy.ops.object.select_all(action='DESELECT')
    for child in root_obj.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root_obj.children[0]
    bpy.ops.object.join()
    
    char_obj = bpy.context.active_object
    char_obj.name = "CompanionMike3D"
    char_obj.parent = None
    bpy.data.objects.remove(root_obj)
    
    # ピボットを足元接地位置に設定
    bbox = [char_obj.matrix_world @ Vector(corner) for corner in char_obj.bound_box]
    min_z = min(v.z for v in bbox)
    center_x = sum(v.x for v in bbox) / 8.0
    center_y = sum(v.y for v in bbox) / 8.0
    bpy.context.scene.cursor.location = Vector((center_x, center_y, min_z))
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.scene.cursor.location = Vector((0, 0, 0))
    
    # トランスフォーム適用
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    # FBXエクスポート
    output_fbx = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/mike_companion.fbx"
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
    print(f"[Success] Generated & Exported Mike the Cat 3D FBX: {output_fbx}")

if __name__ == "__main__":
    create_mike()
