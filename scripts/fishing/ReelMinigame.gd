extends Control

# 水彩絵本調のリール巻き上げミニゲームUI
# （長押しで緑の枠を動かし、魚をキープしてゲージを溜める）

signal reel_success()
signal reel_failed()

var is_active: bool = false

# パラメータ
var fish_pos: float = 50.0 # 0.0 〜 100.0
var fish_target_pos: float = 50.0
var fish_move_timer: float = 0.0
var fish_speed: float = 35.0

var bar_pos: float = 50.0 # プレイヤー枠の中心
var bar_size: float = 32.0 # 枠の幅
var bar_speed: float = 75.0

var catch_progress: float = 35.0 # 0.0 〜 100.0
var is_inside_safe: bool = false
var time_counter: float = 0.0

var target_fish_data: Dictionary = {}
var reel_sfx_timer: float = 0.0

@onready var progress_bar: ProgressBar = $ProgressBar

func _ready() -> void:
	visible = false

func start_minigame(fish_data: Dictionary) -> void:
	target_fish_data = fish_data
	visible = true
	is_active = true
	
	catch_progress = 35.0
	fish_pos = 50.0
	fish_target_pos = 50.0
	bar_pos = 50.0
	bar_size = 32.0
	
	# 魚種による難易度設定
	var species = fish_data.get("species", "funa")
	match species:
		"medaka":
			fish_speed = 32.0
			bar_size = 38.0 # 小型で釣りやすい
		"yamame":
			fish_speed = 46.0 # すばしっこい
			bar_size = 28.0
		"funa":
			fish_speed = 28.0 # のんびり
			bar_size = 34.0
		"koi":
			fish_speed = 36.0 # 力強い
			bar_size = 28.0
		"catfish":
			fish_speed = 40.0 # 大物
			bar_size = 26.0
		"iwana":
			fish_speed = 44.0 # 渓流の力強い引き
			bar_size = 26.0
		"rainbow_trout":
			fish_speed = 50.0 # 素早いジャンプと鋭い突進
			bar_size = 24.0
		"golden_koi":
			fish_speed = 56.0 # 伝説の主の激しい暴れ！
			bar_size = 22.0

	# 現在装備中の竿の性能補正（安定性で枠が広がる！）
	var rod_data = GameData.RODS.get(GameData.current_rod, {})
	var stability = rod_data.get("stability", 1.0)
	bar_size = clampf(bar_size * stability, 18.0, 52.0)

	if progress_bar:
		progress_bar.value = catch_progress
		
	queue_redraw()

func stop_minigame() -> void:
	is_active = false
	visible = false

func _process(delta: float) -> void:
	if not is_active:
		return
		
	time_counter += delta
	
	# 1. 魚のAI移動
	fish_move_timer -= delta
	if fish_move_timer <= 0.0:
		fish_move_timer = randf_range(0.4, 1.2)
		fish_target_pos = randf_range(12.0, 88.0)
		
	fish_pos = move_toward(fish_pos, fish_target_pos, delta * fish_speed)
	
	# 2. プレイヤーの枠操作（マウス左長押し または Space長押し）
	var is_holding = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("ui_accept")
	if is_holding:
		bar_pos = move_toward(bar_pos, 96.0, delta * bar_speed)
		reel_sfx_timer -= delta
		if reel_sfx_timer <= 0.0:
			reel_sfx_timer = 0.22
			var p_rnd = 0.08
			var p_bonus = 0.15 if is_inside_safe else 0.0
			SoundManager.play_sfx("reel", p_rnd, -2.0)
	else:
		bar_pos = move_toward(bar_pos, 4.0, delta * bar_speed * 0.85)
		reel_sfx_timer = 0.0

	# 3. セーフ枠内判定
	var half_bar = bar_size * 0.5
	is_inside_safe = abs(fish_pos - bar_pos) <= half_bar
	
	if is_inside_safe:
		var rod_data = GameData.RODS.get(GameData.current_rod, {})
		var power = rod_data.get("power", 1.0)
		catch_progress += delta * (22.0 * power) # ゲージ上昇（竿のパワーが直結！）
	else:
		catch_progress -= delta * 14.0 # ゲージ減少
		
	catch_progress = clampf(catch_progress, 0.0, 100.0)
	if progress_bar:
		progress_bar.value = catch_progress

	# 4. 勝敗判定
	if catch_progress >= 100.0:
		is_active = false
		reel_success.emit()
	elif catch_progress <= 0.0:
		is_active = false
		reel_failed.emit()
		
	queue_redraw()

func _draw() -> void:
	if not is_active:
		return
		
	var w = 420.0
	var h = 40.0
	var ox = (size.x - w) * 0.5
	var oy = 20.0
	
	# 1. 水彩紙風の外枠プレート
	var panel_rect = Rect2(ox - 14, oy - 14, w + 28, h + 58)
	draw_rect(panel_rect, Color(0.98, 0.96, 0.90, 0.95), true) # 生成りの紙
	draw_rect(panel_rect, Color(0.55, 0.45, 0.35, 0.8), false, 2.0) # 水彩エッジ線
	
	# 2. 水流トラック（水彩ブルー）
	var track_rect = Rect2(ox, oy, w, h)
	draw_rect(track_rect, Color(0.68, 0.84, 0.94, 0.9), true)
	draw_rect(track_rect, Color(0.40, 0.60, 0.78, 0.85), false, 1.5)
	
	# 水流の波線
	for i in range(5):
		var wx = ox + 30 + i * 80 + sin(time_counter * 3.0 + i) * 12.0
		draw_arc(Vector2(wx, oy + h * 0.5), 12.0, PI * 0.8, PI * 0.2, 8, Color(1, 1, 1, 0.5), 1.5)

	# 3. セーフゾーン枠（プレイヤーが操作する緑の枠）
	var bw = (bar_size / 100.0) * w
	var bx = ox + (bar_pos / 100.0) * w - bw * 0.5
	bx = clampf(bx, ox, ox + w - bw)
	var bar_rect = Rect2(bx, oy + 2, bw, h - 4)
	
	var bar_col = Color(0.45, 0.82, 0.55, 0.65) if is_inside_safe else Color(0.45, 0.82, 0.55, 0.35)
	draw_rect(bar_rect, bar_col, true)
	draw_rect(bar_rect, Color(0.25, 0.65, 0.35, 0.95), false, 2.0)

	# 4. 魚アイコンの描画
	var fx = ox + (fish_pos / 100.0) * w
	var fy = oy + h * 0.5
	
	# 魚の影
	draw_ellipse(Vector2(fx, fy + 2), 12.0, 6.0, Color(0, 0, 0, 0.25))
	
	# 魚アイコン（鮮やかな朱赤または金色）
	var fish_color = Color("#e76f51") if is_inside_safe else Color("#e9c46a")
	draw_circle(Vector2(fx, fy), 8.5, fish_color)
	draw_colored_polygon([
		Vector2(fx - 6, fy),
		Vector2(fx - 15, fy - 7),
		Vector2(fx - 15, fy + 7)
	], fish_color)
	draw_circle(Vector2(fx + 4, fy - 2), 1.8, Color("#2b2d42")) # 目
