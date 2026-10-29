extends Node

# --- ゲームデータ管理シングルトン (Autoload) ---

signal coins_changed(new_amount: int)
signal inventory_changed()
signal equipment_changed()
signal tool_unlocked(tool_id: String)
signal book_updated(species: String, is_first: bool, is_record: bool)

# プレイヤーのステータス
var coins: int = 60 # 初期所持金
var current_rod: String = "starter_rod"
var current_bait: String = "isome"

# 所持品
var inventory: Array[Dictionary] = [] # 釣った魚リスト
var unlocked_rods: Array[String] = ["starter_rod"]
var bait_counts: Dictionary = {
	"isome": 5,
	"okiami": 5,
	"mussel": 3,
	"shrimp": 0,
	"lure": 0
}

# ★図鑑記録: species -> { "caught_count": int, "max_size": float }
var fish_records: Dictionary = {}

# ★探索・釣り具（Key Items）の所持状況
var has_boots: bool = false   # フェルトスパイク靴（濡れたテトラや磯でも安全）
var has_axe: bool = false     # 玉網・タモ網（大物を確実に引き上げる）
var has_boat: bool = false    # プレジャーボート（玄界灘沖合へ出られる）

# マップギミック解放状況
var is_log_cleared: bool = false
var is_on_island: bool = false

# セーブファイルパス (Web/Local両対応のuser://)
const SAVE_PATH = "user://save_data.json"

signal game_saved()
signal game_loaded()

# --- マスターデータ ---

# 釣り竿カタログ（福岡・玄界灘仕様）
const RODS: Dictionary = {
	"starter_rod": {
		"id": "starter_rod",
		"name": "波止のべ竿",
		"price": 0,
		"power": 1.0,
		"stability": 1.0,
		"desc": "堤防でのサビキやちょい投げに最適な万能のべ竿。素直な曲がりで扱いやすい。"
	},
	"surf_cast_rod": {
		"id": "surf_cast_rod",
		"name": "糸島サーフ投竿",
		"price": 130,
		"power": 1.4,
		"stability": 1.25,
		"desc": "白砂の海岸から遠投できる弾力のある投竿。砂底に潜むキスやマゴチを狙い撃つ。"
	},
	"isogame_rod": {
		"id": "isogame_rod",
		"name": "玄界磯チヌ竿",
		"price": 380,
		"power": 1.85,
		"stability": 1.55,
		"desc": "粘り強い胴調子の本格磯竿。荒磯やテトラに潜むチヌやアラカブの突っ込みを受け止める。"
	},
	"master_sea_rod": {
		"id": "master_sea_rod",
		"name": "玄界灘・大物専用剛竿",
		"price": 950,
		"power": 2.5,
		"stability": 2.1,
		"desc": "大型マダイや座布団ヒラメの強烈な引きを圧倒的なパワーでねじ伏せるプロ仕様の剛竿。"
	}
}

# 釣り具・アイテムカタログ
const TOOLS: Dictionary = {
	"boots": {
		"id": "boots",
		"name": "フェルトスパイク靴",
		"icon": "",
		"price": 100,
		"desc": "濡れたテトラポッドや滑りやすい磯場でもガッチリ踏ん張れる安全ブーツ。"
	},
	"axe": {
		"id": "axe",
		"name": "カーボン玉網",
		"icon": "",
		"price": 250,
		"desc": "軽量で頑丈なランディングネット。足場の高い波止から大型魚を確実に掬い上げる。"
	},
	"boat": {
		"id": "boat",
		"name": "プレジャーボート",
		"icon": "",
		"price": 600,
		"desc": "野北漁港から出船できる小型ボート。玄界灘の沖合、大鯛が回遊する深淵へ！"
	}
}

# エサカタログ（福岡・海釣り実戦仕様）
const BAITS: Dictionary = {
	"isome": {
		"id": "isome",
		"name": "アオイソメ",
		"pack_amount": 5,
		"price": 15,
		"rare_boost": 1.0,
		"desc": "活きの良い青虫。動く光と匂いでシロギスやアジ、アラカブを惹きつける堤防の万能エサ。"
	},
	"okiami": {
		"id": "okiami",
		"name": "生オキアミ",
		"pack_amount": 5,
		"price": 25,
		"rare_boost": 1.25,
		"desc": "粒ぞろいの新鮮なオキアミ。アジの群れやチヌ、マダイがたまらず口を使う定番の海エサ。"
	},
	"mussel": {
		"id": "mussel",
		"name": "ムール貝 (イガイ)",
		"pack_amount": 3,
		"price": 35,
		"rare_boost": 1.5,
		"desc": "堤防壁面に付着する天然の貝。硬い殻ごと砕いて食べる年無しチヌ（クロダイ）の特効薬。"
	},
	"shrimp": {
		"id": "shrimp",
		"name": "活きエビ",
		"pack_amount": 3,
		"price": 60,
		"rare_boost": 1.8,
		"desc": "元気に跳ねる活シラサエビ。高級魚キジハタ（アコウ）やスズキが猛烈にアタックする。"
	},
	"lure": {
		"id": "lure",
		"name": "メタルジグ",
		"pack_amount": 3,
		"price": 90,
		"rare_boost": 2.2,
		"desc": "光を乱反射してイワシの逃走を演出するルアー。砂底のヒラメや回遊するフィッシュイーター用。"
	}
}

# 魚データベース（福岡県・糸島 玄界灘の実在の海洋生態系・サイズ・生態に基づく設定）
const FISH_DATABASE: Dictionary = {
	"aji": {
		"id": "aji",
		"name": "マアジ",
		"rarity": "Common",
		"base_price": 20,
		"min_size": 12.0,
		"max_size": 34.0,
		"habitat": "野北漁港・大波止先端（潮通しの良い回遊層）",
		"desc": "玄界灘の激しい潮流で育つマアジは身が引き締まり脂乗りが抜群。初夏から秋にかけて堤防周りに大群で回遊する。夕マズメや夜間の常夜灯下に集まる習性があり、30cmを超えるものは「尺アジ」と呼ばれる。"
	},
	"kisu": {
		"id": "kisu",
		"name": "シロギス",
		"rarity": "Common",
		"base_price": 25,
		"min_size": 12.0,
		"max_size": 26.5,
		"habitat": "野北サーフ（白砂海岸の波打ち際・駆け上がり）",
		"desc": "「砂浜の貴婦人」と称される透き通る美しい魚体。糸島の大口海岸などの白砂底に生息し、砂の中に潜むゴカイ類を吸い込むように捕食する。繊細なアタリと上品で甘みのある白身が釣り人に愛されている。"
	},
	"arakabu": {
		"id": "arakabu",
		"name": "アラカブ (カサゴ)",
		"rarity": "Common",
		"base_price": 30,
		"min_size": 14.0,
		"max_size": 28.5,
		"habitat": "波止の基礎石・テトラポッドの隙間",
		"desc": "九州で「アラカブ」と呼ばれる根魚の代表。堤防の足元や消波ブロックの暗がりにじっと潜み、落ちてくるエサを一瞬でひったくる。大きな口とトゲのあるヒレを持ち、煮付けや味噌汁にすると濃厚な出汁が出る。"
	},
	"chinu": {
		"id": "chinu",
		"name": "チヌ (クロダイ)",
		"rarity": "Rare",
		"base_price": 75,
		"min_size": 22.0,
		"max_size": 54.0,
		"habitat": "波止のケーソン足元・テトラ帯",
		"desc": "警戒心が極めて強く、知恵比べが楽しめる名ターゲット。福岡では小型を「メイタ」と呼ぶ。堤防に付着したイガイやカニを頑丈な歯で噛み砕く。50cmを超える「年無し（としなし）」の銀鱗と強烈な引きは圧巻。"
	},
	"magochi": {
		"id": "magochi",
		"name": "マゴチ",
		"rarity": "Rare",
		"base_price": 95,
		"min_size": 35.0,
		"max_size": 62.0,
		"habitat": "野北サーフの浅場〜ブレイクライン",
		"desc": "上から押しつぶされたような平たい体を持つ砂地のハンター。「照りゴチ」と呼ばれ初夏〜夏にサーフの浅場へ寄る。砂に身を隠して目の前を通る小魚やエビを豪快に捕食し、強烈な首振りダンスで竿を揺らす。"
	},
	"suzuki": {
		"id": "suzuki",
		"name": "スズキ (シーバス)",
		"rarity": "Rare",
		"base_price": 120,
		"min_size": 45.0,
		"max_size": 88.0,
		"habitat": "波打ち際のサラシ・潮目・離岸流",
		"desc": "白波が砕けるサラシや潮通しの良い潮流帯を回遊する大型フィッシュイーター。フッキングすると水面を割って高くジャンプし、頭を激しく振る「エラ洗い」で針を外そうとする。80cm超のランカーサイズは迫力満点。"
	},
	"kijihata": {
		"id": "kijihata",
		"name": "キジハタ (アコウ)",
		"rarity": "Epic",
		"base_price": 160,
		"min_size": 22.0,
		"max_size": 48.0,
		"habitat": "大波止沖合の沈み瀬・深場の岩礁帯",
		"desc": "「夏のフグ」とも称される玄界灘の超高級根魚。福岡・九州では「アコウ」と呼ばれる。鮮やかな赤橙色の体に散らばる青い斑点が宝石のように美しい。強烈な力で一気に海底の岩穴に潜り込もうとする。"
	},
	"hirame": {
		"id": "hirame",
		"name": "ヒラメ",
		"rarity": "Epic",
		"base_price": 180,
		"min_size": 32.0,
		"max_size": 78.0,
		"habitat": "野北サーフ沖合の深み・海底の砂地",
		"desc": "砂底に完璧に擬態するサーフの頂点捕食者。鋭い歯を持ち、頭上を通るキスやアジに電光石火の速さで襲いかかる。肉厚な70cm超の「座布団ヒラメ」は糸島サーフに通うアングラーすべての夢。"
	},
	"madai": {
		"id": "madai",
		"name": "マダイ (真鯛)",
		"rarity": "Epic",
		"base_price": 220,
		"min_size": 25.0,
		"max_size": 76.0,
		"habitat": "大波止先端の沖合本流・深場",
		"desc": "玄界灘の荒波と豊富な潮流に育まれた「百魚の王」。鮮やかな桜色の魚体にエメラルドグリーンの斑点が美しく輝く。波止の先端から沖の潮目へ流すとヒットし、竿先を激しく叩く独特の三段引きで魅了する。"
	},
	"aoriika": {
		"id": "aoriika",
		"name": "アオリイカ (ミズイカ)",
		"rarity": "Legendary",
		"base_price": 500,
		"min_size": 20.0,
		"max_size": 45.0,
		"habitat": "大波止周りのホンダワラ藻場・深淵",
		"desc": "「イカの王様」と称えられる最高峰ターゲット。九州では「ミズイカ」と呼ばれる。水晶のように透き通る肉厚な胴体と、光の加減で虹色に変化する美しい体色が特徴。キロアップの親イカはジェット噴射でドラグを唸らせる。"
	}
}

func _ready() -> void:
	load_game()

# 外部画像ロードヘルパー
static func load_texture(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res = load(res_path)
		if res is Texture2D:
			return res
	# フォールバック: res://から直接バイナリをロード
	if FileAccess.file_exists(res_path):
		var bytes = FileAccess.get_file_as_bytes(res_path)
		if bytes.size() > 0:
			var img = Image.new()
			var err = OK
			if res_path.ends_with(".png"):
				err = img.load_png_from_buffer(bytes)
			elif res_path.ends_with(".jpg") or res_path.ends_with(".jpeg"):
				err = img.load_jpg_from_buffer(bytes)
			if err == OK:
				return ImageTexture.create_from_image(img)
	# 最終フォールバック: ローカルファイルシステムパス
	var global_path = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_path):
		var img = Image.new()
		var err = img.load(global_path)
		if err == OK:
			return ImageTexture.create_from_image(img)
	push_warning("Failed to load texture: " + res_path)
	return null

# 水彩絵本調パステルボタンスタイル共通ヘルパー
static func apply_pastel_button_style(btn: Button) -> void:
	if not btn: return
	var st_n = StyleBoxFlat.new()
	st_n.bg_color = Color(0.95, 0.92, 0.85, 0.95)
	st_n.border_color = Color(0.78, 0.66, 0.52, 0.9)
	st_n.set_border_width_all(1)
	st_n.set_corner_radius_all(6)
	st_n.content_margin_left = 10.0
	st_n.content_margin_right = 10.0
	st_n.content_margin_top = 4.0
	st_n.content_margin_bottom = 4.0
	
	var st_h = st_n.duplicate()
	st_h.bg_color = Color(0.99, 0.96, 0.88, 1.0)
	st_h.border_color = Color(0.90, 0.55, 0.30, 0.95)
	
	var st_p = st_n.duplicate()
	st_p.bg_color = Color(0.86, 0.80, 0.70, 1.0)
	st_p.border_color = Color(0.68, 0.48, 0.32, 0.95)
	
	var st_d = st_n.duplicate()
	st_d.bg_color = Color(0.90, 0.88, 0.84, 0.7)
	st_d.border_color = Color(0.78, 0.75, 0.70, 0.6)
	
	btn.add_theme_stylebox_override("normal", st_n)
	btn.add_theme_stylebox_override("hover", st_h)
	btn.add_theme_stylebox_override("pressed", st_p)
	btn.add_theme_stylebox_override("disabled", st_d)
	btn.add_theme_color_override("font_color", Color(0.20, 0.28, 0.32, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.12, 0.20, 0.25, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.15, 0.22, 0.28, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55, 0.85))

# コイン
func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	save_game()

func spend_coins(cost: int) -> bool:
	if coins >= cost:
		coins -= cost
		coins_changed.emit(coins)
		save_game()
		return true
	return false

# 魚インベントリ
func add_caught_fish(fish_dict: Dictionary) -> void:
	inventory.append(fish_dict)
	inventory_changed.emit()
	save_game()

func sell_fish_at(index: int) -> int:
	if index < 0 or index >= inventory.size():
		return 0
	var fish = inventory[index]
	var price = fish.get("price", 10)
	inventory.remove_at(index)
	add_coins(price)
	inventory_changed.emit()
	SoundManager.play_sfx("coin", 0.08)
	save_game()
	return price

func sell_all_fish() -> int:
	var total = 0
	for fish in inventory:
		total += fish.get("price", 10)
	inventory.clear()
	add_coins(total)
	inventory_changed.emit()
	if total > 0:
		SoundManager.play_sfx("coin", 0.05, 2.0)
	save_game()
	return total

# 道具・竿・エサ購入
func buy_tool(tool_id: String) -> bool:
	var tool_data = TOOLS.get(tool_id)
	if not tool_data: return false
	if spend_coins(tool_data.price):
		match tool_id:
			"boots": has_boots = true
			"axe": has_axe = true
			"boat": has_boat = true
		SoundManager.play_sfx("coin", 0.05)
		tool_unlocked.emit(tool_id)
		equipment_changed.emit()
		save_game()
		return true
	return false

func has_tool(tool_id: String) -> bool:
	match tool_id:
		"boots": return has_boots
		"axe": return has_axe
		"boat": return has_boat
	return false

func buy_rod(rod_id: String) -> bool:
	if rod_id in unlocked_rods:
		current_rod = rod_id
		SoundManager.play_sfx("coin", 0.05, -2.0)
		equipment_changed.emit()
		save_game()
		return true
	var data = RODS.get(rod_id)
	if data and spend_coins(data.price):
		unlocked_rods.append(rod_id)
		current_rod = rod_id
		SoundManager.play_sfx("coin", 0.05)
		equipment_changed.emit()
		save_game()
		return true
	return false

func equip_rod(rod_id: String) -> void:
	if rod_id in unlocked_rods:
		current_rod = rod_id
		SoundManager.play_sfx("coin", 0.08, -3.0)
		equipment_changed.emit()
		save_game()

func buy_bait(bait_id: String) -> bool:
	var data = BAITS.get(bait_id)
	if data and spend_coins(data.price):
		bait_counts[bait_id] = bait_counts.get(bait_id, 0) + data.pack_amount
		current_bait = bait_id
		SoundManager.play_sfx("coin", 0.06)
		equipment_changed.emit()
		save_game()
		return true
	return false

func equip_bait(bait_id: String) -> void:
	if bait_counts.get(bait_id, 0) > 0:
		current_bait = bait_id
		SoundManager.play_sfx("coin", 0.08, -3.0)
		equipment_changed.emit()
		save_game()

func get_current_bait_boost() -> float:
	if bait_counts.get(current_bait, 0) > 0:
		var b_data = BAITS.get(current_bait, {})
		return b_data.get("rare_boost", 1.0)
	return 1.0

func consume_current_bait() -> float:
	var boost = get_current_bait_boost()
	if bait_counts.get(current_bait, 0) > 0:
		bait_counts[current_bait] -= 1
		if bait_counts[current_bait] <= 0:
			for k in ["isome", "okiami", "mussel", "shrimp", "lure"]:
				if bait_counts.get(k, 0) > 0:
					current_bait = k
					break
		equipment_changed.emit()
		save_game()
	return boost

# --- ★図鑑・釣果記録システム ---
func record_fish_catch(species: String, size: float) -> Dictionary:
	var is_first = not fish_records.has(species)
	var is_new_record = false
	
	if is_first:
		fish_records[species] = {
			"caught_count": 1,
			"max_size": size
		}
		is_new_record = true
	else:
		var rec = fish_records[species]
		rec.caught_count += 1
		if size > rec.max_size:
			rec.max_size = size
			is_new_record = true
			
	book_updated.emit(species, is_first, is_new_record)
	save_game()
	return {
		"is_first": is_first,
		"is_new_record": is_new_record
	}

func get_discovered_count() -> int:
	return fish_records.size()

func get_total_species_count() -> int:
	return FISH_DATABASE.size()

# --- ★セーブ＆ロード機能 (Web/Local両対応) ---

func save_game() -> bool:
	var save_dict = {
		"version": 1,
		"coins": coins,
		"current_rod": current_rod,
		"current_bait": current_bait,
		"inventory": inventory,
		"unlocked_rods": unlocked_rods,
		"bait_counts": bait_counts,
		"fish_records": fish_records,
		"has_boots": has_boots,
		"has_axe": has_axe,
		"has_boat": has_boat,
		"is_log_cleared": is_log_cleared,
		"is_on_island": is_on_island
	}
	
	var json_str = JSON.stringify(save_dict)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("Failed to open save file for writing: " + SAVE_PATH)
		return false
		
	file.store_string(json_str)
	file.close()
	game_saved.emit()
	return true

func load_game() -> bool:
	if not has_save_file():
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
		
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_err = json.parse(json_str)
	if parse_err != OK:
		push_warning("Failed to parse save file JSON: " + json.get_error_message())
		return false
		
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return false
		
	# データを復元
	coins = data.get("coins", 60)
	current_rod = data.get("current_rod", "starter_rod")
	if not RODS.has(current_rod):
		current_rod = "starter_rod"
	current_bait = data.get("current_bait", "isome")
	if not BAITS.has(current_bait):
		current_bait = "isome"
	
	# インベントリ
	inventory.clear()
	var raw_inv = data.get("inventory", [])
	if typeof(raw_inv) == TYPE_ARRAY:
		for item in raw_inv:
			if typeof(item) == TYPE_DICTIONARY:
				inventory.append(item)
				
	# 解放済みの竿
	var raw_rods = data.get("unlocked_rods", ["starter_rod"])
	if typeof(raw_rods) == TYPE_ARRAY:
		unlocked_rods.clear()
		for rod in raw_rods:
			var s_rod = str(rod)
			if RODS.has(s_rod):
				unlocked_rods.append(s_rod)
	if unlocked_rods.is_empty():
		unlocked_rods.append("starter_rod")
		
	# エサ所持数
	var raw_baits = data.get("bait_counts", {})
	if typeof(raw_baits) == TYPE_DICTIONARY:
		for k in ["isome", "okiami", "mussel", "shrimp", "lure"]:
			bait_counts[k] = int(raw_baits.get(k, 0))
	if bait_counts.get("isome", 0) <= 0 and bait_counts.get("mussel", 0) <= 0:
		bait_counts["isome"] = 5
		bait_counts["okiami"] = 5
		bait_counts["mussel"] = 3
			
	# 図鑑記録
	fish_records.clear()
	var raw_records = data.get("fish_records", {})
	if typeof(raw_records) == TYPE_DICTIONARY:
		for sp_key in raw_records.keys():
			var rec_data = raw_records[sp_key]
			if typeof(rec_data) == TYPE_DICTIONARY:
				fish_records[sp_key] = {
					"caught_count": int(rec_data.get("caught_count", 1)),
					"max_size": float(rec_data.get("max_size", 0.0))
				}
				
	# 探索道具
	has_boots = bool(data.get("has_boots", false))
	has_axe = bool(data.get("has_axe", false))
	has_boat = bool(data.get("has_boat", false))
	
	# ギミック
	is_log_cleared = bool(data.get("is_log_cleared", false))
	is_on_island = bool(data.get("is_on_island", false))
	
	# 全シグナルを発行してUIと同期
	coins_changed.emit(coins)
	inventory_changed.emit()
	equipment_changed.emit()
	game_loaded.emit()
	return true

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func reset_save_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	coins = 60
	current_rod = "starter_rod"
	current_bait = "isome"
	inventory.clear()
	unlocked_rods = ["starter_rod"]
	bait_counts = {
		"isome": 5,
		"okiami": 5,
		"mussel": 3,
		"shrimp": 0,
		"lure": 0
	}
	fish_records.clear()
	has_boots = false
	has_axe = false
	has_boat = false
	is_log_cleared = false
	is_on_island = false
	
	coins_changed.emit(coins)
	inventory_changed.emit()
	equipment_changed.emit()
	save_game()
