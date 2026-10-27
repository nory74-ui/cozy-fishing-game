extends Control

# 水辺のよろず屋モーダル（魚売却、探索道具アンロック、釣り竿、エサ）

signal closed()

@onready var tab_sell: Button = $Card/VBox/TabHBox/BtnSell
@onready var tab_tools: Button = $Card/VBox/TabHBox/BtnTools
@onready var tab_rods: Button = $Card/VBox/TabHBox/BtnRods
@onready var tab_baits: Button = $Card/VBox/TabHBox/BtnBaits
@onready var btn_close: Button = $Card/VBox/HeaderHBox/CloseBtn
@onready var backdrop: ColorRect = $Backdrop

@onready var content_list: VBoxContainer = $Card/VBox/Scroll/ContentList
@onready var status_bar: Label = $Card/VBox/BottomBar/StatusLabel
@onready var btn_action_all: Button = $Card/VBox/BottomBar/ActionAllBtn

enum Tab { SELL, TOOLS, RODS, BAITS }
var current_tab: Tab = Tab.SELL

func _ready() -> void:
	visible = false
	for b in [tab_sell, tab_tools, tab_rods, tab_baits, btn_close, btn_action_all]:
		GameData.apply_pastel_button_style(b)
		
	tab_sell.pressed.connect(func():
		SoundManager.play_sfx("book", 0.08, -3.0)
		switch_tab(Tab.SELL)
	)
	tab_tools.pressed.connect(func():
		SoundManager.play_sfx("book", 0.08, -3.0)
		switch_tab(Tab.TOOLS)
	)
	tab_rods.pressed.connect(func():
		SoundManager.play_sfx("book", 0.08, -3.0)
		switch_tab(Tab.RODS)
	)
	tab_baits.pressed.connect(func():
		SoundManager.play_sfx("book", 0.08, -3.0)
		switch_tab(Tab.BAITS)
	)
	
	if btn_close:
		btn_close.pressed.connect(close_shop)
		
	if backdrop:
		backdrop.gui_input.connect(_on_backdrop_gui_input)
		
	btn_action_all.pressed.connect(_on_action_all)
	
	GameData.coins_changed.connect(func(_val): _refresh_ui())
	GameData.inventory_changed.connect(func(): _refresh_ui())
	GameData.equipment_changed.connect(func(): _refresh_ui())

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			close_shop()
			get_viewport().set_input_as_handled()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_shop()

func open_shop() -> void:
	visible = true
	switch_tab(Tab.SELL)

func close_shop() -> void:
	visible = false
	closed.emit()

func switch_tab(tab: Tab) -> void:
	current_tab = tab
	tab_sell.button_pressed = (tab == Tab.SELL)
	tab_tools.button_pressed = (tab == Tab.TOOLS)
	tab_rods.button_pressed = (tab == Tab.RODS)
	tab_baits.button_pressed = (tab == Tab.BAITS)
	_refresh_ui()

func _clear_list() -> void:
	for child in content_list.get_children():
		child.queue_free()

func _refresh_ui() -> void:
	if not visible:
		return
	_clear_list()
	match current_tab:
		Tab.SELL:
			_render_sell_tab()
		Tab.TOOLS:
			_render_tools_tab()
		Tab.RODS:
			_render_rods_tab()
		Tab.BAITS:
			_render_baits_tab()

func _make_item_panel() -> PanelContainer:
	var item_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.94, 0.90, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.78, 0.68, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	item_panel.add_theme_stylebox_override("panel", style)
	return item_panel

# --- 1. 魚売却タブ ---
func _render_sell_tab() -> void:
	status_bar.add_theme_color_override("font_color", Color("#2b2d42"))
	var total_value = 0
	for fish in GameData.inventory:
		total_value += fish.get("price", 10)
		
	btn_action_all.visible = true
	btn_action_all.text = "すべての魚を売る (+" + str(total_value) + " G)"
	btn_action_all.disabled = (GameData.inventory.size() == 0)
	status_bar.text = "所持金: " + str(GameData.coins) + " G  |  バケツ: " + str(GameData.inventory.size()) + " 匹"

	if GameData.inventory.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "バケツは空っぽです。川や池で魚を釣って持ってこよう！"
		empty_lbl.add_theme_color_override("font_color", Color("#5c677d"))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_list.add_child(empty_lbl)
		return

	for i in range(GameData.inventory.size()):
		var fish = GameData.inventory[i]
		var item_panel = _make_item_panel()
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		
		var sp = fish.get("species", "funa")
		var f_tex = GameData.load_texture("res://assets/fish_side_" + sp + ".png")
		if f_tex:
			var icon_rect = TextureRect.new()
			icon_rect.texture = f_tex
			icon_rect.custom_minimum_size = Vector2(56, 28)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hbox.add_child(icon_rect)
		
		var icon_lbl = Label.new()
		icon_lbl.text = fish.get("name", "魚") + " (" + str(fish.get("size", 15.0)) + " cm)"
		icon_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_lbl.add_theme_color_override("font_color", Color("#2b2d42"))
		hbox.add_child(icon_lbl)
		
		var rarity_lbl = Label.new()
		var rarity = fish.get("rarity", "Common")
		rarity_lbl.text = "【" + rarity + "】"
		rarity_lbl.custom_minimum_size = Vector2(80, 0)
		match rarity:
			"Common": rarity_lbl.modulate = Color("#2a9d8f")
			"Rare": rarity_lbl.modulate = Color("#e76f51")
			"Epic": rarity_lbl.modulate = Color("#7209b7")
			"Legendary": rarity_lbl.modulate = Color("#f4a261")
		hbox.add_child(rarity_lbl)
		
		var price_lbl = Label.new()
		var price = fish.get("price", 10)
		price_lbl.text = "+" + str(price) + " G"
		price_lbl.custom_minimum_size = Vector2(80, 0)
		price_lbl.add_theme_color_override("font_color", Color("#e76f51"))
		hbox.add_child(price_lbl)
		
		var sell_btn = Button.new()
		sell_btn.text = "売却"
		sell_btn.custom_minimum_size = Vector2(80, 36)
		sell_btn.add_theme_font_size_override("font_size", 13)
		GameData.apply_pastel_button_style(sell_btn)
		var idx = i
		sell_btn.pressed.connect(func(): GameData.sell_fish_at(idx))
		hbox.add_child(sell_btn)
		
		item_panel.add_child(hbox)
		content_list.add_child(item_panel)

# --- 2. 探索道具タブ ---
func _render_tools_tab() -> void:
	btn_action_all.visible = false
	status_bar.add_theme_color_override("font_color", Color("#2b2d42"))
	status_bar.text = "所持金: " + str(GameData.coins) + " G  |  道具を手に入れて新しい釣りスポットを開拓しよう！"
	
	for tool_key in ["boots", "axe", "boat"]:
		var tool = GameData.TOOLS.get(tool_key)
		var is_owned = GameData.has_tool(tool_key)
		
		var item_panel = _make_item_panel()
		var hbox = HBoxContainer.new()
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_lbl = Label.new()
		title_lbl.text = tool.name + (" 【購入済】" if is_owned else "")
		title_lbl.add_theme_color_override("font_color", Color("#2b2d42"))
		var desc_lbl = Label.new()
		desc_lbl.text = tool.desc
		desc_lbl.add_theme_color_override("font_color", Color("#5c677d"))
		vbox.add_child(title_lbl)
		vbox.add_child(desc_lbl)
		hbox.add_child(vbox)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(130, 36)
		btn.add_theme_font_size_override("font_size", 13)
		GameData.apply_pastel_button_style(btn)
		if is_owned:
			btn.text = "購入済"
			btn.disabled = true
		else:
			btn.text = "購入 (" + str(tool.price) + " G)"
			btn.disabled = (GameData.coins < tool.price)
			btn.pressed.connect(func(): GameData.buy_tool(tool_key))
		hbox.add_child(btn)
		
		item_panel.add_child(hbox)
		content_list.add_child(item_panel)

# --- 3. 釣り竿タブ ---
func _render_rods_tab() -> void:
	btn_action_all.visible = false
	status_bar.add_theme_color_override("font_color", Color("#2b2d42"))
	status_bar.text = "所持金: " + str(GameData.coins) + " G  |  竿が良いほど魚が引きやすく、緑枠が広がります。"
	
	for rod_key in ["branch_rod", "bamboo_rod", "carbon_rod", "master_rod"]:
		var rod = GameData.RODS.get(rod_key)
		var is_unlocked = rod_key in GameData.unlocked_rods
		var is_equipped = (GameData.current_rod == rod_key)
		
		var item_panel = _make_item_panel()
		var hbox = HBoxContainer.new()
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_lbl = Label.new()
		title_lbl.text = rod.name + (" [装備中]" if is_equipped else "")
		title_lbl.add_theme_color_override("font_color", Color("#2b2d42"))
		var desc_lbl = Label.new()
		desc_lbl.text = rod.desc + " (パワー: x" + str(rod.power) + ", 安定度: x" + str(rod.stability) + ")"
		desc_lbl.add_theme_color_override("font_color", Color("#5c677d"))
		vbox.add_child(title_lbl)
		vbox.add_child(desc_lbl)
		hbox.add_child(vbox)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(130, 36)
		btn.add_theme_font_size_override("font_size", 13)
		GameData.apply_pastel_button_style(btn)
		if is_equipped:
			btn.text = "装備中"
			btn.disabled = true
		elif is_unlocked:
			btn.text = "装備する"
			btn.pressed.connect(func(): GameData.equip_rod(rod_key))
		else:
			btn.text = "購入 (" + str(rod.price) + " G)"
			btn.disabled = (GameData.coins < rod.price)
			btn.pressed.connect(func(): GameData.buy_rod(rod_key))
		hbox.add_child(btn)
		
		item_panel.add_child(hbox)
		content_list.add_child(item_panel)

# --- 4. エサタブ ---
func _render_baits_tab() -> void:
	btn_action_all.visible = false
	status_bar.add_theme_color_override("font_color", Color("#2b2d42"))
	status_bar.text = "所持金: " + str(GameData.coins) + " G  |  良いエサほど珍しい魚や大物が集まります。"
	
	for bait_key in ["worm", "dumpling", "lure"]:
		var bait = GameData.BAITS.get(bait_key)
		var count = GameData.bait_counts.get(bait_key, 0)
		var is_equipped = (GameData.current_bait == bait_key and count > 0)
		
		var item_panel = _make_item_panel()
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_lbl = Label.new()
		title_lbl.text = bait.name + " (所持: " + str(count) + "個)" + (" [使用中]" if is_equipped else "")
		title_lbl.add_theme_color_override("font_color", Color("#2b2d42"))
		var desc_lbl = Label.new()
		desc_lbl.text = bait.desc + " [引き寄せ＆大物補正: x" + str(bait.rare_boost) + "]"
		desc_lbl.add_theme_color_override("font_color", Color("#5c677d"))
		vbox.add_child(title_lbl)
		vbox.add_child(desc_lbl)
		hbox.add_child(vbox)
		
		if count > 0 and not is_equipped:
			var eq_btn = Button.new()
			eq_btn.custom_minimum_size = Vector2(76, 36)
			eq_btn.add_theme_font_size_override("font_size", 13)
			GameData.apply_pastel_button_style(eq_btn)
			eq_btn.text = "使う"
			eq_btn.pressed.connect(func(): GameData.equip_bait(bait_key))
			hbox.add_child(eq_btn)
		
		var buy_btn = Button.new()
		buy_btn.custom_minimum_size = Vector2(130, 36)
		buy_btn.add_theme_font_size_override("font_size", 13)
		GameData.apply_pastel_button_style(buy_btn)
		buy_btn.text = str(bait.pack_amount) + "個購入 (" + str(bait.price) + " G)"
		buy_btn.disabled = (GameData.coins < bait.price)
		buy_btn.pressed.connect(func(): GameData.buy_bait(bait_key))
		hbox.add_child(buy_btn)
		
		item_panel.add_child(hbox)
		content_list.add_child(item_panel)

func _on_action_all() -> void:
	if current_tab == Tab.SELL:
		GameData.sell_all_fish()
