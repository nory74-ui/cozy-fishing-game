extends Node3D
class_name FishingWorld3D

# --- 福岡・糸島 野北海岸 3Dワールドマネージャー（Xの動画完全再現カメラ＆ライティング） ---

const FishDb = preload("res://scripts/fishing3d/FishDatabase3D.gd")

@onready var player: Node3D = $CharacterBarlock3D
@onready var mike: Node3D = $CompanionMike3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var fish_book_modal: Control = $FishBookModal
@onready var fishing_hud: CanvasLayer = $FishingHUD3D

@export var day_cycle_duration: float = 180.0
var current_time_of_day: float = 0.25
var is_time_paused: bool = false

var footprint_mesh: Mesh
var footprint_mat: StandardMaterial3D
var footprints: Array[Node3D] = []
const MAX_FOOTPRINTS: int = 50

# Xの動画（frame_001 / 003 / 007 / 009）と完全一致する見下ろし角（俯角55.6度・FOV 40度）
@export var camera_follow_speed: float = 5.0
var camera_offset: Vector3 = Vector3(0.0, 10.5, 7.2)

func _ready() -> void:
	_setup_camera()
	_setup_footprint_assets()
	_update_lighting(0.0)

	# 初期スポーン位置（Xの動画 frame_001.jpg と同じ波打ち際・海浜樹のそば）
	if player and mike and camera_pivot:
		player.global_position = Vector3(2.4, 0.32, 2.2)
		if player.has_node("VisualRoot"):
			player.get_node("VisualRoot").rotation.y = deg_to_rad(-25.0)
		mike.global_position = Vector3(3.2, 0.36, 2.6)
		camera_pivot.global_position = player.global_position + Vector3(-0.6, 0.0, 0.0)
		camera.position = camera_offset
		camera.look_at(camera_pivot.global_position, Vector3.UP)

	if SoundManager:
		SoundManager.play_ambient("ambient_waves")

	if fishing_hud and fish_book_modal:
		if fishing_hud.has_signal("book_open_requested"):
			fishing_hud.book_open_requested.connect(func():
				fish_book_modal.open_book()
			)

	for arg in OS.get_cmdline_args():
		if arg == "--capture-nogita-3d":
			_do_capture_nogita()
			break

func _setup_camera() -> void:
	if camera_pivot and camera:
		camera.fov = 40.0
		camera.position = camera_offset
		camera.look_at(camera_pivot.global_position, Vector3.UP)

func _setup_footprint_assets() -> void:
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.10
	cyl.bottom_radius = 0.09
	cyl.height = 0.01
	footprint_mesh = cyl

	footprint_mat = StandardMaterial3D.new()
	footprint_mat.albedo_color = Color(0.58, 0.46, 0.30, 0.45)
	footprint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	footprint_mat.roughness = 0.95
	footprint_mesh.material = footprint_mat

func add_footprint(pos: Vector3) -> void:
	if pos.x < 0.8 or pos.y < 0.0 or pos.y > 0.65:
		return

	var fp = MeshInstance3D.new()
	fp.mesh = footprint_mesh
	fp.position = Vector3(pos.x, pos.y + 0.01, pos.z)

	if player and player.get_node_or_null("VisualRoot"):
		fp.rotation.y = player.get_node("VisualRoot").rotation.y

	$FootprintContainer.add_child(fp)
	footprints.append(fp)

	if footprints.size() > MAX_FOOTPRINTS:
		var old = footprints.pop_front()
		if is_instance_valid(old):
			old.queue_free()

func _process(delta: float) -> void:
	if not is_time_paused:
		current_time_of_day += delta / day_cycle_duration
		if current_time_of_day >= 1.0:
			current_time_of_day -= 1.0
		_update_lighting(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			current_time_of_day = fmod(current_time_of_day + 0.25, 1.0)
			_update_lighting(0.0)

func _physics_process(delta: float) -> void:
	if player and camera_pivot:
		var target_pos = player.global_position + Vector3(-0.6, 0.0, 0.0)
		target_pos.z = clamp(target_pos.z, -14.5, 14.5)
		target_pos.x = clamp(target_pos.x, -9.5, 6.5)
		camera_pivot.global_position = camera_pivot.global_position.lerp(target_pos, camera_follow_speed * delta)

func _update_lighting(_delta: float) -> void:
	var sun_angle = (current_time_of_day - 0.25) * TAU

	if sun_light:
		sun_light.shadow_enabled = true
		sun_light.shadow_opacity = 0.78
		sun_light.shadow_blur = 1.2
		# Xの動画準拠：左上（北西）から右下（南東）へくっきりした木陰と船影を落とす太陽角度
		sun_light.rotation_degrees = Vector3(-52.0, -138.0, 0.0)

		var daylight_val = clamp(sin(sun_angle + PI * 0.5), -1.0, 1.0)

		if daylight_val > 0.2: # 昼
			sun_light.light_color = Color(1.0, 0.96, 0.88)
			sun_light.light_energy = lerp(0.65, 0.88, daylight_val)
			if player and player.has_method("set_lantern_enabled"):
				player.set_lantern_enabled(false)
			if world_env and world_env.environment:
				world_env.environment.fog_light_color = Color(0.62, 0.82, 0.86)
				world_env.environment.fog_density = 0.0005
		elif daylight_val > -0.2: # 夕方
			var sunset_factor = (daylight_val + 0.2) / 0.4
			sun_light.light_color = Color(1.0, 0.52, 0.26).lerp(Color(1.0, 0.95, 0.88), sunset_factor)
			sun_light.light_energy = lerp(0.32, 0.65, sunset_factor)
			if player and player.has_method("set_lantern_enabled"):
				player.set_lantern_enabled(true)
			if world_env and world_env.environment:
				world_env.environment.fog_light_color = Color(0.88, 0.48, 0.30)
				world_env.environment.fog_density = 0.0012
		else: # 夜
			sun_light.light_color = Color(0.12, 0.18, 0.38)
			sun_light.light_energy = 0.05
			if player and player.has_method("set_lantern_enabled"):
				player.set_lantern_enabled(true)
			if world_env and world_env.environment:
				world_env.environment.fog_light_color = Color(0.04, 0.06, 0.14)
				world_env.environment.fog_density = 0.0025

	if world_env and world_env.environment:
		var env = world_env.environment
		env.ambient_light_sky_contribution = 0.18
		var daylight_val = clamp(sin(sun_angle + PI * 0.5), -1.0, 1.0)
		if daylight_val > 0.0:
			env.background_energy_multiplier = lerp(0.20, 0.85, daylight_val)
			env.ambient_light_color = Color(0.78, 0.84, 0.80).lerp(Color(0.86, 0.88, 0.82), daylight_val)
			env.ambient_light_energy = lerp(0.20, 0.32, daylight_val)
		else:
			env.background_energy_multiplier = 0.06
			env.ambient_light_color = Color(0.06, 0.10, 0.20)
			env.ambient_light_energy = 0.15

# --- キャプチャ検証 ---
func _do_capture_nogita() -> void:
	is_time_paused = true
	current_time_of_day = 0.25
	_update_lighting(0.0)

	var fishing_ctrl = get_node_or_null("RealFishingController3D")
	var hud_node = get_node_or_null("FishingHUD3D")
	var fx_node = get_node_or_null("FishingFX3D")

	# 0. Tripoモデルのキャラクタークローズアップ（バーロック & ミケ）
	if player and mike and camera and camera_pivot:
		var spot_x = 3.8
		var spot_z = 2.0
		player.global_position = Vector3(spot_x, 0.30, spot_z)
		player.velocity = Vector3.ZERO
		if player.has_node("VisualRoot"):
			player.get_node("VisualRoot").rotation.y = deg_to_rad(12.0)
		mike.global_position = Vector3(spot_x + 0.75, 0.32, spot_z + 0.15)
		mike.velocity = Vector3.ZERO
		if mike.has_node("VisualRoot"):
			mike.get_node("VisualRoot").rotation.y = deg_to_rad(-18.0)
		camera_pivot.global_position = Vector3(spot_x + 0.35, 0.72, spot_z)
		camera.position = Vector3(0.0, 0.45, 3.2)
		camera.look_at(camera_pivot.global_position, Vector3.UP)
		await get_tree().create_timer(0.6).timeout
		var img_char = get_viewport().get_texture().get_image()
		img_char.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_characters_closeup.png")
		camera.position = camera_offset

	# 1. 砂浜でのバーロック＆ミケ（Xの動画 frame_001.jpg / frame_003.jpg 完全再現アングル）
	if player and mike:
		var p_x = 2.2
		var p_z = 2.4
		player.global_position = Vector3(p_x, 0.22, p_z)
		player.velocity = Vector3.ZERO
		if player.has_node("VisualRoot"):
			player.get_node("VisualRoot").rotation.y = deg_to_rad(-35.0)
		mike.global_position = Vector3(p_x + 0.85, 0.26, p_z + 0.45)
		mike.velocity = Vector3.ZERO

		camera_pivot.global_position = Vector3(1.6, 0.15, 2.5)
		camera.position = camera_offset
		camera.look_at(camera_pivot.global_position, Vector3.UP)

		add_footprint(Vector3(p_x + 0.5, 0.24, p_z + 0.2))
		add_footprint(Vector3(p_x + 1.0, 0.28, p_z + 0.4))
	await get_tree().create_timer(0.7).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_beach_day.png")

	# 1.5 木製ロング桟橋と中空の木造小舟 & 漁師の番屋デッキ（frame_007.jpg / frame_009.jpg 完全再現）
	if player and mike:
		player.global_position = Vector3(-1.8, 0.50, -3.6)
		player.velocity = Vector3.ZERO
		if player.has_node("VisualRoot"):
			player.get_node("VisualRoot").rotation.y = deg_to_rad(25.0)
		mike.global_position = Vector3(-0.7, 0.50, -3.5)
		mike.velocity = Vector3.ZERO
		camera_pivot.global_position = Vector3(-1.4, 0.3, -2.8)
		camera.position = camera_offset
		camera.look_at(camera_pivot.global_position, Vector3.UP)
	await get_tree().create_timer(0.6).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_boat.png")

	# 2. 野北の大波止・白灯台の前へ移動 & 3Dリアルフィッシング・キャスト
	if player and mike and fishing_ctrl:
		player.global_position = Vector3(-4.5, 0.98, -11.5)
		player.velocity = Vector3.ZERO
		mike.global_position = Vector3(-3.2, 0.98, -11.3)
		mike.velocity = Vector3.ZERO
		camera_pivot.global_position = Vector3(-5.0, 0.5, -11.2)
		camera.position = camera_offset
		camera.look_at(camera_pivot.global_position, Vector3.UP)

		fishing_ctrl.current_state = fishing_ctrl.State.WAITING
		fishing_ctrl.bobber_node.global_position = Vector3(-9.5, 0.05, -11.5)
		fishing_ctrl.bobber_node.visible = true
		if fx_node:
			fx_node.spawn_water_splash(Vector3(-9.5, 0.05, -11.5), 12, 2.0)
	await get_tree().create_timer(0.6).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_pier_lighthouse.png")

	# 3. 本格ファイト中
	if fishing_ctrl and hud_node:
		fishing_ctrl.current_state = fishing_ctrl.State.FIGHTING
		fishing_ctrl.current_fish = FishDb.get_fish_dict("suzuki")
		fishing_ctrl.current_fish["is_first"] = true
		fishing_ctrl.fight_tension = 0.62
		fishing_ctrl.fight_distance = 6.2
		hud_node.show_fight_ui("スズキ (シーバス)")
		hud_node.update_fight_status(0.62, 6.2, true)
		if fx_node:
			fx_node.spawn_water_splash(Vector3(-8.5, 0.05, -11.5), 8, 2.5)
	await get_tree().create_timer(0.6).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_fight.png")

	# 4. 釣り上げ成功
	if fishing_ctrl and hud_node:
		fishing_ctrl.current_state = fishing_ctrl.State.LANDING
		hud_node.hide_fight_ui()
		hud_node.show_catch_result(fishing_ctrl.current_fish)
		if fx_node:
			fx_node.spawn_catch_sparkles(player.global_position + Vector3(-1.0, 1.5, 0.0))
	await get_tree().create_timer(0.7).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_catch.png")

	# 5. お魚図鑑モーダル
	if hud_node:
		hud_node.hide_catch_result()
	if fish_book_modal:
		GameData.record_fish_catch("suzuki", 78.4)
		GameData.record_fish_catch("aji", 24.2)
		fish_book_modal.selected_species = "suzuki"
		fish_book_modal.open_book()
	await get_tree().create_timer(0.7).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_zukan.png")
	if fish_book_modal:
		fish_book_modal.close_book()

	# 6. 夕暮れの糸島サンセット
	current_time_of_day = 0.5
	_update_lighting(0.0)
	await get_tree().create_timer(0.5).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_sunset.png")

	# 7. 夜釣り（ランタン＆ケミホタル発光）
	current_time_of_day = 0.75
	_update_lighting(0.0)
	await get_tree().create_timer(0.5).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_night.png")

	get_tree().quit()
