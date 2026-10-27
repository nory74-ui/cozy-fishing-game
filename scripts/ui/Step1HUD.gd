extends Control

# ステップ3対応 HUD（パステルカードガイド、所持金、バケツ匹数、よろず屋ボタン）

signal open_shop_requested()
signal open_book_requested()

@onready var status_label: Label = $Card/VBox/StatusLabel
@onready var tip_label: Label = $Card/VBox/TipLabel
@onready var stats_label: Label = $Card/VBox/HBoxStats/StatsLabel
@onready var btn_book: Button = $Card/VBox/HBoxStats/BookButton
@onready var btn_shop: Button = $Card/VBox/HBoxStats/ShopButton
@onready var btn_title: Button = $Card/VBox/HBoxStats/TitleButton

func _ready() -> void:
	GameData.coins_changed.connect(func(_val): update_stats())
	GameData.inventory_changed.connect(func(): update_stats())
	GameData.equipment_changed.connect(func(): update_stats())
	GameData.book_updated.connect(func(_sp, _f, _r): update_stats())
	
	if btn_shop:
		_apply_pastel_btn_style(btn_shop)
		btn_shop.pressed.connect(func(): open_shop_requested.emit())
	if btn_book:
		_apply_pastel_btn_style(btn_book)
		btn_book.pressed.connect(func(): open_book_requested.emit())
	if btn_title:
		_apply_pastel_btn_style(btn_title)
		btn_title.pressed.connect(func():
			SoundManager.play_sfx("coin")
			SoundManager.stop_bgm(0.5)
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		)
		
	update_stats()
	set_status("水辺を探して、魚影の近くにウキを投げてみよう")

func _apply_pastel_btn_style(btn: Button) -> void:
	var st_n = StyleBoxFlat.new()
	st_n.bg_color = Color(0.95, 0.92, 0.85, 0.95)
	st_n.border_color = Color(0.78, 0.66, 0.52, 0.9)
	st_n.set_border_width_all(1)
	st_n.set_corner_radius_all(6)
	st_n.content_margin_left = 10.0
	st_n.content_margin_right = 10.0
	st_n.content_margin_top = 4.0
	st_n.content_margin_bottom = 4.0
	
	var st_h = st_n.duplicate()
	st_h.bg_color = Color(0.99, 0.96, 0.88, 1.0)
	st_h.border_color = Color(0.90, 0.55, 0.30, 0.95)
	
	var st_p = st_n.duplicate()
	st_p.bg_color = Color(0.88, 0.84, 0.76, 1.0)
	
	btn.add_theme_stylebox_override("normal", st_n)
	btn.add_theme_stylebox_override("hover", st_h)
	btn.add_theme_stylebox_override("pressed", st_p)
	btn.add_theme_color_override("font_color", Color(0.20, 0.28, 0.32, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.12, 0.20, 0.25, 1.0))
	btn.add_theme_font_size_override("font_size", 13)

func update_stats() -> void:
	if stats_label:
		var tools_str = ""
		if GameData.has_boots: tools_str += " [長靴]"
		if GameData.has_axe: tools_str += " [オノ]"
		if GameData.has_boat: tools_str += " [ボート]"
		
		var discovered = GameData.get_discovered_count()
		var total = GameData.get_total_species_count()
		stats_label.text = "所持金: " + str(GameData.coins) + " G | バケツ: " + str(GameData.inventory.size()) + "匹 | 図鑑: " + str(discovered) + "/" + str(total) + "種" + tools_str
		
	if tip_label:
		var rod_name = GameData.RODS.get(GameData.current_rod, {}).get("name", "木の枝竿")
		var b_count = GameData.bait_counts.get(GameData.current_bait, 0)
		var b_name = GameData.BAITS.get(GameData.current_bait, {}).get("name", "みみず")
		var bait_info = b_name + "(×" + str(b_count) + ")" if b_count > 0 else "エサなし"
		tip_label.text = "竿: " + rod_name + " ＆ エサ: " + bait_info + "  |  【WASD】移動 【左クリック】釣り 【E】調べる"

func set_status(text: String, is_alert: bool = false) -> void:
	if status_label:
		status_label.text = text
		if is_alert:
			status_label.modulate = Color("#e76f51")
		else:
			status_label.modulate = Color("#264653")
