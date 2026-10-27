extends Node2D

# 本物の水彩画アセットで構築された「水彩の世界」フィールドマップ
# （ステップ4：浅瀬飛び石・エメラルド滝壺・湖の孤島・ボート乗り場対応）

var tex_grass: Texture2D
var tex_water: Texture2D
var tex_tree: Texture2D

var map_size = Vector2(2400, 1600)
var time_counter: float = 0.0

# 1. 池の形状
var pond_center = Vector2(1450, 800)
var pond_rx = 420.0
var pond_ry = 300.0
var safe_pond_rx = 360.0
var safe_pond_ry = 240.0

# 2. 湖の孤島（Mysterious Isle）
var island_center = Vector2(1450, 800)
var island_rx = 80.0
var island_ry = 55.0

# 3. 川の形状
var river_x = 420.0
var river_width = 180.0
var safe_river_half_width = 52.0

# 4. 浅瀬飛び石エリア（長靴ギミック）
var shallow_y_min = 1160.0
var shallow_y_max = 1240.0

# 5. 秘密のエメラルド滝壺（オノギミック開通先）
var basin_center = Vector2(1100, 170)
var basin_rx = 135.0
var basin_ry = 85.0
var safe_basin_rx = 95.0
var safe_basin_ry = 55.0

# 6. 桟橋の定義
var pond_pier_rect = Rect2(980, 760, 170, 80)    # 池の西桟橋（先端 x=1150）
var river_pier_rect = Rect2(440, 560, 140, 70)   # 川の桟橋（先端 x=440）
var boat_shore_pier = Rect2(1820, 775, 55, 50)   # 湖の東岸ボート桟橋
var island_dock_pier = Rect2(1500, 780, 50, 40)  # 孤島側の船着き場

# 装飾
var water_lilies: Array[Dictionary] = []
var trees: Array[Vector2] = []
var tree_sprites: Array[Sprite2D] = []

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	tex_grass = GameData.load_texture("res://assets/watercolor_grass_bg.jpg")
	tex_water = GameData.load_texture("res://assets/watercolor_water.jpg")
	tex_tree = GameData.load_texture("res://assets/watercolor_tree.png")
	
	_generate_trees()
	_generate_water_lilies()
	_build_collision_boundaries()

func _generate_trees() -> void:
	# 秘密の滝壺周り、原生林（川の西）、広場周りの木々
	var tree_positions = [
		# 西の原生林（浅瀬を渡った先の豊かな森）
		Vector2(140, 950), Vector2(180, 1100), Vector2(130, 1250), Vector2(190, 1380),
		Vector2(260, 1020), Vector2(250, 1350),
		Vector2(140, 220), Vector2(180, 480), Vector2(160, 720),
		
		# 川と池の間の森
		Vector2(680, 220), Vector2(760, 380), Vector2(850, 180),
		Vector2(700, 1050), Vector2(820, 1250), Vector2(660, 1380),
		
		# 滝壺の奥・左右を囲む原生木・険しい峡谷の森
		Vector2(920, 140), Vector2(980, 80), Vector2(1220, 90), Vector2(1280, 150),
		Vector2(1010, 340), Vector2(1190, 340), # 倒木の両脇にそびえる大木
		Vector2(940, 330), Vector2(870, 340), Vector2(800, 320), Vector2(720, 340), Vector2(640, 330), # 西の封鎖樹林
		Vector2(1250, 340), Vector2(1330, 330), Vector2(1410, 340), Vector2(1480, 320), # 東の封鎖樹林
		Vector2(860, 220), Vector2(880, 130), Vector2(1320, 220), Vector2(1360, 110), # 滝壺左右の深林
		
		# 池の東岸・南岸・北東の深林連峰
		Vector2(1780, 260), Vector2(1980, 450), Vector2(2050, 820), Vector2(1980, 1150),
		Vector2(1400, 1380), Vector2(1680, 1320), Vector2(1150, 1380),
		Vector2(1480, 200), Vector2(2150, 650),
		Vector2(1650, 280), Vector2(1850, 200), Vector2(2050, 240), Vector2(2250, 180), Vector2(1900, 360), Vector2(2100, 380) # 北東の山岳原生林
	]
	# マップ外周の境界木
	for x in range(80, int(map_size.x), 160):
		tree_positions.append(Vector2(x, 70 + randf_range(-15, 15)))
		tree_positions.append(Vector2(x, map_size.y - 70 + randf_range(-15, 15)))
		
	for p in tree_positions:
		trees.append(p)
		var spr = Sprite2D.new()
		spr.texture = tex_tree
		spr.position = p
		spr.scale = Vector2(0.24, 0.24) * randf_range(0.9, 1.15)
		add_child(spr)
		tree_sprites.append(spr)

func _generate_water_lilies() -> void:
	var lily_bases = [
		Vector2(1650, 650), Vector2(1720, 700), Vector2(1600, 620),
		Vector2(1300, 950), Vector2(1380, 980), Vector2(1250, 920),
		Vector2(1700, 920), Vector2(1760, 880),
		# 滝壺の睡蓮
		Vector2(1060, 160), Vector2(1140, 170)
	]
	for lb in lily_bases:
		water_lilies.append({
			"pos": lb + Vector2(randf_range(-14, 14), randf_range(-14, 14)),
			"radius": randf_range(15.0, 22.0),
			"has_flower": randf() > 0.4,
			"flower_color": Color("#ffb3c6") if randf() > 0.3 else Color("#fff0f3")
		})

func is_in_water(pos: Vector2) -> bool:
	if is_on_pier(pos) or is_on_island(pos): return false
	
	# 滝壺
	var bdx = (pos.x - basin_center.x) / basin_rx
	var bdy = (pos.y - basin_center.y) / basin_ry
	if (bdx * bdx + bdy * bdy) <= 1.0: return true

	# 池
	var dx = (pos.x - pond_center.x) / pond_rx
	var dy = (pos.y - pond_center.y) / pond_ry
	if (dx * dx + dy * dy) <= 1.0: return true
	
	# 川
	var wave_offset = sin(pos.y * 0.005) * 60.0
	var cur_rx = river_x + wave_offset
	if abs(pos.x - cur_rx) < (river_width * 0.5): return true
	
	return false

func is_on_pier(pos: Vector2) -> bool:
	return pond_pier_rect.has_point(pos) or river_pier_rect.has_point(pos) \
		or boat_shore_pier.has_point(pos) or island_dock_pier.has_point(pos)

func is_on_island(pos: Vector2) -> bool:
	var idx = (pos.x - island_center.x) / island_rx
	var idy = (pos.y - island_center.y) / island_ry
	return (idx * idx + idy * idy) <= 1.0

func is_castable_water(pos: Vector2) -> bool:
	return is_in_water(pos) and not is_on_pier(pos) and not is_on_island(pos)

func is_in_safe_water(pos: Vector2) -> bool:
	# 滝壺
	var bdx = (pos.x - basin_center.x) / safe_basin_rx
	var bdy = (pos.y - basin_center.y) / safe_basin_ry
	if (bdx * bdx + bdy * bdy) <= 1.0: return true

	# 池（孤島の内側は避ける）
	var pdx = (pos.x - pond_center.x) / safe_pond_rx
	var pdy = (pos.y - pond_center.y) / safe_pond_ry
	if (pdx * pdx + pdy * pdy) <= 1.0:
		var idx = (pos.x - island_center.x) / (island_rx + 20.0)
		var idy = (pos.y - island_center.y) / (island_ry + 20.0)
		if (idx * idx + idy * idy) >= 1.0: # 孤島の外側
			return true

	# 川
	var wave_offset = sin(pos.y * 0.005) * 60.0
	var cur_rx = river_x + wave_offset
	if abs(pos.x - cur_rx) <= safe_river_half_width: return true
	
	return false

func get_clamped_safe_water_pos(pos: Vector2) -> Vector2:
	# 1. 滝壺エリア
	if pos.distance_to(basin_center) < 250.0:
		var bdx = (pos.x - basin_center.x) / safe_basin_rx
		var bdy = (pos.y - basin_center.y) / safe_basin_ry
		var bd2 = bdx * bdx + bdy * bdy
		if bd2 > 1.0:
			var sc = 1.0 / sqrt(bd2)
			return basin_center + Vector2(bdx * safe_basin_rx * sc, bdy * safe_basin_ry * sc)
		return pos

	# 2. 池エリア
	var dist_to_pond = pos.distance_to(pond_center)
	if dist_to_pond < 600.0:
		var pdx = (pos.x - pond_center.x) / safe_pond_rx
		var pdy = (pos.y - pond_center.y) / safe_pond_ry
		var d2 = pdx * pdx + pdy * pdy
		var res = pos
		if d2 > 1.0:
			var scale = 1.0 / sqrt(d2)
			res = pond_center + Vector2(pdx * safe_pond_rx * scale, pdy * safe_pond_ry * scale)
			
		# 孤島との干渉防止（孤島の中にめり込まないよう押し出す）
		var dist_to_island = res.distance_to(island_center)
		var min_island_r = island_rx + 25.0
		if dist_to_island < min_island_r:
			var push_dir = (res - island_center).normalized()
			if push_dir.length_squared() < 0.01: push_dir = Vector2.RIGHT
			res = island_center + push_dir * min_island_r
			
		return res
		
	# 3. 川エリア
	else:
		var wave_offset = sin(pos.y * 0.005) * 60.0
		var cur_rx = river_x + wave_offset
		var cx = clampf(pos.x, cur_rx - safe_river_half_width, cur_rx + safe_river_half_width)
		var cy = clampf(pos.y, 80.0, map_size.y - 80.0)
		return Vector2(cx, cy)

func _build_collision_boundaries() -> void:
	var sb = StaticBody2D.new()
	add_child(sb)
	
	# 外周壁
	var thickness = 60.0
	var bounds = [
		Rect2(0, -thickness, map_size.x, thickness),
		Rect2(0, map_size.y, map_size.x, thickness),
		Rect2(-thickness, 0, thickness, map_size.y),
		Rect2(map_size.x, 0, thickness, map_size.y)
	]
	for r in bounds:
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = r.size
		col.shape = shape
		col.position = r.position + r.size * 0.5
		sb.add_child(col)

	# 木の幹
	for tree_pos in trees:
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 20.0
		col.shape = shape
		col.position = tree_pos + Vector2(0, 35)
		sb.add_child(col)

	# 1. 池の水際侵入防止コリジョン（64分割で隙間なく桟橋と完全密閉）
	var pond_segments = 64
	var p_left = pond_pier_rect.position.x   # 980
	var p_right = pond_pier_rect.end.x       # 1150
	var p_top = pond_pier_rect.position.y    # 760
	var p_bottom = pond_pier_rect.end.y      # 840
	
	var bp_l = boat_shore_pier.position.x    # 1820 (先端)
	var bp_r = boat_shore_pier.end.x        # 1875 (付け根)
	var bp_t = boat_shore_pier.position.y   # 775
	var bp_b = boat_shore_pier.end.y        # 825

	# 池の西桟橋壁（先端・北・南）
	_add_wall_seg(sb, Vector2(p_left, p_top), Vector2(p_right, p_top))       # 西桟橋北壁
	_add_wall_seg(sb, Vector2(p_right, p_top), Vector2(p_right, p_bottom))   # 西桟橋先端壁
	_add_wall_seg(sb, Vector2(p_right, p_bottom), Vector2(p_left, p_bottom)) # 西桟橋南壁

	# 東岸ボート桟橋壁（先端・北・南）★先端壁で水面落下を100%遮断！
	_add_wall_seg(sb, Vector2(bp_r, bp_t), Vector2(bp_l, bp_t))       # ボート桟橋北壁
	_add_wall_seg(sb, Vector2(bp_l, bp_t), Vector2(bp_l, bp_b))       # ボート桟橋先端壁！
	_add_wall_seg(sb, Vector2(bp_l, bp_b), Vector2(bp_r, bp_b))       # ボート桟橋南壁

	for s in range(pond_segments):
		var a1 = (TAU / pond_segments) * s
		var a2 = (TAU / pond_segments) * (s + 1)
		var p1 = pond_center + Vector2(cos(a1) * (pond_rx - 6), sin(a1) * (pond_ry - 6))
		var p2 = pond_center + Vector2(cos(a2) * (pond_rx - 6), sin(a2) * (pond_ry - 6))
		
		# A. 西側池桟橋の開口部（x < 1450 かつ y in [760, 840]）
		var in_west_pier_1 = (p1.x < 1450.0 and p1.y >= p_top and p1.y <= p_bottom)
		var in_west_pier_2 = (p2.x < 1450.0 and p2.y >= p_top and p2.y <= p_bottom)
		
		# B. 東側ボート桟橋の開口部（x > 1450 かつ y in [775, 825]）
		var in_east_pier_1 = (p1.x > 1450.0 and p1.y >= bp_t and p1.y <= bp_b)
		var in_east_pier_2 = (p2.x > 1450.0 and p2.y >= bp_t and p2.y <= bp_b)
		
		if in_west_pier_1 and in_west_pier_2:
			continue # 桟橋の開口部内なのでスキップ
		elif in_west_pier_1 and not in_west_pier_2:
			# p1が開口部内、p2が開口部外 ➔ 桟橋北/南端からp2へ直結！
			var connect_pt = Vector2(p_left, p_top) if p2.y < 800.0 else Vector2(p_left, p_bottom)
			_add_wall_seg(sb, connect_pt, p2)
			continue
		elif not in_west_pier_1 and in_west_pier_2:
			# p1が開口部外、p2が開口部内 ➔ p1から桟橋北/南端へ直結！
			var connect_pt = Vector2(p_left, p_top) if p1.y < 800.0 else Vector2(p_left, p_bottom)
			_add_wall_seg(sb, p1, connect_pt)
			continue
			
		if in_east_pier_1 and in_east_pier_2:
			continue
		elif in_east_pier_1 and not in_east_pier_2:
			var connect_pt = Vector2(bp_r, bp_t) if p2.y < 800.0 else Vector2(bp_r, bp_b)
			_add_wall_seg(sb, connect_pt, p2)
			continue
		elif not in_east_pier_1 and in_east_pier_2:
			var connect_pt = Vector2(bp_r, bp_t) if p1.y < 800.0 else Vector2(bp_r, bp_b)
			_add_wall_seg(sb, p1, connect_pt)
			continue
			
		_add_wall_seg(sb, p1, p2)

	# 2. 湖の孤島の落下防止外周壁（島から水面へ落ちない）
	var island_segments = 32
	var id_l = island_dock_pier.position.x # 1500
	var id_r = island_dock_pier.end.x      # 1550
	var id_t = island_dock_pier.position.y # 780
	var id_b = island_dock_pier.end.y      # 820

	# 孤島船着き場の壁（北・東先端・南）★水面落下を100%遮断！
	_add_wall_seg(sb, Vector2(id_l, id_t), Vector2(id_r, id_t))
	_add_wall_seg(sb, Vector2(id_r, id_t), Vector2(id_r, id_b))
	_add_wall_seg(sb, Vector2(id_r, id_b), Vector2(id_l, id_b))

	for s in range(island_segments):
		var a1 = (TAU / island_segments) * s
		var a2 = (TAU / island_segments) * (s + 1)
		var ip1 = island_center + Vector2(cos(a1) * (island_rx - 4), sin(a1) * (island_ry - 4))
		var ip2 = island_center + Vector2(cos(a2) * (island_rx - 4), sin(a2) * (island_ry - 4))
		
		# 孤島船着き場付近の開口部（x >= 1450 かつ y in [780, 820]）
		var in_dock_1 = (ip1.x >= 1450.0 and ip1.y >= id_t and ip1.y <= id_b)
		var in_dock_2 = (ip2.x >= 1450.0 and ip2.y >= id_t and ip2.y <= id_b)
		
		if in_dock_1 and in_dock_2:
			continue
		elif in_dock_1 and not in_dock_2:
			var connect_pt = Vector2(id_l, id_t) if ip2.y < 800.0 else Vector2(id_l, id_b)
			_add_wall_seg(sb, connect_pt, ip2)
			continue
		elif not in_dock_1 and in_dock_2:
			var connect_pt = Vector2(id_l, id_t) if ip1.y < 800.0 else Vector2(id_l, id_b)
			_add_wall_seg(sb, ip1, connect_pt)
			continue
			
		_add_wall_seg(sb, ip1, ip2)

	# 3. 川の岸辺コリジョン（川の桟橋と隙間なく結合）
	var rp_l = river_pier_rect.position.x # 440 (先端)
	var rp_r = river_pier_rect.end.x      # 580 (付け根)
	var rp_t = river_pier_rect.position.y # 560
	var rp_b = river_pier_rect.end.y      # 630

	_add_wall_seg(sb, Vector2(rp_r, rp_t), Vector2(rp_l, rp_t))       # 川桟橋北壁
	_add_wall_seg(sb, Vector2(rp_l, rp_t), Vector2(rp_l, rp_b))       # 川桟橋先端壁
	_add_wall_seg(sb, Vector2(rp_l, rp_b), Vector2(rp_r, rp_b))       # 川桟橋南壁

	var river_steps = 60
	for step in range(river_steps):
		var y1 = (map_size.y / river_steps) * step
		var y2 = (map_size.y / river_steps) * (step + 1)
		var cx1 = river_x + sin(y1 * 0.005) * 60.0
		var cx2 = river_x + sin(y2 * 0.005) * 60.0
		
		# 西岸
		var w_p1 = Vector2(cx1 - river_width * 0.5 + 4, y1)
		var w_p2 = Vector2(cx2 - river_width * 0.5 + 4, y2)
		var in_shallow_w = (y1 >= shallow_y_min and y1 <= shallow_y_max) or (y2 >= shallow_y_min and y2 <= shallow_y_max)
		if not in_shallow_w:
			_add_wall_seg(sb, w_p1, w_p2)
		
		# 東岸（川の桟橋と隙間なく結合）
		var e_p1 = Vector2(cx1 + river_width * 0.5 - 4, y1)
		var e_p2 = Vector2(cx2 + river_width * 0.5 - 4, y2)
		var in_shallow_e = (y1 >= shallow_y_min and y1 <= shallow_y_max) or (y2 >= shallow_y_min and y2 <= shallow_y_max)
		if in_shallow_e:
			continue
			
		var in_pier_1 = (y1 >= rp_t and y1 <= rp_b)
		var in_pier_2 = (y2 >= rp_t and y2 <= rp_b)
		
		if in_pier_1 and in_pier_2:
			continue
		elif in_pier_1 and not in_pier_2:
			var connect_pt = Vector2(rp_r, rp_t) if y2 < (rp_t + rp_b) * 0.5 else Vector2(rp_r, rp_b)
			_add_wall_seg(sb, connect_pt, e_p2)
			continue
		elif not in_pier_1 and in_pier_2:
			var connect_pt = Vector2(rp_r, rp_t) if y1 < (rp_t + rp_b) * 0.5 else Vector2(rp_r, rp_b)
			_add_wall_seg(sb, e_p1, connect_pt)
			continue
			
		_add_wall_seg(sb, e_p1, e_p2)

	# 4. 秘密の滝壺コリジョン（北、西、東の外周壁。南の岸辺は釣りデッキとして開放）
	var basin_segments = 24
	for s in range(basin_segments):
		var a1 = (TAU / basin_segments) * s
		var a2 = (TAU / basin_segments) * (s + 1)
		# 南側（angle 約 0.25 TAU 〜 0.75 TAU の一部）は岸辺
		var ang_mid = (a1 + a2) * 0.5
		if ang_mid > PI * 0.25 and ang_mid < PI * 0.75:
			continue # 南の岸辺は開けておく
		var bp1 = basin_center + Vector2(cos(a1) * (basin_rx - 4), sin(a1) * (basin_ry - 4))
		var bp2 = basin_center + Vector2(cos(a2) * (basin_rx - 4), sin(a2) * (basin_ry - 4))
		_add_wall_seg(sb, bp1, bp2)

	# 5. 滝壺峡谷・倒木バリケード壁（倒木を迂回する侵入を100%遮断！）
	# 倒木の位置: (1100, 340), コリジョン幅: 110px (x: 1045〜1155)
	
	# A. 西側封鎖壁（滝壺西側の断崖壁を北外周(y=0)から倒木ライン(y=340)まで隙間なく縦断完全密閉！）
	_add_wall_seg(sb, Vector2(920, 0), Vector2(920, 340))      # 西側の断崖壁（北外周壁から倒木ラインまで貫通）
	_add_wall_seg(sb, Vector2(920, 340), Vector2(1048, 340))   # 西断崖壁から倒木左端への直結壁
	_add_wall_seg(sb, Vector2(1048, 340), Vector2(1048, 250)) # 谷間小道西ガイド壁
	_add_wall_seg(sb, Vector2(1048, 250), Vector2(920, 250))   # 釣りデッキ西側の岩壁
	_add_wall_seg(sb, Vector2(500, 340), Vector2(920, 340))    # 川から西断崖壁への封鎖横壁

	# B. 東側封鎖壁（滝壺東側の断崖壁を北外周(y=0)から倒木ライン(y=340)まで隙間なく縦断完全密閉！）
	# ★重要: x=1260の縦壁が y=0 から y=340 まで完全に直結！右側の森からのすり抜けを100%封鎖！
	_add_wall_seg(sb, Vector2(1260, 0), Vector2(1260, 340))    # 東側の断崖壁（北外周壁から倒木ラインまで完全貫通！）
	_add_wall_seg(sb, Vector2(1152, 340), Vector2(1260, 340))  # 倒木右端から東断崖壁への直結壁
	_add_wall_seg(sb, Vector2(1152, 340), Vector2(1152, 250)) # 谷間小道東ガイド壁
	_add_wall_seg(sb, Vector2(1152, 250), Vector2(1260, 250))  # 釣りデッキ東側の岩壁
	
	# C. 池北側・北東連峰の遮断壁（池の右側の森の上部への侵入も完全遮断！）
	_add_wall_seg(sb, Vector2(1260, 340), Vector2(1450, 340))  # 東側平原への遮断横壁
	_add_wall_seg(sb, Vector2(1450, 340), Vector2(1450, 430))  # 縦壁
	_add_wall_seg(sb, Vector2(1450, 430), Vector2(2400, 430))  # 北東の深林・山岳連峰への完全遮断横壁（東端まで！）

func _add_wall_seg(sb: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var col = CollisionShape2D.new()
	var seg = SegmentShape2D.new()
	seg.a = a
	seg.b = b
	col.shape = seg
	sb.add_child(col)

func _process(delta: float) -> void:
	time_counter += delta
	for i in range(tree_sprites.size()):
		var spr = tree_sprites[i]
		spr.rotation = sin(time_counter * 1.2 + i * 0.5) * 0.02
	queue_redraw()

func _draw() -> void:
	# 1. 草地背景
	if tex_grass:
		var tile_size = 1024.0
		for ty in range(0, int(map_size.y), int(tile_size)):
			for tx in range(0, int(map_size.x), int(tile_size)):
				draw_texture(tex_grass, Vector2(tx, ty), Color(0.98, 0.98, 0.96, 1.0))
	else:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color("#d8f3dc"))

	# 2. 小道
	# 広場から池桟橋、川桟橋へ
	draw_line(Vector2(950, 800), Vector2(pond_pier_rect.position.x + 20, pond_pier_rect.position.y + 40), Color(0.95, 0.91, 0.82, 0.8), 56.0)
	draw_line(Vector2(950, 800), Vector2(river_pier_rect.end.x - 20, river_pier_rect.position.y + 35), Color(0.95, 0.91, 0.82, 0.8), 48.0)
	draw_circle(Vector2(950, 800), 72.0, Color(0.95, 0.91, 0.82, 0.85))
	
	# 広場から浅瀬（y=1200）への南の小道
	draw_line(Vector2(950, 800), Vector2(650, 1050), Color(0.95, 0.91, 0.82, 0.65), 36.0)
	draw_line(Vector2(650, 1050), Vector2(510, 1200), Color(0.95, 0.91, 0.82, 0.65), 36.0)
	
	# 広場から北の倒木・滝壺（y=340〜180）への北の小道
	draw_line(Vector2(950, 800), Vector2(1050, 500), Color(0.95, 0.91, 0.82, 0.65), 36.0)
	draw_line(Vector2(1050, 500), Vector2(1100, 340), Color(0.95, 0.91, 0.82, 0.65), 36.0)
	if GameData.is_log_cleared:
		# 倒木破壊後は滝壺の畔まで開通した道
		draw_line(Vector2(1100, 340), Vector2(1100, 260), Color(0.95, 0.91, 0.82, 0.75), 32.0)

	# 池の北側から東岸ボート桟橋への小道
	draw_line(Vector2(1450, 480), Vector2(1820, 785), Color(0.95, 0.91, 0.82, 0.6), 32.0)

	# 3. 川の水面
	var river_steps = 70
	var left_shore: PackedVector2Array = []
	var right_shore: PackedVector2Array = []
	var left_water: PackedVector2Array = []
	var right_water: PackedVector2Array = []
	var uvs_water: PackedVector2Array = []
	
	for s in range(river_steps + 1):
		var y = (map_size.y / river_steps) * s
		var cx = river_x + sin(y * 0.005) * 60.0
		left_shore.append(Vector2(cx - river_width * 0.5 - 22.0, y))
		right_shore.append(Vector2(cx + river_width * 0.5 + 22.0, y))
		left_water.append(Vector2(cx - river_width * 0.5, y))
		right_water.append(Vector2(cx + river_width * 0.5, y))

	var poly_shore: PackedVector2Array = []
	for p in left_shore: poly_shore.append(p)
	for idx in range(right_shore.size() - 1, -1, -1): poly_shore.append(right_shore[idx])
	draw_colored_polygon(poly_shore, Color(0.92, 0.86, 0.78, 0.75))

	var poly_water: PackedVector2Array = []
	for p in left_water: poly_water.append(p)
	for idx in range(right_water.size() - 1, -1, -1): poly_water.append(right_water[idx])
	for p in poly_water: uvs_water.append(p / 1024.0)
	
	if tex_water:
		draw_polygon(poly_water, [Color(0.9, 0.95, 1.0, 0.9)], uvs_water, tex_water)
	else:
		draw_colored_polygon(poly_water, Color(0.65, 0.82, 0.95, 0.85))

	for idx in range(left_water.size() - 1):
		draw_line(left_water[idx], left_water[idx + 1], Color(0.35, 0.55, 0.75, 0.7), 2.5)
		draw_line(right_water[idx], right_water[idx + 1], Color(0.35, 0.55, 0.75, 0.7), 2.5)

	# 4. 池の水面
	draw_ellipse(pond_center, pond_rx + 30.0, pond_ry + 26.0, Color(0.92, 0.86, 0.78, 0.75))
	var pond_pts: PackedVector2Array = []
	var pond_uvs: PackedVector2Array = []
	var pond_segments = 64
	for i in range(pond_segments):
		var ang = (TAU / pond_segments) * i
		var pt = pond_center + Vector2(cos(ang) * pond_rx, sin(ang) * pond_ry)
		pond_pts.append(pt)
		pond_uvs.append(pt / 1024.0)
		
	if tex_water:
		draw_polygon(pond_pts, [Color(0.92, 0.96, 1.0, 0.92)], pond_uvs, tex_water)
	else:
		draw_colored_polygon(pond_pts, Color(0.65, 0.82, 0.95, 0.85))
		
	draw_ellipse(pond_center + Vector2(20, 10), pond_rx * 0.65, pond_ry * 0.65, Color(0.35, 0.60, 0.85, 0.45))
	draw_ellipse(pond_center, pond_rx, pond_ry, Color(0.32, 0.52, 0.72, 0.75), false, 3.0)

	# 5. 秘密のエメラルド滝壺（滝とエメラルドグリーン水面）
	_draw_emerald_basin()

	# 6. 湖の孤島（Mysterious Isle）
	_draw_mysterious_island()

	# 7. 水彩の睡蓮
	for lily in water_lilies:
		var lp = lily["pos"]
		var lr = lily["radius"]
		draw_arc(lp, lr, 0.35, PI * 1.95, 24, Color(0.40, 0.68, 0.48, 0.85), lr, false)
		draw_line(lp, lp + Vector2(cos(PI * 0.5), sin(PI * 0.5)) * (lr * 0.8), Color(0.32, 0.55, 0.38, 0.65), 1.2)
		if lily["has_flower"]:
			draw_circle(lp + Vector2(4, -3), 7.0, lily["flower_color"])
			draw_circle(lp + Vector2(4, -3), 3.0, Color(1.0, 0.82, 0.35, 0.9))

	# 8. 水面の波線
	var wave_col = Color(1, 1, 1, 0.5)
	for w in range(6):
		var wy = pond_center.y - 110 + w * 44
		var wx = pond_center.x - 170 + sin(time_counter * 1.3 + w) * 22.0
		draw_arc(Vector2(wx, wy), 24.0, PI * 0.8, PI * 0.2, 10, wave_col, 2.0)

	# 9. 木製桟橋
	_draw_watercolor_pier(pond_pier_rect, "east")
	_draw_watercolor_pier(river_pier_rect, "west")
	_draw_watercolor_pier(boat_shore_pier, "west")
	_draw_watercolor_pier(island_dock_pier, "east")

func _draw_emerald_basin() -> void:
	# 1. 滝壺内部の砂浜・岸辺（水彩の柔らかな砂浜）
	draw_ellipse(basin_center, basin_rx + 22.0, basin_ry + 18.0, Color(0.92, 0.88, 0.80, 0.85))
	
	# エメラルド水面
	var b_pts: PackedVector2Array = []
	var b_uvs: PackedVector2Array = []
	for i in range(32):
		var a = (TAU / 32) * i
		var pt = basin_center + Vector2(cos(a) * basin_rx, sin(a) * basin_ry)
		b_pts.append(pt)
		b_uvs.append(pt / 1024.0)
	if tex_water:
		draw_polygon(b_pts, [Color(0.35, 0.92, 0.80, 0.92)], b_uvs, tex_water)
	else:
		draw_colored_polygon(b_pts, Color(0.25, 0.75, 0.65, 0.88)) # エメラルドグリーン
	draw_ellipse(basin_center, basin_rx * 0.65, basin_ry * 0.65, Color(0.15, 0.60, 0.55, 0.5))
	draw_polyline(b_pts, Color(0.18, 0.55, 0.48, 0.8), 2.5)

	# 北の岩壁と清流の滝（アニメーション）
	var cliff_rect = Rect2(basin_center.x - 60, basin_center.y - basin_ry - 25, 120, 35)
	draw_rect(cliff_rect, Color(0.45, 0.48, 0.46), true) # 崖の岩
	draw_rect(cliff_rect, Color(0.3, 0.32, 0.3), false, 2.0)
	
	# 滝の流れ
	var fall_width = 36.0
	var fall_top = basin_center.y - basin_ry - 25
	var fall_bottom = basin_center.y - basin_ry + 15
	var flow_phase = sin(time_counter * 8.0) * 2.0
	draw_rect(Rect2(basin_center.x - fall_width * 0.5 + flow_phase, fall_top, fall_width, fall_bottom - fall_top), Color(0.85, 0.98, 1.0, 0.85), true)
	
	# 滝壺の白い水しぶき
	for sp in range(5):
		var sx = basin_center.x - 20 + sp * 10 + sin(time_counter * 10.0 + sp) * 4.0
		var sy = fall_bottom + sin(time_counter * 12.0 + sp * 2.0) * 3.0
		draw_circle(Vector2(sx, sy), 4.5, Color(1, 1, 1, 0.75))

func _draw_mysterious_island() -> void:
	# 孤島の砂浜・岸辺
	draw_ellipse(island_center, island_rx + 14.0, island_ry + 10.0, Color(0.92, 0.86, 0.78, 0.9))
	
	# 孤島の緑豊かな芝生
	draw_ellipse(island_center, island_rx, island_ry, Color(0.48, 0.78, 0.42, 0.95))
	draw_ellipse(island_center, island_rx, island_ry, Color(0.32, 0.58, 0.28), false, 2.5)
	
	# 石畳
	draw_circle(island_center + Vector2(10, 0), 12.0, Color(0.82, 0.8, 0.75, 0.8))
	draw_circle(island_center + Vector2(-15, 8), 10.0, Color(0.82, 0.8, 0.75, 0.8))
	
	# 神木（桜色・大樹）の幹と枝葉
	var tree_base = island_center + Vector2(-18, -12)
	# 幹
	draw_rect(Rect2(tree_base.x - 6, tree_base.y - 10, 12, 22), Color("#6b4226"), true)
	# 桜の満開の葉（水彩ピンクの雲）
	var leaf_col = Color(1.0, 0.78, 0.86, 0.92)
	var leaf_col2 = Color(0.98, 0.65, 0.76, 0.85)
	draw_circle(tree_base + Vector2(0, -22), 22.0, leaf_col)
	draw_circle(tree_base + Vector2(-12, -18), 17.0, leaf_col2)
	draw_circle(tree_base + Vector2(14, -18), 18.0, leaf_col2)
	draw_circle(tree_base + Vector2(0, -30), 16.0, Color(1.0, 0.85, 0.92, 0.95))
	# 花びらの舞
	for p in range(4):
		var px = tree_base.x + 10 + sin(time_counter * 2.0 + p) * 20.0
		var py = tree_base.y - 10 + p * 8.0 + cos(time_counter * 2.5 + p) * 6.0
		draw_circle(Vector2(px, py), 2.2, Color(1.0, 0.72, 0.82, 0.8))

func _draw_watercolor_pier(rect: Rect2, tip_dir: String) -> void:
	# 桟橋の水中杭
	draw_rect(Rect2(rect.end.x - 14, rect.position.y - 4, 12, 14), Color(0.3, 0.38, 0.45, 0.55), true)
	draw_rect(Rect2(rect.end.x - 14, rect.end.y - 10, 12, 14), Color(0.3, 0.38, 0.45, 0.55), true)
	
	# 木の天板
	draw_rect(rect, Color(0.82, 0.68, 0.52, 0.95), true)
	draw_rect(rect, Color(0.55, 0.42, 0.32, 0.85), false, 2.0)
	
	# 板のすじ
	var step = 16.0
	var cur_x = rect.position.x + step
	while cur_x < rect.end.x:
		draw_line(Vector2(cur_x, rect.position.y), Vector2(cur_x, rect.end.y), Color(0.55, 0.42, 0.32, 0.65), 1.5)
		cur_x += step

	# 桟橋の手すり杭・ロープ柵
	var post_col = Color(0.48, 0.35, 0.25, 0.95)
	var rope_col = Color(0.88, 0.82, 0.68, 0.85)
	
	if tip_dir == "east":
		var p_top_l = Vector2(rect.position.x + 6, rect.position.y + 2)
		var p_top_r = Vector2(rect.end.x - 6, rect.position.y + 2)
		var p_bot_l = Vector2(rect.position.x + 6, rect.end.y - 2)
		var p_bot_r = Vector2(rect.end.x - 6, rect.end.y - 2)
		draw_line(p_top_l, p_top_r, rope_col, 2.0)
		draw_line(p_bot_l, p_bot_r, rope_col, 2.0)
		draw_circle(p_top_l, 3.8, post_col)
		draw_circle(p_top_r, 3.8, post_col)
		draw_circle(p_bot_l, 3.8, post_col)
		draw_circle(p_bot_r, 3.8, post_col)
	else:
		var p_top_r = Vector2(rect.end.x - 6, rect.position.y + 2)
		var p_top_l = Vector2(rect.position.x + 6, rect.position.y + 2)
		var p_bot_r = Vector2(rect.end.x - 6, rect.end.y - 2)
		var p_bot_l = Vector2(rect.position.x + 6, rect.end.y - 2)
		draw_line(p_top_r, p_top_l, rope_col, 2.0)
		draw_line(p_bot_r, p_bot_l, rope_col, 2.0)
		draw_circle(p_top_l, 3.8, post_col)
		draw_circle(p_top_r, 3.8, post_col)
		draw_circle(p_bot_l, 3.8, post_col)
		draw_circle(p_bot_r, 3.8, post_col)
