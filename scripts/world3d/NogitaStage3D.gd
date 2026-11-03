extends Node3D
class_name NogitaStage3D

# --- 福岡県糸島・野北海岸 3Dステージビルダー（Xの動画クオリティ完全再現版） ---

var mat_sand: StandardMaterial3D
var mat_seabed: StandardMaterial3D
var mat_rock: StandardMaterial3D
var mat_grass: StandardMaterial3D
var mat_pier_concrete: StandardMaterial3D
var mat_pier_stone: StandardMaterial3D
var mat_wood_plank: StandardMaterial3D
var mat_wood_plank_alt: StandardMaterial3D
var mat_wood_post: StandardMaterial3D
var mat_post_cap: StandardMaterial3D
var mat_rope: StandardMaterial3D
var mat_crab: StandardMaterial3D
var mat_pebble: StandardMaterial3D
var mat_bush_green: StandardMaterial3D
var mat_bush_olive: StandardMaterial3D
var mat_flower_white: StandardMaterial3D
var mat_flower_yellow: StandardMaterial3D

var lighthouse_beam: SpotLight3D
var moored_boat: Node3D
var swimming_fish: Array[Dictionary] = []

func _ready() -> void:
	_init_materials()
	_build_terrain()
	_build_water_plane()
	_build_wooden_banya_deck_and_pier()
	_build_nogita_pier()
	_build_white_lighthouse()
	_build_tetrapods()
	_build_japanese_black_pines()
	_build_coral_and_seaweed_garden()
	_build_beach_decorations()
	_spawn_fish_shadows()

func _process(delta: float) -> void:
	_update_swimming_fish(delta)
	if lighthouse_beam:
		lighthouse_beam.rotation.y += delta * 0.8
	if moored_boat:
		var t = Time.get_ticks_msec() / 1000.0
		moored_boat.position.y = 0.02 + sin(t * 1.7) * 0.025
		moored_boat.rotation.z = sin(t * 1.3) * 0.035
		moored_boat.rotation.x = cos(t * 1.0) * 0.025

func _init_materials() -> void:
	mat_sand = StandardMaterial3D.new()
	mat_sand.albedo_color = Color(0.88, 0.78, 0.56)
	mat_sand.roughness = 0.92

	mat_seabed = StandardMaterial3D.new()
	mat_seabed.albedo_color = Color(0.76, 0.74, 0.60)
	mat_seabed.roughness = 0.88

	mat_rock = StandardMaterial3D.new()
	mat_rock.albedo_color = Color(0.56, 0.60, 0.64)
	mat_rock.roughness = 0.86

	mat_grass = StandardMaterial3D.new()
	mat_grass.albedo_color = Color(0.32, 0.64, 0.22)
	mat_grass.roughness = 0.84

	mat_pier_concrete = StandardMaterial3D.new()
	mat_pier_concrete.albedo_color = Color(0.76, 0.75, 0.72)
	mat_pier_concrete.roughness = 0.90

	mat_pier_stone = StandardMaterial3D.new()
	mat_pier_stone.albedo_color = Color(0.58, 0.57, 0.54)
	mat_pier_stone.roughness = 0.90

	mat_wood_plank = StandardMaterial3D.new()
	mat_wood_plank.albedo_color = Color(0.56, 0.40, 0.28)
	mat_wood_plank.roughness = 0.85

	mat_wood_plank_alt = StandardMaterial3D.new()
	mat_wood_plank_alt.albedo_color = Color(0.64, 0.47, 0.34)
	mat_wood_plank_alt.roughness = 0.85

	mat_wood_post = StandardMaterial3D.new()
	mat_wood_post.albedo_color = Color(0.42, 0.29, 0.20)
	mat_wood_post.roughness = 0.88

	mat_post_cap = StandardMaterial3D.new()
	mat_post_cap.albedo_color = Color(0.84, 0.76, 0.64)
	mat_post_cap.roughness = 0.78

	mat_rope = StandardMaterial3D.new()
	mat_rope.albedo_color = Color(0.78, 0.70, 0.52)
	mat_rope.roughness = 0.88

	mat_crab = StandardMaterial3D.new()
	mat_crab.albedo_color = Color(0.86, 0.26, 0.18)
	mat_crab.roughness = 0.55

	mat_pebble = StandardMaterial3D.new()
	mat_pebble.albedo_color = Color(0.54, 0.62, 0.64)
	mat_pebble.roughness = 0.82

	mat_bush_green = StandardMaterial3D.new()
	mat_bush_green.albedo_color = Color(0.26, 0.58, 0.22)
	mat_bush_green.roughness = 0.80

	mat_bush_olive = StandardMaterial3D.new()
	mat_bush_olive.albedo_color = Color(0.68, 0.64, 0.26)
	mat_bush_olive.roughness = 0.82

	mat_flower_white = StandardMaterial3D.new()
	mat_flower_white.albedo_color = Color(0.98, 0.98, 0.95)
	mat_flower_white.roughness = 0.50

	mat_flower_yellow = StandardMaterial3D.new()
	mat_flower_yellow.albedo_color = Color(0.95, 0.82, 0.22)
	mat_flower_yellow.roughness = 0.50

# --- 1. 広大でシームレスな地形（120m × 160m：画面上下の切れを完全解消） ---
func _build_terrain() -> void:
	var terrain_root = Node3D.new()
	terrain_root.name = "Terrain3D"
	add_child(terrain_root)

	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var res_x = 120
	var res_z = 160
	var min_x = -65.0
	var max_x = 55.0
	var min_z = -80.0
	var max_z = 80.0

	var step_x = (max_x - min_x) / float(res_x)
	var step_z = (max_z - min_z) / float(res_z)

	# Xの動画（frame_001 / frame_003 / frame_009）完全準拠のカラーパレット（白飛びしない豊かな発色）
	var col_deep_seabed = Color(0.24, 0.50, 0.44) # 深みのあるターコイズ砂底
	var col_wet_sand = Color(0.60, 0.49, 0.32)    # 波打ち際のしっとりした濡れ砂
	var col_dry_sand = Color(0.76, 0.65, 0.42)    # 温かみのあるゴールドサンド
	var col_grass = Color(0.22, 0.46, 0.14)       # 深みのある海浜草地グリーン

	for iz in range(res_z):
		for ix in range(res_x):
			var x0 = min_x + ix * step_x
			var x1 = min_x + (ix + 1) * step_x
			var z0 = min_z + iz * step_z
			var z1 = min_z + (iz + 1) * step_z

			var p00 = Vector3(x0, _get_terrain_height(x0, z0), z0)
			var p10 = Vector3(x1, _get_terrain_height(x1, z0), z0)
			var p01 = Vector3(x0, _get_terrain_height(x0, z1), z1)
			var p11 = Vector3(x1, _get_terrain_height(x1, z1), z1)

			var c00 = _get_terrain_color(x0, z0, col_deep_seabed, col_wet_sand, col_dry_sand, col_grass)
			var c10 = _get_terrain_color(x1, z0, col_deep_seabed, col_wet_sand, col_dry_sand, col_grass)
			var c01 = _get_terrain_color(x0, z1, col_deep_seabed, col_wet_sand, col_dry_sand, col_grass)
			var c11 = _get_terrain_color(x1, z1, col_deep_seabed, col_wet_sand, col_dry_sand, col_grass)

			surface_tool.set_color(c00)
			surface_tool.set_uv(Vector2((x0 - min_x) / 4.0, (z0 - min_z) / 4.0))
			surface_tool.add_vertex(p00)

			surface_tool.set_color(c10)
			surface_tool.set_uv(Vector2((x1 - min_x) / 4.0, (z0 - min_z) / 4.0))
			surface_tool.add_vertex(p10)

			surface_tool.set_color(c11)
			surface_tool.set_uv(Vector2((x1 - min_x) / 4.0, (z1 - min_z) / 4.0))
			surface_tool.add_vertex(p11)

			surface_tool.set_color(c00)
			surface_tool.set_uv(Vector2((x0 - min_x) / 4.0, (z0 - min_z) / 4.0))
			surface_tool.add_vertex(p00)

			surface_tool.set_color(c11)
			surface_tool.set_uv(Vector2((x1 - min_x) / 4.0, (z1 - min_z) / 4.0))
			surface_tool.add_vertex(p11)

			surface_tool.set_color(c01)
			surface_tool.set_uv(Vector2((x0 - min_x) / 4.0, (z1 - min_z) / 4.0))
			surface_tool.add_vertex(p01)

	surface_tool.generate_normals()
	surface_tool.generate_tangents()
	var terrain_mesh = surface_tool.commit()

	var mat_terrain = StandardMaterial3D.new()
	mat_terrain.vertex_color_use_as_albedo = true
	mat_terrain.roughness = 0.90

	var terrain_inst = MeshInstance3D.new()
	terrain_inst.mesh = terrain_mesh
	terrain_inst.material_override = mat_terrain
	terrain_root.add_child(terrain_inst)

	var terrain_body = StaticBody3D.new()
	terrain_body.collision_layer = 2
	terrain_body.collision_mask = 0
	var col_shape = CollisionShape3D.new()
	col_shape.shape = terrain_mesh.create_trimesh_shape()
	terrain_body.add_child(col_shape)
	terrain_root.add_child(terrain_body)

	_build_natural_beach_features(terrain_root)

# 汀線（水面 y=0 と交差する X 座標の緩やかな自然カーブ）
func _get_shoreline_x(z: float) -> float:
	return 0.6 + sin(z * 0.16) * 1.1 + cos(z * 0.09 + 0.5) * 0.6

# 座標(x, z)における標高 y の計算
func _get_terrain_height(x: float, z: float) -> float:
	var shore_x = _get_shoreline_x(z)
	var d = x - shore_x
	if d < 0.0:
		# 遠浅の海底（エメラルドグリーンの浅瀬が広く続くよう緩やかに深くなる）
		return max(d * 0.095 - 0.32 * (1.0 - exp(d * 0.14)), -2.6)
	elif d < 5.2:
		# 歩きやすいなだらかなゴールデンサンドビーチ
		return d * 0.085
	else:
		# 草地と奥の海岸岩壁へのなだらかな隆起
		var d_grass = d - 5.2
		return 0.442 + d_grass * 0.16 + sin(z * 0.25) * 0.06

# 頂点カラーのブレンド（草地の境界を有機的に波打たせる）
func _get_terrain_color(x: float, z: float, c_seabed: Color, c_wet: Color, c_dry: Color, c_grass: Color) -> Color:
	var shore_x = _get_shoreline_x(z)
	var d = x - shore_x
	var grass_border = 4.6 + sin(z * 0.65) * 0.45 + cos(z * 1.3) * 0.25
	if d < -0.5:
		return c_seabed
	elif d < 0.35:
		return c_seabed.lerp(c_wet, (d + 0.5) / 0.85)
	elif d < 1.35:
		return c_wet.lerp(c_dry, (d - 0.35) / 1.0)
	elif d < grass_border:
		return c_dry
	elif d < grass_border + 0.85:
		return c_dry.lerp(c_grass, (d - grass_border) / 0.85)
	else:
		return c_grass

# --- Xの動画（frame_001 / frame_003）完全準拠：海岸岩壁・浅瀬の白波岩・低木・野花 ---
func _build_natural_beach_features(parent: Node3D) -> void:
	var boulder_scene = load("res://assets/models/fbx/nogita_coastal_boulder.glb")

	# 1. 浅瀬に顔を出す丸岩（水面と交差して白い波の輪ができる frame_001 / frame_003 の象徴的表現！）
	var shallow_rocks = [
		{"pos": Vector3(-0.35, -0.18, 2.2), "scale": Vector3(0.55, 0.50, 0.52), "rot": 0.4},
		{"pos": Vector3(-1.45, -0.36, 5.0), "scale": Vector3(0.95, 0.85, 0.90), "rot": 1.2},
		{"pos": Vector3(-0.55, -0.22, -0.4), "scale": Vector3(0.45, 0.42, 0.45), "rot": 2.1},
		{"pos": Vector3(-1.80, -0.40, -6.8), "scale": Vector3(0.80, 0.65, 0.75), "rot": 0.8},
		{"pos": Vector3(-0.60, -0.22, 8.5), "scale": Vector3(0.65, 0.55, 0.60), "rot": 1.7}
	]
	for sr in shallow_rocks:
		if boulder_scene:
			var r_inst = boulder_scene.instantiate()
			r_inst.position = sr["pos"]
			r_inst.scale = sr["scale"]
			r_inst.rotation.y = sr["rot"]
			parent.add_child(r_inst)

	# 2. 画面右奥（東側）の海岸スレート岩壁＆ボルダー群（frame_001.jpg 右上の立体岸壁！）
	for z_idx in range(-14, 16):
		var z_val = z_idx * 1.8 + randf_range(-0.3, 0.3)
		var shore_x = _get_shoreline_x(z_val)
		var cliff_x = shore_x + 8.6 + sin(z_val * 0.3) * 0.8
		var cliff_y = _get_terrain_height(cliff_x, z_val) - 0.2
		if boulder_scene:
			var cliff = boulder_scene.instantiate()
			cliff.position = Vector3(cliff_x, cliff_y, z_val)
			cliff.scale = Vector3(randf_range(1.8, 2.6), randf_range(2.2, 3.4), randf_range(1.8, 2.5))
			cliff.rotation = Vector3(randf_range(-0.1, 0.1), randf_range(0, TAU), randf_range(-0.15, 0.15))
			parent.add_child(cliff)

	# 草地境界のアクセント岩（frame_001.jpg / frame_005.jpg）
	var border_rocks = [
		Vector3(6.8, 0.0, 4.2),
		Vector3(6.4, 0.0, -0.8),
		Vector3(7.2, 0.0, -7.2),
		Vector3(6.5, 0.0, 9.5),
		Vector3(7.0, 0.0, -14.0)
	]
	for br in border_rocks:
		if boulder_scene:
			var b_inst = boulder_scene.instantiate()
			var by = _get_terrain_height(br.x, br.z) - 0.08
			b_inst.position = Vector3(br.x, by, br.z)
			b_inst.scale = Vector3(randf_range(0.75, 1.15), randf_range(0.65, 0.95), randf_range(0.75, 1.10))
			b_inst.rotation.y = randf_range(0, TAU)
			parent.add_child(b_inst)

	# 3. 豊かな海浜低木（緑＆オリーブイエローの丸みを帯びたブッシュ frame_001.jpg）
	var bush_z_list = [-13.0, -9.2, -6.8, -1.2, 1.4, 3.0, 5.2, 7.6, 10.2, 12.8, 15.0]
	for idx in range(bush_z_list.size()):
		var bz = bush_z_list[idx]
		var bx = _get_shoreline_x(bz) + 5.3 + randf_range(-0.35, 0.65)
		var by = _get_terrain_height(bx, bz)
		var is_olive = (idx % 3 == 1)
		_spawn_lush_bush(parent, Vector3(bx, by, bz), mat_bush_olive if is_olive else mat_bush_green, randf_range(0.85, 1.25))

	# 4. 砂浜と草地の境界に咲く白い小花＆草束（frame_001.jpg 右上の白い花畑！）
	for i in range(95):
		var fz = randf_range(-18.0, 18.0)
		if abs(fz - (-3.6)) < 2.2:
			continue # 番屋デッキ周辺はスキップ
		var fx = _get_shoreline_x(fz) + randf_range(4.5, 7.6)
		var fy = _get_terrain_height(fx, fz)

		var flower = Node3D.new()
		flower.position = Vector3(fx, fy + 0.03, fz)
		flower.rotation.y = randf_range(0, TAU)

		# 5枚花びらの可憐な白い野花
		for p in range(5):
			var ang = (p / 5.0) * TAU
			var petal = MeshInstance3D.new()
			var sm = SphereMesh.new()
			sm.radius = 0.045
			sm.height = 0.025
			sm.material = mat_flower_white
			petal.mesh = sm
			petal.position = Vector3(cos(ang) * 0.05, 0.02, sin(ang) * 0.05)
			flower.add_child(petal)

		var center = MeshInstance3D.new()
		var cm = SphereMesh.new()
		cm.radius = 0.03
		cm.height = 0.03
		cm.material = mat_flower_yellow
		center.mesh = cm
		center.position.y = 0.025
		flower.add_child(center)

		parent.add_child(flower)

func _spawn_lush_bush(parent: Node3D, pos: Vector3, mat: Material, scale_val: float) -> void:
	var bush = Node3D.new()
	bush.position = pos
	bush.scale = Vector3.ONE * scale_val
	var offsets = [
		Vector3(0.0, 0.22, 0.0),
		Vector3(0.22, 0.16, 0.12),
		Vector3(-0.20, 0.15, 0.14),
		Vector3(0.10, 0.17, -0.20),
		Vector3(-0.15, 0.18, -0.15),
		Vector3(0.0, 0.30, 0.05)
	]
	for off in offsets:
		var puff = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = randf_range(0.22, 0.30)
		sm.height = sm.radius * 1.65
		sm.material = mat
		puff.mesh = sm
		puff.position = off
		bush.add_child(puff)
	parent.add_child(bush)

# --- 2. 水平線まで途切れない広大な海面（260m × 260m） ---
func _build_water_plane() -> void:
	var water_inst = MeshInstance3D.new()
	water_inst.name = "NogitaWater3D"

	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(260.0, 260.0)
	plane_mesh.subdivide_width = 160
	plane_mesh.subdivide_depth = 160

	var shader = load("res://shaders/stylized_water.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		plane_mesh.material = mat

	water_inst.mesh = plane_mesh
	water_inst.position = Vector3(-35.0, 0.0, 0.0)
	add_child(water_inst)

# --- 3. 漁師の番屋デッキ & 木製ロング桟橋 & 中空の木造小舟（frame_005 / 007 / 009 完全再現） ---
func _build_wooden_banya_deck_and_pier() -> void:
	var wood_root = Node3D.new()
	wood_root.name = "WoodenPier3D"
	add_child(wood_root)

	var deck_y = 0.48
	var pier_z = -3.6

	# A. 番屋の広々とした木製デッキ（x = 0.8 〜 5.2, z = -6.4 〜 -1.2）
	var deck_body = StaticBody3D.new()
	deck_body.collision_layer = 2
	deck_body.collision_mask = 0
	var deck_col = CollisionShape3D.new()
	var deck_box = BoxShape3D.new()
	deck_box.size = Vector3(4.6, 0.30, 5.2)
	deck_col.shape = deck_box
	deck_body.add_child(deck_col)
	deck_body.position = Vector3(3.0, deck_y - 0.12, -3.8)
	wood_root.add_child(deck_body)

	# デッキの板張り
	for i in range(14):
		var plank = MeshInstance3D.new()
		var pm = BoxMesh.new()
		pm.size = Vector3(4.5, 0.07, 0.34)
		pm.material = mat_wood_plank if i % 2 == 0 else mat_wood_plank_alt
		plank.mesh = pm
		plank.position = Vector3(0.0, 0.14, -2.4 + i * 0.365)
		deck_body.add_child(plank)

	# 砂浜からデッキへスムーズに登れる階段・スロープ（x = 5.4, z = -2.2）
	var step_body = StaticBody3D.new()
	step_body.collision_layer = 2
	step_body.collision_mask = 0
	var step_col = CollisionShape3D.new()
	var step_box = BoxShape3D.new()
	step_box.size = Vector3(1.6, 0.25, 4.8)
	step_col.shape = step_box
	step_body.add_child(step_col)
	step_body.position = Vector3(5.6, deck_y - 0.15, -3.8)
	step_body.rotation.z = deg_to_rad(-8.0)
	wood_root.add_child(step_body)

	# 漁師の番屋（frame_007.jpg 準拠のストライプ屋根＆ポーチ付き小屋）
	var hut_scene = load("res://assets/models/fbx/nogita_banya_hut.glb")
	if hut_scene:
		var hut_inst = hut_scene.instantiate()
		hut_inst.position = Vector3(3.2, deck_y, -4.5)
		hut_inst.scale = Vector3.ONE * 0.72
		wood_root.add_child(hut_inst)

		# 番屋本体のコリジョン（手前のデッキ通路 z = -2.8 〜 -1.3 は自由に歩ける）
		var hut_col_body = StaticBody3D.new()
		hut_col_body.collision_layer = 2
		var hc = CollisionShape3D.new()
		var hb = BoxShape3D.new()
		hb.size = Vector3(3.2, 2.5, 2.4)
		hc.shape = hb
		hut_col_body.add_child(hc)
		hut_col_body.position = Vector3(3.0, deck_y + 1.25, -4.6)
		wood_root.add_child(hut_col_body)

	# デッキ上の漁具小物（木箱・麻袋・巻かれたロープ frame_007.jpg）
	_spawn_deck_props(wood_root, deck_y)

	# B. エメラルドの海へ伸びる木製ロング桟橋（x = 0.8 〜 -8.2, z = -3.6, 幅 2.1m）
	var pier_body = StaticBody3D.new()
	pier_body.collision_layer = 2
	pier_body.collision_mask = 0
	var pier_col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(9.2, 0.30, 2.1)
	pier_col.shape = box
	pier_body.add_child(pier_col)
	pier_body.position = Vector3(-3.7, deck_y - 0.12, pier_z)
	wood_root.add_child(pier_body)

	# 一枚ずつ表情のある木製プランク（frame_009.jpg の味わい深い不揃いウッドプランク！）
	var num_planks = 26
	for i in range(num_planks):
		var plank = MeshInstance3D.new()
		var pm = BoxMesh.new()
		var len_var = 2.04 + sin(i * 1.7) * 0.10
		pm.size = Vector3(0.31, 0.07, len_var)
		pm.material = mat_wood_plank if (i % 3 != 0) else mat_wood_plank_alt
		plank.mesh = pm
		plank.position = Vector3(-4.35 + i * 0.345, 0.14, sin(i * 2.3) * 0.03)
		plank.rotation.y = deg_to_rad(sin(i * 3.1) * 0.8)
		pier_body.add_child(plank)

	# 桟橋両脇の白いキャップ付き木製ボラード支柱（frame_009.jpg の象徴的な丸杭！）
	var post_x_list = [-8.0, -6.2, -4.4, -2.6, -0.8, 0.8]
	for px in post_x_list:
		for side in [-1.0, 1.0]:
			var pz = pier_z + side * 1.02
			var pole = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.11
			cyl.bottom_radius = 0.12
			cyl.height = 1.65
			cyl.material = mat_wood_post
			pole.mesh = cyl
			pole.position = Vector3(px, 0.02, pz)
			wood_root.add_child(pole)

			# 杭の白い面取りトップキャップ
			var cap = MeshInstance3D.new()
			var cap_m = CylinderMesh.new()
			cap_m.top_radius = 0.08
			cap_m.bottom_radius = 0.115
			cap_m.height = 0.08
			cap_m.material = mat_post_cap
			cap.mesh = cap_m
			cap.position = Vector3(px, 0.86, pz)
			wood_root.add_child(cap)

	# C. 桟橋のすぐ横に係留された中空の木造小舟（frame_009.jpg 完全再現！）
	var boat_scene = load("res://assets/models/fbx/nogita_wooden_boat.glb")
	if boat_scene:
		moored_boat = boat_scene.instantiate()
		moored_boat.name = "MooredBoat"
		moored_boat.position = Vector3(-2.8, 0.02, -1.35)
		moored_boat.rotation.y = deg_to_rad(-82.0) # 桟橋と平行に美しく浮かぶ
		moored_boat.scale = Vector3.ONE * 0.95
		wood_root.add_child(moored_boat)

	# 係留ロープ（桟橋の杭から小舟の船首へ繋がるロープ）
	var rope = MeshInstance3D.new()
	var rm = CylinderMesh.new()
	rm.top_radius = 0.018
	rm.bottom_radius = 0.018
	rm.height = 1.45
	rm.material = mat_rope
	rope.mesh = rm
	rope.position = Vector3(-1.35, 0.42, -2.05)
	rope.rotation = Vector3(deg_to_rad(68.0), deg_to_rad(-42.0), 0.0)
	wood_root.add_child(rope)

func _spawn_deck_props(parent: Node3D, deck_y: float) -> void:
	# 木箱2段積み（frame_007.jpg 右側）
	var crate1 = MeshInstance3D.new()
	var cm1 = BoxMesh.new()
	cm1.size = Vector3(0.55, 0.42, 0.55)
	cm1.material = mat_wood_plank_alt
	crate1.mesh = cm1
	crate1.position = Vector3(1.4, deck_y + 0.21, -1.7)
	crate1.rotation.y = deg_to_rad(12.0)
	parent.add_child(crate1)

	var crate2 = MeshInstance3D.new()
	var cm2 = BoxMesh.new()
	cm2.size = Vector3(0.42, 0.36, 0.42)
	cm2.material = mat_wood_plank
	crate2.mesh = cm2
	crate2.position = Vector3(1.42, deck_y + 0.58, -1.68)
	crate2.rotation.y = deg_to_rad(-18.0)
	parent.add_child(crate2)

	# デッキ上の巻きロープ
	var coil = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.08
	tm.outer_radius = 0.22
	tm.material = mat_rope
	coil.mesh = tm
	coil.position = Vector3(2.2, deck_y + 0.05, -2.1)
	coil.scale = Vector3(1.0, 0.45, 1.0)
	parent.add_child(coil)

# --- 4. 野北漁港の大波止（北側 z = -11.5） ---
func _build_nogita_pier() -> void:
	var pier_root = Node3D.new()
	pier_root.name = "NogitaPier3D"
	add_child(pier_root)

	var pier_start = Vector3(1.8, 0.75, -11.5)
	var pier_length = 16.0
	var pier_width = 2.8
	var pier_dir = Vector3(-1.0, 0.0, 0.0)

	var pier_body = StaticBody3D.new()
	pier_body.collision_layer = 2
	pier_body.collision_mask = 0

	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(pier_length, 1.8, pier_width)
	col.shape = box_shape
	pier_body.add_child(col)

	var pier_center = pier_start + pier_dir * (pier_length * 0.5)
	pier_center.y = 0.1
	pier_body.position = pier_center
	pier_root.add_child(pier_body)

	var top_mesh = MeshInstance3D.new()
	var tm = BoxMesh.new()
	tm.size = Vector3(pier_length, 0.2, pier_width)
	tm.material = mat_pier_concrete
	top_mesh.mesh = tm
	top_mesh.position.y = 0.85
	pier_body.add_child(top_mesh)

	var base_mesh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(pier_length, 1.6, pier_width)
	bm.material = mat_pier_stone
	base_mesh.mesh = bm
	base_mesh.position.y = 0.0
	pier_body.add_child(base_mesh)

	# 砂浜から大波止へ登るなだらかなコンクリートスロープ
	var slope = StaticBody3D.new()
	slope.collision_layer = 2
	slope.collision_mask = 0
	var slope_col = CollisionShape3D.new()
	var slope_box = BoxShape3D.new()
	slope_box.size = Vector3(4.2, 0.4, pier_width)
	slope_col.shape = slope_box
	slope.add_child(slope_col)
	var slope_m = MeshInstance3D.new()
	var s_bm = BoxMesh.new()
	s_bm.size = slope_box.size
	s_bm.material = mat_pier_concrete
	slope_m.mesh = s_bm
	slope.add_child(slope_m)
	slope.position = pier_start + Vector3(1.5, -0.15, 0.0)
	slope.rotation.z = deg_to_rad(-10.0)
	pier_root.add_child(slope)

	# 外海側（北側）の縁石
	var curb = StaticBody3D.new()
	curb.collision_layer = 2
	var curb_col = CollisionShape3D.new()
	var curb_shape = BoxShape3D.new()
	curb_shape.size = Vector3(pier_length, 0.35, 0.22)
	curb_col.shape = curb_shape
	curb.add_child(curb_col)
	var curb_mesh = MeshInstance3D.new()
	var cm = BoxMesh.new()
	cm.size = curb_shape.size
	cm.material = mat_pier_concrete
	curb_mesh.mesh = cm
	curb.add_child(curb_mesh)
	curb.position = Vector3(0.0, 0.98, -pier_width * 0.44)
	pier_body.add_child(curb)

	for i in range(4):
		var bollard = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.12
		cyl.bottom_radius = 0.14
		cyl.height = 0.4
		var mat_bol = StandardMaterial3D.new()
		mat_bol.albedo_color = Color(0.24, 0.25, 0.26)
		mat_bol.metallic = 0.6
		cyl.material = mat_bol
		bollard.mesh = cyl
		bollard.position = Vector3(-pier_length * 0.5 + 2.5 + i * 3.6, 1.15, pier_width * 0.40)
		pier_body.add_child(bollard)

# --- 5. 野北白灯台（GLBモデル） ---
func _build_white_lighthouse() -> void:
	var lh_root = Node3D.new()
	lh_root.name = "NogitaWhiteLighthouse3D"
	lh_root.position = Vector3(-6.8, 0.95, -11.8)
	add_child(lh_root)

	var lh_scene = load("res://assets/models/fbx/nogita_lighthouse.glb")
	if lh_scene:
		var lh_inst = lh_scene.instantiate()
		lh_root.add_child(lh_inst)

	var tower_col = StaticBody3D.new()
	tower_col.collision_layer = 2
	var c_shape = CylinderShape3D.new()
	c_shape.radius = 0.85
	c_shape.height = 4.8
	var col = CollisionShape3D.new()
	col.shape = c_shape
	tower_col.add_child(col)
	tower_col.position.y = 2.4
	lh_root.add_child(tower_col)

	lighthouse_beam = SpotLight3D.new()
	lighthouse_beam.name = "LighthouseBeam"
	lighthouse_beam.light_color = Color(1.0, 0.98, 0.85)
	lighthouse_beam.light_energy = 5.5
	lighthouse_beam.spot_range = 32.0
	lighthouse_beam.spot_angle = 24.0
	lighthouse_beam.position = Vector3(0, 4.8, 0)
	lh_root.add_child(lighthouse_beam)

# --- 6. 外海側のテトラポッド帯（GLBモデル） ---
func _build_tetrapods() -> void:
	var tetra_root = Node3D.new()
	tetra_root.name = "Tetrapods"
	add_child(tetra_root)

	var tp_scene = load("res://assets/models/fbx/nogita_tetrapod.glb")
	for x_idx in range(9):
		var base_x = 1.0 - x_idx * 1.8
		for z_idx in range(2):
			var base_z = -13.6 - z_idx * 1.5 + randf_range(-0.15, 0.15)
			var base_y = 0.15 + (0.45 if z_idx == 0 else -0.3)
			if tp_scene:
				var tp_inst = tp_scene.instantiate()
				tp_inst.position = Vector3(base_x, base_y, base_z)
				tp_inst.rotation = Vector3(randf_range(-0.3, 0.3), randf_range(0, TAU), randf_range(-0.3, 0.3))
				tp_inst.scale = Vector3.ONE * randf_range(0.9, 1.15)
				tetra_root.add_child(tp_inst)

# --- 7. 浜辺に優美な木陰を落とす海浜樹・松林（frame_001.jpg / frame_003.jpg 準拠配置！） ---
func _build_japanese_black_pines() -> void:
	# 画面内に美しい曲線幹と豊かな緑の葉冠（キャノピー）が収まるゴールデンポジション！
	var tree_configs = [
		{"x_off": 2.6, "z": 0.6,  "rot_y": 0.15,  "scale": 0.95}, # プレイヤーすぐ近くの主役ツリー（frame_001 中央上）
		{"x_off": 4.4, "z": 3.4,  "rot_y": -0.35, "scale": 0.92}, # 右中段ツリー（frame_001 右中）
		{"x_off": 5.0, "z": 6.2,  "rot_y": 0.45,  "scale": 1.02}, # 右手前ツリー（frame_001 右下）
		{"x_off": 2.4, "z": -6.8, "rot_y": 0.25,  "scale": 0.95}, # 番屋北側の浜辺ツリー（frame_007 左上）
		{"x_off": 4.8, "z": -8.2, "rot_y": -0.20, "scale": 1.05},
		{"x_off": 4.2, "z": 10.5, "rot_y": 0.10,  "scale": 0.98},
		{"x_off": 5.5, "z": -14.5,"rot_y": -0.40, "scale": 1.05},
		{"x_off": 4.6, "z": 14.5, "rot_y": 0.30,  "scale": 1.00}
	]
	var pine_scene = load("res://assets/models/fbx/nogita_black_pine.glb")
	for cfg in tree_configs:
		var tz = cfg["z"]
		var tx = _get_shoreline_x(tz) + cfg["x_off"]
		var ty = _get_terrain_height(tx, tz) - 0.05
		if pine_scene:
			var p_inst = pine_scene.instantiate()
			p_inst.position = Vector3(tx, ty, tz)
			p_inst.rotation.y = cfg["rot_y"]
			p_inst.scale = Vector3.ONE * cfg["scale"]
			add_child(p_inst)

# --- 8. 透き通る浅瀬の3Dサンゴ礁＆海藻ガーデン（frame_003.jpg / frame_009.jpg 完全再現） ---
func _build_coral_and_seaweed_garden() -> void:
	var garden_root = Node3D.new()
	garden_root.name = "UnderwaterGarden"
	add_child(garden_root)

	var reef_scene = load("res://assets/models/fbx/nogita_coral_reef.glb")
	var reef_spots = [
		{"pos": Vector3(-2.6, -0.52, 3.4),  "scale": 1.15, "rot": 0.3}, # 浅瀬メインリーフ（frame_003 左下）
		{"pos": Vector3(-3.8, -0.68, 0.2),  "scale": 1.25, "rot": 1.8}, # 浅瀬奥リーフ（frame_003 左上）
		{"pos": Vector3(-2.2, -0.48, -2.0), "scale": 0.95, "rot": 2.5}, # 小舟近くのリーフ（frame_009）
		{"pos": Vector3(-5.2, -0.78, -2.4), "scale": 1.20, "rot": 0.9}, # 桟橋南脇のリーフ（frame_009 中央）
		{"pos": Vector3(-5.5, -0.80, -5.4), "scale": 1.30, "rot": 3.6}, # 桟橋北脇のリーフ（frame_009 左上）
		{"pos": Vector3(-1.8, -0.42, 6.8),  "scale": 1.05, "rot": 4.2},
		{"pos": Vector3(-4.5, -0.72, 7.5),  "scale": 1.20, "rot": 1.1},
		{"pos": Vector3(-3.2, -0.58, -7.8), "scale": 1.10, "rot": 2.9},
		{"pos": Vector3(-6.8, -0.92, 1.8),  "scale": 1.35, "rot": 0.5},
		{"pos": Vector3(-2.5, -0.50, 11.2), "scale": 1.15, "rot": 2.0}
	]

	for sp in reef_spots:
		if reef_scene:
			var r_inst = reef_scene.instantiate()
			var ground_y = _get_terrain_height(sp["pos"].x, sp["pos"].z)
			r_inst.position = Vector3(sp["pos"].x, min(ground_y - 0.32, -0.78), sp["pos"].z)
			r_inst.scale = Vector3.ONE * (sp["scale"] * 0.75)
			r_inst.rotation.y = sp["rot"]
			garden_root.add_child(r_inst)

	# 浅瀬に点在する滑らかな海底の丸石（frame_001.jpg / frame_003.jpg）
	for p in range(32):
		var px = randf_range(-6.5, 0.2)
		var pz = randf_range(-9.0, 10.0)
		var py = _get_terrain_height(px, pz)
		var peb = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = randf_range(0.10, 0.24)
		sm.height = sm.radius * 0.65
		sm.material = mat_pebble
		peb.mesh = sm
		peb.position = Vector3(px, py + 0.02, pz)
		peb.rotation.y = randf_range(0, TAU)
		peb.scale = Vector3(1.2, 0.65, 1.0)
		garden_root.add_child(peb)

# --- 9. 澄み切った海を群れで泳ぐダークスレートの3D小魚たち（frame_001 / frame_009 準拠） ---
func _spawn_fish_shadows() -> void:
	var fish_scene = load("res://assets/models/fbx/swimming_sea_fish.glb")
	if not fish_scene:
		fish_scene = load("res://assets/models/fbx/swimming_sea_fish.fbx")

	var school_centers = [
		Vector3(-1.4, -0.24, 2.2),  # 波打ち際すぐ近くの群れ（frame_001 / 003）
		Vector3(-2.8, -0.34, 4.5),  # 浅瀬サンゴ礁の群れ
		Vector3(-1.8, -0.28, -1.2), # 小舟の手前の群れ（frame_009）
		Vector3(-4.8, -0.42, -2.2), # 木製桟橋脇の群れ（frame_009）
		Vector3(-6.2, -0.48, -5.2), # 桟橋沖の群れ（frame_009）
		Vector3(-3.5, -0.38, 0.8),
		Vector3(-5.5, -0.45, -9.2), # 大波止周辺の群れ
		Vector3(-2.2, -0.30, 8.2)
	]

	for sc in school_centers:
		for k in range(3):
			var fish_node: Node3D
			if fish_scene:
				fish_node = fish_scene.instantiate()
			else:
				fish_node = Node3D.new()

			var offset = Vector3(randf_range(-0.8, 0.8), randf_range(-0.04, 0.04), randf_range(-0.8, 0.8))
			var center = sc + offset
			fish_node.position = center
			fish_node.scale = Vector3.ONE * randf_range(0.24, 0.42) # 繊細でリアルな小魚サイズ！
			add_child(fish_node)

			swimming_fish.append({
				"node": fish_node,
				"center": center,
				"radius": randf_range(0.85, 2.1),
				"speed": randf_range(0.55, 1.15) * (1.0 if (k % 2 == 0) else -1.0),
				"phase": randf_range(0.0, TAU),
				"wiggle_speed": randf_range(7.0, 11.0)
			})

func _update_swimming_fish(delta: float) -> void:
	var t = Time.get_ticks_msec() / 1000.0
	for f in swimming_fish:
		f["phase"] += f["speed"] * delta
		var p = f["phase"]
		var r = f["radius"]
		var new_x = f["center"].x + cos(p) * r
		var new_z = f["center"].z + sin(p) * r

		var node: Node3D = f["node"]
		var forward = Vector3(-sin(p) * f["speed"], 0, cos(p) * f["speed"]).normalized()

		node.position.x = new_x
		node.position.z = new_z
		node.rotation.y = atan2(-forward.x, -forward.z) + sin(t * f["wiggle_speed"]) * 0.16
		node.rotation.z = cos(t * f["wiggle_speed"] * 0.8) * 0.08

# --- 10. 波打ち際と砂浜の繊細な小カニ（frame_003.jpg の可愛いミニサイズ！） ---
func _build_beach_decorations() -> void:
	var beach_deco = Node3D.new()
	beach_deco.name = "BeachDecorations"
	add_child(beach_deco)

	var crab_spots = [
		Vector3(2.4, 0.0, 2.2),
		Vector3(0.4, 0.0, 3.8),
		Vector3(1.8, 0.0, 6.2),
		Vector3(1.6, 0.0, -7.2)
	]
	for pos in crab_spots:
		var crab = Node3D.new()
		var cy = _get_terrain_height(pos.x, pos.z) + 0.02
		crab.position = Vector3(pos.x, cy, pos.z)
		crab.rotation.y = randf_range(0, TAU)
		crab.scale = Vector3.ONE * 0.42 # 小さく繊細なリアルサイズ

		var shell = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.08
		sm.material = mat_crab
		shell.mesh = sm
		crab.add_child(shell)

		for h in [-1.0, 1.0]:
			var claw = MeshInstance3D.new()
			var cm = SphereMesh.new()
			cm.radius = 0.045
			cm.height = 0.07
			cm.material = mat_crab
			claw.mesh = cm
			claw.position = Vector3(h * 0.12, 0.02, -0.10)
			crab.add_child(claw)

			for leg_i in range(3):
				var leg = MeshInstance3D.new()
				var lm = CylinderMesh.new()
				lm.top_radius = 0.012
				lm.bottom_radius = 0.008
				lm.height = 0.12
				lm.material = mat_crab
				leg.mesh = lm
				leg.position = Vector3(h * 0.11, 0.0, -0.04 + leg_i * 0.045)
				leg.rotation.z = h * deg_to_rad(55.0)
				crab.add_child(leg)

		beach_deco.add_child(crab)
