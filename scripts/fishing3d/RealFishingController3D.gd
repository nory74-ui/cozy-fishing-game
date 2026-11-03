extends Node
class_name RealFishingController3D

# --- 福岡・糸島 野北海岸 3D本格釣りコントローラー & Autopilot ---

enum State {
	IDLE,
	CHARGING,
	CASTING,
	WAITING,
	NIBBLING,
	HOOKED,
	FIGHTING,
	LANDING
}

var current_state: State = State.IDLE

# 参照ノード
@export var player: CharacterBody3D
@export var companion: CharacterBody3D
@export var hud: CanvasLayer
@export var fx: Node3D

const FishDb = preload("res://scripts/fishing3d/FishDatabase3D.gd")

# キャスト関連
var charge_power: float = 0.0
var charge_speed: float = 2.2
var cast_fly_time: float = 0.0
var cast_duration: float = 0.65
var cast_start_pos: Vector3 = Vector3.ZERO
var cast_target_pos: Vector3 = Vector3.ZERO

# ウキ
var bobber_node: Node3D
var bobber_light: OmniLight3D
var bobber_visual_y: float = 0.0
var bobber_timer: float = 0.0

# 魚データ & ファイトパラメータ
var current_fish: Dictionary = {}
var wait_timer: float = 0.0
var nibble_count: int = 0
var bite_wait_duration: float = 3.0
var fight_tension: float = 0.5
var fight_distance: float = 8.0
var fish_pull_timer: float = 0.0
var is_reeling: bool = false
var reel_sound_timer: float = 0.0

# Autopilot（自律テストAI）
var is_autopilot: bool = false
var autopilot_step_timer: float = 0.0

signal fish_caught(fish_data: Dictionary)
signal state_changed(new_state: State)

func _ready() -> void:
	_create_3d_bobber()
	
	if hud:
		hud.catch_dialog_closed.connect(_on_catch_dialog_closed)

	# コマンドライン引数で --autopilot があれば有効化
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg == "--autopilot":
			set_autopilot(true)
			break

func _create_3d_bobber() -> void:
	bobber_node = Node3D.new()
	bobber_node.name = "RealBobber3D"
	bobber_node.visible = false
	
	# 玉ウキ本体
	var mesh_inst = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.22
	var mat_bob = StandardMaterial3D.new()
	mat_bob.albedo_color = Color(0.95, 0.22, 0.18)
	sm.material = mat_bob
	mesh_inst.mesh = sm
	bobber_node.add_child(mesh_inst)

	# 夜光ケミホタル
	var chemi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.025
	cm.height = 0.16
	var mat_chemi = StandardMaterial3D.new()
	mat_chemi.albedo_color = Color(0.35, 1.0, 0.4)
	mat_chemi.emission_enabled = true
	mat_chemi.emission = Color(0.35, 1.0, 0.4)
	mat_chemi.emission_energy_multiplier = 4.0
	cm.material = mat_chemi
	chemi.mesh = cm
	chemi.position.y = 0.14
	bobber_node.add_child(chemi)

	# ケミホタル光源
	bobber_light = OmniLight3D.new()
	bobber_light.light_color = Color(0.35, 1.0, 0.45)
	bobber_light.light_energy = 2.4
	bobber_light.omni_range = 3.5
	bobber_node.add_child(bobber_light)

	add_child(bobber_node)

func _unhandled_input(event: InputEvent) -> void:
	# [P] キーによるオートパイロットのON/OFF切り替えは常に最優先で受け付ける
	if event is InputEventKey and not event.echo and event.pressed:
		if event.keycode == KEY_P:
			set_autopilot(not is_autopilot)
			get_viewport().set_input_as_handled()
			return

	if is_autopilot:
		return

	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			if event.pressed:
				_on_action_pressed()
			else:
				_on_action_released()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_action_pressed()
		else:
			_on_action_released()

func _on_action_pressed() -> void:
	match current_state:
		State.IDLE:
			_start_charging()
		State.HOOKED:
			_hook_fish()
		State.FIGHTING:
			is_reeling = true
		State.LANDING:
			if hud: hud.hide_catch_result()

func _on_action_released() -> void:
	match current_state:
		State.CHARGING:
			_release_cast()
		State.FIGHTING:
			is_reeling = false

func _process(delta: float) -> void:
	_update_state_machine(delta)
	_update_fishing_line()
	if is_autopilot:
		_process_autopilot(delta)

func _update_state_machine(delta: float) -> void:
	match current_state:
		State.CHARGING:
			charge_power += charge_speed * delta
			var power_ratio = (sin(charge_power) + 1.0) * 0.5
			if hud: hud.show_cast_gauge(power_ratio)

		State.CASTING:
			cast_fly_time += delta
			var t = clamp(cast_fly_time / cast_duration, 0.0, 1.0)
			# 放物線軌道
			var cur_pos = cast_start_pos.lerp(cast_target_pos, t)
			cur_pos.y += sin(t * PI) * 2.5
			bobber_node.global_position = cur_pos
			
			if t >= 1.0:
				_on_bobber_landed()

		State.WAITING:
			bobber_timer += delta
			bobber_node.global_position.y = 0.05 + sin(bobber_timer * 2.8) * 0.035
			bobber_node.rotation.z = sin(bobber_timer * 2.5) * 0.08
			
			wait_timer += delta
			if wait_timer >= bite_wait_duration:
				_start_nibble()

		State.NIBBLING:
			bobber_timer += delta
			wait_timer += delta
			# ツンツン前アタリ
			var nib_pulse = sin(wait_timer * 18.0)
			if nib_pulse > 0.8:
				bobber_node.global_position.y = -0.06
			else:
				bobber_node.global_position.y = 0.04
				
			if wait_timer > 2.0:
				_trigger_hooked()

		State.HOOKED:
			# ウキが水中に深く引き込まれる！
			bobber_node.global_position.y = -0.35
			wait_timer += delta
			# 1.5秒放置するとエサだけ取られて逃げられる
			if wait_timer > 1.5:
				_fish_escaped("エサだけ取られて逃げられた…！")

		State.FIGHTING:
			_process_fighting(delta)

		State.LANDING:
			pass

# --- 1. キャスト動作 ---
func _start_charging() -> void:
	current_state = State.CHARGING
	charge_power = 0.0
	if player:
		player.current_state = CharacterBarlock3D.State.CASTING
		player.facing_dir = 3 # 海側を向く
		player._update_sprite_direction()
	state_changed.emit(current_state)

func _release_cast() -> void:
	var power_ratio = (sin(charge_power) + 1.0) * 0.5
	if hud: hud.hide_cast_gauge()
	
	current_state = State.CASTING
	cast_fly_time = 0.0
	
	var rod_tip = _get_rod_tip_pos()
	cast_start_pos = rod_tip
	
	# 画面内に確実に収まるキャスト距離（2.4m〜4.8m沖合）
	var cast_dist = lerp(2.4, 4.8, power_ratio)
	var forward = Vector3(-1.0, 0.0, randf_range(-0.14, 0.14)).normalized()
	cast_target_pos = player.global_position + forward * cast_dist
	
	# 汀線より必ず海側かつ、カメラ画角から絶対にはみ出さない範囲にクランプ
	var z_clamped = clamp(cast_target_pos.z, player.global_position.z - 1.5, player.global_position.z + 1.5)
	z_clamped = clamp(z_clamped, -14.0, 14.0)
	var shore_x = 0.6 + sin(z_clamped * 0.16) * 1.1 + cos(z_clamped * 0.09 + 0.5) * 0.6
	var max_water_x = min(shore_x - 1.0, player.global_position.x - 1.8)
	var min_screen_x = max(player.global_position.x - 4.5, -11.5)
	cast_target_pos.x = clamp(cast_target_pos.x, min_screen_x, max_water_x)
	cast_target_pos.z = z_clamped

	# 大波止（北防波堤 z < -9.2）の上から投げる場合は手前の開けた海面へ着水させる
	if player.global_position.z < -9.2:
		cast_target_pos.z = clamp(player.global_position.z + 3.0, -8.5, -6.8)
		cast_target_pos.x = clamp(player.global_position.x - lerp(1.8, 3.2, power_ratio), -8.2, -2.5)
	# 木製桟橋（z ≈ -3.6）の上から投げる場合も桟橋の板を避けて海面へ着水させる
	elif abs(player.global_position.z - (-3.6)) < 1.3 and player.global_position.x < 1.2:
		cast_target_pos.z = player.global_position.z + 1.8
		cast_target_pos.x = clamp(player.global_position.x - lerp(2.0, 3.6, power_ratio), -7.5, -2.2)

	cast_target_pos.y = 0.05
	
	bobber_node.global_position = cast_start_pos
	bobber_node.visible = true
	
	if SoundManager:
		SoundManager.play_sfx("cast", 0.15, -2.0)
	state_changed.emit(current_state)

func _on_bobber_landed() -> void:
	current_state = State.WAITING
	wait_timer = 0.0
	bobber_timer = 0.0
	bite_wait_duration = randf_range(2.0, 4.5)
	
	var is_night = false
	var parent_world = get_parent()
	if parent_world and "current_time_of_day" in parent_world:
		is_night = parent_world.current_time_of_day > 0.65
		
	var dist = player.global_position.distance_to(cast_target_pos)
	current_fish = FishDb.get_random_fish(is_night, dist, cast_target_pos.x)
	
	# 着水エフェクト＆着水音
	if fx:
		fx.spawn_water_splash(cast_target_pos, 14, 2.2)
	if SoundManager:
		SoundManager.play_sfx("hit", 0.15, -4.0) # 水音代用
	state_changed.emit(current_state)

# --- 2. 前アタリ & 本アタリ ---
func _start_nibble() -> void:
	current_state = State.NIBBLING
	wait_timer = 0.0
	if fx:
		fx.spawn_water_ripple(bobber_node.global_position, 0.6)
	if SoundManager:
		SoundManager.play_sfx("hit", 0.08, -12.0)
	state_changed.emit(current_state)

func _trigger_hooked() -> void:
	current_state = State.HOOKED
	wait_timer = 0.0
	
	if fx:
		fx.spawn_water_splash(bobber_node.global_position, 16, 3.0)
	if SoundManager:
		SoundManager.play_sfx("hit", 0.25, 2.0)
	if hud:
		hud.trigger_hit()
	state_changed.emit(current_state)

func _hook_fish() -> void:
	current_state = State.FIGHTING
	fight_tension = 0.45
	fight_distance = player.global_position.distance_to(bobber_node.global_position)
	fish_pull_timer = 0.0
	is_reeling = false
	
	if hud:
		hud.show_fight_ui(current_fish.get("name", "魚"))
	if companion and companion.has_method("_update_sprite_direction"):
		companion.facing_dir = 3 # 海を向いて応援
		companion._update_sprite_direction()
	state_changed.emit(current_state)

# --- 3. 本格ファイトシステム ---
func _process_fighting(delta: float) -> void:
	var fish_power = current_fish.get("power", 1.0)
	var pull_freq = current_fish.get("pull_freq", 2.0)
	
	fish_pull_timer += delta * pull_freq
	var fish_burst = max(0.0, sin(fish_pull_timer)) # 魚の突っ込み
	
	# テンション計算
	var tension_delta = 0.0
	if is_reeling:
		tension_delta += 0.55 * delta
		fight_distance -= 3.2 * delta
		reel_sound_timer += delta
		if reel_sound_timer >= 0.16:
			reel_sound_timer = 0.0
			if SoundManager:
				SoundManager.play_sfx("reel", 0.1, -5.0)
	else:
		tension_delta -= 0.40 * delta
		
	tension_delta += fish_burst * 0.50 * fish_power * delta
	fight_tension = clamp(fight_tension + tension_delta, 0.05, 1.05)
	
	# 魚が水面で激しく暴れる飛沫演出
	if fish_burst > 0.7 and randf() < 0.25 and fx:
		fx.spawn_water_splash(bobber_node.global_position, 6, 1.8)
		
	# ウキと魚影の位置をプレイヤーへ引き寄せる
	var to_player = (player.global_position - bobber_node.global_position).normalized()
	bobber_node.global_position += to_player * (3.2 * delta if is_reeling else -0.4 * fish_burst * delta)
	bobber_node.global_position.y = 0.02 + sin(fish_pull_timer * 4.0) * 0.12
	
	if hud:
		hud.update_fight_status(fight_tension, fight_distance, is_reeling)
		
	# 勝敗判定
	if fight_tension >= 0.98:
		_fish_escaped("痛恨のラインブレイク！ 糸が切れてしまった…！")
	elif fight_tension <= 0.08:
		_fish_escaped("糸が緩んで針から外れてしまった…！")
	elif fight_distance <= 1.5:
		_land_fish()

func _fish_escaped(reason: String) -> void:
	current_state = State.IDLE
	if hud:
		hud.hide_fight_ui()
	bobber_node.visible = false
	if player:
		player.current_state = CharacterBarlock3D.State.IDLE
	state_changed.emit(current_state)

# --- 4. 釣り上げ成功 ---
func _land_fish() -> void:
	current_state = State.LANDING
	
	# ゲームデータ＆図鑑への記録
	if GameData:
		var sp_id = current_fish.get("id", "aji")
		var len_val = current_fish.get("length", 20.0)
		var record_res = GameData.record_fish_catch(sp_id, len_val)
		GameData.add_caught_fish(current_fish)
		current_fish["is_first"] = record_res.get("is_first", false)
		current_fish["is_new_record"] = record_res.get("is_new_record", false)

	if hud:
		hud.hide_fight_ui()
		hud.show_catch_result(current_fish)
		
	bobber_node.visible = false
	
	# 黄金スパークル & ファンファーレ
	if fx:
		fx.spawn_catch_sparkles(player.global_position + Vector3(-1.0, 1.5, 0.0))
	if SoundManager:
		SoundManager.play_sfx("fanfare", 0.0, 1.0)
		SoundManager.play_sfx("catch", 0.1, 0.0)

	# ミケが大喜びでぴょんぴょん跳ねる
	if companion and companion.visual_root:
		var ct = create_tween().set_loops(4)
		ct.tween_property(companion.visual_root, "position:y", 0.45, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ct.tween_property(companion.visual_root, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	fish_caught.emit(current_fish)
	state_changed.emit(current_state)

func _on_catch_dialog_closed() -> void:
	current_state = State.IDLE
	if player:
		player.current_state = CharacterBarlock3D.State.IDLE
	state_changed.emit(current_state)

# 竿先位置取得
func _get_rod_tip_pos() -> Vector3:
	if not player: return Vector3.ZERO
	# バーロックの竿先（左手上部）
	return player.global_position + Vector3(-0.9, 1.7, 0.1)

# 釣り糸の更新
func _update_fishing_line() -> void:
	if not fx or not bobber_node: return
	var is_visible = (current_state != State.IDLE and current_state != State.LANDING)
	var tension_val = 0.25
	if current_state == State.WAITING or current_state == State.FIGHTING:
		tension_val = fight_tension
	fx.update_line(_get_rod_tip_pos(), bobber_node.global_position, tension_val, is_visible)

# --- 5. Autopilot（自律プレイテストAI） ---
func set_autopilot(enabled: bool) -> void:
	is_autopilot = enabled
	autopilot_step_timer = 0.0
	is_reeling = false
	if hud:
		hud.set_autopilot_active(is_autopilot)
	if not is_autopilot:
		# オートパイロット解除時に進行中のチャージやUIをクリーンにリセットして手動操作へ即復帰
		if hud:
			hud.hide_cast_gauge()
			hud.hide_fight_ui()
			if hud.result_dialog and hud.result_dialog.visible:
				hud.hide_catch_result()
		if bobber_node:
			bobber_node.visible = false
		current_state = State.IDLE
		if player:
			player.current_state = CharacterBarlock3D.State.IDLE
		state_changed.emit(current_state)
	print("AUTOPILOT MODE: ", "ENABLED" if enabled else "DISABLED")

func _process_autopilot(delta: float) -> void:
	autopilot_step_timer += delta
	match current_state:
		State.IDLE:
			# 波止の良い位置に立ってキャスト開始
			if autopilot_step_timer > 1.2:
				autopilot_step_timer = 0.0
				_on_action_pressed()

		State.CHARGING:
			# パワーが 80% 付近になったら離す
			var power_ratio = (sin(charge_power) + 1.0) * 0.5
			if power_ratio > 0.82:
				_on_action_released()

		State.HOOKED:
			# 電光石火で合わせる！
			if autopilot_step_timer > 0.2:
				autopilot_step_timer = 0.0
				_on_action_pressed()

		State.FIGHTING:
			# テンションが 0.65 未満なら巻き、0.80 を超えたら離す絶妙なリール操作
			if fight_tension < 0.68:
				is_reeling = true
			elif fight_tension > 0.82:
				is_reeling = false

		State.LANDING:
			# 釣果ダイアログを 2.5 秒堪能した後に閉じる
			if autopilot_step_timer > 2.5:
				autopilot_step_timer = 0.0
				if hud:
					hud.hide_catch_result()
