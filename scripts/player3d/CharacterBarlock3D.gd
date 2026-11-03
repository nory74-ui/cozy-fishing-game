extends CharacterBody3D
class_name CharacterBarlock3D

# --- キャプテン・バーロック（3Dキャラクターコントローラー：完全落下防止＆段差快適移動版） ---

@export var move_speed: float = 4.6
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
var cast_timer: float = 0.0

var bobber_node: Node3D
var bobber_light: OmniLight3D
var bobber_target_pos: Vector3 = Vector3.ZERO
var bobber_active: bool = false
var bobber_time: float = 0.0

signal state_changed(new_state: State)
signal cast_finished(target_pos: Vector3)

func _ready() -> void:
	if lantern_light:
		lantern_light.visible = false
	_apply_character_material()
	_create_bobber()
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(58.0)
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

func _create_bobber() -> void:
	bobber_node = Node3D.new()
	bobber_node.name = "NogitaBobber3D"
	bobber_node.visible = false

	var mesh_inst = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.22
	var mat_bob = StandardMaterial3D.new()
	mat_bob.albedo_color = Color(0.95, 0.22, 0.18)
	sm.material = mat_bob
	mesh_inst.mesh = sm
	bobber_node.add_child(mesh_inst)

	var chemi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.025
	cm.height = 0.16
	var mat_chemi = StandardMaterial3D.new()
	mat_chemi.albedo_color = Color(0.3, 1.0, 0.35)
	mat_chemi.emission_enabled = true
	mat_chemi.emission = Color(0.3, 1.0, 0.35)
	mat_chemi.emission_energy_multiplier = 4.5
	cm.material = mat_chemi
	chemi.mesh = cm
	chemi.position.y = 0.14
	bobber_node.add_child(chemi)

	bobber_light = OmniLight3D.new()
	bobber_light.light_color = Color(0.35, 1.0, 0.45)
	bobber_light.light_energy = 2.2
	bobber_light.omni_range = 3.5
	bobber_node.add_child(bobber_light)

	get_tree().root.call_deferred("add_child", bobber_node)

func _get_shoreline_x(z: float) -> float:
	return 0.6 + sin(z * 0.16) * 1.1 + cos(z * 0.09 + 0.5) * 0.6

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if current_state == State.CASTING:
		_process_casting(delta)
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta * 5.0)
		move_and_slide()
		_enforce_safe_bounds()
		return
	elif current_state == State.FISHING:
		_process_fishing(delta)
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta * 5.0)
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
		var t = Time.get_ticks_msec() / 1000.0
		visual_root.position.y = sin(t * 2.2) * 0.015

	velocity.x = clamp(velocity.x, -8.0, 8.0)
	velocity.z = clamp(velocity.z, -8.0, 8.0)
	move_and_slide()
	_enforce_safe_bounds()

# --- 100%落下・海没防止のスマート安全境界ガード ---
func _enforce_safe_bounds() -> void:
	# 1. 南北（画面上下）の安全境界（地形自体は±80mあるため画面端の切れも一切発生しない）
	global_position.z = clamp(global_position.z, -16.5, 16.5)

	var z = global_position.z
	var shore_x = _get_shoreline_x(z)

	# 2. 東側（画面右：海岸スレート岩壁の手前）
	var max_east_x = shore_x + 6.8
	if global_position.x > max_east_x:
		global_position.x = max_east_x
		velocity.x = min(velocity.x, 0.0)

	# 3. 西側（画面左：海側・木製桟橋・大波止の通行制御）
	var on_wooden_pier_corridor = (z >= -4.55 and z <= -2.65)
	var on_breakwater_corridor = (z >= -12.65 and z <= -10.35)

	if on_wooden_pier_corridor and global_position.x < shore_x + 0.4:
		# 木製ロング桟橋の上：先端 x = -7.6 まで歩ける＆左右から海に落ちないようガード
		global_position.x = max(global_position.x, -7.6)
		global_position.z = clamp(global_position.z, -4.40, -2.80)
		if global_position.y < 0.42:
			global_position.y = 0.48
			velocity.y = 0.0
	elif on_breakwater_corridor and global_position.x < shore_x + 0.8:
		# 野北の大波止（白灯台）の上：先端 x = -13.2 まで歩ける＆左右から海に落ちないようガード
		global_position.x = max(global_position.x, -13.2)
		global_position.z = clamp(global_position.z, -12.45, -10.50)
		if global_position.y < 0.85 and global_position.x < 0.5:
			global_position.y = 0.95
			velocity.y = 0.0
	else:
		# 通常の砂浜：波打ち際のくるぶし水深（shore_x - 0.25）でソフトにストップし深海への落下を完全防止
		var min_beach_x = shore_x - 0.25
		if global_position.x < min_beach_x:
			global_position.x = min_beach_x
			velocity.x = max(velocity.x, 0.0)

	# 万一のY座標セーフティ
	if global_position.y < -0.15:
		global_position.y = 0.25
		velocity.y = 0.0

func _start_casting() -> void:
	current_state = State.CASTING
	cast_timer = 0.0
	target_rotation_y = deg_to_rad(-90.0)
	visual_root.rotation.y = target_rotation_y

	var forward = Vector3(-1.0, 0.0, randf_range(-0.25, 0.25)).normalized()
	bobber_target_pos = global_position + forward * randf_range(5.5, 8.5)
	bobber_target_pos.y = 0.04

func _process_casting(delta: float) -> void:
	cast_timer += delta
	if cast_timer < 0.2:
		visual_root.position.y = 0.08
		visual_root.rotation.x = deg_to_rad(10.0)
	elif cast_timer < 0.5:
		visual_root.position.y = 0.0
		visual_root.rotation.x = deg_to_rad(-12.0)
	else:
		visual_root.position.y = 0.0
		visual_root.rotation.x = 0.0
		current_state = State.FISHING
		visual_root.rotation.z = 0.0
		_spawn_bobber()
		cast_finished.emit(bobber_target_pos)

func _spawn_bobber() -> void:
	bobber_active = true
	bobber_time = 0.0
	if bobber_node:
		bobber_node.global_position = bobber_target_pos
		bobber_node.visible = true

func _process_fishing(delta: float) -> void:
	bobber_time += delta
	if bobber_node and bobber_active:
		bobber_node.global_position.y = 0.04 + sin(bobber_time * 2.8) * 0.03
		bobber_node.rotation.z = sin(bobber_time * 3.2) * 0.10

func _retrieve_rod() -> void:
	current_state = State.IDLE
	bobber_active = false
	if bobber_node:
		bobber_node.visible = false

func set_lantern_enabled(enabled: bool) -> void:
	if lantern_light:
		lantern_light.visible = enabled
	if bobber_light:
		bobber_light.visible = enabled
