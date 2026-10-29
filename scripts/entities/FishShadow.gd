extends Node2D

# 福岡・玄界灘 実在海洋生物（魚影・生態遊泳システム）

signal fish_reached_bobber()
signal fish_bit()

enum State {
	WANDER,
	NOTICE,
	APPROACH,
	NIBBLE,
	BITE
}

var current_state: State = State.WANDER

# 魚種: "aji", "kisu", "arakabu", "chinu", "magochi", "suzuki", "kijihata", "hirame", "madai", "aoriika"
@export var fish_species: String = "aji"

var fish_name: String = "マアジ"
var swim_speed: float = 30.0

# 遊泳
var swim_direction: Vector2 = Vector2.RIGHT
var target_swim_dir: Vector2 = Vector2.RIGHT
var wander_timer: float = 0.0
var tail_cycle: float = 0.0
var is_resting: bool = false
var rest_timer: float = 0.0

# ターゲット（ウキ）
var target_bobber: Node2D = null
var notice_timer: float = 0.0
var nibble_timer: float = 0.0
var nibble_count: int = 0
var max_nibbles: int = 2

var map_field: Node2D = null
var sprite: Sprite2D = null
var shadow_sprite: Sprite2D = null

func _ready() -> void:
	_init_species_profile()
	swim_direction = Vector2.RIGHT.rotated(randf() * TAU)
	target_swim_dir = swim_direction
	rotation = swim_direction.angle()
	wander_timer = randf_range(2.0, 5.0)
	_setup_sprite()

func setup(map: Node2D) -> void:
	map_field = map

func _init_species_profile() -> void:
	match fish_species:
		"aji":
			fish_name = "マアジ"
			swim_speed = 36.0 # 俊敏な回遊魚
		"kisu":
			fish_name = "シロギス"
			swim_speed = 28.0 # 砂底を小刻みに探る
		"arakabu":
			fish_name = "アラカブ"
			swim_speed = 22.0 # 根（敷石・テトラ）周りをじっと潜む
		"chinu":
			fish_name = "チヌ"
			swim_speed = 24.0 # 警戒深くゆっくりケーソン沿いを泳ぐ
		"magochi":
			fish_name = "マゴチ"
			swim_speed = 20.0 # 砂底を這うようなフラットフィッシュ
		"suzuki":
			fish_name = "スズキ"
			swim_speed = 42.0 # 豪快で速い遊泳
		"kijihata":
			fish_name = "キジハタ"
			swim_speed = 24.0 # 沈み瀬の隙間を巡回
		"hirame":
			fish_name = "ヒラメ"
			swim_speed = 22.0 # 砂底でじっと待ち伏せ
		"madai":
			fish_name = "マダイ"
			swim_speed = 32.0 # 潮通しの良い沖合を悠然と回遊
		"aoriika":
			fish_name = "アオリイカ"
			swim_speed = 26.0 # 藻場をふわふわ、時にスッと移動
		_:
			fish_name = "玄界灘の魚"
			swim_speed = 28.0

func get_shadow_size_desc() -> String:
	match fish_species:
		"aji":
			return "すばやい銀色の魚影"
		"kisu":
			return "ほっそりした透き通る魚影"
		"arakabu":
			return "岩陰に潜むゴツゴツした魚影"
		"chinu":
			return "銀黒の引き締まった良型の魚影"
		"magochi":
			return "平たい砂底の魚影"
		"suzuki":
			return "大型で細長いスズキの魚影"
		"kijihata":
			return "重量感のある高級魚の魚影"
		"hirame":
			return "砂底に同化した大きな平らな魚影"
		"madai":
			return "美しい桜色の堂々たる魚影"
		"aoriika":
			return "ゆらめくエンペラを持つイカの影"
		_:
			return "水中の魚影"

func _setup_sprite() -> void:
	var tex = GameData.load_texture("res://assets/fish_" + fish_species + ".png")
	if not tex:
		tex = GameData.load_texture("res://assets/hd2d_fish_" + fish_species + ".png")
		
	if tex:
		var scale_val = Vector2(0.035, 0.035)
		match fish_species:
			"kisu":     scale_val = Vector2(0.028, 0.026)
			"aji":      scale_val = Vector2(0.032, 0.030)
			"arakabu":  scale_val = Vector2(0.034, 0.032)
			"chinu":    scale_val = Vector2(0.038, 0.036)
			"magochi":  scale_val = Vector2(0.040, 0.034)
			"hirame":   scale_val = Vector2(0.042, 0.040)
			"kijihata": scale_val = Vector2(0.038, 0.036)
			"madai":    scale_val = Vector2(0.030, 0.030)
			"suzuki":   scale_val = Vector2(0.048, 0.044)
			"aoriika":  scale_val = Vector2(0.036, 0.034)

		# 水底に落ちる魚の影（Drop Shadow）
		shadow_sprite = Sprite2D.new()
		shadow_sprite.texture = tex
		shadow_sprite.scale = scale_val
		shadow_sprite.position = Vector2(8, 12) # 水深分だけ右下に落ちる影
		shadow_sprite.modulate = Color(0.06, 0.16, 0.20, 0.28)
		add_child(shadow_sprite)

		sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.scale = scale_val
		
		var shadow_shader = load("res://assets/shaders/fish_shadow.gdshader")
		if shadow_shader:
			var mat = ShaderMaterial.new()
			mat.shader = shadow_shader
			
			var shadow_col = Color(0.12, 0.26, 0.36, 0.75)
			var glow_col = Color(0.0, 0.0, 0.0, 0.0)
			
			if fish_species == "aoriika":
				shadow_col = Color(0.15, 0.35, 0.40, 0.70)
				glow_col = Color(0.2, 0.8, 0.7, 0.25)
			elif fish_species == "madai":
				glow_col = Color(0.9, 0.4, 0.5, 0.20)
				
			mat.set_shader_parameter("shadow_color", shadow_col)
			mat.set_shader_parameter("glow_color", glow_col)
			mat.set_shader_parameter("depth_fade", 0.25)
			sprite.material = mat
		else:
			sprite.modulate = Color(0.12, 0.26, 0.36, 0.75)
			
		add_child(sprite)

func _process(delta: float) -> void:
	tail_cycle += delta * (swim_speed * 0.16)
	
	match current_state:
		State.WANDER:
			_process_wander(delta)
		State.NOTICE:
			_process_notice(delta)
		State.APPROACH:
			_process_approach(delta)
		State.NIBBLE:
			_process_nibble(delta)
		State.BITE:
			pass
			
	if map_field and map_field.has_method("get_clamped_safe_water_pos"):
		global_position = map_field.get_clamped_safe_water_pos(global_position)
		
	var wiggle = sin(tail_cycle) * 0.08
	var angle = swim_direction.angle()
	
	# 素材（fish_*.png）は「頭が右向き（+X方向）」
	# 常に頭を進行方向（swim_direction）に向け、背中が上を維持する自然な遊泳制御
	if abs(angle) > PI * 0.5:
		# 左半球方向への遊泳: 水平反転（flip_h = true）して頭を左に向け、左基準の角度へ回転
		# angle が PI（真左）のとき、rotation は 0（水平）
		var left_angle = angle - PI if angle > 0.0 else angle + PI
		rotation = left_angle + wiggle
		if sprite: sprite.flip_h = true
		if shadow_sprite: shadow_sprite.flip_h = true
	else:
		# 右半球方向への遊泳: 元の右向きスプライト（flip_h = false）で頭を右に向け、右基準の角度へ回転
		# angle が 0（真右）のとき、rotation は 0（水平）
		rotation = angle + wiggle
		if sprite: sprite.flip_h = false
		if shadow_sprite: shadow_sprite.flip_h = false
		
	queue_redraw()

func _process_wander(delta: float) -> void:
	if is_resting:
		rest_timer -= delta
		if rest_timer <= 0.0:
			is_resting = false
		return

	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.5, 6.0)
		target_swim_dir = Vector2.RIGHT.rotated(randf() * TAU)
		if randf() < 0.25:
			is_resting = true
			rest_timer = randf_range(1.0, 2.5)

	# 桟橋・陸地・浅瀬への接近を事前に検知して回避
	var next_pos = global_position + swim_direction * (swim_speed * delta * 3.5)
	if map_field and not map_field.is_in_safe_water(next_pos):
		# 開けた外海側（画面中央〜南側の安全な水域）へ滑らかに旋回
		var safe_center = Vector2(380, 480)
		var to_safe = (safe_center - global_position).normalized()
		target_swim_dir = to_safe.rotated(randf_range(-0.4, 0.4))
		wander_timer = randf_range(2.0, 4.0)
		
	swim_direction = swim_direction.slerp(target_swim_dir, delta * 3.5).normalized()
	global_position += swim_direction * (swim_speed * delta)

func on_bobber_cast(bobber_node: Node2D) -> void:
	if current_state != State.WANDER and current_state != State.NOTICE:
		return
	var dist = global_position.distance_to(bobber_node.global_position)
	var detect_range = 160.0
	if fish_species in ["madai", "suzuki", "chinu"]:
		detect_range = 220.0
		
	if dist < detect_range:
		target_bobber = bobber_node
		current_state = State.NOTICE
		notice_timer = randf_range(0.4, 1.2)
		target_swim_dir = (bobber_node.global_position - global_position).normalized()

func on_bobber_retrieved() -> void:
	if current_state != State.WANDER:
		current_state = State.WANDER
		target_bobber = null
		target_swim_dir = -swim_direction.rotated(randf_range(-0.4, 0.4))
		wander_timer = randf_range(3.0, 6.0)

func _process_notice(delta: float) -> void:
	if not is_instance_valid(target_bobber) or not target_bobber.is_active:
		current_state = State.WANDER
		return
		
	notice_timer -= delta
	swim_direction = swim_direction.slerp(target_swim_dir, delta * 5.0).normalized()
	if notice_timer <= 0.0:
		current_state = State.APPROACH

func _process_approach(delta: float) -> void:
	if not is_instance_valid(target_bobber) or not target_bobber.is_active:
		current_state = State.WANDER
		return
		
	var to_bobber = target_bobber.global_position - global_position
	var dist = to_bobber.length()
	
	if dist < 14.0:
		current_state = State.NIBBLE
		_start_nibbling()
		fish_reached_bobber.emit()
		return
		
	target_swim_dir = to_bobber.normalized()
	swim_direction = swim_direction.slerp(target_swim_dir, delta * 4.0).normalized()
	global_position += swim_direction * (swim_speed * 1.3) * delta

func _start_nibbling() -> void:
	nibble_count = 0
	var r = randf()
	
	match fish_species:
		"arakabu":
			# 一撃吸い込み
			if r < 0.35:
				max_nibbles = 0
				nibble_timer = randf_range(0.2, 0.4)
			else:
				max_nibbles = 1
				nibble_timer = randf_range(0.3, 0.6)
		"kisu", "aji":
			# 小刻みなつつき（2〜3回）
			max_nibbles = randi_range(2, 4)
			nibble_timer = randf_range(0.3, 0.6)
		"chinu":
			# じっくり前アタリから本アタリ
			max_nibbles = randi_range(3, 5)
			nibble_timer = randf_range(0.7, 1.4)
		"aoriika":
			# 抱きつき（重みじわ〜）
			max_nibbles = randi_range(1, 2)
			nibble_timer = randf_range(0.8, 1.6)
		_:
			if r < 0.2:
				max_nibbles = 0
				nibble_timer = randf_range(0.3, 0.5)
			else:
				max_nibbles = randi_range(1, 3)
				nibble_timer = randf_range(0.5, 1.0)
				
	if max_nibbles > 0 and target_bobber.has_method("trigger_nibble"):
		target_bobber.trigger_nibble(randf_range(2.5, 4.5))

func _process_nibble(delta: float) -> void:
	if not is_instance_valid(target_bobber) or not target_bobber.is_active:
		current_state = State.WANDER
		return
		
	nibble_timer -= delta
	if nibble_timer <= 0.0:
		nibble_count += 1
		if nibble_count > max_nibbles:
			current_state = State.BITE
			target_bobber.trigger_bite()
			fish_bit.emit()
		else:
			nibble_timer = randf_range(0.4, 1.2)
			if target_bobber.has_method("trigger_nibble"):
				target_bobber.trigger_nibble(randf_range(2.0, 5.0))
			swim_direction = swim_direction.rotated(randf_range(-0.4, 0.4))

func _draw() -> void:
	# スプライトがない場合のプロシージャル魚影描画
	if not sprite:
		_draw_procedural_fish_shadow()

	# 注意アイコン
	if current_state == State.NOTICE:
		var q_pos = Vector2(0, -22)
		draw_circle(q_pos, 6.5, Color(0.98, 0.78, 0.25, 0.95))
		draw_circle(q_pos, 4.5, Color(0.95, 0.55, 0.15, 0.95))
		draw_circle(q_pos, 2.0, Color.WHITE)

func _draw_procedural_fish_shadow() -> void:
	var drop_shadow_col = Color(0.06, 0.16, 0.20, 0.28)
	var shadow_col = Color(0.12, 0.26, 0.36, 0.75)
	var body_len = 24.0
	var body_w = 8.0
	var shadow_off = Vector2(8, 12)
	
	match fish_species:
		"kisu":
			body_len = 20.0
			body_w = 4.5
		"aji":
			body_len = 22.0
			body_w = 6.5
		"arakabu":
			body_len = 22.0
			body_w = 9.0
		"chinu":
			body_len = 32.0
			body_w = 14.0
		"magochi":
			body_len = 34.0
			body_w = 9.0
		"hirame":
			body_len = 36.0
			body_w = 20.0
		"suzuki":
			body_len = 44.0
			body_w = 11.0
		"madai":
			body_len = 38.0
			body_w = 16.0
		"aoriika":
			# 水底の影
			draw_ellipse(shadow_off + Vector2(-2, 0), 16.0, 9.0, drop_shadow_col)
			# 本体
			draw_ellipse(Vector2(-2, 0), 16.0, 9.0, shadow_col)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-12, 0), Vector2(-22, -10), Vector2(-22, 10)
			]), shadow_col)
			draw_line(Vector2(12, -2), Vector2(24, -4), shadow_col, 2.0)
			draw_line(Vector2(12, 2), Vector2(24, 4), shadow_col, 2.0)
			return

	# 水底の影（Drop Shadow）
	draw_ellipse(shadow_off, body_len * 0.5, body_w * 0.5, drop_shadow_col)
	var tail_x_s = -body_len * 0.5 + shadow_off.x
	draw_colored_polygon(PackedVector2Array([
		Vector2(tail_x_s, shadow_off.y),
		Vector2(tail_x_s - 8, shadow_off.y - body_w * 0.6),
		Vector2(tail_x_s - 8, shadow_off.y + body_w * 0.6)
	]), drop_shadow_col)

	# 魚体本体（楕円）
	draw_ellipse(Vector2.ZERO, body_len * 0.5, body_w * 0.5, shadow_col)
	# 尾ビレ
	var tail_x = -body_len * 0.5
	var tail_fin = PackedVector2Array([
		Vector2(tail_x, 0),
		Vector2(tail_x - 8, -body_w * 0.6),
		Vector2(tail_x - 8, body_w * 0.6)
	])
	draw_colored_polygon(tail_fin, shadow_col)
