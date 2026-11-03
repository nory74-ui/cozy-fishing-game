extends Node3D
class_name BeachStage3D

# --- スタイライズド 3D ビーチ＆ステージビルダー（映像完全再現版） ---

# マテリアル定義
var mat_sand: StandardMaterial3D
var mat_seabed: StandardMaterial3D
var mat_rock: StandardMaterial3D
var mat_cliff_grass: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_wood_dark: StandardMaterial3D
var mat_roof: StandardMaterial3D
var mat_palm_trunk: StandardMaterial3D
var mat_palm_leaf: StandardMaterial3D
var mat_coral_purple: StandardMaterial3D
var mat_coral_yellow: StandardMaterial3D
var mat_coral_cyan: StandardMaterial3D
var mat_seaweed: StandardMaterial3D
var mat_fish_shadow: StandardMaterial3D

# 海中を回遊する小魚たち
var swimming_fish: Array[Dictionary] = []

func _ready() -> void:
	_init_materials()
	_build_terrain()
	_build_water_plane()
	_build_wooden_pier()
	_build_boathouse()
	_build_palm_trees()
	_build_underwater_reef()
	_spawn_fish_shadows()

func _process(delta: float) -> void:
	_update_swimming_fish(delta)

func _init_materials() -> void:
	# 砂浜（温かみのあるナチュラルサンドカラー）
	mat_sand = StandardMaterial3D.new()
	mat_sand.albedo_color = Color(0.86, 0.76, 0.58)
	mat_sand.roughness = 0.95

	# 海底の砂（水に濡れた深い色）
	mat_seabed = StandardMaterial3D.new()
	mat_seabed.albedo_color = Color(0.70, 0.68, 0.58)
	mat_seabed.roughness = 0.8

	# 芝生
	mat_cliff_grass = StandardMaterial3D.new()
	mat_cliff_grass.albedo_color = Color(0.38, 0.72, 0.28)
	mat_cliff_grass.roughness = 0.75

	# 岩肌・クリフ
	mat_rock = StandardMaterial3D.new()
	mat_rock.albedo_color = Color(0.64, 0.66, 0.68)
	mat_rock.roughness = 0.85

	# 木造桟橋・デッキ（板材）
	mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.68, 0.54, 0.40)
	mat_wood.roughness = 0.65

	mat_wood_dark = StandardMaterial3D.new()
	mat_wood_dark.albedo_color = Color(0.48, 0.36, 0.26)
	mat_wood_dark.roughness = 0.8

	# 屋根（赤褐色の木製スレート）
	mat_roof = StandardMaterial3D.new()
	mat_roof.albedo_color = Color(0.65, 0.38, 0.28)
	mat_roof.roughness = 0.6

	# ヤシの木（幹・葉）
	mat_palm_trunk = StandardMaterial3D.new()
	mat_palm_trunk.albedo_color = Color(0.55, 0.42, 0.30)
	mat_palm_trunk.roughness = 0.85

	mat_palm_leaf = StandardMaterial3D.new()
	mat_palm_leaf.albedo_color = Color(0.24, 0.70, 0.20)
	mat_palm_leaf.roughness = 0.55
	mat_palm_leaf.cull_mode = BaseMaterial3D.CULL_DISABLED

	# サンゴ・海藻
	mat_coral_purple = StandardMaterial3D.new()
	mat_coral_purple.albedo_color = Color(0.72, 0.28, 0.80)
	mat_coral_yellow = StandardMaterial3D.new()
	mat_coral_yellow.albedo_color = Color(0.88, 0.80, 0.25)
	mat_coral_cyan = StandardMaterial3D.new()
	mat_coral_cyan.albedo_color = Color(0.25, 0.85, 0.75)
	mat_seaweed = StandardMaterial3D.new()
	mat_seaweed.albedo_color = Color(0.16, 0.62, 0.32)
	mat_seaweed.cull_mode = BaseMaterial3D.CULL_DISABLED

	# 魚影
	mat_fish_shadow = StandardMaterial3D.new()
	mat_fish_shadow.albedo_color = Color(0.06, 0.18, 0.22, 0.8)
	mat_fish_shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_fish_shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

# --- 1. 地形（砂浜・海底・奥の崖） ---
func _build_terrain() -> void:
	var terrain_root = Node3D.new()
	terrain_root.name = "Terrain3D"
	add_child(terrain_root)

	# 砂浜（中央から右にかけて広がる斜面）
	var beach_body = StaticBody3D.new()
	var beach_box = BoxShape3D.new()
	beach_box.size = Vector3(20.0, 2.0, 40.0)
	var beach_col = CollisionShape3D.new()
	beach_col.shape = beach_box
	beach_body.add_child(beach_col)
	beach_body.position = Vector3(5.5, -0.4, 0.0)
	beach_body.rotation.z = deg_to_rad(-4.5) # 海に向かって傾斜
	
	var beach_mesh = MeshInstance3D.new()
	var box_m = BoxMesh.new()
	box_m.size = beach_box.size
	box_m.material = mat_sand
	beach_mesh.mesh = box_m
	beach_body.add_child(beach_mesh)
	terrain_root.add_child(beach_body)

	# 海底（浅瀬〜深場）
	var sea_bottom = StaticBody3D.new()
	var sb_box = BoxShape3D.new()
	sb_box.size = Vector3(35.0, 2.0, 45.0)
	var sb_col = CollisionShape3D.new()
	sb_col.shape = sb_box
	sea_bottom.add_child(sb_col)
	sea_bottom.position = Vector3(-16.0, -2.6, 0.0)

	var sb_mesh = MeshInstance3D.new()
	var sb_m = BoxMesh.new()
	sb_m.size = sb_box.size
	sb_m.material = mat_seabed
	sb_mesh.mesh = sb_m
	sea_bottom.add_child(sb_mesh)
	terrain_root.add_child(sea_bottom)

	# 右奥の崖（芝生付きの岩山）
	_build_cliff(Vector3(15.0, 2.0, -2.0), Vector3(10.0, 5.0, 36.0))

	# 外周落下防止バリア（マップ外への落下防止）
	var water_barrier = StaticBody3D.new()
	var wb_shape = WorldBoundaryShape3D.new()
	wb_shape.plane = Plane(1.0, 0.0, 0.0, 18.0) # x = -18.0 を境界
	var wb_col = CollisionShape3D.new()
	wb_col.shape = wb_shape
	water_barrier.add_child(wb_col)
	terrain_root.add_child(water_barrier)

func _build_cliff(pos: Vector3, size: Vector3) -> void:
	var cliff = StaticBody3D.new()
	cliff.position = pos
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	cliff.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	bm.material = mat_rock
	mesh_inst.mesh = bm
	cliff.add_child(mesh_inst)

	# 上部の芝生
	var grass_inst = MeshInstance3D.new()
	var gm = BoxMesh.new()
	gm.size = Vector3(size.x, 0.35, size.z)
	gm.material = mat_cliff_grass
	grass_inst.mesh = gm
	grass_inst.position.y = size.y * 0.5 + 0.15
	cliff.add_child(grass_inst)

	add_child(cliff)

# --- 2. スタイライズド水面 ---
func _build_water_plane() -> void:
	var water_mesh_inst = MeshInstance3D.new()
	water_mesh_inst.name = "StylizedWater3D"
	
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(65.0, 65.0)
	plane_mesh.subdivide_width = 70
	plane_mesh.subdivide_depth = 70
	
	var water_shader = load("res://shaders/stylized_water.gdshader")
	if water_shader:
		var shader_mat = ShaderMaterial.new()
		shader_mat.shader = water_shader
		plane_mesh.material = shader_mat
	
	water_mesh_inst.mesh = plane_mesh
	water_mesh_inst.position = Vector3(-12.0, 0.0, 0.0)
	add_child(water_mesh_inst)

# --- 3. 木造桟橋（Pier） ---
func _build_wooden_pier() -> void:
	var pier_root = Node3D.new()
	pier_root.name = "WoodenPier3D"
	add_child(pier_root)

	var pier_start = Vector3(1.8, 0.65, 0.0)
	var pier_length = 13.5
	var pier_width = 2.4
	# 砂浜から左の海に向かって真っ直ぐ伸びる
	var pier_dir = Vector3(-1.0, 0.0, 0.0)

	var pier_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(pier_length, 0.35, pier_width)
	col.shape = box_shape
	pier_body.add_child(col)
	
	var pier_center = pier_start + pier_dir * (pier_length * 0.5)
	pier_center.y = 0.5
	pier_body.position = pier_center
	
	# 両脇の落下防止ガイドコリジョン
	for side in [-1.0, 1.0]:
		var rail_col = CollisionShape3D.new()
		var rail_shape = BoxShape3D.new()
		rail_shape.size = Vector3(pier_length, 0.8, 0.2)
		rail_col.shape = rail_shape
		rail_col.position = Vector3(0.0, 0.4, side * (pier_width * 0.5))
		pier_body.add_child(rail_col)

	pier_root.add_child(pier_body)

	# 板張り（Planks）
	var plank_count = int(pier_length / 0.36)
	for i in range(plank_count):
		var plank = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.30, 0.1, pier_width + randf_range(-0.04, 0.04))
		bm.material = mat_wood if (i % 3 != 0) else mat_wood_dark
		plank.mesh = bm
		var offset_x = -pier_length * 0.5 + i * 0.36 + 0.18
		plank.position = Vector3(offset_x, 0.12, 0.0)
		plank.rotation.y = randf_range(-0.015, 0.015)
		pier_body.add_child(plank)

	# 支柱の杭（Pillars）
	var pair_count = int(pier_length / 2.0)
	for i in range(pair_count):
		var px = -pier_length * 0.5 + i * 2.0 + 0.6
		for side in [-1.0, 1.0]:
			var pillar = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.13
			cyl.bottom_radius = 0.15
			cyl.height = 3.2
			cyl.material = mat_wood_dark
			pillar.mesh = cyl
			pillar.position = Vector3(px, -1.2, side * (pier_width * 0.46))
			pier_body.add_child(pillar)

			# 杭の頭
			var cap = MeshInstance3D.new()
			var cap_cyl = CylinderMesh.new()
			cap_cyl.top_radius = 0.14
			cap_cyl.bottom_radius = 0.14
			cap_cyl.height = 0.45
			cap_cyl.material = mat_wood_dark
			cap.mesh = cap_cyl
			cap.position = Vector3(px, 0.35, side * (pier_width * 0.46))
			pier_body.add_child(cap)

	# 先端の係留ボート（小舟）
	_build_small_boat(pier_center + pier_dir * (pier_length * 0.5 + 2.0) + Vector3(0, -0.4, 0.8))

func _build_small_boat(pos: Vector3) -> void:
	var boat = Node3D.new()
	boat.name = "MooredBoat"
	boat.position = pos
	boat.rotation.y = deg_to_rad(15.0)

	var hull = MeshInstance3D.new()
	var hm = BoxMesh.new()
	hm.size = Vector3(3.0, 0.65, 1.3)
	hm.material = mat_wood
	hull.mesh = hm
	hull.position.y = 0.08
	boat.add_child(hull)

	var seat = MeshInstance3D.new()
	var sm = BoxMesh.new()
	sm.size = Vector3(0.35, 0.1, 1.25)
	sm.material = mat_wood_dark
	seat.mesh = sm
	seat.position.y = 0.3
	boat.add_child(seat)

	add_child(boat)

# --- 4. 海辺の木造小屋（Boathouse） ---
func _build_boathouse() -> void:
	var hut_root = Node3D.new()
	hut_root.name = "Boathouse3D"
	hut_root.position = Vector3(4.8, 0.65, -3.8)
	add_child(hut_root)

	# 小屋本体
	var body_static = StaticBody3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4.5, 3.0, 3.8)
	var col = CollisionShape3D.new()
	col.shape = shape
	body_static.add_child(col)

	var mesh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = shape.size
	bm.material = mat_wood
	mesh.mesh = bm
	body_static.add_child(mesh)
	body_static.position.y = 1.5
	hut_root.add_child(body_static)

	# 三角屋根
	var roof_l = MeshInstance3D.new()
	var rm1 = BoxMesh.new()
	rm1.size = Vector3(5.0, 0.18, 2.4)
	rm1.material = mat_roof
	roof_l.mesh = rm1
	roof_l.position = Vector3(0, 3.5, -0.9)
	roof_l.rotation.x = deg_to_rad(28.0)
	hut_root.add_child(roof_l)

	var roof_r = MeshInstance3D.new()
	var rm2 = BoxMesh.new()
	rm2.size = Vector3(5.0, 0.18, 2.4)
	rm2.material = mat_roof
	roof_r.mesh = rm2
	roof_r.position = Vector3(0, 3.5, 0.9)
	roof_r.rotation.x = deg_to_rad(-28.0)
	hut_root.add_child(roof_r)

	# 青いドア
	var door = MeshInstance3D.new()
	var dm = BoxMesh.new()
	dm.size = Vector3(0.08, 1.8, 0.95)
	var mat_door = StandardMaterial3D.new()
	mat_door.albedo_color = Color(0.24, 0.52, 0.72)
	dm.material = mat_door
	door.mesh = dm
	door.position = Vector3(-2.3, 0.9, 0.0)
	hut_root.add_child(door)

	# 木製デッキテラス（小屋の正面）
	var deck = StaticBody3D.new()
	var deck_shape = BoxShape3D.new()
	deck_shape.size = Vector3(2.6, 0.25, 4.6)
	var deck_col = CollisionShape3D.new()
	deck_col.shape = deck_shape
	deck.add_child(deck_col)
	var deck_m = BoxMesh.new()
	deck_m.size = deck_shape.size
	deck_m.material = mat_wood_dark
	var deck_mesh = MeshInstance3D.new()
	deck_mesh.mesh = deck_m
	deck.add_child(deck_mesh)
	deck.position = Vector3(-3.2, 0.12, 0.0)
	hut_root.add_child(deck)

	# 樽・木箱
	_spawn_barrel(hut_root, Vector3(-3.6, 0.55, 1.6))
	_spawn_crate(hut_root, Vector3(-3.8, 0.55, -1.4), Vector3(0.75, 0.75, 0.75))

func _spawn_barrel(parent: Node3D, pos: Vector3) -> void:
	var b = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.28
	cyl.height = 0.75
	cyl.material = mat_wood_dark
	b.mesh = cyl
	b.position = pos
	parent.add_child(b)

func _spawn_crate(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var c = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	bm.material = mat_wood
	c.mesh = bm
	c.position = pos
	parent.add_child(c)

# --- 5. ヤシの木（Palm Trees） ---
func _build_palm_trees() -> void:
	var tree_positions = [
		Vector3(7.5, 0.9, 3.5),   # 砂浜の右寄り
		Vector3(8.5, 1.1, -5.5),  # 小屋の奥
		Vector3(1.5, 0.5, -7.5),  # 奥の波打ち際
		Vector3(10.5, 1.2, 6.0)   # 南東の高台
	]
	for pos in tree_positions:
		_create_palm_tree(pos)

func _create_palm_tree(base_pos: Vector3) -> void:
	var tree = Node3D.new()
	tree.position = base_pos
	add_child(tree)

	var trunk_height = 4.8
	var segments = 5
	var cur_pos = Vector3.ZERO
	var lean_dir = Vector3(randf_range(-0.25, 0.05), 0, randf_range(-0.15, 0.2)).normalized()

	for s in range(segments):
		var cyl = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		var seg_h = trunk_height / float(segments)
		cm.height = seg_h
		cm.top_radius = lerp(0.26, 0.15, float(s + 1) / float(segments))
		cm.bottom_radius = lerp(0.33, 0.18, float(s) / float(segments))
		cm.material = mat_palm_trunk
		cyl.mesh = cm
		
		cur_pos += Vector3(lean_dir.x * 0.22, seg_h * 0.5, lean_dir.z * 0.22)
		cyl.position = cur_pos
		cur_pos.y += seg_h * 0.5
		tree.add_child(cyl)

	# 幹のコリジョン
	var trunk_col = StaticBody3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.32
	shape.height = 2.0
	var col = CollisionShape3D.new()
	col.shape = shape
	trunk_col.add_child(col)
	trunk_col.position.y = 1.0
	tree.add_child(trunk_col)

	# 葉（放射状に広がるヤシの葉）
	var leaf_count = 7
	for l in range(leaf_count):
		var angle = (float(l) / float(leaf_count)) * TAU
		var leaf = MeshInstance3D.new()
		var lm = BoxMesh.new()
		lm.size = Vector3(0.7, 0.04, 3.0)
		lm.material = mat_palm_leaf
		leaf.mesh = lm
		
		leaf.position = cur_pos + Vector3(sin(angle) * 1.3, -0.35, cos(angle) * 1.3)
		leaf.rotation.y = angle
		leaf.rotation.x = deg_to_rad(30.0)
		tree.add_child(leaf)

# --- 6. 水中岩礁＆サンゴ（Underwater Reef） ---
func _build_underwater_reef() -> void:
	var reef_positions = [
		{"pos": Vector3(-4.0, -1.2, 2.5), "col": mat_coral_purple},
		{"pos": Vector3(-6.5, -1.5, -1.8), "col": mat_coral_yellow},
		{"pos": Vector3(-8.0, -1.8, 3.8), "col": mat_coral_cyan},
		{"pos": Vector3(-5.0, -1.3, -4.5), "col": mat_coral_purple},
		{"pos": Vector3(-3.2, -0.9, -2.5), "col": mat_coral_cyan}
	]
	for r in reef_positions:
		var rock = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = randf_range(0.45, 0.8)
		sm.height = sm.radius * 1.5
		sm.material = mat_rock
		rock.mesh = sm
		rock.position = r["pos"]
		add_child(rock)

		var coral = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.08
		cm.height = 0.5
		cm.material = r["col"]
		coral.mesh = cm
		coral.position = r["pos"] + Vector3(0.1, sm.height * 0.45, -0.1)
		coral.rotation.z = deg_to_rad(randf_range(-15, 15))
		add_child(coral)

# --- 7. 海中を泳ぐ魚影 ---
func _spawn_fish_shadows() -> void:
	var fish_mesh = PlaneMesh.new()
	fish_mesh.size = Vector2(0.28, 0.8)
	fish_mesh.material = mat_fish_shadow

	for i in range(10):
		var fish = MeshInstance3D.new()
		fish.mesh = fish_mesh
		var center = Vector3(randf_range(-14.0, -3.5), -0.3, randf_range(-8.0, 8.0))
		fish.position = center
		add_child(fish)

		swimming_fish.append({
			"node": fish,
			"center": center,
			"radius": randf_range(1.4, 3.8),
			"speed": randf_range(0.5, 1.1) * (1.0 if randf() > 0.5 else -1.0),
			"phase": randf_range(0.0, TAU),
			"wiggle_speed": randf_range(4.0, 7.0)
		})

func _update_swimming_fish(delta: float) -> void:
	var t = Time.get_ticks_msec() / 1000.0
	for f in swimming_fish:
		f["phase"] += f["speed"] * delta
		var p = f["phase"]
		var r = f["radius"]
		var new_x = f["center"].x + cos(p) * r
		var new_z = f["center"].z + sin(p) * r
		
		var node: MeshInstance3D = f["node"]
		var forward = Vector3(-sin(p) * f["speed"], 0, cos(p) * f["speed"]).normalized()
		
		node.position.x = new_x
		node.position.z = new_z
		node.rotation.y = atan2(-forward.x, -forward.z)
		node.rotation.z = sin(t * f["wiggle_speed"]) * 0.14
