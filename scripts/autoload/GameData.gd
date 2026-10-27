extends Node

# --- ゲームデータ管理シングルトン (Autoload) ---

signal coins_changed(new_amount: int)
signal inventory_changed()
signal equipment_changed()
signal tool_unlocked(tool_id: String)
signal book_updated(species: String, is_first: bool, is_record: bool)

# プレイヤーのステータス
var coins: int = 60 # 初期所持金
var current_rod: String = "branch_rod"
var current_bait: String = "worm"

# 所持品
var inventory: Array[Dictionary] = [] # 釣った魚リスト
var unlocked_rods: Array[String] = ["branch_rod"]
var bait_counts: Dictionary = {
	"worm": 5,
	"dumpling": 0,
	"lure": 0
}

# ★図鑑記録: species -> { "caught_count": int, "max_size": float }
var fish_records: Dictionary = {}

# ★探索道具（Key Items）の所持状況
var has_boots: bool = false # ゴム長靴（浅瀬を渡れる）
var has_axe: bool = false   # 木こりのオノ（倒木を壊せる）
var has_boat: bool = false  # 手漕ぎボート（湖の沖へ出られる）

# マップギミック解放状況
var is_log_cleared: bool = false # 倒木が破壊されたか
var is_on_island: bool = false   # 孤島にいるか

# --- マスターデータ ---

# 釣り竿カタログ
const RODS: Dictionary = {
	"branch_rod": {
		"id": "branch_rod",
		"name": "木の枝竿",
		"price": 0,
		"power": 1.0,
		"stability": 1.0,
		"desc": "拾った丈夫な枝で作った手製の竿。素朴で手になじむ。"
	},
	"bamboo_rod": {
		"id": "bamboo_rod",
		"name": "竹のしなやか竿",
		"price": 120,
		"power": 1.35,
		"stability": 1.25,
		"desc": "よくしなる竹で作られた竿。アタリの引きをいなしやすい。"
	},
	"carbon_rod": {
		"id": "carbon_rod",
		"name": "炭素繊維の清流竿",
		"price": 380,
		"power": 1.8,
		"stability": 1.5,
		"desc": "軽くて強靭な素材の竿。大きな魚もしっかり引き寄せる。"
	},
	"master_rod": {
		"id": "master_rod",
		"name": "名人の月影竿",
		"price": 950,
		"power": 2.4,
		"stability": 2.0,
		"desc": "夜光塗料が施された名工の逸品。巨大な主をも引き上げる。"
	}
}

# 探索道具カタログ
const TOOLS: Dictionary = {
	"boots": {
		"id": "boots",
		"name": "ゴム長靴",
		"icon": "",
		"price": 100,
		"desc": "膝下まである丈夫な長靴。川の浅瀬をジャブジャブ歩いて渡れる！"
	},
	"axe": {
		"id": "axe",
		"name": "木こりのオノ",
		"icon": "",
		"price": 250,
		"desc": "切れ味の良い手斧。道をふさぐ倒木を壊して秘密のスポットを開拓！"
	},
	"boat": {
		"id": "boat",
		"name": "手漕ぎボート",
		"icon": "",
		"price": 600,
		"desc": "小さな木製ボート。湖の沖合へ漕ぎ出し、未知の主が住む孤島へ！"
	}
}

# エサカタログ
const BAITS: Dictionary = {
	"worm": {
		"id": "worm",
		"name": "みみず",
		"pack_amount": 5,
		"price": 15,
		"rare_boost": 1.0,
		"desc": "元気なミミズ。どんな魚も好む定番のエサ。"
	},
	"dumpling": {
		"id": "dumpling",
		"name": "だんごエサ",
		"pack_amount": 5,
		"price": 40,
		"rare_boost": 1.4,
		"desc": "香ばしい香りが広がる練り餌。池や湖の魚が集まる。"
	},
	"lure": {
		"id": "lure",
		"name": "きらめくルアー",
		"pack_amount": 3,
		"price": 90,
		"rare_boost": 2.0,
		"desc": "光を反射してキラキラ輝く擬似餌。珍しい魚が大興奮！"
	}
}

# 魚データベース
const FISH_DATABASE: Dictionary = {
	"medaka": {
		"id": "medaka",
		"name": "メダカ",
		"rarity": "Common",
		"base_price": 10,
		"min_size": 2.5,
		"max_size": 4.5,
		"habitat": "穏やかな小川・水草の茂み",
		"desc": "小さくてすばしっこい小川のアイドル。群れで泳ぐ姿が可愛い。"
	},
	"yamame": {
		"id": "yamame",
		"name": "ヤマメ",
		"rarity": "Rare",
		"base_price": 55,
		"min_size": 18.0,
		"max_size": 28.0,
		"habitat": "川の中流・桟橋付近の早瀬",
		"desc": "「渓流の女王」と呼ばれる美しい斑紋の川魚。警戒心が強い。"
	},
	"funa": {
		"id": "funa",
		"name": "ギンブナ",
		"rarity": "Common",
		"base_price": 25,
		"min_size": 15.0,
		"max_size": 26.0,
		"habitat": "中央広場の池・のんびりした岸辺",
		"desc": "のんびり池底の藻を食べる丸っこい魚。日本の釣りの原点。"
	},
	"koi": {
		"id": "koi",
		"name": "ニシキゴイ",
		"rarity": "Epic",
		"base_price": 120,
		"min_size": 38.0,
		"max_size": 60.0,
		"habitat": "中央広場の池・池の深み",
		"desc": "白地に鮮やかな朱赤と墨が映える池の貴族。優雅に泳ぐ。"
	},
	"catfish": {
		"id": "catfish",
		"name": "ナマズ",
		"rarity": "Epic",
		"base_price": 140,
		"min_size": 45.0,
		"max_size": 68.0,
		"habitat": "中央広場の池・水底の暗がり",
		"desc": "長いヒゲとつぶらな瞳がチャーミング。池底に潜む大物。"
	},
	"iwana": {
		"id": "iwana",
		"name": "イワナ",
		"rarity": "Rare",
		"base_price": 85,
		"min_size": 20.0,
		"max_size": 32.0,
		"habitat": "西の原生林（長靴で渡った先）",
		"desc": "原生林の源流に棲む「幻の深山魚」。白い斑点と力強い引きが魅力。"
	},
	"rainbow_trout": {
		"id": "rainbow_trout",
		"name": "ニジマス",
		"rarity": "Epic",
		"base_price": 175,
		"min_size": 30.0,
		"max_size": 52.0,
		"habitat": "秘密の滝壺（オノで開通した先）",
		"desc": "秘密の滝壺に輝く美しい魚。体側の虹色の帯が鮮やかにきらめく。"
	},
	"golden_koi": {
		"id": "golden_koi",
		"name": "黄金の主",
		"rarity": "Legendary",
		"base_price": 600,
		"min_size": 75.0,
		"max_size": 110.0,
		"habitat": "神秘の孤島沖（ボートで渡った先）",
		"desc": "湖の中央の孤島に眠る伝説の主。全身が神々しい黄金の光を放つ。"
	}
}

func _ready() -> void:
	pass

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

func spend_coins(cost: int) -> bool:
	if coins >= cost:
		coins -= cost
		coins_changed.emit(coins)
		return true
	return false

# 魚インベントリ
func add_caught_fish(fish_dict: Dictionary) -> void:
	inventory.append(fish_dict)
	inventory_changed.emit()

func sell_fish_at(index: int) -> int:
	if index < 0 or index >= inventory.size():
		return 0
	var fish = inventory[index]
	var price = fish.get("price", 10)
	inventory.remove_at(index)
	add_coins(price)
	inventory_changed.emit()
	SoundManager.play_sfx("coin", 0.08)
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
		return true
	var data = RODS.get(rod_id)
	if data and spend_coins(data.price):
		unlocked_rods.append(rod_id)
		current_rod = rod_id
		SoundManager.play_sfx("coin", 0.05)
		equipment_changed.emit()
		return true
	return false

func equip_rod(rod_id: String) -> void:
	if rod_id in unlocked_rods:
		current_rod = rod_id
		SoundManager.play_sfx("coin", 0.08, -3.0)
		equipment_changed.emit()

func buy_bait(bait_id: String) -> bool:
	var data = BAITS.get(bait_id)
	if data and spend_coins(data.price):
		bait_counts[bait_id] = bait_counts.get(bait_id, 0) + data.pack_amount
		current_bait = bait_id
		SoundManager.play_sfx("coin", 0.06)
		equipment_changed.emit()
		return true
	return false

func equip_bait(bait_id: String) -> void:
	if bait_counts.get(bait_id, 0) > 0:
		current_bait = bait_id
		SoundManager.play_sfx("coin", 0.08, -3.0)
		equipment_changed.emit()

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
			for k in ["lure", "dumpling", "worm"]:
				if bait_counts.get(k, 0) > 0:
					current_bait = k
					break
		equipment_changed.emit()
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
	return {
		"is_first": is_first,
		"is_new_record": is_new_record
	}

func get_discovered_count() -> int:
	return fish_records.size()

func get_total_species_count() -> int:
	return FISH_DATABASE.size()
