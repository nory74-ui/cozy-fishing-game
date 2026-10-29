@tool
extends SceneTree

# 全10魚種 最高品質リアルデジタルイラスト生成スクリプト Ver 3.0
# （真鯛（fish_side_madai.png）の圧倒的クオリティに完全一致する生物図鑑ペインティング）
# 1100 x 600 の超高解像度キャンバスに、解剖学的骨格・立体鱗・半透明鰭条・リアル瞳を多層レンダリング

func _init() -> void:
	print("=== Generating Master Fish Illustrations (1100x600 Ultra-Realistic) ===")
	var assets_dir = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/"

	var fishes = [
		{"id": "aji", "render": "_draw_aji"},
		{"id": "kisu", "render": "_draw_kisu"},
		{"id": "arakabu", "render": "_draw_arakabu"},
		{"id": "chinu", "render": "_draw_chinu"},
		{"id": "magochi", "render": "_draw_magochi"},
		{"id": "suzuki", "render": "_draw_suzuki"},
		{"id": "kijihata", "render": "_draw_kijihata"},
		{"id": "hirame", "render": "_draw_hirame"},
		{"id": "aoriika", "render": "_draw_aoriika"}
	]

	for f in fishes:
		var img = Image.create(1100, 600, false, Image.FORMAT_RGBA8)
		call(f["render"], img)
		
		# 図鑑・釣果鑑賞用（日本の伝統図鑑スタイル：頭が左向き）
		var side_path = assets_dir + "fish_side_" + f["id"] + ".png"
		img.save_png(side_path)
		
		# 海中遊泳・魚影用（頭が右向き：Godotの+X進行方向と完全一致、背中が上を維持）
		var top_img = Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		top_img.copy_from(img)
		top_img.flip_x()
		var top_path = assets_dir + "fish_" + f["id"] + ".png"
		top_img.save_png(top_path)
		
		print("Generated Ultra-HD fish: ", f["id"])

	print("=== All Fish Illustrations Generated Successfully! ===")
	quit()

# -----------------------------------------------------------------------------
# 描画基本ユーティリティ
# -----------------------------------------------------------------------------
func mix_color(c1: Color, c2: Color, t: float) -> Color:
	return Color(
		lerpf(c1.r, c2.r, t),
		lerpf(c1.g, c2.g, t),
		lerpf(c1.b, c2.b, t),
		lerpf(c1.a, c2.a, t)
	)

func _draw_circle_aa(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var x0 = clampi(int(center.x - radius - 1), 0, img.get_width() - 1)
	var x1 = clampi(int(center.x + radius + 1), 0, img.get_width() - 1)
	var y0 = clampi(int(center.y - radius - 1), 0, img.get_height() - 1)
	var y1 = clampi(int(center.y + radius + 1), 0, img.get_height() - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dist = center.distance_to(Vector2(x, y))
			if dist <= radius:
				var alpha = clampf(radius - dist + 0.5, 0.0, 1.0) * color.a
				var cur = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.blend(Color(color.r, color.g, color.b, alpha)))

func _draw_line_aa(img: Image, p1: Vector2, p2: Vector2, color: Color, width: float = 1.0) -> void:
	var len = p1.distance_to(p2)
	var steps = maxi(1, int(len * 2.0))
	var r = width * 0.5
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var p = lerp(p1, p2, t)
		_draw_circle_aa(img, p, r, color)

func _draw_poly_aa(img: Image, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3: return
	var min_x = 1100.0; var max_x = 0.0
	var min_y = 600.0; var max_y = 0.0
	for p in pts:
		min_x = minf(min_x, p.x); max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y); max_y = maxf(max_y, p.y)
	var x0 = clampi(int(min_x) - 1, 0, img.get_width() - 1)
	var x1 = clampi(int(max_x) + 1, 0, img.get_width() - 1)
	var y0 = clampi(int(min_y) - 1, 0, img.get_height() - 1)
	var y1 = clampi(int(max_y) + 1, 0, img.get_height() - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), pts):
				var cur = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.blend(col))

# -----------------------------------------------------------------------------
# 高度リアルレンダラー部品
# -----------------------------------------------------------------------------
# 1. リアル立体ウロコ模様（重なり合う魚類特有のウロコパターン＋陰影と光沢）
func _draw_realistic_scales(img: Image, body_poly: PackedVector2Array, start_x: float, end_x: float, y_center: float, scale_size: float, base_col: Color, rim_col: Color) -> void:
	var rows = int(240.0 / scale_size)
	var cols = int((end_x - start_x) / (scale_size * 0.85))
	for c in range(cols):
		var x = start_x + c * (scale_size * 0.85)
		var col_offset = (c % 2) * (scale_size * 0.5)
		for r in range(-rows, rows + 1):
			var y = y_center + r * scale_size + col_offset
			var pos = Vector2(x, y)
			if Geometry2D.is_point_in_polygon(pos, body_poly):
				# ウロコの半円弧シャドウ＆ハイライト
				var rad = scale_size * 0.75
				# 後方シャドウ
				_draw_circle_aa(img, pos + Vector2(1.2, 0.8), rad, Color(0.1, 0.15, 0.18, 0.12))
				# ウロコ本体
				_draw_circle_aa(img, pos, rad, base_col)
				# エッジハイライト（光のきらめき）
				_draw_line_aa(img, pos + Vector2(-rad * 0.5, -rad * 0.4), pos + Vector2(rad * 0.2, 0), rim_col, 1.2)

# 2. リアル生物眼球（多層構造：角膜、ゴールド/ブロンズ虹彩、深黒瞳孔、三重点スペキュラ光）
func _draw_realistic_eye(img: Image, center: Vector2, radius: float, iris_col: Color, pupil_ratio: float = 0.55) -> void:
	# 外側強膜シャドウ
	_draw_circle_aa(img, center + Vector2(1, 2), radius + 2.5, Color(0.08, 0.12, 0.15, 0.6))
	_draw_circle_aa(img, center, radius + 1.0, Color(0.85, 0.88, 0.85, 0.95))
	
	# 虹彩（ゴールド/アンバー/ブロンズ）
	_draw_circle_aa(img, center, radius, iris_col)
	# 虹彩の輝きリング
	_draw_circle_aa(img, center + Vector2(-1, -1), radius * 0.85, mix_color(iris_col, Color.WHITE, 0.35))
	
	# 漆黒の瞳孔（中心）
	var pr = radius * pupil_ratio
	_draw_circle_aa(img, center + Vector2(0.5, 0), pr, Color(0.04, 0.06, 0.08, 1.0))
	
	# 水晶体スペキュラハイライト（生き生きとした光の反射）
	_draw_circle_aa(img, center + Vector2(-radius * 0.38, -radius * 0.38), radius * 0.28, Color(1.0, 1.0, 1.0, 0.98))
	_draw_circle_aa(img, center + Vector2(radius * 0.28, radius * 0.25), radius * 0.12, Color(1.0, 1.0, 1.0, 0.75))

# 3. 半透明リアルヒレ（先端グラデーション、多条骨線、分枝軟条）
func _draw_realistic_fin(img: Image, fin_pts: PackedVector2Array, root_p: Vector2, edge_pts: Array[Vector2], base_col: Color, edge_col: Color, ray_count: int, is_spiny: bool = false) -> void:
	# ヒレの半透明皮膜
	_draw_poly_aa(img, fin_pts, base_col)
	
	# ヒレの骨条（Fin Rays）
	var steps = maxi(2, ray_count)
	for i in range(steps):
		var t = float(i) / float(steps - 1)
		var p_edge = lerp(edge_pts[0], edge_pts[edge_pts.size() - 1], t)
		if edge_pts.size() > 2:
			# スプライン的な補間
			var idx = int(t * float(edge_pts.size() - 1))
			p_edge = edge_pts[clampi(idx, 0, edge_pts.size() - 1)]
			
		var ray_w = 2.2 if is_spiny else 1.3
		var ray_c = mix_color(base_col, Color(0.15, 0.18, 0.22, 0.85), 0.45) if is_spiny else mix_color(base_col, edge_col, 0.5)
		_draw_line_aa(img, root_p, p_edge, ray_c, ray_w)
		
		# 軟条の二又分枝
		if not is_spiny and t > 0.1 and t < 0.9:
			var branch_p = lerp(root_p, p_edge, 0.65)
			_draw_line_aa(img, branch_p, p_edge + Vector2(-3, -2), ray_c, 0.9)
			_draw_line_aa(img, branch_p, p_edge + Vector2(3, 2), ray_c, 0.9)

# -----------------------------------------------------------------------------
# 1. マアジ (Japanese Jack Mackerel / Trachurus japonicus)
# -----------------------------------------------------------------------------
func _draw_aji(img: Image) -> void:
	# 尾びれ（鮮やかな二又フォーク状・黄色）
	var tail_pts = PackedVector2Array([
		Vector2(880, 290), Vector2(1040, 160), Vector2(980, 290), Vector2(1040, 420), Vector2(880, 310)
	])
	_draw_realistic_fin(img, tail_pts, Vector2(880, 300), [Vector2(1040, 160), Vector2(980, 290), Vector2(1040, 420)], Color(0.92, 0.82, 0.22, 0.85), Color(0.98, 0.92, 0.45, 0.95), 18)

	# 背びれ（第1背びれ: シャープな三角形、第2背びれ: 長い軟条びれ）
	var dorsal1 = PackedVector2Array([Vector2(420, 220), Vector2(500, 110), Vector2(580, 220)])
	_draw_realistic_fin(img, dorsal1, Vector2(490, 220), [Vector2(500, 110)], Color(0.35, 0.45, 0.52, 0.85), Color(0.65, 0.72, 0.78, 0.9), 8, true)
	
	var dorsal2 = PackedVector2Array([Vector2(600, 220), Vector2(680, 160), Vector2(850, 260)])
	_draw_realistic_fin(img, dorsal2, Vector2(700, 230), [Vector2(680, 160), Vector2(850, 260)], Color(0.85, 0.80, 0.35, 0.80), Color(0.95, 0.92, 0.55, 0.9), 16)

	# 尻びれ（腹側後方）
	var anal_fin = PackedVector2Array([Vector2(620, 370), Vector2(700, 420), Vector2(840, 340)])
	_draw_realistic_fin(img, anal_fin, Vector2(700, 360), [Vector2(700, 420), Vector2(840, 340)], Color(0.90, 0.90, 0.85, 0.80), Color(0.98, 0.98, 0.90, 0.9), 14)

	# 体幹（流線型ポリゴン）
	var body_pts = PackedVector2Array([
		Vector2(140, 300), Vector2(220, 250), Vector2(360, 215), Vector2(520, 210),
		Vector2(700, 235), Vector2(840, 280), Vector2(890, 300),
		Vector2(840, 320), Vector2(700, 365), Vector2(520, 385), Vector2(360, 380),
		Vector2(220, 345)
	])
	_draw_poly_aa(img, body_pts, Color(0.94, 0.96, 0.98, 1.0))

	# 体幹の立体グラデーション（背中: 濃青緑メタリック、側面: 青銀、腹部: 純白シルバー）
	for y in range(200, 395):
		for x in range(130, 900):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 210) / 175.0
				var col = Color.TRANSPARENT
				if norm_y < 0.40:
					var bt = norm_y / 0.40
					col = mix_color(Color(0.14, 0.32, 0.44, 0.95), Color(0.38, 0.62, 0.66, 0.65), bt)
				elif norm_y < 0.65:
					var mt = (norm_y - 0.40) / 0.25
					col = mix_color(Color(0.38, 0.62, 0.66, 0.65), Color(0.88, 0.92, 0.95, 0.3), mt)
				else:
					var wt = (norm_y - 0.65) / 0.35
					col = mix_color(Color(0.88, 0.92, 0.95, 0.3), Color(1.0, 1.0, 1.0, 0.85), wt)
				var cur = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.blend(col))

	# 立体ウロコテクスチャ
	_draw_realistic_scales(img, body_pts, 320, 850, 300, 11.0, Color(0.82, 0.88, 0.92, 0.22), Color(1.0, 1.0, 1.0, 0.45))

	# アジ特有の側線＆ゼゴ（稜鱗: 黄金色〜シルバーの鋭利な突起ライン）
	for i in range(55):
		var t = float(i) / 54.0
		var zx = lerpf(340, 890, t)
		var zy = 295.0 + sin(t * PI * 0.92) * 16.0
		if t > 0.38:
			# 鋭いゼゴの山形プレート
			var z_col = Color(0.95, 0.84, 0.25, 0.95)
			_draw_line_aa(img, Vector2(zx, zy - 6), Vector2(zx + 8, zy + 6), z_col, 2.6)
			_draw_line_aa(img, Vector2(zx + 2, zy - 4), Vector2(zx + 9, zy + 5), Color(1.0, 0.98, 0.70, 0.9), 1.2)
			_draw_circle_aa(img, Vector2(zx + 4, zy), 2.2, Color(0.50, 0.42, 0.15, 0.9))
		else:
			_draw_circle_aa(img, Vector2(zx, zy), 2.0, Color(0.35, 0.55, 0.65, 0.75))

	# 胸びれ（黄色みを帯びたシャープな翼）
	var pect_pts = PackedVector2Array([
		Vector2(350, 305), Vector2(460, 280), Vector2(490, 315), Vector2(360, 325)
	])
	_draw_realistic_fin(img, pect_pts, Vector2(355, 315), [Vector2(460, 280), Vector2(490, 315)], Color(0.92, 0.86, 0.30, 0.85), Color(0.98, 0.95, 0.65, 0.95), 8)

	# エラブタ・主鰓蓋骨＆漆黒斑点
	_draw_line_aa(img, Vector2(320, 245), Vector2(345, 345), Color(0.30, 0.42, 0.50, 0.85), 2.8)
	_draw_line_aa(img, Vector2(322, 246), Vector2(347, 346), Color(1.0, 1.0, 1.0, 0.55), 1.2) # ハイライト
	_draw_circle_aa(img, Vector2(340, 255), 7.5, Color(0.10, 0.12, 0.15, 0.95)) # エラ上部の黒斑

	# リアル眼球
	_draw_realistic_eye(img, Vector2(235, 290), 16.0, Color(0.92, 0.82, 0.28, 1.0), 0.52)

# -----------------------------------------------------------------------------
# 2. シロギス (Japanese Whiting / Sillago japonica)
# -----------------------------------------------------------------------------
func _draw_kisu(img: Image) -> void:
	# 尾びれ（淡い飴色〜透明）
	var tail_pts = PackedVector2Array([
		Vector2(880, 295), Vector2(1030, 210), Vector2(980, 300), Vector2(1030, 390), Vector2(880, 305)
	])
	_draw_realistic_fin(img, tail_pts, Vector2(880, 300), [Vector2(1030, 210), Vector2(980, 300), Vector2(1030, 390)], Color(0.92, 0.88, 0.75, 0.75), Color(0.98, 0.95, 0.85, 0.9), 16)

	# 長い二層背びれ
	var dorsal = PackedVector2Array([Vector2(430, 245), Vector2(510, 160), Vector2(840, 275)])
	_draw_realistic_fin(img, dorsal, Vector2(520, 250), [Vector2(510, 160), Vector2(840, 275)], Color(0.90, 0.86, 0.70, 0.75), Color(0.98, 0.95, 0.85, 0.9), 20)

	# 尻びれ
	var anal_fin = PackedVector2Array([Vector2(550, 345), Vector2(630, 375), Vector2(840, 325)])
	_draw_realistic_fin(img, anal_fin, Vector2(600, 345), [Vector2(630, 375), Vector2(840, 325)], Color(0.92, 0.90, 0.82, 0.75), Color(0.98, 0.98, 0.95, 0.9), 16)

	# 細長い流線型体幹
	var body_pts = PackedVector2Array([
		Vector2(130, 305), Vector2(200, 280), Vector2(340, 255), Vector2(550, 245),
		Vector2(750, 265), Vector2(870, 295), Vector2(890, 300),
		Vector2(870, 305), Vector2(750, 335), Vector2(550, 355), Vector2(340, 345),
		Vector2(200, 325)
	])
	_draw_poly_aa(img, body_pts, Color(0.98, 0.96, 0.94, 1.0))

	# パールピンク〜真珠グラデーション
	for y in range(240, 365):
		for x in range(125, 900):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 245) / 110.0
				var col = Color.TRANSPARENT
				if norm_y < 0.45:
					col = mix_color(Color(0.85, 0.72, 0.58, 0.85), Color(0.95, 0.80, 0.75, 0.5), norm_y / 0.45)
				else:
					col = mix_color(Color(0.95, 0.80, 0.75, 0.5), Color(1.0, 1.0, 1.0, 0.92), (norm_y - 0.45) / 0.55)
				var cur = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.blend(col))

	# 細かな真珠ウロコ
	_draw_realistic_scales(img, body_pts, 300, 860, 300, 7.5, Color(0.92, 0.85, 0.78, 0.25), Color(1.0, 0.98, 0.95, 0.5))

	# 側線の微細なパールゴールドライン
	for i in range(50):
		var t = float(i) / 49.0
		var lx = lerpf(300, 870, t)
		var ly = 295.0 + sin(t * PI) * 5.0
		_draw_circle_aa(img, Vector2(lx, ly), 1.2, Color(0.88, 0.78, 0.55, 0.6))

	# 胸びれ
	var pect_pts = PackedVector2Array([
		Vector2(320, 310), Vector2(400, 290), Vector2(420, 320), Vector2(330, 325)
	])
	_draw_realistic_fin(img, pect_pts, Vector2(325, 315), [Vector2(400, 290), Vector2(420, 320)], Color(0.95, 0.92, 0.75, 0.7), Color(1.0, 0.98, 0.88, 0.9), 7)

	# 尖った口先
	_draw_line_aa(img, Vector2(130, 305), Vector2(170, 300), Color(0.80, 0.65, 0.55, 0.85), 2.2)

	# エラブタ
	_draw_line_aa(img, Vector2(295, 270), Vector2(315, 330), Color(0.82, 0.68, 0.60, 0.75), 2.2)
	_draw_line_aa(img, Vector2(297, 271), Vector2(317, 331), Color(1.0, 1.0, 1.0, 0.6), 1.0)

	# 澄んだ丸い瞳
	_draw_realistic_eye(img, Vector2(220, 295), 13.5, Color(0.88, 0.75, 0.40, 1.0), 0.50)

# -----------------------------------------------------------------------------
# 3. アラカブ / カサゴ (Marbled Rockfish / Sebastiscus marmoratus)
# -----------------------------------------------------------------------------
func _draw_arakabu(img: Image) -> void:
	# 丸みのある大きな尾びれ（赤褐色斑点）
	var tail_pts = PackedVector2Array([
		Vector2(840, 290), Vector2(980, 200), Vector2(990, 300), Vector2(980, 400), Vector2(840, 310)
	])
	_draw_realistic_fin(img, tail_pts, Vector2(840, 300), [Vector2(980, 200), Vector2(990, 300), Vector2(980, 400)], Color(0.68, 0.24, 0.18, 0.85), Color(0.88, 0.42, 0.32, 0.95), 18)

	# 12本の強靭で鋭利な背びれ毒棘（Spiny Dorsal Fin）
	var dorsal = PackedVector2Array([Vector2(340, 200), Vector2(460, 80), Vector2(820, 250)])
	_draw_realistic_fin(img, dorsal, Vector2(450, 210), [Vector2(460, 80), Vector2(820, 250)], Color(0.72, 0.28, 0.20, 0.9), Color(0.92, 0.50, 0.35, 0.95), 14, true)

	# 尻びれ
	var anal_fin = PackedVector2Array([Vector2(600, 390), Vector2(680, 450), Vector2(800, 340)])
	_draw_realistic_fin(img, anal_fin, Vector2(650, 380), [Vector2(680, 450), Vector2(800, 340)], Color(0.70, 0.25, 0.18, 0.85), Color(0.88, 0.45, 0.35, 0.9), 10, true)

	# たくましい岩礁体幹
	var body_pts = PackedVector2Array([
		Vector2(140, 310), Vector2(220, 230), Vector2(380, 190), Vector2(560, 200),
		Vector2(740, 245), Vector2(850, 290), Vector2(860, 305),
		Vector2(840, 320), Vector2(720, 385), Vector2(540, 415), Vector2(360, 405),
		Vector2(220, 380)
	])
	_draw_poly_aa(img, body_pts, Color(0.85, 0.45, 0.35, 1.0))

	# 赤褐色・深紅の岩肌グラデーション
	for y in range(180, 425):
		for x in range(130, 870):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 190) / 225.0
				var col = mix_color(Color(0.45, 0.12, 0.08, 0.95), Color(0.92, 0.65, 0.50, 0.85), norm_y)
				var cur = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.blend(col))

	# アラカブ特有の岩礁迷彩モザイク斑（Marbled Camouflage Spots）
	var seed_spots = [
		Vector2(320, 260), Vector2(420, 240), Vector2(520, 230), Vector2(640, 260),
		Vector2(360, 320), Vector2(460, 310), Vector2(580, 300), Vector2(700, 310),
		Vector2(400, 370), Vector2(520, 360), Vector2(640, 350)
	]
	for sp in seed_spots:
		for j in range(6):
			var a = j * (TAU / 6.0) + sp.x * 0.1
			var p = sp + Vector2(cos(a) * 16.0, sin(a) * 11.0)
			_draw_circle_aa(img, p, 12.0, Color(0.32, 0.08, 0.05, 0.65))
			_draw_circle_aa(img, p + Vector2(-2, -2), 6.5, Color(0.78, 0.30, 0.20, 0.70))

	# 大きな扇形胸びれ（Fan-like Pectoral Fin）
	var pect_pts = PackedVector2Array([
		Vector2(330, 310), Vector2(470, 270), Vector2(500, 350), Vector2(440, 390), Vector2(340, 350)
	])
	_draw_realistic_fin(img, pect_pts, Vector2(335, 330), [Vector2(470, 270), Vector2(500, 350), Vector2(440, 390)], Color(0.82, 0.38, 0.25, 0.85), Color(0.95, 0.60, 0.45, 0.95), 14)

	# ゴツゴツした頭部骨突起・エラブタ棘
	_draw_line_aa(img, Vector2(280, 240), Vector2(330, 350), Color(0.30, 0.08, 0.05, 0.9), 3.2)
	_draw_line_aa(img, Vector2(310, 280), Vector2(335, 290), Color(0.20, 0.05, 0.04, 0.95), 2.5) # 鋭い主鰓蓋棘
	_draw_line_aa(img, Vector2(140, 310), Vector2(240, 350), Color(0.25, 0.08, 0.06, 0.9), 3.5) # 頑丈な大口

	# 上向きの大きなギョロ目
	_draw_realistic_eye(img, Vector2(245, 260), 18.0, Color(0.92, 0.75, 0.25, 1.0), 0.58)

# -----------------------------------------------------------------------------
# 4. チヌ / クロダイ (Black Seabream / Acanthopagrus schlegelii)
# -----------------------------------------------------------------------------
func _draw_chinu(img: Image) -> void:
	# 尾びれ（黒く縁取られた力強い二又尾）
	var tail_pts = PackedVector2Array([
		Vector2(870, 290), Vector2(1030, 170), Vector2(970, 295), Vector2(1030, 420), Vector2(870, 310)
	])
	_draw_realistic_fin(img, tail_pts, Vector2(870, 300), [Vector2(1030, 170), Vector2(970, 295), Vector2(1030, 420)], Color(0.25, 0.28, 0.30, 0.9), Color(0.12, 0.14, 0.16, 0.98), 18)

	# 鋭く強靭な漆黒背びれ棘条
	var dorsal = PackedVector2Array([Vector2(380, 190), Vector2(490, 80), Vector2(840, 240)])
	_draw_realistic_fin(img, dorsal, Vector2(480, 195), [Vector2(490, 80), Vector2(840, 240)], Color(0.22, 0.25, 0.28, 0.95), Color(0.45, 0.50, 0.55, 0.9), 16, true)

	# 尻びれ（鋭い第2棘）
	var anal_fin = PackedVector2Array([Vector2(620, 380), Vector2(690, 440), Vector2(830, 340)])
	_draw_realistic_fin(img, anal_fin, Vector2(660, 370), [Vector2(690, 440), Vector2(830, 340)], Color(0.25, 0.28, 0.30, 0.9), Color(0.15, 0.17, 0.19, 0.95), 12, true)

	# 体高のある重厚な体幹
	var body_pts = PackedVector2Array([
		Vector2(140, 310), Vector2(230, 240), Vector2(380, 180), Vector2(560, 180),
		Vector2(730, 230), Vector2(860, 280), Vector2(880, 295),
		Vector2(860, 315), Vector2(730, 370), Vector2(560, 400), Vector2(380, 395),
		Vector2(230, 360)
	])
	_draw_poly_aa(img, body_pts, Color(0.85, 0.88, 0.90, 1.0))

	# いぶし銀（ガンメタルブラック〜シルバー）グラデーション
	for y in range(175, 410):
		for x in range(130, 890):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 180) / 220.0
				var col = Color.TRANSPARENT
				if norm_y < 0.40:
					col = mix_color(Color(0.12, 0.15, 0.18, 0.95), Color(0.35, 0.40, 0.44, 0.7), norm_y / 0.40)
				elif norm_y < 0.70:
					col = mix_color(Color(0.35, 0.40, 0.44, 0.7), Color(0.70, 0.75, 0.78, 0.4), (norm_y - 0.40) / 0.30)
				else:
					col = mix_color(Color(0.70, 0.75, 0.78, 0.4), Color(0.92, 0.95, 0.98, 0.85), (norm_y - 0.70) / 0.30)
				var cur = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.blend(col))

	# 重厚なウロコ網目（黒い縁取りを持つ大型ウロコ）
	_draw_realistic_scales(img, body_pts, 320, 860, 290, 14.5, Color(0.40, 0.45, 0.48, 0.35), Color(0.88, 0.92, 0.95, 0.55))

	# 鋭い鎌状胸びれ
	var pect_pts = PackedVector2Array([
		Vector2(340, 305), Vector2(470, 275), Vector2(490, 320), Vector2(360, 335)
	])
	_draw_realistic_fin(img, pect_pts, Vector2(345, 315), [Vector2(470, 275), Vector2(490, 320)], Color(0.35, 0.38, 0.42, 0.85), Color(0.55, 0.60, 0.65, 0.9), 10)

	# 頑丈な顎・エラブタ
	_draw_line_aa(img, Vector2(140, 310), Vector2(210, 325), Color(0.18, 0.20, 0.22, 0.9), 3.5)
	_draw_line_aa(img, Vector2(305, 235), Vector2(340, 350), Color(0.16, 0.18, 0.20, 0.85), 3.0)
	_draw_line_aa(img, Vector2(307, 236), Vector2(342, 351), Color(0.85, 0.90, 0.95, 0.5), 1.2)

	# 精悍で鋭い眼
	_draw_realistic_eye(img, Vector2(235, 280), 16.5, Color(0.82, 0.70, 0.30, 1.0), 0.54)

# -----------------------------------------------------------------------------
# 5. マゴチ (Bartail Flathead / Platycephalus sp.)
# -----------------------------------------------------------------------------
func _draw_magochi(img: Image) -> void:
	# 尾びれ（特徴的な黄色と黒のタイガーストライプ）
	var tail_pts = PackedVector2Array([
		Vector2(880, 295), Vector2(1010, 230), Vector2(1020, 300), Vector2(1010, 370), Vector2(880, 305)
	])
	_draw_realistic_fin(img, tail_pts, Vector2(880, 300), [Vector2(1010, 230), Vector2(1020, 300), Vector2(1010, 370)], Color(0.85, 0.75, 0.25, 0.9), Color(0.15, 0.15, 0.15, 0.95), 16)
	# 尾びれの黒太バンド
	_draw_line_aa(img, Vector2(930, 250), Vector2(980, 350), Color(0.10, 0.10, 0.10, 0.9), 8.0)
	_draw_line_aa(img, Vector2(960, 240), Vector2(1005, 320), Color(0.95, 0.88, 0.20, 0.9), 6.0)

	# 背びれ
	var dorsal = PackedVector2Array([Vector2(460, 260), Vector2(530, 180), Vector2(840, 285)])
	_draw_realistic_fin(img, dorsal, Vector2(540, 265), [Vector2(530, 180), Vector2(840, 285)], Color(0.65, 0.55, 0.35, 0.8), Color(0.85, 0.75, 0.55, 0.9), 16)

	# 扁平な頭部とスマートな胴体
	var body_pts = PackedVector2Array([
		Vector2(120, 305), Vector2(240, 280), Vector2(400, 265), Vector2(600, 270),
		Vector2(780, 285), Vector2(880, 295), Vector2(890, 300),
		Vector2(880, 305), Vector2(780, 315), Vector2(600, 330), Vector2(400, 335),
		Vector2(240, 325)
	])
	_draw_poly_aa(img, body_pts, Color(0.82, 0.72, 0.52, 1.0))

	# 砂底擬態（茶褐色〜黄褐色砂紋）グラデーション
	for y in range(260, 345):
		for x in range(115, 900):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 265) / 75.0
				var col = mix_color(Color(0.42, 0.32, 0.18, 0.9), Color(0.92, 0.88, 0.78, 0.85), norm_y)
				var cur = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.blend(col))

	# 砂紋ブチ斑点（Leopard / Sand speckles）
	for i in range(80):
		var rx = randf_range(240, 860)
		var ry = randf_range(270, 330)
		if Geometry2D.is_point_in_polygon(Vector2(rx, ry), body_pts):
			_draw_circle_aa(img, Vector2(rx, ry), randf_range(2.0, 5.0), Color(0.28, 0.18, 0.08, 0.65))
			_draw_circle_aa(img, Vector2(rx + 1, ry + 1), 1.5, Color(0.95, 0.90, 0.75, 0.6))

	# 広大な扇形胸びれ
	var pect_pts = PackedVector2Array([
		Vector2(320, 305), Vector2(440, 275), Vector2(460, 345), Vector2(340, 335)
	])
	_draw_realistic_fin(img, pect_pts, Vector2(325, 315), [Vector2(440, 275), Vector2(460, 345)], Color(0.70, 0.58, 0.38, 0.85), Color(0.88, 0.78, 0.55, 0.9), 12)

	# 偏平ヘッドの口＆頭頂部の眼
	_draw_line_aa(img, Vector2(120, 305), Vector2(250, 315), Color(0.30, 0.20, 0.10, 0.85), 3.0)
	_draw_realistic_eye(img, Vector2(230, 285), 12.0, Color(0.75, 0.60, 0.25, 1.0), 0.52)

# -----------------------------------------------------------------------------
# 6. スズキ / シーバス (Japanese Seabass / Lateolabrax japonicus)
# -----------------------------------------------------------------------------
func _draw_suzuki(img: Image) -> void:
	# 尾びれ（深く切れ込んだ精悍な白銀尾）
	var tail_pts = PackedVector2Array([
		Vector2(880, 290), Vector2(1040, 160), Vector2(980, 295), Vector2(1040, 430), Vector2(880, 315)
	])
	_draw_realistic_fin(img, tail_pts, Vector2(880, 300), [Vector2(1040, 160), Vector2(980, 295), Vector2(1040, 430)], Color(0.55, 0.60, 0.65, 0.85), Color(0.85, 0.90, 0.95, 0.95), 20)

	# 第1背びれ（シャープな鋭い棘条群）
	var dorsal1 = PackedVector2Array([Vector2(390, 205), Vector2(490, 75), Vector2(580, 205)])
	_draw_realistic_fin(img, dorsal1, Vector2(480, 210), [Vector2(490, 75)], Color(0.40, 0.46, 0.52, 0.9), Color(0.70, 0.78, 0.85, 0.95), 10, true)

	# 第2背びれ
	var dorsal2 = PackedVector2Array([Vector2(600, 205), Vector2(680, 140), Vector2(850, 255)])
	_draw_realistic_fin(img, dorsal2, Vector2(690, 215), [Vector2(680, 140), Vector2(850, 255)], Color(0.50, 0.56, 0.62, 0.85), Color(0.80, 0.86, 0.92, 0.9), 16)

	# 尻びれ
	var anal_fin = PackedVector2Array([Vector2(620, 395), Vector2(690, 455), Vector2(840, 345)])
	_draw_realistic_fin(img, anal_fin, Vector2(680, 385), [Vector2(690, 455), Vector2(840, 345)], Color(0.55, 0.60, 0.65, 0.85), Color(0.88, 0.92, 0.96, 0.9), 14, true)

	# 堂々たる大型流線型体幹
	var body_pts = PackedVector2Array([
		Vector2(130, 305), Vector2(230, 235), Vector2(400, 195), Vector2(600, 195),
		Vector2(760, 245), Vector2(870, 285), Vector2(890, 300),
		Vector2(870, 315), Vector2(760, 365), Vector2(600, 405), Vector2(400, 400),
		Vector2(230, 365)
	])
	_draw_poly_aa(img, body_pts, Color(0.92, 0.95, 0.98, 1.0))

	# 青銀スチール〜白銀グラデーション
	for y in range(190, 415):
		for x in range(120, 900):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 195) / 210.0
				var col = Color.TRANSPARENT
				if norm_y < 0.38:
					col = mix_color(Color(0.20, 0.28, 0.36, 0.95), Color(0.48, 0.58, 0.66, 0.65), norm_y / 0.38)
				elif norm_y < 0.68:
					col = mix_color(Color(0.48, 0.58, 0.66, 0.65), Color(0.85, 0.90, 0.95, 0.35), (norm_y - 0.38) / 0.30)
				else:
					col = mix_color(Color(0.85, 0.90, 0.95, 0.35), Color(1.0, 1.0, 1.0, 0.9), (norm_y - 0.68) / 0.32)
				var cur = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.blend(col))

	# スズキ特有の背部細小黒斑群
	for i in range(45):
		var bx = randf_range(360, 780)
		var by = randf_range(210, 285)
		if Geometry2D.is_point_in_polygon(Vector2(bx, by), body_pts):
			_draw_circle_aa(img, Vector2(bx, by), randf_range(1.5, 3.2), Color(0.12, 0.16, 0.20, 0.75))

	# 白銀ウロコ模様
	_draw_realistic_scales(img, body_pts, 340, 870, 300, 13.0, Color(0.65, 0.72, 0.78, 0.28), Color(1.0, 1.0, 1.0, 0.5))

	# 突き出た下顎（獰猛なフィッシュイーター）
	_draw_line_aa(img, Vector2(125, 318), Vector2(230, 340), Color(0.25, 0.30, 0.35, 0.9), 3.5)
	_draw_line_aa(img, Vector2(130, 305), Vector2(220, 320), Color(0.18, 0.22, 0.26, 0.95), 2.8)

	# エラブタ
	_draw_line_aa(img, Vector2(310, 240), Vector2(345, 355), Color(0.30, 0.36, 0.42, 0.85), 3.0)
	_draw_line_aa(img, Vector2(312, 241), Vector2(347, 356), Color(1.0, 1.0, 1.0, 0.6), 1.2)

	# 鋭いシルバー眼
	_draw_realistic_eye(img, Vector2(235, 275), 17.0, Color(0.88, 0.82, 0.45, 1.0), 0.54)

# -----------------------------------------------------------------------------
# 7. キジハタ / アコウ (Red-spotted Grouper / Epinephelus akaara)
# -----------------------------------------------------------------------------
func _draw_kijihata(img: Image) -> void:
	# 丸みのある扇形尾びれ（黄色〜赤のグラデーション）
	var tail_pts = PackedVector2Array([
		Vector2(850, 290), Vector2(990, 205), Vector2(1010, 300), Vector2(990, 395), Vector2(850, 315)
	])
	_draw_realistic_fin(img, tail_pts, Vector2(850, 300), [Vector2(990, 205), Vector2(1010, 300), Vector2(990, 395)], Color(0.88, 0.48, 0.15, 0.85), Color(0.98, 0.75, 0.25, 0.95), 18)

	# 背びれ（前半鋭い棘、後半丸い軟条）
	var dorsal = PackedVector2Array([Vector2(360, 205), Vector2(480, 95), Vector2(830, 255)])
	_draw_realistic_fin(img, dorsal, Vector2(480, 215), [Vector2(480, 95), Vector2(830, 255)], Color(0.85, 0.42, 0.12, 0.9), Color(0.98, 0.70, 0.25, 0.95), 16, true)

	# 尻びれ
	var anal_fin = PackedVector2Array([Vector2(610, 390), Vector2(690, 450), Vector2(820, 345)])
	_draw_realistic_fin(img, anal_fin, Vector2(670, 380), [Vector2(690, 450), Vector2(820, 345)], Color(0.85, 0.42, 0.12, 0.85), Color(0.95, 0.65, 0.25, 0.9), 12, true)

	# 肉厚な体幹
	var body_pts = PackedVector2Array([
		Vector2(140, 310), Vector2(230, 235), Vector2(390, 190), Vector2(580, 195),
		Vector2(750, 245), Vector2(860, 285), Vector2(870, 300),
		Vector2(860, 315), Vector2(740, 375), Vector2(560, 410), Vector2(380, 405),
		Vector2(230, 370)
	])
	_draw_poly_aa(img, body_pts, Color(0.92, 0.52, 0.20, 1.0))

	# オレンジ褐色グラデーション
	for y in range(185, 415):
		for x in range(130, 880):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 190) / 220.0
				var col = mix_color(Color(0.55, 0.20, 0.05, 0.95), Color(0.98, 0.72, 0.45, 0.85), norm_y)
				var cur = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.blend(col))

	# ★キジハタ最大の象徴：宝石のようなコバルトブルー〜水色の輝く斑点群（Azure Gem Spots）
	for i in range(85):
		var rx = randf_range(240, 850)
		var ry = randf_range(205, 395)
		if Geometry2D.is_point_in_polygon(Vector2(rx, ry), body_pts):
			# 水色スポット
			_draw_circle_aa(img, Vector2(rx, ry), randf_range(3.0, 5.5), Color(0.20, 0.75, 0.95, 0.95))
			_draw_circle_aa(img, Vector2(rx - 0.8, ry - 0.8), 2.0, Color(0.75, 0.95, 1.0, 0.98)) # 宝石ハイライト
			_draw_circle_aa(img, Vector2(rx + 1.2, ry + 1.2), 4.5, Color(0.08, 0.25, 0.40, 0.35)) # ドロップシャドウ

	# 大きな胸びれ（黄色〜オレンジ縁）
	var pect_pts = PackedVector2Array([
		Vector2(340, 310), Vector2(480, 275), Vector2(510, 355), Vector2(350, 345)
	])
	_draw_realistic_fin(img, pect_pts, Vector2(345, 325), [Vector2(480, 275), Vector2(510, 355)], Color(0.92, 0.60, 0.15, 0.85), Color(1.0, 0.85, 0.35, 0.95), 14)

	# エラブタ
	_draw_line_aa(img, Vector2(310, 240), Vector2(345, 355), Color(0.38, 0.15, 0.05, 0.85), 3.0)

	# 澄んだ琥珀色の眼
	_draw_realistic_eye(img, Vector2(240, 270), 17.5, Color(0.95, 0.75, 0.25, 1.0), 0.52)

# -----------------------------------------------------------------------------
# 8. ヒラメ (Olive Flounder / Paralichthys olivaceus)
# -----------------------------------------------------------------------------
func _draw_hirame(img: Image) -> void:
	# 菱形尾びれ
	var tail_pts = PackedVector2Array([
		Vector2(880, 295), Vector2(1010, 230), Vector2(1030, 300), Vector2(1010, 370), Vector2(880, 305)
	])
	_draw_realistic_fin(img, tail_pts, Vector2(880, 300), [Vector2(1010, 230), Vector2(1030, 300), Vector2(1010, 370)], Color(0.65, 0.52, 0.38, 0.85), Color(0.85, 0.72, 0.58, 0.95), 18)

	# 体の上下を縁取る長いリボン状の背びれ・尻びれ
	var dorsal = PackedVector2Array([Vector2(250, 230), Vector2(500, 130), Vector2(860, 280)])
	_draw_realistic_fin(img, dorsal, Vector2(520, 220), [Vector2(500, 130), Vector2(860, 280)], Color(0.60, 0.48, 0.35, 0.85), Color(0.82, 0.70, 0.55, 0.9), 28)

	var anal_fin = PackedVector2Array([Vector2(320, 380), Vector2(520, 470), Vector2(860, 320)])
	_draw_realistic_fin(img, anal_fin, Vector2(530, 380), [Vector2(520, 470), Vector2(860, 320)], Color(0.60, 0.48, 0.35, 0.85), Color(0.82, 0.70, 0.55, 0.9), 28)

	# 偏平な木の葉型体幹
	var body_pts = PackedVector2Array([
		Vector2(140, 300), Vector2(240, 225), Vector2(420, 175), Vector2(620, 185),
		Vector2(780, 245), Vector2(880, 290), Vector2(890, 300),
		Vector2(880, 310), Vector2(780, 355), Vector2(620, 415), Vector2(420, 425),
		Vector2(240, 375)
	])
	_draw_poly_aa(img, body_pts, Color(0.72, 0.60, 0.45, 1.0))

	# 砂底・岩肌迷彩グラデーション
	for y in range(170, 430):
		for x in range(130, 900):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 175) / 250.0
				var col = mix_color(Color(0.38, 0.28, 0.18, 0.95), Color(0.78, 0.68, 0.52, 0.85), norm_y)
				var cur = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.blend(col))

	# 砂底擬態モザイク小斑点（茶・白・黒の霧状スプレー）
	for i in range(130):
		var rx = randf_range(230, 860)
		var ry = randf_range(190, 410)
		if Geometry2D.is_point_in_polygon(Vector2(rx, ry), body_pts):
			var r_col = Color(0.18, 0.12, 0.08, 0.75) if randf() < 0.65 else Color(0.95, 0.92, 0.85, 0.8)
			_draw_circle_aa(img, Vector2(rx, ry), randf_range(2.0, 4.5), r_col)

	# 獰猛なカミソリ歯と大きな口
	_draw_line_aa(img, Vector2(140, 300), Vector2(240, 325), Color(0.25, 0.18, 0.10, 0.9), 3.5)

	# 左ヒラメ（体の左側に並んだ2つの鋭い眼）
	_draw_realistic_eye(img, Vector2(250, 270), 13.0, Color(0.85, 0.72, 0.30, 1.0), 0.56)
	_draw_realistic_eye(img, Vector2(285, 260), 12.0, Color(0.85, 0.72, 0.30, 1.0), 0.56)

# -----------------------------------------------------------------------------
# 9. アオリイカ (Bigfin Reef Squid / Sepioteuthis lessoniana)
# -----------------------------------------------------------------------------
func _draw_aoriika(img: Image) -> void:
	# 広大な半透明エンペラ（ひれ: 外套膜の全周を取り囲む波打つ薄膜）
	var fin_pts = PackedVector2Array([
		Vector2(320, 290), Vector2(450, 140), Vector2(650, 110), Vector2(840, 170),
		Vector2(950, 295),
		Vector2(840, 420), Vector2(650, 480), Vector2(450, 450), Vector2(320, 310)
	])
	_draw_poly_aa(img, fin_pts, Color(0.85, 0.92, 0.95, 0.50))
	
	# エンペラの優美な波打ちライン（極細半透明レース）
	for i in range(40):
		var t = float(i) / 39.0
		var fx = lerpf(360, 920, t)
		var fy1 = 135.0 + sin(t * TAU * 2.0) * 12.0
		var fy2 = 465.0 - sin(t * TAU * 2.0) * 12.0
		_draw_circle_aa(img, Vector2(fx, fy1), 4.5, Color(0.95, 0.98, 1.0, 0.65))
		_draw_circle_aa(img, Vector2(fx, fy2), 4.5, Color(0.95, 0.98, 1.0, 0.65))

	# 外套膜（紡錘形のクリスタルボディ）
	var mantle_pts = PackedVector2Array([
		Vector2(340, 300), Vector2(480, 205), Vector2(680, 195), Vector2(860, 240),
		Vector2(960, 300),
		Vector2(860, 360), Vector2(680, 405), Vector2(480, 395)
	])
	_draw_poly_aa(img, mantle_pts, Color(0.92, 0.96, 0.98, 0.78))

	# 水晶透明グラデーション＆微細色素胞（クロマトフォア）
	for y in range(190, 410):
		for x in range(330, 970):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), mantle_pts):
				var norm_y = float(y - 200) / 200.0
				var col = mix_color(Color(0.80, 0.88, 0.94, 0.3), Color(0.98, 0.99, 1.0, 0.85), sin(norm_y * PI))
				var cur = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.blend(col))

	# 茶褐色の色素胞（微小ドットが点滅するリアルなイカ肌）
	for i in range(140):
		var rx = randf_range(380, 940)
		var ry = randf_range(215, 385)
		if Geometry2D.is_point_in_polygon(Vector2(rx, ry), mantle_pts):
			_draw_circle_aa(img, Vector2(rx, ry), randf_range(1.2, 3.2), Color(0.55, 0.28, 0.15, 0.65))
			_draw_circle_aa(img, Vector2(rx + 0.5, ry + 0.5), 1.0, Color(0.85, 0.65, 0.40, 0.5))

	# 頭部＆10本の腕・触腕（前方に伸びるしなやかな触手）
	var arms_base = Vector2(300, 300)
	var arm_targets = [
		Vector2(110, 220), Vector2(100, 260), Vector2(80, 300), Vector2(100, 340), Vector2(110, 380),
		# 2本の長い触腕（Tentacles）
		Vector2(50, 280), Vector2(50, 320)
	]
	for at in arm_targets:
		var mid_p = lerp(arms_base, at, 0.5) + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		_draw_line_aa(img, arms_base, mid_p, Color(0.88, 0.92, 0.95, 0.85), 5.5)
		_draw_line_aa(img, mid_p, at, Color(0.92, 0.96, 0.98, 0.85), 3.8)
		# 触腕先端の吸盤クラブ
		_draw_circle_aa(img, at, 5.0, Color(0.85, 0.70, 0.55, 0.8))

	# 神秘のエメラルドグリーンの瞳（イカ特有の横長スリット瞳孔）
	var eye_center = Vector2(310, 285)
	_draw_circle_aa(img, eye_center, 18.0, Color(0.08, 0.65, 0.60, 0.95))
	_draw_circle_aa(img, eye_center, 15.0, Color(0.20, 0.85, 0.75, 0.98))
	# 横長スリット瞳孔（W字形/スリット）
	_draw_line_aa(img, eye_center + Vector2(-9, 0), eye_center + Vector2(9, 0), Color(0.04, 0.08, 0.08, 1.0), 4.5)
	_draw_circle_aa(img, eye_center + Vector2(-4, -5), 4.0, Color(1.0, 1.0, 1.0, 0.95))
