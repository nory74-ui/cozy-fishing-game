extends Node3D

# 福岡・糸島 野北編 HD-2D メインマネージャー
# スクウェア・エニックス HD-2D 仕様

enum State {
	IDLE,
	CASTING,
	WAITING,
	BITE,
	REELING,
	RESULT,
	SHOP,
	BOOK
}

var current_state: State = State.IDLE

@onready var field = $Field
@onready var player = $Player
@onready var cat = $CatCompanion
@onready var bobber = $Bobber
@onready var camera = $Camera3D
@onready var hud = $CanvasLayer/Step1HUD
@onready var reel_minigame = $CanvasLayer/ReelMinigame
@onready var catch_popup = $CanvasLayer/CatchResultPopup
@onready var shop_modal = $CanvasLayer/ShopModal
@onready var fish_book_modal = $CanvasLayer/FishBookModal

var fish_container: Node3D
var active_fish_shadow: Node3D = null
var current_target_species: String = "kisu"

var bite_timer: float = 0.0

func _ready() -> void:
	fish_container = Node3D.new()
	fish_container.name = "FishContainer"
	add_child(fish_container)

	# プレイヤーの初期配置（野北・白砂サーフの中央）
	player.global_position = Vector3(8.0, 0.5, 6.0)
	cat.target_node = player
	cat.global_position = Vector3(9.5, 0.5, 7.0)
	
	camera.target_node = player
	camera.global_position = player.global_position + Vector3(0, 11, 14)

	# シグナル接続
	player.cast_bobber.connect(_on_player_cast)
	player.retrieve_bobber.connect(_on_player_retrieve)
	
	bobber.landed.connect(_on_bobber_landed)
	bobber.fish_bitten.connect(_on_fish_bitten)

	reel_minigame.reel_success.connect(_on_reel_success)
	reel_minigame.reel_failed.connect(_on_reel_failed)
	catch_popup.confirmed.connect(_on_catch_confirmed)

	if hud:
		if hud.has_signal("open_shop_requested"):
			hud.open_shop_requested.connect(open_shop)
		if hud.has_signal("open_book_requested"):
			hud.open_book_requested.connect(open_book)
		if hud.has_signal("save_game_requested"):
			hud.save_game_requested.connect(func(): GameData.save_game())
		if hud.has_signal("title_requested"):
			hud.title_requested.connect(func():
				GameData.save_game()
				get_tree().change_scene_to_file("res://scenes/title.tscn")
			)

	if shop_modal:
		shop_modal.closed.connect(_on_shop_closed)
	if fish_book_modal:
		fish_book_modal.closed.connect(_on_book_closed)

	_spawn_fishes()
	_spawn_forage_items()

	# 玄界灘のリアル環境音 & BGM
	SoundManager.play_bgm("bgm_fishing", 1.5)
	SoundManager.play_ambient("ambient_waves", 2.0)

	_set_hud_status("【野北海岸 HD-2D】立体的な砂浜、大波止、松林。WASDで歩き回り、SPACEで海へキャスト！")

	# コマンドライン引数による自動キャプチャ検証
	var args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in args:
		if arg == "--capture-hd2d":
			_run_hd2d_capture_test()
			break

func _spawn_fishes() -> void:
	var fish_script = load("res://scripts/entities/FishShadow3D.gd")
	var spots_data = [
		{"pos": Vector3(8.0, 0.04, -4.0), "species": "kisu"},
		{"pos": Vector3(14.0, 0.04, -6.0), "species": "hirame"},
		{"pos": Vector3(-12.0, 0.04, -22.0), "species": "madai"},
		{"pos": Vector3(-18.0, 0.04, -8.0), "species": "chinu"},
		{"pos": Vector3(-19.0, 0.04, 2.0), "species": "arakabu"},
		{"pos": Vector3(-4.0, 0.04, -10.0), "species": "aji"},
		{"pos": Vector3(-3.0, 0.04, -16.0), "species": "aoriika"}
	]
	for data in spots_data:
		var f = Node3D.new()
		f.set_script(fish_script)
		f.species_id = data["species"]
		fish_container.add_child(f)
		f.global_position = data["pos"]
		f.fish_bit.connect(func(): _trigger_bite(data["species"]))

func _spawn_forage_items() -> void:
	var items = [
		{"pos": Vector3(4.0, 0.45, 10.0), "name": "サザエ", "val": 120, "icon": "🐚"},
		{"pos": Vector3(12.0, 0.45, 7.5), "name": "桜貝", "val": 60, "icon": "🌸"},
		{"pos": Vector3(16.0, 0.45, 12.0), "name": "シーグラス", "val": 80, "icon": "💎"},
		{"pos": Vector3(-12.0, 1.85, 4.0), "name": "アワビ", "val": 250, "icon": "🦪"},
		{"pos": Vector3(8.0, 0.45, 2.0), "name": "漂着ボトル", "val": 150, "icon": "🍾"}
	]
	for it in items:
		var sp = Sprite3D.new()
		sp.name = "ForageItem_" + it["name"]
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.pixel_size = 0.0035
		sp.position = it["pos"]
		
		# キラキラの小球メッシュ
		var mi = MeshInstance3D.new()
		var s = SphereMesh.new()
		s.radius = 0.15
		s.height = 0.3
		mi.mesh = s
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.85, 0.3)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.9, 0.4)
		m.emission_energy_multiplier = 2.0
		mi.material_override = m
		sp.add_child(mi)
		
		sp.set_meta("item_data", it)
		add_child(sp)

func _process(delta: float) -> void:
	if current_state == State.WAITING:
		bite_timer += delta
		if bite_timer > 3.0 and active_fish_shadow == null:
			# 自動アタリ発生（付近の魚影がヒット）
			_trigger_bite("kisu")

	# アイテム採取判定（[E] キー）
	if Input.is_key_pressed(KEY_E):
		_check_forage_pickup()

func _check_forage_pickup() -> void:
	for child in get_children():
		if child is Sprite3D and child.has_meta("item_data"):
			var dist = player.global_position.distance_to(child.global_position)
			if dist < 2.0:
				var it = child.get_meta("item_data")
				GameData.money += it["val"]
				GameData.save_game()
				SoundManager.play_sfx("sfx_pickup")
				_set_hud_status(it["icon"] + " " + it["name"] + " を拾った！（+" + str(it["val"]) + " G）", true)
				child.queue_free()
				break

func _on_player_cast(target_pos: Vector3) -> void:
	if current_state != State.IDLE: return
	current_state = State.CASTING
	SoundManager.play_sfx("sfx_cast")
	_set_hud_status("キャスト！ウキが沈むのを待とう…")
	
	bobber.cast_to(player.global_position, target_pos)
	current_state = State.WAITING
	bite_timer = 0.0

	# 近くの魚影に通知
	for f in fish_container.get_children():
		if f.has_method("on_bobber_landed"):
			f.on_bobber_landed(bobber)

func _on_bobber_landed(_pos: Vector3) -> void:
	pass

func _trigger_bite(species: String) -> void:
	if current_state != State.WAITING: return
	current_state = State.BITE
	current_target_species = species
	bobber.bite_reaction()
	SoundManager.play_sfx("sfx_bite")
	_set_hud_status("！魚が食いついた！[SPACE] で合わせろ！", true)
	
	# 少し待って自動またはキー入力でミニゲームへ
	await get_tree().create_timer(0.4).timeout
	_start_reeling()

func _start_reeling() -> void:
	current_state = State.REELING
	var difficulty = 1.0
	var f_info = GameData.get_fish_info(current_target_species)
	if f_info.has("rarity") and f_info["rarity"] == "rare":
		difficulty = 1.4
	reel_minigame.start_game(difficulty, current_target_species)

func _on_player_retrieve() -> void:
	if current_state in [State.CASTING, State.WAITING, State.BITE]:
		bobber.reset_bobber()
		player.is_casting = false
		current_state = State.IDLE
		_set_hud_status("仕掛けを巻き取った。")

func _on_fish_bitten(species_id: String) -> void:
	_trigger_bite(species_id)

func _on_reel_success() -> void:
	current_state = State.RESULT
	bobber.reset_bobber()
	player.is_casting = false

	var f_info = GameData.get_fish_info(current_target_species)
	var min_s = f_info.get("size_min", 15.0)
	var max_s = f_info.get("size_max", 35.0)
	var final_size = randf_range(min_s, max_s)
	
	var is_new_record = GameData.record_fish_catch(current_target_species, final_size)
	GameData.money += f_info.get("base_price", 100)
	GameData.save_game()

	catch_popup.show_catch(current_target_species, final_size, is_new_record)

func _on_reel_failed() -> void:
	bobber.reset_bobber()
	player.is_casting = false
	current_state = State.IDLE
	SoundManager.play_sfx("sfx_splash")
	_set_hud_status("逃げられてしまった…！次こそ釣り上げよう。")

func _on_catch_confirmed() -> void:
	current_state = State.IDLE
	_set_hud_status("ナイスフィッシュ！次の大物を狙おう。")

func open_shop() -> void:
	if shop_modal:
		current_state = State.SHOP
		if shop_modal.has_method("open_shop"):
			shop_modal.open_shop()
		elif shop_modal.has_method("open"):
			shop_modal.open()

func _on_shop_closed() -> void:
	current_state = State.IDLE

func open_book() -> void:
	if fish_book_modal:
		current_state = State.BOOK
		if fish_book_modal.has_method("open_book"):
			fish_book_modal.open_book()
		elif fish_book_modal.has_method("open"):
			fish_book_modal.open()

func _on_book_closed() -> void:
	current_state = State.IDLE

func _set_hud_status(text: String, is_alert: bool = false) -> void:
	if not hud: return
	if hud.has_method("set_status"):
		hud.set_status(text, is_alert)
	elif hud.has_method("show_notification"):
		hud.show_notification(text)

func _run_hd2d_capture_test() -> void:
	await get_tree().create_timer(0.6).timeout
	var dir_path = "/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/"
	var img = get_viewport().get_texture().get_image()
	img.save_png(dir_path + "view_hd2d_nogita_overview.png")
	print("HD2D_OVERVIEW_CAPTURE_SAVED_OK")

	# キャストのキャプチャ
	player._cast()
	await get_tree().create_timer(0.5).timeout
	var img2 = get_viewport().get_texture().get_image()
	img2.save_png(dir_path + "view_hd2d_casting.png")
	print("HD2D_CASTING_CAPTURE_SAVED_OK")

	# 堤防先端（灯台）へ移動したシーンのキャプチャ
	player.is_casting = false
	bobber.reset_bobber()
	player.global_position = Vector3(-12.0, 1.8, -12.0)
	cat.global_position = Vector3(-12.0, 1.8, -10.5)
	await get_tree().create_timer(0.5).timeout
	var img3 = get_viewport().get_texture().get_image()
	img3.save_png(dir_path + "view_hd2d_breakwater_pier.png")
	print("HD2D_PIER_CAPTURE_SAVED_OK")

	get_tree().quit(0)
