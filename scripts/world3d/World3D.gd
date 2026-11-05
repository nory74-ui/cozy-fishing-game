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
@onready var fish_book_modal: CanvasLayer = $FishBookModal
@onready var fishing_shop_modal: CanvasLayer = get_node_or_null("FishingShopModal")
@onready var fishing_hud: CanvasLayer = $FishingHUD3D

@export var day_cycle_duration: float = 1200.0 # 1倍速(1x)で1日＝20分（ゆったり自然な時間経過）
const TIME_SPEED_PRESETS: Array[float] = [0.0, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0]
var time_speed_index: int = 3 # デフォルト: 1.0x
var time_speed_multiplier: float = 1.0
var current_time_of_day: float = 0.25
var is_time_paused: bool = false

var footprint_mesh: Mesh
var footprint_mat: StandardMaterial3D
var footprints: Array[Node3D] = []
const MAX_FOOTPRINTS: int = 50

# Xの動画（frame_001 / 003 / 007 / 009）と完全一致する見下ろし角（俯角55.6度・FOV 40度）
@export var camera_follow_speed: float = 5.0
var default_camera_offset: Vector3 = Vector3(0.0, 10.5, 7.2)
var closeup_camera_offset: Vector3 = Vector3(0.0, 0.38, 3.15) # 正面やや見下ろしのクローズアップ
var current_camera_offset: Vector3 = Vector3(0.0, 10.5, 7.2)
var default_camera_fov: float = 40.0
var closeup_camera_fov: float = 36.0
var is_catch_closeup: bool = false
var camera_tween: Tween = null
var camera_offset: Vector3:
	get: return current_camera_offset
	set(val): current_camera_offset = val

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
		SoundManager.sync_time_bgm(current_time_of_day, 1.0)

	if fishing_hud:
		if fish_book_modal and fishing_hud.has_signal("book_open_requested"):
			fishing_hud.book_open_requested.connect(func():
				fish_book_modal.open_book()
			)
		if fishing_shop_modal and fishing_hud.has_signal("shop_open_requested"):
			fishing_hud.shop_open_requested.connect(func():
				fishing_shop_modal.open_shop()
			)
		if fishing_hud.has_signal("time_jump_requested"):
			fishing_hud.time_jump_requested.connect(_jump_time_of_day)
		if fishing_hud.has_signal("time_speed_cycle_requested"):
			fishing_hud.time_speed_cycle_requested.connect(_cycle_time_speed)
		if fishing_hud.has_signal("time_speed_step_requested"):
			fishing_hud.time_speed_step_requested.connect(_step_time_speed)
		if fishing_hud.has_signal("catch_dialog_closed"):
			fishing_hud.catch_dialog_closed.connect(_on_catch_dialog_closed_reset_camera)

	var fishing_ctrl = get_node_or_null("RealFishingController3D")
	if fishing_ctrl and fishing_ctrl.has_signal("fish_caught"):
		fishing_ctrl.fish_caught.connect(_on_fish_caught_closeup)
	_sync_time_ui()

	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
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
	if not is_time_paused and time_speed_multiplier > 0.0:
		current_time_of_day += (delta * time_speed_multiplier) / day_cycle_duration
		if current_time_of_day >= 1.0:
			current_time_of_day = fmod(current_time_of_day, 1.0)
		_update_lighting(delta)
		if SoundManager:
			SoundManager.sync_time_bgm(current_time_of_day, 2.5)
	_sync_time_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			_jump_time_of_day()
		elif event.keycode == KEY_V:
			_cycle_time_speed()
		elif event.keycode == KEY_BRACKETLEFT or event.keycode == KEY_MINUS or event.keycode == KEY_COMMA:
			_step_time_speed(-1)
		elif event.keycode == KEY_BRACKETRIGHT or event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS or event.keycode == KEY_PERIOD:
			_step_time_speed(1)

func _jump_time_of_day() -> void:
	current_time_of_day = fmod(current_time_of_day + 0.25, 1.0)
	_update_lighting(0.0)
	if SoundManager:
		SoundManager.sync_time_bgm(current_time_of_day, 1.2)
	_sync_time_ui()

func _cycle_time_speed() -> void:
	time_speed_index = (time_speed_index + 1) % TIME_SPEED_PRESETS.size()
	time_speed_multiplier = TIME_SPEED_PRESETS[time_speed_index]
	_sync_time_ui()

func _step_time_speed(delta_step: int) -> void:
	time_speed_index = clampi(time_speed_index + delta_step, 0, TIME_SPEED_PRESETS.size() - 1)
	time_speed_multiplier = TIME_SPEED_PRESETS[time_speed_index]
	_sync_time_ui()

func _sync_time_ui() -> void:
	if fishing_hud and fishing_hud.has_method("update_time_display"):
		fishing_hud.update_time_display(current_time_of_day, time_speed_multiplier)
	var key_speed_lbl = get_node_or_null("CanvasLayer/KeyGuide/PanelTimeSpeed/Label")
	if key_speed_lbl:
		if time_speed_multiplier <= 0.0:
			key_speed_lbl.text = " [V] 時間速度: 停止(0x) "
		elif is_equal_approx(time_speed_multiplier, round(time_speed_multiplier)):
			key_speed_lbl.text = " [V] 時間速度: %dx " % int(round(time_speed_multiplier))
		else:
			key_speed_lbl.text = " [V] 時間速度: %sx " % str(time_speed_multiplier)

func _physics_process(delta: float) -> void:
	if not player or not camera_pivot or not camera:
		return

	if is_catch_closeup:
		# クローズアップ時：左側にダイアログ、右側に源さんとミケが美しく並ぶ黄金比フレーミング
		var target_pivot = player.global_position + Vector3(-0.68, 0.65, 0.0)
		camera_pivot.global_position = camera_pivot.global_position.lerp(target_pivot, delta * 7.0)
		camera.position = current_camera_offset
		camera.look_at(camera_pivot.global_position, Vector3.UP)
		return

	var target_pos = player.global_position + Vector3(-0.6, 0.0, 0.0)
	var fishing_ctrl = get_node_or_null("RealFishingController3D")
	if fishing_ctrl and fishing_ctrl.bobber_node and fishing_ctrl.bobber_node.visible:
		# ウキが着水・飛翔している間はプレイヤーとウキの中間点をフレーミングして絶対に画面外へ出さない
		var mid_x = lerp(player.global_position.x, fishing_ctrl.bobber_node.global_position.x, 0.38)
		var mid_z = lerp(player.global_position.z, fishing_ctrl.bobber_node.global_position.z, 0.25)
		target_pos = Vector3(mid_x, player.global_position.y, mid_z)
	target_pos.z = clamp(target_pos.z, -16.0, 15.0)
	target_pos.x = clamp(target_pos.x, -14.5, 6.5)
	camera_pivot.global_position = camera_pivot.global_position.lerp(target_pos, camera_follow_speed * delta)
	camera.position = current_camera_offset
	camera.look_at(camera_pivot.global_position, Vector3.UP)

func _on_fish_caught_closeup(_fish_data: Dictionary) -> void:
	is_catch_closeup = true
	_animate_camera_zoom(true)

func _on_catch_dialog_closed_reset_camera() -> void:
	is_catch_closeup = false
	_animate_camera_zoom(false)

func _animate_camera_zoom(to_closeup: bool) -> void:
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	camera_tween = create_tween().set_parallel(true)
	if to_closeup:
		camera_tween.tween_property(self, "current_camera_offset", closeup_camera_offset, 0.70).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if camera:
			camera_tween.tween_property(camera, "fov", closeup_camera_fov, 0.70).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		camera_tween.tween_property(self, "current_camera_offset", default_camera_offset, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if camera:
			camera_tween.tween_property(camera, "fov", default_camera_fov, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

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
		set_physics_process(false)
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
		set_physics_process(true)

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

	# 1.5 木製ロング桟橋から南向き（正面手前 +Z 方向）へキャスト検証＆竿先からの釣り糸クローズアップ
	if player and mike and fishing_ctrl:
		player.global_position = Vector3(-3.2, 0.48, -3.6)
		player.velocity = Vector3.ZERO
		player.set_facing_direction(Vector3(0.0, 0.0, 1.0)) # 南向き（画面手前方向）
		mike.global_position = Vector3(-2.1, 0.48, -3.5)
		mike.velocity = Vector3.ZERO

		fishing_ctrl._start_charging()
		fishing_ctrl.charge_power = 0.55
		fishing_ctrl._release_cast()
		fishing_ctrl._on_bobber_landed()

		camera_pivot.global_position = Vector3(-3.2, 0.3, -2.0)
		camera.position = camera_offset
		camera.look_at(camera_pivot.global_position, Vector3.UP)
	await get_tree().create_timer(0.6).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_boat.png")
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_pier_cast_south.png")

	# 1.6 竹竿の穂先（先端）から釣り糸が正確に出ていることを確認するクローズアップ撮影
	if player and camera and camera_pivot and fishing_ctrl:
		set_physics_process(false)
		var tip_pos = player.get_rod_tip_global_position()
		print("ROD_TIP_GLOBAL_POS: ", tip_pos, " BOBBER_POS: ", fishing_ctrl.bobber_node.global_position)
		camera_pivot.global_position = player.global_position + Vector3(0.0, 1.0, 0.8)
		camera.position = Vector3(1.8, 1.2, 2.2)
		camera.look_at(camera_pivot.global_position, Vector3.UP)
		await get_tree().create_timer(0.3).timeout
		var img_tip = get_viewport().get_texture().get_image()
		img_tip.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_rod_tip_line_closeup.png")
		camera.position = camera_offset
		set_physics_process(true)

	# 2. 野北の大波止・白灯台の前へ移動 & 向いている方向（南東〜南方向）へキャスト
	if player and mike and fishing_ctrl:
		player.global_position = Vector3(-4.2, 0.95, -11.2)
		player.velocity = Vector3.ZERO
		player.set_facing_direction(Vector3(-0.35, 0.0, 0.93).normalized()) # 大波止から南南西の湾内向き
		mike.global_position = Vector3(-2.8, 0.95, -11.2)
		mike.velocity = Vector3.ZERO

		fishing_ctrl.current_state = fishing_ctrl.State.IDLE
		fishing_ctrl._start_charging()
		fishing_ctrl.charge_power = 0.65
		fishing_ctrl._release_cast()
		fishing_ctrl._on_bobber_landed()
		fishing_ctrl.current_fish = FishDb.get_fish_dict("suzuki")
		fishing_ctrl._start_fish_approach()
		if fx_node:
			fx_node.spawn_water_splash(fishing_ctrl.bobber_node.global_position, 12, 2.0)

		camera_pivot.global_position = Vector3(-4.6, 0.5, -9.8)
		camera.position = camera_offset
		camera.look_at(camera_pivot.global_position, Vector3.UP)
	await get_tree().create_timer(0.6).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_pier_lighthouse.png")

	# 3. 本格ファイト中
	if fishing_ctrl and hud_node:
		fishing_ctrl.current_state = fishing_ctrl.State.FIGHTING
		fishing_ctrl.current_fish = FishDb.get_fish_dict("suzuki")
		fishing_ctrl.current_fish["is_first"] = true
		fishing_ctrl.fight_tension = 0.42
		fishing_ctrl.fight_distance = 7.4
		fishing_ctrl.fish_stamina = 0.72
		fishing_ctrl.is_fish_dashing = true
		hud_node.show_fight_ui("スズキ (シーバス)", fishing_ctrl.current_fish.get("weight_label", ""))
		hud_node.update_fight_status(0.58, 7.4, false, true, 0.72)
		if fx_node:
			fx_node.spawn_water_splash(Vector3(-5.8, 0.05, -8.2), 8, 2.5)
	await get_tree().create_timer(0.6).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_fight.png")

	# 4a. 3D釣り上げ（抜き上げ）アクション中
	if fishing_ctrl and hud_node:
		hud_node.hide_fight_ui()
		fishing_ctrl._start_landing_action()
		fishing_ctrl.landing_anim_timer = 0.35
	await get_tree().create_timer(0.10).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_landing_action.png")

	# 4b. 釣り上げ成功ダイアログ＆クローズアップ画面へのスムーズな接近
	if fishing_ctrl and hud_node:
		fishing_ctrl._land_fish()
	await get_tree().create_timer(0.85).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_catch.png")

	# 4c. 魚の説明を閉じた後に元の引きの画面へスムーズに戻る
	if hud_node:
		hud_node.hide_catch_result()
	await get_tree().create_timer(0.80).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_after_dialog_reset.png")

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

	# 5a. 潮風釣具店モーダル（竿タブ）
	if fishing_shop_modal:
		fishing_shop_modal.open_shop(0) # Tab.RODS
	await get_tree().create_timer(0.6).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_shop_rods.png")

	# 5b. 潮風釣具店モーダル（ライン・道糸タブ）
	if fishing_shop_modal:
		fishing_shop_modal._switch_tab(1) # Tab.LINES
	await get_tree().create_timer(0.4).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_shop_lines.png")

	# 5c. 潮風釣具店モーダル（エサ・ルアータブ）
	if fishing_shop_modal:
		fishing_shop_modal._switch_tab(3) # Tab.BAITS
	await get_tree().create_timer(0.4).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_shop_baits.png")

	# 5d. 潮風釣具店モーダル（魚売却タブ）
	if fishing_shop_modal:
		GameData.add_caught_fish(FishDb.get_fish_dict("aji"))
		GameData.add_caught_fish(FishDb.get_fish_dict("chinu"))
		fishing_shop_modal._switch_tab(4) # Tab.SELL
	await get_tree().create_timer(0.4).timeout
	img = get_viewport().get_texture().get_image()
	img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_nogita_3d_shop_sell.png")
	if fishing_shop_modal:
		fishing_shop_modal.close_shop()

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
