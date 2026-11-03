extends Node2D

# 三毛猫ミケ（Mike the Cat: 22cm, 2歳, 幸運の招き猫）
# キャプテン・バーロックの相棒。ミニサファリハット、首のバンダナ＆金の鈴、招き猫ポーズ

@export var follow_distance: float = 34.0
@export var follow_speed: float = 220.0

var player_node: Node2D = null

var tex_mike_front: Texture2D = preload("res://assets/characters/mike_cat_front.png")
var tex_mike_side: Texture2D = preload("res://assets/characters/mike_cat_side.png")
var tex_mike_back: Texture2D = preload("res://assets/characters/mike_cat_back.png")

enum CatState { IDLE, WALKING, SITTING, CHEERING }
var current_state: CatState = CatState.SITTING

enum CatDir { FRONT, BACK, RIGHT, LEFT }
var current_dir: CatDir = CatDir.FRONT

var walk_time: float = 0.0
var idle_anim_timer: float = 0.0
var meow_bubble_timer: float = 5.0
var show_bubble: bool = false
var bubble_text: String = "🐾"

func _ready() -> void:
	z_index = 4
	var p = get_parent().get_node_or_null("Player")
	if p:
		player_node = p
		global_position = player_node.global_position + Vector2(26, 4)

func get_perspective_scale(y_pos: float) -> float:
	var t = clampf((y_pos - 450.0) / (1200.0 - 450.0), 0.0, 1.0)
	return lerpf(0.65, 1.18, t)

func _process(delta: float) -> void:
	var c_scale = get_perspective_scale(global_position.y)
	scale = Vector2(c_scale, c_scale)

	if not player_node:
		var p = get_parent().get_node_or_null("Player")
		if p:
			player_node = p
		return

	# 吹き出しタイマー
	idle_anim_timer += delta
	meow_bubble_timer -= delta
	if meow_bubble_timer <= 0.0:
		meow_bubble_timer = randf_range(8.0, 16.0)
		show_bubble = true
		var bubbles = ["🐾", "🐟✨", "にゃ♪", "🌊"]
		bubble_text = bubbles[randi() % bubbles.size()]
		# 2.2秒後に吹き出し非表示
		get_tree().create_timer(2.2).timeout.connect(func(): show_bubble = false)

	# プレイヤーの釣り状態・位置に応じた追従AI
	var target_offset = Vector2(24, 6) # プレイヤーの右斜め後ろが定位置
	if player_node.get("current_dir") == 2: # RIGHT
		target_offset = Vector2(-22, 6)
	elif player_node.get("current_dir") == 3: # LEFT
		target_offset = Vector2(22, 6)

	var target_pos = player_node.global_position + target_offset
	var dist = global_position.distance_to(target_pos)
	var is_player_moving = player_node.get("is_moving") if player_node.has_method("is_moving") or "is_moving" in player_node else false
	var is_fishing = player_node.get("is_fishing") if "is_fishing" in player_node else false

	if dist > follow_distance or is_player_moving:
		# トコトコ追従歩行
		var dir_vec = (target_pos - global_position).normalized()
		var move_dist = minf(dist, follow_speed * delta * (1.3 if dist > 60.0 else 1.0))
		global_position += dir_vec * move_dist
		
		walk_time += delta * 8.0
		current_state = CatState.WALKING
		
		if abs(dir_vec.x) > abs(dir_vec.y):
			current_dir = CatDir.RIGHT if dir_vec.x > 0 else CatDir.LEFT
		else:
			current_dir = CatDir.FRONT if dir_vec.y > 0 else CatDir.BACK
	else:
		walk_time = 0.0
		if is_fishing:
			current_state = CatState.CHEERING # 釣り中は応援ポーズ
			current_dir = CatDir.FRONT
		else:
			current_state = CatState.SITTING
			current_dir = CatDir.FRONT

	queue_redraw()

func _draw() -> void:
	# 1. ミケの小さな影
	var shadow_offset = Vector2(1, 10)
	draw_ellipse(shadow_offset, 11.0, 5.5, Color(0.12, 0.16, 0.18, 0.28))

	# 2. アニメーション（歩行時のぽてぽてボブ）
	var bob_y = 0.0
	var tilt_deg = 0.0
	if current_state == CatState.WALKING:
		var step = int(walk_time) % 4
		bob_y = -2.0 if (step == 1 or step == 3) else 0.0
		tilt_deg = 4.0 if step == 1 else (-4.0 if step == 3 else 0.0)
	elif current_state == CatState.CHEERING:
		# 応援中：小さく呼吸するようにぷるぷる動く
		bob_y = sin(idle_anim_timer * 4.0) * 1.2

	# 3. ミケ公式スプライトの描画
	var scale_factor = 35.0 / 229.0 # 高さ基準

	match current_dir:
		CatDir.FRONT:
			if tex_mike_front:
				var m_w = 176.0 * scale_factor
				var m_h = 229.0 * scale_factor
				draw_set_transform(Vector2(0, 10), deg_to_rad(tilt_deg), Vector2.ONE)
				draw_texture_rect(tex_mike_front, Rect2(-m_w * 0.5, -m_h + bob_y, m_w, m_h), false)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		CatDir.BACK:
			if tex_mike_back:
				var m_w = 160.0 * scale_factor
				var m_h = 229.0 * scale_factor
				draw_set_transform(Vector2(0, 10), deg_to_rad(tilt_deg), Vector2.ONE)
				draw_texture_rect(tex_mike_back, Rect2(-m_w * 0.5, -m_h + bob_y, m_w, m_h), false)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		CatDir.RIGHT:
			if tex_mike_side:
				var m_w = 165.0 * scale_factor
				var m_h = 230.0 * scale_factor
				draw_set_transform(Vector2(0, 10), deg_to_rad(tilt_deg), Vector2.ONE)
				draw_texture_rect(tex_mike_side, Rect2(-m_w * 0.5, -m_h + bob_y, m_w, m_h), false)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		CatDir.LEFT:
			if tex_mike_side:
				var m_w = 165.0 * scale_factor
				var m_h = 230.0 * scale_factor
				draw_set_transform(Vector2(0, 10), deg_to_rad(-tilt_deg), Vector2(-1.0, 1.0))
				draw_texture_rect(tex_mike_side, Rect2(-m_w * 0.5, -m_h + bob_y, m_w, m_h), false)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# 4. かわいい「にゃん」吹き出し
	if show_bubble:
		var bub_pos = Vector2(10, -26 + bob_y)
		# 吹き出し背景（白い丸角・ポワンとした雲）
		draw_circle(bub_pos, 9.0, Color.WHITE)
		draw_circle(bub_pos + Vector2(6, 0), 7.0, Color.WHITE)
		draw_circle(bub_pos + Vector2(-6, 0), 7.0, Color.WHITE)
		draw_circle(bub_pos + Vector2(-4, 9), 3.0, Color.WHITE)
		draw_circle(bub_pos + Vector2(-7, 13), 1.8, Color.WHITE)
		# 文字
		var default_font = ThemeDB.fallback_font
		if default_font:
			draw_string(default_font, bub_pos + Vector2(-8, 4), bubble_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color("#333333"))
