extends Node2D

# 水面に浮かぶウキ（ボバー）と釣り糸

var is_in_water: bool = false
var target_pos: Vector2 = Vector2(600, 430)
var current_pos: Vector2 = Vector2(250, 280)
var bob_offset: float = 0.0
var time_counter: float = 0.0

var rod_tip_pos: Vector2 = Vector2(250, 280)

# 波紋エフェクトデータ
var ripples: Array[Dictionary] = []
var ripple_timer: float = 0.0

# アタリ・HIT演出
var nibble_offset: float = 0.0
var show_hit_mark: bool = false
var hit_scale: float = 1.0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	time_counter += delta
	
	if is_in_water:
		# 水面での上下のゆらめき
		bob_offset = sin(time_counter * 3.0) * 4.0 + nibble_offset
		current_pos = current_pos.lerp(target_pos, delta * 5.0)
		
		# 波紋の生成
		ripple_timer += delta
		if ripple_timer > 0.8:
			ripple_timer = 0.0
			ripples.append({"radius": 2.0, "alpha": 0.8})
	else:
		current_pos = current_pos.lerp(rod_tip_pos, delta * 12.0)
		bob_offset = 0.0
	
	# 既存の波紋を拡大・フェードアウト
	var i = ripples.size() - 1
	while i >= 0:
		ripples[i]["radius"] += delta * 25.0
		ripples[i]["alpha"] -= delta * 0.7
		if ripples[i]["alpha"] <= 0.0:
			ripples.remove_at(i)
		i -= 1

	if show_hit_mark:
		hit_scale = 1.0 + sin(time_counter * 15.0) * 0.15

	queue_redraw()

func cast_to(pos: Vector2) -> void:
	target_pos = pos
	is_in_water = true
	# 着水時に波紋
	ripples.append({"radius": 5.0, "alpha": 1.0})
	ripples.append({"radius": 1.0, "alpha": 1.0})

func pull_back() -> void:
	is_in_water = false
	show_hit_mark = false
	nibble_offset = 0.0

func set_nibble(active: bool) -> void:
	if active:
		nibble_offset = 7.0 # 少し沈む
		ripples.append({"radius": 3.0, "alpha": 0.9})
	else:
		nibble_offset = 0.0

func set_hit(active: bool) -> void:
	show_hit_mark = active
	if active:
		nibble_offset = 15.0 # グッと深く沈む
		for k in range(3):
			ripples.append({"radius": 2.0 + k * 4.0, "alpha": 1.0})

func _draw() -> void:
	var final_pos = current_pos + Vector2(0, bob_offset)
	
	# 1. 釣り糸（竿先からウキへ）
	if is_in_water:
		# 少したわみのある糸
		var mid_point = (rod_tip_pos + final_pos) * 0.5 + Vector2(0, 30)
		draw_line(rod_tip_pos, mid_point, Color(1, 1, 1, 0.5), 1.0)
		draw_line(mid_point, final_pos, Color(1, 1, 1, 0.5), 1.0)
	
	# 2. 波紋の描画
	for r in ripples:
		var col = Color(1, 1, 1, clampf(r["alpha"] * 0.5, 0.0, 1.0))
		draw_ellipse(final_pos + Vector2(0, 6), r["radius"], r["radius"] * 0.35, col, 1.5)
	
	if not is_in_water:
		return
		
	# 3. ウキの影
	draw_ellipse(final_pos + Vector2(0, 8), 10, 4, Color(0, 0, 0, 0.25))
	
	# 4. ウキ（紅白の浮き子）
	# 下半分（白）
	draw_arc(final_pos, 9.0, 0, PI, 16, Color.WHITE, 9.0, false)
	# 上半分（赤）
	draw_arc(final_pos, 9.0, PI, TAU, 16, Color("e63946"), 9.0, false)
	# 芯（アンテナ棒）
	draw_line(final_pos - Vector2(0, 15), final_pos + Vector2(0, 5), Color("2b2d42"), 2.0)
	draw_circle(final_pos - Vector2(0, 15), 3.0, Color("fca311"))
	
	# 5. HIT! の吹き出し演出
	if show_hit_mark:
		var mark_pos = final_pos + Vector2(0, -45)
		draw_set_transform(mark_pos, 0, Vector2(hit_scale, hit_scale))
		
		# 吹き出し背景
		draw_circle(Vector2.ZERO, 20, Color("ffb703"))
		draw_circle(Vector2.ZERO, 17, Color("fb8500"))
		
		# 「！」マーク
		draw_rect(Rect2(-3, -11, 6, 12), Color.WHITE, true)
		draw_circle(Vector2(0, 6), 3.5, Color.WHITE)
		
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
