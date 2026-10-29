@tool
extends SceneTree

# 釣り小屋本体（建物・屋根・オーニング・壁・木箱・樽）のみを綺麗にクロップ＆透過

func _init() -> void:
	print("Refining beach_shack_building...")
	var brain_dir = "/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/"
	var assets_dir = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/"

	var img = Image.new()
	img.load(brain_dir + "beach_shack_1793277312735.jpg")
	img.convert(Image.FORMAT_RGBA8)

	var w = img.get_width()
	# デッキ床（手摺）の高さまで（支柱より上）: y=0〜590
	var h = 590

	var crop = Image.create(w, h, false, Image.FORMAT_RGBA8)
	crop.blit_rect(img, Rect2i(0, 0, w, h), Vector2i.ZERO)

	for y in range(h):
		for x in range(w):
			var col = crop.get_pixel(x, y)
			var min_rgb = minf(col.r, minf(col.g, col.b))
			if min_rgb >= 0.96:
				col.a = 0.0
			elif min_rgb > 0.88:
				var t = (min_rgb - 0.88) / (0.96 - 0.88)
				col.a = 1.0 - t
			# 下端 (y: 540〜590) を滑らかにフェード
			if y > 540:
				var fade = 1.0 - float(y - 540) / 50.0
				col.a *= fade
			crop.set_pixel(x, y, col)

	var used = crop.get_used_rect()
	var pad = 6
	var final_crop = Rect2i(
		maxi(0, used.position.x - pad),
		maxi(0, used.position.y - pad),
		mini(w - used.position.x, used.size.x + pad * 2),
		mini(h - used.position.y, used.size.y + pad * 2)
	)
	var result = Image.create(final_crop.size.x, final_crop.size.y, false, Image.FORMAT_RGBA8)
	result.blit_rect(crop, final_crop, Vector2i.ZERO)
	result.save_png(assets_dir + "beach_shack_building.png")
	print("Saved refined beach_shack_building.png: ", result.get_size(), " used: ", used)
	quit()
