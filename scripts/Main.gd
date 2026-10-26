extends Node2D

# メインシーン統括スクリプト (ステップ3：ショップ小屋・魚売却・探索道具アンロック)

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

@onready var map_field = $MapField
@onready var player = $Player
@onready var bobber = $Bobber
@onready var hud = $CanvasLayer/Step1HUD
@onready var fish_container = $FishContainer
@onready var reel_minigame = $CanvasLayer/ReelMinigame
@onready var catch_popup = $CanvasLayer/CatchResultPopup
@onready var shop_modal = $CanvasLayer/ShopModal
@onready var fish_book_modal = $CanvasLayer/FishBookModal
@onready var shop_building = $ShopBuilding

@onready var shallow_crossing = $ShallowCrossing
@onready var fallen_log = $FallenLog
@onready var boat_dock = $BoatDock

var fish_shadow_script = preload("res://scripts/entities/FishShadow.gd")

var biting_fish_node: Node2D = null
var last_caught_species: String = "funa"
var bite_timer: float = 0.0
var bite_window: float = 1.4

func _ready() -> void:
	player.global_position = Vector2(950, 800)
	
	player.cast_bobber.connect(_on_player_cast)
	player.retrieve_bobber.connect(_on_player_retrieve)
	
	bobber.fish_bitten.connect(_on_bobber_fish_bitten)
	
	reel_minigame.reel_success.connect(_on_reel_success)
	reel_minigame.reel_failed.connect(_on_reel_failed)
	
	catch_popup.confirmed.connect(_on_catch_confirmed)
	
	# ショップの連携
	if shop_building:
		shop_building.shop_interacted.connect(open_shop)
	if hud:
		hud.open_shop_requested.connect(open_shop)
		hud.open_book_requested.connect(open_book)
	if shop_modal:
		shop_modal.closed.connect(_on_shop_closed)
	if fish_book_modal:
		fish_book_modal.closed.connect(_on_book_closed)
		
	# 探索ギミックの連携
	if boat_dock:
		boat_dock.player_node = player
		boat_dock.boat_ride_started.connect(_on_boat_ride_started)
		boat_dock.boat_ride_finished.connect(_on_boat_ride_finished)
	if shallow_crossing:
		shallow_crossing.shallow_entered.connect(_on_shallow_entered)
	if fallen_log:
		fallen_log.log_destroyed.connect(_on_log_destroyed)

	GameData.tool_unlocked.connect(_on_tool_unlocked)
	
	_spawn_initial_fishes()
	SoundManager.play_bgm("bgm_fishing", 1.5)

	for arg in OS.get_cmdline_user_args():
		if arg == "--capture-shadows":
			_run_capture_shadows_test()

func _run_capture_shadows_test() -> void:
	await get_tree().create_timer(0.5).timeout
	var dir_path = "/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/"
	get_viewport().get_texture().get_image().save_png(dir_path + "view_fish_shadows.png")
	print("SHADOWS_CAPTURE_SAVED_OK")
	get_tree().quit()

func _process(delta: float) -> void:
	if current_state == State.BITE:
		bite_timer -= delta
		if bite_timer <= 0.0:
			_on_miss_bite()

func _unhandled_input(event: InputEvent) -> void:
	if current_state == State.SHOP or current_state == State.BOOK:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_B or event.keycode == KEY_J:
			open_book()
			return
		
	var is_action = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_action = true
	elif event.is_action_pressed("ui_accept"):
		is_action = true
		
	if is_action and current_state == State.BITE:
		_start_reeling_fight()
		get_viewport().set_input_as_handled()

func open_book() -> void:
	if current_state == State.REELING or current_state == State.RESULT:
		return
	if current_state == State.WAITING or current_state == State.BITE:
		bobber.retrieve()
		player.reset_fishing_state()
		for fish in fish_container.get_children():
			if fish.has_method("on_bobber_retrieved"):
				fish.on_bobber_retrieved()
		
	SoundManager.play_sfx("book")
	current_state = State.BOOK
	player.set_physics_process(false)
	fish_book_modal.open_book()
	hud.set_status("📘 お魚図鑑を閲覧中... これまでに釣った魚の記録を確認しよう")

func _on_book_closed() -> void:
	SoundManager.play_sfx("book")
	current_state = State.IDLE
	player.set_physics_process(true)
	hud.set_status("図鑑を閉じた。まだ見ぬ大物を目指して釣りに出かけよう！")

func open_shop() -> void:
	if current_state == State.REELING or current_state == State.RESULT:
		return
	if current_state == State.WAITING or current_state == State.BITE:
		bobber.retrieve()
		player.reset_fishing_state()
		for fish in fish_container.get_children():
			if fish.has_method("on_bobber_retrieved"):
				fish.on_bobber_retrieved()
		
	SoundManager.play_sfx("book")
	current_state = State.SHOP
	player.set_physics_process(false) # おじさんの移動を一時停止
	shop_modal.open_shop()
	hud.set_status("🏪 水辺のよろず屋で買い物中...")

func _on_shop_closed() -> void:
	SoundManager.play_sfx("book")
	current_state = State.IDLE
	player.set_physics_process(true)
	hud.set_status("店を出た。魚を釣るか、新しいスポットを探してみよう")

func _on_tool_unlocked(tool_id: String) -> void:
	var tool_data = GameData.TOOLS.get(tool_id, {})
	var t_name = tool_data.get("name", "道具")
	SoundManager.play_sfx("catch", 0.05, 1.0)
	hud.set_status("🎉 【" + t_name + "】を手に入れた！ 探索範囲が広がった！", true)

func _on_shallow_entered(has_boots: bool) -> void:
	if has_boots:
		hud.set_status("🥾 長靴を履いて浅瀬を渡った！ 川の向こう『西の原生林』に到達！")
	else:
		hud.set_status("💦 浅瀬だ... 水が深くて渡れない。【ゴム長靴】があれば渡れそうだ！")

func _on_log_destroyed() -> void:
	hud.set_status("🪓 木こりのオノで倒木を切り払った！ 北の『秘密のエメラルド滝壺』が開通！", true)
	map_field.queue_redraw()

func _on_boat_ride_started() -> void:
	hud.set_status("⛵ 手漕ぎボートで湖をスイスイ進んでいる...")

func _on_boat_ride_finished(at_island: bool) -> void:
	if at_island:
		hud.set_status("🌸 湖の中央『神秘の孤島』へ上陸した！ 湖の底に眠る主の気配がする...", true)
	else:
		hud.set_status("⛵ 岸のボート乗り場へ無事に戻ってきた。")

func _spawn_initial_fishes() -> void:
	# 1. 川の魚（小川〜中流）
	var river_fish_list = ["medaka", "medaka", "yamame", "yamame", "funa"]
	for i in range(river_fish_list.size()):
		_spawn_single_fish(river_fish_list[i], "river", i, river_fish_list.size())

	# 2. 池の魚（広場池）
	var pond_fish_list = ["funa", "koi", "catfish", "koi", "funa"]
	for i in range(pond_fish_list.size()):
		_spawn_single_fish(pond_fish_list[i], "pond", i, pond_fish_list.size())

	# 3. ★西の原生林・深山渓流の魚（🥾 長靴で渡った先で釣れる「イワナ」）
	_spawn_fixed_fish("iwana", Vector2(410, 1320))
	_spawn_fixed_fish("iwana", Vector2(430, 1100))

	# 4. ★秘密のエメラルド滝壺の魚（🪓 オノで開通した先で釣れる「ニジマス」）
	_spawn_fixed_fish("rainbow_trout", Vector2(1080, 180))
	_spawn_fixed_fish("rainbow_trout", Vector2(1130, 160))

	# 5. ★湖の中央孤島沖の伝説の主（⛵ 手漕ぎボートで渡った先で狙う「黄金の主」）
	_spawn_fixed_fish("golden_koi", Vector2(1450, 680))

func _spawn_fixed_fish(species: String, pos: Vector2) -> void:
	var fish = Node2D.new()
	fish.set_script(fish_shadow_script)
	fish.fish_species = species
	fish_container.add_child(fish)
	fish.setup(map_field)
	fish.global_position = pos
	
	fish.fish_reached_bobber.connect(func():
		if current_state == State.WAITING:
			var s_desc = fish.get_shadow_size_desc() if fish.has_method("get_shadow_size_desc") else "魚影"
			hud.set_status("🐟 【" + s_desc + "】がウキに近寄ってきた！ つついている...")
	)
	fish.fish_bit.connect(func():
		biting_fish_node = fish
	)

func _spawn_single_fish(species: String, area: String, idx: int, total: int) -> void:
	var fish = Node2D.new()
	fish.set_script(fish_shadow_script)
	fish.fish_species = species
	fish_container.add_child(fish)
	fish.setup(map_field)
	
	if area == "river":
		var py = 180.0 + (float(idx) / float(total)) * (map_field.map_size.y - 360.0) + randf_range(-40, 40)
		var cx = map_field.river_x + sin(py * 0.005) * 60.0
		var px = cx + randf_range(-map_field.safe_river_half_width * 0.6, map_field.safe_river_half_width * 0.6)
		fish.global_position = Vector2(px, py)
	else:
		var angle = (TAU / float(total)) * float(idx) + randf_range(-0.3, 0.3)
		var dist = randf_range(0.35, 0.75)
		var pos = map_field.pond_center + Vector2(cos(angle) * map_field.safe_pond_rx * dist, sin(angle) * map_field.safe_pond_ry * dist)
		fish.global_position = pos
		
	fish.fish_reached_bobber.connect(func():
		if current_state == State.WAITING:
			var s_desc = fish.get_shadow_size_desc() if fish.has_method("get_shadow_size_desc") else "魚影"
			hud.set_status("🐟 【" + s_desc + "】がウキに近寄ってきた！ つついている...")
	)
	fish.fish_bit.connect(func():
		biting_fish_node = fish
	)

func _on_player_cast(target_pos: Vector2) -> void:
	if current_state == State.SHOP:
		return
	current_state = State.WAITING
	biting_fish_node = null
	bobber.launch(target_pos, player)
	SoundManager.play_sfx("cast", 0.08)
	hud.set_status("ポチャ〜ン... ウキを投げ入れた。魚が気づくのを待とう")
	
	for fish in fish_container.get_children():
		if fish.has_method("on_bobber_cast"):
			fish.on_bobber_cast(bobber)

func _on_player_retrieve() -> void:
	if current_state == State.SHOP:
		return
	current_state = State.IDLE
	biting_fish_node = null
	bobber.retrieve()
	reel_minigame.stop_minigame()
	SoundManager.play_sfx("cast", 0.12, -4.0)
	hud.set_status("ウキを回収した。移動して別の魚影を探してみよう")
	
	for fish in fish_container.get_children():
		if fish.has_method("on_bobber_retrieved"):
			fish.on_bobber_retrieved()

func _on_bobber_fish_bitten() -> void:
	current_state = State.BITE
	bite_timer = bite_window
	SoundManager.play_sfx("hit", 0.04, 2.0)
	hud.set_status("💥 HIT!! 水中の獲物が食いついた！ 今すぐ合わせろ！", true)

func _on_miss_bite() -> void:
	current_state = State.IDLE
	bobber.retrieve()
	player.reset_fishing_state()
	hud.set_status("ああ〜！合わせが遅れて逃げられちゃった... また挑戦しよう")
	for fish in fish_container.get_children():
		if fish.has_method("on_bobber_retrieved"):
			fish.on_bobber_retrieved()
	biting_fish_node = null

func _start_reeling_fight() -> void:
	current_state = State.REELING
	var species = "funa"
	var fish_name = "フナ"
	if is_instance_valid(biting_fish_node):
		species = biting_fish_node.fish_species
		fish_name = biting_fish_node.fish_name
		
	var fish_info = {
		"species": species,
		"name": fish_name
	}
	reel_minigame.start_minigame(fish_info)
	hud.set_status("🎣 ファイト開始！【長押し】でリールを巻き、緑の枠に魚影をキープしろ！")

func _on_reel_success() -> void:
	current_state = State.RESULT
	reel_minigame.stop_minigame()
	bobber.retrieve()
	player.reset_fishing_state()
	SoundManager.play_sfx("catch", 0.05, 1.5)
	
	var species = "funa"
	if is_instance_valid(biting_fish_node):
		species = biting_fish_node.fish_species
		biting_fish_node.queue_free()
		biting_fish_node = null
		
	for fish in fish_container.get_children():
		if fish.has_method("on_bobber_retrieved"):
			fish.on_bobber_retrieved()
			
	last_caught_species = species
	var bait_boost = GameData.consume_current_bait()
	var fish_dict = _generate_fish_loot(species, bait_boost)
	var record_result = GameData.record_fish_catch(species, fish_dict.size)
	fish_dict["is_first"] = record_result.is_first
	fish_dict["is_new_record"] = record_result.is_new_record
	
	GameData.add_caught_fish(fish_dict)
	
	catch_popup.show_result(fish_dict)
	if record_result.is_first:
		hud.set_status("🎉 【新種発見！】" + fish_dict.name + " を初めて釣り上げた！図鑑に登録！", true)
	elif record_result.is_new_record:
		hud.set_status("👑 【大物記録更新！】" + fish_dict.name + " (" + str(fish_dict.size) + "cm) 自己ベスト！", true)
	else:
		hud.set_status("✨ やったー！見事に " + fish_dict.name + " を釣り上げた！")

func _on_reel_failed() -> void:
	current_state = State.IDLE
	reel_minigame.stop_minigame()
	bobber.retrieve()
	player.reset_fishing_state()
	hud.set_status("糸が切れて逃げられちゃった...！ 次こそ釣り上げよう")
	for fish in fish_container.get_children():
		if fish.has_method("on_bobber_retrieved"):
			fish.on_bobber_retrieved()
	biting_fish_node = null

func _on_catch_confirmed() -> void:
	current_state = State.IDLE
	SoundManager.play_sfx("coin", 0.08, -2.0)
	hud.set_status("バケツに入れた！よろず屋で売ってお金を稼ごう！")
	
	# 釣られた魚の本来の生息エリアに新しい魚影を補充スポーン
	if fish_container.get_child_count() < 15:
		match last_caught_species:
			"golden_koi":
				_spawn_fixed_fish("golden_koi", Vector2(1450 + randf_range(-50, 50), 680 + randf_range(-20, 20)))
			"rainbow_trout":
				_spawn_fixed_fish("rainbow_trout", Vector2(1100 + randf_range(-40, 40), 170 + randf_range(-20, 20)))
			"iwana":
				_spawn_fixed_fish("iwana", Vector2(420 + randf_range(-20, 20), 1200 + randf_range(-120, 120)))
			"koi", "catfish":
				var p_pool = ["funa", "koi", "catfish"]
				_spawn_single_fish(p_pool[randi() % p_pool.size()], "pond", randi() % 5, 5)
			"medaka", "yamame":
				var r_pool = ["medaka", "yamame", "funa"]
				_spawn_single_fish(r_pool[randi() % r_pool.size()], "river", randi() % 5, 5)
			_:
				var area = "pond" if randf() > 0.5 else "river"
				_spawn_single_fish("funa", area, randi() % 5, 5)

func _generate_fish_loot(species: String, bait_boost: float = 1.0) -> Dictionary:
	var base_data = GameData.FISH_DATABASE.get(species, GameData.FISH_DATABASE["funa"])
	# エサのレア補正が高いほど大きなサイズが釣れやすくなる（複数回ロールして最大値を採用）
	var rolls = 1
	if bait_boost >= 1.9:
		rolls = 3
	elif bait_boost >= 1.3:
		rolls = 2
	var best_t = randf()
	for r in range(rolls - 1):
		best_t = maxf(best_t, randf())
	var raw_size = lerpf(base_data.min_size, base_data.max_size, best_t)
	var size = snappedf(raw_size, 0.1)
	var size_ratio = (size - base_data.min_size) / maxf(0.1, (base_data.max_size - base_data.min_size))
	var price = int(base_data.base_price * (1.0 + size_ratio * 0.6))
	
	return {
		"species": species,
		"name": base_data.name,
		"size": size,
		"rarity": base_data.rarity,
		"price": price,
		"desc": base_data.desc
	}
