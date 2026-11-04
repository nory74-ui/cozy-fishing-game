extends RefCounted
class_name FishDatabase3D

# --- 福岡・糸島 野北海岸の魚種マスターデータ（GameDataと完全連携） ---

# 魚ごとのテクスチャとファイト設定（GameDataのFISH_DATABASEと結合）
const FISH_SPECS = {
	"aji": {
		"texture": "res://assets/fish_side_aji.png",
		"power": 0.65,
		"stamina": 5.5,
		"pull_freq": 2.8,
		"preferred_baits": ["okiami", "isome"],
		"min_rod_rank": 1,
		"recommended_line_kg": 1.5
	},
	"kisu": {
		"texture": "res://assets/fish_side_kisu.png",
		"power": 0.60,
		"stamina": 5.0,
		"pull_freq": 3.2,
		"preferred_baits": ["isome", "okiami"],
		"min_rod_rank": 1,
		"recommended_line_kg": 1.5
	},
	"arakabu": {
		"texture": "res://assets/fish_side_arakabu.png",
		"power": 0.85,
		"stamina": 7.5,
		"pull_freq": 1.6,
		"preferred_baits": ["isome", "crab_bait", "okiami"],
		"min_rod_rank": 1,
		"recommended_line_kg": 2.0
	},
	"chinu": {
		"texture": "res://assets/fish_side_chinu.png",
		"power": 1.25,
		"stamina": 12.0,
		"pull_freq": 2.1,
		"preferred_baits": ["crab_bait", "isome"],
		"min_rod_rank": 2,
		"recommended_line_kg": 4.5
	},
	"magochi": {
		"texture": "res://assets/fish_side_magochi.png",
		"power": 1.15,
		"stamina": 11.0,
		"pull_freq": 1.9,
		"preferred_baits": ["live_fish", "isome", "lure"],
		"min_rod_rank": 2,
		"recommended_line_kg": 5.0
	},
	"suzuki": {
		"texture": "res://assets/fish_side_suzuki.png",
		"power": 1.45,
		"stamina": 15.0,
		"pull_freq": 2.3,
		"preferred_baits": ["live_fish", "lure"],
		"min_rod_rank": 3,
		"recommended_line_kg": 8.0
	},
	"kijihata": {
		"texture": "res://assets/fish_side_kijihata.png",
		"power": 1.35,
		"stamina": 13.0,
		"pull_freq": 1.7,
		"preferred_baits": ["crab_bait", "live_fish"],
		"min_rod_rank": 2,
		"recommended_line_kg": 5.5
	},
	"hirame": {
		"texture": "res://assets/fish_side_hirame.png",
		"power": 1.40,
		"stamina": 14.0,
		"pull_freq": 2.0,
		"preferred_baits": ["live_fish", "lure"],
		"min_rod_rank": 3,
		"recommended_line_kg": 8.5
	},
	"madai": {
		"texture": "res://assets/fish_side_madai.png",
		"power": 1.55,
		"stamina": 16.5,
		"pull_freq": 1.8,
		"preferred_baits": ["lure", "crab_bait", "okiami"],
		"min_rod_rank": 3,
		"recommended_line_kg": 10.0
	},
	"aoriika": {
		"texture": "res://assets/fish_side_aoriika.png",
		"power": 1.20,
		"stamina": 11.0,
		"pull_freq": 2.6,
		"preferred_baits": ["lure", "live_fish"],
		"min_rod_rank": 2,
		"recommended_line_kg": 4.5
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
	base_data["preferred_baits"] = spec.get("preferred_baits", ["okiami", "isome"])
	base_data["min_rod_rank"] = spec.get("min_rod_rank", 1)
	base_data["recommended_line_kg"] = spec.get("recommended_line_kg", 2.0)
	
	var len_val = snapped(randf_range(base_data["min_size"], base_data["max_size"]), 0.1)
	base_data["length"] = len_val
	base_data["size"] = len_val
	base_data["weight"] = snapped((len_val * len_val * len_val) * 0.000014 * randf_range(0.85, 1.15), 0.05)
	if base_data["weight"] < 0.08: base_data["weight"] = 0.08

	var w_kg: float = base_data["weight"]
	# 重量クラスと3D魚影サイズ・引きの重さパラメータを計算
	if w_kg < 0.45:
		base_data["weight_class"] = "light"
		base_data["weight_label"] = "軽量級（小気味よい引き）"
		base_data["shadow_scale"] = clamp(0.24 + (len_val / 100.0) * 0.25, 0.24, 0.34)
		base_data["reel_speed_mult"] = 1.25 # 軽いのでスイスイ寄ってくるが口切れ注意
		base_data["dash_pull_speed"] = 0.65
	elif w_kg < 2.2:
		base_data["weight_class"] = "medium"
		base_data["weight_label"] = "中量級（力強い突っ込み）"
		base_data["shadow_scale"] = clamp(0.35 + (len_val / 100.0) * 0.28, 0.35, 0.48)
		base_data["reel_speed_mult"] = 0.82 # 適度な重み
		base_data["dash_pull_speed"] = 1.45
	else:
		base_data["weight_class"] = "heavy"
		base_data["weight_label"] = "重量級・大物（強烈な重量感と疾走！）"
		base_data["shadow_scale"] = clamp(0.50 + (len_val / 100.0) * 0.30, 0.50, 0.72)
		base_data["reel_speed_mult"] = clamp(0.52 - (w_kg - 2.2) * 0.025, 0.32, 0.52) # ズッシリ重く簡単には寄らない
		base_data["dash_pull_speed"] = clamp(2.1 + (w_kg - 2.2) * 0.15, 2.1, 3.2)

	# 価格計算（基本価格 + サイズ補正）
	var size_ratio = (len_val - base_data["min_size"]) / max(1.0, (base_data["max_size"] - base_data["min_size"]))
	base_data["price"] = int(base_data["base_price"] * (1.0 + size_ratio * 1.5))
	return base_data

static func get_random_fish(is_night: bool = false, distance: float = 4.0, cast_x: float = -4.0, power_ratio: float = 0.5, current_bait: String = "okiami") -> Dictionary:
	var pool = []

	# 力加減（近い・中間・遠い）と水深によって釣れる魚種・サイズ帯の基本候補
	if power_ratio < 0.35 or distance < 2.8:
		# ちょい投げ（波打ち際・浅瀬）：シロギス・アジ・アラカブなど軽量級中心
		if is_night:
			pool = ["aji", "aji", "arakabu", "arakabu", "kisu", "chinu"]
		else:
			pool = ["kisu", "kisu", "kisu", "aji", "aji", "arakabu", "magochi"]
	elif power_ratio < 0.72 or distance < 4.8:
		# 中投げ（藻場・沈み瀬周辺）：中量級〜良型が揃う
		if is_night:
			pool = ["aoriika", "chinu", "arakabu", "kijihata", "suzuki", "aji"]
		else:
			pool = ["chinu", "magochi", "aoriika", "kijihata", "aji", "kisu", "hirame"]
	else:
		# フルキャスト（沖合の深場・潮目）：マダイ・スズキ・ヒラメなど重量級の大物確率UP！
		if is_night:
			pool = ["suzuki", "suzuki", "madai", "kijihata", "aoriika", "hirame"]
		else:
			pool = ["madai", "madai", "hirame", "suzuki", "kijihata", "chinu", "magochi"]

	# ★エサ適合フィルタリング: 現在装備しているエサを好む魚種のみを抽出！
	var bait_matched_pool: Array[String] = []
	for sp_id in pool:
		var spec = FISH_SPECS.get(sp_id, {})
		var pref_baits = spec.get("preferred_baits", [])
		if current_bait in pref_baits:
			bait_matched_pool.append(sp_id)

	# もし現在の距離プール内に好餌魚がいなかった場合、全魚種からそのエサを好む魚を探索
	if bait_matched_pool.is_empty():
		for sp_id in FISH_SPECS.keys():
			var spec = FISH_SPECS[sp_id]
			var pref_baits = spec.get("preferred_baits", [])
			if current_bait in pref_baits:
				bait_matched_pool.append(sp_id)

	# 万一エサ未指定等の場合はフォールバック
	if bait_matched_pool.is_empty():
		bait_matched_pool = ["aji", "kisu"]

	var chosen_key = bait_matched_pool[randi() % bait_matched_pool.size()]
	return get_fish_dict(chosen_key)
