extends SceneTree

func _init() -> void:
	# Mainシーンをロードして1フレーム描画
	var main_scene = load("res://scenes/main.tscn")
	var root_node = main_scene.instantiate()
	root.add_child(root_node)
