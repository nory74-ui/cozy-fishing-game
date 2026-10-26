@tool
extends SceneTree

func _init() -> void:
	print("Correctly cropping 4 fishes vertically...")
	var assets_dir = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/"
	var img = Image.new()
	if img.load(assets_dir + "hd2d_fishes.png") != OK:
		print("Failed to load hd2d_fishes.png")
		quit()
		return
		
	var w = img.get_width()
	var h = img.get_height()
	
	# 横に4列並んでいる
	var col_w = w / 4
	var fish_names = ["yamame", "koi", "catfish", "funa"]
	
	for i in range(4):
		var name = fish_names[i]
		var start_x = i * col_w
		var end_x = (i + 1) * col_w
		
		var min_x = end_x
		var max_x = start_x
		var min_y = h
		var max_y = 0
		var found = false
		
		for y in range(h):
			for x in range(start_x, end_x):
				if img.get_pixel(x, y).a > 0.05:
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
					min_y = mini(min_y, y)
					max_y = maxi(max_y, y)
					found = true
					
		if found and max_x > min_x and max_y > min_y:
			# 余裕を持たせたクロップ
			var pad = 4
			min_x = maxi(0, min_x - pad)
			min_y = maxi(0, min_y - pad)
			max_x = mini(w - 1, max_x + pad)
			max_y = mini(h - 1, max_y + pad)
			
			var crop_rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
			var sub_img = img.get_region(crop_rect)
			
			# ここで右向き（頭が右）になるよう90度時計回りに回転させておく！
			# そうすると Godot で rotation = swim_direction.angle() だけで完璧に一致する！
			var rotated_img = Image.create(sub_img.get_height(), sub_img.get_width(), false, Image.FORMAT_RGBA8)
			var sw = sub_img.get_width()
			var sh = sub_img.get_height()
			for sy in range(sh):
				for sx in range(sw):
					# 90度時計回り: new_x = sh - 1 - sy, new_y = sx
					var rx = sh - 1 - sy
					var ry = sx
					rotated_img.set_pixel(rx, ry, sub_img.get_pixel(sx, sy))
					
			var out_path = assets_dir + "hd2d_fish_" + name + ".png"
			rotated_img.save_png(out_path)
			print("Cropped & Rotated (facing RIGHT): ", out_path, " size: ", rotated_img.get_size())
			
	print("All fishes correctly cropped and saved!")
	quit()
