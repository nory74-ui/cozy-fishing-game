extends Node2D

# 水面に浮かぶウキ（パステル調の波紋、糸、食いつき演出）

signal fish_bitten()

var is_active: bool = false
var bob_offset: float = 0.0
var time_counter: float = 0.0

var ripples: Array[Dictionary] = []
var ripple_timer: float = 0.0

var is_bitten: bool = false
var bite_anim_timer: float = 0.0
var nibble_dip: float = 0.0
var occupied_by_fish: Node2D = null

var player_node: Node2D = null

func _ready() -> void:
	visible = false

func launch(target_global_pos: Vector2, player: Node2D) -> void:
	player_node = player
	global_position = target_global_pos
	is_active = true
	is_bitten = false
	nibble_dip = 0.0
	occupied_by_fish = null
	visible = true
	ripples.clear()
	# 着水波紋
	ripples.append({"radius": 4.0, "alpha": 0.8})
	ripples.append({"radius": 1.0, "alpha": 0.8})

func retrieve() -> void:
	is_active = false
	is_bitten = false
	nibble_dip = 0.0
	occupied_by_fish = null
	visible = false
	ripples.clear()

func trigger_nibble(strength: float = 4.0) -> void:
	nibble_dip = strength
	ripples.append({"radius": 2.0 + strength * 0.5, "alpha": 0.85})
	SoundManager.play_sfx("cast", 0.25, -13.0 + strength)

func trigger_bite() -> void:
	is_bitten = true
	bite_anim_timer = 0.0
	fish_bitten.emit()
	# 食いつき時のダイナミックな波紋群
	for i in range(4):
		ripples.append({"radius": 3.0 + i * 5.0, "alpha": 0.95})

func _process(delta: float) -> void:
	if not is_active:
		return
		
	time_counter += delta
	if nibble_dip > 0.0:
		nibble_dip = move_toward(nibble_dip, 0.0, delta * 15.0)
	bob_offset = sin(time_counter * 3.5) * 2.0 + nibble_dip
	
	if is_bitten:
		bite_anim_timer += delta
		bob_offset += 8.5 # グッと力強く水中に引き込まれるリアルな沈み込み！

	# 波紋の定期発生
	ripple_timer += delta
	if ripple_timer > 0.7:
		ripple_timer = 0.0
		ripples.append({"radius": 2.0, "alpha": 0.7})
		
	# 波紋の更新
	var i = ripples.size() - 1
	while i >= 0:
		ripples[i]["radius"] += delta * 20.0
		ripples[i]["alpha"] -= delta * 0.6
		if ripples[i]["alpha"] <= 0.0:
			ripples.remove_at(i)
		i -= 1
		
	queue_redraw()

func _draw() -> void:
	if not is_active:
		return
		
	var draw_pos = Vector2(0, bob_offset)
	
	# 1. 釣り糸（プレイヤーの竿先からウキへ）
	if player_node and player_node.has_method("get_rod_tip_global_pos"):
		var tip_pos = to_local(player_node.get_rod_tip_global_pos())
		var mid = (tip_pos + draw_pos) * 0.5 + Vector2(0, 15)
		draw_line(tip_pos, mid, Color(1, 1, 1, 0.45), 1.0)
		draw_line(mid, draw_pos, Color(1, 1, 1, 0.45), 1.0)

	# 2. 波紋（淡い水色〜白の輪）
	for r in ripples:
		var c = Color(1, 1, 1, clampf(r["alpha"] * 0.45, 0.0, 1.0))
		draw_ellipse(draw_pos + Vector2(0, 2), r["radius"], r["radius"] * 0.5, c, 1.5)

	# 3. ウキの影
	draw_ellipse(draw_pos + Vector2(0, 4), 6.0, 3.0, Color(0, 0, 0, 0.2))

	# 4. パステルのウキ（淡いコーラルピンク & ミルキーホワイト）
	var col_top = Color("#f28482") # 淡いコーラル
	var col_bot = Color("#ffffff")
	draw_circle(draw_pos, 6.0, col_top)
	draw_circle(draw_pos + Vector2(0, 2), 4.5, col_bot)
	draw_line(draw_pos - Vector2(0, 8), draw_pos, Color("#84a59d"), 1.5)
	draw_circle(draw_pos - Vector2(0, 8), 2.0, Color("#f6bd60"))

	# 5. 「！」マーク（食いついた瞬間）
	if is_bitten:
		var mark_offset = Vector2(0, -22 - sin(bite_anim_timer * 12.0) * 3.0)
		draw_circle(mark_offset, 10.0, Color("#ffb703"))
		draw_circle(mark_offset, 8.0, Color("#f77f00"))
		#  exclamation
		draw_rect(Rect2(mark_offset.x - 1.5, mark_offset.y - 5, 3, 6), Color.WHITE, true)
		draw_circle(mark_offset + Vector2(0, 3.5), 1.5, Color.WHITE)
