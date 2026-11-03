extends Node3D

signal landed(pos: Vector3)
signal fish_bitten(species_id: String)

var is_active: bool = false
var is_floating: bool = false
var float_time: float = 0.0

var bobber_mesh: MeshInstance3D

func _ready() -> void:
	visible = false
	
	bobber_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	bobber_mesh.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.25, 0.15) # 赤いウキ
	mat.roughness = 0.3
	bobber_mesh.material_override = mat
	add_child(bobber_mesh)

func cast_to(from_pos: Vector3, target_pos: Vector3) -> void:
	is_active = true
	is_floating = false
	visible = true
	global_position = from_pos + Vector3(0, 1.2, 0)
	
	var tween = create_tween().set_parallel(true)
	# 水平移動
	tween.tween_property(self, "global_position:x", target_pos.x, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:z", target_pos.z, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 垂直移動（放物線）
	var y_tween = create_tween()
	y_tween.tween_property(self, "global_position:y", from_pos.y + 2.5, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	y_tween.tween_property(self, "global_position:y", 0.08, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await y_tween.finished
	is_floating = true
	SoundManager.play_sfx("sfx_splash")
	landed.emit(global_position)

func _process(delta: float) -> void:
	if is_floating:
		float_time += delta * 3.0
		bobber_mesh.position.y = sin(float_time) * 0.03

func bite_reaction() -> void:
	# ウキが水中に沈むアクション
	var tween = create_tween()
	tween.tween_property(bobber_mesh, "position:y", -0.15, 0.12)
	tween.tween_property(bobber_mesh, "position:y", 0.0, 0.2)

func reset_bobber() -> void:
	is_active = false
	is_floating = false
	visible = false
