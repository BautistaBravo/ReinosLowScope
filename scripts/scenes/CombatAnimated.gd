extends Control

var controller
var stamina_bar
var input_label
var log_label
var party_container
var enemy_container

func _ready():
	controller = load("res://scripts/scenes/CombatController.gd").new()
	controller.name = "Controller"
	add_child(controller)

	controller.combat_state_changed.connect(_on_state_changed)
	controller.log_message.connect(_on_log)
	controller.player_stamina_updated.connect(_on_player_stamina)
	controller.party_updated.connect(_on_party_updated)
	controller.enemy_updated.connect(_on_enemy_updated)
	controller.targeting_mode_changed.connect(_on_targeting)
	controller.combat_ended.connect(_on_combat_ended)

	_build_visuals()

func _build_visuals():
	# Background
	var bg = TextureRect.new()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ph = PlaceholderTexture2D.new()
	ph.size = Vector2(1152, 648)
	bg.texture = ph
	bg.modulate = Color(0.2, 0.05, 0.05) # Dark Red for Combat
	add_child(bg)

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Top Bar
	var top = HBoxContainer.new()
	root.add_child(top)

	var stam_lbl = Label.new()
	stam_lbl.text = "Player Stamina"
	top.add_child(stam_lbl)

	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(300, 20)
	top.add_child(stamina_bar)

	input_label = Label.new()
	input_label.text = "Input: "
	top.add_child(input_label)

	# Battle Area
	var battle = HBoxContainer.new()
	battle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(battle)

	party_container = VBoxContainer.new()
	party_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_container.alignment = BoxContainer.ALIGNMENT_CENTER
	battle.add_child(party_container)

	enemy_container = VBoxContainer.new()
	enemy_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	battle.add_child(enemy_container)

	log_label = Label.new()
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(log_label)

func _input(event):
	# Delegate input to controller
	controller.handle_input(event)

# --- Signal Callbacks ---

func _on_state_changed(is_active):
	# Could animate UI entrance
	pass

func _on_log(text):
	log_label.text = text

func _on_player_stamina(current, max_val):
	stamina_bar.max_value = max_val
	stamina_bar.value = current

func _on_party_updated(party_data, party_stamina, party_max_stamina):
	for c in party_container.get_children():
		c.queue_free()

	for i in range(party_data.size()):
		var member = party_data[i]
		var hbox = HBoxContainer.new()
		party_container.add_child(hbox)

		# Sprite
		var icon = TextureRect.new()
		icon.texture = _create_placeholder(Color.BLUE)
		icon.custom_minimum_size = Vector2(64, 64)
		hbox.add_child(icon)

		var info_box = VBoxContainer.new()
		hbox.add_child(info_box)

		var lbl = Label.new()
		lbl.text = member["name"]
		info_box.add_child(lbl)

		# Calc Stats for HP bar (need effective max)
		var bonus_hp = GameManager.get_member_effective_stat(i, "hp", 0)
		var total_max_hp = member["max_hp"] + bonus_hp

		var hp_bar = ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(100, 10)
		hp_bar.max_value = total_max_hp
		hp_bar.value = member["hp"]
		hp_bar.modulate = Color.RED
		info_box.add_child(hp_bar)

		var stam_bar = ProgressBar.new()
		stam_bar.custom_minimum_size = Vector2(100, 8)
		stam_bar.max_value = party_max_stamina[i]
		stam_bar.value = party_stamina[i]
		stam_bar.modulate = Color.YELLOW
		info_box.add_child(stam_bar)

func _on_enemy_updated(enemies, selected_idx):
	for c in enemy_container.get_children():
		c.queue_free()

	for i in range(enemies.size()):
		var enemy = enemies[i]
		if enemy["hp"] <= 0:
			# Dead placeholder
			var dead = TextureRect.new()
			dead.texture = _create_placeholder(Color(0.2, 0.2, 0.2))
			dead.custom_minimum_size = Vector2(64, 64)
			enemy_container.add_child(dead)
			continue

		var vbox = VBoxContainer.new()
		enemy_container.add_child(vbox)

		var sprite = TextureRect.new()
		sprite.texture = _create_placeholder(Color.RED)
		sprite.custom_minimum_size = Vector2(64, 64)

		# Highlight selection
		if i == selected_idx:
			sprite.modulate = Color(1.5, 1.5, 0.5) # Glow

		vbox.add_child(sprite)

		var lbl = Label.new()
		lbl.text = enemy["name"] + "\nHP: " + str(enemy["hp"])
		vbox.add_child(lbl)

func _on_targeting(is_targeting, text):
	input_label.text = text
	if is_targeting:
		input_label.modulate = Color.YELLOW
	else:
		input_label.modulate = Color.WHITE

func _on_combat_ended(victory):
	if victory:
		# Return to Animated Level Selector
		get_tree().change_scene_to_file("res://scenes/LevelSelectorAnimated.tscn")
	else:
		# Return to Main Menu
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _create_placeholder(color):
	var p = PlaceholderTexture2D.new()
	p.size = Vector2(64, 64)
	return p # Tint handled by modulate on node usually, or just use white placeholder and modulate node
