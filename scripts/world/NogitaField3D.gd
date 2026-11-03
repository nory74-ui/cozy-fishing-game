extends Node3D

# 福岡・糸島 野北（のぎた）海岸 HD-2D フィールド
# スクウェア・エニックスのHD-2D手法に準拠：
# 3Dジオメトリ空間 × ピクセルアートテクスチャ × ドット絵スプライト × 動的水面 × DoF（被写界深度）

var sand_mat: StandardMaterial3D
var concrete_mat: StandardMaterial3D
var cliff_mat: StandardMaterial3D
var grass_mat: StandardMaterial3D
var water_mat: ShaderMaterial

# スポット座標の定義（釣り・採取・移動判定用）
const PIER_SURFACE_Y = 1.8
const BEACH_SURFACE_Y = 0.4
const HILL_SURFACE_Y = 2.8

func _ready() -> void:
	_init_materials()
	_build_ocean()
	_build_beach()
	_build_breakwater_pier()
	_build_pine_ridge()
	_build_props()
	_setup_lighting()

func _load_image_texture(path: String) -> Texture2D:
	var global_path = ProjectSettings.globalize_path(path)
	var img = Image.load_from_file(global_path)
	if img:
		return ImageTexture.create_from_image(img)
	return null

func _init_materials() -> void:
	# 砂浜マテリアル
	sand_mat = StandardMaterial3D.new()
	var tex_sand = _load_image_texture("res://assets/tex_sand.png")
	if tex_sand:
		sand_mat.albedo_texture = tex_sand
		sand_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sand_mat.uv1_scale = Vector3(20, 20, 1)
	sand_mat.roughness = 0.95

	# コンクリート防波堤マテリアル
	concrete_mat = StandardMaterial3D.new()
	var tex_concrete = _load_image_texture("res://assets/tex_concrete.png")
	if tex_concrete:
		concrete_mat.albedo_texture = tex_concrete
		concrete_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		concrete_mat.uv1_scale = Vector3(8, 8, 1)
	concrete_mat.roughness = 0.85

	# 崖・岩肌マテリアル
	cliff_mat = StandardMaterial3D.new()
	var tex_cliff = _load_image_texture("res://assets/tex_cliff.png")
	if tex_cliff:
		cliff_mat.albedo_texture = tex_cliff
		cliff_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		cliff_mat.uv1_scale = Vector3(6, 6, 1)
	cliff_mat.roughness = 0.9

	# 芝生・緑マテリアル
	grass_mat = StandardMaterial3D.new()
	var tex_grass = _load_image_texture("res://assets/tex_grass.png")
	if tex_grass:
		grass_mat.albedo_texture = tex_grass
		grass_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		grass_mat.uv1_scale = Vector3(15, 15, 1)
	grass_mat.roughness = 0.9

	# 3D水面シェーダーマテリアル
	water_mat = ShaderMaterial.new()
	var shader = load("res://assets/shaders/hd2d_water.gdshader")
	if shader:
		water_mat.shader = shader

func _setup_lighting() -> void:
	# 太陽光 (DirectionalLight3D)
	var sun = DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-42, 38, 0)
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	# 環境設定 (WorldEnvironment) - スクエニHD-2Dの空気感
	var env_node = WorldEnvironment.new()
	env_node.name = "HD2DEnvironment"
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.48, 0.72, 0.92) # 爽快な玄界灘の青空
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.75, 0.85)
	env.ambient_light_energy = 0.65
	
	# ブルーム (光のきらめき)
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.15
	
	# トーンマップ (深みのあるコントラスト)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	add_child(env_node)

func _build_ocean() -> void:
	# 広大な玄界灘 3D水面プレーン
	var ocean_mesh = PlaneMesh.new()
	ocean_mesh.size = Vector2(100, 100)
	ocean_mesh.subdivide_width = 40
	ocean_mesh.subdivide_depth = 40
	
	var ocean_inst = MeshInstance3D.new()
	ocean_inst.name = "OceanSurface"
	ocean_inst.mesh = ocean_mesh
	ocean_inst.material_override = water_mat
	ocean_inst.position = Vector3(0, 0.05, 0)
	add_child(ocean_inst)

func _build_beach() -> void:
	# 白砂サーフ (中央〜東側に広がるなだらかな傾斜地)
	var beach_body = StaticBody3D.new()
	beach_body.name = "BeachGround"
	
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(32, 0.8, 28)
	col.shape = box_shape
	beach_body.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(32, 0.8, 28)
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = sand_mat
	beach_body.add_child(mesh_inst)
	
	# 砂浜の配置 (中心 x: 8, y: 0.1, z: 4)
	beach_body.position = Vector3(8.0, 0.1, 4.0)
	add_child(beach_body)

func _build_breakwater_pier() -> void:
	# 野北名物・大波止 (西側に突き出る厚みのある3Dコンクリート堤防)
	# 堤防本体
	var pier_body = StaticBody3D.new()
	pier_body.name = "BreakwaterPier"
	
	var pier_col = CollisionShape3D.new()
	var p_shape = BoxShape3D.new()
	p_shape.size = Vector3(6.0, PIER_SURFACE_Y + 0.8, 34.0)
	pier_col.shape = p_shape
	pier_body.add_child(pier_col)
	
	var pier_mesh = MeshInstance3D.new()
	var p_mesh = BoxMesh.new()
	p_mesh.size = Vector3(6.0, PIER_SURFACE_Y + 0.8, 34.0)
	pier_mesh.mesh = p_mesh
	pier_mesh.material_override = concrete_mat
	pier_body.add_child(pier_mesh)
	
	pier_body.position = Vector3(-12.0, (PIER_SURFACE_Y + 0.8) / 2.0 - 0.4, -2.0)
	add_child(pier_body)

	# 砂浜から堤防へ登るスロープ・階段
	var ramp_body = StaticBody3D.new()
	ramp_body.name = "PierRamp"
	var r_col = CollisionShape3D.new()
	var r_shape = BoxShape3D.new()
	r_shape.size = Vector3(6.0, 0.6, 8.0)
	r_col.shape = r_shape
	ramp_body.add_child(r_col)
	
	var r_mesh = MeshInstance3D.new()
	var r_mesh_box = BoxMesh.new()
	r_mesh_box.size = Vector3(6.0, 0.6, 8.0)
	r_mesh.mesh = r_mesh_box
	r_mesh.material_override = concrete_mat
	ramp_body.add_child(r_mesh)
	
	ramp_body.position = Vector3(-6.0, 0.7, 12.0)
	ramp_body.rotation_degrees = Vector3(12, 90, 0) # なだらかなスロープ
	add_child(ramp_body)

func _build_pine_ridge() -> void:
	# 砂浜の背後（南側・奥）にそびえる松林の高台
	var ridge_body = StaticBody3D.new()
	ridge_body.name = "PineRidge"
	
	var r_col = CollisionShape3D.new()
	var r_shape = BoxShape3D.new()
	r_shape.size = Vector3(45, HILL_SURFACE_Y + 0.8, 14)
	r_col.shape = r_shape
	ridge_body.add_child(r_col)
	
	var r_mesh = MeshInstance3D.new()
	var r_mesh_box = BoxMesh.new()
	r_mesh_box.size = Vector3(45, HILL_SURFACE_Y + 0.8, 14)
	r_mesh.mesh = r_mesh_box
	r_mesh.material_override = grass_mat
	ridge_body.add_child(r_mesh)
	
	ridge_body.position = Vector3(2.0, (HILL_SURFACE_Y + 0.8) / 2.0 - 0.4, 21.0)
	add_child(ridge_body)

	# 崖面の擁壁 (前面)
	var cliff_mesh = MeshInstance3D.new()
	var c_box = BoxMesh.new()
	c_box.size = Vector3(45, HILL_SURFACE_Y, 0.6)
	cliff_mesh.mesh = c_box
	cliff_mesh.material_override = cliff_mat
	cliff_mesh.position = Vector3(2.0, HILL_SURFACE_Y / 2.0, 13.7)
	add_child(cliff_mesh)

func _build_props() -> void:
	# 1. 野北白灯台 (堤防の先端 x: -12, z: -17)
	_spawn_lighthouse(Vector3(-12.0, PIER_SURFACE_Y, -16.5))

	# 2. テトラポッド帯 (堤防の西側外海 x: -16.5, z: -14 〜 2)
	for z_pos in range(-15, 6, 4):
		_spawn_tetrapod(Vector3(-16.0, 0.4, float(z_pos)))
		_spawn_tetrapod(Vector3(-17.5, 0.8, float(z_pos + 1)))

	# 3. 糸島クロマツ（黒松）の林 (高台の上に並ぶ立体スプライト3D - 背景として美しく配置)
	var pine_tex = load("res://assets/nogita_kuromatsu_pine.png")
	if pine_tex:
		var pine_positions = [
			Vector3(-6.0, HILL_SURFACE_Y, 21.0),
			Vector3(0.0, HILL_SURFACE_Y, 22.5),
			Vector3(6.0, HILL_SURFACE_Y, 20.5),
			Vector3(12.0, HILL_SURFACE_Y, 22.0),
			Vector3(18.0, HILL_SURFACE_Y, 21.0),
			Vector3(24.0, HILL_SURFACE_Y, 23.0)
		]
		for p_pos in pine_positions:
			_spawn_pine_tree(p_pos, pine_tex)

	# 4. 漁師の番屋 (高台の広場 x: -1.0, z: 20.5)
	_spawn_shack(Vector3(-1.0, HILL_SURFACE_Y, 20.5))

	# 5. ハマヒルガオ（砂浜の野草）
	var flower_tex = load("res://assets/nogita_hamahirugao.png")
	if flower_tex:
		var flower_positions = [
			Vector3(4.0, BEACH_SURFACE_Y, 9.0),
			Vector3(12.0, BEACH_SURFACE_Y, 8.5),
			Vector3(16.0, BEACH_SURFACE_Y, 11.0),
			Vector3(1.0, BEACH_SURFACE_Y, 12.0)
		]
		for f_pos in flower_positions:
			var sp = Sprite3D.new()
			sp.texture = flower_tex
			sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sp.pixel_size = 0.003
			sp.position = f_pos
			add_child(sp)

func _spawn_lighthouse(pos: Vector3) -> void:
	var lh_tex = load("res://assets/nogita_lighthouse.png")
	if lh_tex:
		var sp = Sprite3D.new()
		sp.name = "LighthouseSprite"
		sp.texture = lh_tex
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = 0.0065
		sp.centered = true
		sp.position = pos + Vector3(0, 2.5, 0)
		add_child(sp)
		
		# 灯台の丸形土台コリジョン
		var body = StaticBody3D.new()
		var col = CollisionShape3D.new()
		var cyl = CylinderShape3D.new()
		cyl.radius = 1.6
		cyl.height = 3.0
		col.shape = cyl
		body.add_child(col)
		body.position = pos + Vector3(0, 1.5, 0)
		add_child(body)

func _spawn_tetrapod(pos: Vector3) -> void:
	var tetra_tex = load("res://assets/nogita_tetrapod.png")
	if tetra_tex:
		var sp = Sprite3D.new()
		sp.texture = tetra_tex
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = 0.004
		sp.position = pos
		add_child(sp)
		
		var body = StaticBody3D.new()
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(1.8, 1.6, 1.8)
		col.shape = box
		body.add_child(col)
		body.position = pos + Vector3(0, 0.8, 0)
		add_child(body)

func _spawn_pine_tree(pos: Vector3, tex: Texture2D) -> void:
	var sp = Sprite3D.new()
	sp.texture = tex
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.pixel_size = 0.0075
	sp.centered = true
	sp.position = pos + Vector3(0, 3.0, 0)
	add_child(sp)

	# 幹のコリジョン（木の上を歩くのを完全に防ぐ物理判定）
	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = 0.7
	cyl.height = 4.0
	col.shape = cyl
	body.add_child(col)
	body.position = pos + Vector3(0, 2.0, 0)
	add_child(body)

func _spawn_shack(pos: Vector3) -> void:
	var shack_tex = load("res://assets/beach_shack_building.png")
	if shack_tex:
		var sp = Sprite3D.new()
		sp.texture = shack_tex
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = 0.007
		sp.centered = true
		sp.position = pos + Vector3(0, 2.8, 0)
		add_child(sp)

		var body = StaticBody3D.new()
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(5.0, 3.5, 3.5)
		col.shape = box
		body.add_child(col)
		body.position = pos + Vector3(0, 1.75, 0)
		add_child(body)
