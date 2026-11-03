extends CharacterBody2D

# キャプテン・バーロック（Captain Barlock: 155cm, 38歳 漁師）
# サファリハット（魚ワッペン）、青白ボーダーシャツ、首巻きタオル、星＆錨ベスト、魚ポシェット、茶パンツ＆ブーツ

signal cast_bobber(target_pos: Vector2)
signal retrieve_bobber()

@export var speed: float = 230.0
@export var cast_max_distance: float = 460.0

var is_fishing: bool = false
var bobber_in_water: bool = false

enum Direction { DOWN, UP, RIGHT, LEFT }
var current_dir: Direction = Direction.DOWN

var walk_time: float = 0.0
var step_sfx_timer: float = 0.0
var is_moving: bool = false
var rod_swing_anim: float = 0.0

var mouse_world_pos: Vector2 = Vector2.ZERO
var can_cast_at_mouse: bool = false
var last_safe_pos: Vector2 = Vector2(1650, 850)

@onready var map_field = get_parent().get_node_or_null("MapField")

# キャプテン・バーロック公式三面図テクスチャ
var tex_barlock_front: Texture2D = preload("res://assets/characters/captain_barlock_front.png")
var tex_barlock_side: Texture2D = preload("res://assets/characters/captain_barlock_side.png")
var tex_barlock_back: Texture2D = preload("res://assets/characters/captain_barlock_back.png")

func _ready() -> void:
	current_dir = Direction.LEFT # 海（左側）を向いて構える
	last_safe_pos = global_position

func get_perspective_scale(y_pos: float) -> float:
	# 奥（y ≈ 450, 防波堤奥・白灯台付近）: 0.65倍
	# 手前（y ≈ 1200, 手前サーフ・砂浜）: 1.18倍
	var t = clampf((y_pos - 450.0) / (1200.0 - 450.0), 0.0, 1.0)
	return lerpf(0.65, 1.18, t)

func _physics_process(delta: float) -> void:
	var p_scale = get_perspective_scale(global_position.y)
	scale = Vector2(p_scale, p_scale)
	
	var main_node = get_parent()
	var m_state = main_node.current_state if (main_node and "current_state" in main_node) else 0
	# REELING(4), RESULT(5), SHOP(6), BOOK(7) 中は移動しない
	if m_state >= 4:
		velocity = Vector2.ZERO
		is_moving = false
		queue_redraw()
		return
		
	var input_vec = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_vec.length() > 0:
		if is_fishing:
			stop_fishing()
			
		velocity = input_vec * speed
		walk_time += delta * 7.0 # おじさんのぽてぽて歩行テンポ
		is_moving = true
		
		step_sfx_timer -= delta
		if step_sfx_timer <= 0.0:
			step_sfx_timer = 0.38 # ぽてぽて歩行に合わせた軽快な間隔
			SoundManager.play_sfx("step", 0.08, -7.0) # クリアに聞こえる心地よい足音
		
		# ドラクエ風4方向判定
		if abs(input_vec.x) > abs(input_vec.y):
			current_dir = Direction.RIGHT if input_vec.x > 0 else Direction.LEFT
		else:
			current_dir = Direction.DOWN if input_vec.y > 0 else Direction.UP
	else:
		velocity = Vector2.ZERO
		walk_time = 0.0
		step_sfx_timer = 0.08
		is_moving = false

	move_and_slide()
	_prevent_water_intrusion()

	if rod_swing_anim > 0.0:
		rod_swing_anim = maxf(0.0, rod_swing_anim - delta * 4.0)

	mouse_world_pos = get_global_mouse_position()
	var dist_to_mouse = global_position.distance_to(mouse_world_pos)
	
	if map_field and map_field.is_castable_water(mouse_world_pos) and dist_to_mouse <= cast_max_distance:
		can_cast_at_mouse = true
	else:
		can_cast_at_mouse = false

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var main_node = get_parent()
		var m_state = main_node.current_state if (main_node and "current_state" in main_node) else 0
		# 左クリック: キャストまたはウキ回収
		if event.button_index == MOUSE_BUTTON_LEFT:
			if m_state == 2 and is_fishing:
				stop_fishing()
				get_viewport().set_input_as_handled()
			elif m_state == 0 and can_cast_at_mouse:
				start_fishing(mouse_world_pos)
				get_viewport().set_input_as_handled()
		# 右クリック: ウキ回収（動画の「(右) 引く」ガイドに対応）
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if is_fishing:
				stop_fishing()
				get_viewport().set_input_as_handled()

func start_fishing(target: Vector2) -> void:
	is_fishing = true
	bobber_in_water = true
	rod_swing_anim = 1.0
	
	var dir_vec = target - global_position
	if abs(dir_vec.x) > abs(dir_vec.y):
		current_dir = Direction.RIGHT if dir_vec.x > 0 else Direction.LEFT
	else:
		current_dir = Direction.DOWN if dir_vec.y > 0 else Direction.UP
		
	cast_bobber.emit(target)

func stop_fishing() -> void:
	if is_fishing:
		is_fishing = false
		bobber_in_water = false
		retrieve_bobber.emit()

func reset_fishing_state() -> void:
	is_fishing = false
	bobber_in_water = false
	queue_redraw()

func _prevent_water_intrusion() -> void:
	if not map_field: return
	
	var cur_pos = global_position
	# プレイヤーの足元座標
	var foot_pos = cur_pos + Vector2(0, 10)
	
	var is_walkable = true
	if map_field.has_method("is_point_walkable"):
		is_walkable = map_field.is_point_walkable(foot_pos)
	elif map_field.has_method("is_in_water") and map_field.is_in_water(foot_pos):
		# 水域に入っている場合、桟橋の上、孤島の上、または長靴所持時の浅瀬なら歩行許可
		if (map_field.has_method("is_on_pier") and map_field.is_on_pier(foot_pos)) or (map_field.has_method("is_on_island") and map_field.is_on_island(foot_pos)):
			is_walkable = true
		elif GameData.has_boots and foot_pos.y >= map_field.shallow_y_min - 15.0 and foot_pos.y <= map_field.shallow_y_max + 15.0:
			is_walkable = true
		else:
			is_walkable = false # 水面への侵入禁止！
			
	if is_walkable:
		last_safe_pos = cur_pos
	else:
		# 安全な位置へ瞬時に押し戻す
		global_position = last_safe_pos
		velocity = Vector2.ZERO

func get_rod_tip_global_pos() -> Vector2:
	var swing = sin(rod_swing_anim * PI) * 16.0
	var offset: Vector2
	match current_dir:
		Direction.DOWN:
			offset = Vector2(14, 18 + swing)
		Direction.UP:
			offset = Vector2(16, -26 - swing)
		Direction.RIGHT:
			offset = Vector2(28 + swing, 4)
		Direction.LEFT:
			offset = Vector2(-28 - swing, 4)
	return global_position + offset

func _get_boot_color() -> Color:
	if GameData.has_boots:
		return Color("#2d6a4f") # 深いフォレストグリーンのゴム長靴
	return Color("#582f0e")     # 初期革靴

func _draw() -> void:
	# 1. 地面の立体影（動画完全一致：右斜め後ろへ落ちるリアルなソフトシャドウ）
	var shadow_poly = PackedVector2Array([
		Vector2(-10, 16),
		Vector2(12, 16),
		Vector2(32, 6),
		Vector2(16, 4)
	])
	draw_colored_polygon(shadow_poly, Color(0.12, 0.16, 0.18, 0.35))
	draw_ellipse(Vector2(2, 16), 16.0, 7.0, Color(0.12, 0.16, 0.18, 0.28))

	# 浅瀬を歩行中の水しぶきエフェクト
	if is_moving and map_field and map_field.is_in_water(global_position):
		var splash_phase = sin(walk_time * 2.5) * 4.0
		draw_arc(Vector2(0, 16), 12.0 + splash_phase, 0, TAU, 16, Color(1, 1, 1, 0.75), 1.8)
		draw_circle(Vector2(-9 + splash_phase, 14), 2.8, Color(0.9, 0.96, 1.0, 0.85))
		draw_circle(Vector2(9 - splash_phase, 14), 2.8, Color(0.9, 0.96, 1.0, 0.85))

	# 2. 歩行ステップ・ボブアニメーション
	var step = int(walk_time) % 4 if is_moving else 0
	var bob_y = -2.5 if (step == 1 or step == 3) else 0.0
	var tilt_deg = 0.0
	if is_moving:
		if step == 1:
			tilt_deg = 3.0
		elif step == 3:
			tilt_deg = -3.0

	# 3. キャプテン・バーロック公式スプライト描画
	match current_dir:
		Direction.DOWN:
			_draw_barlock_front(step, bob_y, tilt_deg)
		Direction.UP:
			_draw_barlock_back(step, bob_y, tilt_deg)
		Direction.RIGHT:
			_draw_barlock_side(step, bob_y, tilt_deg, false)
		Direction.LEFT:
			_draw_barlock_side(step, bob_y, tilt_deg, true)

	# 4. 照準マーカー
	if can_cast_at_mouse and not is_fishing:
		var target_local = to_local(mouse_world_pos)
		draw_circle(target_local, 16.0, Color(1, 1, 1, 0.25))
		draw_arc(target_local, 16.0, 0, TAU, 24, Color(0.95, 0.55, 0.4, 0.85), 2.2)
		draw_circle(target_local, 4.0, Color(1.0, 0.85, 0.3, 0.95))
		draw_line(Vector2.ZERO, target_local, Color(1, 1, 1, 0.45), 1.2)

# --- A. キャプテン・バーロック：下向き（正面） ---
func _draw_barlock_front(step: int, bob_y: float, tilt_deg: float) -> void:
	if tex_barlock_front:
		var w = 43.0
		var h = 66.0
		var dest_rect = Rect2(-w * 0.5, 16.0 - h + bob_y, w, h)
		
		if abs(tilt_deg) > 0.01:
			draw_set_transform(Vector2(0, 16), deg_to_rad(tilt_deg), Vector2.ONE)
			draw_texture_rect(tex_barlock_front, Rect2(-w * 0.5, -h + bob_y, w, h), false)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		else:
			draw_texture_rect(tex_barlock_front, dest_rect, false)
			
		# 釣り中なら手元から竿を斜め前に構える演出
		if is_fishing:
			var hand_pos = Vector2(10, 6 + bob_y)
			var rod_tip = get_rod_tip_global_pos() - global_position
			draw_line(hand_pos, rod_tip, Color("#7f5539"), 2.6)
			draw_line(hand_pos, rod_tip, Color("#ddb892"), 1.2)
			draw_circle(hand_pos, 2.5, Color("#495057"))
	else:
		_draw_fallback_ojisan_down(step, bob_y)

# --- B. キャプテン・バーロック：上向き（背面） ---
func _draw_barlock_back(step: int, bob_y: float, tilt_deg: float) -> void:
	if tex_barlock_back:
		var w = 43.0
		var h = 66.0
		var dest_rect = Rect2(-w * 0.5, 16.0 - h + bob_y, w, h)
		
		if abs(tilt_deg) > 0.01:
			draw_set_transform(Vector2(0, 16), deg_to_rad(tilt_deg), Vector2.ONE)
			draw_texture_rect(tex_barlock_back, Rect2(-w * 0.5, -h + bob_y, w, h), false)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		else:
			draw_texture_rect(tex_barlock_back, dest_rect, false)
			
		if is_fishing:
			var hand_pos = Vector2(10, 4 + bob_y)
			var rod_tip = get_rod_tip_global_pos() - global_position
			draw_line(hand_pos, rod_tip, Color("#7f5539"), 2.6)
			draw_line(hand_pos, rod_tip, Color("#ddb892"), 1.2)
	else:
		_draw_fallback_ojisan_up(step, bob_y)

# --- C. キャプテン・バーロック：左右向き（側面） ---
func _draw_barlock_side(step: int, bob_y: float, tilt_deg: float, flip: bool) -> void:
	if tex_barlock_side:
		var orig_w = 300.0
		var orig_h = 235.0
		var scale_factor = 66.0 / 250.0 # 高さ基準スケール
		var w = orig_w * scale_factor
		var h = orig_h * scale_factor
		var center_offset_x = 120.0 * scale_factor # 足元中心
		
		var sgn = -1.0 if flip else 1.0
		var final_tilt = tilt_deg * sgn
		
		draw_set_transform(Vector2(0, 16), deg_to_rad(final_tilt), Vector2(sgn, 1.0))
		draw_texture_rect(tex_barlock_side, Rect2(-center_offset_x, -h + bob_y, w, h), false)
		
		if is_fishing:
			var rod_tip = (get_rod_tip_global_pos() - global_position)
			rod_tip.x *= sgn
			var hand_pos = Vector2(12, -12 + bob_y)
			draw_line(hand_pos, rod_tip, Color("#7f5539"), 2.6)
			draw_line(hand_pos, rod_tip, Color("#ddb892"), 1.2)
			
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		_draw_fallback_ojisan_side(step, bob_y, flip)

# フォールバックベクター描画
func _draw_fallback_ojisan_down(step: int, bob_y: float) -> void:
	var boot_col = _get_boot_color()
	draw_rect(Rect2(-9, 13, 7, 5), boot_col, true)
	draw_rect(Rect2(2, 13, 7, 5), boot_col, true)

func _draw_fallback_ojisan_up(step: int, bob_y: float) -> void:
	var boot_col = _get_boot_color()
	draw_rect(Rect2(-9, 13, 7, 5), boot_col, true)
	draw_rect(Rect2(2, 13, 7, 5), boot_col, true)

func _draw_fallback_ojisan_side(step: int, bob_y: float, flip: bool) -> void:
	var boot_col = _get_boot_color()
	draw_rect(Rect2(-3.5, 13, 7, 5), boot_col, true)


