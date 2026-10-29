@tool
extends SceneTree

func _init() -> void:
	print("Cropping fish_side_madai.png to tight bounding box...")
	var assets_dir = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/"
	var img = Image.new()
	var err = img.load(assets_dir + "fish_side_madai.png")
	if err == OK:
		var rect = img.get_used_rect()
		print("Original used_rect: ", rect)
		# パディングを少し持たせてクロップ
		var pad = 12
		var crop_rect = Rect2i(
			maxi(0, rect.position.x - pad),
			maxi(0, rect.position.y - pad),
			mini(img.get_width() - rect.position.x, rect.size.x + pad * 2),
			mini(img.get_height() - rect.position.y, rect.size.y + pad * 2)
		)
		var cropped = Image.create(crop_rect.size.x, crop_rect.size.y, false, Image.FORMAT_RGBA8)
		cropped.blit_rect(img, crop_rect, Vector2i.ZERO)
		cropped.save_png(assets_dir + "fish_side_madai.png")
		print("Saved cropped fish_side_madai.png: ", cropped.get_size())
	quit()
