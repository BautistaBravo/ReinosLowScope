extends Node

var controller

func _ready():
	print("Test Runner Started")
	_setup_game_data()

	controller = load("res://scripts/scenes/CombatController.gd").new()
	add_child(controller)

	controller.targeting_mode_changed.connect(_on_targeting)
	controller.combat_ended.connect(_on_end)

	print("Initing Combat...")
	controller.init_combat()

	# Wait for start delay (2.0s in controller) + buffer
	await get_tree().create_timer(2.2).timeout

	_test_input_logic()

func _setup_game_data():
	# Mock Party
	GameManager.party = [
		{
			"name": "Hero1", "hp": 50, "max_hp": 50, "base_stamina": 100,
			"base_stamina_regen": 50.0, # High regen for test to ensure enough stam
			"skills": {}, "equipment": {}
		},
		{
			"name": "Hero2", "hp": 50, "max_hp": 50, "base_stamina": 100,
			"base_stamina_regen": 50.0,
			"skills": {}, "equipment": {}
		}
	]

	# Mock Level
	GameManager.selected_level = 1
	# Mock databases directly in GameManager since init_combat reads GameManager.get_level_data which reads databases
	GameManager.level_database = {
		"1": { "enemies": ["test_slime"] }
	}
	GameManager.enemy_database = {
		"test_slime": { "name": "Slime", "hp": 10, "max_hp": 10, "damage": 1, "ai_type": "random" }
	}

func _test_input_logic():
	print("Testing Input...")

	# Test TAB switching (This was the crasher)
	var ev_tab = InputEventKey.new()
	ev_tab.keycode = KEY_TAB
	ev_tab.pressed = true
	controller.handle_input(ev_tab)
	print("TAB Pressed - If you see this, no crash!")

	# Test Q Input
	var ev_q = InputEventKey.new()
	ev_q.keycode = KEY_Q
	ev_q.pressed = true
	controller.handle_input(ev_q)

	# Wait a bit for cooldown? Controller has 0.5s cooldown.
	await get_tree().create_timer(0.6).timeout

	var ev_w = InputEventKey.new()
	ev_w.keycode = KEY_W
	ev_w.pressed = true
	controller.handle_input(ev_w)

	await get_tree().create_timer(0.6).timeout

	var ev_e = InputEventKey.new()
	ev_e.keycode = KEY_E
	ev_e.pressed = true
	controller.handle_input(ev_e)

	print("ALL TESTS PASSED")
	get_tree().quit(0)

func _on_targeting(is_targeting, text):
	print("Signal targeting_mode_changed: ", text)

func _on_end(victory):
	print("Combat Ended: ", victory)
