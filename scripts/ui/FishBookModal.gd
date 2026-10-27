extends Control

# 水彩絵本調の「お魚図鑑」（全8種類の魚の生態・最大サイズ記録・累計釣果コレクション）

signal closed()

@onready var title_label: Label = $Card/VBox/HeaderHBox/TitleLabel
@onready var progress_label: Label = $Card/VBox/HeaderHBox/ProgressLabel
@onready var btn_close: Button = $Card/VBox/HeaderHBox/CloseBtn
@onready var backdrop: ColorRect = $Backdrop

# リストと詳細
@onready var fish_list_container: VBoxContainer = $Card/VBox/BodyHBox/LeftScroll/FishList
@onready var detail_card: PanelContainer = $Card/VBox/BodyHBox/DetailCard
@onready var detail_container: VBoxContainer = $Card/VBox/BodyHBox/DetailCard/DetailVBox

# 詳細パネル内のノード
@onready var detail_icon: TextureRect = $Card/VBox/BodyHBox/DetailCard/DetailVBox/FishTextureRect
@onready var detail_name: Label = $Card/VBox/BodyHBox/DetailCard/DetailVBox/NameLabel
@onready var detail_rarity: Label = $Card/VBox/BodyHBox/DetailCard/DetailVBox/RarityLabel
@onready var detail_max_size: Label = $Card/VBox/BodyHBox/DetailCard/DetailVBox/StatsHBox/MaxSizeLabel
@onready var detail_count: Label = $Card/VBox/BodyHBox/DetailCard/DetailVBox/StatsHBox/CountLabel
@onready var detail_habitat: Label = $Card/VBox/BodyHBox/DetailCard/DetailVBox/HabitatLabel
@onready var detail_desc: Label = $Card/VBox/BodyHBox/DetailCard/DetailVBox/DescLabel

var selected_species: String = "medaka"
const SPECIES_ORDER: Array[String] = [
	"medaka", "yamame", "funa", "koi", "catfish", "iwana", "rainbow_trout", "golden_koi"
]

func _ready() -> void:
	visible = false
	if btn_close:
		GameData.apply_pastel_button_style(btn_close)
		btn_close.pressed.connect(close_book)
	if backdrop:
		backdrop.gui_input.connect(_on_backdrop_gui_input)
		
	# 詳細カードの水彩紙スタイル
	if detail_card:
		var d_style = StyleBoxFlat.new()
		d_style.bg_color = Color(0.96, 0.94, 0.89, 0.95) # 優しいクリーム色
		d_style.border_width_left = 1
		d_style.border_width_top = 1
		d_style.border_width_right = 1
		d_style.border_width_bottom = 1
		d_style.border_color = Color(0.85, 0.78, 0.68, 0.9)
		d_style.corner_radius_top_left = 8
		d_style.corner_radius_top_right = 8
		d_style.corner_radius_bottom_right = 8
		d_style.corner_radius_bottom_left = 8
		d_style.content_margin_left = 16.0
		d_style.content_margin_top = 14.0
		d_style.content_margin_right = 16.0
		d_style.content_margin_bottom = 14.0
		detail_card.add_theme_stylebox_override("panel", d_style)
		
	GameData.book_updated.connect(func(_sp, _f, _r): _refresh_ui())

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B or event.keycode == KEY_J:
			close_book()
			get_viewport().set_input_as_handled()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_book()

func open_book() -> void:
	visible = true
	# 最初に選択する魚: 発見済の魚があればその魚、なければmedaka
	for sp in SPECIES_ORDER:
		if GameData.fish_records.has(sp):
			selected_species = sp
			break
	_refresh_ui()

func close_book() -> void:
	visible = false
	closed.emit()

func _refresh_ui() -> void:
	if not visible: return
	
	# 1. 進捗
	var discovered = GameData.get_discovered_count()
	var total = GameData.get_total_species_count()
	var pct = int((float(discovered) / float(total)) * 100.0)
	if progress_label:
		progress_label.text = "発見度: " + str(discovered) + " / " + str(total) + " 種 (" + str(pct) + "%)"
		if discovered == total:
			progress_label.text += " 【完全制覇！】"
			
	# 2. リスト再描画
	for child in fish_list_container.get_children():
		child.queue_free()
		
	for sp in SPECIES_ORDER:
		var base_data = GameData.FISH_DATABASE.get(sp, {})
		var is_discovered = GameData.fish_records.has(sp)
		var record = GameData.fish_records.get(sp, {})
		
		var item_btn = Button.new()
		item_btn.custom_minimum_size = Vector2(260, 48)
		item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# スタイル
		var style = StyleBoxFlat.new()
		if sp == selected_species:
			style.bg_color = Color(0.92, 0.88, 0.80, 0.95)
			style.border_color = Color("#b07d62")
			style.border_width_left = 3
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
		else:
			style.bg_color = Color(0.98, 0.96, 0.92, 0.75)
			style.border_color = Color(0.85, 0.80, 0.72, 0.7)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_bottom_left = 6
		style.content_margin_left = 10.0
		style.content_margin_top = 4.0
		style.content_margin_right = 10.0
		style.content_margin_bottom = 4.0
		item_btn.add_theme_stylebox_override("normal", style)
		item_btn.add_theme_stylebox_override("hover", style)
		item_btn.add_theme_stylebox_override("pressed", style)
		
		var btn_hbox = HBoxContainer.new()
		btn_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var name_lbl = Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		
		if is_discovered:
			name_lbl.text = base_data.get("name", "魚")
			name_lbl.add_theme_color_override("font_color", Color("#2b2d42"))
		else:
			name_lbl.text = "？？？？？？"
			name_lbl.add_theme_color_override("font_color", Color("#8d99ae"))
		btn_hbox.add_child(name_lbl)
		
		var max_lbl = Label.new()
		max_lbl.add_theme_font_size_override("font_size", 13)
		if is_discovered:
			var max_s = record.get("max_size", 0.0)
			max_lbl.text = str(max_s) + " cm"
			max_lbl.add_theme_color_override("font_color", Color("#e76f51"))
		else:
			max_lbl.text = "未発見"
			max_lbl.add_theme_color_override("font_color", Color("#adb5bd"))
		btn_hbox.add_child(max_lbl)
		
		item_btn.add_child(btn_hbox)
		
		var species_to_select = sp
		item_btn.pressed.connect(func():
			if selected_species != species_to_select:
				SoundManager.play_sfx("book", 0.08, -3.0)
			selected_species = species_to_select
			_refresh_ui()
		)
		fish_list_container.add_child(item_btn)
		
	# 3. 詳細プレビュー更新
	_render_detail()

func _render_detail() -> void:
	var base_data = GameData.FISH_DATABASE.get(selected_species, {})
	var is_discovered = GameData.fish_records.has(selected_species)
	var record = GameData.fish_records.get(selected_species, {})
	
	if is_discovered:
		detail_name.text = base_data.get("name", "魚")
		detail_name.add_theme_color_override("font_color", Color("#2b2d42"))
		
		var rarity = base_data.get("rarity", "Common")
		detail_rarity.text = "【レア度: " + rarity + "】"
		match rarity:
			"Common": detail_rarity.modulate = Color("#2a9d8f")
			"Rare": detail_rarity.modulate = Color("#e76f51")
			"Epic": detail_rarity.modulate = Color("#7209b7")
			"Legendary": detail_rarity.modulate = Color("#f4a261")
			
		detail_max_size.text = "最大記録: " + str(record.get("max_size", 0.0)) + " cm"
		detail_max_size.add_theme_color_override("font_color", Color("#d95d39"))
		detail_count.text = "累計釣果: " + str(record.get("caught_count", 0)) + " 匹"
		detail_count.add_theme_color_override("font_color", Color("#264653"))
		detail_habitat.text = "主な生息地: " + base_data.get("habitat", "水辺")
		detail_habitat.add_theme_color_override("font_color", Color("#2a6f97"))
		detail_desc.text = base_data.get("desc", "穏やかな水辺に棲む魚。")
		detail_desc.add_theme_color_override("font_color", Color("#4a4e69"))
		
		# イラスト読み込み
		var tex_name = selected_species
		if tex_name == "medaka" or tex_name == "iwana" or tex_name == "rainbow_trout":
			tex_name = "yamame"
		elif tex_name == "golden_koi":
			tex_name = "koi"
			
		var tex = GameData.load_texture("res://assets/hd2d_fish_" + tex_name + ".png")
		if not tex:
			tex = GameData.load_texture("res://assets/fish_" + tex_name + ".png")
		if detail_icon:
			detail_icon.texture = tex
			match selected_species:
				"medaka": detail_icon.modulate = Color(1.0, 0.82, 0.5, 1.0)
				"iwana": detail_icon.modulate = Color(0.72, 0.88, 0.65, 1.0)
				"rainbow_trout": detail_icon.modulate = Color(1.15, 0.85, 0.95, 1.0)
				"golden_koi": detail_icon.modulate = Color(1.4, 1.25, 0.55, 1.0)
				_: detail_icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		detail_name.text = "？？？？？？ (未発見)"
		detail_name.add_theme_color_override("font_color", Color("#8d99ae"))
		detail_rarity.text = "【レア度: ？？？】"
		detail_rarity.modulate = Color("#8d99ae")
		detail_max_size.text = "最大記録: --- cm"
		detail_max_size.add_theme_color_override("font_color", Color("#adb5bd"))
		detail_count.text = "累計釣果: 0 匹"
		detail_count.add_theme_color_override("font_color", Color("#adb5bd"))
		detail_habitat.text = "ヒント: " + base_data.get("habitat", "未知の水辺")
		detail_habitat.add_theme_color_override("font_color", Color("#6c757d"))
		detail_desc.text = "まだ釣り上げたことのない魚。道具を手に入れて新たな水辺を探索してみよう！"
		detail_desc.add_theme_color_override("font_color", Color("#8d99ae"))
		
		if detail_icon:
			detail_icon.texture = null
			detail_icon.modulate = Color.WHITE
