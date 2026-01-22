extends Control

# Constants
const BASE_STAMINA_COST = 5
const BASE_STAMINA_REGEN = 1.0
const BASE_MAX_STAMINA = 100.0

# State
var current_stamina = 100.0
var max_stamina = 100.0
var stamina_regen = 1.0

var input_buffer = []
var selected_enemy_index = -1
var enemies_data = [] # Local copy of enemy data for the battle
var enemy_atb_gauges = [] # Array of floats (0 to 100)
var is_combat_active = true

# UI References
var stamina_bar: ProgressBar
var input_label: Label
var log_label: Label
var party_container: VBoxContainer
var enemy_container: VBoxContainer
var input_feedback: Label

func _ready():
	_calculate_party_stats()
	current_stamina = max_stamina
	input_buffer = []

	_build_ui()
	_load_party()
	_load_enemies()

func _calculate_party_stats():
	# Calculate global stamina stats based on equipment
	var bonus_stam = GameManager.get_party_total_stat_bonus("stamina")
	var bonus_regen = GameManager.get_party_total_stat_bonus("stamina_regen")

	max_stamina = BASE_MAX_STAMINA + bonus_stam
	stamina_regen = BASE_STAMINA_REGEN + bonus_regen

func _build_ui():
	# Root VBox
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Top Bar: Stamina
	var top_bar = HBoxContainer.new()
	root.add_child(top_bar)

	var stam_label = Label.new()
	stam_label.text = "Stamina:"
	top_bar.add_child(stam_label)

	stamina_bar = ProgressBar.new()
	stamina_bar.max_value = max_stamina
	stamina_bar.custom_minimum_size = Vector2(200, 20)
	top_bar.add_child(stamina_bar)

	input_feedback = Label.new()
	input_feedback.text = "Input: "
	top_bar.add_child(input_feedback)

	# Middle: Battle Ground
	var battle_ground = HBoxContainer.new()
	battle_ground.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(battle_ground)

	# Left: Party
	party_container = VBoxContainer.new()
	party_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_container.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_ground.add_child(party_container)

	# Right: Enemies
	enemy_container = VBoxContainer.new()
	enemy_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_ground.add_child(enemy_container)

	# Bottom: Log
	log_label = Label.new()
	log_label.text = "Battle Started!"
	root.add_child(log_label)

func _load_party():
	_refresh_party_ui()

func _refresh_party_ui():
	# Clear existing
	for child in party_container.get_children():
		child.queue_free()

	# Rebuild
	for i in range(GameManager.party.size()):
		var member = GameManager.party[i]
		var panel = PanelContainer.new()
		party_container.add_child(panel)

		var vbox = VBoxContainer.new()
		panel.add_child(vbox)

		# Calc Stats
		var bonus_hp = GameManager.get_member_effective_stat(i, "hp", 0)
		var total_max_hp = member["max_hp"] + bonus_hp

		var name_lbl = Label.new()
		name_lbl.text = member["name"] + " (Lvl " + str(member["level"]) + ")"
		vbox.add_child(name_lbl)

		var hp_bar = ProgressBar.new()
		hp_bar.max_value = total_max_hp
		hp_bar.value = member["hp"]
		hp_bar.custom_minimum_size = Vector2(100, 10)
		vbox.add_child(hp_bar)

		var hp_text = Label.new()
		hp_text.text = str(member["hp"]) + "/" + str(total_max_hp)
		vbox.add_child(hp_text)

func _load_enemies():
	enemies_data = GameManager.get_level_data(GameManager.selected_level)
	enemy_atb_gauges = []
	for e in enemies_data:
		enemy_atb_gauges.append(0.0)

	_refresh_enemy_ui()

func _refresh_enemy_ui():
	for child in enemy_container.get_children():
		child.queue_free()

	for i in range(enemies_data.size()):
		var enemy = enemies_data[i]
		if enemy["hp"] <= 0:
			continue

		var btn = Button.new()
		btn.toggle_mode = true
		btn.button_pressed = (i == selected_enemy_index)
		btn.text = enemy["name"] + "\nHP: " + str(enemy["hp"])
		btn.custom_minimum_size = Vector2(120, 60)
		btn.pressed.connect(_on_enemy_selected.bind(i))
		enemy_container.add_child(btn)

func _on_enemy_selected(index):
	selected_enemy_index = index
	_refresh_enemy_ui()

func _process(delta):
	if not is_combat_active:
		return

	# Regen Player Stamina
	current_stamina = min(current_stamina + stamina_regen * delta, max_stamina)
	stamina_bar.value = current_stamina

	# Process Enemies
	for i in range(enemies_data.size()):
		if enemies_data[i]["hp"] > 0:
			var speed = enemies_data[i].get("speed", 10.0)
			enemy_atb_gauges[i] += speed * delta
			if enemy_atb_gauges[i] >= 100.0:
				enemy_atb_gauges[i] = 0.0
				_enemy_attack(i)

func _enemy_attack(enemy_idx):
	var ai_type = enemies_data[enemy_idx].get("ai_type", "random")
	var target_idx = -1

	var alive_indices = []
	for i in range(GameManager.party.size()):
		if GameManager.party[i]["hp"] > 0:
			alive_indices.append(i)

	if alive_indices.size() == 0:
		return # No one to attack

	# AI Logic
	if ai_type == "focus_weak":
		var lowest_hp = 9999
		for i in alive_indices:
			if GameManager.party[i]["hp"] < lowest_hp:
				lowest_hp = GameManager.party[i]["hp"]
				target_idx = i
	elif ai_type == "aggressive":
		var highest_hp = -1
		for i in alive_indices:
			if GameManager.party[i]["hp"] > highest_hp:
				highest_hp = GameManager.party[i]["hp"]
				target_idx = i
	else: # random
		target_idx = alive_indices.pick_random()

	if target_idx != -1:
		var dmg = enemies_data[enemy_idx].get("damage", 2)
		GameManager.damage_party_member(target_idx, dmg)
		log_label.text = enemies_data[enemy_idx]["name"] + " hits " + GameManager.party[target_idx]["name"] + " for " + str(dmg)
		_refresh_party_ui()
		_check_loss_condition()

func _input(event):
	if not is_combat_active:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key = ""
		if event.keycode == KEY_Q:
			key = "Q"
		elif event.keycode == KEY_W:
			key = "W"
		elif event.keycode == KEY_E:
			key = "E"

		if key != "":
			if current_stamina >= BASE_STAMINA_COST:
				current_stamina -= BASE_STAMINA_COST
				input_buffer.append(key)
				_update_input_label()

				if input_buffer.size() >= 3:
					_execute_combo()
			else:
				log_label.text = "Not enough stamina!"

func _update_input_label():
	var text = "Input: "
	for k in input_buffer:
		text += k + " "
	input_feedback.text = text

func _execute_combo():
	var q = input_buffer.count("Q")
	var w = input_buffer.count("W")
	var e = input_buffer.count("E")

	var log_text = "Combo: "

	# Heal
	if w > 0:
		var heal_base = w * 1
		# Maybe equip affects healing? Assuming not for now, or maybe "damage" stat affects it?
		# Let's say damage stat affects healing too for simplicity? Or just kept base.
		# Prompt says: "Curando 1 punto... haciendo 1 punto de daño...". Doesn't specify stats affect healing.
		# I will stick to base healing.
		GameManager.heal_party(heal_base)
		log_text += "Heal party " + str(heal_base) + ". "
		_refresh_party_ui()

	# Damage
	# Calculate total damage bonus from party equipment
	var total_dmg_bonus = GameManager.get_party_total_stat_bonus("damage")
	# Does "damage extra" apply to every hit? Or just total combo?
	# Let's apply it to total combo damage.

	var base_dmg = (q * 1) + (e * 2)
	var total_dmg = base_dmg + total_dmg_bonus

	if base_dmg > 0:
		# Check target
		if selected_enemy_index != -1 and selected_enemy_index < enemies_data.size() and enemies_data[selected_enemy_index]["hp"] > 0:
			enemies_data[selected_enemy_index]["hp"] -= total_dmg
			log_text += "Hit enemy for " + str(total_dmg) + " (Base " + str(base_dmg) + " + Bonus " + str(total_dmg_bonus) + ")."
			_refresh_enemy_ui()
			_check_win_condition()
		else:
			log_text += "Attack missed (no target)!"

	log_label.text = log_text
	input_buffer.clear()
	_update_input_label()

func _check_win_condition():
	var all_dead = true
	var total_xp = 0
	for e in enemies_data:
		if e["hp"] > 0:
			all_dead = false
		else:
			total_xp += e.get("xp_reward", 10)

	if all_dead:
		is_combat_active = false
		log_label.text = "Victory! gained " + str(total_xp) + " XP."
		GameManager.gain_party_xp(total_xp)
		GameManager.save_game()

		# Delay exit
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/LevelSelector.tscn")

func _check_loss_condition():
	var all_dead = true
	for m in GameManager.party:
		if m["hp"] > 0:
			all_dead = false
			break

	if all_dead:
		is_combat_active = false
		log_label.text = "Defeat..."
		# Maybe reload?
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
