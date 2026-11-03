extends CharacterBody3D
class_name Player3D

# --- スタイライズド3D プレイヤーコントローラー（釣り・キャスト対応） ---

@export var move_speed: float = 4.8
@export var rotation_speed: float = 12.0
@export var gravity: float = 18.0

# 状態
enum State { IDLE, WALKING, CASTING, FISHING, SITTING }
var current_state: State = State.IDLE

# 参照ノード
@onready var visual_root: Node3D = $VisualRoot
@onready var hat: MeshInstance3D = $VisualRoot/Hat
@onready var rod_prop: Node3D = $VisualRoot/FishingRod
@onready var lantern_light: OmniLight3D = $VisualRoot/LanternLight

# アニメーションパラメータ
var walk_anim_timer: float = 0.0
var original_body_pos: Vector3 = Vector3.ZERO
var original_rod_transform: Transform3D
var cast_timer: float = 0.0

# 足跡タイマー
var footprint_timer: float = 0.0

# ウキ（Float / Bobber）
var bobber_node: Node3D
var bobber_light: OmniLight3D
var bobber_target_pos: Vector3 = Vector3.ZERO
var bobber_active: bool = false
var bobber_time: float = 0.0

signal state_changed(new_state: State)
signal fish_hooked(fish_name: String)

func _ready() -> void:
	if visual_root:
		original_body_pos = visual_root.position
	if rod_prop:
		original_rod_transform = rod_prop.transform
	if lantern_light:
		lantern_light.visible = false
	_create_bobber()

func _create_bobber() -> void:
	bobber_node = Node3D.new()
	bobber_node.name = "FishingBobber3D"
	bobber_node.visible = false
	
	# ウキ本体（赤白の丸型ウキ）
	var mesh_inst = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	var mat_bob = StandardMaterial3D.new()
	mat_bob.albedo_color = Color(0.95, 0.25, 0.2) # 鮮やかな赤
	sm.material = mat_bob
	mesh_inst.mesh = sm
	bobber_node.add_child(mesh_inst)

	# 夜光ケミホタル（緑色発光体）
	var chemi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.03
	cm.height = 0.18
	var mat_chemi = StandardMaterial3D.new()
	mat_chemi.albedo_color = Color(0.3, 1.0, 0.3)
	mat_chemi.emission_enabled = true
	mat_chemi.emission = Color(0.3, 1.0, 0.3)
	mat_chemi.emission_energy_multiplier = 4.0
	cm.material = mat_chemi
	chemi.mesh = cm
	chemi.position.y = 0.16
	bobber_node.add_child(chemi)

	# ウキの発光（夜の海を照らす緑の光）
	bobber_light = OmniLight3D.new()
	bobber_light.light_color = Color(0.35, 1.0, 0.45)
	bobber_light.light_energy = 2.0
	bobber_light.omni_range = 3.5
	bobber_node.add_child(bobber_light)

	get_tree().root.call_deferred("add_child", bobber_node)

func _physics_process(delta: float) -> void:
	# 重力
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	
	# 奈落落下防止セーフティガード
	if global_position.y < -1.5:
		global_position = Vector3(2.0, 1.4, 0.0)
		velocity = Vector3.ZERO

	# 釣り中の処理
	if current_state == State.CASTING:
		_process_casting(delta)
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta * 5.0)
		move_and_slide()
		return
	elif current_state == State.FISHING:
		_process_fishing(delta)
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta * 5.0)
		move_and_slide()
		return
	elif current_state == State.SITTING:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta * 5.0)
		move_and_slide()
		return

	# 入力方向の取得
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
		
		var target_angle = atan2(-direction.x, -direction.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, rotation_speed * delta)
		
		walk_anim_timer += delta * 14.0
		var bob_height = abs(sin(walk_anim_timer)) * 0.12
		visual_root.position.y = original_body_pos.y + bob_height
		visual_root.rotation.z = sin(walk_anim_timer * 0.5) * 0.08
		
		if hat:
			hat.rotation.x = sin(walk_anim_timer) * 0.06
			hat.rotation.z = cos(walk_anim_timer) * 0.04
		
		footprint_timer += delta
		if footprint_timer >= 0.28:
			footprint_timer = 0.0
			_spawn_footprint()
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta * 5.0)
		current_state = State.IDLE
		walk_anim_timer = 0.0
		visual_root.position.y = move_toward(visual_root.position.y, original_body_pos.y, delta * 2.0)
		visual_root.rotation.z = move_toward(visual_root.rotation.z, 0.0, delta * 3.0)
		if hat:
			hat.rotation.x = move_toward(hat.rotation.x, 0.0, delta * 2.0)
			hat.rotation.z = move_toward(hat.rotation.z, 0.0, delta * 2.0)
		
		# アイドリング呼吸
		var t = Time.get_ticks_msec() / 1000.0
		visual_root.position.y = original_body_pos.y + sin(t * 2.2) * 0.03

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			if current_state == State.FISHING or current_state == State.CASTING:
				_retrieve_rod()
			else:
				_start_casting()
		elif event.keycode == KEY_C:
			if current_state == State.IDLE:
				current_state = State.SITTING
				visual_root.position.y = original_body_pos.y - 0.25
			elif current_state == State.SITTING:
				current_state = State.IDLE
				visual_root.position.y = original_body_pos.y

func _start_casting() -> void:
	current_state = State.CASTING
	cast_timer = 0.0
	
	# 前方の海に向かってウキの着水目標地点を決定
	var forward = -visual_root.global_transform.basis.z.normalized()
	# もし海方向（Xマイナス）を向いていなければ海側へ
	if forward.x > -0.2:
		forward = Vector3(-1.0, 0.0, randf_range(-0.3, 0.3)).normalized()
		visual_root.rotation.y = atan2(-forward.x, -forward.z)
	
	bobber_target_pos = global_position + forward * randf_range(5.0, 9.0)
	bobber_target_pos.y = 0.05 # 水面の高さ

func _process_casting(delta: float) -> void:
	cast_timer += delta
	# 竿を後ろに振りかぶってから前へ振り下ろすモーション
	if cast_timer < 0.25:
		var p = cast_timer / 0.25
		rod_prop.rotation.x = lerp(0.0, deg_to_rad(-45.0), p)
	elif cast_timer < 0.55:
		var p = (cast_timer - 0.25) / 0.3
		rod_prop.rotation.x = lerp(deg_to_rad(-45.0), deg_to_rad(40.0), p)
	else:
		# キャスト完了 -> ウキを投下
		current_state = State.FISHING
		_spawn_bobber()

func _spawn_bobber() -> void:
	bobber_active = true
	bobber_time = 0.0
	if bobber_node:
		bobber_node.global_position = bobber_target_pos
		bobber_node.visible = true

func _process_fishing(delta: float) -> void:
	bobber_time += delta
	# 竿を構えて待機
	rod_prop.rotation.x = deg_to_rad(20.0) + sin(bobber_time * 1.5) * 0.03
	
	# 水面でウキが波に合わせてピョコピョコ揺れる
	if bobber_node and bobber_active:
		bobber_node.global_position.y = 0.05 + sin(bobber_time * 2.8) * 0.04
		bobber_node.rotation.z = sin(bobber_time * 3.2) * 0.12

func _retrieve_rod() -> void:
	current_state = State.IDLE
	bobber_active = false
	if bobber_node:
		bobber_node.visible = false
	rod_prop.transform = original_rod_transform

func set_lantern_enabled(enabled: bool) -> void:
	if lantern_light:
		lantern_light.visible = enabled
	if bobber_light:
		bobber_light.visible = enabled

func _spawn_footprint() -> void:
	var parent_world = get_parent()
	if parent_world and parent_world.has_method("add_footprint"):
		parent_world.add_footprint(global_position)
