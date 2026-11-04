extends CharacterBody3D
class_name CompanionMike3D

# --- 相棒のミケ（三毛猫 3D コンパニオン：4足・尻尾・耳・金鈴・招き猫 関節アニメーション＆落下防止版） ---

@export var follow_target_path: NodePath
var follow_target: Node3D

@export var follow_speed: float = 4.8
@export var stop_distance: float = 1.25
@export var start_follow_distance: float = 1.75
@export var gravity: float = 20.0

@onready var visual_root: Node3D = $VisualRoot

# 関節ピボットノード（方法C：Blenderでパーツ分けしたピボット階層）
var left_front_paw: Node3D = null
var right_front_paw: Node3D = null
var left_back_paw: Node3D = null
var right_back_paw: Node3D = null
var body_pivot: Node3D = null
var head_pivot: Node3D = null
var tail_pivot: Node3D = null
var left_ear_pivot: Node3D = null
var right_ear_pivot: Node3D = null
var bell_pivot: Node3D = null

var is_following: bool = false
var target_rotation_y: float = 0.0
var walk_anim_timer: float = 0.0

# 後方互換性プロパティ
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

func _ready() -> void:
	if follow_target_path:
		follow_target = get_node_or_null(follow_target_path)
	_bind_mike_joints()
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(58.0)
	floor_constant_speed = true

func _bind_mike_joints() -> void:
	if not visual_root:
		return
	left_front_paw = visual_root.find_child("LeftFrontPawPivot", true, false) as Node3D
	right_front_paw = visual_root.find_child("RightFrontPawPivot", true, false) as Node3D
	left_back_paw = visual_root.find_child("LeftBackPawPivot", true, false) as Node3D
	right_back_paw = visual_root.find_child("RightBackPawPivot", true, false) as Node3D
	body_pivot = visual_root.find_child("BodyPivot", true, false) as Node3D
	head_pivot = visual_root.find_child("HeadPivot", true, false) as Node3D
	tail_pivot = visual_root.find_child("TailPivot", true, false) as Node3D
	left_ear_pivot = visual_root.find_child("LeftEarPivot", true, false) as Node3D
	right_ear_pivot = visual_root.find_child("RightEarPivot", true, false) as Node3D
	bell_pivot = visual_root.find_child("BellPivot", true, false) as Node3D

func _get_shoreline_x(z: float) -> float:
	return 0.6 + sin(z * 0.16) * 1.1 + cos(z * 0.09 + 0.5) * 0.6

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if not follow_target:
		var parent = get_parent()
		if parent:
			follow_target = parent.get_node_or_null("CharacterBarlock3D")
		if not follow_target:
			move_and_slide()
			return

	var to_target = follow_target.global_position - global_position
	to_target.y = 0.0
	var dist = to_target.length()

	# 離れすぎた場合は源さんのすぐ後ろにスムーズ復帰
	if dist > 6.5:
		global_position = follow_target.global_position + Vector3(0.8, 0.1, 0.4)
		velocity = Vector3.ZERO
		return

	if dist > start_follow_distance:
		is_following = true
	elif dist < stop_distance:
		is_following = false

	var t = Time.get_ticks_msec() / 1000.0

	if is_following:
		var dir = to_target.normalized()
		velocity.x = dir.x * follow_speed
		velocity.z = dir.z * follow_speed

		target_rotation_y = atan2(dir.x, dir.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rotation_y, delta * 12.0)

		walk_anim_timer += delta * 15.0
		visual_root.position.y = abs(sin(walk_anim_timer)) * 0.048
		visual_root.rotation.z = sin(walk_anim_timer * 0.5) * 0.04

		# ミケの4本の足・尻尾・猫耳・金の鈴がトコトコ揺れる歩行アニメーション
		_animate_walk_joints(walk_anim_timer)
	else:
		velocity.x = move_toward(velocity.x, 0, follow_speed * delta * 6.0)
		velocity.z = move_toward(velocity.z, 0, follow_speed * delta * 6.0)
		walk_anim_timer = 0.0
		visual_root.rotation.z = move_toward(visual_root.rotation.z, 0.0, delta * 3.0)
		visual_root.position.y = sin(t * 2.5) * 0.012

		var is_fishing_cheer = (follow_target.get("current_state") == 3)
		if is_fishing_cheer:
			target_rotation_y = deg_to_rad(-90.0)
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rotation_y, delta * 8.0)

		_animate_idle_or_cheer_joints(t, delta, is_fishing_cheer)

	velocity.x = clamp(velocity.x, -8.0, 8.0)
	velocity.z = clamp(velocity.z, -8.0, 8.0)
	velocity.y = 0.0
	move_and_slide()
	_enforce_safe_bounds()

func _animate_walk_joints(w_time: float) -> void:
	var s = sin(w_time)
	# 対角線歩行（右前足＆左後ろ足 ⇄ 左前足＆右後ろ足）
	if right_front_paw:
		right_front_paw.rotation.x = s * 0.55
	if left_front_paw:
		left_front_paw.rotation.x = -s * 0.55
	if left_back_paw:
		left_back_paw.rotation.x = s * 0.50
	if right_back_paw:
		right_back_paw.rotation.x = -s * 0.50
	if tail_pivot:
		tail_pivot.rotation.y = sin(w_time * 0.8) * 0.42
		tail_pivot.rotation.x = deg_to_rad(-35.0) + cos(w_time * 1.6) * 0.12
	if head_pivot:
		head_pivot.rotation.z = sin(w_time * 0.5) * 0.05
	if bell_pivot:
		bell_pivot.rotation.z = sin(w_time * 2.0) * 0.22

func _animate_idle_or_cheer_joints(t: float, delta: float, is_cheer: bool) -> void:
	if left_back_paw:
		left_back_paw.rotation.x = move_toward(left_back_paw.rotation.x, 0.0, delta * 6.0)
	if right_back_paw:
		right_back_paw.rotation.x = move_toward(right_back_paw.rotation.x, 0.0, delta * 6.0)

	if is_cheer:
		# 源さんが釣り・ファイト中は前足をパタパタさせて尻尾を大きく振って応援！
		if right_front_paw:
			right_front_paw.rotation.x = deg_to_rad(-75.0 + sin(t * 12.0) * 28.0)
		if left_front_paw:
			left_front_paw.rotation.x = deg_to_rad(-45.0 - sin(t * 12.0) * 25.0)
		if tail_pivot:
			tail_pivot.rotation.y = sin(t * 9.0) * 0.52
		if head_pivot:
			head_pivot.rotation.z = sin(t * 6.0) * 0.08
	else:
		# のんびり待機：右前足を招き猫のように可愛く挙げてチョイチョイと揺らす＆耳ピクピク
		if right_front_paw:
			var beckon = deg_to_rad(-62.0 + sin(t * 3.8) * 16.0)
			right_front_paw.rotation.x = lerp(right_front_paw.rotation.x, beckon, delta * 6.0)
		if left_front_paw:
			left_front_paw.rotation.x = move_toward(left_front_paw.rotation.x, 0.0, delta * 5.0)
		if tail_pivot:
			tail_pivot.rotation.y = sin(t * 2.2) * 0.32
			tail_pivot.rotation.x = deg_to_rad(-38.0 + cos(t * 1.5) * 6.0)
		if head_pivot:
			head_pivot.rotation.z = sin(t * 1.4) * 0.04
		if right_ear_pivot:
			var ear_twitch = sin(t * 14.0) * 0.14 if fmod(t, 4.2) < 0.35 else 0.0
			right_ear_pivot.rotation.z = ear_twitch
		if bell_pivot:
			bell_pivot.rotation.z = sin(t * 2.5) * 0.06

func _enforce_safe_bounds() -> void:
	global_position.z = clamp(global_position.z, -16.5, 16.5)
	var z = global_position.z
	var shore_x = _get_shoreline_x(z)
	var on_wooden_pier = (z >= -4.50 and z <= -2.70)
	var on_breakwater = (z >= -12.65 and z <= -10.15)

	if on_wooden_pier and global_position.x < shore_x + 0.6:
		global_position.x = max(global_position.x, -7.2)
		if global_position.x < 0.7:
			global_position.z = clamp(global_position.z, -4.35, -2.85)
	elif on_breakwater and global_position.x < shore_x + 1.0:
		global_position.x = max(global_position.x, -12.8)
		if global_position.x < 0.8:
			global_position.z = clamp(global_position.z, -12.40, -10.30)
	else:
		global_position.x = max(global_position.x, min(shore_x - 0.10, 0.80))

	if follow_target and follow_target.has_method("get_walkable_surface_height"):
		var target_y = follow_target.get_walkable_surface_height(global_position.x, global_position.z)
		global_position.y = lerp(global_position.y, target_y, 0.35)
	elif global_position.y < -0.1:
		global_position.y = 0.25
