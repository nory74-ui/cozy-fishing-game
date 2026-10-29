@tool
extends SceneTree

# 小屋の画像の外周水色エッジをアルファフェードして海面と完全シームレス化

func _init() -> void:
	var path = "/Users/nryktnk/.gemini/antigravity/scratch/cozy-fishing-game/assets/beach_shack.png"
	var img = Image.new()
	if img.load(path) != OK:
		quit()
		return
		
	img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	var center = Vector2(w * 0.48, h * 0.48)
	var max_r = float(w) * 0.47
	
	for y in range(h):
		for x in range(w):
			var col = img.get_pixel(x, y)
			if col.a > 0.0:
				var dist = (Vector2(x, y) - center).length()
				# 外周に近い部分の水色背景（r < 0.7, g > 0.7, b > 0.7）をフェードアウト
				var is_water_color = (col.g > 0.65 and col.b > 0.65 and col.r < 0.65)
				if is_water_color:
					# 外周フェード
					var edge_dist = dist / max_r
					if edge_dist > 0.65:
						var fade = clampf((edge_dist - 0.65) / 0.28, 0.0, 1.0)
						col.a *= (1.0 - fade)
				img.set_pixel(x, y, col)
				
	img.save_png(path)
	print("Beach shack edge faded successfully!")
	quit()
