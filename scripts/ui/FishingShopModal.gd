extends CanvasLayer
class_name FishingShopModal

# --- 潮風釣具店（野北番屋支店）モーダルUI ---
# 釣り竿・道糸・リール・エサの売買・装備、および釣果魚の一括・個別売却

signal shop_closed

enum Tab {
	RODS,
	LINES,
	REELS,
	BAITS,
	SELL
}

var current_tab: Tab = Tab.RODS

# UIノード参照
@onready var panel_container: PanelContainer = $Center/PanelContainer
@onready var title_label: Label = $Center/PanelContainer/VBox/Header/TitleLabel
@onready var coins_label: Label = $Center/PanelContainer/VBox/Header/CoinsLabel
@onready var btn_close: Button = $Center/PanelContainer/VBox/Header/BtnClose

# タブボタン
@onready var btn_tab_rods: Button = $Center/PanelContainer/VBox/TabHBox/BtnTabRods
@onready var btn_tab_lines: Button = $Center/PanelContainer/VBox/TabHBox/BtnTabLines
@onready var btn_tab_reels: Button = $Center/PanelContainer/VBox/TabHBox/BtnTabReels
@onready var btn_tab_baits: Button = $Center/PanelContainer/VBox/TabHBox/BtnTabBaits
@onready var btn_tab_sell: Button = $Center/PanelContainer/VBox/TabHBox/BtnTabSell

# コンテンツ
@onready var item_scroll: ScrollContainer = $Center/PanelContainer/VBox/ItemScroll
@onready var item_vbox: VBoxContainer = $Center/PanelContainer/VBox/ItemScroll/ItemVBox
@onready var footer_hbox: HBoxContainer = $Center/PanelContainer/VBox/FooterHBox
@onready var sell_all_button: Button = $Center/PanelContainer/VBox/FooterHBox/SellAllButton
@onready var summary_label: Label = $Center/PanelContainer/VBox/FooterHBox/SummaryLabel

func _ready() -> void:
	visible = false
	
	if GameData:
		GameData.coins_changed.connect(_on_coins_changed)
		GameData.inventory_changed.connect(_refresh_current_tab)
		GameData.equipment_changed.connect(_refresh_current_tab)

	btn_close.pressed.connect(close_shop)
	
	btn_tab_rods.pressed.connect(func(): _switch_tab(Tab.RODS))
	btn_tab_lines.pressed.connect(func(): _switch_tab(Tab.LINES))
	btn_tab_reels.pressed.connect(func(): _switch_tab(Tab.REELS))
	btn_tab_baits.pressed.connect(func(): _switch_tab(Tab.BAITS))
	btn_tab_sell.pressed.connect(func(): _switch_tab(Tab.SELL))
	
	sell_all_button.pressed.connect(_on_sell_all_pressed)

	_style_tabs()
	_update_coins_display()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_U:
			close_shop()
			get_viewport().set_input_as_handled()

func open_shop(default_tab: Tab = Tab.RODS) -> void:
	visible = true
	_update_coins_display()
	_switch_tab(default_tab)
	if SoundManager:
		SoundManager.play_sfx("coin", 0.05, 1.0)

func close_shop() -> void:
	visible = false
	shop_closed.emit()

func _on_coins_changed(_new_amount: int) -> void:
	_update_coins_display()
	_refresh_current_tab()

func _update_coins_display() -> void:
	if not coins_label: return
	var c = GameData.coins if GameData else 0
	coins_label.text = "所持金: 🪙 %d G" % c

func _style_tabs() -> void:
	var tabs = [btn_tab_rods, btn_tab_lines, btn_tab_reels, btn_tab_baits, btn_tab_sell]
	for t in tabs:
		if t and GameData:
			GameData.apply_pastel_button_style(t)
	if sell_all_button and GameData:
		GameData.apply_pastel_button_style(sell_all_button)
	if btn_close and GameData:
		GameData.apply_pastel_button_style(btn_close)

func _switch_tab(tab: Tab) -> void:
	current_tab = tab
	# タブボタンスタイルの強調
	var tabs = [btn_tab_rods, btn_tab_lines, btn_tab_reels, btn_tab_baits, btn_tab_sell]
	for i in range(tabs.size()):
		var b = tabs[i]
		if b:
			if i == int(tab):
				b.modulate = Color(1.2, 1.15, 0.9, 1.0)
			else:
				b.modulate = Color(0.85, 0.85, 0.85, 0.8)
	_refresh_current_tab()

func _refresh_current_tab() -> void:
	if not visible or not item_vbox:
		return

	# 既存のリスト要素をクリア
	for child in item_vbox.get_children():
		child.queue_free()

	sell_all_button.visible = (current_tab == Tab.SELL)
	
	match current_tab:
		Tab.RODS:
			summary_label.text = "※ 竿のランクが足りないと、大物の突進時に耐えきれずバラシになります。"
			_populate_rods()
		Tab.LINES:
			summary_label.text = "※ 大物の重量に対してライン耐力(kg)が足りないと、突進時に高切れします。"
			_populate_lines()
		Tab.REELS:
			summary_label.text = "※ 高性能リールほどハイギアで巻き上げ速度がUPし、大物を一気に寄せられます。"
			_populate_reels()
		Tab.BAITS:
			summary_label.text = "※ 魚種ごとに好むエサが異なります。狙いたい魚に合わせてエサを選びましょう。"
			_populate_baits()
		Tab.SELL:
			_populate_sell_list()

# --- 1. 竿リスト ---
func _populate_rods() -> void:
	if not GameData: return
	for rod_id in ["starter_rod", "isokozue_rod", "shore_jig_rod", "master_genkai_rod"]:
		var rod = GameData.RODS.get(rod_id)
		if not rod: continue
		var card = _create_item_card()
		var is_unlocked = rod_id in GameData.unlocked_rods
		var is_equipped = (GameData.current_rod == rod_id)
		
		var title_txt = "【ランク%d】%s" % [rod.rank, rod.name]
		var sub_txt = "対象目安: %s (最大耐荷重: %0.1fkg)" % [rod.rank_label, rod.max_weight]
		var desc_txt = rod.desc
		
		_setup_card_info(card, title_txt, sub_txt, desc_txt)
		_setup_card_actions(card, rod.price, is_unlocked, is_equipped,
			func(): # 購入
				if GameData.buy_rod(rod_id):
					_refresh_current_tab(),
			func(): # 装備
				GameData.equip_rod(rod_id)
				_refresh_current_tab()
		)
		item_vbox.add_child(card)

# --- 2. 道糸・ラインリスト ---
func _populate_lines() -> void:
	if not GameData: return
	for line_id in ["nylon_1_5", "fluoro_3", "pe_1_2", "pe_2_5"]:
		var line_data = GameData.LINES.get(line_id)
		if not line_data: continue
		var card = _create_item_card()
		var is_unlocked = line_id in GameData.unlocked_lines
		var is_equipped = (GameData.current_line == line_id)
		
		var title_txt = "【ランク%d】%s" % [line_data.rank, line_data.name]
		var sub_txt = "破断耐力: %0.1f kg" % line_data.strength_kg
		var desc_txt = line_data.desc
		
		_setup_card_info(card, title_txt, sub_txt, desc_txt)
		_setup_card_actions(card, line_data.price, is_unlocked, is_equipped,
			func(): # 購入
				if GameData.buy_line(line_id):
					_refresh_current_tab(),
			func(): # 装備
				GameData.equip_line(line_id)
				_refresh_current_tab()
		)
		item_vbox.add_child(card)

# --- 3. リールリスト ---
func _populate_reels() -> void:
	if not GameData: return
	for reel_id in ["reel_1000", "reel_2500", "reel_4000"]:
		var reel = GameData.REELS.get(reel_id)
		if not reel: continue
		var card = _create_item_card()
		var is_unlocked = reel_id in GameData.unlocked_reels
		var is_equipped = (GameData.current_reel == reel_id)
		
		var title_txt = reel.name
		var sub_txt = "巻き上げ速度倍率: %0.2fx (ドラグ力: %0.1fx)" % [reel.reel_speed_mult, reel.drag_power]
		var desc_txt = reel.desc
		
		_setup_card_info(card, title_txt, sub_txt, desc_txt)
		_setup_card_actions(card, reel.price, is_unlocked, is_equipped,
			func(): # 購入
				if GameData.buy_reel(reel_id):
					_refresh_current_tab(),
			func(): # 装備
				GameData.equip_reel(reel_id)
				_refresh_current_tab()
		)
		item_vbox.add_child(card)

# --- 4. エサ・ルアーリスト ---
func _populate_baits() -> void:
	if not GameData: return
	for bait_id in ["okiami", "isome", "crab_bait", "live_fish", "lure"]:
		var bait = GameData.BAITS.get(bait_id)
		if not bait: continue
		var card = _create_item_card()
		var count = GameData.bait_counts.get(bait_id, 0)
		var is_equipped = (GameData.current_bait == bait_id and count > 0)
		var is_infinite = bait.get("is_infinite", false)
		
		var count_str = "∞ (買い切り)" if is_infinite else "%d 個所持" % count
		var title_txt = "%s  【%s】" % [bait.name, count_str]
		var sub_txt = "好む魚: %s" % bait.target_info
		var desc_txt = bait.desc
		
		_setup_card_info(card, title_txt, sub_txt, desc_txt)
		
		# エサのアクション設定
		var btn_container = card.get_node("HBox/ActionVBox")
		var price_btn = Button.new()
		GameData.apply_pastel_button_style(price_btn)
		
		if is_infinite and count > 0:
			price_btn.text = "購入済み"
			price_btn.disabled = true
		else:
			var pack_txt = "(1個)" if is_infinite else "(%d個)" % bait.pack_amount
			price_btn.text = "購入 %s: %d G" % [pack_txt, bait.price]
			price_btn.disabled = (GameData.coins < bait.price)
			price_btn.pressed.connect(func():
				if GameData.buy_bait(bait_id):
					_refresh_current_tab()
			)
		btn_container.add_child(price_btn)
		
		var equip_btn = Button.new()
		GameData.apply_pastel_button_style(equip_btn)
		if is_equipped:
			equip_btn.text = "✔ 装備中"
			equip_btn.disabled = true
			equip_btn.modulate = Color(0.4, 1.0, 0.5)
		else:
			equip_btn.text = "ハリにつける"
			equip_btn.disabled = (count <= 0)
			equip_btn.pressed.connect(func():
				GameData.equip_bait(bait_id)
				_refresh_current_tab()
			)
		btn_container.add_child(equip_btn)
		
		item_vbox.add_child(card)

# --- 5. 魚売却リスト ---
func _populate_sell_list() -> void:
	if not GameData: return
	var inv = GameData.inventory
	var total_val = 0
	for f in inv:
		total_val += f.get("price", 10)
		
	summary_label.text = "手持ちの魚: %d 匹 (売却見込み合計: 🪙 %d G)" % [inv.size(), total_val]
	sell_all_button.text = "💰 まとめて全て売却 (+%d G)" % total_val
	sell_all_button.disabled = (inv.is_empty())
	
	if inv.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "\n現在、ビクの中に魚はいません。\n野北の海で魚を釣り上げて持ってきましょう！"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		item_vbox.add_child(empty_lbl)
		return

	for i in range(inv.size()):
		var fish = inv[i]
		var card = _create_item_card()
		var f_name = fish.get("name", "魚")
		var f_len = fish.get("length", 20.0)
		var f_weight = fish.get("weight", 0.3)
		var f_price = fish.get("price", 20)
		var f_sci = fish.get("scientific_name", "")
		
		var title_txt = "🐟 %s (%0.1fcm / %0.2fkg)" % [f_name, f_len, f_weight]
		var sub_txt = "学名: %s   生息地: %s" % [f_sci, fish.get("habitat", "野北海岸")]
		var desc_txt = fish.get("desc", "")
		
		_setup_card_info(card, title_txt, sub_txt, desc_txt)
		
		var btn_container = card.get_node("HBox/ActionVBox")
		var sell_btn = Button.new()
		GameData.apply_pastel_button_style(sell_btn)
		sell_btn.text = "売る: +%d G" % f_price
		var fish_idx = i
		sell_btn.pressed.connect(func():
			GameData.sell_fish_at(fish_idx)
			_refresh_current_tab()
		)
		btn_container.add_child(sell_btn)
		
		item_vbox.add_child(card)

func _on_sell_all_pressed() -> void:
	if not GameData: return
	var total = GameData.sell_all_fish()
	if total > 0:
		_refresh_current_tab()

# --- カードUI共通生成ヘルパー ---
func _create_item_card() -> PanelContainer:
	var pc = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.18, 0.24, 0.92)
	style.border_color = Color(0.35, 0.45, 0.55, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 16)
	pc.add_child(hbox)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.name = "InfoVBox"
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var act_vbox = VBoxContainer.new()
	act_vbox.name = "ActionVBox"
	act_vbox.custom_minimum_size = Vector2(150, 0)
	act_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	act_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(act_vbox)
	
	return pc

func _setup_card_info(card: PanelContainer, title: String, sub: String, desc: String) -> void:
	var info_vbox = card.get_node("HBox/InfoVBox")
	
	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.add_theme_font_size_override("font_size", 16)
	t_lbl.add_theme_color_override("font_color", Color(0.98, 0.92, 0.75))
	info_vbox.add_child(t_lbl)
	
	var s_lbl = Label.new()
	s_lbl.text = sub
	s_lbl.add_theme_font_size_override("font_size", 12)
	s_lbl.add_theme_color_override("font_color", Color(0.45, 0.82, 0.95))
	info_vbox.add_child(s_lbl)
	
	var d_lbl = Label.new()
	d_lbl.text = desc
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_lbl.add_theme_font_size_override("font_size", 11)
	d_lbl.add_theme_color_override("font_color", Color(0.80, 0.84, 0.88, 0.9))
	info_vbox.add_child(d_lbl)

func _setup_card_actions(card: PanelContainer, price: int, is_unlocked: bool, is_equipped: bool, on_buy: Callable, on_equip: Callable) -> void:
	var act_vbox = card.get_node("HBox/ActionVBox")
	
	if not is_unlocked:
		var buy_btn = Button.new()
		GameData.apply_pastel_button_style(buy_btn)
		buy_btn.text = "購入: %d G" % price
		buy_btn.disabled = (GameData.coins < price)
		buy_btn.pressed.connect(on_buy)
		act_vbox.add_child(buy_btn)
	else:
		var equip_btn = Button.new()
		GameData.apply_pastel_button_style(equip_btn)
		if is_equipped:
			equip_btn.text = "✔ 装備中"
			equip_btn.disabled = true
			equip_btn.modulate = Color(0.4, 1.0, 0.5)
		else:
			equip_btn.text = "装備する"
			equip_btn.pressed.connect(on_equip)
		act_vbox.add_child(equip_btn)
