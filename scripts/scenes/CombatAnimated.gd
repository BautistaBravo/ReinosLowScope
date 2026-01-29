extends Control

var controller
var stamina_bar
var input_label
var log_label
var scroll_log
var party_container
var enemy_container
var background_rect

# State
var current_controlled_idx = 0

func _ready():
	controller = load("res://scripts/scenes/CombatController.gd").new()
	controller.name = "Controller"
	add_child(controller)

	controller.combat_state_changed.connect(_on_state_changed)
	controller.log_message.connect(_on_log)
	controller.player_stamina_updated.connect(_on_player_stamina)
	controller.party_updated.connect(_on_party_updated)
	controller.enemy_updated.connect(_on_enemy_updated)
	controller.combat_frame_update.connect(_on_frame_update)
	controller.targeting_mode_changed.connect(_on_targeting)
	controller.input_accepted.connect(_on_input_accepted)
	controller.combo_executed.connect(_on_combo_executed)
	controller.combat_ended.connect(_on_combat_ended)

	_build_visuals()

	controller.init_combat()

func _build_visuals():
	# Background
	background_rect = TextureRect.new()
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg_path = GameManager.get_current_level_background()
	if bg_path != "" and ResourceLoader.exists(bg_path):
		background_rect.texture = load(bg_path)
	else:
		var ph = PlaceholderTexture2D.new()
		ph.size = Vector2(1152, 648)
		background_rect.texture = ph
		background_rect.modulate = Color(0.2, 0.05, 0.05)

	add_child(background_rect)

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
	var battle_wrapper = Control.new()
	battle_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(battle_wrapper)

	var battle = HBoxContainer.new()
	# Zoom out logic: Scale down and center
	battle.scale = Vector2(0.5, 0.5)
	battle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	# Force a large enough minimum size so it doesn't shrink when scaled
	battle.custom_minimum_size = Vector2(2000, 1000)
	battle.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_wrapper.add_child(battle)

	party_container = VBoxContainer.new()
	party_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_container.alignment = BoxContainer.ALIGNMENT_CENTER
	battle.add_child(party_container)

	# Spacer to force separation/center logic
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(100, 0)
	battle.add_child(spacer)

	enemy_container = VBoxContainer.new()
	enemy_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	battle.add_child(enemy_container)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 100)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_END
	root.add_child(scroll)
	scroll_log = scroll

	log_label = RichTextLabel.new()
	log_label.scroll_following = true
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_label)

func _input(event):
	controller.handle_input(event)

# --- Signal Callbacks ---

func _on_state_changed(is_active):
	pass

func _on_log(text):
	log_label.append_text(text + "\n")
	# Heuristic to detect switch message if we didn't add a specific signal
	if text.begins_with("Switched to"):
		# Force refresh to update highlight
		pass

func _on_player_stamina(current, max_val):
	stamina_bar.max_value = max_val
	stamina_bar.value = current

func _on_party_updated(party_data, party_stamina, party_max_stamina):
	# Update active idx from controller (we can read it directly since it's a child node script variable)
	current_controlled_idx = controller.controlled_hero_idx

	for c in party_container.get_children():
		c.queue_free()

	for i in range(party_data.size()):
		var member = party_data[i]
		var hbox = HBoxContainer.new()
		party_container.add_child(hbox)

		# Sprite
		var icon = TextureRect.new()
		if member.has("sprite") and ResourceLoader.exists(member["sprite"]):
			icon.texture = load(member["sprite"])
		else:
			icon.texture = _create_placeholder(Color.BLUE)
		icon.custom_minimum_size = Vector2(64, 64)

		# Highlight Controlled Hero
		if i == current_controlled_idx:
			icon.modulate = Color(1.2, 1.2, 1.2) # Subtle Glow
			var indicator = Label.new()
			indicator.text = " [CTRL]"
			indicator.modulate = Color.YELLOW
			hbox.add_child(indicator)
		else:
			icon.modulate = Color.WHITE

		hbox.add_child(icon)

		var info_box = VBoxContainer.new()
		hbox.add_child(info_box)

		var lbl = Label.new()
		lbl.text = member["name"]
		info_box.add_child(lbl)

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

func _on_enemy_updated(enemies, atb_gauges, selected_idx):
	for c in enemy_container.get_children():
		c.queue_free()

	for i in range(enemies.size()):
		var enemy = enemies[i]
		if enemy["hp"] <= 0:
			var dead = TextureRect.new()
			dead.texture = _create_placeholder(Color(0.2, 0.2, 0.2))
			dead.custom_minimum_size = Vector2(64, 64)
			enemy_container.add_child(dead)
			continue

		var vbox = VBoxContainer.new()
		enemy_container.add_child(vbox)

		var sprite = TextureRect.new()
		# Load enemy sprite if available
		if enemy.has("sprite") and ResourceLoader.exists(enemy["sprite"]):
			sprite.texture = load(enemy["sprite"])
		else:
			sprite.texture = _create_placeholder(Color.RED)
		sprite.custom_minimum_size = Vector2(64, 64)

		if i == selected_idx:
			sprite.modulate = Color(1.5, 1.5, 0.5)
		else:
			sprite.modulate = Color.WHITE

		vbox.add_child(sprite)

		var lbl = Label.new()
		lbl.text = enemy["name"]
		vbox.add_child(lbl)

		var hp_bar = ProgressBar.new()
		hp_bar.name = "HPBar"
		hp_bar.custom_minimum_size = Vector2(80, 10)
		hp_bar.max_value = enemy["max_hp"]
		hp_bar.value = enemy["hp"]
		hp_bar.modulate = Color.RED
		hp_bar.show_percentage = false
		vbox.add_child(hp_bar)

		var atb_bar = ProgressBar.new()
		atb_bar.name = "ATBBar"
		atb_bar.custom_minimum_size = Vector2(80, 5)
		if atb_gauges.size() > i:
			atb_bar.value = atb_gauges[i]
		atb_bar.max_value = 100.0
		atb_bar.modulate = Color.CYAN
		atb_bar.show_percentage = false
		vbox.add_child(atb_bar)

func _on_frame_update(party_stam, enemy_atb):
	# Update Party Bars (last child of info box)
	var party_nodes = party_container.get_children()
	for i in range(min(party_nodes.size(), party_stam.size())):
		var hbox = party_nodes[i]
		# Hierarchy: HBox -> InfoBox(VBox) -> [Label, HPBar, StamBar]
		# StamBar is last child
		if hbox.get_child_count() > 1:
			var info_box = hbox.get_child(1)
			if info_box.get_child_count() > 2:
				var stam_bar = info_box.get_child(2)
				if stam_bar is ProgressBar:
					stam_bar.value = party_stam[i]

	# Update Enemy ATB
	var enemy_nodes = enemy_container.get_children()
	for i in range(min(enemy_nodes.size(), enemy_atb.size())):
		var vbox = enemy_nodes[i]
		# Hierarchy: VBox -> [Sprite, Label, HPBar, ATBBar]
		# ATBBar is last
		var atb = vbox.find_child("ATBBar", false, false)
		if atb:
			atb.value = enemy_atb[i]

func _on_targeting(is_targeting, text):
	input_label.text = text
	if is_targeting:
		input_label.modulate = Color.YELLOW
	else:
		input_label.modulate = Color.WHITE

func _on_input_accepted(key, hero_idx):
	var color = Color.WHITE
	if key == "q": color = Color.RED
	elif key == "w": color = Color.GREEN
	elif key == "e": color = Color.BLUE

	_spawn_particle(hero_idx, color, false)

func _on_combo_executed(hero_idx, target_idx):
	_spawn_particle(hero_idx, Color.YELLOW, true)

func _spawn_particle(hero_idx, color, is_explosion):
	var party_nodes = party_container.get_children()
	if hero_idx >= 0 and hero_idx < party_nodes.size():
		var target_node = party_nodes[hero_idx].get_child(0) # Icon is first child of HBox

		var emitter = CPUParticles2D.new()
		target_node.add_child(emitter)
		emitter.show_behind_parent = true # Draw behind the sprite
		emitter.position = Vector2(32, 32) # Center of 64x64 icon
		emitter.amount = 30
		emitter.one_shot = true
		emitter.explosiveness = 1.0
		emitter.lifetime = 0.8
		emitter.direction = Vector2(0, -1)
		emitter.spread = 180
		emitter.gravity = Vector2(0, 0)
		emitter.initial_velocity_min = 60
		emitter.initial_velocity_max = 120
		emitter.scale_amount_min = 4.0
		emitter.scale_amount_max = 8.0
		emitter.color = color

		if is_explosion:
			emitter.amount = 60
			emitter.scale_amount_min = 6.0
			emitter.scale_amount_max = 12.0
			emitter.initial_velocity_min = 120
			emitter.initial_velocity_max = 250

		emitter.emitting = true

		# Auto-cleanup
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(emitter):
			emitter.queue_free()

func _on_combat_ended(victory, summary_data = {}):
	if victory:
		_show_summary(summary_data)
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _show_summary(data):
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Victory!"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var content = Label.new()
	var txt = "Gold Earned: " + str(data.get("gold", 0)) + "\n"
	txt += "XP Earned: " + str(data.get("xp", 0)) + "\n"
	txt += "Items Found:\n"
	for item in data.get("drops", []):
		txt += "- " + item + "\n"

	txt += "\nLevel Ups:\n"
	for name in data.get("level_ups", []):
		txt += name + " Leveled Up!\n"

	content.text = txt
	vbox.add_child(content)

	var btn = Button.new()
	btn.text = "Continue"
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/LevelSelectorAnimated.tscn"))
	vbox.add_child(btn)

func _create_placeholder(color):
	var p = PlaceholderTexture2D.new()
	p.size = Vector2(64, 64)
	return p
