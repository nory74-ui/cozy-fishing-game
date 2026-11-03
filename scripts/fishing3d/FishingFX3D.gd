extends Node3D
class_name FishingFX3D

# --- 3D釣り演出・フィッシングライン & パーティクルエフェクト ---

var line_mesh_instance: MeshInstance3D
var imm_mesh: ImmediateMesh
var line_mat: StandardMaterial3D

# エフェクト素材
var splash_mesh: SphereMesh
var splash_mat: StandardMaterial3D
var ring_mesh: TorusMesh
var ring_mat: StandardMaterial3D

func _ready() -> void:
	# 釣り糸レンダラーの初期化
	imm_mesh = ImmediateMesh.new()
	line_mat = StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.95, 0.95, 0.98, 0.75)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	line_mesh_instance = MeshInstance3D.new()
	line_mesh_instance.mesh = imm_mesh
	line_mesh_instance.material_override = line_mat
	add_child(line_mesh_instance)

	# 水しぶき用マテリアル
	splash_mat = StandardMaterial3D.new()
	splash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	splash_mat.albedo_color = Color(0.9, 0.96, 1.0, 0.85)
	splash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	splash_mesh = SphereMesh.new()
	splash_mesh.radius = 0.06
	splash_mesh.height = 0.12
	splash_mesh.material = splash_mat

	# 波紋リング用マテリアル
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.6)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.35
	ring_mesh.outer_radius = 0.40
	ring_mesh.material = ring_mat

# 釣り糸の描画（竿先〜ウキ）
# tension: 0.0(たるみ) 〜 1.0(ピンと張る)
func update_line(rod_tip: Vector3, bobber_pos: Vector3, tension: float = 0.2, visible_line: bool = true) -> void:
	imm_mesh.clear_surfaces()
	if not visible_line:
		return

	imm_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	var segments = 16
	var sag = lerp(0.85, 0.05, clamp(tension, 0.0, 1.0)) # たるみ量
	var mid = (rod_tip + bobber_pos) * 0.5
	mid.y -= sag
	
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		# 2次ベジェ曲線
		var p0 = rod_tip.lerp(mid, t)
		var p1 = mid.lerp(bobber_pos, t)
		var pt = p0.lerp(p1, t)
		imm_mesh.surface_add_vertex(pt)
		
	imm_mesh.surface_end()

# 着水スプラッシュ
func spawn_water_splash(pos: Vector3, count: int = 12, force: float = 2.5) -> void:
	spawn_water_ripple(pos, 0.8)
	for i in range(count):
		var droplet = MeshInstance3D.new()
		droplet.mesh = splash_mesh
		droplet.position = pos + Vector3(randf_range(-0.1, 0.1), 0.05, randf_range(-0.1, 0.1))
		add_child(droplet)
		
		var dir = Vector3(randf_range(-1, 1), randf_range(1.2, 2.5), randf_range(-1, 1)).normalized()
		var vel = dir * force * randf_range(0.6, 1.4)
		_animate_droplet(droplet, vel)

func _animate_droplet(droplet: Node3D, initial_vel: Vector3) -> void:
	var tween = create_tween()
	var duration = 0.45
	var target_pos = droplet.position + Vector3(initial_vel.x * 0.35, -0.05, initial_vel.z * 0.35)
	
	# 上昇して落下
	tween.tween_property(droplet, "position:y", droplet.position.y + initial_vel.y * 0.22, duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(droplet, "position:y", 0.02, duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(droplet, "position:x", target_pos.x, duration)
	tween.parallel().tween_property(droplet, "position:z", target_pos.z, duration)
	tween.parallel().tween_property(droplet, "scale", Vector3(0.01, 0.01, 0.01), duration).set_delay(duration * 0.5)
	tween.tween_callback(droplet.queue_free)

# 水面の波紋リング
func spawn_water_ripple(pos: Vector3, max_scale: float = 1.6) -> void:
	var ripple = MeshInstance3D.new()
	ripple.mesh = ring_mesh
	ripple.position = Vector3(pos.x, 0.04, pos.z)
	ripple.scale = Vector3(0.1, 0.1, 0.1)
	add_child(ripple)

	var tween = create_tween()
	tween.tween_property(ripple, "scale", Vector3(max_scale, 0.2, max_scale), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(ripple.queue_free)

# 釣り上げ時の黄金キラキラスパークル
func spawn_catch_sparkles(pos: Vector3) -> void:
	for i in range(18):
		var star = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.08
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, randf_range(0.8, 1.0), 0.2, 0.9)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.9, 0.3)
		mat.emission_energy_multiplier = 3.0
		sm.material = mat
		star.mesh = sm
		star.position = pos + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))
		add_child(star)

		var tween = create_tween()
		var target_offset = Vector3(randf_range(-1.2, 1.2), randf_range(0.8, 2.2), randf_range(-1.2, 1.2))
		tween.tween_property(star, "position", star.position + target_offset, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(star, "scale", Vector3(0.01, 0.01, 0.01), 0.7).set_delay(0.2)
		tween.tween_callback(star.queue_free)
