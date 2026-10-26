extends Node2D

# HD-2D 実在魚（全身が完全に揃った美しいドット絵魚、進行方向へのスムーズな遊泳）

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

# 魚種: "yamame", "koi", "catfish", "funa", "medaka"
@export var fish_species: String = "funa"

var fish_name: String = "フナ"
var swim_speed: float = 28.0

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
		"yamame":
			fish_name = "ヤマメ"
			swim_speed = 36.0
		"funa":
			fish_name = "ギンブナ"
			swim_speed = 26.0
		"koi":
			fish_name = "ニシキゴイ"
			swim_speed = 20.0
		"catfish":
			fish_name = "ナマズ"
			swim_speed = 22.0
		"medaka":
			fish_name = "メダカ"
			swim_speed = 42.0
		"iwana":
			fish_name = "イワナ"
			swim_speed = 34.0
		"rainbow_trout":
			fish_name = "ニジマス"
			swim_speed = 38.0
		"golden_koi":
			fish_name = "黄金の主"
			swim_speed = 18.0

func get_shadow_size_desc() -> String:
	match fish_species:
		"medaka":
			return "ちいさな魚影"
		"funa":
			return "中くらいの魚影"
		"yamame":
			return "素早い魚影"
		"iwana":
			return "渓流の魚影"
		"rainbow_trout":
			return "大きな素早い魚影"
		"koi":
			return "大きな魚影"
		"catfish":
			return "底に潜む大きな魚影"
		"golden_koi":
			return "金色にきらめく巨大な魚影"
		_:
			return "水中の魚影"

func _setup_sprite() -> void:
	var tex_name = fish_species
	if tex_name == "medaka" or tex_name == "iwana" or tex_name == "rainbow_trout":
		tex_name = "yamame"
	elif tex_name == "golden_koi":
		tex_name = "koi"
		
	var tex = GameData.load_texture("res://assets/hd2d_fish_" + tex_name + ".png")
	if not tex:
		tex = GameData.load_texture("res://assets/fish_" + tex_name + ".png")
		
	if tex:
		# 自然で適切な魚影サイズにスケーリング
		var scale_val = Vector2(0.07, 0.07)
		match fish_species:
			"medaka":        scale_val = Vector2(0.038, 0.038)
			"yamame":        scale_val = Vector2(0.065, 0.065)
			"funa":          scale_val = Vector2(0.070, 0.070)
			"koi":           scale_val = Vector2(0.092, 0.092)
			"catfish":       scale_val = Vector2(0.096, 0.096)
			"iwana":         scale_val = Vector2(0.075, 0.075)
			"rainbow_trout": scale_val = Vector2(0.082, 0.082)
			"golden_koi":    scale_val = Vector2(0.138, 0.138) # 圧倒的巨大魚影！

		sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.scale = scale_val
		
		# ★水中の魚影（シルエット）シェーダーを適用
		var shadow_shader = load("res://assets/shaders/fish_shadow.gdshader")
		if shadow_shader:
			var mat = ShaderMaterial.new()
			mat.shader = shadow_shader
			
			var shadow_col = Color(0.12, 0.22, 0.35, 0.70)
			var glow_col = Color(0.0, 0.0, 0.0, 0.0)
			
			match fish_species:
				"medaka":
					shadow_col = Color(0.18, 0.28, 0.40, 0.60) # 浅瀬の小さな淡い影
				"catfish":
					shadow_col = Color(0.08, 0.15, 0.25, 0.80) # 底に潜む濃い影
				"golden_koi":
					shadow_col = Color(0.16, 0.22, 0.28, 0.82)
					glow_col = Color(1.15, 0.95, 0.45, 0.35)   # 神秘的な淡い金色の微光
				_:
					shadow_col = Color(0.12, 0.22, 0.36, 0.72)
					
			mat.set_shader_parameter("shadow_color", shadow_col)
			mat.set_shader_parameter("glow_color", glow_col)
			mat.set_shader_parameter("depth_fade", 0.30)
			sprite.material = mat
		else:
			# フォールバック
			sprite.modulate = Color(0.12, 0.22, 0.35, 0.70)
			
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
			
	# 陸地への侵入防止：安全水深エリア内にハードクランプ
	if map_field and map_field.has_method("get_clamped_safe_water_pos"):
		global_position = map_field.get_clamped_safe_water_pos(global_position)
		
	# 頭を進行方向に向けて、尾ヒレのゆったりとしたしなりを加える
	var wiggle = sin(tail_cycle) * 0.08
	rotation = swim_direction.angle() + wiggle
		
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

	# 境界反転
	var next_pos = global_position + swim_direction * swim_speed * delta * 2.5
	if map_field and not map_field.is_in_safe_water(next_pos):
		target_swim_dir = -swim_direction.rotated(randf_range(-0.5, 0.5))
		
	swim_direction = swim_direction.slerp(target_swim_dir, delta * 2.8).normalized()
	global_position += swim_direction * swim_speed * delta
	
	# 回遊中に近くにあるウキに気づく判定
	if is_instance_valid(target_bobber) and target_bobber.is_active and target_bobber.occupied_by_fish == null:
		_check_bobber_detection(target_bobber)

func on_bobber_cast(bobber: Node2D) -> void:
	target_bobber = bobber
	if current_state != State.WANDER:
		return
	_check_bobber_detection(bobber)

func _check_bobber_detection(bobber: Node2D) -> void:
	var dist = global_position.distance_to(bobber.global_position)
	var base_range = 175.0
	if fish_species == "koi" or fish_species == "catfish" or fish_species == "golden_koi":
		base_range = 220.0
	var boost = sqrt(GameData.get_current_bait_boost()) # エサによる引き寄せ範囲拡大
	var detect_range = base_range * boost
	
	if dist <= detect_range:
		is_resting = false
		current_state = State.NOTICE
		notice_timer = randf_range(0.4, 0.8)
		target_swim_dir = (bobber.global_position - global_position).normalized()

func on_bobber_retrieved() -> void:
	target_bobber = null
	if current_state != State.WANDER:
		current_state = State.WANDER
		target_swim_dir = Vector2.RIGHT.rotated(randf() * TAU)

func _process_notice(delta: float) -> void:
	if not is_instance_valid(target_bobber) or not target_bobber.is_active or (target_bobber.occupied_by_fish != null and target_bobber.occupied_by_fish != self):
		current_state = State.WANDER
		return
		
	swim_direction = swim_direction.slerp(target_swim_dir, delta * 6.0).normalized()
	
	notice_timer -= delta
	if notice_timer <= 0.0:
		current_state = State.APPROACH

func _process_approach(delta: float) -> void:
	if not is_instance_valid(target_bobber) or not target_bobber.is_active or (target_bobber.occupied_by_fish != null and target_bobber.occupied_by_fish != self):
		current_state = State.WANDER
		return
		
	var target_pos = target_bobber.global_position
	if map_field:
		target_pos = map_field.get_clamped_safe_water_pos(target_bobber.global_position)
		
	var to_target = target_pos - global_position
	var dist = to_target.length()
	
	if dist < 20.0 or global_position.distance_to(target_bobber.global_position) < 30.0:
		target_bobber.occupied_by_fish = self
		current_state = State.NIBBLE
		nibble_count = 0
		max_nibbles = randi_range(1, 3)
		nibble_timer = 0.65
		if target_bobber.has_method("trigger_nibble"):
			target_bobber.trigger_nibble()
		fish_reached_bobber.emit()
	else:
		swim_direction = swim_direction.slerp(to_target.normalized(), delta * 4.5).normalized()
		global_position += swim_direction * (swim_speed * 1.15) * delta

func _process_nibble(delta: float) -> void:
	if not is_instance_valid(target_bobber) or not target_bobber.is_active:
		current_state = State.WANDER
		return
		
	nibble_timer -= delta
	if nibble_timer <= 0.0:
		nibble_count += 1
		if nibble_count >= max_nibbles:
			current_state = State.BITE
			target_bobber.trigger_bite()
			fish_bit.emit()
		else:
			nibble_timer = randf_range(0.6, 1.0)
			if target_bobber.has_method("trigger_nibble"):
				target_bobber.trigger_nibble()
			swim_direction = swim_direction.rotated(randf_range(-0.3, 0.3))

func _draw() -> void:
	# 黄金の主の神々しいオーラ
	if fish_species == "golden_koi":
		var pulse = (sin(tail_cycle * 2.0) + 1.0) * 0.5
		var aura_radius = 24.0 + pulse * 6.0
		draw_circle(Vector2.ZERO, aura_radius, Color(1.0, 0.85, 0.2, 0.18 + pulse * 0.12))
		draw_arc(Vector2.ZERO, aura_radius + 4.0, 0, TAU, 24, Color(1.0, 0.9, 0.4, 0.35 + pulse * 0.2), 1.5)

	# HD-2D 金色の「？」マーク（気づいた時）
	if current_state == State.NOTICE:
		var q_pos = Vector2(0, -26)
		draw_circle(q_pos, 7.5, Color(0.98, 0.78, 0.25, 0.95))
		draw_circle(q_pos, 5.5, Color(0.95, 0.55, 0.15, 0.95))
		draw_arc(q_pos - Vector2(0, 1), 2.5, PI, TAU, 12, Color.WHITE, 1.8)
		draw_line(q_pos + Vector2(2.5, -1), q_pos + Vector2(0, 1.5), Color.WHITE, 1.8)
		draw_circle(q_pos + Vector2(0, 3.8), 1.2, Color.WHITE)
