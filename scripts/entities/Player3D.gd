extends CharacterBody3D

signal cast_bobber(target_pos: Vector3)
signal retrieve_bobber

const SPEED = 5.5
const JUMP_VELOCITY = 4.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var sprite: Sprite3D
var shadow: Decal

var tex_front: Texture2D
var tex_back: Texture2D
var tex_side: Texture2D

enum Facing { DOWN, UP, LEFT, RIGHT }
var current_facing: Facing = Facing.DOWN
var is_casting: bool = false
var anim_tick: float = 0.0

func _ready() -> void:
	tex_front = load("res://assets/characters/captain_barlock_front.png")
	tex_back = load("res://assets/characters/captain_barlock_back.png")
	tex_side = load("res://assets/characters/captain_barlock_side.png")
	
	if not sprite:
		sprite = Sprite3D.new()
		sprite.name = "Sprite3D"
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.pixel_size = 0.0055
		sprite.position = Vector3(0, 0.9, 0)
		add_child(sprite)
	
	_update_sprite()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_casting:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		move_and_slide()
		return

	# 入力ベクトル（カメラ視点に合わせた3D移動）
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0

	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction != Vector3.ZERO:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		# 向きの決定
		if abs(direction.x) > abs(direction.z):
			if direction.x > 0:
				current_facing = Facing.RIGHT
			else:
				current_facing = Facing.LEFT
		else:
			if direction.z > 0:
				current_facing = Facing.DOWN
			else:
				current_facing = Facing.UP
				
		anim_tick += delta * 10.0
		sprite.position.y = 0.9 + sin(anim_tick) * 0.04 # 歩行アニメーションのピッチ
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		sprite.position.y = 0.9
		
	_update_sprite()
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		if not is_casting:
			_cast()
		else:
			_retrieve()

func _cast() -> void:
	is_casting = true
	# プレイヤーの向いている方向の前方水面へキャスト
	var f_vec = Vector3.ZERO
	match current_facing:
		Facing.DOWN: f_vec = Vector3(0, 0, 8.0)
		Facing.UP: f_vec = Vector3(0, 0, -8.0)
		Facing.LEFT: f_vec = Vector3(-8.0, 0, 0)
		Facing.RIGHT: f_vec = Vector3(8.0, 0, 0)
		
	var target = global_position + f_vec
	target.y = 0.1 # 水面高さ
	cast_bobber.emit(target)

func _retrieve() -> void:
	is_casting = false
	retrieve_bobber.emit()

func _update_sprite() -> void:
	if not sprite: return
	match current_facing:
		Facing.DOWN:
			sprite.texture = tex_front
			sprite.flip_h = false
		Facing.UP:
			sprite.texture = tex_back
			sprite.flip_h = false
		Facing.LEFT:
			sprite.texture = tex_side
			sprite.flip_h = true
		Facing.RIGHT:
			sprite.texture = tex_side
			sprite.flip_h = false
