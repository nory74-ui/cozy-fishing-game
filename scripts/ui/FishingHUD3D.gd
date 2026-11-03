extends CanvasLayer
class_name FishingHUD3D

# --- 3D釣り専用HUD（キャストゲージ・ファイト・学術的釣果ポップアップ） ---

signal reel_button_pressed
signal reel_button_released
signal catch_dialog_closed
signal book_open_requested

@onready var cast_gauge_container: Control = $CastGaugeContainer
@onready var cast_power_bar: ProgressBar = $CastGaugeContainer/CastPowerBar

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

@onready var autopilot_label: Label = $AutopilotLabel
@onready var btn_open_book: Button = $BtnOpenBook

func _ready() -> void:
	cast_gauge_container.visible = false
	fight_container.visible = false
	hit_indicator.visible = false
	result_dialog.visible = false
	if autopilot_label:
		autopilot_label.visible = false
		
	if btn_open_book:
		if GameData:
			GameData.apply_pastel_button_style(btn_open_book)
		btn_open_book.pressed.connect(func():
			book_open_requested.emit()
		)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B or event.keycode == KEY_J:
			book_open_requested.emit()

# キャストパワーゲージ
func show_cast_gauge(power_ratio: float) -> void:
	cast_gauge_container.visible = true
	cast_power_bar.value = power_ratio * 100.0

func hide_cast_gauge() -> void:
	cast_gauge_container.visible = false

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
func show_fight_ui(fish_name: String) -> void:
	fight_container.visible = true
	fish_name_fight_label.text = "FIGHT: " + fish_name
	tension_alert_label.text = ""

func update_fight_status(tension: float, distance: float, _is_reeling: bool) -> void:
	tension_bar.value = tension * 100.0
	distance_label.text = "距離: %0.1fm" % max(0.0, distance)
	
	if tension > 0.85:
		tension_alert_label.text = "⚠️ 糸が張りすぎ！ 切れるぞ！（リールを離せ！）"
		tension_alert_label.modulate = Color(1.0, 0.25, 0.25)
	elif tension < 0.20:
		tension_alert_label.text = "⚠️ 糸が緩んでいる！ バレるぞ！（リールを巻け！）"
		tension_alert_label.modulate = Color(0.35, 0.75, 1.0)
	else:
		tension_alert_label.text = "⭕ 最適テンション！ その調子で巻き上げろ！"
		tension_alert_label.modulate = Color(0.35, 1.0, 0.45)

func hide_fight_ui() -> void:
	fight_container.visible = false

# 釣果ダイアログ（詳細な生態・学術データ対応）
func show_catch_result(fish_data: Dictionary) -> void:
	result_dialog.visible = true
	result_title.text = "🎣 %s を釣り上げた！" % fish_data.get("name", "謎の魚")
	
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
		record_badge_label.text = "  🌟 初釣り上げ！ (NEW SPECIES)"
		record_badge_label.visible = true
	elif fish_data.get("is_new_record", false):
		record_badge_label.text = "  🏆 最大サイズ新記録！"
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

func hide_catch_result() -> void:
	result_dialog.visible = false
	catch_dialog_closed.emit()

func set_autopilot_active(active: bool) -> void:
	if autopilot_label:
		autopilot_label.visible = active
