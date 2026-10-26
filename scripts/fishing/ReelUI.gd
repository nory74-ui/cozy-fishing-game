extends Control

# ミニゲームの視覚表示（トラック、魚、セーフ枠、進行ゲージ）

var fish_percent: float = 50.0
var bar_percent: float = 50.0
var bar_width_pct: float = 30.0
var progress_percent: float = 30.0
var is_reeling: bool = false
var is_inside_safe: bool = false

@onready var progress_bar = $ProgressBar

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_ui(f_pos: float, b_pos: float, b_size: float, prog: float, inside: bool) -> void:
	fish_percent = f_pos
	bar_percent = b_pos
	bar_width_pct = b_size
	progress_percent = prog
	is_inside_safe = inside
	if progress_bar:
		progress_bar.value = prog
	queue_redraw()

func set_reel_active(active: bool) -> void:
	is_reeling = active

func _draw() -> void:
	var total_w = 400.0
	var total_h = 36.0
	var start_x = (size.x - total_w) * 0.5
	var start_y = 40.0
	
	# 1. 外枠背景プレート
	var bg_rect = Rect2(start_x - 12, start_y - 12, total_w + 24, total_h + 52)
	draw_rect(bg_rect, Color(0.12, 0.15, 0.18, 0.85), true)
	draw_rect(bg_rect, Color(0.85, 0.75, 0.5, 0.9), false, 2.0)
	
	# 2. ミニゲームトラック（水流バー）
	var track_rect = Rect2(start_x, start_y, total_w, total_h)
	draw_rect(track_rect, Color(0.18, 0.28, 0.35, 0.9), true)
	draw_rect(track_rect, Color(0.4, 0.6, 0.7, 0.8), false, 1.5)
	
	# 3. セーフゾーン（プレイヤーが操作する緑の枠）
	var bw = (bar_width_pct / 100.0) * total_w
	var bx = start_x + (bar_percent / 100.0) * total_w - bw * 0.5
	bx = clampf(bx, start_x, start_x + total_w - bw)
	var bar_rect = Rect2(bx, start_y + 2, bw, total_h - 4)
	
	var bar_col = Color(0.3, 0.85, 0.45, 0.5) if is_inside_safe else Color(0.3, 0.75, 0.45, 0.35)
	draw_rect(bar_rect, bar_col, true)
	draw_rect(bar_rect, Color(0.4, 1.0, 0.6, 0.9), false, 2.0)
	
	# 4. 魚アイコンの描画
	var fx = start_x + (fish_percent / 100.0) * total_w
	var fy = start_y + total_h * 0.5
	
	# 魚の影
	draw_circle(Vector2(fx, fy + 2), 10, Color(0, 0, 0, 0.3))
	# 魚の体
	var fish_color = Color("ffb703") if is_inside_safe else Color("f4a261")
	draw_circle(Vector2(fx, fy), 8, fish_color)
	draw_colored_polygon([
		Vector2(fx - 6, fy),
		Vector2(fx - 14, fy - 6),
		Vector2(fx - 14, fy + 6)
	], fish_color)
	# 魚の目
	draw_circle(Vector2(fx + 3, fy - 2), 2, Color.BLACK)
