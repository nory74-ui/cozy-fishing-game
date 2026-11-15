extends Node3D

# --- うみかぜ日和 タイトル画面（野北漁港 3D ライブジオラマ版） ---

const BASE_CAM_POS := Vector3(2.8, 2.7, 4.2)
const BASE_CAM_LOOK := Vector3(-8.2, 2.05, -3.2)
const BASE_BOBBER_POS := Vector3(-5.7, 0.02, -2.05)

const TIME_PRESETS := [
	{"label": "【昼】 12:00 [T]", "time": 0.25},
	{"label": "【夕】 18:00 [T]", "time": 0.50},
	{"label": "【夜】 0:00 [T]",  "time": 0.75},
	{"label": "【朝】 6:00 [T]",  "time": 0.00},
]

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $DirectionalLight3D
@onready var player: Node3D = $CharacterBarlock3D
@onready var mike: Node3D = $CompanionMike3D
@onready var camera: Camera3D = $TitleCamera
@onready var diorama_props: Node3D = $DioramaProps

@onready var btn_start: Button = $CanvasLayer/MenuCard/Margin/VBox/BtnStart
@onready var save_info_label: Label = $CanvasLayer/MenuCard/Margin/VBox/SaveSummary/Margin/SaveInfoLabel
@onready var btn_new_game: Button = $CanvasLayer/MenuCard/Margin/VBox/BtnNewGame
@onready var btn_book: Button = $CanvasLayer/MenuCard/Margin/VBox/BtnBook
@onready var btn_help: Button = $CanvasLayer/MenuCard/Margin/VBox/BtnHelp
@onready var btn_quit: Button = $CanvasLayer/MenuCard/Margin/VBox/BtnQuit
@onready var time_preview_btn: Button = $CanvasLayer/TopRightHud/TimePreviewBtn

@onready var fish_book_modal: CanvasLayer = $FishBookModal
@onready var help_modal: Control = $CanvasLayer/HelpModal
@onready var help_close_btn: Button = $CanvasLayer/HelpModal/Card/VBox/Header/BtnCloseHelp
@onready var help_backdrop: ColorRect = $CanvasLayer/HelpModal/Backdrop
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect

var is_fading_out: bool = false
var fade_alpha: float = 0.0
var is_capture_mode: bool = false
var current_preset_idx: int = 0

var player_visual_root: Node3D
var player_head_pivot: Node3D
var player_right_arm_pivot: Node3D
var mike_visual_root: Node3D
var mike_head_pivot: Node3D
var mike_tail_pivot: Node3D
var mike_right_paw_pivot: Node3D
var mike_bell_pivot: Node3D

var bobber_node: Node3D
var ripple_mesh: MeshInstance3D
var ripple_mat: StandardMaterial3D
var line_mesh_inst: MeshInstance3D
var line_immediate: ImmediateMesh

func is_ui_modal_open() -> bool:
	return true

func _ready() -> void:
	var args = OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if "--capture-nogita-3d" in args:
		get_tree().change_scene_to_file.call_deferred("res://scenes/world3d/World3D.tscn")
		return

	btn_start.pressed.connect(_on_start_pressed)
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_book.pressed.connect(_on_book_pressed)
	btn_help.pressed.connect(_on_help_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	time_preview_btn.pressed.connect(_on_time_preview_pressed)
	help_close_btn.pressed.connect(_close_help_modal)
	help_backdrop.gui_input.connect(_on_help_backdrop_input)

	if OS.has_feature("web"):
		btn_quit.visible = false

	_setup_diorama_actors()
	_setup_diorama_props()
	_apply_time_preset(0)
	_update_save_display()

	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 0)

	btn_start.grab_focus()
	_check_capture_args(args)

func _setup_diorama_actors() -> void:
	if player:
		player.set_physics_process(false)
		player.position = Vector3(-4.6, 0.48, -3.6)
		player_visual_root = player.get_node_or_null("VisualRoot")
		if player_visual_root:
			player_visual_root.rotation.y = deg_to_rad(-24.0)
			player_head_pivot = player_visual_root.find_child("HeadPivot", true, false) as Node3D
			player_right_arm_pivot = player_visual_root.find_child("RightArmPivot", true, false) as Node3D
			if player_right_arm_pivot:
				player_right_arm_pivot.rotation.x = deg_to_rad(-16.0)
		if player.has_method("set_facing_direction"):
			player.set_facing_direction(Vector3(-0.41, 0.0, 0.91).normalized())

	if mike:
		mike.set_physics_process(false)
		mike.position = Vector3(-5.45, 0.48, -3.35)
		mike_visual_root = mike.get_node_or_null("VisualRoot")
		if mike_visual_root:
			mike_visual_root.rotation.y = deg_to_rad(32.0)
			mike_head_pivot = mike_visual_root.find_child("HeadPivot", true, false) as Node3D
			mike_tail_pivot = mike_visual_root.find_child("TailPivot", true, false) as Node3D
			mike_right_paw_pivot = mike_visual_root.find_child("RightFrontPawPivot", true, false) as Node3D
			mike_bell_pivot = mike_visual_root.find_child("BellPivot", true, false) as Node3D

	if camera:
		camera.position = BASE_CAM_POS
		camera.look_at(BASE_CAM_LOOK, Vector3.UP)

func _setup_diorama_props() -> void:
	if not diorama_props:
		return

	# ウキ（赤白の海釣り浮き＋水面下の淡いエメラルド光）
	bobber_node = Node3D.new()
	bobber_node.name = "DecorativeBobber"
	bobber_node.position = BASE_BOBBER_POS
	diorama_props.add_child(bobber_node)

	var body_top = MeshInstance3D.new()
	var top_m = SphereMesh.new()
	top_m.radius = 0.068
	top_m.height = 0.14
	var top_mat = StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.95, 0.22, 0.16)
	top_mat.roughness = 0.35
	top_mat.emission_enabled = true
	top_mat.emission = Color(0.85, 0.18, 0.12)
	top_mat.emission_energy_multiplier = 0.28
	top_m.material = top_mat
	body_top.mesh = top_m
	body_top.position.y = 0.03
	bobber_node.add_child(body_top)

	var tip = MeshInstance3D.new()
	var tip_m = CylinderMesh.new()
	tip_m.top_radius = 0.012
	tip_m.bottom_radius = 0.016
	tip_m.height = 0.11
	var tip_mat = StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.98, 0.94, 0.82)
	tip_mat.roughness = 0.4
	tip_m.material = tip_mat
	tip.mesh = tip_m
	tip.position.y = 0.12
	bobber_node.add_child(tip)

	var glow_light = OmniLight3D.new()
	glow_light.light_color = Color(0.28, 0.96, 0.72)
	glow_light.light_energy = 0.9
	glow_light.omni_range = 2.0
	glow_light.shadow_enabled = false
	glow_light.position.y = -0.05
	bobber_node.add_child(glow_light)

	ripple_mesh = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 0.24
	tor.outer_radius = 0.30
	ripple_mat = StandardMaterial3D.new()
	ripple_mat.albedo_color = Color(0.92, 0.99, 1.0, 0.55)
	ripple_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ripple_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tor.material = ripple_mat
	ripple_mesh.mesh = tor
	ripple_mesh.position = Vector3(BASE_BOBBER_POS.x, 0.025, BASE_BOBBER_POS.z)
	diorama_props.add_child(ripple_mesh)

	# 竿先からウキへ伸びる釣り糸
	line_immediate = ImmediateMesh.new()
	line_mesh_inst = MeshInstance3D.new()
	line_mesh_inst.name = "DecorativeFishingLine"
	line_mesh_inst.mesh = line_immediate
	var line_mat = StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.94, 0.97, 1.0, 0.88)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mesh_inst.material_override = line_mat
	diorama_props.add_child(line_mesh_inst)

func _update_fishing_line() -> void:
	if not line_immediate or not bobber_node or not player:
		return
	var tip_pos: Vector3
	if player.has_method("get_rod_tip_global_position"):
		tip_pos = player.get_rod_tip_global_position()
	else:
		tip_pos = player.global_position + Vector3(-0.35, 1.85, 0.45)

	var end_pos: Vector3 = bobber_node.global_position + Vector3(0.0, 0.06, 0.0)
	line_immediate.clear_surfaces()
	line_immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	const SEGMENTS := 8
	for i in range(SEGMENTS + 1):
		var u = float(i) / float(SEGMENTS)
		var p = tip_pos.lerp(end_pos, u)
		# ごく自然なたわみ
		p.y -= sin(u * PI) * 0.11
		line_immediate.surface_add_vertex(p)
	line_immediate.surface_end()

func _apply_time_preset(idx: int) -> void:
	current_preset_idx = posmod(idx, TIME_PRESETS.size())
	var preset: Dictionary = TIME_PRESETS[current_preset_idx]
	var t_day: float = preset["time"]
	if time_preview_btn:
		time_preview_btn.text = preset["label"]

	var daylight_val: float = clamp(sin(t_day * TAU), -1.0, 1.0)
	var total_hours: float = fmod((t_day * 24.0) + 6.0, 24.0)
	var is_morning: bool = (total_hours >= 4.0 and total_hours < 12.0)

	if sun_light:
		sun_light.shadow_enabled = true
		sun_light.shadow_opacity = 0.78
		sun_light.shadow_blur = 1.2
		sun_light.rotation_degrees = Vector3(-52.0, -138.0, 0.0)

		if daylight_val > 0.25:
			sun_light.light_color = Color(1.0, 0.96, 0.88)
			sun_light.light_energy = lerp(0.68, 0.90, daylight_val)
			_set_lantern(false)
			_set_env_colors(
				Color(0.28, 0.58, 0.90), Color(0.68, 0.87, 0.94),
				Color(0.62, 0.82, 0.86), 0.0005,
				Color(0.86, 0.88, 0.82), 0.34, 0.85
			)
		elif daylight_val > -0.2 and is_morning:
			var dawn_factor = (daylight_val + 0.2) / 0.45
			sun_light.light_color = Color(0.98, 0.72, 0.56).lerp(Color(1.0, 0.96, 0.88), dawn_factor)
			sun_light.light_energy = lerp(0.42, 0.68, dawn_factor)
			_set_lantern(dawn_factor < 0.35)
			_set_env_colors(
				Color(0.42, 0.56, 0.78), Color(0.94, 0.76, 0.68),
				Color(0.86, 0.76, 0.72), 0.0009,
				Color(0.80, 0.82, 0.80), 0.28, 0.58
			)
		elif daylight_val > -0.2:
			var sunset_factor = (daylight_val + 0.2) / 0.45
			sun_light.light_color = Color(1.0, 0.52, 0.26).lerp(Color(1.0, 0.95, 0.88), sunset_factor)
			sun_light.light_energy = lerp(0.35, 0.68, sunset_factor)
			_set_lantern(true, 0.55)
			_set_env_colors(
				Color(0.26, 0.30, 0.56), Color(0.96, 0.56, 0.34),
				Color(0.88, 0.48, 0.30), 0.0012,
				Color(0.76, 0.62, 0.58), 0.28, 0.50
			)
		else:
			sun_light.light_color = Color(0.18, 0.26, 0.48)
			sun_light.light_energy = 0.10
			_set_lantern(true, 1.25)
			_set_env_colors(
				Color(0.03, 0.06, 0.15), Color(0.09, 0.14, 0.26),
				Color(0.06, 0.10, 0.20), 0.0018,
				Color(0.12, 0.18, 0.32), 0.24, 0.14
			)

	if SoundManager:
		SoundManager.sync_time_bgm(t_day, 1.2)

func _set_lantern(enabled: bool, energy: float = 1.25) -> void:
	if player and player.has_method("set_lantern_enabled"):
		player.set_lantern_enabled(enabled)
		var lantern := player.get_node_or_null("VisualRoot/LanternLight") as OmniLight3D
		if not lantern:
			lantern = player.find_child("LanternLight", true, false) as OmniLight3D
		if lantern:
			lantern.light_energy = energy

func _set_env_colors(sky_top: Color, sky_horizon: Color, fog_col: Color, fog_dens: float, amb_col: Color, amb_energy: float, bg_mult: float) -> void:
	if not world_env or not world_env.environment:
		return
	var env = world_env.environment
	env.ambient_light_sky_contribution = 0.18
	env.ambient_light_color = amb_col
	env.ambient_light_energy = amb_energy
	env.background_energy_multiplier = bg_mult
	env.fog_light_color = fog_col
	env.fog_density = fog_dens
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
		sky_mat.sky_top_color = sky_top
		sky_mat.sky_horizon_color = sky_horizon
		sky_mat.ground_horizon_color = sky_horizon

func _check_capture_args(args: PackedStringArray) -> void:
	if "--capture-title" in args:
		is_capture_mode = true
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.35).timeout
		var img = get_viewport().get_texture().get_image()
		img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_title_screen.png")
		print("TITLE_CAPTURE_SAVED_OK")
		get_tree().quit()
	elif "--capture-title-sunset" in args:
		is_capture_mode = true
		_apply_time_preset(1)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.35).timeout
		var img = get_viewport().get_texture().get_image()
		img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_title_sunset.png")
		print("TITLE_SUNSET_CAPTURE_SAVED_OK")
		get_tree().quit()
	elif "--capture-help" in args:
		is_capture_mode = true
		_on_help_pressed()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.25).timeout
		var img = get_viewport().get_texture().get_image()
		img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_title_help.png")
		print("HELP_CAPTURE_SAVED_OK")
		get_tree().quit()
	elif "--capture-title-book" in args:
		is_capture_mode = true
		_on_book_pressed()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.25).timeout
		var img = get_viewport().get_texture().get_image()
		img.save_png("/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/view_title_book.png")
		print("TITLE_BOOK_CAPTURE_SAVED_OK")
		get_tree().quit()

func _process(delta: float) -> void:
	var t = Time.get_ticks_msec() / 1000.0

	# ゆるやかな海風カメラ揺らぎ（キャプチャ直後は落ち着いた基準構図に寄せる）
	if camera:
		var sway_amp = 0.0 if is_capture_mode else 1.0
		var cam_offset = Vector3(cos(t * 0.28) * 0.20, sin(t * 0.34) * 0.07, sin(t * 0.22) * 0.16) * sway_amp
		camera.position = BASE_CAM_POS + cam_offset
		camera.look_at(BASE_CAM_LOOK + Vector3(sin(t * 0.18) * 0.06, 0.0, 0.0) * sway_amp, Vector3.UP)

	# 源さんのゆったり呼吸＆竿揺れ
	if player_visual_root:
		player_visual_root.position.y = sin(t * 1.9) * 0.015
		player_visual_root.rotation.z = sin(t * 1.1) * 0.015
	if player_head_pivot:
		player_head_pivot.rotation.y = sin(t * 0.9) * 0.07
	if player_right_arm_pivot:
		player_right_arm_pivot.rotation.x = deg_to_rad(-16.0) + sin(t * 1.8) * 0.035

	# ミケのしっぽゆらゆら＆ご挨拶ポーズ
	if mike_visual_root:
		mike_visual_root.position.y = sin(t * 2.5) * 0.012
	if mike_tail_pivot:
		mike_tail_pivot.rotation.y = sin(t * 3.8) * 0.34
	if mike_head_pivot:
		mike_head_pivot.rotation.z = sin(t * 1.6) * 0.07
	if mike_right_paw_pivot:
		mike_right_paw_pivot.rotation.x = deg_to_rad(-28.0 + sin(t * 3.0) * 14.0)
	if mike_bell_pivot:
		mike_bell_pivot.rotation.z = sin(t * 3.2) * 0.12

	# ウキと波紋のアニメーション
	if bobber_node:
		bobber_node.position.y = BASE_BOBBER_POS.y + sin(t * 2.1) * 0.025
		bobber_node.rotation.z = sin(t * 1.6) * 0.06
	if ripple_mesh and ripple_mat:
		var cycle = fmod(t * 0.45, 1.0)
		var r_scale = 0.65 + cycle * 1.85
		ripple_mesh.scale = Vector3(r_scale, 1.0, r_scale)
		ripple_mat.albedo_color.a = (1.0 - cycle) * 0.55

	_update_fishing_line()

	if is_fading_out and fade_rect:
		fade_alpha = min(fade_alpha + delta * 2.5, 1.0)
		fade_rect.color = Color(0, 0, 0, fade_alpha)
		if fade_alpha >= 1.0:
			get_tree().change_scene_to_file("res://scenes/world3d/World3D.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if is_fading_out:
		return
	if fish_book_modal and fish_book_modal.visible:
		return
	if help_modal and help_modal.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_help_modal()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			_on_time_preview_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB or event.keycode == KEY_B:
			_on_book_pressed()
			get_viewport().set_input_as_handled()

func _update_save_display() -> void:
	var has_save = GameData.has_save_file()
	if has_save:
		btn_start.text = "つづきから  （釣りへ出発）"
		save_info_label.text = "所持金: %d G  |  図鑑: %d / %d 種" % [GameData.coins, GameData.get_discovered_count(), GameData.get_total_species_count()]
	else:
		btn_start.text = "釣りをはじめる  （出発）"
		save_info_label.text = "セーブデータなし（野北漁港から開始）"

func _on_time_preview_pressed() -> void:
	_apply_time_preset(current_preset_idx + 1)

func _on_start_pressed() -> void:
	if is_fading_out:
		return
	is_fading_out = true

func _on_new_game_pressed() -> void:
	if is_fading_out:
		return
	GameData.reset_save_data()
	_update_save_display()
	is_fading_out = true

func _on_book_pressed() -> void:
	if is_fading_out:
		return
	if fish_book_modal and fish_book_modal.has_method("open_book"):
		fish_book_modal.open_book()

func _on_help_pressed() -> void:
	if is_fading_out:
		return
	if help_modal:
		help_modal.visible = true

func _close_help_modal() -> void:
	if help_modal:
		help_modal.visible = false

func _on_help_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_help_modal()

func _on_quit_pressed() -> void:
	get_tree().quit()
