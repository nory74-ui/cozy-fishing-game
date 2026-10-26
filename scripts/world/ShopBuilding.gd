extends Node2D

# 水辺のよろず屋（ショップ小屋オブジェクト）

signal shop_interacted()

var is_player_nearby: bool = false
var time_counter: float = 0.0

@onready var prompt_label: Label = $PromptLabel
@onready var interaction_area: Area2D = $Area2D

func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	time_counter += delta
	if is_player_nearby and prompt_label:
		# フキダシのやさしい上下浮遊
		prompt_label.position.y = -85.0 + sin(time_counter * 4.0) * 3.0

func _unhandled_input(event: InputEvent) -> void:
	if is_player_nearby:
		var main_node = get_parent()
		if main_node and "current_state" in main_node and main_node.current_state != 0: # State.IDLE 以外は開かない
			return
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_E):
			shop_interacted.emit()
			get_viewport().set_input_as_handled()

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_nearby = true
		if prompt_label:
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_nearby = false
		if prompt_label:
			prompt_label.visible = false

func _draw() -> void:
	# 1. 小屋の影
	draw_ellipse(Vector2(0, 35), 55.0, 20.0, Color(0.12, 0.18, 0.22, 0.35))
	
	# 2. 木造の壁
	var wall_rect = Rect2(-45, -20, 90, 50)
	draw_rect(wall_rect, Color("#dda15e"), true) # 木壁
	draw_rect(wall_rect, Color("#99582a"), false, 2.0)
	# 板のすじ
	for px in [-25, -5, 15, 35]:
		draw_line(Vector2(px, -20), Vector2(px, 30), Color("#bc6c25", 0.6), 1.5)

	# 3. カウンター窓口
	draw_rect(Rect2(-25, 0, 50, 25), Color("#ffe8d6"), true) # 店内明かり
	draw_rect(Rect2(-25, 0, 50, 25), Color("#6b4226"), false, 2.0)
	# カウンター天板
	draw_rect(Rect2(-28, 18, 56, 8), Color("#6f4e37"), true)
	# のれん（赤と白のストライプ）
	for i in range(5):
		var nx = -25 + i * 10
		var ncol = Color("#e76f51") if i % 2 == 0 else Color("#f4f1de")
		draw_rect(Rect2(nx, 0, 10, 8), ncol, true)

	# 4. 三角屋根（水彩の赤屋根）
	var roof_pts: PackedVector2Array = [
		Vector2(0, -55),   # 屋根の頂上
		Vector2(55, -15),  # 右下
		Vector2(-55, -15)  # 左下
	]
	draw_colored_polygon(roof_pts, Color("#d62828")) # 明るい赤
	draw_polyline([Vector2(-58, -14), Vector2(0, -56), Vector2(58, -14)], Color("#780000"), 3.0)

	# 5. 看板（魚のマーク）
	var sign_pos = Vector2(0, -32)
	draw_circle(sign_pos, 11.0, Color("#faedcd"))
	draw_circle(sign_pos, 11.0, Color("#6f4e37"), false, 1.5)
	# 魚マーク
	draw_circle(sign_pos, 4.0, Color("#2a6f97"))
	draw_colored_polygon([
		sign_pos - Vector2(2, 0),
		sign_pos - Vector2(7, -3),
		sign_pos - Vector2(7, 3)
	], Color("#2a6f97"))
