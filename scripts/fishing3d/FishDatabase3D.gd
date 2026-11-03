extends RefCounted
class_name FishDatabase3D

# --- 福岡・糸島 野北海岸の魚種マスターデータ（GameDataと完全連携） ---

# 魚ごとのテクスチャとファイト設定（GameDataのFISH_DATABASEと結合）
const FISH_SPECS = {
	"aji": {
		"texture": "res://assets/fish_side_aji.png",
		"power": 0.65,
		"stamina": 5.5,
		"pull_freq": 2.8
	},
	"kisu": {
		"texture": "res://assets/fish_side_kisu.png",
		"power": 0.60,
		"stamina": 5.0,
		"pull_freq": 3.2
	},
	"arakabu": {
		"texture": "res://assets/fish_side_arakabu.png",
		"power": 0.85,
		"stamina": 7.5,
		"pull_freq": 1.6
	},
	"chinu": {
		"texture": "res://assets/fish_side_chinu.png",
		"power": 1.25,
		"stamina": 12.0,
		"pull_freq": 2.1
	},
	"magochi": {
		"texture": "res://assets/fish_side_magochi.png",
		"power": 1.15,
		"stamina": 11.0,
		"pull_freq": 1.9
	},
	"suzuki": {
		"texture": "res://assets/fish_side_suzuki.png",
		"power": 1.45,
		"stamina": 15.0,
		"pull_freq": 2.3
	},
	"kijihata": {
		"texture": "res://assets/fish_side_kijihata.png",
		"power": 1.35,
		"stamina": 13.0,
		"pull_freq": 1.7
	},
	"hirame": {
		"texture": "res://assets/fish_side_hirame.png",
		"power": 1.40,
		"stamina": 14.0,
		"pull_freq": 2.0
	},
	"madai": {
		"texture": "res://assets/fish_side_madai.png",
		"power": 1.55,
		"stamina": 16.5,
		"pull_freq": 1.8
	},
	"aoriika": {
		"texture": "res://assets/fish_side_aoriika.png",
		"power": 1.20,
		"stamina": 11.0,
		"pull_freq": 2.6
	}
}

static func get_fish_dict(species_id: String) -> Dictionary:
	var base_data = {}
	if GameData and GameData.FISH_DATABASE.has(species_id):
		base_data = GameData.FISH_DATABASE[species_id].duplicate()
	else:
		base_data = {
			"id": species_id,
			"name": species_id,
			"scientific_name": "",
			"rarity": "Common",
			"base_price": 50,
			"min_size": 20.0,
			"max_size": 40.0,
			"habitat": "野北海岸",
			"desc": ""
		}
		
	var spec = FISH_SPECS.get(species_id, {})
	base_data["texture"] = spec.get("texture", "res://assets/fish_side_aji.png")
	base_data["power"] = spec.get("power", 1.0)
	base_data["stamina"] = spec.get("stamina", 10.0)
	base_data["pull_freq"] = spec.get("pull_freq", 2.0)
	
	var len_val = snapped(randf_range(base_data["min_size"], base_data["max_size"]), 0.1)
	base_data["length"] = len_val
	base_data["size"] = len_val
	base_data["weight"] = snapped((len_val * len_val * len_val) * 0.000014 * randf_range(0.85, 1.15), 0.05)
	if base_data["weight"] < 0.08: base_data["weight"] = 0.08
	
	# 価格計算（基本価格 + サイズ補正）
	var size_ratio = (len_val - base_data["min_size"]) / max(1.0, (base_data["max_size"] - base_data["min_size"]))
	base_data["price"] = int(base_data["base_price"] * (1.0 + size_ratio * 1.5))
	return base_data

static func get_random_fish(is_night: bool = false, distance: float = 8.0, cast_x: float = -8.0) -> Dictionary:
	var pool = []
	
	if cast_x > 0.0:
		# 砂浜サーフエリア
		pool = ["kisu", "kisu", "magochi", "hirame", "aji"]
	elif distance > 10.5:
		# 大波止先端・沖合深場
		if is_night:
			pool = ["suzuki", "suzuki", "aoriika", "madai", "kijihata"]
		else:
			pool = ["madai", "suzuki", "hirame", "aoriika", "aji"]
	elif is_night:
		# 夜間の波止・テトラ際
		pool = ["suzuki", "aoriika", "arakabu", "chinu", "aji"]
	else:
		# 日中の波止周辺
		pool = ["aji", "aji", "arakabu", "chinu", "kisu", "aoriika"]
	
	var chosen_key = pool[randi() % pool.size()]
	return get_fish_dict(chosen_key)
