@tool
extends SceneTree

func _init() -> void:
	var brain_dir = "/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/"
	var assets_dir = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/"
	
	var src_img = Image.new()
	var err = src_img.load(brain_dir + "game_crops/crop_06.png")
	if err != OK:
		print("Failed to load crop_06")
		quit()
		return
	src_img.convert(Image.FORMAT_RGBA8)
		
	# 1. 白い岩 (約 x: 822, y: 196, w: 56, h: 50)
	var rock_rect = Rect2i(820, 196, 58, 52)
	var rock_img = Image.create(rock_rect.size.x, rock_rect.size.y, false, Image.FORMAT_RGBA8)
	rock_img.blit_rect(src_img, rock_rect, Vector2i.ZERO)
	# 砂浜色（ベージュ）を透明化
	for y in range(rock_img.get_height()):
		for x in range(rock_img.get_width()):
			var c = rock_img.get_pixel(x, y)
			# 砂浜色 (r > 0.85, g > 0.8, b > 0.65 かつ r > b + 0.15)
			if c.r > 0.82 and c.g > 0.75 and c.b < 0.75 and (c.r - c.b) > 0.12:
				c.a = 0.0
			rock_img.set_pixel(x, y, c)
	rock_img.save_png(assets_dir + "beach_rock.png")
	print("Saved beach_rock.png")
	
	# 2. カニ (約 x: 724, y: 76, w: 22, h: 22)
	var crab_rect = Rect2i(720, 74, 28, 26)
	var crab_img = Image.create(crab_rect.size.x, crab_rect.size.y, false, Image.FORMAT_RGBA8)
	crab_img.blit_rect(src_img, crab_rect, Vector2i.ZERO)
	for y in range(crab_img.get_height()):
		for x in range(crab_img.get_width()):
			var c = crab_img.get_pixel(x, y)
			if c.r > 0.80 and c.g > 0.72 and (c.r - c.b) > 0.1:
				c.a = 0.0
			crab_img.set_pixel(x, y, c)
	crab_img.save_png(assets_dir + "beach_crab.png")
	print("Saved beach_crab.png")
	
	quit()
