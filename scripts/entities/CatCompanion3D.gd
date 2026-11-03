extends CharacterBody3D

@export var target_node: Node3D = null

var tex_front: Texture2D
var tex_back: Texture2D
var tex_side: Texture2D
var sprite: Sprite3D

var anim_tick: float = 0.0

func _ready() -> void:
	tex_front = load("res://assets/characters/mike_cat_front.png")
	tex_back = load("res://assets/characters/mike_cat_back.png")
	tex_side = load("res://assets/characters/mike_cat_side.png")
	
	sprite = Sprite3D.new()
	sprite.name = "CatSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = 0.0055
	sprite.position = Vector3(0, 0.45, 0)
	sprite.texture = tex_front
	add_child(sprite)

func _physics_process(delta: float) -> void:
	if not target_node: return
	
	var diff = target_node.global_position - global_position
	var dist = diff.length()
	
	if dist > 2.0:
		var dir = diff.normalized()
		velocity.x = dir.x * 4.5
		velocity.z = dir.z * 4.5
		
		if abs(dir.x) > abs(dir.z):
			sprite.texture = tex_side
			sprite.flip_h = (dir.x < 0)
		else:
			if dir.z > 0:
				sprite.texture = tex_front
			else:
				sprite.texture = tex_back
		anim_tick += delta * 12.0
		sprite.position.y = 0.45 + sin(anim_tick) * 0.03
	else:
		velocity.x = move_toward(velocity.x, 0, 4.0)
		velocity.z = move_toward(velocity.z, 0, 4.0)
		sprite.position.y = 0.45
		
	move_and_slide()
