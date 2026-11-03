"""
Procedural Stylized Wooden Fishing Boat Generator for Blender 5.2
Generates a charming cozy rowboat matching the X video aesthetic.
Exports to: assets/models/fbx/nogita_wooden_boat.fbx
"""

import bpy
import bmesh
from mathutils import Vector, Matrix
import math
import os

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_boat():
    clear_scene()
    
    # 1. 船体メッシュの生成 (Sleek organic rowboat hull)
    mesh = bpy.data.meshes.new("NogitaRowboatMesh")
    obj = bpy.data.objects.new("NogitaRowboat", mesh)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    
    bm = bmesh.new()
    
    # 船体の断面リブ定義 (Z: 長さ方向, X: 幅方向, Y: 高さ方向)
    # (z_pos, width, height, keel_y)
    ribs = [
        (-1.6, 0.05, 0.65, 0.25),  # 船首 (Bow - 反り上がり)
        (-1.2, 0.45, 0.48, 0.05),
        (-0.6, 0.70, 0.42, -0.05),
        (0.0,  0.75, 0.40, -0.08), # 船央 (Midships - 最も幅広)
        (0.6,  0.70, 0.42, -0.05),
        (1.1,  0.55, 0.46, 0.02),
        (1.4,  0.42, 0.50, 0.10)   # 船尾 (Stern)
    ]
    
    rib_verts = []
    for (z, w, h, ky) in ribs:
        # 左舷、竜骨(底)、右舷、内側
        v_left_gunwale  = bm.verts.new(Vector((-w, ky + h, z)))
        v_left_chine    = bm.verts.new(Vector((-w * 0.75, ky + h * 0.3, z)))
        v_keel          = bm.verts.new(Vector((0.0, ky, z)))
        v_right_chine   = bm.verts.new(Vector((w * 0.75, ky + h * 0.3, z)))
        v_right_gunwale = bm.verts.new(Vector((w, ky + h, z)))
        rib_verts.append([v_left_gunwale, v_left_chine, v_keel, v_right_chine, v_right_gunwale])
        
    bm.verts.ensure_lookup_table()
    
    # リブ間を四角形面（Quads）で繋ぐ
    for i in range(len(rib_verts) - 1):
        r1 = rib_verts[i]
        r2 = rib_verts[i+1]
        for j in range(4):
            bm.faces.new([r1[j], r2[j], r2[j+1], r1[j+1]])
            
    # 船首と船尾の端面
    # 船尾トランサム (Stern transom)
    st = rib_verts[-1]
    bm.faces.new([st[0], st[1], st[2], st[3], st[4]])
    
    # 船体内部の厚み付け (Solidify)
    bm.normal_update()
    bmesh.ops.solidify(bm, geom=bm.faces, thickness=0.06)
    
    # 座板 (Seats / Thwarts)
    seat_positions = [-0.5, 0.2, 0.9]
    for sp in seat_positions:
        # ボックスメッシュで座板を作成
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(Vector((0, 0.22, sp))) @ Matrix.Diagonal(Vector((1.1, 0.05, 0.28, 1.0))))
        
    # 船首の係留リング台 (Bow block)
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(Vector((0, 0.55, -1.4))) @ Matrix.Diagonal(Vector((0.25, 0.15, 0.25, 1.0))))
    
    bm.to_mesh(mesh)
    bm.free()
    
    # マテリアル設定 (風化チークウッド)
    mat = bpy.data.materials.new(name="M_WeatheredWood")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.62, 0.42, 0.26, 1.0)
        bsdf.inputs['Roughness'].default_value = 0.82
    mesh.materials.append(mat)
    
    # スムースシェード
    for poly in mesh.polygons:
        poly.use_smooth = True
        
    # 原点を底面中央に設定
    bbox = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_z = min(v.z for v in bbox)
    center_x = sum(v.x for v in bbox) / 8.0
    center_y = sum(v.y for v in bbox) / 8.0
    bpy.context.scene.cursor.location = Vector((center_x, center_y, min_z))
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.scene.cursor.location = Vector((0, 0, 0))
    
    # クリーンアップ実行
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    output_fbx = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/nogita_wooden_boat.fbx"
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
    print(f"[Success] Exported stylized boat FBX to: {output_fbx}")

if __name__ == "__main__":
    create_boat()
