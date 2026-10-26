@tool
extends SceneTree

func _init() -> void:
	var img = Image.new()
	var err = img.load("/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/watercolor_fishes.png")
	if err != OK:
		print("Failed to load fishes image")
		quit()
		return
		
	var w = img.get_width()
	var h = img.get_height()
	
	# 4分割領域（左上、右上、左下、右下）
	var regions = {
		"yamame": Rect2i(0, 0, w / 2, h / 2),
		"koi": Rect2i(w / 2, 0, w / 2, h / 2),
		"catfish": Rect2i(0, h / 2, w / 2, h / 2),
		"funa": Rect2i(w / 2, h / 2, w / 2, h / 2)
	}
	
	for name in regions:
		var r = regions[name]
		# コンポーネントのタイトな境界を探索
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
			var out_path = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/fish_" + name + ".png"
			sub_img.save_png(out_path)
			print("Cropped: ", out_path, " size: ", crop_rect.size)
			
	print("Fishes cropped successfully!")
	quit()
