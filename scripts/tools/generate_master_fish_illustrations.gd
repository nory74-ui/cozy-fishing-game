@tool
extends SceneTree

# 全10魚種 最高品質リアルデジタルイラスト生成スクリプト
# （マダイのプロ品質に匹敵する、各魚の骨格・ウロコ・エラ・ヒレ条線・瞳を描画）

func _init() -> void:
	print("Generating master fish illustrations (800x400 HD)...")
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
		var img = Image.create(800, 400, false, Image.FORMAT_RGBA8)
		call(f["render"], img)
		var side_path = assets_dir + "fish_side_" + f["id"] + ".png"
		var top_path = assets_dir + "fish_" + f["id"] + ".png"
		img.save_png(side_path)
		img.save_png(top_path)
		print("Generated HD fish: ", f["id"], " -> ", side_path)

	print("All fish illustrations generated successfully!")
	quit()

# -----------------------------------------------------------------------------
# 描画補助関数群
# -----------------------------------------------------------------------------
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
	var min_x = 800.0
	var max_x = 0.0
	var min_y = 400.0
	var max_y = 0.0
	for p in pts:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
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
# 1. マアジ (Japanese Jack Mackerel)
# -----------------------------------------------------------------------------
func _draw_aji(img: Image) -> void:
	# 尾びれ（黄色）
	var tail_pts = PackedVector2Array([
		Vector2(650, 200), Vector2(740, 110), Vector2(710, 200), Vector2(740, 290)
	])
	_draw_poly_aa(img, tail_pts, Color(0.92, 0.82, 0.25, 0.95))
	for i in range(12):
		var t = float(i) / 11.0
		var tip = lerp(Vector2(740, 110), Vector2(740, 290), t)
		_draw_line_aa(img, Vector2(650, 200), tip, Color(0.78, 0.65, 0.15, 0.7), 1.4)

	# 背びれ・尻びれ
	var dorsal1 = PackedVector2Array([Vector2(320, 160), Vector2(380, 80), Vector2(430, 160)])
	var dorsal2 = PackedVector2Array([Vector2(440, 160), Vector2(500, 110), Vector2(610, 175)])
	var anal_fin = PackedVector2Array([Vector2(450, 240), Vector2(510, 275), Vector2(610, 225)])
	_draw_poly_aa(img, dorsal1, Color(0.35, 0.45, 0.52, 0.85))
	_draw_poly_aa(img, dorsal2, Color(0.85, 0.80, 0.35, 0.80))
	_draw_poly_aa(img, anal_fin, Color(0.90, 0.90, 0.85, 0.80))

	# 体幹（流線型）
	var body_pts = PackedVector2Array([
		Vector2(100, 200), Vector2(160, 165), Vector2(260, 145), Vector2(380, 140),
		Vector2(500, 155), Vector2(610, 185), Vector2(660, 200),
		Vector2(610, 215), Vector2(500, 245), Vector2(380, 260), Vector2(260, 255),
		Vector2(160, 235)
	])
	_draw_poly_aa(img, body_pts, Color(0.92, 0.94, 0.96, 1.0))

	# 体幹の陰影グラデーション（背中: 深青緑〜オリーブ、腹部: シルバー白）
	for y in range(130, 270):
		for x in range(90, 670):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 140) / 120.0
				var col = Color.TRANSPARENT
				if norm_y < 0.45:
					var bt = norm_y / 0.45
					col = mix_color(Color(0.20, 0.38, 0.48, 0.95), Color(0.42, 0.65, 0.68, 0.6), bt)
				else:
					var wt = (norm_y - 0.45) / 0.55
					col = mix_color(Color(0.85, 0.88, 0.92, 0.2), Color(1.0, 1.0, 1.0, 0.85), wt)
				var cur = img.get_pixel(x, y)
				img.set_pixel(x, y, cur.blend(col))

	# アジ特有の側線＆ゼゴ（稜鱗: 尾部にかけてのシャープな黄・銀のトゲ線）
	for i in range(40):
		var t = float(i) / 39.0
		var zx = lerpf(240, 650, t)
		var zy = 195.0 + sin(t * PI * 0.9) * 12.0
		if t > 0.4:
			_draw_line_aa(img, Vector2(zx, zy - 4), Vector2(zx + 6, zy + 4), Color(0.92, 0.82, 0.25, 0.9), 2.2)
			_draw_circle_aa(img, Vector2(zx + 3, zy), 1.5, Color(0.45, 0.40, 0.15, 0.8))
		else:
			_draw_circle_aa(img, Vector2(zx, zy), 1.5, Color(0.35, 0.55, 0.65, 0.7))

	# エラブタ・黒班（アジ特有のエラブタ上部の黒点）
	_draw_line_aa(img, Vector2(230, 165), Vector2(245, 230), Color(0.35, 0.45, 0.52, 0.8), 2.2)
	_draw_circle_aa(img, Vector2(240, 172), 5.5, Color(0.12, 0.15, 0.18, 0.9)) # エラブタ黒斑

	# 大きな胸びれ（黄色みを帯びた半透明）
	var pectoral = PackedVector2Array([Vector2(250, 205), Vector2(340, 195), Vector2(320, 225)])
	_draw_poly_aa(img, pectoral, Color(0.92, 0.85, 0.40, 0.75))

	# 瞳
	_draw_eye(img, Vector2(165, 190), 12.0, Color(0.92, 0.82, 0.25, 1.0))

# -----------------------------------------------------------------------------
# 2. シロギス (Japanese Whiting)
# -----------------------------------------------------------------------------
func _draw_kisu(img: Image) -> void:
	# 尾びれ
	var tail_pts = PackedVector2Array([
		Vector2(660, 200), Vector2(745, 140), Vector2(715, 200), Vector2(745, 260)
	])
	_draw_poly_aa(img, tail_pts, Color(0.95, 0.88, 0.80, 0.85))

	# 背びれ（繊細な透明ヒレ）
	var dorsal1 = PackedVector2Array([Vector2(320, 180), Vector2(370, 125), Vector2(410, 180)])
	var dorsal2 = PackedVector2Array([Vector2(420, 180), Vector2(490, 145), Vector2(590, 190)])
	_draw_poly_aa(img, dorsal1, Color(0.95, 0.85, 0.75, 0.75))
	_draw_poly_aa(img, dorsal2, Color(0.95, 0.85, 0.75, 0.70))

	# 体幹（ほっそりしたスレンダー体型）
	var body_pts = PackedVector2Array([
		Vector2(90, 200), Vector2(170, 175), Vector2(280, 165), Vector2(420, 165),
		Vector2(550, 180), Vector2(670, 200), Vector2(550, 220),
		Vector2(420, 235), Vector2(280, 235), Vector2(170, 225)
	])
	_draw_poly_aa(img, body_pts, Color(0.98, 0.96, 0.94, 1.0))

	# オパール・真珠の輝きグラデーション
	for y in range(160, 240):
		for x in range(85, 680):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 165) / 70.0
				var col = Color.TRANSPARENT
				if norm_y < 0.4:
					col = mix_color(Color(0.85, 0.75, 0.65, 0.85), Color(0.95, 0.82, 0.85, 0.5), norm_y / 0.4)
				else:
					col = mix_color(Color(0.95, 0.82, 0.85, 0.3), Color(1.0, 1.0, 1.0, 0.9), (norm_y - 0.4) / 0.6)
				img.set_pixel(x, y, img.get_pixel(x, y).blend(col))

	# 側線の微細なパールピンクのライン
	for i in range(45):
		var t = float(i) / 44.0
		var px = lerpf(180, 660, t)
		var py = 200.0 + sin(t * PI) * 3.0
		_draw_circle_aa(img, Vector2(px, py), 1.2, Color(0.92, 0.78, 0.75, 0.8))

	# エラ・胸びれ
	_draw_line_aa(img, Vector2(215, 175), Vector2(225, 225), Color(0.75, 0.65, 0.60, 0.7), 1.8)
	var pectoral = PackedVector2Array([Vector2(230, 205), Vector2(295, 200), Vector2(285, 220)])
	_draw_poly_aa(img, pectoral, Color(0.98, 0.90, 0.82, 0.8))

	# 澄んだ瞳
	_draw_eye(img, Vector2(150, 192), 9.0, Color(0.2, 0.2, 0.2, 1.0))

# -----------------------------------------------------------------------------
# 3. アラカブ / カサゴ (Scorpionfish)
# -----------------------------------------------------------------------------
func _draw_arakabu(img: Image) -> void:
	# 尾びれ（団扇状・丸い）
	var tail_pts = PackedVector2Array([
		Vector2(620, 200), Vector2(720, 140), Vector2(735, 200), Vector2(720, 260)
	])
	_draw_poly_aa(img, tail_pts, Color(0.68, 0.25, 0.18, 0.9))

	# 大きく鋭い背びれ（毒々しくもカッコいい棘条群）
	for s in range(8):
		var sx = 260.0 + s * 38.0
		var h = 90.0 - abs(s - 3) * 8.0
		var spine_pts = PackedVector2Array([
			Vector2(sx - 15, 160), Vector2(sx, 160 - h), Vector2(sx + 15, 160)
		])
		_draw_poly_aa(img, spine_pts, Color(0.75, 0.28, 0.20, 0.85))
		_draw_line_aa(img, Vector2(sx, 160), Vector2(sx, 160 - h), Color(0.95, 0.85, 0.70, 0.9), 2.2)

	# ゴツゴツした重量感ある体幹
	var body_pts = PackedVector2Array([
		Vector2(110, 200), Vector2(180, 150), Vector2(280, 135), Vector2(420, 145),
		Vector2(540, 170), Vector2(630, 200), Vector2(540, 230),
		Vector2(420, 255), Vector2(280, 265), Vector2(180, 250)
	])
	_draw_poly_aa(img, body_pts, Color(0.72, 0.28, 0.20, 1.0))

	# 赤褐色のまだら迷彩＆岩肌グラデーション
	for y in range(130, 270):
		for x in range(100, 640):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 135) / 130.0
				var col = mix_color(Color(0.48, 0.15, 0.10, 0.9), Color(0.88, 0.55, 0.40, 0.8), norm_y)
				img.set_pixel(x, y, img.get_pixel(x, y).blend(col))

	# 散らばる白・黒の斑点
	for bx in range(180, 600, 28):
		for by in range(150, 250, 22):
			_draw_circle_aa(img, Vector2(bx + sin(by) * 8.0, by), 4.5, Color(0.32, 0.08, 0.05, 0.8))
			_draw_circle_aa(img, Vector2(bx + 6, by + 4), 3.0, Color(0.95, 0.85, 0.75, 0.7))

	# 大きな胸びれ（トゲトゲの扇）
	var pec_pts = PackedVector2Array([
		Vector2(240, 205), Vector2(340, 170), Vector2(360, 220), Vector2(330, 250)
	])
	_draw_poly_aa(img, pec_pts, Color(0.68, 0.25, 0.18, 0.85))

	# クルリとした大きな眼
	_draw_eye(img, Vector2(175, 185), 14.0, Color(0.85, 0.65, 0.20, 1.0))

# -----------------------------------------------------------------------------
# 4. チヌ / クロダイ (Black Seabream)
# -----------------------------------------------------------------------------
func _draw_chinu(img: Image) -> void:
	# 尾びれ（黒光りする頑強な尾）
	var tail_pts = PackedVector2Array([
		Vector2(640, 200), Vector2(735, 120), Vector2(705, 200), Vector2(735, 280)
	])
	_draw_poly_aa(img, tail_pts, Color(0.24, 0.28, 0.32, 0.95))

	# シャープな背びれ
	var dorsal = PackedVector2Array([
		Vector2(290, 145), Vector2(380, 75), Vector2(560, 125), Vector2(610, 180)
	])
	_draw_poly_aa(img, dorsal, Color(0.20, 0.24, 0.28, 0.9))
	for i in range(10):
		var sx = 300.0 + i * 28.0
		_draw_line_aa(img, Vector2(sx, 145), Vector2(sx + 5, 80 + i * 8), Color(0.65, 0.70, 0.75, 0.8), 2.0)

	# 体高のある引き締まった体幹
	var body_pts = PackedVector2Array([
		Vector2(110, 200), Vector2(180, 145), Vector2(290, 120), Vector2(440, 125),
		Vector2(560, 160), Vector2(650, 200), Vector2(560, 240),
		Vector2(440, 275), Vector2(290, 270), Vector2(180, 245)
	])
	_draw_poly_aa(img, body_pts, Color(0.70, 0.74, 0.78, 1.0))

	# いぶし銀の鱗テクスチャとグラデーション
	for y in range(115, 280):
		for x in range(100, 660):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 120) / 155.0
				var col = mix_color(Color(0.18, 0.22, 0.26, 0.95), Color(0.85, 0.88, 0.92, 0.6), norm_y)
				img.set_pixel(x, y, img.get_pixel(x, y).blend(col))

	# 重厚なウロコ網目
	for sx in range(220, 600, 16):
		for sy in range(140, 260, 14):
			_draw_line_aa(img, Vector2(sx, sy), Vector2(sx + 8, sy + 7), Color(0.15, 0.18, 0.22, 0.4), 1.2)
			_draw_line_aa(img, Vector2(sx + 8, sy + 7), Vector2(sx, sy + 14), Color(0.15, 0.18, 0.22, 0.4), 1.2)

	# 胸びれ
	var pectoral = PackedVector2Array([Vector2(260, 205), Vector2(360, 190), Vector2(340, 225)])
	_draw_poly_aa(img, pectoral, Color(0.35, 0.40, 0.45, 0.85))

	# 精悍な眼
	_draw_eye(img, Vector2(175, 185), 13.0, Color(0.75, 0.80, 0.85, 1.0))

# -----------------------------------------------------------------------------
# 5. マゴチ (Flathead)
# -----------------------------------------------------------------------------
func _draw_magochi(img: Image) -> void:
	# 尾びれ（黄色と黒の縞）
	var tail_pts = PackedVector2Array([
		Vector2(650, 200), Vector2(740, 145), Vector2(735, 200), Vector2(740, 255)
	])
	_draw_poly_aa(img, tail_pts, Color(0.88, 0.80, 0.35, 0.95))
	_draw_line_aa(img, Vector2(670, 175), Vector2(735, 175), Color(0.15, 0.15, 0.15, 0.9), 4.0)
	_draw_line_aa(img, Vector2(670, 225), Vector2(735, 225), Color(0.15, 0.15, 0.15, 0.9), 4.0)

	# 扁平な体幹（ワニのような平べったい頭部とスリムな尾）
	var body_pts = PackedVector2Array([
		Vector2(80, 200), Vector2(160, 180), Vector2(280, 175), Vector2(450, 180),
		Vector2(580, 190), Vector2(660, 200), Vector2(580, 210),
		Vector2(450, 220), Vector2(280, 225), Vector2(160, 220)
	])
	_draw_poly_aa(img, body_pts, Color(0.55, 0.45, 0.35, 1.0))

	# 砂底迷彩
	for y in range(170, 230):
		for x in range(75, 670):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 175) / 50.0
				var col = mix_color(Color(0.40, 0.32, 0.24, 0.9), Color(0.78, 0.72, 0.60, 0.7), norm_y)
				img.set_pixel(x, y, img.get_pixel(x, y).blend(col))

	# 砂模様のブチ斑点
	for bx in range(150, 620, 22):
		for by in range(180, 220, 12):
			_draw_circle_aa(img, Vector2(bx, by), 2.8, Color(0.25, 0.18, 0.12, 0.75))

	# 幅広い団扇状の胸びれ
	var pec1 = PackedVector2Array([Vector2(220, 175), Vector2(300, 150), Vector2(310, 180)])
	var pec2 = PackedVector2Array([Vector2(220, 225), Vector2(300, 250), Vector2(310, 220)])
	_draw_poly_aa(img, pec1, Color(0.52, 0.42, 0.32, 0.85))
	_draw_poly_aa(img, pec2, Color(0.52, 0.42, 0.32, 0.85))

	# 上部を向く平たい眼
	_draw_eye(img, Vector2(150, 190), 8.5, Color(0.65, 0.55, 0.25, 1.0))

# -----------------------------------------------------------------------------
# 6. スズキ (Japanese Sea Bass)
# -----------------------------------------------------------------------------
func _draw_suzuki(img: Image) -> void:
	# 尾びれ（大型で力強い二又）
	var tail_pts = PackedVector2Array([
		Vector2(650, 200), Vector2(750, 115), Vector2(715, 200), Vector2(750, 285)
	])
	_draw_poly_aa(img, tail_pts, Color(0.35, 0.42, 0.48, 0.95))

	# 大きな二層の背びれ
	var dorsal1 = PackedVector2Array([Vector2(280, 150), Vector2(360, 75), Vector2(430, 150)])
	var dorsal2 = PackedVector2Array([Vector2(440, 150), Vector2(520, 110), Vector2(620, 175)])
	_draw_poly_aa(img, dorsal1, Color(0.30, 0.38, 0.45, 0.9))
	_draw_poly_aa(img, dorsal2, Color(0.40, 0.48, 0.55, 0.85))
	for i in range(8):
		var sx = 295.0 + i * 16.0
		_draw_line_aa(img, Vector2(sx, 150), Vector2(sx, 80 + i * 8), Color(0.85, 0.90, 0.95, 0.9), 2.2)

	# 堂々たる大型流線型体幹
	var body_pts = PackedVector2Array([
		Vector2(90, 200), Vector2(170, 150), Vector2(290, 130), Vector2(450, 135),
		Vector2(580, 165), Vector2(660, 200), Vector2(580, 235),
		Vector2(450, 265), Vector2(290, 260), Vector2(170, 240)
	])
	_draw_poly_aa(img, body_pts, Color(0.92, 0.94, 0.96, 1.0))

	# 銀黒〜白銀のメタリックグラデーション
	for y in range(125, 270):
		for x in range(85, 670):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 130) / 135.0
				var col = mix_color(Color(0.22, 0.30, 0.38, 0.95), Color(0.92, 0.95, 0.98, 0.7), norm_y)
				img.set_pixel(x, y, img.get_pixel(x, y).blend(col))

	# 背部の微細な黒点散布（スズキ特有の小黒斑群）
	for bx in range(260, 580, 18):
		for by in range(145, 195, 12):
			_draw_circle_aa(img, Vector2(bx + sin(by) * 6.0, by), 1.8, Color(0.15, 0.20, 0.25, 0.8))

	# エラ・胸びれ
	_draw_line_aa(img, Vector2(220, 155), Vector2(240, 235), Color(0.28, 0.36, 0.42, 0.85), 2.5)
	var pectoral = PackedVector2Array([Vector2(250, 205), Vector2(350, 195), Vector2(330, 225)])
	_draw_poly_aa(img, pectoral, Color(0.45, 0.55, 0.62, 0.85))

	# 鋭い捕食者の眼
	_draw_eye(img, Vector2(160, 185), 14.0, Color(0.85, 0.75, 0.30, 1.0))

# -----------------------------------------------------------------------------
# 7. キジハタ / アコウ (Red-spotted Grouper)
# -----------------------------------------------------------------------------
func _draw_kijihata(img: Image) -> void:
	# 尾びれ（丸い高級感ある尾）
	var tail_pts = PackedVector2Array([
		Vector2(630, 200), Vector2(725, 135), Vector2(740, 200), Vector2(725, 265)
	])
	_draw_poly_aa(img, tail_pts, Color(0.78, 0.38, 0.18, 0.95))

	# 背びれ
	var dorsal = PackedVector2Array([
		Vector2(270, 145), Vector2(360, 85), Vector2(550, 120), Vector2(610, 175)
	])
	_draw_poly_aa(img, dorsal, Color(0.82, 0.42, 0.20, 0.9))

	# 重量感ある体幹
	var body_pts = PackedVector2Array([
		Vector2(100, 200), Vector2(170, 145), Vector2(280, 125), Vector2(430, 130),
		Vector2(550, 160), Vector2(640, 200), Vector2(550, 240),
		Vector2(430, 270), Vector2(280, 265), Vector2(170, 245)
	])
	_draw_poly_aa(img, body_pts, Color(0.85, 0.42, 0.22, 1.0))

	# 鮮やかなオレンジ褐色グラデーション
	for y in range(120, 275):
		for x in range(95, 650):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 125) / 145.0
				var col = mix_color(Color(0.55, 0.22, 0.10, 0.95), Color(0.95, 0.65, 0.40, 0.7), norm_y)
				img.set_pixel(x, y, img.get_pixel(x, y).blend(col))

	# キジハタ特有の宝石のような水色・オレンジ斑点
	for bx in range(160, 620, 18):
		for by in range(140, 260, 16):
			_draw_circle_aa(img, Vector2(bx + sin(by) * 5.0, by), 3.8, Color(0.20, 0.70, 0.90, 0.9))
			_draw_circle_aa(img, Vector2(bx + sin(by) * 5.0 - 1, by - 1), 2.0, Color(0.60, 0.90, 1.0, 0.95))

	# 胸びれ
	var pectoral = PackedVector2Array([Vector2(240, 205), Vector2(340, 185), Vector2(350, 225)])
	_draw_poly_aa(img, pectoral, Color(0.90, 0.50, 0.25, 0.85))

	# 瞳
	_draw_eye(img, Vector2(165, 185), 13.0, Color(0.20, 0.65, 0.85, 1.0))

# -----------------------------------------------------------------------------
# 8. ヒラメ (Olive Flounder)
# -----------------------------------------------------------------------------
func _draw_hirame(img: Image) -> void:
	# 尾びれ
	var tail_pts = PackedVector2Array([
		Vector2(640, 200), Vector2(730, 130), Vector2(710, 200), Vector2(730, 270)
	])
	_draw_poly_aa(img, tail_pts, Color(0.45, 0.38, 0.30, 0.9))

	# 上下に広がる長いヒレ
	var dorsal = PackedVector2Array([
		Vector2(160, 150), Vector2(300, 95), Vector2(500, 110), Vector2(620, 175)
	])
	var anal = PackedVector2Array([
		Vector2(180, 250), Vector2(320, 305), Vector2(500, 290), Vector2(620, 225)
	])
	_draw_poly_aa(img, dorsal, Color(0.48, 0.40, 0.32, 0.85))
	_draw_poly_aa(img, anal, Color(0.48, 0.40, 0.32, 0.85))

	# 平らな楕円体幹（サーフの座布団ヒラメ）
	var body_pts = PackedVector2Array([
		Vector2(90, 200), Vector2(160, 140), Vector2(290, 105), Vector2(450, 115),
		Vector2(580, 155), Vector2(650, 200), Vector2(580, 245),
		Vector2(450, 285), Vector2(290, 295), Vector2(160, 260)
	])
	_draw_poly_aa(img, body_pts, Color(0.48, 0.40, 0.32, 1.0))

	# 砂底擬態テクスチャ
	for y in range(100, 300):
		for x in range(85, 660):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), body_pts):
				var norm_y = float(y - 105) / 190.0
				var col = mix_color(Color(0.35, 0.28, 0.22, 0.95), Color(0.65, 0.58, 0.48, 0.7), norm_y)
				img.set_pixel(x, y, img.get_pixel(x, y).blend(col))

	# 砂利斑点
	for bx in range(150, 620, 20):
		for by in range(120, 280, 18):
			_draw_circle_aa(img, Vector2(bx + sin(by) * 6.0, by), 3.2, Color(0.25, 0.18, 0.14, 0.8))
			_draw_circle_aa(img, Vector2(bx + 4, by + 3), 2.0, Color(0.85, 0.80, 0.70, 0.6))

	# 鋭い牙を持つ大きな口
	_draw_line_aa(img, Vector2(90, 200), Vector2(150, 215), Color(0.18, 0.12, 0.08, 0.9), 2.5)

	# 左側に並ぶ二つの眼（ヒラメ特有の両眼）
	_draw_eye(img, Vector2(145, 175), 7.5, Color(0.75, 0.65, 0.35, 1.0))
	_draw_eye(img, Vector2(165, 168), 7.5, Color(0.75, 0.65, 0.35, 1.0))

# -----------------------------------------------------------------------------
# 9. アオリイカ (Bigfin Reef Squid)
# -----------------------------------------------------------------------------
func _draw_aoriika(img: Image) -> void:
	# ゆらめくエンペラ（胴体の周囲を覆う透明なフリル）
	var fin_pts = PackedVector2Array([
		Vector2(200, 200), Vector2(250, 110), Vector2(400, 95), Vector2(560, 120),
		Vector2(650, 200), Vector2(560, 280), Vector2(400, 305), Vector2(250, 290)
	])
	_draw_poly_aa(img, fin_pts, Color(0.75, 0.92, 0.95, 0.65))

	# 水晶のように透き通る肉厚な胴体（外套膜）
	var mantle_pts = PackedVector2Array([
		Vector2(210, 200), Vector2(270, 140), Vector2(380, 125), Vector2(500, 140),
		Vector2(640, 200), Vector2(500, 260), Vector2(380, 275), Vector2(270, 260)
	])
	_draw_poly_aa(img, mantle_pts, Color(0.92, 0.96, 0.98, 0.90))

	# 虹色の透明感グラデーション
	for y in range(120, 280):
		for x in range(200, 650):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), mantle_pts):
				var norm_x = float(x - 210) / 430.0
				var col = mix_color(Color(0.85, 0.92, 0.98, 0.5), Color(0.98, 0.85, 0.90, 0.4), norm_x)
				img.set_pixel(x, y, img.get_pixel(x, y).blend(col))

	# 胴体の虎斑（アオリイカの美しい縞模様）
	for i in range(12):
		var sx = 270.0 + i * 28.0
		_draw_line_aa(img, Vector2(sx, 150), Vector2(sx + 10, 250), Color(0.45, 0.35, 0.30, 0.35), 2.5)

	# 10本の触腕・腕（前方に伸びるしなやかな触腕）
	for a in range(8):
		var ang = (a - 3.5) * 0.18
		var arm_end = Vector2(80, 200) + Vector2(cos(ang) * 90.0, sin(ang) * 60.0)
		_draw_line_aa(img, Vector2(190, 200), arm_end, Color(0.90, 0.88, 0.85, 0.9), 3.5)
	# 2本の長い触腕
	_draw_line_aa(img, Vector2(190, 195), Vector2(50, 160), Color(0.95, 0.90, 0.88, 0.95), 4.0)
	_draw_line_aa(img, Vector2(190, 205), Vector2(50, 240), Color(0.95, 0.90, 0.88, 0.95), 4.0)

	# エメラルドグリーンに妖しく輝く大きな眼
	_draw_circle_aa(img, Vector2(200, 185), 11.0, Color(0.1, 0.15, 0.2, 1.0))
	_draw_circle_aa(img, Vector2(200, 185), 7.5, Color(0.20, 0.85, 0.65, 0.95))
	_draw_circle_aa(img, Vector2(198, 183), 3.0, Color(1.0, 1.0, 1.0, 1.0))

# -----------------------------------------------------------------------------
# 共通描画パーツ
# -----------------------------------------------------------------------------
func _draw_eye(img: Image, center: Vector2, radius: float, iris_col: Color) -> void:
	_draw_circle_aa(img, center, radius, Color(0.15, 0.18, 0.22, 1.0)) # 外枠
	_draw_circle_aa(img, center, radius * 0.75, iris_col)              # 虹彩
	_draw_circle_aa(img, center, radius * 0.45, Color(0.08, 0.10, 0.12, 1.0)) # 瞳孔
	_draw_circle_aa(img, center + Vector2(-radius * 0.25, -radius * 0.25), radius * 0.25, Color.WHITE) # 光彩ハイライト

func mix_color(c1: Color, c2: Color, t: float) -> Color:
	return Color(
		lerpf(c1.r, c2.r, t),
		lerpf(c1.g, c2.g, t),
		lerpf(c1.b, c2.b, t),
		lerpf(c1.a, c2.a, t)
	)
