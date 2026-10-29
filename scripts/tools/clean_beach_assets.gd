@tool
extends SceneTree

# 美麗アセットのフラッドフィル透過＆最適トリミングスクリプト

func _init() -> void:
	print("Cleaning and cropping beach assets...")
	var brain_dir = "/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/"
	var assets_dir = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/"

	# 1. ヤシの木 (palm_tree.png)
	clean_white_bg(brain_dir + "palm_tree_1793277330888.jpg", assets_dir + "palm_tree_hd.png", 0.90, 0.97)

	# 2. サンゴ海草 (coral_seaweed.png)
	clean_white_bg(brain_dir + "coral_seaweed_1793277347235.jpg", assets_dir + "coral_seaweed_hd.png", 0.90, 0.97)

	print("Done cleaning beach assets!")
	quit()

func clean_white_bg(src_path: String, dst_path: String, thresh_min: float, thresh_max: float) -> void:
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

	var used = img.get_used_rect()
	print(src_path.get_file(), " used rect: ", used)
	var pad = 8
	var crop_rect = Rect2i(
		maxi(0, used.position.x - pad),
		maxi(0, used.position.y - pad),
		mini(w - used.position.x, used.size.x + pad * 2),
		mini(h - used.position.y, used.size.y + pad * 2)
	)
	var cropped = Image.create(crop_rect.size.x, crop_rect.size.y, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(img, crop_rect, Vector2i.ZERO)
	cropped.save_png(dst_path)
	print("Saved clean HD asset: ", dst_path, " size: ", cropped.get_size())
