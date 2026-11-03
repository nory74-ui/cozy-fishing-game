"""
Procedural Stylized 3D Character Model: Captain Barlock
Reference: User-provided character sheet (Front / Side / Back views)
Tool: Blender 5.2 LTS via Headless Python
Exports: assets/models/fbx/barlock_character.fbx
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

def create_barlock():
    clear_scene()
    
    # マテリアルパレット（三面図に完全忠実）
    mat_hat = create_material("M_Hat", (0.58, 0.48, 0.32), 0.75)      # カーキベージュ
    mat_hat_brim = create_material("M_HatBrim", (0.50, 0.40, 0.26), 0.8) # つば
    mat_skin = create_material("M_Skin", (0.96, 0.78, 0.65), 0.6)     # 明るい肌色
    mat_beard = create_material("M_Beard", (0.24, 0.16, 0.10), 0.85)  # 濃い茶色のヒゲ
    mat_nose = create_material("M_Nose", (0.88, 0.38, 0.30), 0.5)     # 赤い丸鼻
    mat_towel = create_material("M_Towel", (0.92, 0.92, 0.90), 0.9)   # 白い首タオル
    mat_shirt_blue = create_material("M_ShirtBlue", (0.16, 0.45, 0.82), 0.7) # 青ボーダー
    mat_shirt_white = create_material("M_ShirtWhite", (0.94, 0.94, 0.92), 0.7) # 白ボーダー
    mat_vest = create_material("M_Vest", (0.62, 0.48, 0.30), 0.8)     # フィッシングベスト
    mat_pants = create_material("M_Pants", (0.38, 0.30, 0.22), 0.85)  # ズボン
    mat_boots = create_material("M_Boots", (0.22, 0.14, 0.10), 0.5)   # 長靴
    mat_gold = create_material("M_Gold", (0.95, 0.75, 0.15), 0.35)    # バッジ・リール
    mat_pouch = create_material("M_Pouch", (0.35, 0.72, 0.88), 0.6)   # 水色魚ポシェット

    root_obj = bpy.data.objects.new("Barlock_Root", None)
    bpy.context.scene.collection.objects.link(root_obj)

    # 1. 頭部 (Head)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=16, radius=0.34, location=(0, 0, 1.25))
    head = bpy.context.active_object
    head.name = "Head"
    head.scale = (1.05, 0.98, 1.0)
    head.data.materials.append(mat_skin)
    head.parent = root_obj

    # 2. 豊かな立体的ヒゲ (Beard & Moustache)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=0.30, location=(0, -0.12, 1.12))
    beard = bpy.context.active_object
    beard.name = "Beard"
    beard.scale = (1.15, 0.95, 0.85)
    beard.data.materials.append(mat_beard)
    beard.parent = root_obj

    # 口ヒゲ (Moustache)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.10, depth=0.36, location=(0, -0.28, 1.22))
    mustache = bpy.context.active_object
    mustache.name = "Moustache"
    mustache.rotation_euler = (0, math.radians(90), 0)
    mustache.scale = (0.6, 0.9, 1.1)
    mustache.data.materials.append(mat_beard)
    mustache.parent = root_obj

    # 3. 赤い丸鼻 (Round Red Nose)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=10, radius=0.08, location=(0, -0.32, 1.28))
    nose = bpy.context.active_object
    nose.name = "Nose"
    nose.scale = (1.1, 0.9, 0.9)
    nose.data.materials.append(mat_nose)
    nose.parent = root_obj

    # 瞳 (Eyes)
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.04, location=(side * 0.12, -0.30, 1.34))
        eye = bpy.context.active_object
        eye.data.materials.append(mat_beard)
        eye.parent = root_obj

    # 4. 探検帽子 (Safari Hat)
    # クラウン (Dome)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=14, radius=0.38, location=(0, 0, 1.48))
    hat_dome = bpy.context.active_object
    hat_dome.name = "Hat_Dome"
    hat_dome.scale = (1.05, 1.08, 0.75)
    hat_dome.data.materials.append(mat_hat)
    hat_dome.parent = root_obj

    # つば (Brim)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.62, depth=0.04, location=(0, 0, 1.40))
    hat_brim = bpy.context.active_object
    hat_brim.name = "Hat_Brim"
    hat_brim.scale = (1.05, 1.15, 1.0)
    hat_brim.rotation_euler = (math.radians(-6), 0, 0)
    hat_brim.data.materials.append(mat_hat_brim)
    hat_brim.parent = root_obj

    # お魚ワッペンバッジ
    bpy.ops.mesh.primitive_cube_add(size=0.08, location=(0, -0.38, 1.48))
    badge = bpy.context.active_object
    badge.scale = (1.2, 0.2, 0.9)
    badge.data.materials.append(mat_gold)
    badge.parent = root_obj

    # 5. 白い首掛けタオル (Towel around neck)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.28, minor_radius=0.07, location=(0, 0, 1.04))
    towel_neck = bpy.context.active_object
    towel_neck.scale = (1.05, 1.0, 0.8)
    towel_neck.data.materials.append(mat_towel)
    towel_neck.parent = root_obj
    # 前に垂れるタオルの端
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(side * 0.14, -0.25, 0.88))
        towel_flap = bpy.context.active_object
        towel_flap.scale = (0.08, 0.04, 0.24)
        towel_flap.data.materials.append(mat_towel)
        towel_flap.parent = root_obj

    # 6. 胴体・フィッシングベスト (Body / Torso & Vest)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=16, radius=0.45, location=(0, 0, 0.78))
    body = bpy.context.active_object
    body.name = "Torso"
    body.scale = (1.02, 0.92, 1.12)
    body.data.materials.append(mat_vest)
    body.parent = root_obj

    # 腕・ボーダーシャツの袖 (Arms)
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=0.48, location=(side * 0.44, 0, 0.76))
        arm = bpy.context.active_object
        arm.rotation_euler = (math.radians(10), 0, math.radians(side * -18))
        arm.data.materials.append(mat_shirt_blue)
        arm.parent = root_obj
        # 手
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.10, location=(side * 0.52, -0.05, 0.52))
        hand = bpy.context.active_object
        hand.data.materials.append(mat_skin)
        hand.parent = root_obj

    # 7. 脚・ズボン & 長靴 (Pants & Boots)
    for side in [-1, 1]:
        # ズボン
        bpy.ops.mesh.primitive_cylinder_add(radius=0.16, depth=0.35, location=(side * 0.18, 0, 0.42))
        leg = bpy.context.active_object
        leg.data.materials.append(mat_pants)
        leg.parent = root_obj
        # ブーツ
        bpy.ops.mesh.primitive_cylinder_add(radius=0.17, depth=0.30, location=(side * 0.18, -0.04, 0.18))
        boot = bpy.context.active_object
        boot.scale = (1.0, 1.25, 1.0)
        boot.data.materials.append(mat_boots)
        boot.parent = root_obj

    # 8. お魚ポシェット (Fish Pouch on hip)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.14, location=(0.38, -0.15, 0.65))
    pouch = bpy.context.active_object
    pouch.name = "FishPouch"
    pouch.scale = (0.7, 1.2, 0.9)
    pouch.data.materials.append(mat_pouch)
    pouch.parent = root_obj

    # 9. 釣り竿 (Fishing Rod on back)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.025, depth=1.85, location=(-0.25, 0.32, 1.15))
    rod = bpy.context.active_object
    rod.name = "FishingRod"
    rod.rotation_euler = (math.radians(-25), math.radians(12), 0)
    mat_rod = create_material("M_Rod", (0.28, 0.22, 0.18), 0.5)
    rod.data.materials.append(mat_rod)
    rod.parent = root_obj

    # 全メッシュを1つのオブジェクトに結合
    bpy.ops.object.select_all(action='DESELECT')
    for child in root_obj.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root_obj.children[0]
    bpy.ops.object.join()
    
    char_obj = bpy.context.active_object
    char_obj.name = "CaptainBarlock3D"
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
    output_fbx = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/barlock_character.fbx"
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
    print(f"[Success] Generated & Exported Captain Barlock 3D FBX: {output_fbx}")

if __name__ == "__main__":
    create_barlock()
