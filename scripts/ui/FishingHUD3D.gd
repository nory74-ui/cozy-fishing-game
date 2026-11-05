extends CanvasLayer
class_name FishingHUD3D

# --- 3D釣り専用HUD（キャストゲージ・ファイト・学術的釣果ポップアップ） ---

signal reel_button_pressed
signal reel_button_released
signal catch_dialog_closed
signal book_open_requested
signal shop_open_requested
signal time_jump_requested
signal time_speed_cycle_requested
signal time_speed_step_requested(delta_step: int)

@onready var cast_gauge_container: Control = $CastGaugeContainer
@onready var cast_power_bar: ProgressBar = $CastGaugeContainer/CastPowerBar
@onready var cast_label: Label = get_node_or_null("CastGaugeContainer/Label")
var status_toast_label: Label = null
var toast_tween: Tween = null

@onready var fight_container: Control = $FightContainer
@onready var tension_bar: ProgressBar = $FightContainer/TensionBar
@onready var distance_label: Label = $FightContainer/DistanceLabel
@onready var fish_name_fight_label: Label = $FightContainer/FishNameFightLabel
@onready var tension_alert_label: Label = $FightContainer/TensionAlertLabel
@onready var reel_prompt_label: Label = $FightContainer/ReelPromptLabel

@onready var hit_indicator: Label = $HitIndicator
@onready var result_dialog: PanelContainer = $ResultDialog
@onready var result_title: Label = $ResultDialog/VBox/FishTitle
@onready var scientific_name_label: Label = $ResultDialog/VBox/SubTitleHBox/ScientificName
@onready var rarity_badge_label: Label = $ResultDialog/VBox/SubTitleHBox/RarityBadge
@onready var record_badge_label: Label = $ResultDialog/VBox/SubTitleHBox/RecordBadge
@onready var result_icon: TextureRect = $ResultDialog/VBox/FishIcon
@onready var result_stats: Label = $ResultDialog/VBox/FishStats
@onready var result_habitat: Label = $ResultDialog/VBox/HabitatLabel
@onready var result_desc: Label = $ResultDialog/VBox/FishDesc

@onready var btn_sell_now: Button = get_node_or_null("ResultDialog/VBox/ResultActionHBox/BtnSellNow")
@onready var btn_keep_fish: Button = get_node_or_null("ResultDialog/VBox/ResultActionHBox/BtnKeepFish")

@onready var coins_label: Label = get_node_or_null("CoinsDisplay/CoinsLabel")
@onready var autopilot_label: Label = $AutopilotLabel
@onready var btn_time_of_day: Button = get_node_or_null("TimeControlContainer/BtnTimeOfDay")
@onready var btn_speed_down: Button = get_node_or_null("TimeControlContainer/BtnSpeedDown")
@onready var btn_time_speed: Button = get_node_or_null("TimeControlContainer/BtnTimeSpeed")
@onready var btn_speed_up: Button = get_node_or_null("TimeControlContainer/BtnSpeedUp")
@onready var btn_open_shop: Button = get_node_or_null("BtnOpenShop")
@onready var btn_open_book: Button = $BtnOpenBook
@onready var btn_to_title: Button = $BtnToTitle

@onready var equipment_bar: PanelContainer = get_node_or_null("EquipmentBar")
@onready var equip_rod_label: Label = get_node_or_null("EquipmentBar/HBox/EquipRodLabel")
@onready var equip_line_label: Label = get_node_or_null("EquipmentBar/HBox/EquipLineLabel")
@onready var equip_reel_label: Label = get_node_or_null("EquipmentBar/HBox/EquipReelLabel")
@onready var equip_bait_label: Label = get_node_or_null("EquipmentBar/HBox/EquipBaitLabel")

var current_caught_fish: Dictionary = {}

func _ready() -> void:
	cast_gauge_container.visible = false
	fight_container.visible = false
	hit_indicator.visible = false
	result_dialog.visible = false
	if autopilot_label:
		autopilot_label.visible = false

	# スタイル設定
	if GameData:
		GameData.coins_changed.connect(_on_coins_changed)
		GameData.equipment_changed.connect(_update_equipment_display)
		_on_coins_changed(GameData.coins)
		_update_equipment_display()

	if btn_sell_now and GameData:
		GameData.apply_pastel_button_style(btn_sell_now)
		btn_sell_now.pressed.connect(_on_sell_now_pressed)
	if btn_keep_fish and GameData:
		GameData.apply_pastel_button_style(btn_keep_fish)
		btn_keep_fish.pressed.connect(hide_catch_result)

	status_toast_label = Label.new()
	status_toast_label.name = "StatusToastLabel"
	status_toast_label.anchors_preset = Control.PRESET_CENTER_TOP
	status_toast_label.anchor_left = 0.5
	status_toast_label.anchor_right = 0.5
	status_toast_label.offset_left = -300.0
	status_toast_label.offset_right = 300.0
	status_toast_label.offset_top = 72.0
	status_toast_label.offset_bottom = 110.0
	status_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_toast_label.add_theme_font_size_override("font_size", 17)
	status_toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	status_toast_label.add_theme_constant_override("outline_size", 5)
	status_toast_label.visible = false
	add_child(status_toast_label)

	for b in [btn_time_of_day, btn_speed_down, btn_time_speed, btn_speed_up, btn_open_shop, btn_open_book, btn_to_title]:
		if b and GameData:
			GameData.apply_pastel_button_style(b)

	if btn_time_of_day:
		btn_time_of_day.focus_mode = Control.FOCUS_NONE
		btn_time_of_day.pressed.connect(func(): time_jump_requested.emit())
	if btn_speed_down:
		btn_speed_down.focus_mode = Control.FOCUS_NONE
		btn_speed_down.pressed.connect(func(): time_speed_step_requested.emit(-1))
	if btn_time_speed:
		btn_time_speed.focus_mode = Control.FOCUS_NONE
		btn_time_speed.pressed.connect(func(): time_speed_cycle_requested.emit())
	if btn_speed_up:
		btn_speed_up.focus_mode = Control.FOCUS_NONE
		btn_speed_up.pressed.connect(func(): time_speed_step_requested.emit(1))

	if btn_open_shop:
		btn_open_shop.focus_mode = Control.FOCUS_NONE
		btn_open_shop.pressed.connect(func(): shop_open_requested.emit())

	if btn_open_book:
		btn_open_book.focus_mode = Control.FOCUS_NONE
		btn_open_book.pressed.connect(func(): book_open_requested.emit())

	if btn_to_title:
		btn_to_title.focus_mode = Control.FOCUS_NONE
		btn_to_title.pressed.connect(func():
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		)

	# 装備バースタイル
	if equipment_bar:
		var st_bar = StyleBoxFlat.new()
		st_bar.bg_color = Color(0.10, 0.13, 0.18, 0.88)
		st_bar.border_color = Color(0.40, 0.48, 0.58, 0.75)
		st_bar.set_border_width_all(1)
		st_bar.set_corner_radius_all(8)
		st_bar.content_margin_left = 16
		st_bar.content_margin_right = 16
		st_bar.content_margin_top = 8
		st_bar.content_margin_bottom = 8
		equipment_bar.add_theme_stylebox_override("panel", st_bar)

func _on_coins_changed(new_amount: int) -> void:
	if coins_label:
		coins_label.text = "所持金: %d G" % new_amount

func _update_equipment_display() -> void:
	if not GameData: return
	var rod = GameData.RODS.get(GameData.current_rod, {})
	var line = GameData.LINES.get(GameData.current_line, {})
	var reel = GameData.REELS.get(GameData.current_reel, {})
	var bait = GameData.BAITS.get(GameData.current_bait, {})
	var count = GameData.bait_counts.get(GameData.current_bait, 0)
	var is_inf = bait.get("is_infinite", false)

	if equip_rod_label:
		equip_rod_label.text = "竿: %s (R%d)" % [rod.get("name", "のべ竿"), rod.get("rank", 1)]
	if equip_line_label:
		equip_line_label.text = "糸: %s" % line.get("name", "ナイロン1.5号")
	if equip_reel_label:
		equip_reel_label.text = "リール: %s" % reel.get("name", "入門1000番")
	if equip_bait_label:
		var cnt_str = "∞" if is_inf else str(count)
		equip_bait_label.text = "エサ: %s (%s)" % [bait.get("name", "エサ"), cnt_str]

func update_time_display(time_of_day: float, speed_mult: float) -> void:
	if btn_time_of_day:
		var total_hours = fmod((time_of_day * 24.0) + 6.0, 24.0)
		var hh = int(total_hours)
		var mm = int((total_hours - hh) * 60.0)
		var icon_label = "【昼】"
		if hh >= 5 and hh < 9:
			icon_label = "【朝】"
		elif hh >= 9 and hh < 16:
			icon_label = "【昼】"
		elif hh >= 16 and hh < 19:
			icon_label = "【夕】"
		else:
			icon_label = "【夜】"
		btn_time_of_day.text = "%s%02d:%02d [T]" % [icon_label, hh, mm]
	if btn_time_speed:
		if speed_mult <= 0.0:
			btn_time_speed.text = "速度: 停止 [V]"
		elif is_equal_approx(speed_mult, round(speed_mult)):
			btn_time_speed.text = "速度: %dx [V]" % int(round(speed_mult))
		else:
			btn_time_speed.text = "速度: %sx [V]" % str(speed_mult)

func _unhandled_input(event: InputEvent) -> void:
	if result_dialog and result_dialog.visible:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE)):
			hide_catch_result()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B or event.keycode == KEY_J:
			book_open_requested.emit()
		elif event.keycode == KEY_U:
			shop_open_requested.emit()
		elif event.keycode == KEY_1:
			_switch_bait_by_key("okiami")
		elif event.keycode == KEY_2:
			_switch_bait_by_key("isome")
		elif event.keycode == KEY_3:
			_switch_bait_by_key("crab_bait")
		elif event.keycode == KEY_4:
			_switch_bait_by_key("live_fish")
		elif event.keycode == KEY_5:
			_switch_bait_by_key("lure")

func _switch_bait_by_key(bait_id: String) -> void:
	if not GameData: return
	var b_data = GameData.BAITS.get(bait_id, {})
	var b_name = b_data.get("name", bait_id)
	var count = GameData.bait_counts.get(bait_id, 0)
	if count > 0 or b_data.get("is_infinite", false):
		GameData.equip_bait(bait_id)
		show_status_toast("◆ エサを「%s」に切り替えました" % b_name, Color(0.7, 1.0, 0.8), 1.8)
	else:
		show_status_toast("【所持数0】%s を持っていません！ [U]キーの釣具店で購入できます" % b_name, Color(1.0, 0.45, 0.35), 2.4)

# キャストパワーゲージ
func show_cast_gauge(power_ratio: float) -> void:
	cast_gauge_container.visible = true
	cast_power_bar.value = power_ratio * 100.0
	if cast_label:
		var pct = int(round(power_ratio * 100.0))
		var zone_str = "ちょい投げ（手前・浅瀬）"
		if power_ratio >= 0.72:
			zone_str = "フル遠投（沖合・大物狙い！）"
		elif power_ratio >= 0.35:
			zone_str = "中投げ（藻場・沈み瀬）"
		cast_label.text = "CAST POWER: %d%% 【%s】" % [pct, zone_str]

func hide_cast_gauge() -> void:
	cast_gauge_container.visible = false

func show_status_toast(msg: String, color: Color = Color(1.0, 0.95, 0.65), duration: float = 2.4) -> void:
	if not status_toast_label:
		return
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	status_toast_label.text = msg
	status_toast_label.modulate = color
	status_toast_label.visible = true
	toast_tween = create_tween()
	toast_tween.tween_interval(duration)
	toast_tween.tween_property(status_toast_label, "modulate:a", 0.0, 0.35)
	toast_tween.tween_callback(func(): status_toast_label.visible = false)

# HIT演出
func trigger_hit() -> void:
	hit_indicator.visible = true
	hit_indicator.scale = Vector2(0.3, 0.3)
	hit_indicator.pivot_offset = hit_indicator.size * 0.5
	var tween = create_tween()
	tween.tween_property(hit_indicator, "scale", Vector2(1.2, 1.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(hit_indicator, "scale", Vector2(1.0, 1.0), 0.12)
	tween.tween_interval(0.65)
	tween.tween_callback(func(): hit_indicator.visible = false)

# ファイト中UI
func show_fight_ui(fish_name: String, weight_label: String = "") -> void:
	fight_container.visible = true
	if weight_label != "":
		fish_name_fight_label.text = "◆ 手応え: " + weight_label
	else:
		fish_name_fight_label.text = "FIGHT: " + fish_name
	tension_alert_label.text = ""

func update_fight_status(tension: float, distance: float, _is_reeling: bool, is_dashing: bool = false, stamina_ratio: float = 1.0) -> void:
	tension_bar.value = tension * 100.0
	var stam_pct = int(clamp(stamina_ratio, 0.0, 1.0) * 100.0)
	distance_label.text = "残り: %0.1fm (魚体力: %d%%)" % [max(0.0, distance), stam_pct]

	if tension > 0.82:
		tension_alert_label.text = "【危険】糸が限界！ 切れるぞ！（今すぐリールを離せ！）"
		tension_alert_label.modulate = Color(1.0, 0.25, 0.25)
	elif is_dashing:
		tension_alert_label.text = "【強引】魚が猛烈に突っ込んでいる！ 無理に巻かず耐えろ！"
		tension_alert_label.modulate = Color(1.0, 0.58, 0.20)
	elif tension < 0.22:
		tension_alert_label.text = "【注意】糸が緩んでいる！ バレるぞ！（リールを巻け！）"
		tension_alert_label.modulate = Color(0.35, 0.78, 1.0)
	else:
		tension_alert_label.text = "◎ 魚が止まった！ 最適テンションを保って巻き上げろ！"
		tension_alert_label.modulate = Color(0.35, 1.0, 0.45)

func hide_fight_ui() -> void:
	fight_container.visible = false

# 釣果ダイアログ（詳細な生態・学術データ対応）
func show_catch_result(fish_data: Dictionary) -> void:
	if status_toast_label:
		status_toast_label.visible = false
	current_caught_fish = fish_data
	result_dialog.visible = true
	result_title.text = "★ %s を釣り上げた！" % fish_data.get("name", "謎の魚")
	
	var sci = fish_data.get("scientific_name", "")
	if sci != "":
		scientific_name_label.text = "学名: " + sci
	else:
		scientific_name_label.text = ""
		
	var rarity = fish_data.get("rarity", "Common")
	rarity_badge_label.text = "【%s】" % rarity
	match rarity:
		"Common": rarity_badge_label.modulate = Color("#2a9d8f")
		"Rare": rarity_badge_label.modulate = Color("#e76f51")
		"Epic": rarity_badge_label.modulate = Color("#9d4edd")
		"Legendary": rarity_badge_label.modulate = Color("#f4a261")
		
	if fish_data.get("is_first", false):
		record_badge_label.text = "  ★ 初釣り上げ！ (NEW SPECIES)"
		record_badge_label.visible = true
	elif fish_data.get("is_new_record", false):
		record_badge_label.text = "  ★ 最大サイズ新記録！"
		record_badge_label.visible = true
	else:
		record_badge_label.text = ""
		record_badge_label.visible = false
	
	var len_val = fish_data.get("length", fish_data.get("size", 30.0))
	var weight_val = fish_data.get("weight", 0.5)
	var price_val = fish_data.get("price", 100)
	result_stats.text = "体長: %0.1f cm   重量: %0.2f kg   売却値: %d コイン" % [len_val, weight_val, price_val]
	result_habitat.text = "主な生息地: " + fish_data.get("habitat", "野北海岸の浅瀬〜沖合")
	result_desc.text = fish_data.get("desc", "")

	if btn_sell_now:
		btn_sell_now.text = "すぐに売却 (+%d G)" % price_val
	
	var tex_path = fish_data.get("texture", "")
	if ResourceLoader.exists(tex_path):
		result_icon.texture = load(tex_path)
	elif GameData:
		var tex = GameData.load_texture("res://assets/fish_side_" + fish_data.get("id", "") + ".png")
		if tex: result_icon.texture = tex
	
	# ポップインアニメーション
	result_dialog.scale = Vector2(0.5, 0.5)
	result_dialog.pivot_offset = result_dialog.size * 0.5
	var tween = create_tween()
	tween.tween_property(result_dialog, "scale", Vector2(1.05, 1.05), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(result_dialog, "scale", Vector2(1.0, 1.0), 0.1)

func _on_sell_now_pressed() -> void:
	if not GameData or GameData.inventory.is_empty():
		hide_catch_result()
		return
	# 直前にビクへ入った魚（最後の要素）を売却
	var last_idx = GameData.inventory.size() - 1
	var price = GameData.sell_fish_at(last_idx)
	show_status_toast("【売却】 %s を売却して %d G を獲得しました！" % [current_caught_fish.get("name", "魚"), price], Color(1.0, 0.90, 0.35), 2.4)
	hide_catch_result()

func hide_catch_result() -> void:
	result_dialog.visible = false
	result_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	result_dialog.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hide_catch_result()
	)
	catch_dialog_closed.emit()

func set_autopilot_active(active: bool) -> void:
	if autopilot_label:
		autopilot_label.visible = active
