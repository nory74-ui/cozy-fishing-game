extends Node2D

# 川の浅瀬・飛び石エリア（🥾 ゴム長靴ギミック）

signal shallow_entered(has_boots: bool)

@export var player_node: Node2D = null

var is_player_in_zone: bool = false
var time_counter: float = 0.0

# 飛び石の座標
var stones: Array[Vector2] = [
	Vector2(480, 1200),
	Vector2(440, 1205),
	Vector2(400, 1195),
	Vector2(360, 1200)
]

@onready var barrier_body: StaticBody2D = $BarrierBody
@onready var trigger_area: Area2D = $TriggerArea
@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_area_body_entered)
		trigger_area.body_exited.connect(_on_trigger_area_body_exited)
		for child in trigger_area.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				child.shape.size = Vector2(280, 110)
	GameData.tool_unlocked.connect(_on_tool_unlocked)
	_update_barrier_state()

func _process(delta: float) -> void:
	time_counter += delta
	if is_player_in_zone and prompt_label and prompt_label.visible:
		prompt_label.position.y = 1135.0 + sin(time_counter * 4.0) * 3.0
	queue_redraw()

func _update_barrier_state() -> void:
	# 長靴を持っていればバリアコリジョンを無効化（通過可能）
	var can_cross = GameData.has_boots
	if barrier_body:
		for col in barrier_body.get_children():
			if col is CollisionShape2D:
				col.set_deferred("disabled", can_cross)

func _on_tool_unlocked(tool_id: String) -> void:
	if tool_id == "boots":
		_update_barrier_state()
		if prompt_label:
			prompt_label.text = "🥾 ゴム長靴で浅瀬をジャブジャブ渡れる！"

func _on_trigger_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_in_zone = true
		if prompt_label:
			prompt_label.visible = true
			if GameData.has_boots:
				prompt_label.text = "🥾 浅瀬：ジャブジャブ渡れる！"
			else:
				prompt_label.text = "💦 浅瀬：長靴があれば渡れそうだ..."
		shallow_entered.emit(GameData.has_boots)

func _on_trigger_area_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_in_zone = false
		if prompt_label:
			prompt_label.visible = false

func _draw() -> void:
	# 飛び石の描画（水彩の平たい丸石たち）
	for i in range(stones.size()):
		var sp = stones[i]
		# 水中の影
		draw_ellipse(sp + Vector2(2, 4), 18.0, 12.0, Color(0.2, 0.35, 0.45, 0.4))
		# 石本体（薄い茶褐色〜グレーの水彩石）
		var stone_col = Color(0.78, 0.74, 0.68) if i % 2 == 0 else Color(0.72, 0.70, 0.65)
		draw_ellipse(sp, 16.0, 11.0, stone_col)
		draw_ellipse(sp, 16.0, 11.0, Color(0.5, 0.45, 0.40), false, 1.5)
		# 苔のアクセント
		draw_arc(sp - Vector2(3, 2), 6.0, 0.5, 2.8, 8, Color(0.45, 0.62, 0.42, 0.75), 2.0)
		
		# 水しぶき・白波（長靴がある時は活発に揺らめく）
		var wave_phase = time_counter * 3.0 + i * 1.2
		var wave_r = 17.0 + sin(wave_phase) * 2.5
		draw_arc(sp, wave_r, 0, TAU, 16, Color(1, 1, 1, 0.45), 1.2)
