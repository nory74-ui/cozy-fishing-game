@tool
extends SceneTree

func _init() -> void:
	print("Converting watercolor images to transparent PNGs...")
	var assets_dir = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/"
	
	process_image(assets_dir + "watercolor_fisherman.jpg", assets_dir + "watercolor_fisherman.png", 0.92, 0.97)
	process_image(assets_dir + "watercolor_tree.jpg", assets_dir + "watercolor_tree.png", 0.90, 0.96)
	process_image(assets_dir + "watercolor_fishes.jpg", assets_dir + "watercolor_fishes.png", 0.92, 0.97)
	
	print("All images converted successfully!")
	quit()

func process_image(src_path: String, dst_path: String, thresh_min: float, thresh_max: float) -> void:
	var img = Image.new()
	var err = img.load(src_path)
	if err != OK:
		print("Failed to load: ", src_path)
		return
		
	img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	
	for y in range(h):
		for x in range(w):
			var col = img.get_pixel(x, y)
			# 明度・白さの計算
			var brightness = (col.r + col.g + col.b) / 3.0
			var min_rgb = minf(col.r, minf(col.g, col.b))
			
			if min_rgb >= thresh_max:
				col.a = 0.0
			elif min_rgb > thresh_min:
				var t = (min_rgb - thresh_min) / (thresh_max - thresh_min)
				col.a = 1.0 - t
			img.set_pixel(x, y, col)
			
	img.save_png(dst_path)
	print("Saved transparent PNG: ", dst_path)
