extends Node

# --- サウンド管理シングルトン (Autoload: SoundManager) ---

var bgm_player: AudioStreamPlayer
var current_bgm_name: String = ""
var bgm_volume_db: float = -6.0

var sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 12

var audio_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	add_child(bgm_player)
	
	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)
		
	_preload_all()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		cleanup()

func _exit_tree() -> void:
	cleanup()

func cleanup() -> void:
	if is_instance_valid(bgm_player):
		bgm_player.stop()
		bgm_player.stream = null
	for p in sfx_players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	audio_cache.clear()

func _preload_all() -> void:
	# BGM
	_load_sound("bgm_title", "res://assets/audio/bgm_title.ogg", true)
	_load_sound("bgm_fishing", "res://assets/audio/bgm_fishing.ogg", true)
	
	# SFX
	_load_sound("cast", "res://assets/audio/sfx_cast.wav")
	_load_sound("hit", "res://assets/audio/sfx_hit.wav")
	_load_sound("reel", "res://assets/audio/sfx_reel.wav")
	_load_sound("catch", "res://assets/audio/sfx_catch.wav")
	_load_sound("coin", "res://assets/audio/sfx_coin.wav")
	_load_sound("book", "res://assets/audio/sfx_book.wav")
	_load_sound("step", "res://assets/audio/sfx_step.wav")

func _load_sound(sound_id: String, res_path: String, is_loop: bool = false) -> void:
	var stream: AudioStream = null
	
	# 1. 通常の ResourceLoader
	if ResourceLoader.exists(res_path):
		stream = load(res_path)
		
	# 2. フォールバック（直接ファイル読み込み）
	if not stream:
		var global_path = ProjectSettings.globalize_path(res_path)
		if res_path.ends_with(".ogg"):
			stream = AudioStreamOggVorbis.load_from_file(global_path)
		elif res_path.ends_with(".wav"):
			stream = _load_wav_file(global_path)
			
	if stream:
		if is_loop:
			if stream is AudioStreamOggVorbis:
				stream.loop = true
			elif stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		audio_cache[sound_id] = stream
	else:
		push_warning("SoundManager: Failed to load sound: " + res_path)

# WAVファイルの動的ローダー
func _load_wav_file(path: String) -> AudioStreamWAV:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return null
	
	var bytes = file.get_buffer(file.get_length())
	file.close()
	
	if bytes.size() < 44: return null
	
	# RIFF ヘッダー検証
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF": return null
	if bytes.slice(8, 12).get_string_from_ascii() != "WAVE": return null
	
	var wav = AudioStreamWAV.new()
	var pos = 12
	var data_pos = 0
	var data_size = 0
	
	while pos < bytes.size() - 8:
		var chunk_id = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var chunk_size = bytes.decode_u32(pos + 4)
		pos += 8
		
		if chunk_id == "fmt ":
			var format_tag = bytes.decode_u16(pos)
			var channels = bytes.decode_u16(pos + 2)
			var sample_rate = bytes.decode_u32(pos + 4)
			var bits_per_sample = bytes.decode_u16(pos + 14)
			
			wav.stereo = (channels == 2)
			wav.mix_rate = sample_rate
			
			if bits_per_sample == 16:
				wav.format = AudioStreamWAV.FORMAT_16_BITS
			elif bits_per_sample == 8:
				wav.format = AudioStreamWAV.FORMAT_8_BITS
			else:
				# 24bit等の場合
				wav.format = AudioStreamWAV.FORMAT_16_BITS
		elif chunk_id == "data":
			data_pos = pos
			data_size = chunk_size
			break
			
		pos += chunk_size
		
	if data_pos > 0 and data_size > 0:
		wav.data = bytes.slice(data_pos, data_pos + data_size)
		return wav
		
	return null

# --- BGM コントロール ---

func play_bgm(bgm_id: String, fade_time: float = 1.0) -> void:
	if current_bgm_name == bgm_id and bgm_player.playing:
		return
		
	var stream: AudioStream = audio_cache.get(bgm_id)
	if not stream:
		push_warning("SoundManager: BGM not found: " + bgm_id)
		return
		
	current_bgm_name = bgm_id
	
	if bgm_player.playing and fade_time > 0.0:
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -60.0, fade_time * 0.5)
		tween.tween_callback(func():
			bgm_player.stream = stream
			bgm_player.play()
			var tween_in = create_tween()
			tween_in.tween_property(bgm_player, "volume_db", bgm_volume_db, fade_time * 0.5)
		)
	else:
		bgm_player.stream = stream
		bgm_player.volume_db = bgm_volume_db
		bgm_player.play()

func stop_bgm(fade_time: float = 0.8) -> void:
	current_bgm_name = ""
	if bgm_player.playing:
		if fade_time > 0.0:
			var tween = create_tween()
			tween.tween_property(bgm_player, "volume_db", -60.0, fade_time)
			tween.tween_callback(func(): bgm_player.stop())
		else:
			bgm_player.stop()

# --- SFX コントロール ---

func play_sfx(sfx_id: String, pitch_rnd: float = 0.06, volume_db: float = 0.0) -> void:
	var stream: AudioStream = audio_cache.get(sfx_id)
	if not stream:
		return
		
	# プールから空いているプレイヤーを探す
	var player: AudioStreamPlayer = null
	for p in sfx_players:
		if not p.playing:
			player = p
			break
			
	# 全て再生中の場合は最初のプレイヤーを再利用
	if not player:
		player = sfx_players[0]
		
	player.stream = stream
	player.volume_db = volume_db
	if pitch_rnd > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_rnd, 1.0 + pitch_rnd)
	else:
		player.pitch_scale = 1.0
		
	player.play()
