extends Node2D

# タイトル画面（水彩のこもれび湖畔、桟橋でくつろぐおじさん、泳ぐ魚たち、木漏れ日エフェクト）

var tex_grass: Texture2D
var tex_water: Texture2D
var tex_tree: Texture2D

var time_counter: float = 0.0

# 木漏れ日・花びらパーティクル
var petals: Array[Dictionary] = []

# 背景の魚影（タイトル画面を泳ぐ魚たち）
var title_fishes: Array[Dictionary] = []

@onready var btn_start: Button = $CanvasLayer/MenuCard/VBox/BtnStart
@onready var btn_new_game: Button = $CanvasLayer/MenuCard/VBox/BtnNewGame
@onready var btn_book: Button = $CanvasLayer/MenuCard/VBox/BtnBook
@onready var btn_help: Button = $CanvasLayer/MenuCard/VBox/BtnHelp
@onready var btn_quit: Button = $CanvasLayer/MenuCard/VBox/BtnQuit
@onready var title_logo_rect: TextureRect = $CanvasLayer/TitleCard/VBox/TitleLogoRect

@onready var fish_book_modal: Control = $CanvasLayer/FishBookModal
@onready var help_modal: Control = $CanvasLayer/HelpModal
@onready var help_close_btn: Button = $CanvasLayer/HelpModal/Card/VBox/HeaderHBox/CloseBtn
@onready var help_backdrop: ColorRect = $CanvasLayer/HelpModal/Backdrop

# シーン遷移用フェード
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect
var is_transitioning: bool = false
var fade_alpha: float = 0.0

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	tex_grass = GameData.load_texture("res://assets/watercolor_grass_bg.jpg")
	tex_water = GameData.load_texture("res://assets/watercolor_water.jpg")
	tex_tree = GameData.load_texture("res://assets/watercolor_tree.png")
	
	if title_logo_rect:
		title_logo_rect.texture = GameData.load_texture("res://assets/title_logo.png")
	
	btn_start.pressed.connect(_on_start_pressed)
	if btn_new_game:
		btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_book.pressed.connect(_on_book_pressed)
	btn_help.pressed.connect(_on_help_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	_update_start_buttons()
	
	if help_close_btn:
		GameData.apply_pastel_button_style(help_close_btn)
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
	
	_init_particles()
	_init_title_fishes()
	
	if fade_rect:
		fade_rect.color = Color(0.98, 0.96, 0.92, 0.0)

	SoundManager.play_bgm("bgm_title", 1.0)

	for arg in OS.get_cmdline_user_args():
		if arg == "--capture-title":
			_run_capture_title_test()
		elif arg == "--capture-help":
			_run_capture_help_test()
		elif arg == "--capture-title-book":
			_run_capture_title_book_test()

func _run_capture_title_test() -> void:
	await get_tree().create_timer(0.5).timeout
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

func _init_particles() -> void:
	petals.clear()
	for i in range(25):
		petals.append({
			"pos": Vector2(randf_range(0, 1152), randf_range(0, 648)),
			"vel": Vector2(randf_range(15, 45), randf_range(20, 50)),
			"phase": randf() * TAU,
			"size": randf_range(3.5, 6.0),
			"color": Color(1.0, 0.82, 0.88, randf_range(0.4, 0.75)) # 桜色の花びら
		})

func _init_title_fishes() -> void:
	title_fishes.clear()
	# 錦鯉、ヤマメ、黄金の主、ナマズ、ニジマスたち
	var configs = [
		{"species": "koi", "pos": Vector2(860, 460), "dir": Vector2(-1, 0.2).normalized(), "speed": 20.0, "scale": 0.095, "col": Color.WHITE},
		{"species": "golden_koi", "pos": Vector2(980, 360), "dir": Vector2(-0.7, -0.7).normalized(), "speed": 16.0, "scale": 0.13, "col": Color(1.4, 1.25, 0.55)},
		{"species": "yamame", "pos": Vector2(760, 480), "dir": Vector2(0.85, -0.5).normalized(), "speed": 30.0, "scale": 0.075, "col": Color.WHITE},
		{"species": "catfish", "pos": Vector2(920, 560), "dir": Vector2(-0.8, 0.4).normalized(), "speed": 18.0, "scale": 0.095, "col": Color.WHITE},
		{"species": "rainbow_trout", "pos": Vector2(820, 330), "dir": Vector2(0.9, 0.4).normalized(), "speed": 26.0, "scale": 0.08, "col": Color.WHITE}
	]
	for cfg in configs:
		var tex_name = cfg["species"]
		var tex = GameData.load_texture("res://assets/hd2d_fish_" + tex_name + ".png")
		if not tex:
			tex = GameData.load_texture("res://assets/fish_" + tex_name + ".png")
		title_fishes.append({
			"tex": tex,
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
	
	# 花びらパーティクル
	for p in petals:
		p.pos += p.vel * delta
		p.pos.x += sin(time_counter * 1.5 + p.phase) * 12.0 * delta
		if p.pos.y > 660.0: p.pos.y = -20.0
		if p.pos.x > 1170.0: p.pos.x = -20.0
		
	# 魚の遊泳
	for f in title_fishes:
		f.tail += delta * f.wiggle_speed
		f.pos += f.dir * f.speed * delta
		# 境界反転（湖のエリア x: 500〜1100, y: 260〜620）
		if f.pos.x < 520.0 or f.pos.x > 1080.0 or f.pos.y < 280.0 or f.pos.y > 600.0:
			var center = Vector2(800, 440)
			f.dir = (center - f.pos).normalized().rotated(randf_range(-0.4, 0.4))
			
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

func _update_start_buttons() -> void:
	var has_save = GameData.has_save_file()
	if btn_start:
		btn_start.disabled = not has_save
		if has_save:
			btn_start.text = "つづきから"
		else:
			btn_start.text = "つづきから (データなし)"
	if btn_new_game:
		btn_new_game.text = "はじめから"

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
	# 1. 水彩草地背景
	if tex_grass:
		draw_texture(tex_grass, Vector2(0, 0), Color(0.98, 0.98, 0.96, 1.0))
		draw_texture(tex_grass, Vector2(1024, 0), Color(0.98, 0.98, 0.96, 1.0))
	else:
		draw_rect(Rect2(0, 0, 1152, 648), Color("#d8f3dc"))
		
	# 2. 小道（左下から桟橋の付け根へ向かう小道）
	draw_line(Vector2(0, 560), Vector2(490, 480), Color(0.95, 0.91, 0.82, 0.85), 85.0)
	draw_circle(Vector2(480, 480), 65.0, Color(0.95, 0.91, 0.82, 0.85))

	# 3. 湖の水面（右側に広がる穏やかな水彩の湖）
	var pond_center = Vector2(850, 430)
	var pond_rx = 360.0
	var pond_ry = 230.0
	
	# 岸辺の砂浜
	draw_ellipse(pond_center, pond_rx + 28.0, pond_ry + 22.0, Color(0.92, 0.86, 0.78, 0.75))
	
	# 水面ポリゴン
	var pts: PackedVector2Array = []
	var uvs: PackedVector2Array = []
	for i in range(48):
		var ang = (TAU / 48) * i
		var pt = pond_center + Vector2(cos(ang) * pond_rx, sin(ang) * pond_ry)
		pts.append(pt)
		uvs.append(pt / 1024.0)
		
	if tex_water:
		draw_polygon(pts, [Color(0.92, 0.96, 1.0, 0.92)], uvs, tex_water)
	else:
		draw_colored_polygon(pts, Color(0.65, 0.82, 0.95, 0.85))
		
	draw_ellipse(pond_center + Vector2(20, 10), pond_rx * 0.65, pond_ry * 0.65, Color(0.35, 0.60, 0.85, 0.45))
	draw_ellipse(pond_center, pond_rx, pond_ry, Color(0.32, 0.52, 0.72, 0.75), false, 2.5)

	# 4. 水面の波線
	var wave_col = Color(1, 1, 1, 0.45)
	for w in range(4):
		var wy = pond_center.y - 80 + w * 45
		var wx = pond_center.x - 120 + sin(time_counter * 1.4 + w) * 20.0
		draw_arc(Vector2(wx, wy), 24.0, PI * 0.8, PI * 0.2, 10, wave_col, 2.0)

	# 5. 水彩の睡蓮
	var lily_positions = [Vector2(720, 320), Vector2(760, 350), Vector2(980, 530), Vector2(1050, 480)]
	for lp in lily_positions:
		draw_arc(lp, 20.0, 0.35, PI * 1.95, 20, Color(0.40, 0.68, 0.48, 0.85), 20.0, false)
		draw_circle(lp + Vector2(4, -3), 7.0, Color("#ffb3c6"))
		draw_circle(lp + Vector2(4, -3), 3.0, Color("#ffb703"))

	# 6. タイトル画面の魚たち
	for f in title_fishes:
		if f["tex"]:
			var rot = f["dir"].angle() + sin(f["tail"]) * 0.08
			var tr = Transform2D(rot, f["pos"])
			draw_set_transform_matrix(tr)
			var sz = f["tex"].get_size() * f["scale"]
			draw_texture_rect(f["tex"], Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y), false, f["color"])
			draw_set_transform_matrix(Transform2D.IDENTITY)

	# 7. 木製の桟橋（陸から湖へ突き出る）
	var pier_rect = Rect2(450, 435, 220, 85)
	# 杭（水中・支柱）
	draw_rect(Rect2(pier_rect.end.x - 18, pier_rect.position.y - 6, 16, 18), Color(0.3, 0.38, 0.45, 0.6), true)
	draw_rect(Rect2(pier_rect.end.x - 18, pier_rect.end.y - 12, 16, 18), Color(0.3, 0.38, 0.45, 0.6), true)
	# 天板
	draw_rect(pier_rect, Color(0.82, 0.68, 0.52, 0.95), true)
	draw_rect(pier_rect, Color(0.55, 0.42, 0.32, 0.85), false, 2.5)
	var step = 20.0
	var cur_x = pier_rect.position.x + step
	while cur_x < pier_rect.end.x:
		draw_line(Vector2(cur_x, pier_rect.position.y), Vector2(cur_x, pier_rect.end.y), Color(0.55, 0.42, 0.32, 0.65), 1.8)
		cur_x += step

	# 8. 桟橋の先端で腰掛けてのんびり釣りをする「かわいいおじさん」
	_draw_sitting_fisherman(Vector2(pier_rect.end.x - 28, pier_rect.position.y + 42))

	# 9. 木々（左上奥、右上、右下奥）
	if tex_tree:
		var tree_poses = [Vector2(500, 160), Vector2(1080, 160), Vector2(1120, 320)]
		for tp in tree_poses:
			var scale_v = Vector2(0.26, 0.26)
			var sz = tex_tree.get_size() * scale_v
			draw_texture_rect(tex_tree, Rect2(tp - sz * 0.5, sz), false)

	# 10. 花びら・木漏れ日の舞
	for p in petals:
		draw_circle(p["pos"], p["size"], p["color"])
		draw_circle(p["pos"], p["size"] * 0.5, Color(1, 1, 1, 0.8))

func _draw_sitting_fisherman(pos: Vector2) -> void:
	# 影
	draw_ellipse(pos + Vector2(2, 18), 24.0, 10.0, Color(0.12, 0.18, 0.22, 0.35))
	
	# カラー定義
	var overalls_col = Color("#2a6f97")
	var shirt_col = Color("#e9c46a")
	var skin_col = Color("#fcd5ce")
	var hat_col = Color("#ccd5ae")
	var mustache_col = Color("#f8f9fa")
	var boot_col = Color("#582f0e")
	
	# 1. 桟橋からぶら下げた足（茶色の長靴）
	draw_rect(Rect2(pos.x + 10, pos.y + 10, 10, 20), boot_col, true)
	draw_rect(Rect2(pos.x + 22, pos.y + 10, 10, 20), boot_col, true)
	# つま先
	draw_rect(Rect2(pos.x + 13, pos.y + 26, 12, 6), boot_col, true)
	draw_rect(Rect2(pos.x + 25, pos.y + 26, 12, 6), boot_col, true)
	
	# 2. ぽっこりお腹の丸い胴体（サロペット）
	draw_ellipse(pos + Vector2(2, 2), 22.0, 16.0, overalls_col)
	# 中に着た黄色いシャツ
	draw_circle(pos + Vector2(-10, -4), 8.0, shirt_col)
	draw_circle(pos + Vector2(14, -4), 8.0, shirt_col)
	# サロペットの肩紐
	draw_line(pos + Vector2(-6, -12), pos + Vector2(-4, 6), Color("#1e4f6e"), 3.5)
	draw_line(pos + Vector2(8, -12), pos + Vector2(8, 6), Color("#1e4f6e"), 3.5)
	# 金具ボタン
	draw_circle(pos + Vector2(-4, 2), 2.2, Color("#e9c46a"))
	draw_circle(pos + Vector2(8, 2), 2.2, Color("#e9c46a"))
	
	# 3. 愛らしいお顔
	var head_y = pos.y - 20.0
	draw_circle(Vector2(pos.x, head_y), 16.0, skin_col)
	
	# ほんのり桜色のほっぺ
	draw_circle(Vector2(pos.x - 6, head_y + 3), 4.5, Color(1.0, 0.6, 0.65, 0.45))
	draw_circle(Vector2(pos.x + 8, head_y + 3), 4.5, Color(1.0, 0.6, 0.65, 0.45))
	
	# にっこり笑顔の目（細い三日月）
	draw_arc(Vector2(pos.x + 4, head_y - 2), 3.0, PI * 1.1, PI * 1.9, 8, Color("#2b2d42"), 2.2)
	draw_arc(Vector2(pos.x - 5, head_y - 2), 3.0, PI * 1.1, PI * 1.9, 8, Color("#2b2d42"), 2.2)
	
	# 愛嬌たっぷりの赤い丸鼻
	draw_circle(Vector2(pos.x + 4, head_y + 3), 4.2, Color("#e76f51"))
	draw_circle(Vector2(pos.x + 2.8, head_y + 1.8), 1.5, Color(1, 1, 1, 0.7))
	
	# ふさふさの白い口髭
	draw_ellipse(Vector2(pos.x + 1, head_y + 8), 9.0, 5.0, mustache_col)
	draw_ellipse(Vector2(pos.x + 8, head_y + 8), 8.0, 4.5, mustache_col)
	
	# 4. バケットハット（麦わら帽子）
	draw_ellipse(Vector2(pos.x, head_y - 10), 28.0, 12.0, hat_col)
	draw_rect(Rect2(pos.x - 14, head_y - 22, 28, 14), hat_col, true)
	# 帽子のリボン
	draw_rect(Rect2(pos.x - 14, head_y - 15, 28, 4.0), Color("#d4a373"), true)
	
	# 5. 釣り竿（手から右斜め上へ伸びるしっかりした竹竿）
	var hand_pos = pos + Vector2(10, -2)
	var rod_tip = pos + Vector2(75, -24)
	# 竿本体
	draw_line(hand_pos, rod_tip, Color("#9c6644"), 3.5)
	# 小さなリール
	draw_circle(hand_pos + Vector2(6, 2), 4.5, Color("#495057"))
	draw_circle(hand_pos + Vector2(6, 2), 2.0, Color("#adb5bd"))
	
	# 6. 釣り糸とウキ（水面へ垂れる）
	var bobber_pos = pos + Vector2(120, 55 + sin(time_counter * 3.0) * 3.5)
	draw_line(rod_tip, bobber_pos, Color(1, 1, 1, 0.75), 1.2)
	
	# 赤白のウキ
	draw_circle(bobber_pos, 5.5, Color("#e63946"))
	draw_circle(bobber_pos + Vector2(0, -2.5), 4.0, Color.WHITE)
	
	# 水彩の波紋アニメーション
	var wave_r = 10.0 + sin(time_counter * 3.5) * 4.0
	draw_arc(bobber_pos, wave_r, 0, TAU, 16, Color(1, 1, 1, 0.65), 1.5)
	draw_arc(bobber_pos, wave_r * 1.6, 0, TAU, 16, Color(1, 1, 1, 0.35), 1.0)
