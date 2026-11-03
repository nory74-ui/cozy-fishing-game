extends Node2D

# =============================================================================
# うみかぜ日和 〜 福岡・糸島 野北編 〜
# 【方法①：世界観統一＆完全物理整合マップ】
# - 背景イラスト1枚絵を完全撤去し、純粋な地形キャンバスを最下層に配置。
# - 余計な小屋（番屋）や巨大な花は完全排除し、美しい自然の野北海岸へ世界観を統一。
# - 堤防の上にあったテトラポッドを完全排除し、砂浜から堤防の先端（灯台）まで
#   快適かつスムーズに歩いて行けるように登り口と歩行路を完全開通。
# - 海岸線に正確な進入禁止コリジョンを設定し、海中への侵入を完全ブロック。
# =============================================================================

signal shop_interacted()

const MAP_SIZE = Vector2(2304, 1296)
var map_size: Vector2 = MAP_SIZE
var pond_center: Vector2 = Vector2(600, 350)
var safe_pond_rx: float = 350.0
var safe_pond_ry: float = 200.0
var river_x: float = 500.0
var safe_river_half_width: float = 120.0

# テクスチャアセット
var tex_terrain_base: Texture2D
var tex_pine: Texture2D
var tex_lighthouse: Texture2D
var tex_tetrapod: Texture2D
var tex_crab: Texture2D

var ground_node: Node2D
var ysort_world: Node2D
var boundary_node: StaticBody2D

var crabs: Array[Dictionary] = []

func _ready() -> void:
	z_index = 0
	_load_textures()
	_setup_layers()
	_build_ground_terrain()
	_build_physical_boundaries()
	_build_world_props()
	_init_creatures()

func _load_textures() -> void:
	tex_terrain_base = GameData.load_texture("res://assets/terrain_nogita_base.png")
	tex_pine = GameData.load_texture("res://assets/nogita_kuromatsu_pine.png")
	tex_lighthouse = GameData.load_texture("res://assets/nogita_lighthouse.png")
	tex_tetrapod = GameData.load_texture("res://assets/nogita_tetrapod.png")
	tex_crab = GameData.load_texture("res://assets/beach_crab.png")

func _setup_layers() -> void:
	# 1. 地面レイヤー（純粋な海・砂浜・堤防・芝生丘）
	ground_node = Node2D.new()
	ground_node.name = "GroundTerrain"
	ground_node.z_index = 0
	add_child(ground_node)
	
	# 2. 境界コリジョン（海侵入防止、崖、外枠壁）
	boundary_node = StaticBody2D.new()
	boundary_node.name = "WorldBoundaries"
	add_child(boundary_node)

	# 3. Y-Sortオブジェクトレイヤー（灯台、木、テトラポッド、プレイヤー）
	ysort_world = Node2D.new()
	ysort_world.name = "YSortProps"
	ysort_world.y_sort_enabled = true
	ysort_world.z_index = 3
	add_child(ysort_world)

# -----------------------------------------------------------------------------
# 1. 地面・地形の描画
# -----------------------------------------------------------------------------
func _build_ground_terrain() -> void:
	if tex_terrain_base:
		var bg_spr = Sprite2D.new()
		bg_spr.name = "PureTerrainBase"
		bg_spr.texture = tex_terrain_base
		bg_spr.centered = false
		ground_node.add_child(bg_spr)

# -----------------------------------------------------------------------------
# 2. 物理コリジョン境界（海への侵入防止、堤防落下防止、崖面、外枠）
# -----------------------------------------------------------------------------
func _build_physical_boundaries() -> void:
	# A. マップ外枠壁
	_add_wall_box(Vector2(0, -40), Vector2(MAP_SIZE.x, 40))
	_add_wall_box(Vector2(0, MAP_SIZE.y), Vector2(MAP_SIZE.x, 40))
	_add_wall_box(Vector2(-40, 0), Vector2(40, MAP_SIZE.y))
	_add_wall_box(Vector2(MAP_SIZE.x, 0), Vector2(40, MAP_SIZE.y))

	# B. 防波堤の海側エッジ（海への落下防止壁）
	# 先端
	_add_wall_segment(Vector2(320, 390), Vector2(475, 325))
	# 西側エッジ（外海側）
	_add_wall_segment(Vector2(320, 390), Vector2(560, 1010))
	# 東側エッジ（内海側）
	_add_wall_segment(Vector2(475, 325), Vector2(670, 950))
	# ※ (560, 1010) と (670, 950) の間は堤防の登り口として完全に開放！

	# C. 海岸線・波打ち際の進入禁止壁（海に入れない壁）
	var shore_north = PackedVector2Array([
		Vector2(1980, 0),
		Vector2(1780, 140),
		Vector2(1560, 260),
		Vector2(1340, 400),
		Vector2(1140, 520),
		Vector2(960, 640),
		Vector2(800, 760),
		Vector2(700, 880),
		Vector2(670, 950) # 堤防の東側壁にぴったり接続
	])
	for i in range(shore_north.size() - 1):
		_add_wall_segment(shore_north[i], shore_north[i + 1])

	# 堤防西側の海（外海側の波打ち際）
	var shore_south = PackedVector2Array([
		Vector2(560, 1010), # 堤防の西側壁にぴったり接続
		Vector2(380, 1090),
		Vector2(200, 1170),
		Vector2(0, 1240)
	])
	for i in range(shore_south.size() - 1):
		_add_wall_segment(shore_south[i], shore_south[i + 1])

	# D. 崖面（急斜面ブロック：中央の砂道 x:1500〜1720 以外をブロック）
	var cliff_north = PackedVector2Array([
		Vector2(2304, 280),
		Vector2(2180, 330),
		Vector2(2000, 500),
		Vector2(1840, 660),
		Vector2(1720, 770)
	])
	for i in range(cliff_north.size() - 1):
		_add_wall_segment(cliff_north[i], cliff_north[i + 1])

	var cliff_south = PackedVector2Array([
		Vector2(1500, 920),
		Vector2(1240, 1030),
		Vector2(960, 1130),
		Vector2(750, 1220),
		Vector2(600, 1296)
	])
	for i in range(cliff_south.size() - 1):
		_add_wall_segment(cliff_south[i], cliff_south[i + 1])

func _add_wall_box(pos: Vector2, size: Vector2) -> void:
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	col.position = pos + size * 0.5
	boundary_node.add_child(col)

func _add_wall_segment(p1: Vector2, p2: Vector2) -> void:
	var col = CollisionShape2D.new()
	var shape = SegmentShape2D.new()
	shape.a = p1
	shape.b = p2
	col.shape = shape
	boundary_node.add_child(col)

# -----------------------------------------------------------------------------
# 3. プロップ配置（世界観統一：余計な小屋や花は全廃、灯台と黒松のみ品よく配置）
# -----------------------------------------------------------------------------
func _build_world_props() -> void:
	# 1. 野北白灯台（防波堤の先端・壁際に小さく配置）
	_spawn_lighthouse(Vector2(395, 335))

	# 2. 糸島クロマツ（黒松）
	# 砂浜には置かず、高台の緑の芝生エリアにのみ美しく配置
	var pine_positions = [
		Vector2(2120, 360),
		Vector2(1950, 480),
		Vector2(2180, 680),
		Vector2(2000, 850),
		Vector2(1650, 1120),
		Vector2(1350, 1220),
		Vector2(2200, 1050)
	]
	for pos in pine_positions:
		_spawn_pine_tree(pos)

	# 3. テトラポッド（堤防の上には絶対に置かず、外海の海中波打ち際にのみ配置）
	var tetra_positions = [
		Vector2(180, 1150),
		Vector2(240, 1120),
		Vector2(120, 1200)
	]
	for pos in tetra_positions:
		_spawn_tetrapod(pos)

func _spawn_lighthouse(pos: Vector2) -> void:
	if not tex_lighthouse: return
	var body = StaticBody2D.new()
	body.name = "NogitaLighthouse"
	body.y_sort_enabled = true
	body.position = pos

	var spr = Sprite2D.new()
	spr.texture = tex_lighthouse
	spr.scale = Vector2(0.36, 0.36) # スリムで品の良いスケール
	spr.offset = Vector2(0, -spr.texture.get_height() * 0.45)
	body.add_child(spr)

	# コンパクトな土台コリジョン（プレイヤーが灯台の横を通って堤防先端まで行ける）
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 28.0
	col.shape = circle
	col.position = Vector2(0, -15)
	body.add_child(col)

	ysort_world.add_child(body)

func _spawn_pine_tree(pos: Vector2) -> void:
	if not tex_pine: return
	var body = StaticBody2D.new()
	body.name = "KuromatsuPine"
	body.y_sort_enabled = true
	body.position = pos

	var spr = Sprite2D.new()
	spr.texture = tex_pine
	spr.scale = Vector2(0.50, 0.50)
	spr.offset = Vector2(0, -spr.texture.get_height() * 0.45)
	body.add_child(spr)

	# 木の幹の根元にだけ小さなコリジョン（木の後ろを通ると葉に隠れる）
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 24.0
	col.shape = circle
	col.position = Vector2(0, -10)
	body.add_child(col)

	ysort_world.add_child(body)

func _spawn_tetrapod(pos: Vector2) -> void:
	if not tex_tetrapod: return
	var body = StaticBody2D.new()
	body.name = "Tetrapod"
	body.y_sort_enabled = true
	body.position = pos

	var spr = Sprite2D.new()
	spr.texture = tex_tetrapod
	spr.scale = Vector2(0.35, 0.35)
	spr.offset = Vector2(0, -spr.texture.get_height() * 0.35)
	body.add_child(spr)

	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 28.0
	col.shape = circle
	col.position = Vector2(0, -10)
	body.add_child(col)

	ysort_world.add_child(body)

func _init_creatures() -> void:
	for _i in range(5):
		crabs.append({
			"pos": Vector2(randf_range(850, 1450), randf_range(750, 950)),
			"origin": Vector2(randf_range(850, 1450), randf_range(750, 950)),
			"vel": Vector2(randf_range(-12, 12), randf_range(-8, 8)),
			"walk_time": 0.0,
			"pause_time": randf_range(1.0, 3.0)
		})

func _process(delta: float) -> void:
	for c in crabs:
		if c["pause_time"] > 0.0:
			c["pause_time"] -= delta
		else:
			c["walk_time"] += delta
			c["pos"] += c["vel"] * delta
			if c["walk_time"] > 2.0:
				c["walk_time"] = 0.0
				c["pause_time"] = randf_range(1.5, 3.0)
				c["vel"] = Vector2(randf_range(-16, 16), randf_range(-10, 10))
	queue_redraw()

func _draw() -> void:
	if tex_crab:
		for c in crabs:
			draw_texture(tex_crab, c["pos"] - Vector2(12, 12), Color(1, 1, 1, 0.85))

# -----------------------------------------------------------------------------
# 判定関数（釣りキャスト・移動判定）
# -----------------------------------------------------------------------------
func is_water_position(pos: Vector2) -> bool:
	# 堤防の上は陸地
	if is_on_pier(pos):
		return false
	# 海岸線（北西側）判定
	# (x, y) が波打ち際より外側（海側）にあるか
	if pos.x < 0 or pos.y < 0:
		return true
	# 簡易対角線判定: y < -0.65 * x + 1300
	return (pos.y < -0.65 * pos.x + 1300)

func is_on_pier(pos: Vector2) -> bool:
	# 堤防の矩形エリア判定（回転ポリゴン）
	# 堤防中心線: (390, 360) -> (620, 980)
	var v_pier = Vector2(620 - 390, 980 - 360) # 方向ベクトル (230, 620)
	var len_pier = v_pier.length()
	var dir_pier = v_pier.normalized()
	var normal_pier = Vector2(-dir_pier.y, dir_pier.x)
	
	var v_rel = pos - Vector2(390, 360)
	var proj_along = v_rel.dot(dir_pier)
	var proj_across = abs(v_rel.dot(normal_pier))
	
	return (proj_along >= -30.0 and proj_along <= len_pier + 40.0 and proj_across <= 95.0)

func is_in_safe_water(pos: Vector2) -> bool:
	return is_water_position(pos)

func is_castable_water(pos: Vector2) -> bool:
	return is_water_position(pos)

func is_in_water(pos: Vector2) -> bool:
	return is_water_position(pos)

func get_shore_x(y: float) -> float:
	return max((1300.0 - y) / 0.65, 300.0)
