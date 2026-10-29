extends Node2D

# タイトル画面（福岡・糸島 玄界灘フィッシング リニューアルUI）

var time_counter: float = 0.0

# 砂浜のカニ・蝶
var crabs: Array[Dictionary] = []
var butterflies: Array[Dictionary] = []

# タイトルの海中を泳ぐ玄界灘の魚たち
var title_fishes: Array[Dictionary] = []

@onready var btn_start: Button = $CanvasLayer/MenuCard/VBox/BtnStart
@onready var save_info_label: Label = $CanvasLayer/MenuCard/VBox/SaveInfoLabel
@onready var btn_new_game: Button = $CanvasLayer/MenuCard/VBox/BtnNewGame
@onready var btn_book: Button = $CanvasLayer/MenuCard/VBox/BtnBook
@onready var btn_help: Button = $CanvasLayer/MenuCard/VBox/BtnHelp
@onready var btn_quit: Button = $CanvasLayer/MenuCard/VBox/BtnQuit

@onready var fish_book_modal: Control = $CanvasLayer/FishBookModal
@onready var help_modal: Control = $CanvasLayer/HelpModal
@onready var help_close_btn: Button = $CanvasLayer/HelpModal/Card/VBox/HeaderHBox/CloseBtn
@onready var help_backdrop: ColorRect = $CanvasLayer/HelpModal/Backdrop

# シーン遷移用フェード
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect
var is_transitioning: bool = false
var fade_alpha: float = 0.0

var tex_crab: Texture2D

func _ready() -> void:
	tex_crab = GameData.load_texture("res://assets/beach_crab.png")
	
	btn_start.pressed.connect(_on_start_pressed)
	if btn_new_game:
		btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_book.pressed.connect(_on_book_pressed)
	btn_help.pressed.connect(_on_help_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	_update_start_buttons()
	
	if help_close_btn:
		help_close_btn.pressed.connect(func():
			SoundManager.play_sfx("book", 0.08, -2.0)
			help_modal.visible = false
		)
	if help_backdrop:
		help_backdrop.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				help_modal.visible = false
		)
		
	help_modal.visible = false
	fish_book_modal.visible = false
	
	_init_crabs_and_butterflies()
	_init_title_fishes()
	
	if fade_rect:
		fade_rect.color = Color(0.98, 0.96, 0.92, 0.0)

	SoundManager.play_bgm("bgm_title", 1.0)

	# 引数チェック（テストキャプチャ対応）
	var all_args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in all_args:
		if arg == "--capture-title":
			_run_capture_title_test()
			break
		elif arg == "--capture-help":
			_run_capture_help_test()
			break
		elif arg == "--capture-title-book":
			_run_capture_title_book_test()
			break

func _run_capture_title_test() -> void:
	await get_tree().create_timer(0.6).timeout
	var dir_path = "/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/"
	get_viewport().get_texture().get_image().save_png(dir_path + "view_title_screen.png")
	print("TITLE_CAPTURE_SAVED_OK")
	get_tree().quit()

func _run_capture_title_book_test() -> void:
	await get_tree().create_timer(0.2).timeout
	fish_book_modal.open_book()
	await get_tree().create_timer(0.4).timeout
	var dir_path = "/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/"
	get_viewport().get_texture().get_image().save_png(dir_path + "view_title_book.png")
	print("TITLE_BOOK_CAPTURE_SAVED_OK")
	get_tree().quit()

func _run_capture_help_test() -> void:
	await get_tree().create_timer(0.2).timeout
	help_modal.visible = true
	await get_tree().create_timer(0.4).timeout
	var dir_path = "/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/"
	get_viewport().get_texture().get_image().save_png(dir_path + "view_title_help.png")
	print("HELP_CAPTURE_SAVED_OK")
	get_tree().quit()

func _init_crabs_and_butterflies() -> void:
	crabs.clear()
	crabs.append({
		"pos": Vector2(850, 200),
		"origin": Vector2(850, 200),
		"vel": Vector2(-12, 3),
		"walk_time": 0.0,
		"pause_time": 1.5,
		"scale": Vector2(0.85, 0.85)
	})
	crabs.append({
		"pos": Vector2(920, 520),
		"origin": Vector2(920, 520),
		"vel": Vector2(10, -5),
		"walk_time": 0.0,
		"pause_time": 2.2,
		"scale": Vector2(0.75, 0.75)
	})

	butterflies.clear()
	butterflies.append({
		"pos": Vector2(960, 240),
		"origin": Vector2(960, 240),
		"angle": 0.0,
		"radius": 45.0,
		"speed": 1.3,
		"color": Color(0.25, 0.68, 1.0, 0.95)
	})
	butterflies.append({
		"pos": Vector2(740, 340),
		"origin": Vector2(740, 340),
		"angle": 1.2,
		"radius": 35.0,
		"speed": 1.1,
		"color": Color(0.95, 0.85, 0.35, 0.9)
	})

func _init_title_fishes() -> void:
	title_fishes.clear()
	# マダイ、マアジ、シロギス、チヌ、ヒラメ
	var configs = [
		{"species": "madai", "pos": Vector2(480, 480), "dir": Vector2(-0.8, -0.4).normalized(), "speed": 22.0, "scale": 0.10, "col": Color(1.0, 0.85, 0.88, 0.85)},
		{"species": "aji", "pos": Vector2(360, 380), "dir": Vector2(0.9, -0.3).normalized(), "speed": 34.0, "scale": 0.055, "col": Color(0.85, 0.95, 1.0, 0.85)},
		{"species": "kisu", "pos": Vector2(620, 260), "dir": Vector2(-0.85, 0.5).normalized(), "speed": 26.0, "scale": 0.048, "col": Color(0.95, 0.98, 1.0, 0.80)},
		{"species": "chinu", "pos": Vector2(520, 360), "dir": Vector2(-0.9, 0.2).normalized(), "speed": 20.0, "scale": 0.082, "col": Color(0.75, 0.82, 0.90, 0.85)},
		{"species": "hirame", "pos": Vector2(600, 490), "dir": Vector2(0.7, 0.4).normalized(), "speed": 18.0, "scale": 0.092, "col": Color(0.80, 0.85, 0.80, 0.75)}
	]
	for cfg in configs:
		var tex = GameData.load_texture("res://assets/fish_" + cfg["species"] + ".png")
		if not tex:
			tex = GameData.load_texture("res://assets/hd2d_fish_" + cfg["species"] + ".png")
		title_fishes.append({
			"tex": tex,
			"species": cfg["species"],
			"pos": cfg["pos"],
			"dir": cfg["dir"],
			"speed": cfg["speed"],
			"scale": cfg["scale"],
			"color": cfg["col"],
			"tail": 0.0,
			"wiggle_speed": cfg["speed"] * 0.18
		})

func _process(delta: float) -> void:
	time_counter += delta
	
	# カニ
	for c in crabs:
		if c["pause_time"] > 0.0:
			c["pause_time"] -= delta
		else:
			c["walk_time"] += delta
			c["pos"] += c["vel"] * delta
			if c["walk_time"] > 2.2:
				c["walk_time"] = 0.0
				c["pause_time"] = randf_range(1.5, 3.5)
				var offset = c["pos"] - c["origin"]
				if offset.length() > 40.0:
					c["vel"] = -c["vel"].normalized() * randf_range(10, 16)
				else:
					c["vel"] = Vector2(randf_range(-16, 16), randf_range(-10, 10))

	# 蝶
	for b in butterflies:
		b["angle"] += delta * b["speed"]
		b["pos"] = b["origin"] + Vector2(cos(b["angle"]) * b["radius"], sin(b["angle"] * 1.5) * (b["radius"] * 0.6))

	# 魚の遊泳
	for f in title_fishes:
		f["tail"] += delta * f["wiggle_speed"]
		f["pos"] += f["dir"] * f["speed"] * delta
		# 画面の海域（x: 200〜660, y: 180〜580）でターン
		if f["pos"].x < 180.0 or f["pos"].x > 660.0 or f["pos"].y < 160.0 or f["pos"].y > 580.0:
			var center = Vector2(420, 360)
			f["dir"] = (center - f["pos"]).normalized().rotated(randf_range(-0.4, 0.4))
			
	# シーン遷移フェード
	if is_transitioning:
		fade_alpha = move_toward(fade_alpha, 1.0, delta * 2.2)
		if fade_rect:
			fade_rect.color = Color(0.98, 0.96, 0.92, fade_alpha)
		if fade_alpha >= 1.0:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
			
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if help_modal.visible:
				help_modal.visible = false
			elif fish_book_modal.visible:
				fish_book_modal.close_book()
		elif event.keycode == KEY_TAB:
			_on_book_pressed()
			get_viewport().set_input_as_handled()

func _update_start_buttons() -> void:
	var has_save = GameData.has_save_file()
	if btn_start:
		btn_start.disabled = not has_save
		if has_save:
			btn_start.text = "つづきから"
			if save_info_label:
				save_info_label.text = "所持金: " + str(GameData.coins) + " G  |  図鑑: " + str(GameData.get_discovered_count()) + " / 10 種"
				save_info_label.visible = true
		else:
			btn_start.text = "つづきから (データなし)"
			if save_info_label:
				save_info_label.text = "新規冒険を始められます"

func _on_start_pressed() -> void:
	if is_transitioning: return
	GameData.load_game()
	SoundManager.play_sfx("coin", 0.05, 2.0)
	SoundManager.stop_bgm(0.8)
	is_transitioning = true
	fade_alpha = 0.0

func _on_new_game_pressed() -> void:
	if is_transitioning: return
	GameData.reset_save_data()
	SoundManager.play_sfx("coin", 0.05, 2.0)
	SoundManager.stop_bgm(0.8)
	is_transitioning = true
	fade_alpha = 0.0

func _on_book_pressed() -> void:
	SoundManager.play_sfx("book")
	fish_book_modal.open_book()

func _on_help_pressed() -> void:
	SoundManager.play_sfx("book")
	help_modal.visible = true

func _on_quit_pressed() -> void:
	SoundManager.play_sfx("coin")
	get_tree().quit()

func _draw() -> void:
	# 1. 砂浜の小石・貝殻
	var pebbles = [
		Vector2(780, 180), Vector2(850, 320), Vector2(820, 480), Vector2(900, 420)
	]
	for p in pebbles:
		draw_ellipse(p + Vector2(2, 2), 6.0, 3.5, Color(0.55, 0.48, 0.38, 0.35))
		draw_ellipse(p, 5.0, 3.5, Color(0.92, 0.90, 0.86, 0.95))

	var shells = [Vector2(810, 240), Vector2(890, 360), Vector2(860, 560)]
	for s in shells:
		draw_circle(s, 3.5, Color(0.98, 0.82, 0.85, 0.95))

	# 2. カニたち
	if tex_crab:
		for c in crabs:
			var w_phase = sin(time_counter * 12.0) * 1.5 if c["pause_time"] <= 0.0 else 0.0
			var c_pos = c["pos"] + Vector2(0, w_phase)
			draw_texture_rect(tex_crab, Rect2(c_pos, tex_crab.get_size() * c["scale"]), false)

	# 3. 蝶たち
	for b in butterflies:
		var b_pos = b["pos"]
		var flap = abs(sin(time_counter * 9.0))
		draw_ellipse(b_pos + Vector2(-3.0 * flap, -2), 4.5 * flap, 5.5, b["color"])
		draw_ellipse(b_pos + Vector2(3.0 * flap, -2), 4.5 * flap, 5.5, b["color"])
		draw_circle(b_pos, 1.2, Color(0.1, 0.1, 0.1, 0.85))

	# 4. タイトル画面の海中を泳ぐ魚たち（透き通る水面下の魚影）
	for f in title_fishes:
		if f["tex"]:
			var rot = f["dir"].angle() + sin(f["tail"]) * 0.08
			var tr = Transform2D(rot, f["pos"])
			draw_set_transform_matrix(tr)
			var sz = f["tex"].get_size() * f["scale"]
			draw_texture_rect(f["tex"], Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y), false, f["color"])
			draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			# プロシージャルシルエット
			var rot = f["dir"].angle() + sin(f["tail"]) * 0.08
			var tr = Transform2D(rot, f["pos"])
			draw_set_transform_matrix(tr)
			draw_ellipse(Vector2.ZERO, 16.0, 6.0, Color(0.12, 0.24, 0.32, 0.65))
			draw_set_transform_matrix(Transform2D.IDENTITY)
