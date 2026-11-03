extends Node3D

signal fish_approached
signal fish_bit

@export var species_id: String = "aji"

var mesh_inst: MeshInstance3D
var swim_speed: float = 1.2
var patrol_center: Vector3
var patrol_radius: float = 4.0
var angle: float = 0.0

enum State { PATROL, CHASE, BITE, FLEE }
var current_state: State = State.PATROL
var target_bobber: Node3D = null

func _ready() -> void:
	patrol_center = global_position
	angle = randf() * TAU
	
	mesh_inst = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(0.8, 0.3)
	quad.orientation = PlaneMesh.FACE_Y
	mesh_inst.mesh = quad
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.05, 0.15, 0.25, 0.6) # 水中の黒い魚影
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	add_child(mesh_inst)

func _process(delta: float) -> void:
	match current_state:
		State.PATROL:
			angle += delta * 0.5
			global_position.x = patrol_center.x + cos(angle) * patrol_radius
			global_position.z = patrol_center.z + sin(angle) * (patrol_radius * 0.6)
			global_position.y = 0.04
			rotation.y = -angle + PI/2.0
			
		State.CHASE:
			if target_bobber and is_instance_valid(target_bobber):
				var diff = target_bobber.global_position - global_position
				diff.y = 0
				if diff.length() < 0.4:
					current_state = State.BITE
					fish_bit.emit()
				else:
					var dir = diff.normalized()
					global_position += dir * swim_speed * 1.8 * delta
					look_at(target_bobber.global_position, Vector3.UP)
					rotation.x = 0
					rotation.z = 0

func on_bobber_landed(bobber: Node3D) -> void:
	var dist = global_position.distance_to(bobber.global_position)
	if dist < 6.0:
		target_bobber = bobber
		current_state = State.CHASE
		fish_approached.emit()
