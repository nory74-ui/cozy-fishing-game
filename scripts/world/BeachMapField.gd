extends Node2D

# 福岡県・糸島「野北（のぎた）漁港 大波止 ＆ 野北サーフ」マップ
# 玄界灘の透明な海、コンクリート大波止、テトラポッド、白砂サーフを完全再現

signal shop_interacted()

var tex_crab: Texture2D
var time_counter: float = 0.0

# カニたちの動的データ
var crabs: Array[Dictionary] = []

# 青い蝶の動的データ
var butterflies: Array[Dictionary] = []

# 画面サイズ
const SCREEN_SIZE = Vector2(1152, 648)

# 大波止（防波堤）の定義
# X: 0 〜 540, Y: 195 〜 355
const PIER_RECT = Rect2(0, 195, 540, 160)
const PIER_WALK_RECT = Rect2(20, 205, 520, 140)

# スロープ（堤防と砂浜の接続部）
const SLOPE_RECT = Rect2(530, 230, 180, 110)

func _ready() -> void:
	tex_crab = GameData.load_texture("res://assets/beach_crab.png")
	_init_crabs()
	_init_butterflies()

func _init_crabs() -> void:
	crabs.clear()
	# 野北サーフの白砂を歩くカニ
	crabs.append({
		"pos": Vector2(820, 160),
		"origin": Vector2(820, 160),
		"vel": Vector2(-12, 4),
		"walk_time": 0.0,
		"pause_time": 1.5,
		"scale": Vector2(0.85, 0.85)
	})
	crabs.append({
		"pos": Vector2(890, 480),
		"origin": Vector2(890, 480),
		"vel": Vector2(10, -5),
		"walk_time": 0.0,
		"pause_time": 2.2,
		"scale": Vector2(0.75, 0.75)
	})

func _init_butterflies() -> void:
	butterflies.clear()
	butterflies.append({
		"pos": Vector2(980, 180),
		"origin": Vector2(980, 180),
		"angle": 0.0,
		"radius": 40.0,
		"speed": 1.3,
		"color": Color(0.25, 0.68, 1.0, 0.95)
	})
	butterflies.append({
		"pos": Vector2(760, 300),
		"origin": Vector2(760, 300),
		"angle": 1.5,
		"radius": 30.0,
		"speed": 1.1,
		"color": Color(0.95, 0.85, 0.35, 0.9)
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
				var offset_from_orig = c["pos"] - c["origin"]
				if offset_from_orig.length() > 40.0:
					c["vel"] = -c["vel"].normalized() * randf_range(10, 16)
				else:
					c["vel"] = Vector2(randf_range(-16, 16), randf_range(-10, 10))
					
	# 蝶の舞い
	for b in butterflies:
		b["angle"] += delta * b["speed"]
		b["pos"] = b["origin"] + Vector2(cos(b["angle"]) * b["radius"], sin(b["angle"] * 1.5) * (b["radius"] * 0.6))
		
	queue_redraw()

# 野北サーフの海岸線（波打ち際のX座標）
func get_shore_x(y: float) -> float:
	var uv_y = y / SCREEN_SIZE.y
	var curve_uv = 0.63 + sin(uv_y * PI * 0.95 + 0.2) * 0.08 + (uv_y - 0.5) * 0.06
	return curve_uv * SCREEN_SIZE.x

# プレイヤーの歩行可能エリア判定（絶対に海でスタックしない安全判定）
func is_point_walkable(pos: Vector2) -> bool:
	# 画面外制限
	if pos.x < 25.0 or pos.x > SCREEN_SIZE.x - 25.0 or pos.y < 25.0 or pos.y > SCREEN_SIZE.y - 25.0:
		return false

	# 1. 大波止（防波堤の上）: 広々としたコンクリートの足場
	if PIER_WALK_RECT.has_point(pos):
		# 波止の設備衝突（常夜灯ポール、ベンチ）
		var light_pole_rect = Rect2(505, 220, 25, 25)
		if light_pole_rect.has_point(pos):
			return false
		var bench_rect = Rect2(360, 210, 50, 25)
		if bench_rect.has_point(pos):
			return false
		return true

	# 2. スロープ（波止と砂浜の接続部）
	if SLOPE_RECT.has_point(pos):
		return true

	# 3. 野北サーフ（白砂海岸）: 波打ち際より陸地側
	var shore_x = get_shore_x(pos.y)
	if pos.x >= shore_x - 15.0:
		return true

	# それ以外は海
	return false

# キャスト対象（水面かどうか）
func is_water(pos: Vector2) -> bool:
	# 陸地（波止、スロープ、砂浜）以外はすべて海
	return not is_point_walkable(pos)

func is_castable_water(pos: Vector2) -> bool:
	if not is_water(pos):
		return false
	# 画面端の制限
	if pos.x < 30.0 or pos.x > SCREEN_SIZE.x - 30.0 or pos.y < 30.0 or pos.y > SCREEN_SIZE.y - 30.0:
		return false
	return true

func is_in_safe_water(pos: Vector2) -> bool:
	return is_castable_water(pos)

func get_clamped_safe_water_pos(pos: Vector2) -> Vector2:
	var res = pos
	res.x = clampf(res.x, 50.0, SCREEN_SIZE.x - 50.0)
	res.y = clampf(res.y, 50.0, SCREEN_SIZE.y - 50.0)
	# もし陸地をクリックしたら海側へオフセット
	if not is_water(res):
		if res.x > 500.0:
			res.x = get_shore_x(res.y) - 60.0
		elif res.y < 280.0:
			res.y = 150.0
		else:
			res.y = 420.0
	return res

func is_in_water(pos: Vector2) -> bool:
	return is_water(pos)

func is_on_pier(pos: Vector2) -> bool:
	return PIER_WALK_RECT.has_point(pos)

func is_on_island(pos: Vector2) -> bool:
	return false

func _draw() -> void:
	# ==========================================
	# 1. 水底のディテール（透明な海を通して透ける）
	# ==========================================
	# A. 堤防の海中基礎（捨石・ケーソン基礎）
	var base_poly = PackedVector2Array([
		Vector2(0, 175),
		Vector2(555, 175),
		Vector2(575, 205),
		Vector2(575, 365),
		Vector2(555, 385),
		Vector2(0, 385)
	])
	draw_colored_polygon(base_poly, Color(0.18, 0.32, 0.35, 0.65))
	
	# B. 水底に揺れるホンダワラ藻場（玄界灘の豊かな海藻）
	var seaweed_color = Color(0.14, 0.38, 0.22, 0.65)
	for i in range(12):
		var sx = 60.0 + i * 40.0
		var sy1 = 160.0 + sin(i * 1.5) * 15.0
		var sy2 = 410.0 + cos(i * 1.8) * 20.0
		var sway = sin(time_counter * 1.8 + i) * 6.0
		# 北側の海藻
		draw_line(Vector2(sx, sy1 + 15), Vector2(sx + sway, sy1), seaweed_color, 4.0)
		draw_circle(Vector2(sx + sway, sy1), 5.0, seaweed_color)
		# 南側の海藻
		draw_line(Vector2(sx + 20, sy2 - 15), Vector2(sx + 20 + sway, sy2), seaweed_color, 4.5)
		draw_circle(Vector2(sx + 20 + sway, sy2), 6.0, seaweed_color)

	# C. 大波止南側のテトラポッド消波ブロック帯（水底〜水面）
	_draw_tetrapods()

	# ==========================================
	# 2. 大波止（コンクリート防波堤本体）
	# ==========================================
	_draw_pier()

	# ==========================================
	# 3. スロープ・ウッドデッキ連絡路
	# ==========================================
	_draw_slope()

	# ==========================================
	# 4. 白砂サーフの小物（小石、貝殻、漂着物）
	# ==========================================
	_draw_beach_details()

	# ==========================================
	# 5. 生き物（カニ、蝶）
	# ==========================================
	_draw_creatures()

func _draw_tetrapods() -> void:
	# 大波止南側のテトラポッド（消波ブロック）群
	var tetra_base_color = Color(0.48, 0.52, 0.56, 0.95)
	var tetra_light_color = Color(0.68, 0.72, 0.76, 0.95)
	var tetra_shadow_color = Color(0.32, 0.35, 0.38, 0.95)
	
	for i in range(11):
		var tx = 40.0 + i * 46.0
		var ty = 368.0 + (i % 2) * 16.0
		# テトラの足（4本の円柱を組んだ形状）
		# 影
		draw_circle(Vector2(tx + 4, ty + 8), 16.0, Color(0.1, 0.2, 0.25, 0.4))
		# 3つの足
		draw_circle(Vector2(tx - 10, ty + 6), 11.0, tetra_shadow_color)
		draw_circle(Vector2(tx + 10, ty + 6), 11.0, tetra_base_color)
		draw_circle(Vector2(tx, ty - 8), 12.0, tetra_light_color)
		# 中央ノード
		draw_circle(Vector2(tx, ty), 10.0, tetra_light_color)

func _draw_pier() -> void:
	# 堤防の側壁の立体感（厚み）
	var wall_rect_top = Rect2(0, 192, 540, 10)
	draw_rect(wall_rect_top, Color(0.62, 0.65, 0.68, 1.0))
	
	var wall_rect_bot = Rect2(0, 350, 540, 14)
	draw_rect(wall_rect_bot, Color(0.42, 0.45, 0.48, 1.0))

	var wall_rect_end = Rect2(536, 192, 10, 172)
	draw_rect(wall_rect_end, Color(0.50, 0.53, 0.56, 1.0))

	# 堤防の天板（白いコンクリート床）
	var deck_rect = Rect2(0, 202, 536, 148)
	draw_rect(deck_rect, Color(0.88, 0.89, 0.90, 1.0))
	
	# コンクリートの継ぎ目（目地スリットライン）
	for i in range(1, 6):
		var sx = i * 90.0
		draw_line(Vector2(sx, 202), Vector2(sx, 350), Color(0.72, 0.74, 0.76, 0.9), 1.5)

	# 縁石・黄黒の警戒安全ライン（エプロン）
	var curb_color_yellow = Color(0.95, 0.78, 0.15, 1.0)
	var curb_color_black = Color(0.22, 0.24, 0.26, 1.0)
	
	# 上側縁石
	draw_rect(Rect2(0, 202, 536, 6), curb_color_yellow)
	for i in range(18):
		if i % 2 == 1:
			draw_rect(Rect2(i * 30.0, 202, 15.0, 6), curb_color_black)

	# 下側縁石
	draw_rect(Rect2(0, 344, 536, 6), curb_color_yellow)
	for i in range(18):
		if i % 2 == 1:
			draw_rect(Rect2(i * 30.0, 344, 15.0, 6), curb_color_black)

	# 先端縁石
	draw_rect(Rect2(530, 202, 6, 148), curb_color_yellow)
	for i in range(5):
		if i % 2 == 1:
			draw_rect(Rect2(530, 202 + i * 30.0, 6, 15.0), curb_color_black)

	# 係留用ボラード（ビット）3箇所
	var bollard_positions = [Vector2(140, 214), Vector2(320, 214), Vector2(480, 214)]
	for bp in bollard_positions:
		# 影
		draw_ellipse(bp + Vector2(2, 4), 7.0, 3.5, Color(0.2, 0.2, 0.2, 0.35))
		# ボラード本体（鋳鉄）
		draw_circle(bp, 5.5, Color(0.28, 0.30, 0.32, 1.0))
		draw_circle(bp + Vector2(-1, -1), 3.5, Color(0.48, 0.50, 0.52, 1.0))

	# 木製釣りベンチ
	var b_pos = Vector2(360, 214)
	draw_rect(Rect2(b_pos + Vector2(3, 4), Vector2(46, 18)), Color(0.2, 0.2, 0.2, 0.25))
	draw_rect(Rect2(b_pos, Vector2(46, 18)), Color(0.68, 0.48, 0.30, 1.0))
	draw_rect(Rect2(b_pos + Vector2(2, 2), Vector2(42, 14)), Color(0.78, 0.58, 0.38, 1.0))
	draw_line(Vector2(b_pos.x, b_pos.y + 9), Vector2(b_pos.x + 46, b_pos.y + 9), Color(0.58, 0.38, 0.22, 1.0), 1.0)

	# 白灯台ポール（野北漁港のシンボル常夜灯）
	var pole_pos = Vector2(512, 230)
	# 影
	draw_ellipse(pole_pos + Vector2(6, 10), 18.0, 6.0, Color(0.2, 0.2, 0.2, 0.35))
	# 台座
	draw_circle(pole_pos, 14.0, Color(0.75, 0.78, 0.82, 1.0))
	draw_circle(pole_pos, 10.0, Color(0.92, 0.94, 0.96, 1.0))
	# 柱本体
	draw_rect(Rect2(pole_pos.x - 4, pole_pos.y - 48, 8, 48), Color(0.95, 0.96, 0.98, 1.0))
	draw_rect(Rect2(pole_pos.x - 2, pole_pos.y - 46, 3, 46), Color(1.0, 1.0, 1.0, 0.9))
	# ランプ部
	draw_circle(Vector2(pole_pos.x, pole_pos.y - 52), 7.0, Color(0.98, 0.92, 0.55, 0.95))
	draw_circle(Vector2(pole_pos.x, pole_pos.y - 52), 4.0, Color(1.0, 0.99, 0.85, 1.0))
	# 屋根
	draw_line(Vector2(pole_pos.x - 8, pole_pos.y - 56), Vector2(pole_pos.x + 8, pole_pos.y - 56), Color(0.25, 0.45, 0.75, 1.0), 3.0)

	# 救命浮環（オレンジと白）
	var ring_pos = Vector2(450, 335)
	draw_circle(ring_pos, 9.0, Color(0.95, 0.40, 0.15, 1.0))
	draw_circle(ring_pos, 5.0, Color(0.88, 0.89, 0.90, 1.0))
	draw_circle(ring_pos + Vector2(-4, 0), 2.5, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(ring_pos + Vector2(4, 0), 2.5, Color(1.0, 1.0, 1.0, 0.95))

	# 「糸島・野北漁港」案内プレート（クリックでショップオープン）
	var sign_pos = Vector2(40, 222)
	draw_rect(Rect2(sign_pos + Vector2(2, 3), Vector2(70, 36)), Color(0.2, 0.2, 0.2, 0.25))
	draw_rect(Rect2(sign_pos, Vector2(70, 36)), Color(0.25, 0.42, 0.55, 0.95))
	draw_rect(Rect2(sign_pos + Vector2(2, 2), Vector2(66, 32)), Color(0.96, 0.97, 0.98, 1.0))
	draw_string(ThemeDB.fallback_font, sign_pos + Vector2(10, 16), "野北波止", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.25, 0.35, 1.0))
	draw_string(ThemeDB.fallback_font, sign_pos + Vector2(10, 28), "釣具・店", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.40, 0.20, 1.0))

func _draw_slope() -> void:
	# 大波止から野北サーフ（砂浜）へのウッドデッキスロープ
	var slope_poly = PackedVector2Array([
		Vector2(536, 235),
		Vector2(690, 255),
		Vector2(690, 325),
		Vector2(536, 345)
	])
	# 影
	var shadow_poly = PackedVector2Array([
		Vector2(536, 345),
		Vector2(690, 325),
		Vector2(696, 335),
		Vector2(536, 352)
	])
	draw_colored_polygon(shadow_poly, Color(0.2, 0.2, 0.2, 0.25))
	draw_colored_polygon(slope_poly, Color(0.78, 0.62, 0.44, 1.0))
	
	# 板の木目ライン
	for i in range(7):
		var t = float(i) / 6.0
		var p1 = lerp(Vector2(536, 235), Vector2(690, 255), t)
		var p2 = lerp(Vector2(536, 345), Vector2(690, 325), t)
		draw_line(p1, p2, Color(0.58, 0.42, 0.26, 0.85), 1.5)

func _draw_beach_details() -> void:
	# 野北サーフの白砂に散らばる小石、貝殻（桜貝）
	var pebbles = [
		Vector2(750, 140), Vector2(810, 220), Vector2(860, 360),
		Vector2(790, 440), Vector2(880, 560), Vector2(930, 290)
	]
	for p in pebbles:
		draw_ellipse(p + Vector2(2, 2), 6.0, 3.5, Color(0.55, 0.48, 0.38, 0.35))
		draw_ellipse(p, 5.0, 3.5, Color(0.92, 0.90, 0.86, 0.95))
		draw_ellipse(p + Vector2(-1, -1), 3.0, 2.0, Color(0.98, 0.98, 0.98, 0.95))

	# 桜貝（淡いピンクの貝殻）
	var shells = [Vector2(770, 270), Vector2(840, 180), Vector2(920, 460)]
	for s in shells:
		draw_circle(s, 3.5, Color(0.98, 0.82, 0.85, 0.95))
		draw_circle(s + Vector2(-0.5, -0.5), 2.0, Color(1.0, 0.94, 0.95, 0.95))

func _draw_creatures() -> void:
	# カニたち
	if tex_crab:
		for c in crabs:
			var w_phase = sin(time_counter * 12.0) * 1.5 if c["pause_time"] <= 0.0 else 0.0
			var c_pos = c["pos"] + Vector2(0, w_phase)
			draw_texture_rect(tex_crab, Rect2(c_pos, tex_crab.get_size() * c["scale"]), false)

	# 青い蝶・黄色い蝶
	for b in butterflies:
		var b_pos = b["pos"]
		var flap = abs(sin(time_counter * 9.0))
		draw_ellipse(b_pos + Vector2(-3.0 * flap, -2), 4.5 * flap, 5.5, b["color"])
		draw_ellipse(b_pos + Vector2(3.0 * flap, -2), 4.5 * flap, 5.5, b["color"])
		draw_circle(b_pos, 1.2, Color(0.1, 0.1, 0.1, 0.85))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 案内看板または波止の店クリックでショップを開く
		var sign_rect = Rect2(30, 210, 90, 50)
		if sign_rect.has_point(event.position):
			shop_interacted.emit()
