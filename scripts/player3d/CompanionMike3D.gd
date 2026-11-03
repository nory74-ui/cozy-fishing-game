extends CharacterBody3D
class_name CompanionMike3D

# --- 相棒のミケ（三毛猫 3D コンパニオン：完全落下防止版） ---

@export var follow_target_path: NodePath
var follow_target: Node3D

@export var follow_speed: float = 4.8
@export var stop_distance: float = 1.25
@export var start_follow_distance: float = 1.75
@export var gravity: float = 20.0

@onready var visual_root: Node3D = $VisualRoot

var is_following: bool = false
var target_rotation_y: float = 0.0
var walk_anim_timer: float = 0.0

func _ready() -> void:
	if follow_target_path:
		follow_target = get_node_or_null(follow_target_path)
	_apply_companion_material()
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(58.0)
	floor_constant_speed = true

func _apply_companion_material() -> void:
	var base_tex = load("res://assets/models/fbx/mike_companion_cute_calico_cat_3d_model_basecolor.jpg")
	var norm_tex = load("res://assets/models/fbx/mike_companion_cute_calico_cat_3d_model_normal.png")
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

	# 離れすぎた場合はバーロックのすぐ後ろにスムーズ復帰
	if dist > 6.5:
		global_position = follow_target.global_position + Vector3(0.8, 0.1, 0.4)
		velocity = Vector3.ZERO
		return

	if dist > start_follow_distance:
		is_following = true
	elif dist < stop_distance:
		is_following = false

	if is_following:
		var dir = to_target.normalized()
		velocity.x = dir.x * follow_speed
		velocity.z = dir.z * follow_speed

		target_rotation_y = atan2(dir.x, dir.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rotation_y, delta * 12.0)

		walk_anim_timer += delta * 16.0
		visual_root.position.y = abs(sin(walk_anim_timer)) * 0.05
		visual_root.rotation.z = sin(walk_anim_timer * 0.5) * 0.04
	else:
		velocity.x = move_toward(velocity.x, 0, follow_speed * delta * 6.0)
		velocity.z = move_toward(velocity.z, 0, follow_speed * delta * 6.0)
		walk_anim_timer = 0.0
		visual_root.rotation.z = move_toward(visual_root.rotation.z, 0.0, delta * 3.0)

		var t = Time.get_ticks_msec() / 1000.0
		visual_root.position.y = sin(t * 2.5) * 0.012

		if follow_target.get("current_state") == 3:
			target_rotation_y = deg_to_rad(-90.0)
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_rotation_y, delta * 8.0)

	velocity.x = clamp(velocity.x, -8.0, 8.0)
	velocity.z = clamp(velocity.z, -8.0, 8.0)
	move_and_slide()
	_enforce_safe_bounds()

func _enforce_safe_bounds() -> void:
	global_position.z = clamp(global_position.z, -16.5, 16.5)
	var z = global_position.z
	var shore_x = _get_shoreline_x(z)
	var on_wooden_pier = (z >= -4.55 and z <= -2.65)
	var on_breakwater = (z >= -12.65 and z <= -10.35)

	if on_wooden_pier and global_position.x < shore_x + 0.4:
		global_position.x = max(global_position.x, -7.2)
		global_position.z = clamp(global_position.z, -4.35, -2.85)
		if global_position.y < 0.42:
			global_position.y = 0.48
	elif on_breakwater and global_position.x < shore_x + 0.8:
		global_position.x = max(global_position.x, -12.8)
		global_position.z = clamp(global_position.z, -12.40, -10.55)
		if global_position.y < 0.85 and global_position.x < 0.5:
			global_position.y = 0.95
	else:
		global_position.x = max(global_position.x, shore_x - 0.10)

	if global_position.y < -0.1:
		global_position.y = 0.25
