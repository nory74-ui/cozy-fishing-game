extends CharacterBody3D
class_name CharacterBarlock3D

# --- キャプテン・バーロック（3Dキャラクターコントローラー：桟橋・番屋前・堤防シームレス移動＆釣り上げアクション対応版） ---

@export var move_speed: float = 4.8
@export var gravity: float = 20.0

enum State { IDLE, WALKING, CASTING, FISHING, SITTING }
var current_state: State = State.IDLE

@onready var visual_root: Node3D = $VisualRoot
@onready var lantern_light: OmniLight3D = $VisualRoot/LanternLight
@onready var model_node: Node3D = get_node_or_null("VisualRoot/Model3D")

var target_rotation_y: float = 0.0
var last_move_dir: Vector3 = Vector3(0, 0, 1)

# 後方互換性プロパティ（3Dモデルの回転と自動同期）
var facing_dir: int = 0:
	set(val):
		facing_dir = val
		match val:
			0: target_rotation_y = 0.0
			1: target_rotation_y = deg_to_rad(90.0)
			2: target_rotation_y = deg_to_rad(180.0)
			3: target_rotation_y = deg_to_rad(-90.0)
		if visual_root:
			visual_root.rotation.y = target_rotation_y

func _update_sprite_direction() -> void:
	pass

var walk_anim_timer: float = 0.0
var footprint_timer: float = 0.0
var action_tween: Tween = null

signal state_changed(new_state: State)

func _ready() -> void:
	if lantern_light:
		lantern_light.visible = false
	_apply_character_material()
	floor_snap_length = 0.65
	floor_max_angle = deg_to_rad(65.0)
	floor_constant_speed = true

func _apply_character_material() -> void:
	var base_tex = load("res://assets/models/fbx/barlock_character_fisherman_3d_model_basecolor.jpg")
	var norm_tex = load("res://assets/models/fbx/barlock_character_fisherman_3d_model_normal.png")
	if not base_tex or not visual_root:
		return
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.albedo_texture = base_tex
	mat.metallic = 0.0
	mat.roughness = 0.82
	mat.metallic_specular = 0.20
	if norm_tex:
		mat.normal_enabled = true
		mat.normal_texture = norm_tex
		mat.normal_scale = 0.6
	_set_mesh_material_recursive(visual_root, mat)

func _set_mesh_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_set_mesh_material_recursive(child, mat)

func _get_shoreline_x(z: float) -> float:
	return 0.6 + sin(z * 0.16) * 1.1 + cos(z * 0.09 + 0.5) * 0.6

func _get_base_terrain_height(x: float, z: float) -> float:
	var shore_x = _get_shoreline_x(z)
	var d = x - shore_x
	if d < 0.0:
		return max(d * 0.095 - 0.32 * (1.0 - exp(d * 0.14)), -2.6)
	elif d < 5.2:
		return d * 0.085
	else:
		return 0.442 + (d - 5.2) * 0.16 + sin(z * 0.25) * 0.06

# 砂浜・番屋デッキ・木製桟橋・大波止（堤防）のすべての床高さを滑らかに返す
func get_walkable_surface_height(x: float, z: float) -> float:
	var h = _get_base_terrain_height(x, z)

	# 1. 木製ロング桟橋（z = -4.55 〜 -2.65, x = -8.0 〜 0.85）
	if z >= -4.55 and z <= -2.65 and x <= 0.85 and x >= -8.0:
		h = max(h, 0.48)

	# 2. 漁師の番屋デッキ＆南北スロープ（x = 0.65 〜 5.6, z = -7.2 〜 -0.4）
	if x >= 0.65 and x <= 5.6:
		if z >= -6.4 and z <= -1.2:
			h = max(h, 0.48)
		elif z > -1.2 and z <= -0.4:
			var t_s = (z - (-0.4)) / (-1.2 - (-0.4))
			h = max(h, lerp(h, 0.48, clamp(t_s, 0.0, 1.0)))
		elif z >= -7.2 and z < -6.4:
			var t_n = (z - (-7.2)) / (-6.4 - (-7.2))
			h = max(h, lerp(h, 0.48, clamp(t_n, 0.0, 1.0)))

	# 3. 野北漁港の大波止（北防波堤 z = -12.8 〜 -10.1）＆スロープ（z = -10.1 〜 -9.1, x = 0.5 〜 4.5）
	if z >= -12.8 and z <= -10.1:
		if x <= 1.8:
			h = max(h, 0.95)
		elif x <= 4.5:
			var t_e = 1.0 - ((x - 1.8) / (4.5 - 1.8))
			h = max(h, lerp(h, 0.95, clamp(t_e, 0.0, 1.0)))
	elif z > -10.1 and z <= -9.1 and x >= 0.4 and x <= 4.5:
		var t_z = (z - (-9.1)) / (-10.1 - (-9.1))
		var target_pier_h = 0.95 if x <= 1.8 else lerp(h, 0.95, clamp(1.0 - ((x - 1.8) / 2.7), 0.0, 1.0))
		h = max(h, lerp(h, target_pier_h, clamp(t_z, 0.0, 1.0)))

	return h

func _physics_process(delta: float) -> void:
	# キャスト中・釣り中はその場で待機（RealFishingController3Dがアニメーション制御）
	if current_state == State.CASTING or current_state == State.FISHING:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 6.0)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta * 6.0)
		velocity.y = 0.0
		move_and_slide()
		_enforce_safe_bounds()
		return

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir.length_squared() < 0.01:
		var rx = 0.0
		var rz = 0.0
		if Input.is_key_pressed(KEY_A): rx -= 1.0
		if Input.is_key_pressed(KEY_D): rx += 1.0
		if Input.is_key_pressed(KEY_W): rz -= 1.0
		if Input.is_key_pressed(KEY_S): rz += 1.0
		input_dir = Vector2(rx, rz).normalized()

	var direction = Vector3.ZERO
	if input_dir.length_squared() > 0.01:
		var cam = get_viewport().get_camera_3d()
		if cam:
			var cam_basis = cam.global_transform.basis
			var forward = -cam_basis.z
			forward.y = 0.0
			forward = forward.normalized()
			var right = cam_basis.x
			right.y = 0.0
			right = right.normalized()
			direction = (right * input_dir.x + forward * -input_dir.y).normalized()
		else:
			direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	if direction.length_squared() > 0.01:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		current_state = State.WALKING
		last_move_dir = direction

		target_rotation_y = atan2(direction.x, direction.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rotation_y, delta * 12.0)

		walk_anim_timer += delta * 12.0
		visual_root.position.y = abs(sin(walk_anim_timer)) * 0.06
		visual_root.rotation.z = sin(walk_anim_timer * 0.5) * 0.04
		visual_root.rotation.x = move_toward(visual_root.rotation.x, 0.0, delta * 5.0)

		footprint_timer += delta
		if footprint_timer >= 0.28:
			footprint_timer = 0.0
			var parent_world = get_parent()
			if parent_world and parent_world.has_method("add_footprint"):
				parent_world.add_footprint(global_position)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 6.0)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta * 6.0)
		current_state = State.IDLE
		walk_anim_timer = 0.0
		visual_root.rotation.z = move_toward(visual_root.rotation.z, 0.0, delta * 3.0)
		visual_root.rotation.x = move_toward(visual_root.rotation.x, 0.0, delta * 5.0)
		var t = Time.get_ticks_msec() / 1000.0
		visual_root.position.y = sin(t * 2.2) * 0.015

	velocity.x = clamp(velocity.x, -8.0, 8.0)
	velocity.z = clamp(velocity.z, -8.0, 8.0)
	velocity.y = 0.0
	move_and_slide()
	_enforce_safe_bounds()

# --- 100%落下・海没防止 ＆ 桟橋・番屋デッキ・大波止へのシームレス移動制御 ---
func _enforce_safe_bounds() -> void:
	global_position.z = clamp(global_position.z, -16.5, 16.5)

	var z = global_position.z
	var shore_x = _get_shoreline_x(z)

	# 東側（画面右：海岸スレート岩壁の手前）
	var max_east_x = shore_x + 6.8
	if global_position.x > max_east_x:
		global_position.x = max_east_x
		velocity.x = min(velocity.x, 0.0)

	# 西側（画面左：木製桟橋・大波止・波打ち際の境界）
	var on_wooden_pier_corridor = (z >= -4.50 and z <= -2.70)
	var on_breakwater_corridor = (z >= -12.65 and z <= -10.15)

	if on_wooden_pier_corridor and global_position.x < shore_x + 0.6:
		# 木製ロング桟橋の上：先端 x = -7.6 まで自由に歩ける
		global_position.x = max(global_position.x, -7.6)
		if global_position.x < 0.7:
			global_position.z = clamp(global_position.z, -4.40, -2.80)
	elif on_breakwater_corridor and global_position.x < shore_x + 1.0:
		# 野北の大波止（白灯台）の上：先端 x = -13.2 まで自由に歩ける
		global_position.x = max(global_position.x, -13.2)
		if global_position.x < 0.8:
			global_position.z = clamp(global_position.z, -12.45, -10.25)
	else:
		# 砂浜・番屋前デッキ：波打ち際でストップして海への落下を防止
		var min_beach_x = min(shore_x - 0.15, 0.80)
		if global_position.x < min_beach_x:
			global_position.x = min_beach_x
			velocity.x = max(velocity.x, 0.0)

	# 床面の高さ（砂浜・デッキ・桟橋・堤防）へ滑らかに追従
	var target_y = get_walkable_surface_height(global_position.x, global_position.z)
	global_position.y = lerp(global_position.y, target_y, 0.35)

# --- 3D 釣り＆釣り上げ（抜き上げ）アクションアニメーション ---
func play_charge_pose(power_ratio: float) -> void:
	if not visual_root: return
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, deg_to_rad(-90.0), 0.25)
	# チャージ量に応じて竿を後ろへ大きく溜める
	visual_root.rotation.x = deg_to_rad(lerp(4.0, 20.0, power_ratio))
	visual_root.position.y = lerp(0.0, -0.04, power_ratio)

func play_cast_swing_anim() -> void:
	if not visual_root: return
	if action_tween and action_tween.is_valid():
		action_tween.kill()
	action_tween = create_tween()
	action_tween.tween_property(visual_root, "rotation:x", deg_to_rad(-18.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	action_tween.parallel().tween_property(visual_root, "position:y", 0.12, 0.14)
	action_tween.tween_property(visual_root, "rotation:x", 0.0, 0.22)
	action_tween.parallel().tween_property(visual_root, "position:y", 0.0, 0.22)

func play_fight_pose(is_reeling: bool, is_dashing: bool, time_sec: float) -> void:
	if not visual_root: return
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, deg_to_rad(-90.0), 0.2)
	if is_dashing:
		# 魚の強烈な引きに腰を落として耐えるポーズ
		visual_root.rotation.x = deg_to_rad(14.0 + sin(time_sec * 18.0) * 4.0)
		visual_root.position.y = -0.03 + abs(sin(time_sec * 12.0)) * 0.03
	elif is_reeling:
		# 竿をポンピングしながら力強くリールを巻くモーション
		visual_root.rotation.x = deg_to_rad(8.0 + sin(time_sec * 10.0) * 7.0)
		visual_root.position.y = abs(sin(time_sec * 10.0)) * 0.05
	else:
		visual_root.rotation.x = move_toward(visual_root.rotation.x, deg_to_rad(4.0), 0.1)
		visual_root.position.y = move_toward(visual_root.position.y, 0.0, 0.1)

func play_landing_heave_anim() -> void:
	if not visual_root: return
	if action_tween and action_tween.is_valid():
		action_tween.kill()
	action_tween = create_tween()
	# 1. 竿を大きく天へ振り上げて魚を海から抜き上げる豪快なアクション！
	action_tween.tween_property(visual_root, "rotation:x", deg_to_rad(28.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	action_tween.parallel().tween_property(visual_root, "position:y", 0.34, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2. 着地してもう一度喜びのジャンプ！
	action_tween.tween_property(visual_root, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	action_tween.parallel().tween_property(visual_root, "rotation:x", deg_to_rad(-6.0), 0.18)
	action_tween.tween_property(visual_root, "position:y", 0.22, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	action_tween.parallel().tween_property(visual_root, "rotation:x", 0.0, 0.15)
	action_tween.tween_property(visual_root, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func reset_pose() -> void:
	if not visual_root: return
	if action_tween and action_tween.is_valid():
		action_tween.kill()
	visual_root.rotation.x = 0.0
	visual_root.rotation.z = 0.0
	visual_root.position.y = 0.0

func set_lantern_enabled(enabled: bool) -> void:
	if lantern_light:
		lantern_light.visible = enabled
