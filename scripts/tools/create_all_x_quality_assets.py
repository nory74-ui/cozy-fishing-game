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

def make_mat(name, color_rgba, roughness=0.78, metallic=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        lin_r = pow(color_rgba[0], 2.2)
        lin_g = pow(color_rgba[1], 2.2)
        lin_b = pow(color_rgba[2], 2.2)
        bsdf.inputs["Base Color"].default_value = (lin_r, lin_g, lin_b, color_rgba[3])
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return mat

def export_glb(base_name):
    glb_path = os.path.join(OUT_DIR, f"{base_name}.glb")
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format='GLB',
        export_materials='EXPORT'
    )
    print(f"Exported {base_name}.glb")

# ==============================================================================
# 1. HOLLOW WOODEN ROWBOAT / 木造和船・小舟
# ==============================================================================
def build_hollow_wooden_boat():
    clear_scene()
    mat_hull_outer = make_mat("BoatHullOuter", (0.42, 0.25, 0.14, 1.0), 0.78)
    mat_hull_inner = make_mat("BoatHullInner", (0.68, 0.49, 0.31, 1.0), 0.80)
    mat_seat = make_mat("BoatSeat", (0.76, 0.56, 0.36, 1.0), 0.78)
    mat_gunwale = make_mat("BoatGunwale", (0.30, 0.17, 0.09, 1.0), 0.72)

    bm = bmesh.new()
    num_sections = 20
    half_len = 1.45
    outer_rings = []
    inner_rings = []

    for i in range(num_sections + 1):
        t = i / float(num_sections)
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

    seat_y_positions = [-0.62, 0.05, 0.72]
    seat_widths = [0.84, 1.08, 0.92]
    for sy, sw in zip(seat_y_positions, seat_widths):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, sy, 0.31))
        seat = bpy.context.active_object
        seat.scale = (sw, 0.24, 0.04)
        bpy.ops.object.transform_apply(scale=True)
        seat.data.materials.append(mat_seat)

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

    export_glb("nogita_wooden_boat")

# ==============================================================================
# 2. JAPANESE BLACK PINE (クロマツ / 福岡・糸島 野北海岸の防風黒松)
#    Wind-sculpted curving dark pine trunk + spreading boughs + layered pine pads
# ==============================================================================
def build_japanese_black_pine():
    clear_scene()
    mat_bark_dark = make_mat("PineBarkDark", (0.28, 0.19, 0.14, 1.0), 0.90)
    mat_bark_mid = make_mat("PineBarkMid", (0.36, 0.24, 0.17, 1.0), 0.88)
    mat_pine_deep = make_mat("PineNeedleDeep", (0.14, 0.38, 0.17, 1.0), 0.72)
    mat_pine_mid = make_mat("PineNeedleMid", (0.20, 0.48, 0.20, 1.0), 0.70)
    mat_pine_bright = make_mat("PineNeedleBright", (0.28, 0.56, 0.23, 1.0), 0.68)

    objs = []

    def add_branch_tube(points, radii, mat):
        for i in range(len(points) - 1):
            p0 = mathutils.Vector(points[i])
            p1 = mathutils.Vector(points[i+1])
            r0 = radii[i]
            r1 = radii[i+1]
            diff = p1 - p0
            length = diff.length
            mid = (p0 + p1) * 0.5
            bpy.ops.mesh.primitive_cone_add(
                vertices=10, radius1=r0, radius2=r1, depth=length * 1.06,
                location=mid
            )
            seg = bpy.context.active_object
            rot_quat = diff.to_track_quat('Z', 'Y')
            seg.rotation_mode = 'QUATERNION'
            seg.rotation_quaternion = rot_quat
            seg.rotation_mode = 'XYZ'
            seg.data.materials.append(mat if i % 2 == 0 else mat_bark_mid)
            bpy.ops.object.shade_smooth()
            objs.append(seg)

    # 1. Sinuous wind-sculpted Kuromatsu main trunk (leaning gracefully toward sea -X)
    trunk_pts = [
        ( 0.00,  0.00, 0.00),
        ( 0.06, -0.04, 0.45),
        (-0.08,  0.05, 0.95),
        (-0.28,  0.08, 1.48),
        (-0.48,  0.02, 2.02),
        (-0.58, -0.04, 2.55),
        (-0.52,  0.00, 3.05)
    ]
    trunk_radii = [0.28, 0.23, 0.19, 0.16, 0.13, 0.10, 0.07]
    add_branch_tube(trunk_pts, trunk_radii, mat_bark_dark)

    # Root flares gripping the coastal sand
    for r_idx in range(4):
        ang = (r_idx / 4.0) * math.tau + 0.3
        rx = math.cos(ang) * 0.32
        ry = math.sin(ang) * 0.32
        add_branch_tube([(0, 0, 0.18), (rx, ry, -0.02)], [0.14, 0.06], mat_bark_dark)

    # 2. Spreading horizontal pine boughs (クロマツの枝張り)
    boughs = [
        # Lower seaward bough (-X, +Y)
        ([(-0.22, 0.06, 1.35), (-0.75, 0.35, 1.52), (-1.28, 0.55, 1.60)], [0.11, 0.08, 0.05]),
        # Mid right bough (+X, -Y)
        ([(-0.36, 0.05, 1.75), ( 0.18, -0.42, 1.95), ( 0.65, -0.68, 2.05)], [0.10, 0.07, 0.045]),
        # Mid-high seaward bough (-X, -Y)
        ([(-0.52, -0.01, 2.25), (-1.05, -0.45, 2.42), (-1.48, -0.62, 2.48)], [0.09, 0.065, 0.04]),
        # Upper back bough (+X, +Y)
        ([(-0.56, -0.02, 2.48), (-0.05, 0.52, 2.68), ( 0.38, 0.82, 2.75)], [0.085, 0.06, 0.04]),
        # Crown top bough
        ([(-0.52, 0.00, 2.95), (-0.78, 0.12, 3.22)], [0.07, 0.04])
    ]
    for b_pts, b_rad in boughs:
        add_branch_tube(b_pts, b_rad, mat_bark_dark)

    # 3. Layered Japanese Black Pine Foliage Pads (松の枝棚・葉むら)
    # Each pad is a horizontal layered cluster of flattened dome puffs + pine needle fan clusters
    def add_pine_cloud_pad(center, radius_xy, thickness_z, primary_mat, accent_mat):
        cx, cy, cz = center
        # Main central cushion (flattened underside, rounded top like real pruned/coastal Kuromatsu)
        sub_puffs = [
            (0.0, 0.0, 0.0, 1.0, primary_mat),
            (radius_xy * 0.48,  radius_xy * 0.25, -0.03, 0.72, primary_mat),
            (-radius_xy * 0.45, radius_xy * 0.30, -0.02, 0.75, accent_mat),
            (radius_xy * 0.32, -radius_xy * 0.45, -0.04, 0.70, primary_mat),
            (-radius_xy * 0.38,-radius_xy * 0.38, -0.02, 0.68, accent_mat),
            (0.0, 0.0, thickness_z * 0.38, 0.65, mat_pine_bright)
        ]
        for ox, oy, oz, sc, mat in sub_puffs:
            bpy.ops.mesh.primitive_ico_sphere_add(
                subdivisions=2, radius=1.0,
                location=(cx + ox, cy + oy, cz + oz)
            )
            puff = bpy.context.active_object
            puff.scale = (radius_xy * sc, radius_xy * sc * 0.92, thickness_z * sc)
            bpy.ops.object.transform_apply(scale=True)

            # Flatten bottom slightly so the pad has crisp Japanese pine shelf silhouette
            bm = bmesh.new()
            bm.from_mesh(puff.data)
            for v in bm.verts:
                if v.co.z < 0.0:
                    v.co.z *= 0.45
            bm.to_mesh(puff.data)
            bm.free()

            bpy.ops.object.shade_smooth()
            puff.data.materials.append(mat)
            objs.append(puff)

    pine_pads = [
        # Lower seaward shelf
        ((-1.25,  0.55, 1.68), 0.72, 0.32, mat_pine_deep, mat_pine_mid),
        ((-0.82,  0.38, 1.82), 0.56, 0.26, mat_pine_mid, mat_pine_bright),
        # Mid right shelf
        (( 0.62, -0.65, 2.12), 0.68, 0.30, mat_pine_deep, mat_pine_mid),
        (( 0.22, -0.38, 2.24), 0.52, 0.25, mat_pine_mid, mat_pine_bright),
        # Mid-high seaward shelf
        ((-1.42, -0.58, 2.54), 0.74, 0.32, mat_pine_deep, mat_pine_mid),
        ((-0.95, -0.35, 2.68), 0.58, 0.26, mat_pine_mid, mat_pine_bright),
        # Upper back shelf
        (( 0.35,  0.78, 2.82), 0.66, 0.28, mat_pine_deep, mat_pine_mid),
        ((-0.05,  0.45, 2.94), 0.54, 0.25, mat_pine_mid, mat_pine_bright),
        # Grand top crown canopy (主冠)
        ((-0.68,  0.08, 3.26), 0.92, 0.38, mat_pine_mid, mat_pine_bright),
        ((-0.35, -0.15, 3.12), 0.68, 0.30, mat_pine_deep, mat_pine_mid),
        ((-0.95,  0.22, 3.10), 0.64, 0.28, mat_pine_deep, mat_pine_mid)
    ]
    for center, r_xy, th_z, m1, m2 in pine_pads:
        add_pine_cloud_pad(center, r_xy, th_z, m1, m2)

    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    export_glb("nogita_black_pine")

# ==============================================================================
# 3. JAPANESE FISHERMAN'S BANYA HUT (糸島・野北の木造漁師番屋・和瓦屋根と杉板外壁)
# ==============================================================================
def build_fishermans_banya():
    clear_scene()
    mat_cedar_wall = make_mat("CedarWall", (0.52, 0.36, 0.24, 1.0), 0.86)
    mat_timber_dark = make_mat("TimberDark", (0.26, 0.17, 0.11, 1.0), 0.84)
    mat_kawara_dark = make_mat("KawaraDark", (0.22, 0.25, 0.28, 1.0), 0.68)
    mat_kawara_mid = make_mat("KawaraMid", (0.28, 0.31, 0.35, 1.0), 0.70)
    mat_shikkui = make_mat("ShikkuiWhite", (0.86, 0.84, 0.78, 1.0), 0.75)
    mat_door_wood = make_mat("DoorWood", (0.38, 0.25, 0.16, 1.0), 0.80)
    mat_window_warm = make_mat("WindowWarm", (0.92, 0.82, 0.58, 1.0), 0.45)
    mat_glass_float = make_mat("GlassFloat", (0.18, 0.64, 0.56, 1.0), 0.35)

    # Main cedar cabin body
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.6, 0.0, 1.15))
    cabin = bpy.context.active_object
    cabin.scale = (3.4, 3.6, 2.3)
    bpy.ops.object.transform_apply(scale=True)
    cabin.data.materials.append(mat_cedar_wall)

    # Corner timber pillars (柱)
    for px in [-2.28, 1.08]:
        for py in [-1.78, 1.78]:
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, py, 1.15))
            pillar = bpy.context.active_object
            pillar.scale = (0.14, 0.14, 2.32)
            bpy.ops.object.transform_apply(scale=True)
            pillar.data.materials.append(mat_timber_dark)

    # Gable walls (妻壁 - 漆喰と杉板)
    bm = bmesh.new()
    v1 = bm.verts.new((-2.3, -1.8, 2.3))
    v2 = bm.verts.new(( 1.1, -1.8, 2.3))
    v3 = bm.verts.new((-0.6, -1.8, 3.45))
    v4 = bm.verts.new((-2.3,  1.8, 2.3))
    v5 = bm.verts.new(( 1.1,  1.8, 2.3))
    v6 = bm.verts.new((-0.6,  1.8, 3.45))
    bm.faces.new((v1, v2, v3))
    bm.faces.new((v5, v4, v6))
    bm.faces.new((v1, v3, v6, v4))
    bm.faces.new((v2, v5, v6, v3))
    m_gable = bpy.data.meshes.new("Gable")
    bm.to_mesh(m_gable)
    bm.free()
    gable_obj = bpy.data.objects.new("GableWall", m_gable)
    bpy.context.collection.objects.link(gable_obj)
    gable_obj.data.materials.append(mat_cedar_wall)

    # Traditional Japanese Kawara tiled gable roof (いぶし銀の和瓦屋根)
    num_rows = 7
    for side in [-1, 1]:
        for s in range(num_rows):
            x_center = -0.6 + side * (0.12 + s * 0.28)
            z_center = 3.45 - (0.08 + s * 0.19)
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x_center, 0.0, z_center))
            plank = bpy.context.active_object
            plank.scale = (0.34, 4.18, 0.09)
            plank.rotation_euler = (0, side * math.radians(34.0), 0)
            bpy.ops.object.transform_apply(rotation=True, scale=True)
            plank.data.materials.append(mat_kawara_dark if s % 2 == 0 else mat_kawara_mid)

    # Roof ridge beam (棟瓦)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.6, 0.0, 3.52))
    ridge = bpy.context.active_object
    ridge.scale = (0.22, 4.24, 0.16)
    bpy.ops.object.transform_apply(scale=True)
    ridge.data.materials.append(mat_shikkui)

    # Side wooden awning / porch roof (庇・下屋)
    for s in range(6):
        y_pos = -1.5 + s * 0.60
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(1.85, y_pos, 2.10 - (s % 2)*0.01))
        porch = bpy.context.active_object
        porch.scale = (1.75, 0.58, 0.08)
        porch.rotation_euler = (0, math.radians(15.0), 0)
        bpy.ops.object.transform_apply(rotation=True, scale=True)
        porch.data.materials.append(mat_kawara_dark if s % 2 == 0 else mat_kawara_mid)

    # Porch support posts
    for py in [-1.55, 1.55]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.09, depth=2.0, location=(2.55, py, 1.0))
        post = bpy.context.active_object
        post.data.materials.append(mat_timber_dark)

    # Sliding lattice door (木製格子引き戸)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.6, -1.82, 0.95))
    door = bpy.context.active_object
    door.scale = (1.05, 0.12, 1.85)
    bpy.ops.object.transform_apply(scale=True)
    door.data.materials.append(mat_door_wood)

    # Warm window above/beside door
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.6, -1.83, 2.65))
    win = bpy.context.active_object
    win.scale = (0.65, 0.12, 0.45)
    bpy.ops.object.transform_apply(scale=True)
    win.data.materials.append(mat_window_warm)

    # Traditional glass fishing floats (レトロな浮き玉) hanging under porch
    for fy in [-0.6, 0.0, 0.6]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.14, location=(1.12, fy, 1.55))
        fl = bpy.context.active_object
        fl.data.materials.append(mat_glass_float)

    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = cabin
    bpy.ops.object.join()
    export_glb("nogita_banya_hut")

# ==============================================================================
# 4. GENKAI SEA ROCKY REEF & KELP/SARGASSUM FOREST
#    (玄界灘・野北の沈み瀬とホンダワラ・アラメ・ワカメ・テングサの藻場)
#    NO tropical pink/purple corals! 100% authentic Fukuoka/Itoshima marine flora!
# ==============================================================================
def build_genkai_seaweed_reef():
    clear_scene()
    mat_basalt_rock = make_mat("GenkaiBasaltRock", (0.34, 0.40, 0.42, 1.0), 0.86)
    mat_moss_rock = make_mat("GenkaiMossRock", (0.28, 0.44, 0.34, 1.0), 0.84)
    mat_hondawara = make_mat("HondawaraAmber", (0.54, 0.43, 0.15, 1.0), 0.68)
    mat_arame_kelp = make_mat("ArameKelpGreen", (0.16, 0.46, 0.24, 1.0), 0.65)
    mat_wakame = make_mat("WakameGreen", (0.24, 0.56, 0.25, 1.0), 0.65)
    mat_tengusa = make_mat("TengusaRedAlgae", (0.48, 0.18, 0.20, 1.0), 0.72)

    # 1. Main basalt reef base rock + secondary side rock
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.78, location=(0, 0, 0.15))
    rock = bpy.context.active_object
    rock.scale = (1.30, 1.10, 0.40)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    rock.data.materials.append(mat_basalt_rock)

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.48, location=(-0.42, 0.28, 0.18))
    sub_rock = bpy.context.active_object
    sub_rock.scale = (1.15, 0.95, 0.48)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    sub_rock.data.materials.append(mat_moss_rock)

    # 2. Hondawara (ホンダワラ / 玉藻) golden-brown stalks with spherical air bladders
    for h in range(7):
        ang = (h / 7.0) * math.tau + 0.2
        rx = -0.15 + math.cos(ang) * 0.28
        ry = 0.10 + math.sin(ang) * 0.25
        stalk_h = 0.48 + (h % 3) * 0.12
        bpy.ops.mesh.primitive_cone_add(
            vertices=8, radius1=0.045, radius2=0.018, depth=stalk_h,
            location=(rx, ry, 0.22 + stalk_h * 0.45)
        )
        stalk = bpy.context.active_object
        stalk.rotation_euler = (math.sin(ang) * 0.22, math.cos(ang) * 0.22, 0)
        bpy.ops.object.shade_smooth()
        stalk.data.materials.append(mat_hondawara)

        # Small air bladders / leaf clusters along the Hondawara stalk
        for b_idx in range(3):
            bz = 0.28 + b_idx * 0.13
            bx = rx + math.cos(ang + b_idx) * 0.06
            by = ry + math.sin(ang + b_idx) * 0.06
            bpy.ops.mesh.primitive_uv_sphere_add(
                segments=8, ring_count=6, radius=0.055 - b_idx * 0.008,
                location=(bx, by, bz)
            )
            bladder = bpy.context.active_object
            bladder.scale = (1.2, 0.85, 1.4)
            bpy.ops.object.transform_apply(scale=True)
            bpy.ops.object.shade_smooth()
            bladder.data.materials.append(mat_hondawara)

    # 3. Tengusa / Makusa (テングサ・マクサ：日本の紅藻) low tufts on the rock
    for t in range(4):
        ang = (t / 4.0) * math.tau + 0.5
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2, radius=0.15,
            location=(0.25 + math.cos(ang)*0.18, -0.15 + math.sin(ang)*0.18, 0.28)
        )
        tuft = bpy.context.active_object
        tuft.scale = (1.1, 1.1, 0.72)
        bpy.ops.object.transform_apply(scale=True)
        bpy.ops.object.shade_smooth()
        tuft.data.materials.append(mat_tengusa)

    # 4. Arame & Wakame (アラメ・カジメ・ワカメ) swaying green kelp blades
    for w in range(11):
        ang = (w / 11.0) * math.tau
        bm = bmesh.new()
        segs = 6
        blade_len = 0.56 + (w % 3) * 0.16
        for s in range(segs + 1):
            u = s / float(segs)
            r_out = 0.08 + u * 0.36
            z_h = 0.16 + u * blade_len
            wave = math.sin(u * math.pi * 1.6 + w) * 0.07
            bw = 0.072 * math.sin((1.0 - u * 0.65) * math.pi * 0.5)
            bm.verts.new((r_out, -bw + wave, z_h))
            bm.verts.new((r_out,  bw + wave, z_h))
        bm.verts.ensure_lookup_table()
        for s in range(segs):
            f = bm.faces.new((bm.verts[s*2], bm.verts[s*2+1], bm.verts[s*2+3], bm.verts[s*2+2]))
            f.smooth = True
        m_weed = bpy.data.meshes.new("KelpBlade")
        bm.to_mesh(m_weed)
        bm.free()
        w_obj = bpy.data.objects.new("KelpBlade", m_weed)
        bpy.context.collection.objects.link(w_obj)
        w_obj.location = (0.36 * math.cos(ang), 0.36 * math.sin(ang), 0.0)
        w_obj.rotation_euler = (0, 0, ang)
        w_obj.data.materials.append(mat_arame_kelp if w % 2 == 0 else mat_wakame)
        mod = w_obj.modifiers.new("Solid", 'SOLIDIFY')
        mod.thickness = 0.020
        bpy.context.view_layer.objects.active = w_obj
        bpy.ops.object.modifier_apply(modifier="Solid")

    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = rock
    bpy.ops.object.join()
    export_glb("nogita_coral_reef")

# ==============================================================================
# 5. STYLIZED COASTAL BOULDER & CLIFF ROCK (玄界灘の海岸岩・花崗岩)
# ==============================================================================
def build_stylized_boulder():
    clear_scene()
    mat_rock = make_mat("CoastalSlateRock", (0.56, 0.60, 0.63, 1.0), 0.86)

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
    export_glb("nogita_coastal_boulder")

build_hollow_wooden_boat()
build_japanese_black_pine()
build_fishermans_banya()
build_genkai_seaweed_reef()
build_stylized_boulder()
print("=== ALL NOGITA JAPANESE NATURAL ENVIRONMENT 3D ASSETS BUILT SUCCESSFULLY ===")
