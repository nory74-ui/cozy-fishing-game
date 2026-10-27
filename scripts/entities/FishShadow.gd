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
		"medaka":
			fish_name = "メダカ"
			swim_speed = 36.0 # 小刻みにすばしっこく泳ぐ
		"yamame":
			fish_name = "ヤマメ"
			swim_speed = 40.0 # 清流を鋭く俊敏に泳ぐ
		"iwana":
			fish_name = "イワナ"
			swim_speed = 32.0 # 岩陰に潜みながら警戒して泳ぐ
		"funa":
			fish_name = "ギンブナ"
			swim_speed = 24.0 # のんびり池底を巡回
		"rainbow_trout":
			fish_name = "ニジマス"
			swim_speed = 42.0 # 滝壺を力強く活発に回遊
		"koi":
			fish_name = "ニシキゴイ"
			swim_speed = 20.0 # 悠然と優雅に泳ぐ
		"catfish":
			fish_name = "ナマズ"
			swim_speed = 18.0 # 水底を重々しく這うように泳ぐ
		"golden_koi":
			fish_name = "黄金の主"
			swim_speed = 16.0 # 威風堂々たる威厳ある泳ぎ
		_:
			fish_name = "魚"
			swim_speed = 28.0

func get_shadow_size_desc() -> String:
	match fish_species:
		"medaka":
			return "ちいさな魚影"
		"funa":
			return "丸っこい魚影"
		"yamame":
			return "すばやい魚影"
		"iwana":
			return "渓流の魚影"
		"rainbow_trout":
			return "大きな力強い魚影"
		"koi":
			return "優雅な大きな魚影"
		"catfish":
			return "底に潜む大きな魚影"
		"golden_koi":
			return "金色にきらめく巨大な主の魚影"
		_:
			return "水中の魚影"

func _setup_sprite() -> void:
	# 全8魚種すべて専用の実在スプライトテクスチャを読み込み
	var tex = GameData.load_texture("res://assets/hd2d_fish_" + fish_species + ".png")
	if not tex:
		tex = GameData.load_texture("res://assets/fish_" + fish_species + ".png")
		
	if tex:
		# 実在のサイズ比率（メダカ3cm 〜 黄金の主100cm）を精密に反映したスケーリング
		var scale_val = Vector2(0.07, 0.07)
		match fish_species:
			"medaka":        scale_val = Vector2(0.032, 0.030) # 極小・スリム
			"yamame":        scale_val = Vector2(0.062, 0.058) # 流線型スリム
			"iwana":         scale_val = Vector2(0.068, 0.056) # 円筒形・岩陰魚影
			"funa":          scale_val = Vector2(0.066, 0.066) # 体高のある丸型
			"rainbow_trout": scale_val = Vector2(0.084, 0.076) # 太くがっしりしたトラウト
			"catfish":       scale_val = Vector2(0.098, 0.090) # 頭部が平たく大きい底生魚
			"koi":           scale_val = Vector2(0.105, 0.095) # 肉厚で大柄な錦鯉
			"golden_koi":    scale_val = Vector2(0.145, 0.135) # 画面を圧倒する巨大な主！

		sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.scale = scale_val
		
		# 水中の魚影（シルエット）シェーダーを適用
		var shadow_shader = load("res://assets/shaders/fish_shadow.gdshader")
		if shadow_shader:
			var mat = ShaderMaterial.new()
			mat.shader = shadow_shader
			
			var shadow_col = Color(0.12, 0.22, 0.35, 0.70)
			var glow_col = Color(0.0, 0.0, 0.0, 0.0)
			
			match fish_species:
				"medaka":
					shadow_col = Color(0.20, 0.30, 0.42, 0.55) # 浅瀬の小さな淡い半透明の影
				"catfish":
					shadow_col = Color(0.06, 0.12, 0.22, 0.85) # 底に潜む濃く重い影
				"golden_koi":
					shadow_col = Color(0.18, 0.24, 0.30, 0.82)
					glow_col = Color(1.20, 1.00, 0.45, 0.38)   # 神秘的な黄金のオーラ微光
				_:
					shadow_col = Color(0.12, 0.22, 0.36, 0.72)
					
			mat.set_shader_parameter("shadow_color", shadow_col)
			mat.set_shader_parameter("glow_color", glow_col)
			mat.set_shader_parameter("depth_fade", 0.30)
			sprite.material = mat
		else:
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
		match fish_species:
			"yamame", "rainbow_trout":
				notice_timer = randf_range(0.15, 0.45) # 鋭くすばやい反応
			"iwana":
				notice_timer = randf_range(0.40, 1.10) # 慎重に観察する間
			"golden_koi", "koi":
				notice_timer = randf_range(0.50, 1.30) # 悠然とした反応
			_:
				notice_timer = randf_range(0.25, 0.85)
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
	
	if dist < 22.0 or global_position.distance_to(target_bobber.global_position) < 32.0:
		_start_nibbling()
	else:
		swim_direction = swim_direction.slerp(to_target.normalized(), delta * 4.5).normalized()
		global_position += swim_direction * (swim_speed * 1.15) * delta

# つつき・ヒット開始処理（魚種と個体による多彩でリアルなランダムタイミング）
func _start_nibbling() -> void:
	target_bobber.occupied_by_fish = self
	current_state = State.NIBBLE
	nibble_count = 0
	fish_reached_bobber.emit()
	
	var r = randf() # 0.0 〜 1.0
	
	# 魚種ごとの捕食習性に応じたタイミング・つつき回数プロファイル
	match fish_species:
		"yamame", "rainbow_trout":
			# 俊敏なトラウト類: アグレッシブ！電撃即食い or 1〜2回の鋭いつつき
			if r < 0.22:
				max_nibbles = 0 # 電撃即ヒット！
				nibble_timer = randf_range(0.20, 0.40)
			elif r < 0.65:
				max_nibbles = 1 # 1回つつき即食い
				nibble_timer = randf_range(0.30, 0.55)
			else:
				max_nibbles = randi_range(2, 3) # 2〜3回
				nibble_timer = randf_range(0.40, 0.75)
				
		"iwana":
			# 警戒心の強いイワナ: ウキの前で様子見＆慎重なつつき
			if r < 0.10:
				max_nibbles = 1
				nibble_timer = randf_range(0.40, 0.70)
			elif r < 0.60:
				max_nibbles = randi_range(2, 3)
				nibble_timer = randf_range(0.60, 1.20)
			else:
				max_nibbles = randi_range(4, 5) # じらしパターン！
				nibble_timer = randf_range(0.80, 1.60)
				
		"catfish":
			# 底から一気に吸い込むナマズ: 即食い、またはじっと待ってから一撃
			if r < 0.25:
				max_nibbles = 0 # 下からドスン！
				nibble_timer = randf_range(0.25, 0.50)
			elif r < 0.70:
				max_nibbles = 1
				nibble_timer = randf_range(0.50, 0.90)
			else:
				max_nibbles = randi_range(2, 3)
				nibble_timer = randf_range(0.70, 1.30)
				
		"golden_koi", "koi":
			# 悠然とした大ゴイ: じわじわと間をあけて焦らしつつ食い込む
			if r < 0.08:
				max_nibbles = 0
				nibble_timer = randf_range(0.35, 0.60)
			elif r < 0.45:
				max_nibbles = randi_range(1, 2)
				nibble_timer = randf_range(0.60, 1.20)
			else:
				max_nibbles = randi_range(3, 4) # 堂々の3〜4回つつき
				nibble_timer = randf_range(0.80, 1.70)
				
		"medaka":
			# メダカ: ちょこまかとした小刻みな突進
			if r < 0.20:
				max_nibbles = 1
				nibble_timer = randf_range(0.25, 0.45)
			else:
				max_nibbles = randi_range(2, 4)
				nibble_timer = randf_range(0.30, 0.60)
				
		_: # ギンブナなど
			if r < 0.12:
				max_nibbles = 0
				nibble_timer = randf_range(0.25, 0.45)
			elif r < 0.40:
				max_nibbles = 1
				nibble_timer = randf_range(0.40, 0.70)
			elif r < 0.80:
				max_nibbles = randi_range(2, 3)
				nibble_timer = randf_range(0.50, 1.10)
			else:
				max_nibbles = randi_range(4, 5) # 警戒フェイント
				nibble_timer = randf_range(0.80, 1.50)
				
	# つつき回数が1回以上の場合は最初のツンを演出
	if max_nibbles > 0:
		var strength = randf_range(2.5, 5.0)
		if target_bobber.has_method("trigger_nibble"):
			target_bobber.trigger_nibble(strength)

func _process_nibble(delta: float) -> void:
	if not is_instance_valid(target_bobber) or not target_bobber.is_active:
		current_state = State.WANDER
		return
		
	nibble_timer -= delta
	if nibble_timer <= 0.0:
		nibble_count += 1
		if nibble_count > max_nibbles:
			# 本命の食い込み（HIT!!）
			current_state = State.BITE
			target_bobber.trigger_bite()
			fish_bit.emit()
		else:
			# 次のつつきまでのインターバル（毎度ランダムに揺らぐリアルな間隔！）
			var interval = randf_range(0.35, 1.30)
			# たまにフェイントで長めの間（焦らし）を挟む
			if randf() < 0.22:
				interval = randf_range(1.20, 2.00)
			nibble_timer = interval
			
			var strength = randf_range(2.2, 5.5)
			if target_bobber.has_method("trigger_nibble"):
				target_bobber.trigger_nibble(strength)
			swim_direction = swim_direction.rotated(randf_range(-0.4, 0.4))

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
