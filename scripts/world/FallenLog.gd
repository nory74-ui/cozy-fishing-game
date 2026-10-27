extends Node2D

# 秘密の渓谷へ続く倒木ギミック（🪓 木こりのオノ）

signal log_destroyed()

var is_player_nearby: bool = false
var time_counter: float = 0.0
var is_destroying: bool = false
var destroy_timer: float = 0.0
var chips: Array[Dictionary] = []

@onready var static_body: StaticBody2D = $StaticBody2D
@onready var interaction_area: Area2D = $Area2D
@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
		
	if GameData.is_log_cleared:
		visible = false
		if static_body:
			for col in static_body.get_children():
				if col is CollisionShape2D:
					col.disabled = true

func _process(delta: float) -> void:
	time_counter += delta
	
	if is_destroying:
		destroy_timer += delta
		for chip in chips:
			chip.pos += chip.vel * delta
			chip.vel.y += 280.0 * delta # 重力
			chip.rot += chip.vrot * delta
			chip.alpha = maxf(0.0, 1.0 - (destroy_timer / 0.8))
			
		queue_redraw()
		if destroy_timer >= 0.8:
			is_destroying = false
			visible = false
			GameData.is_log_cleared = true
			if static_body:
				for col in static_body.get_children():
					if col is CollisionShape2D:
						col.disabled = true
			log_destroyed.emit()
		return
		
	if is_player_nearby and prompt_label and prompt_label.visible:
		prompt_label.position.y = -55.0 + sin(time_counter * 4.0) * 3.0
		
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if is_player_nearby and not GameData.is_log_cleared and not is_destroying:
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_E):
			if GameData.has_axe:
				_start_destroy_effect()
				get_viewport().set_input_as_handled()
			else:
				if prompt_label:
					prompt_label.text = "【倒木】オノがあれば切り払えそうだ！"

func _start_destroy_effect() -> void:
	is_destroying = true
	destroy_timer = 0.0
	SoundManager.play_sfx("hit", 0.05, 2.0)
	if prompt_label:
		prompt_label.visible = false
		
	# 木片パーティクル生成
	chips.clear()
	for i in range(24):
		chips.append({
			"pos": Vector2(randf_range(-40, 40), randf_range(-15, 15)),
			"vel": Vector2(randf_range(-140, 140), randf_range(-220, -60)),
			"size": Vector2(randf_range(6, 14), randf_range(4, 9)),
			"rot": randf() * TAU,
			"vrot": randf_range(-8, 8),
			"color": Color("#8c562e") if randf() > 0.4 else Color("#6b4226"),
			"alpha": 1.0
		})

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not GameData.is_log_cleared and not is_destroying:
		is_player_nearby = true
		if prompt_label:
			prompt_label.visible = true
			if GameData.has_axe:
				prompt_label.text = "【倒木】[E] 木こりのオノで倒木を切り払う！"
			else:
				prompt_label.text = "【倒木】オノがあれば壊せそう"

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_nearby = false
		if prompt_label:
			prompt_label.visible = false

func _draw() -> void:
	if GameData.is_log_cleared and not is_destroying:
		return
		
	# 倒木の本体描画（苔むした水彩の丸太）
	if not is_destroying:
		# 影
		draw_ellipse(Vector2(0, 14), 56.0, 14.0, Color(0.15, 0.2, 0.15, 0.35))
		
		# 丸太の胴体（幅108px、谷間の岩壁にぴったり挟まる）
		var log_rect = Rect2(-54, -13, 108, 26)
		draw_rect(log_rect, Color("#8c562e"), true) # 茶色の樹皮
		draw_rect(log_rect, Color("#5e3012"), false, 2.0)
		
		# 木目ライン
		draw_line(Vector2(-42, -5), Vector2(42, -5), Color("#5e3012", 0.5), 1.5)
		draw_line(Vector2(-38, 4), Vector2(36, 4), Color("#5e3012", 0.5), 1.5)
		
		# 切り口の年輪（左端と右端）
		draw_ellipse(Vector2(-53, 0), 6.5, 12.0, Color("#d4a373"))
		draw_ellipse(Vector2(-53, 0), 6.5, 12.0, Color("#5e3012"), false, 1.2)
		draw_ellipse(Vector2(-53, 0), 3.2, 5.5, Color("#5e3012"), false, 1.0)
		
		# 苔とキノコの装飾
		draw_arc(Vector2(-15, -12), 14.0, 0.2, PI * 0.9, 14, Color("#52796f"), 3.5)
		draw_arc(Vector2(20, -11), 12.0, 0.3, PI * 0.8, 12, Color("#52796f"), 3.0)
		
		# 小さな赤いキノコ
		draw_circle(Vector2(5, -15), 4.5, Color("#e63946"))
		draw_circle(Vector2(5, -14), 1.5, Color.WHITE)
		draw_line(Vector2(5, -11), Vector2(5, -7), Color("#f1faee"), 2.0)
	else:
		# 破壊パーティクルの描画
		for chip in chips:
			var c = chip.color
			c.a = chip.alpha
			var sz = chip.size
			draw_set_transform(chip.pos, chip.rot, Vector2.ONE)
			draw_rect(Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y), c, true)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
