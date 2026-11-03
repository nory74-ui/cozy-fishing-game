extends Control

# =============================================================================
# うみかぜ日和 〜 福岡・糸島 野北編 〜
# 【劇的釣果獲得ポップアップ (Dramatic Catch Presentation)】
# 魚を釣り上げた瞬間の「バシャーン！」、ファンファーレ、跳ねる魚、
# キラキラ光芒パーティクル、大物新記録ゴールドバナー、ミケの祝福演出！
# =============================================================================

signal confirmed()

@onready var title_label: Label = $Card/VBox/TitleLabel
@onready var fish_tex_rect: TextureRect = $Card/VBox/FishTextureRect
@onready var size_label: Label = $Card/VBox/SizeLabel
@onready var record_badge_label: Label = $Card/VBox/RecordBadgeLabel
@onready var rarity_label: Label = $Card/VBox/RarityLabel
@onready var desc_label: Label = $Card/VBox/DescLabel
@onready var price_label: Label = $Card/VBox/PriceLabel
@onready var btn_confirm: Button = $Card/VBox/ConfirmButton

var current_fish: Dictionary = {}
var time_counter: float = 0.0
var particles: Array[Dictionary] = []
var celebration_anim: float = 0.0

func _ready() -> void:
	visible = false
	GameData.apply_pastel_button_style(btn_confirm)
	btn_confirm.pressed.connect(_on_confirm)
	if desc_label:
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(400, 0)

func _process(delta: float) -> void:
	if not visible: return
	time_counter += delta
	celebration_anim += delta * 6.0
	
	# パーティクル更新
	for p in particles:
		p["pos"] += p["vel"] * delta
		p["alpha"] = maxf(0.0, p["alpha"] - delta * 0.8)
		p["rot"] += p["rot_speed"] * delta
		
	queue_redraw()

func show_result(fish_data: Dictionary) -> void:
	current_fish = fish_data
	visible = true
	time_counter = 0.0
	celebration_anim = 0.0
	
	# ファンファーレSE再生
	SoundManager.play_sfx("fanfare", 0.02, 2.0)
	
	# パーティクル生成（金・白・水色の星と光粒）
	particles.clear()
	var center = size * 0.5
	for i in range(36):
		var angle = randf() * TAU
		var spd = randf_range(80.0, 320.0)
		particles.append({
			"pos": center + Vector2(cos(angle), sin(angle)) * randf_range(10, 50),
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"alpha": 1.0,
			"size": randf_range(4.0, 9.0),
			"rot": randf() * TAU,
			"rot_speed": randf_range(-4.0, 4.0),
			"color": [Color("#ffd166"), Color("#06d6a0"), Color("#118ab2"), Color("#ffffff")][randi() % 4]
		})
		
	title_label.text = "✨ " + fish_data.get("name", "魚") + " を釣り上げた！ ✨"
	
	# 魚テクスチャの読み込み
	var species = fish_data.get("species", "funa")
	var tex = GameData.load_texture("res://assets/fish_side_" + species + ".png")
	if not tex:
		tex = GameData.load_texture("res://assets/fish_" + species + ".png")
	if not tex:
		tex = GameData.load_texture("res://assets/hd2d_fish_" + species + ".png")
	if fish_tex_rect:
		fish_tex_rect.texture = tex
		fish_tex_rect.modulate = Color.WHITE
		# 魚がピチピチ跳ねるTweenアニメーション
		fish_tex_rect.pivot_offset = fish_tex_rect.size * 0.5
		var tw = create_tween().set_parallel(false)
		tw.tween_property(fish_tex_rect, "scale", Vector2(1.25, 0.8), 0.12)
		tw.tween_property(fish_tex_rect, "scale", Vector2(0.85, 1.2), 0.14)
		tw.tween_property(fish_tex_rect, "scale", Vector2(1.1, 0.95), 0.12)
		tw.tween_property(fish_tex_rect, "scale", Vector2.ONE, 0.15)
		
	size_label.text = "サイズ: " + str(fish_data.get("size", 15.0)) + " cm"
	
	# 大物記録・新種発見バッジ
	var is_first = fish_data.get("is_first", false)
	var is_new_record = fish_data.get("is_new_record", false)
	if record_badge_label:
		if is_first:
			record_badge_label.visible = true
			record_badge_label.text = "★【新種発見！】お魚図鑑に新登録！★"
			record_badge_label.add_theme_color_override("font_color", Color("#06d6a0"))
		elif is_new_record:
			record_badge_label.visible = true
			record_badge_label.text = "👑【NEW RECORD! 自己最高記録更新！】👑"
			record_badge_label.add_theme_color_override("font_color", Color("#ffd166"))
		else:
			record_badge_label.visible = false
	
	var rarity = fish_data.get("rarity", "Common")
	rarity_label.text = "【" + rarity + "】"
	match rarity:
		"Common":
			rarity_label.modulate = Color("#2a9d8f")
		"Rare":
			rarity_label.modulate = Color("#e76f51")
		"Epic":
			rarity_label.modulate = Color("#7209b7")
		"Legendary":
			rarity_label.modulate = Color("#f4a261")
			
	desc_label.text = fish_data.get("desc", "玄界灘に生息する魚。")
	price_label.text = "売却価値: +" + str(fish_data.get("price", 10)) + " G"

func _draw() -> void:
	if not visible: return
	
	# キラキラ光芒星パーティクルの描画
	for p in particles:
		if p["alpha"] <= 0.0: continue
		var col: Color = p["color"]
		var c = Color(col.r, col.g, col.b, p["alpha"])
		var sz = p["size"]
		var pos = p["pos"]
		draw_set_transform(pos, p["rot"], Vector2.ONE)
		# 4点星
		draw_line(Vector2(-sz, 0), Vector2(sz, 0), c, 2.0)
		draw_line(Vector2(0, -sz), Vector2(0, sz), c, 2.0)
		draw_circle(Vector2.ZERO, sz * 0.4, c)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _on_confirm() -> void:
	visible = false
	confirmed.emit()
