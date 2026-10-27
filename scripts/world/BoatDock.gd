extends Node2D

# 手漕ぎボート乗り場＆孤島移動システム（⛵ 手漕ぎボート）

signal boat_ride_started()
signal boat_ride_finished(at_island: bool)

@export var player_node: CharacterBody2D = null

# 岸側の桟橋と孤島側の桟橋の座標
var dock_shore_pos: Vector2 = Vector2(1840, 800)
var dock_island_pos: Vector2 = Vector2(1540, 800)

var is_player_near_shore: bool = false
var is_player_near_island: bool = false
var time_counter: float = 0.0

# 乗船アニメーション
var is_riding: bool = false
var ride_progress: float = 0.0
var ride_start_pos: Vector2 = Vector2.ZERO
var ride_end_pos: Vector2 = Vector2.ZERO
var heading_to_island: bool = true

@onready var shore_area: Area2D = $ShoreArea
@onready var island_area: Area2D = $IslandArea
@onready var prompt_label_shore: Label = $PromptLabelShore
@onready var prompt_label_island: Label = $PromptLabelIsland

func _ready() -> void:
	if prompt_label_shore: prompt_label_shore.visible = false
	if prompt_label_island: prompt_label_island.visible = false
	if shore_area:
		shore_area.body_entered.connect(_on_shore_area_body_entered)
		shore_area.body_exited.connect(_on_shore_area_body_exited)
	if island_area:
		island_area.body_entered.connect(_on_island_area_body_entered)
		island_area.body_exited.connect(_on_island_area_body_exited)

func _process(delta: float) -> void:
	time_counter += delta
	
	if is_riding:
		ride_progress += delta * 0.45 # 約2.2秒で移動
		var t = clampf(ride_progress, 0.0, 1.0)
		# イージング（滑らかな加減速）
		var smooth_t = sin(t * PI * 0.5)
		var cur_pos = ride_start_pos.lerp(ride_end_pos, smooth_t)
		# 湖面の揺れを加える
		cur_pos.y += sin(time_counter * 6.0) * 4.0
		
		if player_node:
			player_node.global_position = cur_pos
			
		queue_redraw()
		
		if ride_progress >= 1.0:
			_finish_ride()
		return

	if prompt_label_shore and prompt_label_shore.visible:
		prompt_label_shore.position.y = 740.0 + sin(time_counter * 4.0) * 3.0
	if prompt_label_island and prompt_label_island.visible:
		prompt_label_island.position.y = 740.0 + sin(time_counter * 4.0) * 3.0
		
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if is_riding: return
	
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_E):
		if is_player_near_shore:
			if GameData.has_boat:
				_start_ride(true)
				get_viewport().set_input_as_handled()
			else:
				if prompt_label_shore:
					prompt_label_shore.text = "【ボート乗り場】ショップでボートを買えば孤島へ渡れそうだ..."
		elif is_player_near_island:
			_start_ride(false)
			get_viewport().set_input_as_handled()

func _start_ride(to_island: bool) -> void:
	is_riding = true
	ride_progress = 0.0
	heading_to_island = to_island
	SoundManager.play_sfx("cast", 0.08)
	
	if to_island:
		ride_start_pos = dock_shore_pos
		ride_end_pos = dock_island_pos
	else:
		ride_start_pos = dock_island_pos
		ride_end_pos = dock_shore_pos
		
	if player_node:
		if player_node.has_method("stop_fishing"):
			player_node.stop_fishing()
		player_node.set_physics_process(false)
		
	if prompt_label_shore: prompt_label_shore.visible = false
	if prompt_label_island: prompt_label_island.visible = false
	boat_ride_started.emit()

func _finish_ride() -> void:
	is_riding = false
	GameData.is_on_island = heading_to_island
	GameData.save_game()
	SoundManager.play_sfx("cast", 0.12, -3.0)
	
	if player_node:
		player_node.global_position = ride_end_pos
		player_node.last_safe_pos = ride_end_pos
		player_node.set_physics_process(true)
		
	if heading_to_island and is_player_near_island and prompt_label_island:
		prompt_label_island.visible = true
	elif not heading_to_island and is_player_near_shore and prompt_label_shore:
		prompt_label_shore.visible = true
		
	boat_ride_finished.emit(heading_to_island)

func _on_shore_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not is_riding:
		is_player_near_shore = true
		if prompt_label_shore:
			prompt_label_shore.visible = true
			if GameData.has_boat:
				prompt_label_shore.text = "【ボート乗り場】[E] 手漕ぎボートで孤島へ渡る"
			else:
				prompt_label_shore.text = "【ボート乗り場】ボートがあれば渡れる"

func _on_shore_area_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_near_shore = false
		if prompt_label_shore:
			prompt_label_shore.visible = false

func _on_island_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not is_riding:
		is_player_near_island = true
		if prompt_label_island:
			prompt_label_island.visible = true
			prompt_label_island.text = "【ボート乗り場】[E] 手漕ぎボートで岸へ戻る"

func _on_island_area_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		is_player_near_island = false
		if prompt_label_island:
			prompt_label_island.visible = false

func _draw() -> void:
	# 1. 岸側のボート係留杭
	var post_pos = dock_shore_pos + Vector2(10, -25)
	draw_circle(post_pos, 5.0, Color("#5e3012"))
	draw_circle(post_pos, 2.5, Color("#d4a373"))
	
	# 2. 係留ロープ
	var b_pos = dock_shore_pos + Vector2(-15, 0) if not is_riding else (player_node.global_position if player_node else dock_shore_pos)
	if not is_riding:
		draw_line(post_pos, b_pos + Vector2(10, 0), Color("#d4a373", 0.7), 2.0)

	# 3. 手漕ぎボートの描画（木製の小舟）
	var boat_center = b_pos
	if is_riding and player_node:
		boat_center = player_node.global_position + Vector2(0, 16)
	elif GameData.is_on_island:
		boat_center = dock_island_pos + Vector2(15, 0)
		
	# 水中の影
	draw_ellipse(boat_center + Vector2(0, 4), 32.0, 14.0, Color(0.1, 0.2, 0.3, 0.35))
	
	# ボートの船体（水彩ウッド）
	var hull_pts: PackedVector2Array = [
		boat_center + Vector2(-28, 0),
		boat_center + Vector2(-18, -12),
		boat_center + Vector2(18, -12),
		boat_center + Vector2(28, 0),
		boat_center + Vector2(18, 12),
		boat_center + Vector2(-18, 12)
	]
	draw_colored_polygon(hull_pts, Color("#dda15e"))
	draw_polyline(hull_pts, Color("#6b4226"), 2.2)
	# 船内のくぼみ
	draw_ellipse(boat_center, 18.0, 7.0, Color("#bc6c25"))
	# オール（木製の櫂）
	var oar_angle = sin(time_counter * 5.0) * 0.25 if is_riding else 0.1
	draw_line(boat_center + Vector2(-4, -6), boat_center + Vector2(-16, -18).rotated(oar_angle), Color("#5e3012"), 2.5)
	draw_line(boat_center + Vector2(-4, 6), boat_center + Vector2(-16, 18).rotated(-oar_angle), Color("#5e3012"), 2.5)
