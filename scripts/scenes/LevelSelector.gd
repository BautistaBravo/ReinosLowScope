extends Control

func _ready():
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(vbox)

	var label = Label.new()
	label.text = "Select Level"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var grid = GridContainer.new()
	grid.columns = 3
	vbox.add_child(grid)

	for i in range(1, 6): # Levels 1 to 5
		var btn = Button.new()
		btn.text = "Level " + str(i)
		btn.custom_minimum_size = Vector2(100, 50)
		btn.pressed.connect(_on_level_selected.bind(i))
		grid.add_child(btn)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)

	var back_btn = Button.new()
	back_btn.text = "Back to Menu"
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)

func _on_level_selected(level_idx):
	GameManager.selected_level = level_idx
	get_tree().change_scene_to_file("res://scenes/Combat.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
