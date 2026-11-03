import bpy
import bmesh
import math
import mathutils
import random
import os

OUT_DIR = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/models/fbx"
os.makedirs(OUT_DIR, exist_ok=True)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def make_mat(name, color_rgba, roughness=0.75, metallic=0.0):
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
    return mat

def export_glb_and_fbx(base_name):
    glb_path = os.path.join(OUT_DIR, f"{base_name}.glb")
    fbx_path = os.path.join(OUT_DIR, f"{base_name}.fbx")
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format='GLB',
        export_materials='EXPORT'
    )
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_ALL',
        axis_forward='-Z',
        axis_up='Y'
    )
    print(f"Exported {base_name} (.glb & .fbx)")

# ==============================================================================
# 1. HOLLOW WOODEN ROWBOAT (frame_009.jpg complete replica, Blender Z-up)
#    X = width, Y = length (-1.45 bow to +1.45 stern), Z = height
# ==============================================================================
def build_hollow_wooden_boat():
    clear_scene()
    mat_hull_outer = make_mat("BoatHullOuter", (0.42, 0.23, 0.12, 1.0), 0.75)
    mat_hull_inner = make_mat("BoatHullInner", (0.68, 0.48, 0.30, 1.0), 0.80)
    mat_seat = make_mat("BoatSeat", (0.76, 0.56, 0.36, 1.0), 0.78)
    mat_gunwale = make_mat("BoatGunwale", (0.32, 0.17, 0.09, 1.0), 0.70)

    bm = bmesh.new()
    num_sections = 20
    half_len = 1.45
    outer_rings = []
    inner_rings = []

    for i in range(num_sections + 1):
        t = i / float(num_sections) # 0.0 (bow -Y) to 1.0 (stern +Y)
        y_len = -half_len + t * (2.0 * half_len)

        if t < 0.5:
            w = (math.sin((t / 0.5) * (math.pi * 0.5)) ** 0.72) * 0.64
        else:
            w = (1.0 - 0.32 * (((t - 0.5) / 0.5) ** 1.6)) * 0.64
        w = max(w, 0.04)

        sheer_z = 0.40 + 0.13 * ((abs(t - 0.45) / 0.55) ** 1.8)
        keel_z = 0.03 + 0.08 * ((abs(t - 0.5) / 0.5) ** 2.4)

        thick = min(0.055, w * 0.42)
        floor_z = keel_z + 0.05

        o_ring = []
        i_ring = []
        steps_arc = 8
        for j in range(steps_arc + 1):
            u = j / float(steps_arc)
            ang = math.pi * u
            side_x = -math.cos(ang)
            depth_factor = math.sin(ang)

            ox = side_x * w * (1.0 - 0.18 * (depth_factor ** 2))
            oz = sheer_z - (sheer_z - keel_z) * (depth_factor ** 0.75)

            iw = max(w - thick, 0.012)
            ix = side_x * iw * (1.0 - 0.20 * (depth_factor ** 2))
            iz = sheer_z - (sheer_z - floor_z) * (depth_factor ** 0.72)

            o_ring.append(bm.verts.new((ox, y_len, oz)))
            i_ring.append(bm.verts.new((ix, y_len, iz)))

        outer_rings.append(o_ring)
        inner_rings.append(i_ring)

    bm.verts.ensure_lookup_table()

    for i in range(num_sections):
        for j in range(8):
            f_out = bm.faces.new((
                outer_rings[i][j],
                outer_rings[i+1][j],
                outer_rings[i+1][j+1],
                outer_rings[i][j+1]
            ))
            f_out.material_index = 0
            f_out.smooth = True

            f_in = bm.faces.new((
                inner_rings[i][j+1],
                inner_rings[i+1][j+1],
                inner_rings[i+1][j],
                inner_rings[i][j]
            ))
            f_in.material_index = 1
            f_in.smooth = True

        f_rim_l = bm.faces.new((
            outer_rings[i][0],
            inner_rings[i][0],
            inner_rings[i+1][0],
            outer_rings[i+1][0]
        ))
        f_rim_l.material_index = 3

        f_rim_r = bm.faces.new((
            inner_rings[i][8],
            outer_rings[i][8],
            outer_rings[i+1][8],
            inner_rings[i+1][8]
        ))
        f_rim_r.material_index = 3

    for idx in [0, num_sections]:
        for j in range(8):
            f_cap = bm.faces.new((
                outer_rings[idx][j],
                outer_rings[idx][j+1],
                inner_rings[idx][j+1],
                inner_rings[idx][j]
            ))
            f_cap.material_index = 3

    mesh = bpy.data.meshes.new("HollowBoatMesh")
    bm.to_mesh(mesh)
    bm.free()

    boat_obj = bpy.data.objects.new("HollowBoat", mesh)
    bpy.context.collection.objects.link(boat_obj)
    for m in [mat_hull_outer, mat_hull_inner, mat_seat, mat_gunwale]:
        boat_obj.data.materials.append(m)

    # 3 Cross Seats (Thwarts) along Y
    seat_y_positions = [-0.62, 0.05, 0.72]
    seat_widths = [0.84, 1.08, 0.92]
    for sy, sw in zip(seat_y_positions, seat_widths):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, sy, 0.31))
        seat = bpy.context.active_object
        seat.scale = (sw, 0.24, 0.04)
        bpy.ops.object.transform_apply(scale=True)
        seat.data.materials.append(mat_seat)

    # Internal wooden floor slats
    for sx in [-0.16, 0.0, 0.16]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, 0.05, 0.11))
        slat = bpy.context.active_object
        slat.scale = (0.10, 1.85, 0.025)
        bpy.ops.object.transform_apply(scale=True)
        slat.data.materials.append(mat_seat)

    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = boat_obj
    bpy.ops.object.join()

    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')

    export_glb_and_fbx("nogita_wooden_boat")

# ==============================================================================
# 2. COASTAL TREE (Curved segmented trunk + layered lush fronds - frame_001.jpg)
# ==============================================================================
def build_coastal_tree():
    clear_scene()
    mat_trunk = make_mat("TreeTrunk", (0.52, 0.38, 0.27, 1.0), 0.88)
    mat_trunk_ring = make_mat("TreeTrunkRing", (0.42, 0.30, 0.21, 1.0), 0.90)
    mat_leaf_bright = make_mat("LeafBright", (0.36, 0.74, 0.22, 1.0), 0.65)
    mat_leaf_mid = make_mat("LeafMid", (0.26, 0.62, 0.18, 1.0), 0.68)
    mat_leaf_warm = make_mat("LeafWarm", (0.64, 0.72, 0.24, 1.0), 0.70)
    mat_crown = make_mat("CrownBrown", (0.38, 0.25, 0.16, 1.0), 0.85)

    objs = []
    num_segs = 11
    top_pos = mathutils.Vector((0, 0, 0))

    for i in range(num_segs):
        t = i / float(num_segs - 1)
        z_up = i * 0.26 + 0.13
        curve_x = -math.sin(t * math.pi * 0.52) * 0.80
        curve_y = math.sin(t * math.pi * 0.8) * 0.10
        r_bot = 0.20 * (1.0 - t * 0.40)
        r_top = 0.20 * (1.0 - (t + 0.06) * 0.40) * 1.08

        bpy.ops.mesh.primitive_cone_add(
            vertices=12, radius1=r_bot, radius2=r_top, depth=0.28,
            location=(curve_x, curve_y, z_up)
        )
        seg = bpy.context.active_object
        seg.rotation_euler = (0, math.radians(-15.0 * (1.0 - t * 0.3)), 0)
        seg.data.materials.append(mat_trunk if i % 2 == 0 else mat_trunk_ring)
        bpy.ops.object.shade_smooth()
        objs.append(seg)
        top_pos = mathutils.Vector((curve_x, curve_y, z_up + 0.14))

    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12, ring_count=8, radius=0.20,
        location=top_pos
    )
    crown = bpy.context.active_object
    crown.data.materials.append(mat_crown)
    objs.append(crown)

    def create_frond(angle_z, pitch_deg, length, width, mat):
        bm = bmesh.new()
        segs = 9
        for s in range(segs + 1):
            u = s / float(segs)
            dist = u * length
            arch_z = math.sin(u * math.pi * 0.65) * 0.35 - (u ** 2.2) * 0.72
            w = math.sin(u * math.pi) * width * (1.05 - 0.18 * (s % 2))
            if s == segs:
                w = 0.01
            bm.verts.new((dist, -w, arch_z))
            bm.verts.new((dist, 0.0, arch_z + 0.05 * math.sin(u * math.pi)))
            bm.verts.new((dist, w, arch_z))

        bm.verts.ensure_lookup_table()
        for s in range(segs):
            idx = s * 3
            f1 = bm.faces.new((bm.verts[idx], bm.verts[idx+3], bm.verts[idx+4], bm.verts[idx+1]))
            f2 = bm.faces.new((bm.verts[idx+1], bm.verts[idx+4], bm.verts[idx+5], bm.verts[idx+2]))
            f1.smooth = True
            f2.smooth = True

        m = bpy.data.meshes.new("FrondMesh")
        bm.to_mesh(m)
        bm.free()
        f_obj = bpy.data.objects.new("Frond", m)
        bpy.context.collection.objects.link(f_obj)
        f_obj.location = top_pos
        f_obj.rotation_euler = (0, math.radians(pitch_deg), angle_z)
        f_obj.data.materials.append(mat)
        mod = f_obj.modifiers.new("Solid", 'SOLIDIFY')
        mod.thickness = 0.025
        bpy.context.view_layer.objects.active = f_obj
        bpy.ops.object.modifier_apply(modifier="Solid")
        return f_obj

    for k in range(8):
        ang = (k / 8.0) * math.tau + 0.2
        mat = mat_leaf_bright if k % 2 == 0 else mat_leaf_mid
        objs.append(create_frond(ang, -14.0, 1.85, 0.40, mat))

    for k in range(5):
        ang = (k / 5.0) * math.tau + 0.55
        mat = mat_leaf_warm if k < 2 else mat_leaf_mid
        objs.append(create_frond(ang, 8.0, 1.50, 0.34, mat))

    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    export_glb_and_fbx("nogita_black_pine")

# ==============================================================================
# 3. FISHERMAN'S HUT / BANYA (frame_005.jpg & frame_007.jpg replica)
# ==============================================================================
def build_fishermans_banya():
    clear_scene()
    mat_wall = make_mat("BanyaWall", (0.72, 0.48, 0.36, 1.0), 0.85)
    mat_trim = make_mat("BanyaTrim", (0.45, 0.26, 0.18, 1.0), 0.80)
    mat_roof_dark = make_mat("BanyaRoofDark", (0.64, 0.36, 0.25, 1.0), 0.78)
    mat_roof_light = make_mat("BanyaRoofLight", (0.82, 0.62, 0.44, 1.0), 0.78)
    mat_door_frame = make_mat("BanyaDoorFrame", (0.32, 0.38, 0.44, 1.0), 0.75)
    mat_chimney = make_mat("BanyaChimney", (0.22, 0.24, 0.27, 1.0), 0.70)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.6, 0.0, 1.15))
    cabin = bpy.context.active_object
    cabin.scale = (3.4, 3.6, 2.3)
    bpy.ops.object.transform_apply(scale=True)
    cabin.data.materials.append(mat_wall)

    bm = bmesh.new()
    v1 = bm.verts.new((-2.3, -1.8, 2.3))
    v2 = bm.verts.new(( 1.1, -1.8, 2.3))
    v3 = bm.verts.new((-0.6, -1.8, 3.55))
    v4 = bm.verts.new((-2.3,  1.8, 2.3))
    v5 = bm.verts.new(( 1.1,  1.8, 2.3))
    v6 = bm.verts.new((-0.6,  1.8, 3.55))
    bm.faces.new((v1, v2, v3))
    bm.faces.new((v5, v4, v6))
    bm.faces.new((v1, v3, v6, v4))
    bm.faces.new((v2, v5, v6, v3))
    m_gable = bpy.data.meshes.new("Gable")
    bm.to_mesh(m_gable)
    bm.free()
    gable_obj = bpy.data.objects.new("GableWall", m_gable)
    bpy.context.collection.objects.link(gable_obj)
    gable_obj.data.materials.append(mat_wall)

    num_stripes = 7
    for side in [-1, 1]:
        for s in range(num_stripes):
            x_center = -0.6 + side * (0.12 + s * 0.28)
            z_center = 3.55 - (0.08 + s * 0.20)
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x_center, 0.0, z_center))
            plank = bpy.context.active_object
            plank.scale = (0.34, 4.15, 0.08)
            plank.rotation_euler = (0, side * math.radians(36.0), 0)
            bpy.ops.object.transform_apply(rotation=True, scale=True)
            plank.data.materials.append(mat_roof_dark if s % 2 == 0 else mat_roof_light)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.6, 0.0, 3.60))
    ridge = bpy.context.active_object
    ridge.scale = (0.20, 4.22, 0.18)
    bpy.ops.object.transform_apply(scale=True)
    ridge.data.materials.append(mat_trim)

    for s in range(6):
        y_pos = -1.5 + s * 0.60
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(1.85, y_pos, 2.15 - (s % 2)*0.01))
        porch = bpy.context.active_object
        porch.scale = (1.75, 0.58, 0.08)
        porch.rotation_euler = (0, math.radians(16.0), 0)
        bpy.ops.object.transform_apply(rotation=True, scale=True)
        porch.data.materials.append(mat_roof_dark if s % 2 == 0 else mat_roof_light)

    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.10, depth=2.0, location=(2.55, 1.55, 1.0))
    post = bpy.context.active_object
    post.data.materials.append(mat_trim)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.6, -1.82, 0.95))
    door = bpy.context.active_object
    door.scale = (0.95, 0.12, 1.85)
    bpy.ops.object.transform_apply(scale=True)
    door.data.materials.append(mat_door_frame)

    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.32, depth=0.14, location=(-0.6, -1.82, 2.75), rotation=(math.radians(90), 0, 0))
    win = bpy.context.active_object
    win.data.materials.append(mat_door_frame)

    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.09, depth=0.95, location=(0.25, 0.4, 3.45))
    chim = bpy.context.active_object
    chim.data.materials.append(mat_chimney)

    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = cabin
    bpy.ops.object.join()
    export_glb_and_fbx("nogita_banya_hut")

# ==============================================================================
# 4. UNDERWATER CORAL & SEAWEED REEF CLUSTER (frame_003.jpg & frame_009.jpg)
# ==============================================================================
def build_coral_reef_cluster():
    clear_scene()
    mat_rock_base = make_mat("ReefRock", (0.46, 0.56, 0.58, 1.0), 0.85)
    mat_coral_purple = make_mat("CoralPurple", (0.48, 0.26, 0.85, 1.0), 0.55)
    mat_coral_pink = make_mat("CoralPink", (0.86, 0.34, 0.52, 1.0), 0.55)
    mat_coral_yellow = make_mat("CoralYellow", (0.76, 0.84, 0.25, 1.0), 0.60)
    mat_seaweed = make_mat("SeaweedGreen", (0.18, 0.68, 0.32, 1.0), 0.65)

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.75, location=(0, 0, 0.15))
    rock = bpy.context.active_object
    rock.scale = (1.25, 1.05, 0.42)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    rock.data.materials.append(mat_rock_base)

    for b in range(6):
        ang = (b / 6.0) * math.tau
        tilt = math.radians(28.0 + (b % 2) * 14.0)
        bpy.ops.mesh.primitive_cone_add(
            vertices=8, radius1=0.06, radius2=0.025, depth=0.48,
            location=(-0.25 + math.cos(ang)*0.12, 0.15 + math.sin(ang)*0.12, 0.38)
        )
        branch = bpy.context.active_object
        branch.rotation_euler = (math.sin(ang)*tilt, math.cos(ang)*tilt, 0)
        bpy.ops.object.shade_smooth()
        branch.data.materials.append(mat_coral_pink)

    for t in range(5):
        ang = (t / 5.0) * math.tau + 0.4
        h = 0.28 + (t % 3) * 0.10
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=10, radius=0.075, depth=h,
            location=(0.28 + math.cos(ang)*0.14, -0.15 + math.sin(ang)*0.14, 0.28 + h*0.4)
        )
        tube = bpy.context.active_object
        tube.rotation_euler = (math.sin(ang)*0.22, math.cos(ang)*0.22, 0)
        bpy.ops.object.shade_smooth()
        tube.data.materials.append(mat_coral_purple)

    for y_idx in range(3):
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=12, ring_count=8, radius=0.18 - y_idx*0.03,
            location=(-0.05 + y_idx*0.18, 0.22 - y_idx*0.12, 0.30)
        )
        dome = bpy.context.active_object
        dome.scale = (1.1, 1.0, 0.85)
        bpy.ops.object.transform_apply(scale=True)
        bpy.ops.object.shade_smooth()
        dome.data.materials.append(mat_coral_yellow)

    for w in range(9):
        ang = (w / 9.0) * math.tau
        bm = bmesh.new()
        segs = 6
        blade_len = 0.55 + (w % 3) * 0.18
        for s in range(segs + 1):
            u = s / float(segs)
            r_out = 0.08 + u * 0.38
            z_h = 0.18 + u * blade_len
            wave = math.sin(u * math.pi * 1.5 + w) * 0.06
            bw = 0.065 * math.sin((1.0 - u * 0.7) * math.pi * 0.5)
            bm.verts.new((r_out, -bw + wave, z_h))
            bm.verts.new((r_out,  bw + wave, z_h))
        bm.verts.ensure_lookup_table()
        for s in range(segs):
            f = bm.faces.new((bm.verts[s*2], bm.verts[s*2+1], bm.verts[s*2+3], bm.verts[s*2+2]))
            f.smooth = True
        m_weed = bpy.data.meshes.new("WeedBlade")
        bm.to_mesh(m_weed)
        bm.free()
        w_obj = bpy.data.objects.new("WeedBlade", m_weed)
        bpy.context.collection.objects.link(w_obj)
        w_obj.location = (0.35 * math.cos(ang), 0.35 * math.sin(ang), 0.0)
        w_obj.rotation_euler = (0, 0, ang)
        w_obj.data.materials.append(mat_seaweed)
        mod = w_obj.modifiers.new("Solid", 'SOLIDIFY')
        mod.thickness = 0.018
        bpy.context.view_layer.objects.active = w_obj
        bpy.ops.object.modifier_apply(modifier="Solid")

    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = rock
    bpy.ops.object.join()
    export_glb_and_fbx("nogita_coral_reef")

# ==============================================================================
# 5. STYLIZED COASTAL BOULDER & CLIFF ROCK (frame_001.jpg beveled slate rock)
# ==============================================================================
def build_stylized_boulder():
    clear_scene()
    mat_rock = make_mat("CoastalSlateRock", (0.58, 0.62, 0.65, 1.0), 0.86)

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0, 0, 0.45))
    rock = bpy.context.active_object
    rock.scale = (1.35, 1.10, 0.72)
    bpy.ops.object.transform_apply(scale=True)

    bm = bmesh.new()
    bm.from_mesh(rock.data)
    for v in bm.verts:
        nx = math.sin(v.co.x * 2.5 + v.co.y * 1.8) * 0.12
        ny = math.cos(v.co.y * 2.3 - v.co.z * 2.0) * 0.12
        v.co.x += nx
        v.co.y += ny
        if v.co.z < 0.0:
            v.co.z *= 0.25
    bm.to_mesh(rock.data)
    bm.free()

    bpy.ops.object.shade_smooth()
    rock.data.materials.append(mat_rock)
    export_glb_and_fbx("nogita_coastal_boulder")

build_hollow_wooden_boat()
build_coastal_tree()
build_fishermans_banya()
build_coral_reef_cluster()
build_stylized_boulder()
print("=== ALL 5 X-VIDEO QUALITY 3D ENVIRONMENT MODELS BUILT SUCCESSFULLY ===")
