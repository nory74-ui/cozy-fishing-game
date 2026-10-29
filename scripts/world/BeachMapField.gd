extends Node2D

# うみかぜ日和 〜 日本全国お魚釣り旅：福岡・糸島編 〜
# 福岡・糸島「野北漁港 大波止 ＆ 野北サーフ・大口海岸」マップ
# 添付動画（ForkedPush）完全準拠の圧倒的美麗グラフィック：
# 1. 水底の豊かなディテール（色とりどりのサンゴ風海草、丸い浮草、ゆらめくホンダワラ藻場、玉石、水底の影）
# 2. 味わい深い木造ウッドデッキ＆釣り小屋（Beach Shack & Pier、柱の接触泡、樽、木箱、漁網、浮き輪）
# 3. 頑丈な野北波止（コンクリート天板、黄黒縁石、白灯台ポール、係留ビット、ベンチ）
# 4. 白砂サーフの立派なヤシの木（砂浜に落ちる繊細な葉の影）、滑らかな海岸の岩、桜貝、小石
# 5. カニの横歩き、舞うアゲハ蝶

signal shop_interacted()

var tex_crab: Texture2D
var time_counter: float = 0.0

# カニたちの動的データ
var crabs: Array[Dictionary] = []

# 蝶の動的データ
var butterflies: Array[Dictionary] = []

# 画面サイズ
const SCREEN_SIZE = Vector2(1152, 648)

# 歩行可能エリアの定義
# 1. 木造ウッドデッキ（小屋の前）
const DECK_WALK_RECT = Rect2(30, 110, 260, 110)
# 2. 大波止（防波堤の上）
const PIER_WALK_RECT = Rect2(200, 195, 340, 145)
# 3. ウッドデッキから波止への連絡デッキ
const CONNECT_WALK_RECT = Rect2(160, 180, 120, 80)
# 4. スロープ（堤防と砂浜の接続部）
const SLOPE_RECT = Rect2(530, 230, 175, 110)

func _ready() -> void:
	tex_crab = GameData.load_texture("res://assets/beach_crab.png")
	_init_crabs()
	_init_butterflies()

func _init_crabs() -> void:
	crabs.clear()
	crabs.append({
		"pos": Vector2(810, 210),
		"origin": Vector2(810, 210),
		"vel": Vector2(-12, 5),
		"walk_time": 0.0,
		"pause_time": 1.5,
		"scale": Vector2(0.85, 0.85)
	})
	crabs.append({
		"pos": Vector2(890, 470),
		"origin": Vector2(890, 470),
		"vel": Vector2(10, -6),
		"walk_time": 0.0,
		"pause_time": 2.2,
		"scale": Vector2(0.75, 0.75)
	})

func _init_butterflies() -> void:
	butterflies.clear()
	butterflies.append({
		"pos": Vector2(980, 190),
		"origin": Vector2(980, 190),
		"angle": 0.0,
		"radius": 45.0,
		"speed": 1.2,
		"color": Color(0.25, 0.68, 1.0, 0.95)
	})
	butterflies.append({
		"pos": Vector2(760, 310),
		"origin": Vector2(760, 310),
		"angle": 1.5,
		"radius": 32.0,
		"speed": 1.1,
		"color": Color(0.96, 0.86, 0.35, 0.9)
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
	var curve_uv = 0.63 + sin(uv_y * PI * 0.95 + 0.18) * 0.08 + (uv_y - 0.5) * 0.06
	return curve_uv * SCREEN_SIZE.x

# プレイヤーの歩行可能エリア判定
func is_point_walkable(pos: Vector2) -> bool:
	if pos.x < 25.0 or pos.x > SCREEN_SIZE.x - 25.0 or pos.y < 25.0 or pos.y > SCREEN_SIZE.y - 25.0:
		return false

	# 1. 木製ウッドデッキ
	if DECK_WALK_RECT.has_point(pos):
		# 小屋の本体（壁）への衝突
		if pos.x < 130 and pos.y < 165:
			return false
		return true

	# 2. デッキと波止の連絡路
	if CONNECT_WALK_RECT.has_point(pos):
		return true

	# 3. 大波止（防波堤の上）
	if PIER_WALK_RECT.has_point(pos):
		# 白灯台ポール、ベンチ
		if Rect2(505, 215, 25, 25).has_point(pos) or Rect2(360, 205, 50, 25).has_point(pos):
			return false
		return true

	# 4. スロープ
	if SLOPE_RECT.has_point(pos):
		return true

	# 5. 白砂サーフ（波打ち際より陸地側）
	var shore_x = get_shore_x(pos.y)
	if pos.x >= shore_x - 18.0:
		# 海岸の大岩への衝突
		if (pos - Vector2(790, 260)).length() < 24.0:
			return false
		# ヤシの木の幹への衝突
		if (pos - Vector2(1080, 440)).length() < 24.0:
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
	return PIER_WALK_RECT.has_point(pos) or DECK_WALK_RECT.has_point(pos)

func is_on_island(pos: Vector2) -> bool:
	return false

func _draw() -> void:
	# =========================================================================
	# レイヤー 1: 水底のディテール（透明な海の下に透けて見える生物・岩・海草）
	# =========================================================================
	_draw_seabed_details()

	# =========================================================================
	# レイヤー 2: 水中構造物の基礎（テトラポッド、水中の杭、ケーソン基礎）
	# =========================================================================
	_draw_submerged_structures()

	# =========================================================================
	# レイヤー 3: 陸地・水上構造物（ウッドデッキ小屋、大波止、スロープ）
	# =========================================================================
	_draw_wood_deck_and_shack()
	_draw_pier()
	_draw_slope()

	# =========================================================================
	# レイヤー 4: 砂浜の自然（ヤシの木、葉の影、海岸の岩、貝殻、生き物）
	# =========================================================================
	_draw_beach_nature()
	_draw_creatures()

# -----------------------------------------------------------------------------
# レイヤー 1: 水底のディテール
# -----------------------------------------------------------------------------
func _draw_seabed_details() -> void:
	# A. 水底の丸い玉石・岩（透き通る水底に見える滑らかな石）
	var seabed_rocks = [
		Vector2(280, 480), Vector2(340, 520), Vector2(430, 490),
		Vector2(210, 420), Vector2(370, 140), Vector2(440, 120),
		Vector2(620, 160), Vector2(650, 480), Vector2(580, 530)
	]
	for r in seabed_rocks:
		# 水底の影
		draw_ellipse(r + Vector2(3, 4), 14.0, 9.0, Color(0.10, 0.25, 0.28, 0.35))
		# 岩の本体（水色と馴染むベージュグレー）
		draw_ellipse(r, 12.0, 8.0, Color(0.68, 0.72, 0.65, 0.75))
		draw_ellipse(r + Vector2(-2, -2), 8.0, 5.0, Color(0.82, 0.86, 0.78, 0.80))

	# B. 動画完全再現：鮮やかなサンゴ風海草（紫・マゼンタ・ピンクの美しい海藻）
	var coral_positions = [
		Vector2(90, 490), Vector2(130, 530), Vector2(170, 470), Vector2(110, 440)
	]
	var coral_base = Color(0.55, 0.18, 0.45, 0.75)
	var coral_light = Color(0.85, 0.35, 0.65, 0.85)
	for cp in coral_positions:
		var sway = sin(time_counter * 1.5 + cp.x) * 4.0
		# 茎・基部
		draw_circle(cp + Vector2(2, 2), 6.0, Color(0.1, 0.2, 0.2, 0.3))
		# フリル状の花びら型サンゴ海草
		for j in range(5):
			var a = j * (TAU / 5.0) + time_counter * 0.2
			var petal_pos = cp + Vector2(cos(a) * 11.0 + sway * 0.5, sin(a) * 9.0)
			draw_circle(petal_pos, 7.0, coral_base)
			draw_circle(petal_pos + Vector2(-1, -1), 4.5, coral_light)
		draw_circle(cp + Vector2(sway * 0.3, 0), 6.0, Color(0.95, 0.60, 0.75, 0.90))

	# C. 動画完全再現：丸いスイレン風浮草・緑のリーフパッド
	var lily_positions = [
		Vector2(140, 430), Vector2(190, 460), Vector2(230, 420), Vector2(165, 480)
	]
	var lily_dark = Color(0.15, 0.45, 0.28, 0.80)
	var lily_light = Color(0.35, 0.78, 0.45, 0.90)
	for lp in lily_positions:
		var float_bob = sin(time_counter * 2.0 + lp.x * 0.2) * 2.5
		var center = lp + Vector2(0, float_bob)
		# 浮草の影
		draw_ellipse(center + Vector2(3, 5), 14.0, 10.0, Color(0.08, 0.22, 0.20, 0.30))
		# 葉の本体
		draw_ellipse(center, 13.0, 9.5, lily_dark)
		draw_ellipse(center + Vector2(-1, -1), 10.0, 7.5, lily_light)
		# 切れ込み
		draw_line(center, center + Vector2(10, 0), Color(0.20, 0.65, 0.60, 0.8), 2.0)

	# D. ゆらゆら揺れるホンダワラ藻場（玄界灘の豊かな海藻）
	var seaweed_color = Color(0.18, 0.42, 0.25, 0.70)
	var seaweed_tip = Color(0.32, 0.65, 0.38, 0.85)
	for i in range(14):
		var sx = 80.0 + i * 36.0
		var sy1 = 155.0 + sin(i * 1.5) * 16.0
		var sy2 = 415.0 + cos(i * 1.8) * 20.0
		var sway = sin(time_counter * 1.6 + i * 0.7) * 7.0
		# 北側の海藻
		draw_line(Vector2(sx, sy1 + 18), Vector2(sx + sway, sy1), seaweed_color, 4.5)
		draw_circle(Vector2(sx + sway, sy1), 5.5, seaweed_tip)
		# 南側の海藻
		draw_line(Vector2(sx + 15, sy2 - 18), Vector2(sx + 15 + sway, sy2), seaweed_color, 4.5)
		draw_circle(Vector2(sx + 15 + sway, sy2), 6.0, seaweed_tip)

# -----------------------------------------------------------------------------
# レイヤー 2: 水中構造物の基礎・テトラポッド
# -----------------------------------------------------------------------------
func _draw_submerged_structures() -> void:
	# A. 堤防の海中基礎（ケーソン捨石基礎）
	var base_poly = PackedVector2Array([
		Vector2(180, 175),
		Vector2(555, 175),
		Vector2(575, 205),
		Vector2(575, 365),
		Vector2(555, 385),
		Vector2(180, 385)
	])
	draw_colored_polygon(base_poly, Color(0.15, 0.30, 0.32, 0.60))

	# B. 消波テトラポッド帯（大波止の南側）
	var tetra_base_color = Color(0.46, 0.52, 0.56, 0.95)
	var tetra_light_color = Color(0.68, 0.74, 0.78, 0.95)
	var tetra_shadow_color = Color(0.30, 0.34, 0.38, 0.95)
	
	for i in range(11):
		var tx = 180.0 + i * 36.0
		var ty = 368.0 + (i % 2) * 16.0
		# 水中の影
		draw_circle(Vector2(tx + 4, ty + 8), 16.0, Color(0.08, 0.20, 0.24, 0.40))
		# 3つの足
		draw_circle(Vector2(tx - 10, ty + 6), 11.0, tetra_shadow_color)
		draw_circle(Vector2(tx + 10, ty + 6), 11.0, tetra_base_color)
		draw_circle(Vector2(tx, ty - 8), 12.0, tetra_light_color)
		# 中央ノード
		draw_circle(Vector2(tx, ty), 10.0, tetra_light_color)
		
		# 水面接触泡（テトラポッドの足元にできる白い泡）
		var foam_phase = sin(time_counter * 2.5 + i) * 1.5
		draw_arc(Vector2(tx, ty - 2), 14.0 + foam_phase, 0.0, TAU, 12, Color(1.0, 1.0, 1.0, 0.45), 2.0)

# -----------------------------------------------------------------------------
# レイヤー 3: 陸地・水上構造物（木造デッキ小屋、大波止、スロープ）
# -----------------------------------------------------------------------------
func _draw_wood_deck_and_shack() -> void:
	# A. 水中に刺さる木製の柱（Pillars / Piles）
	var pillar_x = [45, 115, 185, 255]
	var pillar_y = [215, 230]
	for px in pillar_x:
		for py in pillar_y:
			# 柱の水中影
			draw_line(Vector2(px, py), Vector2(px + 4, py + 16), Color(0.1, 0.2, 0.2, 0.45), 8.0)
			# 柱本体
			draw_line(Vector2(px, py - 15), Vector2(px, py + 8), Color(0.38, 0.25, 0.16, 1.0), 7.0)
			draw_line(Vector2(px - 1, py - 15), Vector2(px - 1, py + 8), Color(0.52, 0.36, 0.24, 1.0), 3.0)
			# 水面接触白泡（Contact Foam）
			var p_foam = abs(sin(time_counter * 2.0 + px)) * 2.0
			draw_circle(Vector2(px, py + 4), 6.5 + p_foam, Color(1.0, 1.0, 1.0, 0.60))

	# B. ウッドデッキ桟橋の床面（板張りテクスチャ）
	var deck_rect = Rect2(20, 95, 260, 130)
	# デッキ全体の影
	draw_rect(Rect2(25, 102, 260, 130), Color(0.12, 0.22, 0.24, 0.40))
	# デッキ土台
	draw_rect(deck_rect, Color(0.58, 0.40, 0.26, 1.0))
	draw_rect(Rect2(22, 97, 256, 124), Color(0.76, 0.58, 0.38, 1.0))
	
	# 横方向の板張りライン（Planks）
	for y in range(105, 225, 12):
		draw_line(Vector2(22, y), Vector2(278, y), Color(0.50, 0.34, 0.20, 0.9), 1.5)
		# 釘の頭（Nails）
		for x in range(35, 275, 45):
			draw_circle(Vector2(x, y - 6), 1.2, Color(0.35, 0.22, 0.12, 0.9))

	# デッキ周囲のロープ手すり（手前と右側は開口）
	draw_rect(Rect2(18, 93, 264, 4), Color(0.48, 0.32, 0.18, 1.0))

	# C. 釣り小屋（Beach Shack 本体：左上）
	var shack_rect = Rect2(20, 40, 130, 90)
	# 小屋の影
	draw_rect(Rect2(28, 48, 130, 90), Color(0.15, 0.15, 0.15, 0.35))
	# 壁
	draw_rect(shack_rect, Color(0.70, 0.50, 0.34, 1.0))
	draw_rect(Rect2(24, 44, 122, 82), Color(0.82, 0.64, 0.46, 1.0))
	# 壁の板目
	for x in range(35, 145, 14):
		draw_line(Vector2(x, 44), Vector2(x, 126), Color(0.62, 0.44, 0.28, 0.7), 1.2)
	
	# 青い木製ドア
	var door_rect = Rect2(65, 78, 30, 48)
	draw_rect(door_rect, Color(0.24, 0.48, 0.65, 1.0))
	draw_rect(Rect2(67, 80, 26, 44), Color(0.34, 0.60, 0.78, 1.0))
	draw_circle(Vector2(70, 102), 2.2, Color(0.95, 0.85, 0.40, 1.0)) # 金色ドアノブ

	# 屋根（庇）
	var roof_poly = PackedVector2Array([
		Vector2(12, 45), Vector2(158, 45), Vector2(148, 30), Vector2(22, 30)
	])
	draw_colored_polygon(roof_poly, Color(0.52, 0.30, 0.18, 1.0))
	
	# 壁に掛かった赤白の救命浮輪
	var r_center = Vector2(122, 75)
	draw_circle(r_center, 9.0, Color(0.92, 0.30, 0.18, 1.0))
	draw_circle(r_center, 4.5, Color(0.82, 0.64, 0.46, 1.0))
	draw_circle(r_center + Vector2(-4, 0), 2.5, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(r_center + Vector2(4, 0), 2.5, Color(1.0, 1.0, 1.0, 0.95))

	# D. デッキ上の小物（木箱、樽、漁網、ロープ）
	# 木製樽（Barrel）
	var barrel_pos = Vector2(165, 120)
	draw_ellipse(barrel_pos + Vector2(2, 3), 10.0, 8.0, Color(0.15, 0.15, 0.15, 0.30))
	draw_ellipse(barrel_pos, 9.0, 7.5, Color(0.55, 0.36, 0.22, 1.0))
	draw_ellipse(barrel_pos, 7.5, 6.0, Color(0.68, 0.48, 0.32, 1.0))
	draw_arc(barrel_pos, 8.0, 0, TAU, 12, Color(0.32, 0.32, 0.35, 1.0), 2.0) # 金属バンド

	# 積まれた木箱（Crates）
	var crate_pos1 = Vector2(185, 130)
	var crate_pos2 = Vector2(195, 118)
	draw_rect(Rect2(crate_pos1 + Vector2(2, 3), Vector2(22, 20)), Color(0.15, 0.15, 0.15, 0.25))
	draw_rect(Rect2(crate_pos1, Vector2(22, 20)), Color(0.72, 0.54, 0.36, 1.0))
	draw_line(crate_pos1, crate_pos1 + Vector2(22, 20), Color(0.52, 0.36, 0.22, 0.8), 1.5)
	
	draw_rect(Rect2(crate_pos2, Vector2(18, 16)), Color(0.80, 0.62, 0.42, 1.0))
	draw_line(crate_pos2, crate_pos2 + Vector2(18, 16), Color(0.58, 0.42, 0.26, 0.8), 1.5)

	# 巻き網・ロープ（Fishing Net & Rope）
	var net_pos = Vector2(230, 125)
	draw_circle(net_pos + Vector2(2, 3), 12.0, Color(0.15, 0.15, 0.15, 0.20))
	draw_circle(net_pos, 11.0, Color(0.48, 0.52, 0.44, 0.85))
	for r in range(3):
		draw_arc(net_pos, 4.0 + r * 3.0, 0, TAU, 10, Color(0.75, 0.65, 0.45, 0.9), 1.5)

func _draw_pier() -> void:
	# 大波止本体（コンクリート防波堤）
	# 側壁の立体感
	draw_rect(Rect2(200, 192, 340, 10), Color(0.62, 0.65, 0.68, 1.0))
	draw_rect(Rect2(200, 340, 340, 14), Color(0.40, 0.43, 0.46, 1.0))
	draw_rect(Rect2(536, 192, 10, 162), Color(0.48, 0.51, 0.54, 1.0))

	# 天板（白いコンクリート床）
	draw_rect(Rect2(200, 202, 336, 138), Color(0.89, 0.90, 0.91, 1.0))
	
	# 目地スリットライン
	for i in range(1, 4):
		var sx = 200.0 + i * 85.0
		draw_line(Vector2(sx, 202), Vector2(sx, 340), Color(0.74, 0.76, 0.78, 0.9), 1.5)

	# 縁石・黄黒の警戒安全ライン
	var curb_y = Color(0.95, 0.78, 0.15, 1.0)
	var curb_b = Color(0.22, 0.24, 0.26, 1.0)
	
	# 上側縁石
	draw_rect(Rect2(200, 202, 336, 6), curb_y)
	for i in range(12):
		if i % 2 == 1:
			draw_rect(Rect2(200 + i * 28.0, 202, 14.0, 6), curb_b)

	# 下側縁石
	draw_rect(Rect2(200, 334, 336, 6), curb_y)
	for i in range(12):
		if i % 2 == 1:
			draw_rect(Rect2(200 + i * 28.0, 334, 14.0, 6), curb_b)

	# 先端縁石
	draw_rect(Rect2(530, 202, 6, 138), curb_y)
	for i in range(5):
		if i % 2 == 1:
			draw_rect(Rect2(530, 202 + i * 28.0, 6, 14.0), curb_b)

	# 係留用ボラード（ビット）
	var bollard_positions = [Vector2(260, 214), Vector2(380, 214), Vector2(480, 214)]
	for bp in bollard_positions:
		draw_ellipse(bp + Vector2(2, 4), 7.0, 3.5, Color(0.2, 0.2, 0.2, 0.35))
		draw_circle(bp, 5.5, Color(0.28, 0.30, 0.32, 1.0))
		draw_circle(bp + Vector2(-1, -1), 3.5, Color(0.48, 0.50, 0.52, 1.0))

	# 木製釣りベンチ
	var b_pos = Vector2(360, 214)
	draw_rect(Rect2(b_pos + Vector2(3, 4), Vector2(46, 18)), Color(0.2, 0.2, 0.2, 0.25))
	draw_rect(Rect2(b_pos, Vector2(46, 18)), Color(0.68, 0.48, 0.30, 1.0))
	draw_rect(Rect2(b_pos + Vector2(2, 2), Vector2(42, 14)), Color(0.78, 0.58, 0.38, 1.0))
	draw_line(Vector2(b_pos.x, b_pos.y + 9), Vector2(b_pos.x + 46, b_pos.y + 9), Color(0.58, 0.38, 0.22, 1.0), 1.0)

	# 白灯台ポール（野北のシンボル常夜灯）
	var pole_pos = Vector2(512, 230)
	draw_ellipse(pole_pos + Vector2(6, 10), 18.0, 6.0, Color(0.2, 0.2, 0.2, 0.35))
	draw_circle(pole_pos, 14.0, Color(0.75, 0.78, 0.82, 1.0))
	draw_circle(pole_pos, 10.0, Color(0.92, 0.94, 0.96, 1.0))
	draw_rect(Rect2(pole_pos.x - 4, pole_pos.y - 48, 8, 48), Color(0.95, 0.96, 0.98, 1.0))
	draw_rect(Rect2(pole_pos.x - 2, pole_pos.y - 46, 3, 46), Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(Vector2(pole_pos.x, pole_pos.y - 52), 7.0, Color(0.98, 0.92, 0.55, 0.95))
	draw_circle(Vector2(pole_pos.x, pole_pos.y - 52), 4.0, Color(1.0, 0.99, 0.85, 1.0))
	draw_line(Vector2(pole_pos.x - 8, pole_pos.y - 56), Vector2(pole_pos.x + 8, pole_pos.y - 56), Color(0.25, 0.45, 0.75, 1.0), 3.0)

	# 救命浮環
	var ring_pos = Vector2(450, 325)
	draw_circle(ring_pos, 9.0, Color(0.95, 0.40, 0.15, 1.0))
	draw_circle(ring_pos, 5.0, Color(0.89, 0.90, 0.91, 1.0))
	draw_circle(ring_pos + Vector2(-4, 0), 2.5, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(ring_pos + Vector2(4, 0), 2.5, Color(1.0, 1.0, 1.0, 0.95))

	# 「野北波止 釣具店」案内看板
	var sign_pos = Vector2(215, 222)
	draw_rect(Rect2(sign_pos + Vector2(2, 3), Vector2(68, 36)), Color(0.2, 0.2, 0.2, 0.25))
	draw_rect(Rect2(sign_pos, Vector2(68, 36)), Color(0.25, 0.42, 0.55, 0.95))
	draw_rect(Rect2(sign_pos + Vector2(2, 2), Vector2(64, 32)), Color(0.96, 0.97, 0.98, 1.0))
	draw_string(ThemeDB.fallback_font, sign_pos + Vector2(8, 16), "野北波止", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.25, 0.35, 1.0))
	draw_string(ThemeDB.fallback_font, sign_pos + Vector2(8, 28), "釣具・店", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.40, 0.20, 1.0))

func _draw_slope() -> void:
	# 大波止から野北サーフへのスロープ
	var slope_poly = PackedVector2Array([
		Vector2(536, 235),
		Vector2(690, 255),
		Vector2(690, 325),
		Vector2(536, 345)
	])
	var shadow_poly = PackedVector2Array([
		Vector2(536, 345),
		Vector2(690, 325),
		Vector2(696, 335),
		Vector2(536, 352)
	])
	draw_colored_polygon(shadow_poly, Color(0.2, 0.2, 0.2, 0.25))
	draw_colored_polygon(slope_poly, Color(0.78, 0.62, 0.44, 1.0))
	
	for i in range(7):
		var t = float(i) / 6.0
		var p1 = lerp(Vector2(536, 235), Vector2(690, 255), t)
		var p2 = lerp(Vector2(536, 345), Vector2(690, 325), t)
		draw_line(p1, p2, Color(0.58, 0.42, 0.26, 0.85), 1.5)

# -----------------------------------------------------------------------------
# レイヤー 4: 砂浜の自然（ヤシの木、影、海岸の岩、貝殻）
# -----------------------------------------------------------------------------
func _draw_beach_nature() -> void:
	# A. 動画完全再現：砂浜の大きな丸い海岸岩（Beach Boulder: プレイヤーの右側）
	var b_pos = Vector2(790, 260)
	# 砂浜に落ちる岩の影
	draw_ellipse(b_pos + Vector2(8, 12), 26.0, 15.0, Color(0.18, 0.20, 0.16, 0.35))
	# 岩本体（滑らかなグラデーション）
	draw_ellipse(b_pos, 24.0, 18.0, Color(0.55, 0.58, 0.60, 1.0))
	draw_ellipse(b_pos + Vector2(-3, -3), 19.0, 14.0, Color(0.72, 0.75, 0.77, 1.0))
	draw_ellipse(b_pos + Vector2(-7, -6), 11.0, 8.0, Color(0.86, 0.88, 0.90, 1.0))

	# B. 動画完全再現：砂浜の立派なヤシの木 ＆ 砂浜に落ちる美しい葉の影（Cast Palm Shadow）
	var palm_base = Vector2(1090, 450) # 砂浜の右下から生える幹
	var palm_crown = Vector2(1020, 250) # 葉が広がる樹冠の中心
	
	# 1. 砂浜に落ちるヤシの木の葉の影（動画のように左側へ斜めに柔らかく広がるソフトシャドウ）
	var shadow_origin = palm_base + Vector2(-130, -30)
	draw_line(palm_base, shadow_origin, Color(0.18, 0.20, 0.16, 0.24), 16.0)
	
	for i in range(7):
		var a = i * (PI / 3.8) - 2.3
		var s_len = 95.0 + (i % 3) * 15.0
		var s_mid = shadow_origin + Vector2(cos(a) * (s_len * 0.5), sin(a) * (s_len * 0.35))
		var s_tip = shadow_origin + Vector2(cos(a) * s_len, sin(a) * (s_len * 0.65))
		var s_perp = Vector2(-sin(a), cos(a)) * 18.0
		
		# 葉のソフトシャドウポリゴン
		var s_poly = PackedVector2Array([
			shadow_origin,
			s_mid + s_perp,
			s_tip,
			s_mid - s_perp
		])
		draw_colored_polygon(s_poly, Color(0.14, 0.17, 0.13, 0.18))

	# 2. ヤシの木の幹（滑らかにカーブする立体的な幹）
	var trunk_pts = [
		palm_base, Vector2(1075, 390), Vector2(1050, 320), palm_crown
	]
	for k in range(trunk_pts.size() - 1):
		var p1 = trunk_pts[k]
		var p2 = trunk_pts[k + 1]
		draw_line(p1, p2, Color(0.42, 0.28, 0.18, 1.0), 22.0 - k * 3.0)
		draw_line(p1 - Vector2(2, 0), p2 - Vector2(2, 0), Color(0.65, 0.48, 0.32, 1.0), 10.0)
		# 幹の節（リング）
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
		
		# 葉のベースポリゴン（深い緑）
		var leaf_poly_dark = PackedVector2Array([
			palm_crown,
			curve_pt + perp_dir * 22.0,
			end_pt,
			curve_pt - perp_dir * 10.0
		])
		draw_colored_polygon(leaf_poly_dark, leaf_dark)

		# 葉のハイライト側ポリゴン（明るい緑）
		var leaf_poly_light = PackedVector2Array([
			palm_crown,
			curve_pt + perp_dir * 18.0,
			end_pt,
			curve_pt + perp_dir * 2.0
		])
		draw_colored_polygon(leaf_poly_light, leaf_bright)

		# 中央の主脈
		draw_line(palm_crown, curve_pt, leaf_mid, 3.5)
		draw_line(curve_pt, end_pt, leaf_bright, 2.0)
		
		# 羽状の細い切れ込みライン（ディテール）
		for step in range(2, 7):
			var t = float(step) / 7.0
			var stem_pos = lerp(palm_crown, end_pt, t)
			var side_v = perp_dir * (24.0 * (1.0 - t * 0.4))
			draw_line(stem_pos, stem_pos + side_v + Vector2(0, 5.0), leaf_mid, 1.8)

	# C. 砂浜の白砂に散らばる小石、桜貝
	var beach_pebbles = [
		Vector2(750, 140), Vector2(820, 190), Vector2(860, 360),
		Vector2(790, 440), Vector2(880, 560), Vector2(930, 290)
	]
	for p in beach_pebbles:
		draw_ellipse(p + Vector2(2, 2), 6.0, 3.5, Color(0.55, 0.48, 0.38, 0.35))
		draw_ellipse(p, 5.0, 3.5, Color(0.92, 0.90, 0.86, 0.95))
		draw_ellipse(p + Vector2(-1, -1), 3.0, 2.0, Color(0.98, 0.98, 0.98, 0.95))

	var shells = [Vector2(770, 270), Vector2(840, 180), Vector2(920, 460), Vector2(880, 220)]
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
		var sign_rect = Rect2(210, 215, 80, 50)
		var shack_rect = Rect2(20, 40, 130, 100)
		if sign_rect.has_point(event.position) or shack_rect.has_point(event.position):
			shop_interacted.emit()
