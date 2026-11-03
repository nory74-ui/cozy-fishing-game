with open("/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/scripts/tools/create_all_x_quality_assets.py", "r") as f:
    code = f.read()

old_fn = """def make_mat(name, color_rgba, roughness=0.75, metallic=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color_rgba
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return mat"""

new_fn = """def make_mat(name, color_rgba, roughness=0.75, metallic=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        # Convert sRGB tuple to Blender Linear RGB so colors are rich and never bleached!
        lin_r = pow(color_rgba[0], 2.2)
        lin_g = pow(color_rgba[1], 2.2)
        lin_b = pow(color_rgba[2], 2.2)
        bsdf.inputs["Base Color"].default_value = (lin_r, lin_g, lin_b, color_rgba[3])
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return mat"""

assert old_fn in code, "old_fn not found"
code = code.replace(old_fn, new_fn)
with open("/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/scripts/tools/create_all_x_quality_assets.py", "w") as f:
    f.write(code)
print("Updated make_mat with sRGB-to-Linear conversion!")
