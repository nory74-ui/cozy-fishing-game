extends Control

# 南国ビーチ風 HUD（動画「I Just Wanted to Fish」完全再現UI）

signal open_shop_requested()
signal open_book_requested()
signal save_game_requested()
signal title_requested()

# 左下 UI
@onready var bait_circle: PanelContainer = $BottomLeft/HBox/BaitContainer/BaitCircle
@onready var bait_count_label: Label = $BottomLeft/HBox/BaitContainer/BaitCircle/Badge/CountLabel
@onready var bait_icon_rect: TextureRect = $BottomLeft/HBox/BaitContainer/BaitCircle/BaitIcon
@onready var bait_name_label: Label = $BottomLeft/HBox/BaitContainer/NameLabel

# 右上 クエストカード
@onready var quest_card: PanelContainer = $TopRight/QuestCard
@onready var btn_view_fish: Button = $TopRight/QuestCard/VBox/HBoxQuest/BtnViewFish
@onready var check_box_label: Label = $TopRight/QuestCard/VBox/HBoxQuest/CheckLabel
@onready var btn_save: Button = $TopRight/QuestCard/VBox/HBoxSys/BtnSave
@onready var btn_title: Button = $TopRight/QuestCard/VBox/HBoxSys/BtnTitle

# 右下 宝箱・インベントリ
@onready var btn_chest: Button = $BottomRight/HBox/ChestContainer/BtnChest
@onready var chest_alert_badge: Control = $BottomRight/HBox/ChestContainer/AlertBadge

# 上部ステータス（通知・セーブ表示用ポップ）
@onready var notification_label: Label = $TopCenter/NotificationCard/NotificationLabel
@onready var notification_card: PanelContainer = $TopCenter/NotificationCard
var notif_timer: float = 0.0

func _ready() -> void:
	if bait_icon_rect:
		bait_icon_rect.texture = GameData.load_texture("res://assets/mussel_bait.png")
	var chest_rect = get_node_or_null("BottomRight/HBox/ChestContainer/BtnChest/TextureRect")
	if chest_rect:
		chest_rect.texture = GameData.load_texture("res://assets/chest_icon.png")

	if btn_view_fish:
		btn_view_fish.pressed.connect(func():
			SoundManager.play_sfx("book")
			open_book_requested.emit()
		)
		
	if btn_chest:
		btn_chest.pressed.connect(func():
			SoundManager.play_sfx("coin")
			open_shop_requested.emit()
		)
		
	if btn_save:
		btn_save.pressed.connect(_on_save_button_pressed)
		
	if btn_title:
		btn_title.pressed.connect(func():
			GameData.save_game()
			title_requested.emit()
		)
		
	GameData.coins_changed.connect(func(_val): update_ui())
	GameData.inventory_changed.connect(func(): update_ui())
	GameData.equipment_changed.connect(func(): update_ui())
	GameData.book_updated.connect(func(_sp, _f, _r): update_ui())
	GameData.game_saved.connect(_on_game_saved)
	
	notification_card.modulate.a = 0.0
	update_ui()

func _process(delta: float) -> void:
	if notif_timer > 0.0:
		notif_timer -= delta
		if notif_timer <= 0.0:
			var tw = create_tween()
			tw.tween_property(notification_card, "modulate:a", 0.0, 0.4)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			SoundManager.play_sfx("book")
			open_book_requested.emit()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_K:
			SoundManager.play_sfx("coin")
			open_shop_requested.emit()
			get_viewport().set_input_as_handled()

func update_ui() -> void:
	# 1. エサの表示更新
	var bait_id = GameData.current_bait
	var b_count = GameData.bait_counts.get(bait_id, 0)
	var b_name = GameData.BAITS.get(bait_id, {}).get("name", "ムール貝")
	
	if bait_count_label:
		bait_count_label.text = str(b_count)
	if bait_name_label:
		bait_name_label.text = b_name
		
	# 2. 宝箱のアラートバッジ（釣った魚がある場合やお金がある場合に点灯）
	if chest_alert_badge:
		chest_alert_badge.visible = GameData.inventory.size() > 0
		
	# 3. クエストカードの進捗
	if check_box_label:
		if GameData.inventory.size() > 0:
			check_box_label.text = "[v] 釣った魚を見る (" + str(GameData.inventory.size()) + "匹)"
		else:
			check_box_label.text = "[  ] 釣った魚を見る (0匹)"

func show_notification(text: String, duration: float = 2.5) -> void:
	if notification_label:
		notification_label.text = text
	if notification_card:
		notification_card.modulate.a = 1.0
	notif_timer = duration

func _on_game_saved() -> void:
	show_notification("セーブ完了！冒険の記録を保存しました")

func _on_save_button_pressed() -> void:
	SoundManager.play_sfx("coin", 0.05, 1.5)
	GameData.save_game()
	save_game_requested.emit()

func set_status(text: String, is_alert: bool = false) -> void:
	show_notification(text, 3.0)
