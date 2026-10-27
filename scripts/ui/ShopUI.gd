extends Control

# ショップ画面（魚売却、釣り竿、エサ、釣り場の購入・切り替え）

signal closed()

@onready var tab_sell: Button = $Panel/TabHBox/BtnSell
@onready var tab_rods: Button = $Panel/TabHBox/BtnRods
@onready var tab_baits: Button = $Panel/TabHBox/BtnBaits
@onready var tab_spots: Button = $Panel/TabHBox/BtnSpots
@onready var close_btn: Button = $Panel/CloseBtn

@onready var content_list: VBoxContainer = $Panel/ScrollContainer/ContentList
@onready var status_label: Label = $Panel/BottomBar/StatusLabel
@onready var action_all_btn: Button = $Panel/BottomBar/ActionAllBtn

enum Tab { SELL, RODS, BAITS, SPOTS }
var current_tab: Tab = Tab.SELL

func _ready() -> void:
	tab_sell.pressed.connect(func(): switch_tab(Tab.SELL))
	tab_rods.pressed.connect(func(): switch_tab(Tab.RODS))
	tab_baits.pressed.connect(func(): switch_tab(Tab.BAITS))
	tab_spots.pressed.connect(func(): switch_tab(Tab.SPOTS))
	close_btn.pressed.connect(_on_close)
	action_all_btn.pressed.connect(_on_action_all)
	
	GameData.coins_changed.connect(func(_val): _refresh_ui())
	GameData.inventory_changed.connect(func(): _refresh_ui())
	GameData.equipment_changed.connect(func(): _refresh_ui())

func open() -> void:
	visible = true
	switch_tab(Tab.SELL)

func _on_close() -> void:
	visible = false
	closed.emit()

func switch_tab(tab: Tab) -> void:
	current_tab = tab
	tab_sell.button_pressed = (tab == Tab.SELL)
	tab_rods.button_pressed = (tab == Tab.RODS)
	tab_baits.button_pressed = (tab == Tab.BAITS)
	tab_spots.button_pressed = (tab == Tab.SPOTS)
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
		Tab.RODS:
			_render_rods_tab()
		Tab.BAITS:
			_render_baits_tab()
		Tab.SPOTS:
			_render_spots_tab()

# --- 1. 魚売却タブ ---
func _render_sell_tab() -> void:
	var total_value = 0
	for fish in GameData.inventory:
		total_value += fish.get("price", 10)
	
	action_all_btn.visible = true
	action_all_btn.text = "すべての魚を売却 (+" + str(total_value) + " G)"
	action_all_btn.disabled = (GameData.inventory.size() == 0)
	status_label.text = "所持金: " + str(GameData.coins) + " G | バケツの中: " + str(GameData.inventory.size()) + " 匹"

	if GameData.inventory.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "バケツは空っぽです。魚を釣って持ってこよう！"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_list.add_child(empty_lbl)
		return

	for i in range(GameData.inventory.size()):
		var fish = GameData.inventory[i]
		var item_panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		
		var icon_lbl = Label.new()
		icon_lbl.text = fish.get("name", "魚") + " (" + str(fish.get("size", 10.0)) + "cm)"
		icon_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(icon_lbl)
		
		var rarity_lbl = Label.new()
		rarity_lbl.text = "[" + fish.get("rarity", "Common") + "]"
		rarity_lbl.custom_minimum_size = Vector2(80, 0)
		hbox.add_child(rarity_lbl)
		
		var price_lbl = Label.new()
		var price = fish.get("price", 10)
		price_lbl.text = "+" + str(price) + " G"
		price_lbl.custom_minimum_size = Vector2(80, 0)
		hbox.add_child(price_lbl)
		
		var sell_btn = Button.new()
		sell_btn.text = "売る"
		var idx = i
		sell_btn.pressed.connect(func(): GameData.sell_fish_at(idx))
		hbox.add_child(sell_btn)
		
		item_panel.add_child(hbox)
		content_list.add_child(item_panel)

# --- 2. 釣り竿タブ ---
func _render_rods_tab() -> void:
	action_all_btn.visible = false
	status_label.text = "所持金: " + str(GameData.coins) + " G | 性能の高い竿ほど巻き上げ力と安定度が上がります。"
	
	for rod_key in ["branch_rod", "bamboo_rod", "carbon_rod", "master_rod"]:
		var rod = GameData.RODS.get(rod_key)
		var is_unlocked = rod_key in GameData.unlocked_rods
		var is_equipped = (GameData.current_rod == rod_key)
		
		var item_panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_lbl = Label.new()
		title_lbl.text = rod.name + (" (装備中)" if is_equipped else "")
		var desc_lbl = Label.new()
		desc_lbl.text = rod.desc + " [パワー: x" + str(rod.power) + ", 安定度: x" + str(rod.stability) + "]"
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		vbox.add_child(title_lbl)
		vbox.add_child(desc_lbl)
		hbox.add_child(vbox)
		
		var btn = Button.new()
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

# --- 3. エサタブ ---
func _render_baits_tab() -> void:
	action_all_btn.visible = false
	status_label.text = "所持金: " + str(GameData.coins) + " G | エサが良いほど珍しい魚や大物がかかりやすくなります。"
	
	for bait_key in ["worm", "dumpling", "lure"]:
		var bait = GameData.BAITS.get(bait_key)
		var count = GameData.bait_counts.get(bait_key, 0)
		var is_equipped = (GameData.current_bait == bait_key)
		
		var item_panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_lbl = Label.new()
		title_lbl.text = bait.name + " (所持: " + str(count) + "個)" + (" [選択中]" if is_equipped else "")
		var desc_lbl = Label.new()
		desc_lbl.text = bait.desc + " [レア度補正: x" + str(bait.rare_boost) + "]"
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		vbox.add_child(title_lbl)
		vbox.add_child(desc_lbl)
		hbox.add_child(vbox)
		
		if not is_equipped and count > 0:
			var equip_btn = Button.new()
			equip_btn.text = "使う"
			equip_btn.pressed.connect(func(): GameData.equip_bait(bait_key))
			hbox.add_child(equip_btn)
			
		var buy_btn = Button.new()
		buy_btn.text = str(bait.pack_amount) + "個買う (" + str(bait.price) + " G)"
		buy_btn.disabled = (GameData.coins < bait.price)
		buy_btn.pressed.connect(func(): GameData.buy_bait(bait_key))
		hbox.add_child(buy_btn)
		
		item_panel.add_child(hbox)
		content_list.add_child(item_panel)

# --- 4. 釣り場解放タブ ---
func _render_spots_tab() -> void:
	action_all_btn.visible = false
	status_label.text = "所持金: " + str(GameData.coins) + " G | 新しい釣り場を解放して未知の魚に出会おう！"
	
	for spot_key in ["stream", "pond", "lake"]:
		var spot = GameData.SPOTS.get(spot_key)
		var is_unlocked = spot_key in GameData.unlocked_spots
		var is_current = (GameData.current_spot == spot_key)
		
		var item_panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_lbl = Label.new()
		title_lbl.text = spot.name + (" (現在の場所)" if is_current else "")
		var desc_lbl = Label.new()
		desc_lbl.text = spot.desc
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		vbox.add_child(title_lbl)
		vbox.add_child(desc_lbl)
		hbox.add_child(vbox)
		
		var btn = Button.new()
		if is_current:
			btn.text = "滞在中"
			btn.disabled = true
		elif is_unlocked:
			btn.text = "移動する"
			btn.pressed.connect(func():
				GameData.change_spot(spot_key)
				_on_close()
			)
		else:
			btn.text = "解放する (" + str(spot.price) + " G)"
			btn.disabled = (GameData.coins < spot.price)
			btn.pressed.connect(func():
				if GameData.unlock_spot(spot_key):
					_on_close()
			)
		hbox.add_child(btn)
		
		item_panel.add_child(hbox)
		content_list.add_child(item_panel)

func _on_action_all() -> void:
	if current_tab == Tab.SELL:
		GameData.sell_all_fish()
