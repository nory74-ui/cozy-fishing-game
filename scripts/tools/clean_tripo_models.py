import bpy
import mathutils
import math
import os
import shutil

def process_tripo_model(input_fbx_path, output_fbx_path, output_glb_path, target_height, flip_y=False):
    print(f"=== Processing Tripo Model: {input_fbx_path} ===")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    
    # 1. Import Tripo FBX
    bpy.ops.import_scene.fbx(filepath=input_fbx_path)
    
    mesh_objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not mesh_objs:
        print("ERROR: No mesh object found!")
        return False
        
    obj = mesh_objs[0]
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    
    print(f"Original Mesh: {obj.name}, Verts: {len(obj.data.vertices)}, Polys: {len(obj.data.polygons)}")
    print(f"Original Dimensions: {obj.dimensions}")
    
    # 2. Cleanup Mesh Geometry (Merge by distance)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # 3. Decimate (Retain visual quality while optimizing for realtime 60fps)
    # Tripo models have ~500k polygons, reduce to ~35k polys
    decimate_mod = obj.modifiers.new(name="Decimate", type='DECIMATE')
    decimate_mod.ratio = 0.08 # ~40,000 polys
    bpy.ops.object.modifier_apply(modifier="Decimate")
    
    print(f"Decimated Mesh: Verts: {len(obj.data.vertices)}, Polys: {len(obj.data.polygons)}")
    
    # 4. Set Pivot to Bottom Center (Ground contact)
    bbox_corners = [obj.matrix_world @ mathutils.Vector(corner) for corner in obj.bound_box]
    min_x = min(c.x for c in bbox_corners)
    max_x = max(c.x for c in bbox_corners)
    min_y = min(c.y for c in bbox_corners)
    max_y = max(c.y for c in bbox_corners)
    min_z = min(c.z for c in bbox_corners)
    max_z = max(c.z for c in bbox_corners)
    
    center_x = (min_x + max_x) * 0.5
    center_y = (min_y + max_y) * 0.5
    bottom_z = min_z
    
    # Move origin to bottom center
    bpy.context.scene.cursor.location = mathutils.Vector((center_x, center_y, bottom_z))
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    
    # Center object at world (0,0,0)
    obj.location = mathutils.Vector((0, 0, 0))
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    
    # 5. Scale to Target Height
    current_height = max_z - min_z
    if current_height > 0.001:
        scale_factor = target_height / current_height
        obj.scale = (scale_factor, scale_factor, scale_factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        print(f"Scaled by {scale_factor:.4f} to height {target_height}m. New dims: {obj.dimensions}")

    # 6. Ensure textures are relative and textures folder copied alongside
    os.makedirs(os.path.dirname(output_fbx_path), exist_ok=True)
    
    # Apply Smooth Shading
    bpy.ops.object.shade_smooth()
    
    # 7. Export FBX
    bpy.ops.export_scene.fbx(
        filepath=output_fbx_path,
        use_selection=True,
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_ALL',
        axis_forward='-Z',
        axis_up='Y',
        path_mode='COPY',
        embed_textures=True
    )
    print(f"Exported FBX: {output_fbx_path}")
    
    # Also export GLB (Godot 4 native standard)
    if output_glb_path:
        bpy.ops.export_scene.gltf(
            filepath=output_glb_path,
            use_selection=True,
            export_format='GLB',
            export_materials='EXPORT',
            export_image_format='AUTO'
        )
        print(f"Exported GLB: {output_glb_path}")
        
    return True

# Run for Barlock
barlock_raw = '/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/raw/fisherman_tripo/tripo_convert_ebdc8aba-91f5-45d3-ab02-68d56e8d512c.fbx'
barlock_out_fbx = '/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/barlock_character.fbx'
barlock_out_glb = '/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/barlock_character.glb'
process_tripo_model(barlock_raw, barlock_out_fbx, barlock_out_glb, target_height=1.45)

# Run for Mike Cat
cat_raw = '/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/raw/cat_tripo/tripo_convert_99d89363-d7bd-4c96-9146-c477d642dbac.fbx'
cat_out_fbx = '/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/mike_companion.fbx'
cat_out_glb = '/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/mike_companion.glb'
process_tripo_model(cat_raw, cat_out_fbx, cat_out_glb, target_height=0.42)

print("=== All Tripo models successfully cleaned and exported! ===")
