extends Control

# ゲーム画面上部のHUD（コイン、ステータス、操作ガイド、ショップボタン）

signal open_shop_requested()

@onready var coin_label: Label = $TopBar/HBox/CoinContainer/CoinLabel
@onready var spot_label: Label = $TopBar/HBox/SpotContainer/SpotLabel
@onready var equip_label: Label = $TopBar/HBox/EquipContainer/EquipLabel
@onready var bag_label: Label = $TopBar/HBox/BagContainer/BagLabel
@onready var guide_label: Label = $GuideLabel
@onready var shop_button: Button = $TopBar/HBox/ShopButton

func _ready() -> void:
	shop_button.pressed.connect(func(): open_shop_requested.emit())
	
	GameData.coins_changed.connect(_on_coins_changed)
	GameData.spot_changed.connect(_on_spot_changed)
	GameData.equipment_changed.connect(_on_equipment_changed)
	GameData.inventory_changed.connect(_on_inventory_changed)
	
	refresh_all()

func refresh_all() -> void:
	_on_coins_changed(GameData.coins)
	_on_spot_changed(GameData.current_spot)
	_on_equipment_changed()
	_on_inventory_changed()

func _on_coins_changed(amount: int) -> void:
	if coin_label:
		coin_label.text = "💰 " + str(amount) + " G"

func _on_spot_changed(spot_id: String) -> void:
	if spot_label:
		var spot = GameData.SPOTS.get(spot_id, {})
		spot_label.text = "📍 " + spot.get("name", "釣り場")

func _on_equipment_changed() -> void:
	if equip_label:
		var rod = GameData.RODS.get(GameData.current_rod, {})
		var bait = GameData.BAITS.get(GameData.current_bait, {})
		var bait_count = GameData.bait_counts.get(GameData.current_bait, 0)
		equip_label.text = "🎣 " + rod.get("name", "竿") + "  |  🪱 " + bait.get("name", "エサ") + ": " + str(bait_count) + "個"

func _on_inventory_changed() -> void:
	if bag_label:
		bag_label.text = "🪣 " + str(GameData.inventory.size()) + "匹"

func set_guide(text: String) -> void:
	if guide_label:
		guide_label.text = text
