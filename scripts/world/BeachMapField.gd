extends Node2D

# うみかぜ日和 〜 日本全国お魚釣り旅：福岡・糸島編 〜
# 添付動画（ForkedPush: I Just Wanted to Fish）完全再現：
# 究極のクォータービュー（斜め見下ろし3D視点）
# 1. 斜めアイソメトリックにせり出す高床式木造ウッドデッキ＆釣り小屋（Beach Shack & Pier）
# 2. 左奥から右手前へダイナミックに弧を描く斜めの波打ち際＆白砂サーフ
# 3. 桟橋の立体木柱（水面接触泡）、木箱、樽、漁網、浮き輪、野北波止の白灯台・縁石・ボラード
# 4. 砂浜に堂々とそびえ立つヤシの木（砂浜に斜めに落ちるリアルなソフトシャドウ）と海岸の大岩
# 5. 透き通るエメラルドの海の下に沈むサンゴ風海草、丸いスイレン浮草、玉石、揺れるホンダワラ藻場
# 6. カニの横歩き、舞うアゲハ蝶

signal shop_interacted()

var tex_crab: Texture2D
var time_counter: float = 0.0

# カニたちの動的データ
var crabs: Array[Dictionary] = []

# 蝶の動的データ
var butterflies: Array[Dictionary] = []

# 画面サイズ
const SCREEN_SIZE = Vector2(1152, 648)

# クォータービュー歩行可能エリア
# 1. 斜め木造ウッドデッキ桟橋（小屋の前から海へせり出すデッキ）
# ポリゴン判定用
var deck_walk_poly: PackedVector2Array = PackedVector2Array([
	Vector2(0, 95),
	Vector2(330, 140),
	Vector2(295, 275),
	Vector2(0, 235)
])

# 2. デッキから砂浜への連絡スロープ
var slope_walk_poly: PackedVector2Array = PackedVector2Array([
	Vector2(295, 170),
	Vector2(480, 195),
	Vector2(470, 265),
	Vector2(285, 240)
])

func _ready() -> void:
	tex_crab = GameData.load_texture("res://assets/beach_crab.png")
	_init_crabs()
	_init_butterflies()

func _init_crabs() -> void:
	crabs.clear()
	crabs.append({
		"pos": Vector2(760, 210),
		"origin": Vector2(760, 210),
		"vel": Vector2(-10, 4),
		"walk_time": 0.0,
		"pause_time": 1.5,
		"scale": Vector2(0.85, 0.85)
	})
	crabs.append({
		"pos": Vector2(880, 460),
		"origin": Vector2(880, 460),
		"vel": Vector2(10, -5),
		"walk_time": 0.0,
		"pause_time": 2.2,
		"scale": Vector2(0.75, 0.75)
	})

func _init_butterflies() -> void:
	butterflies.clear()
	butterflies.append({
		"pos": Vector2(920, 180),
		"origin": Vector2(920, 180),
		"angle": 0.0,
		"radius": 45.0,
		"speed": 1.2,
		"color": Color(0.25, 0.68, 1.0, 0.95)
	})
	butterflies.append({
		"pos": Vector2(780, 320),
		"origin": Vector2(780, 320),
		"angle": 1.5,
		"radius": 32.0,
		"speed": 1.1,
		"color": Color(0.96, 0.86, 0.35, 0.9)
	})

func _process(delta: float) -> void:
	time_counter += delta
	
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
					
	for b in butterflies:
		b["angle"] += delta * b["speed"]
		b["pos"] = b["origin"] + Vector2(cos(b["angle"]) * b["radius"], sin(b["angle"] * 1.5) * (b["radius"] * 0.6))
		
	queue_redraw()

# クォータービュー海岸線（斜めの波打ち際X座標）
func get_shore_x(y: float) -> float:
	var uv_y = y / SCREEN_SIZE.y
	var curve_uv = 0.44 + uv_y * 0.36 + sin(uv_y * PI * 0.85) * 0.07
	return curve_uv * SCREEN_SIZE.x

# プレイヤーの歩行可能エリア判定
func is_point_walkable(pos: Vector2) -> bool:
	if pos.x < 20.0 or pos.x > SCREEN_SIZE.x - 25.0 or pos.y < 25.0 or pos.y > SCREEN_SIZE.y - 25.0:
		return false

	# 1. 斜め木造ウッドデッキ
	if Geometry2D.is_point_in_polygon(pos, deck_walk_poly):
		# 小屋の壁面
		if pos.x < 140 and pos.y < 165:
			return false
		# 白灯台ポール
		if (pos - Vector2(305, 175)).length() < 18.0:
			return false
		return true

	# 2. デッキから砂浜へのスロープ
	if Geometry2D.is_point_in_polygon(pos, slope_walk_poly):
		return true

	# 3. 白砂サーフ（斜めの波打ち際より陸地側）
	var shore_x = get_shore_x(pos.y)
	if pos.x >= shore_x - 18.0:
		# 海岸の大岩への衝突
		if (pos - Vector2(725, 275)).length() < 28.0:
			return false
		# ヤシの木の幹への衝突
		if (pos - Vector2(980, 420)).length() < 24.0:
			return false
		return true

	return false

func is_water(pos: Vector2) -> bool:
	return not is_point_walkable(pos)

func is_castable_water(pos: Vector2) -> bool:
	if not is_water(pos):
		return false
	if pos.x < 30.0 or pos.x > SCREEN_SIZE.x - 30.0 or pos.y < 30.0 or pos.y > SCREEN_SIZE.y - 30.0:
		return false
	return true

func is_in_safe_water(pos: Vector2) -> bool:
	return is_castable_water(pos)

func get_clamped_safe_water_pos(pos: Vector2) -> Vector2:
	var res = pos
	res.x = clampf(res.x, 50.0, SCREEN_SIZE.x - 50.0)
	res.y = clampf(res.y, 50.0, SCREEN_SIZE.y - 50.0)
	if not is_water(res):
		var shore_x = get_shore_x(res.y)
		if res.x > shore_x - 40.0:
			res.x = shore_x - 70.0
		elif res.y < 280.0:
			res.y = 150.0
		else:
			res.y = 420.0
	return res

func is_in_water(pos: Vector2) -> bool:
	return is_water(pos)

func is_on_pier(pos: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(pos, deck_walk_poly)

func is_on_island(pos: Vector2) -> bool:
	return false

func _draw() -> void:
	# =========================================================================
	# レイヤー 1: 水底のディテール（透き通る水面下にリアルに沈む植物・岩）
	# =========================================================================
	_draw_seabed_details()

	# =========================================================================
	# レイヤー 2: 水中構造物の基礎（テトラポッド、水中の杭、捨石基礎）
	# =========================================================================
	_draw_submerged_structures()

	# =========================================================================
	# レイヤー 3: アイソメトリック斜めウッドデッキ桟橋＆釣り小屋・スロープ
	# =========================================================================
	_draw_isometric_pier_and_shack()
	_draw_slope()

	# =========================================================================
	# レイヤー 4: 砂浜の自然（海岸の大岩、ヤシの木、ソフトシャドウ、貝殻）
	# =========================================================================
	_draw_beach_nature()
	_draw_creatures()

# -----------------------------------------------------------------------------
# レイヤー 1: 水底のディテール（透き通る水底に見える滑らかな石・海草）
# -----------------------------------------------------------------------------
func _draw_seabed_details() -> void:
	# A. 水底の滑らかな玉石
	var seabed_rocks = [
		Vector2(240, 480), Vector2(300, 530), Vector2(390, 460),
		Vector2(170, 390), Vector2(330, 110), Vector2(390, 80),
		Vector2(510, 160), Vector2(590, 430), Vector2(540, 510)
	]
	for r in seabed_rocks:
		draw_ellipse(r + Vector2(3, 5), 14.0, 8.5, Color(0.10, 0.25, 0.28, 0.35))
		draw_ellipse(r, 12.0, 7.5, Color(0.68, 0.72, 0.65, 0.75))
		draw_ellipse(r + Vector2(-2, -2), 8.0, 4.5, Color(0.82, 0.86, 0.78, 0.80))

	# B. 動画完全再現：鮮やかなサンゴ風海草（紫・マゼンタ・ピンクの美しい海藻）
	var coral_positions = [
		Vector2(85, 480), Vector2(125, 520), Vector2(165, 460), Vector2(105, 430)
	]
	var coral_base = Color(0.55, 0.18, 0.45, 0.75)
	var coral_light = Color(0.85, 0.35, 0.65, 0.85)
	for cp in coral_positions:
		var sway = sin(time_counter * 1.5 + cp.x) * 4.0
		draw_circle(cp + Vector2(2, 3), 6.0, Color(0.1, 0.2, 0.2, 0.3))
		for j in range(5):
			var a = j * (TAU / 5.0) + time_counter * 0.2
			var petal_pos = cp + Vector2(cos(a) * 11.0 + sway * 0.5, sin(a) * 8.0)
			draw_circle(petal_pos, 7.0, coral_base)
			draw_circle(petal_pos + Vector2(-1, -1), 4.5, coral_light)
		draw_circle(cp + Vector2(sway * 0.3, 0), 6.0, Color(0.95, 0.60, 0.75, 0.90))

	# C. 動画完全再現：丸いスイレン風浮草・緑のリーフパッド
	var lily_positions = [
		Vector2(135, 410), Vector2(185, 440), Vector2(225, 400), Vector2(160, 460)
	]
	var lily_dark = Color(0.15, 0.45, 0.28, 0.80)
	var lily_light = Color(0.35, 0.78, 0.45, 0.90)
	for lp in lily_positions:
		var float_bob = sin(time_counter * 2.0 + lp.x * 0.2) * 2.5
		var center = lp + Vector2(0, float_bob)
		draw_ellipse(center + Vector2(3, 5), 14.0, 9.0, Color(0.08, 0.22, 0.20, 0.30))
		draw_ellipse(center, 13.0, 8.5, lily_dark)
		draw_ellipse(center + Vector2(-1, -1), 10.0, 6.5, lily_light)
		draw_line(center, center + Vector2(10, 0), Color(0.20, 0.65, 0.60, 0.8), 2.0)

	# D. ゆらゆら揺れるホンダワラ藻場（玄界灘の豊かな海藻）
	var seaweed_color = Color(0.18, 0.42, 0.25, 0.70)
	var seaweed_tip = Color(0.32, 0.65, 0.38, 0.85)
	for i in range(12):
		var sx = 60.0 + i * 36.0
		var sy1 = 140.0 + sin(i * 1.5) * 16.0
		var sy2 = 380.0 + cos(i * 1.8) * 20.0
		var sway = sin(time_counter * 1.6 + i * 0.7) * 7.0
		draw_line(Vector2(sx, sy1 + 18), Vector2(sx + sway, sy1), seaweed_color, 4.5)
		draw_circle(Vector2(sx + sway, sy1), 5.5, seaweed_tip)
		draw_line(Vector2(sx + 15, sy2 - 18), Vector2(sx + 15 + sway, sy2), seaweed_color, 4.5)
		draw_circle(Vector2(sx + 15 + sway, sy2), 6.0, seaweed_tip)

# -----------------------------------------------------------------------------
# レイヤー 2: 水中構造物の基礎・テトラポッド
# -----------------------------------------------------------------------------
func _draw_submerged_structures() -> void:
	# A. 桟橋・波止の水中捨石基礎（斜めパース）
	var base_poly = PackedVector2Array([
		Vector2(0, 110),
		Vector2(345, 155),
		Vector2(325, 290),
		Vector2(0, 250)
	])
	draw_colored_polygon(base_poly, Color(0.14, 0.28, 0.30, 0.50))

	# B. 消波テトラポッド帯（外海側の立体テトラブロック群）
	var tetra_base_color = Color(0.46, 0.52, 0.56, 0.95)
	var tetra_light_color = Color(0.68, 0.74, 0.78, 0.95)
	var tetra_shadow_color = Color(0.30, 0.34, 0.38, 0.95)
	
	for i in range(8):
		var t = float(i) / 7.0
		var tx = lerp(40.0, 290.0, t)
		var ty = lerp(265.0, 305.0, t) + (i % 2) * 12.0
		draw_circle(Vector2(tx + 4, ty + 8), 16.0, Color(0.08, 0.20, 0.24, 0.40))
		draw_circle(Vector2(tx - 10, ty + 6), 11.0, tetra_shadow_color)
		draw_circle(Vector2(tx + 10, ty + 6), 11.0, tetra_base_color)
		draw_circle(Vector2(tx, ty - 8), 12.0, tetra_light_color)
		draw_circle(Vector2(tx, ty), 10.0, tetra_light_color)
		
		var foam_phase = sin(time_counter * 2.5 + i) * 1.5
		draw_arc(Vector2(tx, ty - 2), 14.0 + foam_phase, 0.0, TAU, 12, Color(1.0, 1.0, 1.0, 0.45), 2.0)

# -----------------------------------------------------------------------------
# レイヤー 3: アイソメトリック斜めウッドデッキ桟橋＆釣り小屋（Beach Shack & Pier）
# -----------------------------------------------------------------------------
func _draw_isometric_pier_and_shack() -> void:
	# A. 水中に突き刺さる木製の立体柱（Pillars / Piles）
	var pillars = [
		Vector2(50, 250), Vector2(130, 262), Vector2(210, 274), Vector2(290, 286),
		Vector2(325, 160)
	]
	for p in pillars:
		# 水中影
		draw_line(p, p + Vector2(4, 20), Color(0.08, 0.18, 0.20, 0.50), 9.0)
		# 垂直木柱本体
		draw_line(p - Vector2(0, 18), p + Vector2(0, 10), Color(0.36, 0.24, 0.15, 1.0), 9.0)
		draw_line(p - Vector2(1, 18), p - Vector2(1, 10), Color(0.55, 0.38, 0.26, 1.0), 3.5)
		# 水面接触白泡（Contact Foam）
		var p_foam = abs(sin(time_counter * 2.2 + p.x)) * 2.2
		draw_circle(p + Vector2(0, 5), 7.5 + p_foam, Color(1.0, 1.0, 1.0, 0.70))

	# B. クォータービュー・ウッドデッキ桟橋（斜めアイソメトリック木床）
	# デッキ全体の影（斜め下へ）
	var deck_shadow = PackedVector2Array([
		Vector2(0, 105),
		Vector2(335, 150),
		Vector2(305, 290),
		Vector2(0, 250)
	])
	draw_colored_polygon(deck_shadow, Color(0.12, 0.22, 0.24, 0.35))

	# デッキ手前側面（厚み14pxの板張り側面）
	var deck_side = PackedVector2Array([
		Vector2(0, 235),
		Vector2(295, 275),
		Vector2(295, 289),
		Vector2(0, 249)
	])
	draw_colored_polygon(deck_side, Color(0.46, 0.30, 0.18, 1.0))
	draw_line(Vector2(0, 249), Vector2(295, 289), Color(0.30, 0.18, 0.10, 1.0), 2.0)

	# デッキ上面（アイソメトリック斜め板張り床）
	draw_colored_polygon(deck_walk_poly, Color(0.76, 0.58, 0.38, 1.0))
	
	# 斜めに張られた木板の目地ライン
	for i in range(1, 15):
		var t = float(i) / 14.0
		var p_top = lerp(Vector2(0, 95), Vector2(330, 140), t)
		var p_bot = lerp(Vector2(0, 235), Vector2(295, 275), t)
		draw_line(p_top, p_bot, Color(0.52, 0.36, 0.22, 0.85), 1.6)
		# 釘の頭
		draw_circle(lerp(p_top, p_bot, 0.15), 1.2, Color(0.32, 0.20, 0.10, 0.9))
		draw_circle(lerp(p_top, p_bot, 0.85), 1.2, Color(0.32, 0.20, 0.10, 0.9))

	# 先端の野北縁石ライン（黄黒警戒ライン）
	var curb_start = Vector2(330, 140)
	var curb_end = Vector2(295, 275)
	draw_line(curb_start, curb_end, Color(0.95, 0.78, 0.15, 1.0), 6.0)
	for k in range(8):
		if k % 2 == 1:
			var ck1 = lerp(curb_start, curb_end, float(k) / 8.0)
			var ck2 = lerp(curb_start, curb_end, float(k + 1) / 8.0)
			draw_line(ck1, ck2, Color(0.22, 0.24, 0.26, 1.0), 6.0)

	# デッキ手すりロープ
	draw_line(Vector2(0, 95), Vector2(330, 140), Color(0.50, 0.34, 0.20, 1.0), 3.0)

	# C. アイソメトリック釣り小屋（Beach Shack 本体：左上）
	# 小屋の影
	draw_rect(Rect2(25, 48, 130, 85), Color(0.15, 0.15, 0.15, 0.35))
	
	# 小屋の壁面
	var shack_rect = Rect2(15, 40, 130, 85)
	draw_rect(shack_rect, Color(0.70, 0.50, 0.34, 1.0))
	draw_rect(Rect2(19, 43, 122, 78), Color(0.82, 0.64, 0.46, 1.0))
	for x in range(30, 140, 14):
		draw_line(Vector2(x, 43), Vector2(x, 121), Color(0.62, 0.44, 0.28, 0.7), 1.2)
	
	# 青い木製ドア
	var door_rect = Rect2(60, 75, 30, 48)
	draw_rect(door_rect, Color(0.24, 0.48, 0.65, 1.0))
	draw_rect(Rect2(62, 77, 26, 44), Color(0.34, 0.60, 0.78, 1.0))
	draw_circle(Vector2(65, 99), 2.2, Color(0.95, 0.85, 0.40, 1.0))

	# 小屋の立体屋根（庇）
	var roof_poly = PackedVector2Array([
		Vector2(8, 43), Vector2(155, 43), Vector2(145, 28), Vector2(18, 28)
	])
	draw_colored_polygon(roof_poly, Color(0.52, 0.30, 0.18, 1.0))
	draw_line(Vector2(8, 43), Vector2(155, 43), Color(0.38, 0.22, 0.12, 1.0), 2.5)

	# 救命浮輪
	var r_center = Vector2(118, 72)
	draw_circle(r_center, 9.0, Color(0.92, 0.30, 0.18, 1.0))
	draw_circle(r_center, 4.5, Color(0.82, 0.64, 0.46, 1.0))
	draw_circle(r_center + Vector2(-4, 0), 2.5, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(r_center + Vector2(4, 0), 2.5, Color(1.0, 1.0, 1.0, 0.95))

	# D. デッキ上の小物（立体木箱、樽、漁網）
	# 木製樽
	var barrel_pos = Vector2(165, 125)
	draw_ellipse(barrel_pos + Vector2(2, 4), 10.0, 7.0, Color(0.15, 0.15, 0.15, 0.30))
	draw_ellipse(barrel_pos, 9.0, 7.5, Color(0.55, 0.36, 0.22, 1.0))
	draw_ellipse(barrel_pos, 7.5, 6.0, Color(0.68, 0.48, 0.32, 1.0))
	draw_arc(barrel_pos, 8.0, 0, TAU, 12, Color(0.32, 0.32, 0.35, 1.0), 2.0)

	# 積まれた立体木箱
	var crate_pos1 = Vector2(185, 135)
	var crate_pos2 = Vector2(195, 122)
	draw_rect(Rect2(crate_pos1 + Vector2(2, 4), Vector2(22, 20)), Color(0.15, 0.15, 0.15, 0.25))
	draw_rect(Rect2(crate_pos1, Vector2(22, 20)), Color(0.72, 0.54, 0.36, 1.0))
	draw_rect(Rect2(crate_pos1, Vector2(22, 6)), Color(0.82, 0.64, 0.44, 1.0))
	draw_line(crate_pos1, crate_pos1 + Vector2(22, 20), Color(0.52, 0.36, 0.22, 0.8), 1.5)
	
	draw_rect(Rect2(crate_pos2, Vector2(18, 16)), Color(0.80, 0.62, 0.42, 1.0))
	draw_line(crate_pos2, crate_pos2 + Vector2(18, 16), Color(0.58, 0.42, 0.26, 0.8), 1.5)

	# 巻き網・ロープ
	var net_pos = Vector2(230, 130)
	draw_circle(net_pos + Vector2(2, 3), 12.0, Color(0.15, 0.15, 0.15, 0.20))
	draw_circle(net_pos, 11.0, Color(0.48, 0.52, 0.44, 0.85))
	for r in range(3):
		draw_arc(net_pos, 4.0 + r * 3.0, 0, TAU, 10, Color(0.75, 0.65, 0.45, 0.9), 1.5)

	# E. 野北波止のシンボル設備（白灯台ポール・ボラード・案内看板）
	# 白灯台ポール
	var pole_pos = Vector2(305, 175)
	draw_ellipse(pole_pos + Vector2(5, 8), 16.0, 6.0, Color(0.2, 0.2, 0.2, 0.35))
	draw_circle(pole_pos, 13.0, Color(0.75, 0.78, 0.82, 1.0))
	draw_circle(pole_pos, 9.0, Color(0.92, 0.94, 0.96, 1.0))
	draw_rect(Rect2(pole_pos.x - 4, pole_pos.y - 45, 8, 45), Color(0.95, 0.96, 0.98, 1.0))
	draw_rect(Rect2(pole_pos.x - 2, pole_pos.y - 43, 3, 43), Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(Vector2(pole_pos.x, pole_pos.y - 49), 7.0, Color(0.98, 0.92, 0.55, 0.95))
	draw_circle(Vector2(pole_pos.x, pole_pos.y - 49), 4.0, Color(1.0, 0.99, 0.85, 1.0))
	draw_line(Vector2(pole_pos.x - 8, pole_pos.y - 53), Vector2(pole_pos.x + 8, pole_pos.y - 53), Color(0.25, 0.45, 0.75, 1.0), 3.0)

	# 係留ボラード
	var bollard_pos = Vector2(285, 255)
	draw_ellipse(bollard_pos + Vector2(2, 4), 7.0, 3.5, Color(0.2, 0.2, 0.2, 0.35))
	draw_circle(bollard_pos, 5.5, Color(0.28, 0.30, 0.32, 1.0))
	draw_circle(bollard_pos + Vector2(-1, -1), 3.5, Color(0.48, 0.50, 0.52, 1.0))

	# 「野北波止 釣具店」案内看板
	var sign_pos = Vector2(185, 215)
	draw_rect(Rect2(sign_pos + Vector2(2, 3), Vector2(68, 34)), Color(0.2, 0.2, 0.2, 0.25))
	draw_rect(Rect2(sign_pos, Vector2(68, 34)), Color(0.25, 0.42, 0.55, 0.95))
	draw_rect(Rect2(sign_pos + Vector2(2, 2), Vector2(64, 30)), Color(0.96, 0.97, 0.98, 1.0))
	draw_string(ThemeDB.fallback_font, sign_pos + Vector2(8, 15), "野北波止", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.25, 0.35, 1.0))
	draw_string(ThemeDB.fallback_font, sign_pos + Vector2(8, 26), "釣具・店", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.40, 0.20, 1.0))

func _draw_slope() -> void:
	# 桟橋から白砂サーフへの斜めスロープ
	var shadow_poly = PackedVector2Array([
		Vector2(285, 240),
		Vector2(470, 265),
		Vector2(475, 275),
		Vector2(285, 250)
	])
	draw_colored_polygon(shadow_poly, Color(0.2, 0.2, 0.2, 0.25))
	draw_colored_polygon(slope_walk_poly, Color(0.78, 0.62, 0.44, 1.0))
	
	for i in range(5):
		var t = float(i) / 4.0
		var p1 = lerp(Vector2(295, 170), Vector2(480, 195), t)
		var p2 = lerp(Vector2(285, 240), Vector2(470, 265), t)
		draw_line(p1, p2, Color(0.58, 0.42, 0.26, 0.85), 1.5)

# -----------------------------------------------------------------------------
# レイヤー 4: 砂浜の自然（海岸の大岩、ヤシの木、ソフトシャドウ、貝殻）
# -----------------------------------------------------------------------------
func _draw_beach_nature() -> void:
	# A. 動画完全再現：プレイヤー右側の海岸大岩（Beach Boulder: 立体球体描画）
	var b_pos = Vector2(725, 275)
	draw_ellipse(b_pos + Vector2(8, 12), 26.0, 14.0, Color(0.18, 0.20, 0.16, 0.35))
	draw_ellipse(b_pos, 24.0, 17.0, Color(0.55, 0.58, 0.60, 1.0))
	draw_ellipse(b_pos + Vector2(-3, -3), 19.0, 13.0, Color(0.72, 0.75, 0.77, 1.0))
	draw_ellipse(b_pos + Vector2(-7, -6), 11.0, 7.5, Color(0.86, 0.88, 0.90, 1.0))

	# B. 動画完全再現：砂浜の立派なヤシの木 ＆ 砂浜に斜めに広がる葉のソフトシャドウ
	var palm_base = Vector2(980, 420)
	var palm_crown = Vector2(930, 230)
	
	# 1. 砂浜に落ちるヤシの木の葉の影（動画のように左側へ斜めに柔らかく広がるソフトシャドウ）
	var shadow_origin = palm_base + Vector2(-120, -25)
	draw_line(palm_base, shadow_origin, Color(0.18, 0.20, 0.16, 0.24), 16.0)
	
	for i in range(7):
		var a = i * (PI / 3.8) - 2.3
		var s_len = 95.0 + (i % 3) * 15.0
		var s_mid = shadow_origin + Vector2(cos(a) * (s_len * 0.5), sin(a) * (s_len * 0.35))
		var s_tip = shadow_origin + Vector2(cos(a) * s_len, sin(a) * (s_len * 0.65))
		var s_perp = Vector2(-sin(a), cos(a)) * 18.0
		
		var s_poly = PackedVector2Array([
			shadow_origin,
			s_mid + s_perp,
			s_tip,
			s_mid - s_perp
		])
		draw_colored_polygon(s_poly, Color(0.14, 0.17, 0.13, 0.18))

	# 2. ヤシの木の幹（クォータービューで立体的に立ち上がる幹）
	var trunk_pts = [
		palm_base, Vector2(965, 360), Vector2(945, 295), palm_crown
	]
	for k in range(trunk_pts.size() - 1):
		var p1 = trunk_pts[k]
		var p2 = trunk_pts[k + 1]
		draw_line(p1, p2, Color(0.42, 0.28, 0.18, 1.0), 22.0 - k * 3.0)
		draw_line(p1 - Vector2(2, 0), p2 - Vector2(2, 0), Color(0.65, 0.48, 0.32, 1.0), 10.0)
		draw_circle(p1, 11.0 - k * 1.5, Color(0.32, 0.20, 0.12, 1.0))

	# 3. 豊かなヤシの葉（動画のようなふんわりとリッチな扇状ポリゴン葉）
	var leaf_dark = Color(0.14, 0.40, 0.18, 0.98)
	var leaf_mid = Color(0.24, 0.58, 0.24, 0.98)
	var leaf_bright = Color(0.48, 0.82, 0.32, 0.98)
	
	for i in range(8):
		var base_angle = i * (PI / 4.0) - 1.25
		var leaf_len = 125.0 + (i % 3) * 18.0
		var curve_pt = palm_crown + Vector2(cos(base_angle) * (leaf_len * 0.55), sin(base_angle) * (leaf_len * 0.45) + 12.0)
		var end_pt = palm_crown + Vector2(cos(base_angle) * leaf_len, sin(base_angle) * leaf_len * 0.75 + 28.0)
		var perp_dir = Vector2(-sin(base_angle), cos(base_angle))
		
		var leaf_poly_dark = PackedVector2Array([
			palm_crown,
			curve_pt + perp_dir * 22.0,
			end_pt,
			curve_pt - perp_dir * 10.0
		])
		draw_colored_polygon(leaf_poly_dark, leaf_dark)

		var leaf_poly_light = PackedVector2Array([
			palm_crown,
			curve_pt + perp_dir * 18.0,
			end_pt,
			curve_pt + perp_dir * 2.0
		])
		draw_colored_polygon(leaf_poly_light, leaf_bright)

		draw_line(palm_crown, curve_pt, leaf_mid, 3.5)
		draw_line(curve_pt, end_pt, leaf_bright, 2.0)
		
		for step in range(2, 7):
			var t = float(step) / 7.0
			var stem_pos = lerp(palm_crown, end_pt, t)
			var side_v = perp_dir * (24.0 * (1.0 - t * 0.4))
			draw_line(stem_pos, stem_pos + side_v + Vector2(0, 5.0), leaf_mid, 1.8)

	# C. 砂浜の白砂に散らばる小石、桜貝
	var beach_pebbles = [
		Vector2(780, 160), Vector2(830, 230), Vector2(890, 360),
		Vector2(790, 480), Vector2(910, 540), Vector2(940, 280)
	]
	for p in beach_pebbles:
		draw_ellipse(p + Vector2(2, 2), 6.0, 3.5, Color(0.55, 0.48, 0.38, 0.35))
		draw_ellipse(p, 5.0, 3.5, Color(0.92, 0.90, 0.86, 0.95))
		draw_ellipse(p + Vector2(-1, -1), 3.0, 2.0, Color(0.98, 0.98, 0.98, 0.95))

	var shells = [Vector2(790, 250), Vector2(850, 190), Vector2(920, 430), Vector2(880, 220)]
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

	# 蝶たち
	for b in butterflies:
		var b_pos = b["pos"]
		var flap = abs(sin(time_counter * 9.0))
		draw_ellipse(b_pos + Vector2(-3.0 * flap, -2), 4.5 * flap, 5.5, b["color"])
		draw_ellipse(b_pos + Vector2(3.0 * flap, -2), 4.5 * flap, 5.5, b["color"])
		draw_circle(b_pos, 1.2, Color(0.1, 0.1, 0.1, 0.85))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var sign_rect = Rect2(180, 210, 80, 45)
		var shack_rect = Rect2(15, 40, 130, 95)
		if sign_rect.has_point(event.position) or shack_rect.has_point(event.position):
			shop_interacted.emit()
