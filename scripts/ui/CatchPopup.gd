extends Control

# 魚を釣り上げた時の演出ダイアログ

signal dismissed()

@onready var icon_label: Label = $Panel/VBox/FishIcon
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var size_label: Label = $Panel/VBox/SizeLabel
@onready var rarity_label: Label = $Panel/VBox/RarityLabel
@onready var desc_label: Label = $Panel/VBox/DescLabel
@onready var price_label: Label = $Panel/VBox/PriceLabel
@onready var confirm_btn: Button = $Panel/VBox/ConfirmBtn

func _ready() -> void:
	visible = false
	confirm_btn.pressed.connect(_on_confirm)

func show_catch(fish: Dictionary) -> void:
	visible = true
	icon_label.text = fish.get("icon", "🐟")
	title_label.text = fish.get("name", "謎の魚")
	size_label.text = "サイズ: " + str(fish.get("size", 10.0)) + " cm"
	
	var rarity = fish.get("rarity", "Common")
	rarity_label.text = "レア度: " + rarity
	match rarity:
		"Common":
			rarity_label.modulate = Color("a8dadc")
		"Rare":
			rarity_label.modulate = Color("457b9d")
		"Epic":
			rarity_label.modulate = Color("9d4edd")
		"Legendary":
			rarity_label.modulate = Color("ffb703")
			
	desc_label.text = fish.get("desc", "のんびり泳ぐ魚。")
	price_label.text = "想定売却額: +" + str(fish.get("price", 10)) + " G"

func _on_confirm() -> void:
	visible = false
	dismissed.emit()
