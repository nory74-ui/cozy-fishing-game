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
	LANDING_ACTION,
	LANDING
}

var current_state: State = State.IDLE

# 参照ノード
@export var player: CharacterBody3D
@export var companion: CharacterBody3D
@export var hud: CanvasLayer
@export var fx: Node3D

const FishDb = preload("res://scripts/fishing3d/FishDatabase3D.gd")

# キャスト関連（力加減で近い・中間・遠いが明確に変化）
var charge_power: float = 0.0
var charge_speed: float = 1.35
var last_cast_power_ratio: float = 0.5
var cast_fly_time: float = 0.0
var cast_duration: float = 0.65
var cast_arc_height: float = 2.2
var cast_start_pos: Vector3 = Vector3.ZERO
var cast_target_pos: Vector3 = Vector3.ZERO

# ウキ
var bobber_node: Node3D
var bobber_light: OmniLight3D
var bobber_visual_y: float = 0.0
var bobber_timer: float = 0.0

# ウキに寄ってくる3D魚影（サイズ・動きが魚種と重量に連動）
var stalker_fish_node: Node3D
var stalker_start_pos: Vector3 = Vector3.ZERO
var stalker_angle: float = 0.0
var discover_delay: float = 2.0
var fish_approaching: bool = false
var approach_progress: float = 0.0
var approach_speed: float = 0.45

# 前アタリ（ツンツン）＆ランダムヒットタイミング
var current_fish: Dictionary = {}
var wait_timer: float = 0.0
var nibble_count: int = 0
var target_nibbles: int = 2
var next_nibble_interval: float = 1.2
var nibble_dip_timer: float = 0.0
var hook_window: float = 1.15

# 本格ファイト＆重量差パラメータ
var fight_tension: float = 0.45
var fight_distance: float = 5.0
var fish_stamina: float = 1.0
var is_fish_dashing: bool = false
var dash_state_timer: float = 0.0
var dash_state_duration: float = 1.2
var fish_pull_timer: float = 0.0
var is_reeling: bool = false
var reel_sound_timer: float = 0.0
var landing_anim_timer: float = 0.0
var landing_duration: float = 0.85
var landing_start_pos: Vector3 = Vector3.ZERO

# Autopilot（自律テストAI）
var is_autopilot: bool = false
var autopilot_step_timer: float = 0.0
var autopilot_target_power: float = 0.75

signal fish_caught(fish_data: Dictionary)
signal state_changed(new_state: State)

func _ready() -> void:
	_create_3d_bobber()
	_create_stalker_fish_shadow()

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

func _create_stalker_fish_shadow() -> void:
	var fish_scene = load("res://assets/models/fbx/swimming_sea_fish.glb")
	if not fish_scene:
		fish_scene = load("res://assets/models/fbx/swimming_sea_fish.fbx")
	if fish_scene:
		stalker_fish_node = fish_scene.instantiate()
	else:
		stalker_fish_node = Node3D.new()
	stalker_fish_node.name = "StalkerFishShadow3D"
	stalker_fish_node.visible = false
	add_child(stalker_fish_node)

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
		State.WAITING, State.NIBBLING:
			# 本アタリ（HOOKED）より前にボタンを押すと「早アワセ」で魚が逃げる！
			_fish_escaped("【早アワセ】ウキが深く沈む本アタリまで待とう！")
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

func _get_current_power_ratio() -> float:
	# 0.0（0%）からスタートし、1.0（100%）まで滑らかに往復する
	return pingpong(charge_power, 1.0)

func _process(delta: float) -> void:
	_update_state_machine(delta)
	_update_fishing_line()
	if is_autopilot:
		_process_autopilot(delta)

func _update_state_machine(delta: float) -> void:
	var t_sec = Time.get_ticks_msec() / 1000.0
	match current_state:
		State.CHARGING:
			charge_power += charge_speed * delta
			var power_ratio = _get_current_power_ratio()
			if hud: hud.show_cast_gauge(power_ratio)
			if player and player.has_method("play_charge_pose"):
				player.play_charge_pose(power_ratio)

		State.CASTING:
			cast_fly_time += delta
			var t = clamp(cast_fly_time / max(0.2, cast_duration), 0.0, 1.0)
			# 力加減に応じた放物線軌道
			var cur_pos = cast_start_pos.lerp(cast_target_pos, t)
			cur_pos.y += sin(t * PI) * cast_arc_height
			bobber_node.global_position = cur_pos

			if t >= 1.0:
				_on_bobber_landed()

		State.WAITING:
			bobber_timer += delta
			bobber_node.global_position.y = 0.05 + sin(bobber_timer * 2.6) * 0.03
			bobber_node.rotation.z = sin(bobber_timer * 2.3) * 0.07

			wait_timer += delta
			if not fish_approaching:
				if wait_timer >= discover_delay:
					_start_fish_approach()
			else:
				# 3D魚影がウキへ向かって泳ぎ寄ってくる
				approach_progress = move_toward(approach_progress, 1.0, approach_speed * delta)
				var target_edge = cast_target_pos + Vector3(cos(stalker_angle), 0.0, sin(stalker_angle)) * 0.42
				target_edge.y = -0.22
				if stalker_fish_node:
					stalker_fish_node.global_position = stalker_start_pos.lerp(target_edge, approach_progress)
					var dir_to_bob = (cast_target_pos - stalker_fish_node.global_position).normalized()
					stalker_fish_node.rotation.y = atan2(-dir_to_bob.x, -dir_to_bob.z) + sin(t_sec * 10.0) * 0.18
				if approach_progress >= 1.0:
					_start_nibble()

		State.NIBBLING:
			bobber_timer += delta
			wait_timer += delta

			# ツンツン前アタリの沈み込み演出
			if nibble_dip_timer > 0.0:
				nibble_dip_timer -= delta
				bobber_node.global_position.y = -0.09
				bobber_node.rotation.z = sin(t_sec * 24.0) * 0.22
			else:
				bobber_node.global_position.y = 0.04 + sin(bobber_timer * 3.2) * 0.025
				bobber_node.rotation.z = sin(bobber_timer * 2.5) * 0.06

			# 魚影がウキの周りを窺いながら鼻先で突く動き
			if stalker_fish_node:
				stalker_angle += delta * 0.55
				var dist_from_bob = 0.16 if nibble_dip_timer > 0.0 else 0.46
				var offset_vec = Vector3(cos(stalker_angle), 0.0, sin(stalker_angle)) * dist_from_bob
				stalker_fish_node.global_position = Vector3(
					bobber_node.global_position.x + offset_vec.x,
					-0.20,
					bobber_node.global_position.z + offset_vec.z
				)
				var dir_to_bob = (bobber_node.global_position - stalker_fish_node.global_position).normalized()
				stalker_fish_node.rotation.y = atan2(-dir_to_bob.x, -dir_to_bob.z) + sin(t_sec * 12.0) * 0.20

			# ランダムな間隔で次の前アタリ（ツン）または本アタリ（ググッ！）が発生
			if wait_timer >= next_nibble_interval:
				wait_timer = 0.0
				nibble_count += 1
				if nibble_count >= target_nibbles:
					_trigger_hooked()
				else:
					_do_single_nibble()

		State.HOOKED:
			# ウキが水中に深く引き込まれる本アタリ！
			bobber_node.global_position.y = -0.38
			if stalker_fish_node:
				stalker_fish_node.global_position = Vector3(bobber_node.global_position.x - 0.15, -0.32, bobber_node.global_position.z)
				stalker_fish_node.rotation.y = sin(t_sec * 22.0) * 0.35
			wait_timer += delta
			# ランダム化された猶予時間を過ぎるとエサだけ取られて逃げられる
			if wait_timer > hook_window:
				_fish_escaped("【見切り】エサだけ取られて逃げてしまった…！")

		State.FIGHTING:
			_process_fighting(delta)

		State.LANDING_ACTION:
			_process_landing_action(delta)

		State.LANDING:
			pass

# --- 1. キャスト動作（力加減で手前浅瀬〜沖合深場まで明確に変化） ---
func _start_charging() -> void:
	current_state = State.CHARGING
	charge_power = 0.0
	if stalker_fish_node:
		stalker_fish_node.visible = false
	if player:
		player.current_state = CharacterBarlock3D.State.CASTING
		player.facing_dir = 3 # 海側を向く
		player._update_sprite_direction()
	state_changed.emit(current_state)

func _release_cast() -> void:
	var power_ratio = _get_current_power_ratio()
	last_cast_power_ratio = power_ratio
	if hud: hud.hide_cast_gauge()

	current_state = State.CASTING
	cast_fly_time = 0.0
	cast_duration = lerp(0.38, 0.84, power_ratio)
	cast_arc_height = lerp(1.0, 3.2, power_ratio)
	if player and player.has_method("play_cast_swing_anim"):
		player.play_cast_swing_anim()

	var rod_tip = _get_rod_tip_pos()
	cast_start_pos = rod_tip

	# プレイヤーの位置と力加減（0.0〜1.0）から、画面内で「手前（1.5m）〜中間（4.0m）〜沖合（6.8m）」を明確に作り分ける
	var z_target = clamp(player.global_position.z + randf_range(-0.6, 0.6), -14.0, 14.0)
	var shore_x = 0.6 + sin(z_target * 0.16) * 1.1 + cos(z_target * 0.09 + 0.5) * 0.6

	# 大波止（北防波堤 z < -9.2）の上から投げる場合
	if player.global_position.z < -9.2:
		z_target = clamp(player.global_position.z + lerp(2.1, 4.2, power_ratio), -9.0, -5.8)
		var dist_x = lerp(1.2, 5.2, power_ratio)
		cast_target_pos.x = clamp(player.global_position.x - dist_x, -9.6, -2.0)
		cast_target_pos.z = z_target
	# 木製桟橋（z ≈ -3.6）の上から投げる場合
	elif abs(player.global_position.z - (-3.6)) < 1.3 and player.global_position.x < 1.2:
		z_target = player.global_position.z + lerp(1.4, 2.8, power_ratio)
		var dist_x = lerp(1.2, 5.0, power_ratio)
		cast_target_pos.x = clamp(player.global_position.x - dist_x, -9.2, -1.8)
		cast_target_pos.z = z_target
	# 砂浜・波打ち際から投げる場合：汀線からの距離を power_ratio に比例させる（1.2m〜6.5m沖合）
	else:
		var water_offset = lerp(1.1, 6.4, power_ratio)
		var target_x = min(shore_x - water_offset, player.global_position.x - lerp(1.4, 6.8, power_ratio))
		# カメラ画角から絶対にはみ出さない範囲で近い・遠いを表現
		var min_screen_x = max(player.global_position.x - 7.0, -10.5)
		var max_water_x = shore_x - 0.9
		cast_target_pos.x = clamp(target_x, min_screen_x, max_water_x)
		cast_target_pos.z = z_target

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
	fish_approaching = false
	approach_progress = 0.0

	# 魚がウキに気づくまでの時間をランダム化（1.2秒〜4.2秒）
	discover_delay = randf_range(1.2, 4.2)

	var is_night = false
	var parent_world = get_parent()
	if parent_world and "current_time_of_day" in parent_world:
		is_night = parent_world.current_time_of_day > 0.65

	var dist = player.global_position.distance_to(cast_target_pos)
	current_fish = FishDb.get_random_fish(is_night, dist, cast_target_pos.x, last_cast_power_ratio)

	# 着水エフェクト＆着水音
	if fx:
		fx.spawn_water_splash(cast_target_pos, 14, 2.2)
	if SoundManager:
		SoundManager.play_sfx("hit", 0.15, -4.0)
	state_changed.emit(current_state)

func _start_fish_approach() -> void:
	fish_approaching = true
	approach_progress = 0.0
	# 魚のサイズ・警戒心に応じて接近スピードもランダム化
	var w_class = current_fish.get("weight_class", "medium")
	if w_class == "light":
		approach_speed = randf_range(0.55, 0.85)
	elif w_class == "medium":
		approach_speed = randf_range(0.40, 0.65)
	else:
		approach_speed = randf_range(0.28, 0.48) # 大物はゆったり威風堂々と近づく

	# 沖側〜横方向のランダムな角度（2.2m〜3.6m離れた場所）から3D魚影が出現
	stalker_angle = randf_range(PI * 0.55, PI * 1.45)
	var spawn_dist = randf_range(2.2, 3.5)
	stalker_start_pos = cast_target_pos + Vector3(cos(stalker_angle) * spawn_dist, -0.26, sin(stalker_angle) * spawn_dist)

	if stalker_fish_node:
		var s_val: float = current_fish.get("shadow_scale", 0.35)
		stalker_fish_node.scale = Vector3.ONE * s_val
		stalker_fish_node.global_position = stalker_start_pos
		stalker_fish_node.visible = true

	if hud and hud.has_method("show_status_toast"):
		var shadow_hint = "小さな魚影"
		if w_class == "medium":
			shadow_hint = "良型の魚影"
		elif w_class == "heavy":
			shadow_hint = "巨大な魚影"
		hud.show_status_toast("◆ %sがウキに気づいて寄ってきた…！" % shadow_hint, Color(0.75, 0.95, 1.0), 1.8)

# --- 2. 前アタリ（ツンツン） & ランダムな本アタリタイミング ---
func _start_nibble() -> void:
	current_state = State.NIBBLING
	wait_timer = 0.0
	nibble_count = 0

	# 何回目の前アタリで食い込むかを完全にランダム化（1回でいきなり食うこともあれば、4回焦らすこともある）
	var w_class = current_fish.get("weight_class", "medium")
	if w_class == "heavy" and randf() < 0.35:
		target_nibbles = 1 # フィッシュイーターの大物が一撃でひったくるパターン
	else:
		target_nibbles = randi_range(1, 4)

	_do_single_nibble()
	state_changed.emit(current_state)

func _do_single_nibble() -> void:
	nibble_dip_timer = randf_range(0.18, 0.32)
	# 次のアタリまでの間隔も毎回ランダム（0.55秒〜2.1秒）にしてタイミングを読ませない
	next_nibble_interval = randf_range(0.55, 2.10)
	if fx:
		fx.spawn_water_ripple(bobber_node.global_position, 0.65)
	if SoundManager:
		SoundManager.play_sfx("hit", 0.08, -11.0)

func _trigger_hooked() -> void:
	current_state = State.HOOKED
	wait_timer = 0.0
	# アワセの猶予時間も魚によって0.85秒〜1.30秒にランダム化
	hook_window = randf_range(0.88, 1.30)

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
	# 実際の着水距離に応じた初期ファイト距離（最低でも4.0m〜10.5mの手応えある距離を確保）
	var raw_dist = player.global_position.distance_to(bobber_node.global_position)
	var w_class = current_fish.get("weight_class", "medium")
	var bonus_dist = 1.5 if w_class == "light" else (3.5 if w_class == "medium" else 6.0)
	fight_distance = raw_dist + bonus_dist

	fish_stamina = 1.0
	is_fish_dashing = (w_class != "light") # 中型・大型はフッキング直後にまずファーストランで突っ込む！
	dash_state_timer = 0.0
	dash_state_duration = randf_range(1.1, 2.0) if is_fish_dashing else randf_range(1.2, 2.2)
	fish_pull_timer = 0.0
	is_reeling = false

	if hud:
		hud.show_fight_ui(current_fish.get("name", "魚"), current_fish.get("weight_label", ""))
	if companion and companion.has_method("_update_sprite_direction"):
		companion.facing_dir = 3 # 海を向いて応援
		companion._update_sprite_direction()
	state_changed.emit(current_state)

# --- 3. 本格ファイトシステム（軽量級・中量級・重量級で挙動と難易度が明確に変化） ---
func _process_fighting(delta: float) -> void:
	var fish_power: float = current_fish.get("power", 1.0)
	var pull_freq: float = current_fish.get("pull_freq", 2.0)
	var w_class: String = current_fish.get("weight_class", "medium")
	var reel_speed_mult: float = current_fish.get("reel_speed_mult", 0.85)
	var dash_pull_speed: float = current_fish.get("dash_pull_speed", 1.4)
	var max_stamina_sec: float = current_fish.get("stamina", 10.0)

	# 魚のスタミナ減少（適正テンション 0.35〜0.80 を維持すると効果的に体力を削れる）
	var stamina_drain = (1.0 / max(4.0, max_stamina_sec)) * delta
	if fight_tension >= 0.40 and fight_tension <= 0.82:
		stamina_drain *= 1.35
	fish_stamina = max(0.0, fish_stamina - stamina_drain)

	# 「突っ込み（Dash）」と「溜め・休憩（Rest）」のランダム切り替え
	dash_state_timer += delta
	if dash_state_timer >= dash_state_duration:
		dash_state_timer = 0.0
		if is_fish_dashing:
			is_fish_dashing = false
			# 疲れてくるほど休憩時間が長くなる
			dash_state_duration = randf_range(1.3, 2.5) * lerp(1.4, 0.85, fish_stamina)
		else:
			# スタミナが残っているほど高確率で再び突っ込む
			var dash_chance = lerp(0.25, 0.88, fish_stamina)
			if w_class == "heavy":
				dash_chance = max(dash_chance, 0.55)
			is_fish_dashing = (randf() < dash_chance)
			dash_state_duration = randf_range(0.9, 2.2) * lerp(0.65, 1.15, fish_stamina)
			if is_fish_dashing and fx:
				fx.spawn_water_splash(bobber_node.global_position, 10, 2.2)

	fish_pull_timer += delta * pull_freq * (1.6 if is_fish_dashing else 0.8)
	var pulse = (sin(fish_pull_timer) + 1.0) * 0.5

	# --- テンションと距離の計算 ---
	var tension_delta = 0.0
	var dist_delta = 0.0

	if is_reeling:
		# 軽い魚でも口切れしやすいようテンションが上がり、重い魚ほど突っ込み中に巻くと急激にレッドゾーンへ行く
		var reel_tension_rate = 0.52
		if w_class == "light":
			reel_tension_rate = 0.62 # 小型魚は強引に巻きすぎると口切れしやすい
		elif is_fish_dashing:
			reel_tension_rate = 0.78 * fish_power # 突っ込み中に無理に巻くと一気に切れる！

		tension_delta += reel_tension_rate * delta

		# 巻き上げ速度：魚が突っ込んでいる最中はほとんど寄らず、止まっている時に巻くと寄ってくる
		var base_reel_speed = 1.65 * reel_speed_mult
		if is_fish_dashing:
			dist_delta -= base_reel_speed * 0.20 * delta
		else:
			dist_delta -= base_reel_speed * lerp(1.35, 0.90, fish_stamina) * delta

		reel_sound_timer += delta
		if reel_sound_timer >= 0.16:
			reel_sound_timer = 0.0
			if SoundManager:
				SoundManager.play_sfx("reel", 0.1, -5.0)
	else:
		# リールを止めている時：突っ込み中ならテンションを適度に逃がして耐え、止まっている時に放置するとすぐ緩んでバレる
		if is_fish_dashing:
			tension_delta -= 0.22 * delta
		else:
			tension_delta -= 0.46 * delta

	# 魚の引きによるテンション上昇＆沖への疾走（距離増加）
	if is_fish_dashing:
		var pull_strength = (0.42 + pulse * 0.35) * fish_power * lerp(0.6, 1.1, fish_stamina)
		tension_delta += pull_strength * delta
		# リールを巻いていない、または重量級がダッシュしている時は糸を出して沖へ走る！
		if not is_reeling or w_class == "heavy":
			var run_factor = 0.45 if is_reeling else 1.0
			dist_delta += dash_pull_speed * run_factor * lerp(0.5, 1.0, fish_stamina) * delta
	else:
		tension_delta += pulse * 0.14 * fish_power * delta

	fight_tension = clamp(fight_tension + tension_delta, 0.0, 1.05)
	fight_distance = max(0.0, fight_distance + dist_delta)

	# 魚が水面で激しく暴れる飛沫演出
	if is_fish_dashing and randf() < 0.28 and fx:
		fx.spawn_water_splash(bobber_node.global_position, 7, 2.0)

	# 3D上のウキと魚影の位置を残り距離に合わせて更新
	var dir_from_player = (bobber_node.global_position - player.global_position)
	dir_from_player.y = 0.0
	if dir_from_player.length() < 0.05:
		dir_from_player = Vector3(-1.0, 0.0, 0.0)
	dir_from_player = dir_from_player.normalized()

	var visual_dist = clamp(fight_distance * 0.62, 1.3, 7.2)
	var sway_z = sin(fish_pull_timer * 1.7) * (0.45 if is_fish_dashing else 0.15)
	bobber_node.global_position.x = player.global_position.x + dir_from_player.x * visual_dist
	bobber_node.global_position.z = clamp(player.global_position.z + dir_from_player.z * visual_dist + sway_z * delta * 8.0, -14.0, 14.0)
	bobber_node.global_position.y = 0.02 + sin(fish_pull_timer * 4.0) * 0.12

	if stalker_fish_node:
		stalker_fish_node.visible = true
		stalker_fish_node.global_position = Vector3(bobber_node.global_position.x - 0.18, -0.22, bobber_node.global_position.z)
		stalker_fish_node.rotation.y = atan2(dir_from_player.x, dir_from_player.z) + sin(fish_pull_timer * 5.0) * 0.45

	if player and player.has_method("play_fight_pose"):
		player.play_fight_pose(is_reeling, is_fish_dashing, Time.get_ticks_msec() / 1000.0)

	if hud:
		hud.update_fight_status(fight_tension, fight_distance, is_reeling, is_fish_dashing, fish_stamina)

	# 勝敗判定
	if fight_tension >= 0.98:
		if w_class == "light":
			_fish_escaped("【口切れ】小型魚はテンションを上げすぎないよう注意！")
		else:
			_fish_escaped("【糸切れ】魚が突っ込む時はリールを離して耐えよう！")
	elif fight_tension <= 0.08:
		_fish_escaped("【バラシ】糸が緩みすぎて針が外れてしまった…！")
	elif fight_distance <= 1.2:
		_start_landing_action()

func _fish_escaped(reason: String) -> void:
	current_state = State.IDLE
	is_reeling = false
	if hud:
		hud.hide_cast_gauge()
		hud.hide_fight_ui()
		if hud.has_method("show_status_toast"):
			hud.show_status_toast(reason, Color(1.0, 0.45, 0.35), 2.8)
	if bobber_node:
		bobber_node.visible = false
	if stalker_fish_node:
		stalker_fish_node.visible = false
	if player:
		player.current_state = CharacterBarlock3D.State.IDLE
		if player.has_method("reset_pose"):
			player.reset_pose()
	state_changed.emit(current_state)

# --- 4. 釣り上げアクション（抜き上げ弧軌道＆バーロック歓喜モーション）＆ 釣果表示 ---
func _start_landing_action() -> void:
	current_state = State.LANDING_ACTION
	is_reeling = false
	landing_anim_timer = 0.0
	landing_duration = 0.82
	landing_start_pos = bobber_node.global_position

	if hud:
		hud.hide_fight_ui()
		if hud.has_method("show_status_toast"):
			hud.show_status_toast("★ 抜き上げ！！ 豪快に釣り上げたぞ！", Color(1.0, 0.92, 0.35), 1.2)

	if player and player.has_method("play_landing_heave_anim"):
		player.play_landing_heave_anim()

	if fx:
		fx.spawn_water_splash(landing_start_pos, 22, 3.2)
	if SoundManager:
		SoundManager.play_sfx("catch", 0.08, 0.0)

	if stalker_fish_node:
		stalker_fish_node.visible = true
		stalker_fish_node.global_position = landing_start_pos

	state_changed.emit(current_state)

func _process_landing_action(delta: float) -> void:
	landing_anim_timer += delta
	var t = clamp(landing_anim_timer / max(0.2, landing_duration), 0.0, 1.0)
	var hand_target = (player.global_position + Vector3(-0.55, 1.05, 0.0)) if player else landing_start_pos

	# 水面からバーロック船長の手元へ高い弧を描いて魚が飛んでくる！
	var cur_pos = landing_start_pos.lerp(hand_target, t)
	cur_pos.y += sin(t * PI) * 2.35
	if bobber_node:
		bobber_node.global_position = cur_pos + Vector3(0.0, 0.22, 0.0)
	if stalker_fish_node:
		stalker_fish_node.global_position = cur_pos
		stalker_fish_node.rotation.y += delta * 14.0
		stalker_fish_node.rotation.z = sin(t * TAU * 2.0) * 0.45

	if t >= 1.0:
		_land_fish()

func _land_fish() -> void:
	current_state = State.LANDING
	is_reeling = false

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

	if bobber_node:
		bobber_node.visible = false
	if stalker_fish_node:
		stalker_fish_node.visible = false
		stalker_fish_node.rotation.z = 0.0

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
		if player.has_method("reset_pose"):
			player.reset_pose()
	state_changed.emit(current_state)

# 竿先位置取得
func _get_rod_tip_pos() -> Vector3:
	if not player: return Vector3.ZERO
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
		if hud:
			hud.hide_cast_gauge()
			hud.hide_fight_ui()
			if hud.result_dialog and hud.result_dialog.visible:
				hud.hide_catch_result()
		if bobber_node:
			bobber_node.visible = false
		if stalker_fish_node:
			stalker_fish_node.visible = false
		current_state = State.IDLE
		if player:
			player.current_state = CharacterBarlock3D.State.IDLE
			if player.has_method("reset_pose"):
				player.reset_pose()
		state_changed.emit(current_state)
	print("AUTOPILOT MODE: ", "ENABLED" if enabled else "DISABLED")

func _process_autopilot(delta: float) -> void:
	autopilot_step_timer += delta
	match current_state:
		State.IDLE:
			if autopilot_step_timer > 1.2:
				autopilot_step_timer = 0.0
				# 毎回ランダムな飛距離（ちょい投げ〜遠投）を狙う
				autopilot_target_power = randf_range(0.18, 0.95)
				_on_action_pressed()

		State.CHARGING:
			var power_ratio = _get_current_power_ratio()
			if abs(power_ratio - autopilot_target_power) < 0.06 and autopilot_step_timer > 0.15:
				_on_action_released()

		State.HOOKED:
			if autopilot_step_timer > 0.22:
				autopilot_step_timer = 0.0
				_on_action_pressed()

		State.FIGHTING:
			# 魚の突っ込み中は無理に巻かず、テンションをコントロールする熟練AI
			if is_fish_dashing and fight_tension > 0.58:
				is_reeling = false
			elif fight_tension < 0.64:
				is_reeling = true
			elif fight_tension > 0.78:
				is_reeling = false

		State.LANDING:
			if autopilot_step_timer > 2.5:
				autopilot_step_timer = 0.0
				if hud:
					hud.hide_catch_result()
