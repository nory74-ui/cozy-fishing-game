@tool
extends SceneTree

# 南国ビーチアセットの透過PNG変換＆切り出しスクリプト

func _init() -> void:
	print("Processing beach assets...")
	var brain_dir = "/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/"
	var assets_dir = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/"
	
	# 1. 生成アセットの透過変換
	process_white_transparent(brain_dir + "beach_shack_1793277312735.jpg", assets_dir + "beach_shack.png", 0.94, 0.985)
	process_white_transparent(brain_dir + "palm_tree_1793277330888.jpg", assets_dir + "palm_tree.png", 0.94, 0.985)
	process_white_transparent(brain_dir + "coral_seaweed_1793277347235.jpg", assets_dir + "coral_seaweed.png", 0.94, 0.985)
	process_white_transparent(brain_dir + "mussel_bait_1793277365438.jpg", assets_dir + "mussel_bait.png", 0.94, 0.985)
	
	# 2. 動画の宝箱アイコンの抽出と透過
	extract_and_process_chest(brain_dir + "ui_bottom_right.png", assets_dir + "chest_icon.png")
	
	print("All beach assets processed successfully!")
	quit()

func process_white_transparent(src_path: String, dst_path: String, thresh_min: float, thresh_max: float) -> void:
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
			var min_rgb = minf(col.r, minf(col.g, col.b))
			
			if min_rgb >= thresh_max:
				col.a = 0.0
			elif min_rgb > thresh_min:
				var t = (min_rgb - thresh_min) / (thresh_max - thresh_min)
				col.a = 1.0 - t
			img.set_pixel(x, y, col)
			
	img.save_png(dst_path)
	print("Saved: ", dst_path)

func extract_and_process_chest(src_path: String, dst_path: String) -> void:
	var img = Image.new()
	var err = img.load(src_path)
	if err != OK:
		print("Failed to load chest src: ", src_path)
		return
	img.convert(Image.FORMAT_RGBA8)
	
	# ui_bottom_right.png (150x100) から宝箱の円形枠部分 (約 x: 92〜140, y: 35〜90) をクロップ
	var crop_rect = Rect2i(90, 35, 52, 55)
	var cropped = Image.create(crop_rect.size.x, crop_rect.size.y, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(img, crop_rect, Vector2i.ZERO)
	
	# 背景の海（青緑）を透過処理
	for y in range(cropped.get_height()):
		for x in range(cropped.get_width()):
			var col = cropped.get_pixel(x, y)
			# 円の外側（青緑色）を透明化
			var dist = (Vector2(x, y) - Vector2(26, 28)).length()
			if dist > 25.0:
				col.a = 0.0
			elif dist > 23.5:
				col.a = 1.0 - (dist - 23.5) / 1.5
			cropped.set_pixel(x, y, col)
			
	cropped.save_png(dst_path)
	print("Saved chest icon: ", dst_path)
