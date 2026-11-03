import bpy
import mathutils
import math
import os

def process_tripo_model(input_fbx_path, output_glb_path, target_height):
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
    
    # 2. Cleanup Mesh Geometry
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # 3. Decimate to ~38k polys
    decimate_mod = obj.modifiers.new(name="Decimate", type='DECIMATE')
    decimate_mod.ratio = 0.08
    bpy.ops.object.modifier_apply(modifier="Decimate")
    
    # 4. Set Pivot to Bottom Center
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
    
    bpy.context.scene.cursor.location = mathutils.Vector((center_x, center_y, bottom_z))
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    
    obj.location = mathutils.Vector((0, 0, 0))
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    
    # 5. Scale to Target Height
    current_height = max_z - min_z
    if current_height > 0.001:
        scale_factor = target_height / current_height
        obj.scale = (scale_factor, scale_factor, scale_factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    # 6. Fix Materials: Keep only Base Color texture, remove Metallic/Roughness/Normal links
    #    so glTF exports clean diffuse material with Metallic=0.0, Roughness=0.80!
    for mat in obj.data.materials:
        if not mat or not mat.use_nodes:
            continue
        tree = mat.node_tree
        bsdf = tree.nodes.get("Principled BSDF")
        if bsdf:
            for input_name in ["Metallic", "Roughness", "Normal", "Specular IOR Level"]:
                inp = bsdf.inputs.get(input_name)
                if inp and inp.is_linked:
                    for link in list(inp.links):
                        tree.links.remove(link)
            if "Metallic" in bsdf.inputs:
                bsdf.inputs["Metallic"].default_value = 0.0
            if "Roughness" in bsdf.inputs:
                bsdf.inputs["Roughness"].default_value = 0.80

    # Resize any images in bpy.data.images to 1024x1024 for fast Web & Desktop loading
    for img in bpy.data.images:
        if img.size[0] > 1024 or img.size[1] > 1024:
            img.scale(1024, 1024)

    bpy.ops.object.shade_smooth()
    os.makedirs(os.path.dirname(output_glb_path), exist_ok=True)
    
    bpy.ops.export_scene.gltf(
        filepath=output_glb_path,
        use_selection=True,
        export_format='GLB',
        export_materials='EXPORT',
        export_image_format='JPEG',
        export_jpeg_quality=90
    )
    print(f"Exported clean GLB: {output_glb_path}")
    return True

barlock_raw = '/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/raw/fisherman_tripo/tripo_convert_ebdc8aba-91f5-45d3-ab02-68d56e8d512c.fbx'
barlock_out_glb = '/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/barlock_character.glb'
process_tripo_model(barlock_raw, barlock_out_glb, target_height=1.45)

cat_raw = '/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/raw/cat_tripo/tripo_convert_99d89363-d7bd-4c96-9146-c477d642dbac.fbx'
cat_out_glb = '/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx/mike_companion.glb'
process_tripo_model(cat_raw, cat_out_glb, target_height=0.42)

print("=== Clean Tripo GLB models exported with 1024x1024 BaseColor & Metallic=0.0! ===")
