extends Node2D

# 釣り場の背景（空、山、水面、波紋、桟橋）をプロシージャルに美しく描画する

var time_passed: float = 0.0
var clouds: Array[Dictionary] = []

func _ready() -> void:
	# ランダムな雲を初期化
	for i in range(4):
		clouds.append({
			"pos": Vector2(randf_range(50, 1100), randf_range(40, 180)),
			"size": randf_range(40, 70),
			"speed": randf_range(5, 12)
		})
	
	GameData.spot_changed.connect(_on_spot_changed)

func _on_spot_changed(_spot_id: String) -> void:
	queue_redraw()

func _process(delta: float) -> void:
	time_passed += delta
	# 雲の移動
	for cloud in clouds:
		cloud["pos"].x += cloud["speed"] * delta
		if cloud["pos"].x > 1250:
			cloud["pos"].x = -100
			cloud["pos"].y = randf_range(40, 180)
	queue_redraw()

func _draw() -> void:
	var spot_data = GameData.SPOTS.get(GameData.current_spot, GameData.SPOTS["stream"])
	var sky_col: Color = spot_data.get("sky_color", Color("b5e2fa"))
	var mountain_col: Color = spot_data.get("mountain_color", Color("7fa99b"))
	var water_col: Color = spot_data.get("water_color", Color("5bc0be"))
	
	var screen_w = 1152.0
	var screen_h = 648.0
	var water_y = 350.0
	
	# 1. 空のグラデーション風描画
	draw_rect(Rect2(0, 0, screen_w, water_y), sky_col)
	# 空のやわらかいハイライト
	draw_rect(Rect2(0, 0, screen_w, water_y * 0.4), sky_col.lightened(0.15))
	
	# 2. 雲の描画
	for cloud in clouds:
		var c_pos: Vector2 = cloud["pos"]
		var r: float = cloud["size"]
		var c_color = Color(1, 1, 1, 0.65)
		draw_circle(c_pos, r, c_color)
		draw_circle(c_pos + Vector2(r * 0.7, 0), r * 0.8, c_color)
		draw_circle(c_pos - Vector2(r * 0.6, -r * 0.1), r * 0.7, c_color)
	
	# 3. 遠景の山並み
	var mountain_points: PackedVector2Array = [
		Vector2(0, water_y),
		Vector2(0, water_y - 120),
		Vector2(200, water_y - 220),
		Vector2(450, water_y - 140),
		Vector2(700, water_y - 250),
		Vector2(950, water_y - 170),
		Vector2(screen_w, water_y - 200),
		Vector2(screen_w, water_y)
	]
	draw_colored_polygon(mountain_points, mountain_col.darkened(0.15))
	
	# 手前のなだらかな丘
	var hill_points: PackedVector2Array = [
		Vector2(0, water_y),
		Vector2(100, water_y - 80),
		Vector2(380, water_y - 60),
		Vector2(650, water_y - 110),
		Vector2(900, water_y - 70),
		Vector2(screen_w, water_y - 90),
		Vector2(screen_w, water_y)
	]
	draw_colored_polygon(hill_points, mountain_col)
	
	# 4. 水面
	draw_rect(Rect2(0, water_y, screen_w, screen_h - water_y), water_col)
	# 水深のグラデーション
	draw_rect(Rect2(0, water_y + 120, screen_w, screen_h - water_y - 120), water_col.darkened(0.2))
	
	# 5. 水面の波線（ゆらゆら動く）
	var wave_col = water_col.lightened(0.25)
	wave_col.a = 0.5
	for row in range(5):
		var y = water_y + 30 + row * 50
		var offset = sin(time_passed * 1.5 + row) * 20.0
		for i in range(7):
			var x = 80 + i * 160 + offset
			draw_arc(Vector2(x, y), 25.0, PI * 0.85, PI * 0.15, 12, wave_col, 2.5)

	# 6. 左側の木製桟橋（ピア）
	var pier_color = Color("8c5e34")
	var pier_dark = Color("6b4226")
	# 桟橋の脚（水中）
	draw_rect(Rect2(120, water_y - 10, 20, 160), pier_dark)
	draw_rect(Rect2(240, water_y - 10, 20, 180), pier_dark)
	# 桟橋の天板
	var deck_points: PackedVector2Array = [
		Vector2(0, water_y - 10),
		Vector2(290, water_y - 10),
		Vector2(280, water_y + 25),
		Vector2(0, water_y + 25)
	]
	draw_colored_polygon(deck_points, pier_color)
	draw_line(Vector2(0, water_y + 25), Vector2(280, water_y + 25), pier_dark, 3.0)
	# 板の節目
	for px in range(40, 280, 40):
		draw_line(Vector2(px, water_y - 10), Vector2(px - 5, water_y + 25), pier_dark, 2.0)
