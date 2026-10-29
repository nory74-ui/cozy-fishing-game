@tool
extends SceneTree

# 福岡・玄界灘の海洋生物＆海釣りエサ画像生成スクリプト

func _init() -> void:
	print("Generating sea fish and bait assets...")
	var assets_dir = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/"
	
	_generate_baits(assets_dir)
	_generate_sea_fishes(assets_dir)
	
	print("All sea assets generated successfully!")
	quit()

func _generate_baits(dir: String) -> void:
	# 1. アオイソメ (isome_bait.png)
	var img_isome = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	_draw_circle_aa(img_isome, Vector2(32, 32), 26.0, Color(0.12, 0.16, 0.22, 0.9))
	# 針
	_draw_hook(img_isome, Vector2(32, 28))
	# イソメ（青緑〜赤褐色のうねる虫）
	for i in range(20):
		var t = float(i) / 20.0
		var pos = Vector2(24 + sin(t * 8.0) * 8.0 + t * 16.0, 20 + t * 24.0)
		var col = Color(0.2, 0.5 + sin(t * 4.0) * 0.2, 0.35, 1.0)
		_draw_circle_aa(img_isome, pos, 3.2, col)
	img_isome.save_png(dir + "isome_bait.png")
	
	# 2. オキアミ (okiami_bait.png)
	var img_okiami = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	_draw_circle_aa(img_okiami, Vector2(32, 32), 26.0, Color(0.12, 0.16, 0.22, 0.9))
	_draw_hook(img_okiami, Vector2(32, 28))
	# ピンク透明のオキアミ
	for i in range(16):
		var t = float(i) / 16.0
		var ang = t * 3.14 * 0.8 + 0.2
		var pos = Vector2(32 + cos(ang) * 14.0, 30 + sin(ang) * 12.0)
		var col = Color(1.0, 0.72 + t * 0.1, 0.75, 0.95)
		_draw_circle_aa(img_okiami, pos, 3.5 - t * 1.5, col)
	_draw_circle_aa(img_okiami, Vector2(43, 31), 1.5, Color(0.1, 0.1, 0.1, 1.0)) # 黒い目
	img_okiami.save_png(dir + "okiami_bait.png")

	# 3. 活きエビ (shrimp_bait.png)
	var img_shrimp = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	_draw_circle_aa(img_shrimp, Vector2(32, 32), 26.0, Color(0.12, 0.16, 0.22, 0.9))
	_draw_hook(img_shrimp, Vector2(32, 28))
	for i in range(18):
		var t = float(i) / 18.0
		var ang = t * 3.14 * 0.9
		var pos = Vector2(32 + cos(ang) * 16.0, 32 + sin(ang) * 14.0)
		var col = Color(0.9, 0.85, 0.75, 0.95)
		_draw_circle_aa(img_shrimp, pos, 3.8 - t * 2.0, col)
	_draw_circle_aa(img_shrimp, Vector2(45, 30), 1.5, Color(0.1, 0.1, 0.1, 1.0))
	img_shrimp.save_png(dir + "shrimp_bait.png")

	# 4. メタルジグ (lure_bait.png)
	var img_lure = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	_draw_circle_aa(img_lure, Vector2(32, 32), 26.0, Color(0.12, 0.16, 0.22, 0.9))
	# 銀とピンクのメタルジグ
	for i in range(24):
		var t = float(i) / 24.0
		var pos = Vector2(20 + t * 24.0, 42 - t * 20.0)
		var col = Color(0.9, 0.4 + t * 0.5, 0.7 + t * 0.3, 1.0)
		_draw_circle_aa(img_lure, pos, 4.0 - abs(t - 0.5) * 3.0, col)
	_draw_hook(img_lure, Vector2(20, 42))
	img_lure.save_png(dir + "lure_bait.png")

func _draw_hook(img: Image, center: Vector2) -> void:
	var hook_col = Color(0.85, 0.75, 0.3, 1.0)
	for i in range(20):
		var ang = float(i) / 20.0 * 3.14 * 1.3 - 0.2
		var p = center + Vector2(cos(ang) * 9.0, sin(ang) * 9.0)
		_draw_circle_aa(img, p, 1.2, hook_col)

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
				var out_col = cur.blend(Color(color.r, color.g, color.b, alpha))
				img.set_pixel(x, y, out_col)

func _generate_sea_fishes(dir: String) -> void:
	var fish_specs = [
		{"id": "aji", "name": "マアジ", "back": Color(0.25, 0.42, 0.55), "belly": Color(0.92, 0.94, 0.96), "accent": Color(0.92, 0.80, 0.25), "len": 180, "h": 55},
		{"id": "kisu", "name": "シロギス", "back": Color(0.88, 0.78, 0.70), "belly": Color(0.98, 0.97, 0.96), "accent": Color(0.95, 0.82, 0.85), "len": 170, "h": 36},
		{"id": "arakabu", "name": "アラカブ", "back": Color(0.68, 0.28, 0.22), "belly": Color(0.85, 0.55, 0.45), "accent": Color(0.45, 0.15, 0.12), "len": 170, "h": 72},
		{"id": "chinu", "name": "チヌ", "back": Color(0.28, 0.32, 0.36), "belly": Color(0.72, 0.76, 0.80), "accent": Color(0.18, 0.20, 0.24), "len": 200, "h": 85},
		{"id": "magochi", "name": "マゴチ", "back": Color(0.52, 0.44, 0.35), "belly": Color(0.88, 0.85, 0.78), "accent": Color(0.32, 0.26, 0.20), "len": 210, "h": 46},
		{"id": "suzuki", "name": "スズキ", "back": Color(0.32, 0.40, 0.46), "belly": Color(0.92, 0.94, 0.96), "accent": Color(0.22, 0.26, 0.30), "len": 230, "h": 58},
		{"id": "kijihata", "name": "キジハタ", "back": Color(0.82, 0.42, 0.22), "belly": Color(0.95, 0.70, 0.50), "accent": Color(0.25, 0.65, 0.85), "len": 190, "h": 68},
		{"id": "hirame", "name": "ヒラメ", "back": Color(0.48, 0.42, 0.34), "belly": Color(0.96, 0.96, 0.95), "accent": Color(0.32, 0.28, 0.22), "len": 210, "h": 105},
		{"id": "madai", "name": "マダイ", "back": Color(0.92, 0.45, 0.52), "belly": Color(0.98, 0.85, 0.88), "accent": Color(0.20, 0.75, 0.70), "len": 200, "h": 84},
		{"id": "aoriika", "name": "アオリイカ", "back": Color(0.88, 0.92, 0.94), "belly": Color(0.96, 0.98, 0.99), "accent": Color(0.30, 0.85, 0.80), "len": 190, "h": 80}
	]
	
	for spec in fish_specs:
		var img = Image.create(256, 128, false, Image.FORMAT_RGBA8)
		var center = Vector2(128, 64)
		var f_len = float(spec["len"])
		var f_h = float(spec["h"])
		
		if spec["id"] == "aoriika":
			_render_squid(img, center, f_len, f_h, spec)
		else:
			_render_fish(img, center, f_len, f_h, spec)
			
		# 側面イラスト (fish_side_<sp>.png)
		img.save_png(dir + "fish_side_" + spec["id"] + ".png")
		# 汎用画像 (fish_<sp>.png)
		img.save_png(dir + "fish_" + spec["id"] + ".png")

func _render_fish(img: Image, center: Vector2, length: float, height: float, spec: Dictionary) -> void:
	var rx = length * 0.5
	var ry = height * 0.5
	
	# 尾ビレ
	var tail_x = center.x + rx * 0.85
	for ty in range(int(center.y - ry * 0.9), int(center.y + ry * 0.9)):
		var factor = abs(float(ty - center.y)) / (ry * 0.9)
		var tx_end = tail_x + factor * 28.0
		for tx in range(int(tail_x), int(tx_end)):
			img.set_pixel(tx, ty, spec["back"].lerp(spec["accent"], 0.4))
			
	# 背ビレ
	var dorsal_y = center.y - ry * 0.85
	for dx in range(int(center.x - rx * 0.4), int(center.x + rx * 0.4)):
		for dy in range(int(dorsal_y - 14.0), int(dorsal_y)):
			img.set_pixel(dx, dy, spec["back"].darkened(0.1))

	# 魚体本体（グラデーション楕円）
	for y in range(int(center.y - ry), int(center.y + ry)):
		for x in range(int(center.x - rx), int(center.x + rx)):
			var dx = (float(x - center.x) / rx)
			var dy = (float(y - center.y) / ry)
			if dx * dx + dy * dy <= 1.0:
				var t_vert = (dy + 1.0) * 0.5 # 0 = 背中, 1 = 腹
				var col = spec["back"].lerp(spec["belly"], t_vert)
				# マダイのエメラルド斑点やキジハタの青斑点
				if spec["id"] in ["madai", "kijihata"]:
					if (x % 14 == 0) and (y % 10 == 0) and t_vert < 0.6:
						col = spec["accent"]
				img.set_pixel(x, y, col)
				
	# 目
	var eye_pos = Vector2(center.x - rx * 0.68, center.y - ry * 0.15)
	_draw_circle_aa(img, eye_pos, 4.5, Color(1, 1, 1, 1))
	_draw_circle_aa(img, eye_pos, 2.5, Color(0.1, 0.1, 0.1, 1))

func _render_squid(img: Image, center: Vector2, length: float, height: float, spec: Dictionary) -> void:
	var rx = length * 0.42
	var ry = height * 0.48
	# 胴体
	for y in range(int(center.y - ry), int(center.y + ry)):
		for x in range(int(center.x - rx * 0.8), int(center.x + rx * 0.8)):
			var dx = (float(x - center.x) / rx)
			var dy = (float(y - center.y) / ry)
			if dx * dx + dy * dy <= 1.0:
				var col = spec["belly"].lerp(spec["accent"], 0.15)
				img.set_pixel(x, y, col)
	# ゲソ（触手）
	for i in range(8):
		var y_off = (i - 4) * 5.0
		for x in range(int(center.x - rx * 0.8 - 35), int(center.x - rx * 0.8)):
			img.set_pixel(x, int(center.y + y_off), spec["belly"].darkened(0.1))
	# 目
	_draw_circle_aa(img, Vector2(center.x - rx * 0.6, center.y - 6), 3.5, Color(0.1, 0.1, 0.1, 1.0))
	_draw_circle_aa(img, Vector2(center.x - rx * 0.6, center.y + 6), 3.5, Color(0.1, 0.1, 0.1, 1.0))
