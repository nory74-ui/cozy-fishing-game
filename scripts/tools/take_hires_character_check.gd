extends SceneTree

func _init() -> void:
	print("Starting character hires visual inspection...")
	var main_scene = load("res://scenes/world3d/World3D.tscn").instantiate()
	root.add_child(main_scene)
	
	# Let game settle
	for i in range(25):
		await process_frame
	
	# Capture standard wide angle
	capture_screen("nogita_check_wide.png")
	
	# Move camera to close up on Barlock and Mike
	var camera = main_scene.get_node_or_null("Camera3D")
	var player = main_scene.get_node_or_null("Player3D")
	if camera and player:
		# Front close up
		camera.global_position = player.global_position + Vector3(0, 1.2, 2.5)
		camera.look_at(player.global_position + Vector3(0, 0.7, 0), Vector3.UP)
		for i in range(5):
			await process_frame
		capture_screen("nogita_check_barlock_front.png")
		
		# 3/4 quarter view close up
		camera.global_position = player.global_position + Vector3(1.8, 1.4, 2.0)
		camera.look_at(player.global_position + Vector3(0, 0.6, 0), Vector3.UP)
		for i in range(5):
			await process_frame
		capture_screen("nogita_check_barlock_quarter.png")
		
		# Cat close up
		var cat = main_scene.get_node_or_null("CompanionMike")
		if cat:
			camera.global_position = cat.global_position + Vector3(0.8, 0.6, 1.0)
			camera.look_at(cat.global_position + Vector3(0, 0.25, 0), Vector3.UP)
			for i in range(5):
				await process_frame
			capture_screen("nogita_check_cat_close.png")
			
	print("Captures complete!")
	quit()

func capture_screen(filename: String) -> void:
	var img = root.get_viewport().get_texture().get_image()
	var path = "/Users/nryktnk/.gemini/antigravity/brain/f5531dde-ea5d-4b53-bd51-7f2c584e7f31/" + filename
	img.save_png(path)
	print("Saved capture: ", path)
