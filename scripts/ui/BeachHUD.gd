extends Control

# 福岡・糸島 野北フィッシング HUD（動画の質感・透明感を再現したモダンUI）

signal open_shop_requested()
signal open_book_requested()
signal save_game_requested()
signal title_requested()

# 左下 UI
@onready var bait_circle: PanelContainer = $BottomLeft/BaitContainer/BaitCircle
@onready var bait_count_label: Label = $BottomLeft/BaitContainer/BaitCircle/Badge/CountLabel
@onready var bait_icon_rect: TextureRect = $BottomLeft/BaitContainer/BaitCircle/BaitIcon
@onready var btn_switch_bait: Button = $BottomLeft/BaitContainer/BtnSwitchBait

# 右上 クエストカード
@onready var quest_card: PanelContainer = $TopRight/QuestCard
@onready var btn_view_fish: Button = $TopRight/QuestCard/VBox/HBoxQuest/BtnViewFish
@onready var check_box_label: Label = $TopRight/QuestCard/VBox/HBoxQuest/CheckLabel

# 右下 宝箱・インベントリ
@onready var btn_chest: Button = $BottomRight/HBox/ChestContainer/BtnChest
@onready var chest_alert_badge: Control = $BottomRight/HBox/ChestContainer/AlertBadge

# 上部ステータス（通知・セーブ表示用ポップ）
@onready var notification_label: Label = $TopCenter/NotificationCard/NotificationLabel
@onready var notification_card: PanelContainer = $TopCenter/NotificationCard
var notif_timer: float = 0.0

func _ready() -> void:
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
		
	if btn_switch_bait:
		btn_switch_bait.pressed.connect(_cycle_bait)
		
	GameData.coins_changed.connect(func(_val): update_ui())
	GameData.inventory_changed.connect(func(): update_ui())
	GameData.equipment_changed.connect(func(): update_ui())
	GameData.book_updated.connect(func(_sp, _f, _r): update_ui())
	GameData.game_saved.connect(_on_game_saved)
	
	if notification_card:
		notification_card.visible = false
	update_ui()
	queue_redraw()

func _draw() -> void:
	# 動画完全再現：左下のアクションガイドアイコン群
	# 1. ウキプレビュー（BaitCircleの右横に直立する赤白棒ウキ）
	var bobber_base = Vector2(118, size.y - 55)
	draw_line(bobber_base - Vector2(0, 36), bobber_base, Color(0.15, 0.15, 0.15, 0.85), 2.0) # 黒軸
	draw_rect(Rect2(bobber_base.x - 3.5, bobber_base.y - 36, 7, 12), Color("#d90429"), true)   # 赤トップ
	draw_rect(Rect2(bobber_base.x - 3.5, bobber_base.y - 24, 7, 12), Color("#ffffff"), true)   # 白ボディ
	# 下の極細針ライン
	draw_line(bobber_base, bobber_base + Vector2(0, 16), Color(0.45, 0.45, 0.45, 0.75), 1.0)
	draw_arc(bobber_base + Vector2(4, 16), 4.0, 0, PI, 8, Color(0.45, 0.45, 0.45, 0.75), 1.2)

	# 2. マウス左（動画：縦長楕円、左ボタンが赤）
	var ml_center = Vector2(188, size.y - 48)
	draw_ellipse(ml_center, 9.0, 13.0, Color(0.86, 0.83, 0.78, 0.95))
	draw_arc(ml_center, 9.0, 0, TAU, 16, Color(0.35, 0.32, 0.27, 1.0), 1.5)
	# 中心線
	draw_line(ml_center - Vector2(0, 12), ml_center + Vector2(0, 12), Color(0.35, 0.32, 0.27, 0.7), 1.0)
	draw_line(ml_center - Vector2(9, 0), ml_center + Vector2(9, 0), Color(0.35, 0.32, 0.27, 0.7), 1.0)
	# 左ボタンが鮮やかな赤
	draw_circle(ml_center + Vector2(-4, -6), 3.5, Color("#e63946"))

	# 3. 針ボタン（薄ベージュ丸スロット、中に針マーク）
	var hook_center = Vector2(224, size.y - 48)
	draw_circle(hook_center, 14.0, Color(0.86, 0.83, 0.78, 0.95))
	draw_arc(hook_center, 14.0, 0, TAU, 20, Color(0.35, 0.32, 0.27, 1.0), 1.5)
	# 針マーク
	draw_line(hook_center + Vector2(0, -7), hook_center + Vector2(0, 4), Color(0.35, 0.32, 0.27, 0.9), 2.0)
	draw_arc(hook_center + Vector2(3.5, 4), 3.5, 0, PI, 8, Color(0.35, 0.32, 0.27, 0.9), 2.0)

	# 4. マウス右（動画：丸枠で囲まれた縦長楕円、右ボタンが赤）
	var mr_center = Vector2(272, size.y - 48)
	draw_circle(mr_center, 15.0, Color(0.86, 0.83, 0.78, 0.35))
	draw_arc(mr_center, 15.0, 0, TAU, 24, Color(0.35, 0.32, 0.27, 0.9), 1.5)
	draw_ellipse(mr_center, 8.0, 11.0, Color(0.86, 0.83, 0.78, 0.95))
	draw_arc(mr_center, 8.0, 0, TAU, 16, Color(0.35, 0.32, 0.27, 0.85), 1.2)
	# 中心線
	draw_line(mr_center - Vector2(0, 10), mr_center + Vector2(0, 10), Color(0.35, 0.32, 0.27, 0.6), 1.0)
	draw_line(mr_center - Vector2(8, 0), mr_center + Vector2(8, 0), Color(0.35, 0.32, 0.27, 0.6), 1.0)
	# 右ボタンが鮮やかな赤
	draw_circle(mr_center + Vector2(3.5, -5), 3.0, Color("#e63946"))

	# 5. 麦わら帽子丸ボタン（丸スロット、中に麦わら帽子マーク）
	var hat_center = Vector2(310, size.y - 48)
	draw_circle(hat_center, 14.0, Color(0.86, 0.83, 0.78, 0.95))
	draw_arc(hat_center, 14.0, 0, TAU, 20, Color(0.35, 0.32, 0.27, 1.0), 1.5)
	# 帽子
	draw_ellipse(hat_center + Vector2(0, 2), 9.0, 4.0, Color("#c99a6b"))
	draw_rect(Rect2(hat_center.x - 5, hat_center.y - 5, 10, 5), Color("#c99a6b"), true)
	draw_line(hat_center + Vector2(-5, -1), hat_center + Vector2(5, -1), Color("#264653"), 1.8)

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
		elif event.keycode == KEY_E:
			_cycle_bait()
			get_viewport().set_input_as_handled()

func _cycle_bait() -> void:
	var bait_keys = ["isome", "okiami", "mussel", "shrimp", "lure"]
	var cur_idx = bait_keys.find(GameData.current_bait)
	if cur_idx < 0:
		cur_idx = 0
		
	for i in range(1, bait_keys.size() + 1):
		var next_key = bait_keys[(cur_idx + i) % bait_keys.size()]
		if GameData.bait_counts.get(next_key, 0) > 0:
			GameData.equip_bait(next_key)
			var b_name = GameData.BAITS.get(next_key, {}).get("name", next_key)
			show_notification("エサを【" + b_name + "】に変更しました")
			return
			
	show_notification("他のエサがありません（よろず屋で購入できます）")

func update_ui() -> void:
	# 1. エサの表示更新
	var bait_id = GameData.current_bait
	var b_count = GameData.bait_counts.get(bait_id, 0)
	var b_name = GameData.BAITS.get(bait_id, {}).get("name", "アオイソメ")
	
	if bait_count_label:
		bait_count_label.text = str(b_count)
	if btn_switch_bait:
		btn_switch_bait.text = b_name
		
	# エサアイコン更新
	if bait_icon_rect:
		var tex = GameData.load_texture("res://assets/" + bait_id + "_bait.png")
		if not tex:
			tex = GameData.load_texture("res://assets/mussel_bait.png")
		bait_icon_rect.texture = tex
		
	# 2. 宝箱のアラートバッジ（動画では常に赤い「!」バッジが表示されている）
	if chest_alert_badge:
		chest_alert_badge.visible = true
		
	# 3. クエストカードの進捗（動画完全一致：[ ] 釣った魚を見る）
	if check_box_label:
		if GameData.inventory.size() > 0:
			check_box_label.text = "[v] 釣った魚を見る"
		else:
			check_box_label.text = "□ 釣った魚を見る"

func show_notification(text: String, duration: float = 2.5) -> void:
	if notification_label:
		notification_label.text = text
	if notification_card:
		notification_card.modulate.a = 1.0
	notif_timer = duration

func _on_game_saved() -> void:
	show_notification("セーブ完了！玄界灘の釣果記録を保存しました")

func _on_save_button_pressed() -> void:
	SoundManager.play_sfx("coin", 0.05, 1.5)
	GameData.save_game()
	save_game_requested.emit()

func set_status(text: String, _is_alert: bool = false) -> void:
	show_notification(text, 3.0)
