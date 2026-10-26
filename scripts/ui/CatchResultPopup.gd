extends Control

# 水彩絵本調の釣果獲得ポップアップ（実在魚のイラスト、サイズ、レア度、説明、価格）

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

func _ready() -> void:
	visible = false
	GameData.apply_pastel_button_style(btn_confirm)
	btn_confirm.pressed.connect(_on_confirm)

func show_result(fish_data: Dictionary) -> void:
	current_fish = fish_data
	visible = true
	
	title_label.text = "✨ " + fish_data.get("name", "魚") + " を釣り上げた！"
	
	# スプライト画像の読み込み
	var species = fish_data.get("species", "funa")
	var tex_name = species
	if tex_name == "medaka" or tex_name == "iwana" or tex_name == "rainbow_trout":
		tex_name = "yamame"
	elif tex_name == "golden_koi":
		tex_name = "koi"
		
	var tex = GameData.load_texture("res://assets/hd2d_fish_" + tex_name + ".png")
	if not tex:
		tex = GameData.load_texture("res://assets/fish_" + tex_name + ".png")
	if fish_tex_rect:
		fish_tex_rect.texture = tex
		match species:
			"medaka":
				fish_tex_rect.modulate = Color(1.0, 0.82, 0.5, 1.0)
			"iwana":
				fish_tex_rect.modulate = Color(0.72, 0.88, 0.65, 1.0)
			"rainbow_trout":
				fish_tex_rect.modulate = Color(1.15, 0.85, 0.95, 1.0)
			"golden_koi":
				fish_tex_rect.modulate = Color(1.4, 1.25, 0.55, 1.0)
			_:
				fish_tex_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
		
	size_label.text = "サイズ: " + str(fish_data.get("size", 15.0)) + " cm"
	
	# 図鑑登録・大物記録バッジ
	var is_first = fish_data.get("is_first", false)
	var is_new_record = fish_data.get("is_new_record", false)
	if record_badge_label:
		if is_first:
			record_badge_label.visible = true
			record_badge_label.text = "🎉 【新種発見！】お魚図鑑に登録！"
			record_badge_label.add_theme_color_override("font_color", Color("#2a9d8f"))
		elif is_new_record:
			record_badge_label.visible = true
			record_badge_label.text = "👑 【大物記録更新！】自己ベスト！"
			record_badge_label.add_theme_color_override("font_color", Color("#e76f51"))
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
			
	desc_label.text = fish_data.get("desc", "のんびり泳ぐ魚。")
	price_label.text = "売却価値: +" + str(fish_data.get("price", 10)) + " G"

func _on_confirm() -> void:
	visible = false
	confirmed.emit()
