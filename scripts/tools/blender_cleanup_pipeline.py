"""
Blender 3D Model Cleanup & Optimization Pipeline for Antigravity / Godot
Supports: GLB, GLTF, OBJ, FBX -> Cleaned FBX & GLTF

Usage:
  /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/tools/blender_cleanup_pipeline.py -- <input_file> <output_fbx_or_gltf> [decimate_ratio]
"""

import sys
import os
import bpy
import bmesh
from mathutils import Vector

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def import_model(filepath):
    ext = os.path.splitext(filepath)[1].lower()
    print(f"[Blender Pipeline] Importing: {filepath} ({ext})")
    if ext in ['.glb', '.gltf']:
        bpy.ops.import_scene.gltf(filepath=filepath)
    elif ext == '.obj':
        bpy.ops.wm.obj_import(filepath=filepath)
    elif ext == '.fbx':
        bpy.ops.import_scene.fbx(filepath=filepath)
    else:
        raise ValueError(f"Unsupported file format: {ext}")

def cleanup_mesh(obj, decimate_ratio=0.5):
    print(f"[Blender Pipeline] Cleaning up object: {obj.name}")
    
    # オブジェクトを選択
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    
    # 1. トランスフォームの適用 (Apply Scale & Rotation)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    # 2. エディットモードでの頂点クリーンアップ
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(obj.data)
    
    # 重複頂点の結合 (Merge by distance)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    
    # 浮遊ゴミ・孤立メッシュの削除 (Delete loose geometry)
    loose_verts = [v for v in bm.verts if not v.link_edges]
    bmesh.ops.delete(bm, geom=loose_verts, context='VERTS')
    loose_edges = [e for e in bm.edges if not e.link_faces]
    bmesh.ops.delete(bm, geom=loose_edges, context='EDGES')
    
    # 法線の外側再計算 (Recalculate Outside Normals)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # 3. デシメーション (ポリゴン削減・最適化)
    if decimate_ratio < 0.99:
        mod = obj.modifiers.new(name="Decimate_Auto", type='DECIMATE')
        mod.ratio = max(0.05, min(1.0, decimate_ratio))
        bpy.ops.object.modifier_apply(modifier=mod.name)
        print(f"[Blender Pipeline] Decimated with ratio: {mod.ratio}")
        
    # 4. 原点（ピボット）を底面・接地面に配置 (Set Origin to Bottom Center)
    bbox = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    min_z = min(v.z for v in bbox)
    center_x = sum(v.x for v in bbox) / 8.0
    center_y = sum(v.y for v in bbox) / 8.0
    
    # カーソルを底面中央に移動して原点を設定
    bpy.context.scene.cursor.location = Vector((center_x, center_y, min_z))
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.scene.cursor.location = Vector((0, 0, 0))

def export_model(output_path):
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    ext = os.path.splitext(output_path)[1].lower()
    print(f"[Blender Pipeline] Exporting to: {output_path} ({ext})")
    
    if ext == '.fbx':
        bpy.ops.export_scene.fbx(
            filepath=output_path,
            use_selection=False,
            apply_unit_scale=True,
            apply_scale_options='FBX_SCALE_ALL',
            bake_space_transform=True,
            axis_forward='-Z',
            axis_up='Y'
        )
    elif ext in ['.glb', '.gltf']:
        bpy.ops.export_scene.gltf(
            filepath=output_path,
            export_format='GLB' if ext == '.glb' else 'GLTF_SEPARATE',
            use_selection=False
        )
    else:
        raise ValueError(f"Unsupported export format: {ext}")

def main():
    args = sys.argv
    if "--" not in args:
        print("[Blender Pipeline] Usage: blender -b -P script.py -- <input_file> <output_file> [decimate_ratio]")
        return
    
    custom_args = args[args.index("--") + 1:]
    if len(custom_args) < 2:
        print("[Blender Pipeline] Error: input_file and output_file are required.")
        return
        
    input_file = custom_args[0]
    output_file = custom_args[1]
    decimate_ratio = float(custom_args[2]) if len(custom_args) > 2 else 0.5
    
    clear_scene()
    import_model(input_file)
    
    # シーン内のすべてのメッシュをクリーンアップ
    mesh_objs = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    for obj in mesh_objs:
        cleanup_mesh(obj, decimate_ratio)
        
    export_model(output_file)
    print(f"[Blender Pipeline] Successfully processed and exported: {output_file}")

if __name__ == "__main__":
    main()
