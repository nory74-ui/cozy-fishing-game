extends Node2D

# 釣りの進行とリール巻き上げミニゲームのコントローラー

signal fish_caught(fish_data: Dictionary)
signal fish_escaped()
signal state_changed(new_state: String)

enum State {
	IDLE,
	CASTING,
	WAITING,
	NIBBLE,
	BITE,
	REELING,
	CAUGHT,
	ESCAPED
}

var current_state: State = State.IDLE

@onready var fisherman = $Fisherman
@onready var bobber = $Bobber
@onready var reel_ui = $ReelUI

# タイマー管理
var timer: float = 0.0
var nibble_time: float = 0.0
var bite_time_window: float = 1.3 # HIT後の猶予秒数

# 今回かかる魚のデータ
var current_target_fish: Dictionary = {}

# ミニゲームパラメータ
var fish_pos: float = 50.0 # 0.0 〜 100.0
var fish_target_pos: float = 50.0
var fish_move_timer: float = 0.0
var bar_pos: float = 50.0 # プレイヤーのバー中心
var bar_size: float = 32.0 # バーの幅
var catch_progress: float = 30.0 # 0.0 〜 100.0

func _ready() -> void:
	reel_ui.visible = false
	change_state(State.IDLE)

func _process(delta: float) -> void:
	# 竿先位置をウキに伝える
	if fisherman and bobber:
		bobber.rod_tip_pos = fisherman.get_rod_tip_position()
	
	match current_state:
		State.WAITING:
			timer -= delta
			if timer <= 0.0:
				change_state(State.NIBBLE)
				
		State.NIBBLE:
			timer -= delta
			if timer <= 0.0:
				change_state(State.BITE)
				
		State.BITE:
			timer -= delta
			if timer <= 0.0:
				# 合わせ損ねた場合
				_on_miss_bite()

		State.REELING:
			_process_reeling_minigame(delta)

func _input(event: InputEvent) -> void:
	# クリック or スペースキー
	var is_action = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_action = true
	elif event.is_action_pressed("ui_accept"):
		is_action = true
		
	if is_action:
		match current_state:
			State.IDLE:
				start_cast()
			State.BITE:
				start_reeling()

func start_cast() -> void:
	# エサの有無確認
	var bait_count = GameData.bait_counts.get(GameData.current_bait, 0)
	if bait_count <= 0:
		# エサなしでも釣れるが低確率にするか、エサ消費の案内
		pass
	GameData.consume_current_bait()
	
	# 出現する魚を抽選
	_select_random_fish()
	
	change_state(State.CASTING)
	
	# キャスト位置
	var cast_x = randf_range(520, 850)
	var cast_y = randf_range(410, 520)
	bobber.cast_to(Vector2(cast_x, cast_y))
	
	# 着水後の待機へ遷移
	await get_tree().create_timer(0.6).timeout
	if current_state == State.CASTING:
		change_state(State.WAITING)
		timer = randf_range(2.0, 4.5)

func _select_random_fish() -> void:
	var spot_data = GameData.SPOTS.get(GameData.current_spot, GameData.SPOTS["stream"])
	var fish_ids: Array = spot_data.get("fish_ids", ["medaka"])
	
	# エサによるレア度補正
	var bait_data = GameData.BAITS.get(GameData.current_bait, GameData.BAITS["worm"])
	var rare_boost = bait_data.get("rare_boost", 1.0)
	
	# 重み付け抽選
	var chosen_id = fish_ids[0]
	if fish_ids.size() > 1:
		var roll = randf() * 100.0
		if fish_ids.size() >= 3 and roll < 15.0 * rare_boost:
			chosen_id = fish_ids[2] # レア/主
		elif roll < 45.0 * rare_boost:
			chosen_id = fish_ids[1] # 中堅
		else:
			chosen_id = fish_ids[0] # 定番
	
	var base_fish = GameData.FISH_DATABASE.get(chosen_id, GameData.FISH_DATABASE["medaka"])
	# サイズのランダム計算
	var size = snappedf(randf_range(base_fish.min_size, base_fish.max_size), 0.1)
	# サイズに応じた価格補正（大きいと最大+50%）
	var size_ratio = (size - base_fish.min_size) / maxf(0.1, (base_fish.max_size - base_fish.min_size))
	var price = int(base_fish.base_price * (1.0 + size_ratio * 0.5))
	
	current_target_fish = {
		"id": base_fish.id,
		"name": base_fish.name,
		"icon": base_fish.icon,
		"color": base_fish.color,
		"rarity": base_fish.rarity,
		"size": size,
		"price": price,
		"desc": base_fish.desc,
		"difficulty": base_fish.difficulty
	}

func _on_miss_bite() -> void:
	bobber.set_hit(false)
	bobber.pull_back()
	change_state(State.ESCAPED)
	fish_escaped.emit()
	await get_tree().create_timer(1.2).timeout
	if current_state == State.ESCAPED:
		change_state(State.IDLE)

func start_reeling() -> void:
	bobber.set_hit(false)
	change_state(State.REELING)
	
	# ミニゲーム初期化
	reel_ui.visible = true
	catch_progress = 35.0
	fish_pos = 50.0
	fish_target_pos = 50.0
	bar_pos = 50.0
	
	# 竿の性能反映
	var rod = GameData.RODS.get(GameData.current_rod, GameData.RODS["branch_rod"])
	bar_size = 28.0 * rod.stability

func _process_reeling_minigame(delta: float) -> void:
	var diff = current_target_fish.get("difficulty", 1.0)
	var rod = GameData.RODS.get(GameData.current_rod, GameData.RODS["branch_rod"])
	
	# 魚の気まぐれな移動
	fish_move_timer -= delta
	if fish_move_timer <= 0.0:
		fish_move_timer = randf_range(0.4 / diff, 1.2 / diff)
		fish_target_pos = randf_range(10.0, 90.0)
	
	fish_pos = move_toward(fish_pos, fish_target_pos, delta * 35.0 * diff)
	
	# プレイヤーのバー操作（スペース長押しまたはマウスボタン長押しで右へ、離すと左へ）
	var is_holding = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("ui_accept")
	var bar_speed = 70.0
	if is_holding:
		bar_pos = move_toward(bar_pos, 95.0, delta * bar_speed)
	else:
		bar_pos = move_toward(bar_pos, 5.0, delta * bar_speed * 0.9)
		
	# 魚がバー（緑の枠）の中に入っているか判定
	var half_bar = bar_size * 0.5
	var is_inside = abs(fish_pos - bar_pos) <= half_bar
	
	if is_inside:
		catch_progress += delta * 25.0 * rod.power
		reel_ui.set_reel_active(true)
	else:
		catch_progress -= delta * 12.0
		reel_ui.set_reel_active(false)
	
	catch_progress = clampf(catch_progress, 0.0, 100.0)
	reel_ui.update_ui(fish_pos, bar_pos, bar_size, catch_progress, is_inside)
	
	# 勝敗判定
	if catch_progress >= 100.0:
		_finish_catch_success()
	elif catch_progress <= 0.0:
		_finish_catch_fail()

func _finish_catch_success() -> void:
	reel_ui.visible = false
	bobber.pull_back()
	change_state(State.CAUGHT)
	
	GameData.add_caught_fish(current_target_fish)
	fish_caught.emit(current_target_fish)

func _finish_catch_fail() -> void:
	reel_ui.visible = false
	bobber.pull_back()
	change_state(State.ESCAPED)
	fish_escaped.emit()
	await get_tree().create_timer(1.2).timeout
	if current_state == State.ESCAPED:
		change_state(State.IDLE)

func reset_to_idle() -> void:
	change_state(State.IDLE)

func change_state(new_state: State) -> void:
	current_state = new_state
	var state_name = State.keys()[new_state]
	fisherman.set_pose(state_name)
	state_changed.emit(state_name)
	
	match new_state:
		State.IDLE:
			bobber.pull_back()
		State.NIBBLE:
			bobber.set_nibble(true)
			timer = randf_range(0.4, 0.9)
		State.BITE:
			bobber.set_nibble(false)
			bobber.set_hit(true)
			timer = bite_time_window
