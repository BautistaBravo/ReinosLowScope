extends Control

func _ready():
	var vbox = VBoxContainer.new()
	# Center the container
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(vbox)

	var title = Label.new()
	title.text = "Low Scope RPG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var btn_new = Button.new()
	btn_new.text = "New Game"
	btn_new.pressed.connect(_on_new_game_pressed)
	vbox.add_child(btn_new)

	var btn_load = Button.new()
	btn_load.text = "Load Game"
	btn_load.pressed.connect(_on_load_game_pressed)
	vbox.add_child(btn_load)

func _on_new_game_pressed():
	GameManager.new_game()
	get_tree().change_scene_to_file("res://scenes/LevelSelector.tscn")

func _on_load_game_pressed():
	if GameManager.load_game():
		get_tree().change_scene_to_file("res://scenes/LevelSelector.tscn")
	else:
		print("No save file found!")
