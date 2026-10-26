extends CharacterBody2D

# デフォルメされたかわいいおじさん釣り人キャラクター
# （ぽっこりお腹、ふさふさ口ひげ、赤い丸鼻、バケットハット、サロペット、ドラクエ風4方向歩行アクション）

signal cast_bobber(target_pos: Vector2)
signal retrieve_bobber()

@export var speed: float = 175.0
@export var cast_max_distance: float = 340.0

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
var last_safe_pos: Vector2 = Vector2(950, 800)

@onready var map_field = get_parent().get_node_or_null("MapField")

func _ready() -> void:
	last_safe_pos = global_position

func _physics_process(delta: float) -> void:
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
			step_sfx_timer = 0.38
			SoundManager.play_sfx("step", 0.12, -9.0)
		
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var main_node = get_parent()
		var m_state = main_node.current_state if (main_node and "current_state" in main_node) else 0
		# State.IDLE (0) の時のみキャスト可能、State.WAITING (2) の時のみウキ回収可能
		# State.BITE (3) の時は Main._unhandled_input で「合わせ」を行うためここでは処理しない
		if m_state == 2 and is_fishing:
			stop_fishing()
			get_viewport().set_input_as_handled()
		elif m_state == 0 and can_cast_at_mouse:
			start_fishing(mouse_world_pos)
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
	if map_field.is_in_water(foot_pos):
		# 水域に入っている場合、桟橋の上、孤島の上、または長靴所持時の浅瀬なら歩行許可
		if map_field.is_on_pier(foot_pos) or map_field.is_on_island(foot_pos):
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
			offset = Vector2(16, 26 + swing)
		Direction.UP:
			offset = Vector2(16, -30 - swing)
		Direction.RIGHT:
			offset = Vector2(32 + swing, 6)
		Direction.LEFT:
			offset = Vector2(-32 - swing, 6)
	return global_position + offset

func _get_boot_color() -> Color:
	if GameData.has_boots:
		return Color("#2d6a4f") # 深いフォレストグリーンのゴム長靴
	return Color("#582f0e")     # 初期革靴

func _draw() -> void:
	# 1. 地面の立体影（おじさんの丸い体型に合わせた影）
	var shadow_offset = Vector2(4, 3)
	draw_ellipse(Vector2(2, 17) + shadow_offset, 16.0, 7.0, Color(0.12, 0.18, 0.22, 0.32))

	# 浅瀬を歩行中の水しぶきエフェクト
	if is_moving and map_field and map_field.is_in_water(global_position):
		var splash_phase = sin(walk_time * 2.5) * 4.0
		draw_arc(Vector2(0, 16), 11.0 + splash_phase, 0, TAU, 16, Color(1, 1, 1, 0.75), 1.8)
		draw_circle(Vector2(-8 + splash_phase, 14), 2.8, Color(0.9, 0.96, 1.0, 0.85))
		draw_circle(Vector2(8 - splash_phase, 14), 2.8, Color(0.9, 0.96, 1.0, 0.85))

	# 2. ドラクエ風歩行ステップ (0: 静止, 1: 左足前, 2: 静止, 3: 右足前)
	var step = int(walk_time) % 4 if is_moving else 0
	# ぽっこりお腹が弾むボブアニメーション
	var bob_y = -2.0 if (step == 1 or step == 3) else 0.0

	# 3. 向きに応じた「かわいいおじさん」描画
	match current_dir:
		Direction.DOWN:
			_draw_ojisan_down(step, bob_y)
		Direction.UP:
			_draw_ojisan_up(step, bob_y)
		Direction.RIGHT:
			_draw_ojisan_side(step, bob_y, false)
		Direction.LEFT:
			_draw_ojisan_side(step, bob_y, true)

	# 4. 照準マーカー
	if can_cast_at_mouse and not is_fishing:
		var target_local = to_local(mouse_world_pos)
		draw_circle(target_local, 16.0, Color(1, 1, 1, 0.25))
		draw_arc(target_local, 16.0, 0, TAU, 24, Color(0.95, 0.55, 0.4, 0.85), 2.2)
		draw_circle(target_local, 4.0, Color(1.0, 0.85, 0.3, 0.95))
		draw_line(Vector2.ZERO, target_local, Color(1, 1, 1, 0.45), 1.2)

# --- A. かわいいおじさん：下向き（正面） ---
func _draw_ojisan_down(step: int, bob_y: float) -> void:
	var boot_col = _get_boot_color()
	var overalls_col = Color("#2a6f97") # デニムサロペット（オーバーオール）
	var shirt_col = Color("#e9c46a")    # マスタードイエローのシャツ
	var skin_col = Color("#fcd5ce")     # やさしい肌色
	var mustache_col = Color("#f8f9fa") # ふさふさの白い口ひげ
	var nose_col = Color("#e76f51")     # 赤い丸鼻
	var hat_col = Color("#ccd5ae")      # パステルカーキのバケットハット
	var ribbon_col = Color("#d4a373")

	# 短い足のパタパタ歩行
	var l_foot_y = 13.0
	var r_foot_y = 13.0
	if step == 1:
		l_foot_y = 15.0
		r_foot_y = 11.0
	elif step == 3:
		l_foot_y = 11.0
		r_foot_y = 15.0
		
	draw_rect(Rect2(-9, l_foot_y, 7, 5), boot_col, true)
	draw_rect(Rect2(2, r_foot_y, 7, 5), boot_col, true)

	# ぽっこり太鼓腹（丸いサロペット）
	var belly_y = -3.0 + bob_y
	# シャツの袖
	draw_circle(Vector2(-11, belly_y + 4), 4.5, shirt_col)
	draw_circle(Vector2(11, belly_y + 4), 4.5, shirt_col)
	# ぽっこりお腹
	draw_ellipse(Vector2(0, belly_y + 6), 13.0, 10.0, overalls_col)
	# サロペットの胸当て
	draw_rect(Rect2(-8, belly_y, 16, 12), overalls_col, true)
	draw_rect(Rect2(-7, belly_y - 2, 14, 4), shirt_col, true) # シャツの襟元
	# サスペンダーの金ボタン
	draw_circle(Vector2(-6, belly_y + 2), 1.8, Color("#e9c46a"))
	draw_circle(Vector2(6, belly_y + 2), 1.8, Color("#e9c46a"))

	# 腰の魚籠（ビク）
	draw_ellipse(Vector2(-13, belly_y + 8), 5.0, 6.0, Color("#d4a373"))
	draw_ellipse(Vector2(-13, belly_y + 8), 3.5, 2.0, Color("#bc6c25"))

	# お顔
	var head_y = -14.0 + bob_y
	draw_circle(Vector2(0, head_y), 9.5, skin_col)

	# ふさふさ白眉毛
	draw_line(Vector2(-7, head_y - 4), Vector2(-2, head_y - 4), Color.WHITE, 2.0)
	draw_line(Vector2(2, head_y - 4), Vector2(7, head_y - 4), Color.WHITE, 2.0)

	# ニッコリ優しい目（笑顔のアーチ）
	draw_arc(Vector2(-4.5, head_y - 1), 2.2, PI * 1.1, PI * 1.9, 8, Color("#2b2d42"), 1.8)
	draw_arc(Vector2(4.5, head_y - 1), 2.2, PI * 1.1, PI * 1.9, 8, Color("#2b2d42"), 1.8)

	# ほんのり赤いほっぺ
	draw_circle(Vector2(-7, head_y + 2), 2.2, Color("#f28482", 0.6))
	draw_circle(Vector2(7, head_y + 2), 2.2, Color("#f28482", 0.6))

	# 赤い丸鼻（愛嬌たっぷり！）
	draw_circle(Vector2(0, head_y + 1), 2.8, nose_col)
	draw_circle(Vector2(-0.8, head_y + 0.3), 1.0, Color(1, 1, 1, 0.7)) # 鼻のハイライト

	# 立派でふんわりした口ひげ（カイゼル・ふさふさ白ひげ）
	draw_ellipse(Vector2(-4, head_y + 4.5), 5.0, 3.0, mustache_col)
	draw_ellipse(Vector2(4, head_y + 4.5), 5.0, 3.0, mustache_col)
	draw_circle(Vector2(-8, head_y + 3.8), 2.0, mustache_col) # ひげの毛先
	draw_circle(Vector2(8, head_y + 3.8), 2.0, mustache_col)

	# バケットハット（釣り用帽子）
	draw_ellipse(Vector2(0, head_y - 7), 17.0, 8.0, hat_col) # つば
	draw_rect(Rect2(-9, head_y - 15, 18, 9), hat_col, true)  # クラウン
	draw_rect(Rect2(-9, head_y - 10, 18, 3.0), ribbon_col, true) # リボン
	# 釣り針・ルアーピン飾り
	draw_line(Vector2(6, head_y - 11), Vector2(8, head_y - 8), Color("#e76f51"), 1.8)
	draw_circle(Vector2(8, head_y - 8), 1.5, Color("#ffb703"))

	# 釣り竿
	var rod_tip = get_rod_tip_global_pos() - global_position
	draw_line(Vector2(10, belly_y + 5), rod_tip, Color("#9c6644"), 2.8)
	draw_circle(Vector2(10, belly_y + 5), 3.0, Color("#495057"))

# --- B. かわいいおじさん：上向き（背中） ---
func _draw_ojisan_up(step: int, bob_y: float) -> void:
	var boot_col = _get_boot_color()
	var overalls_col = Color("#2a6f97")
	var shirt_col = Color("#e9c46a")
	var hat_col = Color("#ccd5ae")
	var ribbon_col = Color("#d4a373")

	var l_foot_y = 13.0
	var r_foot_y = 13.0
	if step == 1:
		l_foot_y = 10.0
		r_foot_y = 14.0
	elif step == 3:
		l_foot_y = 14.0
		r_foot_y = 10.0
		
	draw_rect(Rect2(-9, l_foot_y, 7, 5), boot_col, true)
	draw_rect(Rect2(2, r_foot_y, 7, 5), boot_col, true)

	var belly_y = -3.0 + bob_y
	draw_circle(Vector2(-11, belly_y + 4), 4.5, shirt_col)
	draw_circle(Vector2(11, belly_y + 4), 4.5, shirt_col)

	# 丸いお尻と背中
	draw_ellipse(Vector2(0, belly_y + 6), 13.0, 10.0, overalls_col)
	# サスペンダーのクロス（X字）
	draw_line(Vector2(-6, belly_y), Vector2(6, belly_y + 11), Color("#1d3557"), 2.2)
	draw_line(Vector2(6, belly_y), Vector2(-6, belly_y + 11), Color("#1d3557"), 2.2)

	# 腰の魚籠
	draw_ellipse(Vector2(13, belly_y + 8), 5.0, 6.0, Color("#d4a373"))

	# 後頭部
	var head_y = -14.0 + bob_y
	draw_circle(Vector2(0, head_y), 9.5, Color("#adb5bd")) # ロマンスグレーの白髪混じり

	# バケットハット（後ろ姿）
	draw_ellipse(Vector2(0, head_y - 7), 17.0, 8.0, hat_col)
	draw_rect(Rect2(-9, head_y - 15, 18, 9), hat_col, true)
	draw_rect(Rect2(-9, head_y - 10, 18, 3.0), ribbon_col, true)

	# 釣り竿
	var rod_tip = get_rod_tip_global_pos() - global_position
	draw_line(Vector2(10, belly_y + 4), rod_tip, Color("#9c6644"), 2.8)

# --- C. かわいいおじさん：左右向き（横歩き） ---
func _draw_ojisan_side(step: int, bob_y: float, flip: bool) -> void:
	var boot_col = _get_boot_color()
	var overalls_col = Color("#2a6f97")
	var shirt_col = Color("#e9c46a")
	var skin_col = Color("#fcd5ce")
	var mustache_col = Color("#f8f9fa")
	var nose_col = Color("#e76f51")
	var hat_col = Color("#ccd5ae")
	var ribbon_col = Color("#d4a373")

	var sgn = -1.0 if flip else 1.0

	# 前後に大きくよちよちステップ
	var front_foot_x = 3.0 * sgn
	var back_foot_x = -3.0 * sgn
	if step == 1:
		front_foot_x = 7.0 * sgn
		back_foot_x = -7.0 * sgn
	elif step == 3:
		front_foot_x = -6.0 * sgn
		back_foot_x = 6.0 * sgn
		
	draw_rect(Rect2(back_foot_x - 3.5, 12, 7, 5), boot_col.darkened(0.2), true)
	draw_rect(Rect2(front_foot_x - 3.5, 13, 7, 5), boot_col, true)

	var belly_y = -3.0 + bob_y

	# ★★★ 横から見たぽっこり出たお腹！！ ★★★
	# お腹が進行方向（sgn方向）にポコッと突き出ている
	draw_ellipse(Vector2(2.5 * sgn, belly_y + 6), 12.0, 10.0, overalls_col)
	draw_circle(Vector2(-4.0 * sgn, belly_y + 3), 4.5, shirt_col) # 腕・袖
	# 横ポケット
	draw_rect(Rect2(2 * sgn, belly_y + 6, 4 * sgn, 5), Color("#1d3557"), true)

	# お顔
	var head_y = -14.0 + bob_y
	draw_circle(Vector2(2 * sgn, head_y), 9.0, skin_col)
	# 後頭部の白髪
	draw_circle(Vector2(-2.5 * sgn, head_y + 2), 5.0, Color("#adb5bd"))

	# 横顔の目（優しい笑顔）
	draw_arc(Vector2(5.5 * sgn, head_y - 1), 2.0, PI * 1.1, PI * 1.9, 6, Color("#2b2d42"), 1.8)
	# ほっぺ
	draw_circle(Vector2(5 * sgn, head_y + 2.5), 2.0, Color("#f28482", 0.6))

	# ★ちょこんと前に出た赤い丸鼻
	draw_circle(Vector2(8.5 * sgn, head_y + 1), 2.8, nose_col)

	# ★前に突き出たふさふさ口ひげ
	draw_ellipse(Vector2(8.0 * sgn, head_y + 4.5), 5.5, 3.2, mustache_col)
	draw_circle(Vector2(11.0 * sgn, head_y + 4.0), 2.2, mustache_col)

	# バケットハット（横）
	draw_ellipse(Vector2(1.5 * sgn, head_y - 7), 16.0, 7.5, hat_col)
	draw_rect(Rect2(-7 * sgn, head_y - 15, 15 * sgn, 9), hat_col, true)
	draw_rect(Rect2(-7 * sgn, head_y - 10, 15 * sgn, 3.0), ribbon_col, true)

	# 釣り竿
	var rod_tip = get_rod_tip_global_pos() - global_position
	draw_line(Vector2(6 * sgn, belly_y + 5), rod_tip, Color("#9c6644"), 2.8)
