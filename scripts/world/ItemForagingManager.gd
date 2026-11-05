extends Node2D

# =============================================================================
# うみかぜ日和 〜 福岡・糸島 野北編 〜
# 【沿岸アイテム採取システム (Item Foraging Manager)】
# 砂浜・防波堤に打ち上げられるサザエ、アワビ、桜貝、シーグラス、漂着ボトルの採取
# =============================================================================

signal item_collected(item_name: String, value: int, icon: String)

var items: Array[Dictionary] = []
var player_ref: Node2D = null
var time_counter: float = 0.0
var nearest_item_idx: int = -1

# アイテム定義テーブル
const ITEM_TYPES = [
	{
		"id": "sazae",
		"name": "天然サザエ",
		"value": 120,
		"icon": "◆",
		"zone": "pier", # 防波堤・磯根際
		"color": Color(0.4, 0.7, 0.5)
	},
	{
		"id": "awabi",
		"name": "玄界灘アワビ",
		"value": 280,
		"icon": "◆",
		"zone": "pier",
		"color": Color(0.9, 0.6, 0.3)
	},
	{
		"id": "sakuragai",
		"name": "きれいな桜貝",
		"value": 60,
		"icon": "◆",
		"zone": "beach", # 白砂サーフ波打ち際
		"color": Color(1.0, 0.6, 0.75)
	},
	{
		"id": "seaglass",
		"name": "シーグラス（海の宝石）",
		"value": 50,
		"icon": "◆",
		"zone": "beach",
		"color": Color(0.3, 0.85, 0.95)
	},
	{
		"id": "bottle",
		"name": "漂着メッセージボトル",
		"value": 150,
		"icon": "◆",
		"zone": "beach",
		"color": Color(0.95, 0.85, 0.4)
	}
]

func _ready() -> void:
	z_index = 3
	_spawn_initial_items()

func setup(player: Node2D) -> void:
	player_ref = player

func _spawn_initial_items() -> void:
	items.clear()
	# 防波堤の上（先端〜中腹）の海産物
	items.append(_create_item_instance("sazae", Vector2(440, 420)))
	items.append(_create_item_instance("sazae", Vector2(510, 640)))
	items.append(_create_item_instance("awabi", Vector2(560, 780)))
	
	# 白砂サーフの打ち上げ貝殻・シーグラス・ボトル
	items.append(_create_item_instance("sakuragai", Vector2(980, 800)))
	items.append(_create_item_instance("sakuragai", Vector2(1250, 750)))
	items.append(_create_item_instance("seaglass", Vector2(1450, 720)))
	items.append(_create_item_instance("seaglass", Vector2(1100, 900)))
	items.append(_create_item_instance("bottle", Vector2(1350, 880)))

func _create_item_instance(type_id: String, pos: Vector2) -> Dictionary:
	var def = {}
	for t in ITEM_TYPES:
		if t["id"] == type_id:
			def = t
			break
	return {
		"def": def,
		"pos": pos,
		"sparkle_offset": randf() * 10.0,
		"active": true,
		"respawn_timer": 0.0
	}

func _process(delta: float) -> void:
	time_counter += delta
	if not player_ref:
		player_ref = get_parent().get_node_or_null("Player")
		return

	# リスポーンタイマー更新
	for it in items:
		if not it["active"]:
			it["respawn_timer"] -= delta
			if it["respawn_timer"] <= 0.0:
				it["active"] = true

	# プレイヤーとの距離チェック（最近接アイテムを探す）
	nearest_item_idx = -1
	var min_dist = 65.0 # 採取可能距離
	var p_pos = player_ref.global_position
	
	for i in range(items.size()):
		var it = items[i]
		if not it["active"]: continue
		var d = p_pos.distance_to(it["pos"])
		if d < min_dist:
			min_dist = d
			nearest_item_idx = i

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			if nearest_item_idx >= 0:
				_collect_item(nearest_item_idx)
				get_viewport().set_input_as_handled()

func _collect_item(idx: int) -> void:
	var it = items[idx]
	if not it["active"]: return
	it["active"] = false
	it["respawn_timer"] = randf_range(30.0, 60.0) # 30〜60秒後に再スポーン
	
	var d = it["def"]
	GameData.add_coins(d["value"])
	SoundManager.play_sfx("pickup", 0.06)
	item_collected.emit(d["name"], d["value"], d["icon"])

func _draw() -> void:
	# キラキラ光る採取エフェクト
	for i in range(items.size()):
		var it = items[i]
		if not it["active"]: continue
		
		var pos = it["pos"]
		var d = it["def"]
		var c: Color = d["color"]
		
		# 星のきらめきパルス
		var pulse = (sin(time_counter * 5.0 + it["sparkle_offset"]) + 1.0) * 0.5
		var size = 6.0 + pulse * 4.0
		
		# 光輪
		draw_circle(pos, size * 1.5, Color(c.r, c.g, c.b, 0.25 * pulse))
		draw_circle(pos, size * 0.6, Color(1.0, 1.0, 0.9, 0.85))
		
		# 星の十字光
		var len_h = size * 2.0
		draw_line(pos - Vector2(len_h, 0), pos + Vector2(len_h, 0), Color(1.0, 1.0, 1.0, 0.75 * pulse), 1.8)
		draw_line(pos - Vector2(0, len_h), pos + Vector2(0, len_h), Color(1.0, 1.0, 1.0, 0.75 * pulse), 1.8)
		
		# 採取可能範囲内にいる時のガイド吹き出し
		if i == nearest_item_idx:
			var bubble_pos = pos + Vector2(0, -28)
			draw_circle(bubble_pos, 16.0, Color(0.12, 0.16, 0.2, 0.90))
			draw_arc(bubble_pos, 16.0, 0, TAU, 24, Color(1.0, 0.85, 0.3, 0.95), 2.0)
			# 「E」の文字風ライン
			draw_line(bubble_pos + Vector2(-4, -6), bubble_pos + Vector2(4, -6), Color.WHITE, 2.0)
			draw_line(bubble_pos + Vector2(-4, 0), bubble_pos + Vector2(2, 0), Color.WHITE, 2.0)
			draw_line(bubble_pos + Vector2(-4, 6), bubble_pos + Vector2(4, 6), Color.WHITE, 2.0)
			draw_line(bubble_pos + Vector2(-4, -6), bubble_pos + Vector2(-4, 6), Color.WHITE, 2.0)
