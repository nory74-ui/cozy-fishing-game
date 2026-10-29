extends Node2D

# 南国ビーチフィールド（動画「I Just Wanted to Fish」完全再現マップ）

signal shop_interacted()

var tex_shack: Texture2D
var tex_palm: Texture2D
var tex_coral: Texture2D
var tex_rock: Texture2D
var tex_crab: Texture2D

var time_counter: float = 0.0

# カニたちの動的データ
var crabs: Array[Dictionary] = []

# 青い蝶の動的データ
var butterflies: Array[Dictionary] = []

# コリジョン用の海岸線定義
# 砂浜は右側（x > shore_line(y)）
const SCREEN_SIZE = Vector2(1152, 648)

func _ready() -> void:
	tex_shack = GameData.load_texture("res://assets/beach_shack.png")
	tex_palm = GameData.load_texture("res://assets/palm_tree.png")
	tex_coral = GameData.load_texture("res://assets/coral_seaweed.png")
	tex_rock = GameData.load_texture("res://assets/beach_rock.png")
	tex_crab = GameData.load_texture("res://assets/beach_crab.png")
	
	_init_crabs()
	_init_butterflies()

func _init_crabs() -> void:
	crabs.clear()
	# 砂浜をちょこちょこ歩くカニ2匹
	crabs.append({
		"pos": Vector2(725, 95),
		"origin": Vector2(725, 95),
		"vel": Vector2(-15, 0),
		"walk_time": 0.0,
		"pause_time": 1.5,
		"scale": Vector2(0.9, 0.9)
	})
	crabs.append({
		"pos": Vector2(760, 80),
		"origin": Vector2(760, 80),
		"vel": Vector2(12, 5),
		"walk_time": 0.0,
		"pause_time": 2.0,
		"scale": Vector2(0.75, 0.75)
	})

func _init_butterflies() -> void:
	butterflies.clear()
	butterflies.append({
		"pos": Vector2(920, 140),
		"origin": Vector2(920, 140),
		"angle": 0.0,
		"radius": 45.0,
		"speed": 1.4,
		"color": Color(0.25, 0.65, 1.0, 0.9)
	})

func _process(delta: float) -> void:
	time_counter += delta
	
	# カニの動き
	for c in crabs:
		if c["pause_time"] > 0.0:
			c["pause_time"] -= delta
		else:
			c["walk_time"] += delta
			c["pos"] += c["vel"] * delta
			if c["walk_time"] > 2.2:
				c["walk_time"] = 0.0
				c["pause_time"] = randf_range(1.5, 3.5)
				# 逆方向または少しずらした方向へ
				var offset_from_orig = c["pos"] - c["origin"]
				if offset_from_orig.length() > 35.0:
					c["vel"] = -c["vel"].normalized() * randf_range(10, 18)
				else:
					c["vel"] = Vector2(randf_range(-18, 18), randf_range(-10, 10))
					
	# 蝶の舞い
	for b in butterflies:
		b["angle"] += delta * b["speed"]
		b["pos"] = b["origin"] + Vector2(cos(b["angle"]) * b["radius"], sin(b["angle"] * 1.5) * (b["radius"] * 0.6))
		
	queue_redraw()

func get_shore_x(y: float) -> float:
	# 砂浜と波打ち際の境界線 x座標（yに応じた曲線）
	# 画面上部 (y=0) では x=620, 中央 (y=320) では x=720, 下部 (y=648) では x=820
	var norm_y = y / SCREEN_SIZE.y
	return 610.0 + sin(norm_y * PI * 0.9 + 0.3) * 120.0 + norm_y * 140.0

func is_point_walkable(pos: Vector2) -> bool:
	# プレイヤーの歩行可能判定
	# 砂浜および波打ち際（shore_x - 30 までは足首浸かりで歩行可）
	var shore_x = get_shore_x(pos.y)
	if pos.x < shore_x - 45.0:
		return false # 深い海
	# 画面外制限
	if pos.x > SCREEN_SIZE.x - 30.0 or pos.y < 30.0 or pos.y > SCREEN_SIZE.y - 30.0:
		return false
	# 小屋の本体衝突判定
	var shack_rect = Rect2(0, 0, 240, 220)
	if shack_rect.has_point(pos):
		return false
	# ヤシの木の幹衝突判定
	var palm_trunk = Rect2(1010, 280, 50, 60)
	if palm_trunk.has_point(pos):
		return false
	return true

func is_in_safe_water(pos: Vector2) -> bool:
	var shore_x = get_shore_x(pos.y)
	if pos.x < shore_x - 30.0 and pos.x > 40.0 and pos.y > 40.0 and pos.y < SCREEN_SIZE.y - 40.0:
		var shack_rect = Rect2(0, 0, 240, 240)
		return not shack_rect.has_point(pos)
	return false

func get_clamped_safe_water_pos(pos: Vector2) -> Vector2:
	var res = pos
	var shore_x = get_shore_x(res.y)
	if res.x > shore_x - 40.0:
		res.x = shore_x - 40.0
	res.x = clampf(res.x, 50.0, SCREEN_SIZE.x - 50.0)
	res.y = clampf(res.y, 50.0, SCREEN_SIZE.y - 50.0)
	return res

func is_water(pos: Vector2) -> bool:
	# 釣りのキャスト対象（水面判定）
	var shore_x = get_shore_x(pos.y)
	return pos.x < shore_x - 10.0

func is_castable_water(pos: Vector2) -> bool:
	var shore_x = get_shore_x(pos.y)
	if pos.x < shore_x - 10.0 and pos.x > 30.0 and pos.y > 30.0 and pos.y < SCREEN_SIZE.y - 30.0:
		var shack_rect = Rect2(0, 0, 240, 240)
		return not shack_rect.has_point(pos)
	return false

func is_in_water(pos: Vector2) -> bool:
	return pos.x < get_shore_x(pos.y) - 45.0

func is_on_pier(pos: Vector2) -> bool:
	return false

func is_on_island(pos: Vector2) -> bool:
	return false

func _draw() -> void:
	# 1. 小屋の桟橋支柱の海中影
	draw_ellipse(Vector2(140, 260), 120.0, 30.0, Color(0.08, 0.25, 0.3, 0.35))
	
	# 2. 高床式木造小屋
	if tex_shack:
		var shack_pos = Vector2(-15, -20)
		var shack_size = tex_shack.get_size() * 0.36
		draw_texture_rect(tex_shack, Rect2(shack_pos, shack_size), false)
		
	# 3. 水中のサンゴ・海藻（エメラルドグリーンの水底に透ける）
	if tex_coral:
		var coral_pos = Vector2(30, 380)
		var coral_size = tex_coral.get_size() * 0.28
		# 水中ゆらめき
		var sway = sin(time_counter * 1.6) * 3.0
		draw_texture_rect(tex_coral, Rect2(coral_pos + Vector2(sway, 0), coral_size), false, Color(1, 1, 1, 0.88))
		
	# 4. 波打ち際の丸石（Beach Rock）
	var rock_pos = Vector2(835, 230)
	# 濡れた砂の影
	draw_ellipse(rock_pos + Vector2(6, 12), 26.0, 10.0, Color(0.55, 0.48, 0.35, 0.45))
	# 丸石本体（白〜ライトグレーのなめらかな丸石）
	draw_ellipse(rock_pos, 24.0, 18.0, Color(0.86, 0.88, 0.90, 0.98))
	draw_ellipse(rock_pos + Vector2(-3, -3), 18.0, 12.0, Color(0.96, 0.97, 0.98, 0.95))
	draw_ellipse(rock_pos + Vector2(4, 5), 16.0, 10.0, Color(0.72, 0.75, 0.78, 0.7))
	draw_arc(rock_pos, 24.0, 0, TAU, 32, Color(0.68, 0.70, 0.74, 0.6), 1.5)
		
	# 5. カニたち
	if tex_crab:
		for c in crabs:
			var w_phase = sin(time_counter * 12.0) * 1.5 if c["pause_time"] <= 0.0 else 0.0
			var c_pos = c["pos"] + Vector2(0, w_phase)
			draw_texture_rect(tex_crab, Rect2(c_pos, tex_crab.get_size() * c["scale"]), false)
			
	# 6. ヤシの木（Palm Tree - 画面右上に大きく茂る）
	if tex_palm:
		var palm_pos = Vector2(810, 20)
		var palm_size = tex_palm.get_size() * 0.62
		# 幹の影
		draw_ellipse(palm_pos + Vector2(palm_size.x * 0.48, palm_size.y - 30), 85.0, 26.0, Color(0.55, 0.48, 0.35, 0.4))
		draw_texture_rect(tex_palm, Rect2(palm_pos, palm_size), false)
		
	# 7. 青い蝶
	for b in butterflies:
		var b_pos = b["pos"]
		var flap = abs(sin(time_counter * 9.0))
		# 蝶の羽（青色）
		draw_ellipse(b_pos + Vector2(-3.0 * flap, -2), 4.0 * flap, 5.0, b["color"])
		draw_ellipse(b_pos + Vector2(3.0 * flap, -2), 4.0 * flap, 5.0, b["color"])
		draw_circle(b_pos, 1.2, Color(0.1, 0.1, 0.1, 0.8))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 小屋のクリックでショップを開く
		var shack_clickable = Rect2(10, 10, 220, 200)
		if shack_clickable.has_point(event.position):
			shop_interacted.emit()
