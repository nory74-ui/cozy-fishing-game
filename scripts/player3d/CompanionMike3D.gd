extends CharacterBody3D
class_name CompanionMike3D

# --- 相棒のミケ（三毛猫 3D コンパニオン：4足・尻尾・耳・金鈴・招き猫 関節アニメーション＆落下防止版） ---

@export var follow_target_path: NodePath
var follow_target: Node3D

const PIER_Z_MIN := -4.32
const PIER_Z_MAX := -2.88
const PIER_X_MIN := -7.25
const PIER_EXIT_X := 0.85

const BW_Z_MIN := -12.35
const BW_Z_MAX := -10.35
const BW_X_MIN := -12.80
const BW_EXIT_X := 1.15

const DECK_Z_MIN := -6.80
const DECK_Z_MAX := -0.80
const DECK_X_MIN := 0.85
const LAND_HUB_X := 1.65

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

func set_facing_direction(dir: Vector3) -> void:
	var d = Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 0.001:
		return
	d = d.normalized()
	target_rotation_y = atan2(d.x, d.z)
	if visual_root:
		visual_root.rotation.y = target_rotation_y

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
			_enforce_safe_bounds(false, false, delta)
			return

	var was_on_pier := _is_in_pier_arm(global_position)
	var was_on_bw := _is_in_breakwater_arm(global_position)

	var to_target = follow_target.global_position - global_position
	to_target.y = 0.0
	var dist = to_target.length()

	# 陸路で大きく離れた場合のみ源さん付近の安全な陸・桟橋・防波堤上へ復帰（海上の空中ワープを防止）
	if dist > 14.0 or _is_over_water(global_position):
		_teleport_to_safe_spot_near_target()
		return

	if dist > start_follow_distance:
		is_following = true
	elif dist < stop_distance:
		is_following = false

	var t = Time.get_ticks_msec() / 1000.0

	if is_following:
		var nav_pos = _get_navigation_target()
		var nav_vec = nav_pos - global_position
		nav_vec.y = 0.0
		var dir = nav_vec.normalized() if nav_vec.length_squared() > 0.0001 else to_target.normalized()
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
		var parent_world = get_parent()
		var in_closeup = (parent_world and "is_catch_closeup" in parent_world and parent_world.is_catch_closeup)
		if is_fishing_cheer and not in_closeup:
			if follow_target.has_method("get_facing_direction"):
				var f_dir: Vector3 = follow_target.get_facing_direction()
				target_rotation_y = atan2(f_dir.x, f_dir.z)
			else:
				target_rotation_y = deg_to_rad(-90.0)
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rotation_y, delta * 8.0)

		_animate_idle_or_cheer_joints(t, delta, is_fishing_cheer)

	velocity.x = clamp(velocity.x, -8.0, 8.0)
	velocity.z = clamp(velocity.z, -8.0, 8.0)
	velocity.y = 0.0
	move_and_slide()
	_enforce_safe_bounds(was_on_pier, was_on_bw, delta)

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

func _is_in_pier_arm(pos: Vector3) -> bool:
	return pos.x < PIER_EXIT_X and pos.z >= -4.55 and pos.z <= -2.65

func _is_in_breakwater_arm(pos: Vector3) -> bool:
	return pos.x < BW_EXIT_X and pos.z >= -12.65 and pos.z <= -10.10

func _get_min_land_x(z: float) -> float:
	var shore_x := _get_shoreline_x(z)
	if z >= DECK_Z_MIN and z <= DECK_Z_MAX:
		return DECK_X_MIN
	if z >= -10.15 and z <= -9.0:
		return max(shore_x + 0.15, 0.75)
	return shore_x + 0.30

func _is_point_on_walkable_surface(x: float, z: float, eps: float = 0.0) -> bool:
	if z < -16.2 - eps or z > 16.2 + eps or x > _get_shoreline_x(z) + 6.5 + eps:
		return false
	if z >= PIER_Z_MIN - eps and z <= PIER_Z_MAX + eps and x >= PIER_X_MIN - eps:
		return true
	if z >= BW_Z_MIN - eps and z <= BW_Z_MAX + eps and x >= BW_X_MIN - eps:
		return true
	return x >= _get_min_land_x(z) - eps

func _is_over_water(pos: Vector3) -> bool:
	# Vector3(float32)への代入丸め誤差で誤反応しないよう境界外側のみを海と判定する
	return not _is_point_on_walkable_surface(pos.x, pos.z, 0.04)

func _get_navigation_target() -> Vector3:
	var target := follow_target.global_position
	var mike_on_pier := _is_in_pier_arm(global_position)
	var mike_on_bw := _is_in_breakwater_arm(global_position)
	var target_on_pier := _is_in_pier_arm(target)
	var target_on_bw := _is_in_breakwater_arm(target)

	# 桟橋や大波止から別エリアへ移動する際は、海上を突っ切らずに陸・デッキ側の合流路を経由する
	if mike_on_pier and not target_on_pier:
		return Vector3(LAND_HUB_X, global_position.y, -3.6)
	if mike_on_bw and not target_on_bw:
		return Vector3(LAND_HUB_X, global_position.y, -11.2)
	if not mike_on_pier and target_on_pier and (global_position.z < PIER_Z_MIN or global_position.z > PIER_Z_MAX):
		return Vector3(LAND_HUB_X, global_position.y, -3.6)
	if not mike_on_bw and target_on_bw and (global_position.z < BW_Z_MIN or global_position.z > BW_Z_MAX):
		return Vector3(LAND_HUB_X, global_position.y, -11.2)
	return target

func _teleport_to_safe_spot_near_target() -> void:
	var base := follow_target.global_position
	var offsets: Array[Vector3] = [
		Vector3(0.8, 0.0, 0.0),
		Vector3(-0.7, 0.0, 0.0),
		Vector3(0.6, 0.0, -0.45),
		Vector3(0.6, 0.0, 0.45),
		Vector3(0.0, 0.0, -0.65),
		Vector3(0.0, 0.0, 0.65),
		Vector3(1.1, 0.0, 0.0),
		Vector3.ZERO,
	]
	var chosen := Vector3(clamp(base.x, _get_min_land_x(base.z), _get_shoreline_x(base.z) + 6.5), 0.0, clamp(base.z, -16.2, 16.2))
	for off in offsets:
		var cand := base + off
		if _is_point_on_walkable_surface(cand.x, cand.z):
			chosen = cand
			break
	global_position = Vector3(chosen.x, _get_safe_surface_height(chosen.x, chosen.z), chosen.z)
	velocity = Vector3.ZERO
	_enforce_safe_bounds(false, false, 1.0)
	global_position.y = _get_safe_surface_height(global_position.x, global_position.z)

func _get_safe_surface_height(x: float, z: float) -> float:
	if follow_target and follow_target.has_method("get_walkable_surface_height"):
		return max(follow_target.get_walkable_surface_height(x, z), 0.03)
	if z >= -4.55 and z <= -2.65 and x <= 0.85 and x >= -8.0:
		return 0.48
	if z >= -12.8 and z <= -10.1 and x <= 1.8:
		return 0.95
	if x >= 0.65 and x <= 5.6 and z >= -6.4 and z <= -1.2:
		return 0.48
	return max((x - _get_shoreline_x(z)) * 0.085, 0.03)

func _enforce_safe_bounds(was_on_pier: bool = false, was_on_bw: bool = false, delta: float = 0.016) -> void:
	global_position.z = clamp(global_position.z, -16.2, 16.2)
	var z = global_position.z
	var shore_x = _get_shoreline_x(z)
	global_position.x = min(global_position.x, shore_x + 6.5)

	if was_on_pier and global_position.x < PIER_EXIT_X:
		# フレーム落ち時でも桟橋の横端から海へ踏み外さないよう先に回廊内に収める
		global_position.x = max(global_position.x, PIER_X_MIN)
		global_position.z = clamp(global_position.z, PIER_Z_MIN, PIER_Z_MAX)
	elif was_on_bw and global_position.x < BW_EXIT_X:
		# 大波止上からも横へ踏み外さず陸側スロープ経由でのみ離脱可能にする
		global_position.x = max(global_position.x, BW_X_MIN)
		global_position.z = clamp(global_position.z, BW_Z_MIN, BW_Z_MAX)
	elif z >= PIER_Z_MIN and z <= PIER_Z_MAX and global_position.x < _get_min_land_x(z):
		global_position.x = max(global_position.x, PIER_X_MIN)
		global_position.z = clamp(global_position.z, PIER_Z_MIN, PIER_Z_MAX)
	elif z >= BW_Z_MIN and z <= BW_Z_MAX and global_position.x < _get_min_land_x(z):
		global_position.x = max(global_position.x, BW_X_MIN)
		global_position.z = clamp(global_position.z, BW_Z_MIN, BW_Z_MAX)
	else:
		global_position.x = max(global_position.x, _get_min_land_x(z))

	var target_y := _get_safe_surface_height(global_position.x, global_position.z)
	var y_blend: float = clamp(delta * 20.0, 0.35, 1.0)
	global_position.y = max(lerp(global_position.y, target_y, y_blend), 0.03)
