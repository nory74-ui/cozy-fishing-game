@tool
extends SceneTree

func _init() -> void:
	print("Processing HD-2D assets...")
	var assets_dir = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/"
	
	# 1. 釣り人の透過処理
	make_transparent(assets_dir + "hd2d_fisherman.jpg", assets_dir + "hd2d_fisherman.png", 0.90, 0.96)
	
	# 2. 魚シートの透過処理
	make_transparent(assets_dir + "hd2d_fishes.jpg", assets_dir + "hd2d_fishes.png", 0.90, 0.96)
	
	# 3. 魚たちの個別クロップ
	crop_fishes(assets_dir + "hd2d_fishes.png", assets_dir)
	
	print("HD-2D assets processed successfully!")
	quit()

func make_transparent(src: String, dst: String, t_min: float, t_max: float) -> void:
	var img = Image.new()
	if img.load(src) != OK: return
	img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	for y in range(h):
		for x in range(w):
			var col = img.get_pixel(x, y)
			var min_rgb = minf(col.r, minf(col.g, col.b))
			if min_rgb >= t_max:
				col.a = 0.0
			elif min_rgb > t_min:
				col.a = 1.0 - (min_rgb - t_min) / (t_max - t_min)
			img.set_pixel(x, y, col)
	img.save_png(dst)
	print("Saved: ", dst)

func crop_fishes(src: String, out_dir: String) -> void:
	var img = Image.new()
	if img.load(src) != OK: return
	var w = img.get_width()
	var h = img.get_height()
	
	var regions = {
		"yamame": Rect2i(0, 0, w / 2, h / 2),
		"koi": Rect2i(w / 2, 0, w / 2, h / 2),
		"catfish": Rect2i(0, h / 2, w / 2, h / 2),
		"funa": Rect2i(w / 2, h / 2, w / 2, h / 2)
	}
	
	for name in regions:
		var r = regions[name]
		var min_x = r.end.x
		var max_x = r.position.x
		var min_y = r.end.y
		var max_y = r.position.y
		var found = false
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if img.get_pixel(x, y).a > 0.05:
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
					min_y = mini(min_y, y)
					max_y = maxi(max_y, y)
					found = true
		if found and max_x > min_x and max_y > min_y:
			var crop_rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
			var sub_img = img.get_region(crop_rect)
			var out_path = out_dir + "hd2d_fish_" + name + ".png"
			sub_img.save_png(out_path)
			print("Cropped HD-2D fish: ", out_path)
