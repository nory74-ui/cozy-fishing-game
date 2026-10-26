extends Node2D

# 桟橋で釣りをしているキャラクター

var rod_angle: float = -35.0 # 通常時の竿の角度
var target_rod_angle: float = -35.0
var rod_bend: float = 0.0 # 竿のしなり具合

var char_pos: Vector2 = Vector2(230, 310)

func _process(delta: float) -> void:
	rod_angle = lerp(rod_angle, target_rod_angle, delta * 8.0)
	queue_redraw()

func set_pose(state: String) -> void:
	match state:
		"IDLE":
			target_rod_angle = -35.0
			rod_bend = 0.0
		"CASTING":
			target_rod_angle = -65.0
			rod_bend = 5.0
		"WAITING":
			target_rod_angle = -28.0
			rod_bend = 2.0
		"NIBBLE":
			target_rod_angle = -20.0
			rod_bend = 8.0
		"REELING":
			target_rod_angle = -45.0
			rod_bend = 25.0
		"CAUGHT":
			target_rod_angle = -60.0
			rod_bend = -5.0

func get_rod_tip_position() -> Vector2:
	var rad = deg_to_rad(rod_angle)
	var length = 110.0
	var base_tip = char_pos + Vector2(cos(rad) * length, sin(rad) * length - 20)
	# しなりを加味
	base_tip.y += rod_bend * 0.8
	return base_tip

func _draw() -> void:
	# 1. 影
	draw_ellipse(char_pos + Vector2(0, 30), 28, 8, Color(0, 0, 0, 0.2))
	
	# 2. 体（青いオーバーオール）
	var body_color = Color("3a86ff")
	var body_rect = Rect2(char_pos.x - 14, char_pos.y - 10, 28, 38)
	draw_rect(body_rect, body_color, true)
	
	# 3. 足（桟橋からぶら下がっている）
	draw_rect(Rect2(char_pos.x + 4, char_pos.y + 25, 12, 22), Color("26547c"), true)
	draw_circle(char_pos + Vector2(10, 48), 6, Color("4a4e69"))
	
	# 4. 頭（肌色）
	var head_pos = char_pos + Vector2(0, -25)
	draw_circle(head_pos, 15, Color("ffd166"))
	
	# 5. 麦わら帽子
	var hat_color = Color("e9c46a")
	var hat_band = Color("e76f51")
	draw_ellipse(head_pos + Vector2(0, -6), 25, 6, hat_color) # つば
	draw_rect(Rect2(head_pos.x - 12, head_pos.y - 20, 24, 14), hat_color, true) # 山
	draw_rect(Rect2(head_pos.x - 12, head_pos.y - 8, 24, 3), hat_band, true) # リボン
	
	# 6. 釣り竿
	var rod_data = GameData.RODS.get(GameData.current_rod, GameData.RODS["branch_rod"])
	var rod_color = Color("c08552")
	if rod_data.id == "bamboo_rod":
		rod_color = Color("588157")
	elif rod_data.id == "carbon_rod":
		rod_color = Color("343a40")
	elif rod_data.id == "master_rod":
		rod_color = Color("9d4edd")
		
	var handle_pos = char_pos + Vector2(10, 0)
	var tip_pos = get_rod_tip_position()
	
	# 竿の曲線（しなり）を描画
	var mid_pos = (handle_pos + tip_pos) * 0.5 + Vector2(0, rod_bend * 0.5)
	draw_line(handle_pos, mid_pos, rod_color, 4.0)
	draw_line(mid_pos, tip_pos, rod_color, 2.5)
	
	# リール
	draw_circle(handle_pos + Vector2(6, 4), 5, Color("495057"))
	draw_circle(handle_pos + Vector2(6, 4), 3, Color("f8f9fa"))
	
	# 7. 手
	draw_circle(handle_pos, 6, Color("ffd166"))
