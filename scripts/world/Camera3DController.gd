extends Camera3D

@export var target_node: Node3D = null
@export var offset: Vector3 = Vector3(0, 8.5, 11.0)
@export var smooth_speed: float = 4.5

var env_node: WorldEnvironment = null

func _ready() -> void:
	fov = 38.0 # ジオラマ感が出る望遠画角
	current = true
	env_node = get_parent().get_node_or_null("HD2DEnvironment")

func _process(delta: float) -> void:
	if not target_node: return
	
	var desired_pos = target_node.global_position + offset
	global_position = global_position.lerp(desired_pos, delta * smooth_speed)
	look_at(target_node.global_position + Vector3(0, 0.8, 0), Vector3.UP)

	# プレイヤー距離に合わせて被写界深度（DoF）の焦点を自動同期
	if env_node and env_node.camera_attributes is CameraAttributesPractical:
		var cam_attr: CameraAttributesPractical = env_node.camera_attributes
		var dist = global_position.distance_to(target_node.global_position)
		cam_attr.dof_blur_far_distance = dist + 7.0
		cam_attr.dof_blur_near_distance = max(dist - 5.0, 1.0)
