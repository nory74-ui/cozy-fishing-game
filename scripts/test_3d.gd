extends SceneTree

func _init() -> void:
	print("TEST_3D_START")
	var root = Node3D.new()
	var cam = Camera3D.new()
	cam.position = Vector3(0, 5, 10)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	root.add_child(cam)
	
	var box = CSGBox3D.new()
	box.size = Vector3(4, 1, 4)
	root.add_child(box)
	
	print("Node3D, Camera3D, CSGBox3D instantiated successfully!")
	quit(0)
