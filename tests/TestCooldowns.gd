extends Node

var controller

func _ready():
	print("Test Cooldowns Started")
	_setup_game_data()

	controller = load("res://scripts/scenes/CombatController.gd").new()
	add_child(controller)

	# Mock signal connections
	controller.combat_state_changed.connect(func(_a): pass)
	controller.log_message.connect(func(t): print("LOG: ", t))
	controller.party_updated.connect(func(_a, _b, _c): pass)
	controller.enemy_updated.connect(func(_a, _b): pass)

	controller.init_combat()
	await get_tree().create_timer(0.1).timeout # Init frame

	# Skip start delay manually
	controller.is_combat_active = true

	_test_ai_cooldown()

func _setup_game_data():
	# 2 Heroes. Hero 0 controlled. Hero 1 AI.
	GameManager.party = [
		{ "name": "HeroPlayer", "hp": 50, "max_hp": 50, "base_stamina": 100, "base_stamina_regen": 1.0, "skills": {}, "equipment": {} },
		{ "name": "HeroAI", "hp": 50, "max_hp": 50, "base_stamina": 100, "base_stamina_regen": 100.0, "skills": {}, "equipment": {} }
	]

	GameManager.selected_level = 1
	GameManager.level_database = { "1": { "enemies": ["test_enemy"] } }
	GameManager.enemy_database = {
		"test_enemy": { "name": "Enemy1", "hp": 100, "max_hp": 100, "damage": 1, "speed": 100.0, "ai_type": "random" }
	}

func _test_ai_cooldown():
	print("--- Testing AI Party Cooldown ---")
	# HeroAI (idx 1) has high regen, so should fill stamina instantly in _process

	# Force stamina to trigger threshold
	controller.party_stamina[1] = 30.0

	# Run one frame
	controller._process(0.1)

	# Check if acted
	# Since acting consumes 30 stamina, if it acted, stamina should be roughly (30 - 30 + regen*0.1) ~ 10.
	# If it didn't act, stamina would be (30 + regen*0.1) ~ 40.
	# Regen is 100.0/sec.
	# If act: 30 - 30 + 10 = 10.
	# If no act: 30 + 10 = 40.

	var stam = controller.party_stamina[1]
	print("Stamina after Frame 1: ", stam)

	if stam < 20:
		print("Hero acted (Correct)")
	else:
		print("Hero DID NOT act (Unexpected)")

	# Check Cooldown
	var cd = controller.party_action_cooldowns[1]
	print("Cooldown after Frame 1: ", cd)
	if cd > 1.8:
		print("Cooldown set (Correct)")
	else:
		print("Cooldown NOT set (Fail)")

	# Advance time 1.0s
	controller._process(1.0)
	cd = controller.party_action_cooldowns[1]
	print("Cooldown after 1.0s: ", cd)

	# Force Stamina again to ensure it WOULD act if not for cooldown
	controller.party_stamina[1] = 30.0

	controller._process(0.1)
	stam = controller.party_stamina[1]
	print("Stamina after Frame 3 (Cooldown active): ", stam)

	# Should NOT act. Stamina should act accum: 30 + 10 = 40.
	if stam > 35:
		print("Hero waited for cooldown (Correct)")
	else:
		print("Hero acted despite cooldown (Fail)")

	# Advance remaining cooldown (approx 1.0s left)
	controller._process(1.5)
	print("Cooldown should be 0: ", controller.party_action_cooldowns[1])

	# Force stamina
	controller.party_stamina[1] = 30.0
	controller._process(0.1)
	stam = controller.party_stamina[1]
	print("Stamina after Cooldown expire: ", stam)

	if stam < 20:
		print("Hero acted again (Correct)")
	else:
		print("Hero DID NOT act (Fail)")

	print("ALL TESTS PASSED")
	get_tree().quit()
