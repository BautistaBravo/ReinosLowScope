extends Control

# Constants
const BASE_STAMINA_COST = 5
const AI_ACTION_COST = 30.0

# State
var is_combat_active = true

# Player State (Hero 1)
var player_stamina = 100.0
var player_max_stamina = 100.0
var player_stamina_regen = 1.0
var input_buffer = []

# Party State (AI)
var party_stamina = []
var party_max_stamina = []
var party_stamina_regen = []

var selected_enemy_index = -1
var enemies_data = []
var enemy_atb_gauges = []

# UI References
var stamina_bar: ProgressBar
var input_label: Label
var log_label: Label
var party_container: VBoxContainer
var enemy_container: VBoxContainer
var input_feedback: Label

func _ready():
	_calculate_party_stats()
	# Initialize run-time stamina
	party_stamina = []
	for i in range(GameManager.party.size()):
		party_stamina.append(party_max_stamina[i])

	player_stamina = party_stamina[0]
	input_buffer = []

	_build_ui()
	_load_party()
	_load_enemies()

func _calculate_party_stats():
	party_max_stamina = []
	party_stamina_regen = []

	for i in range(GameManager.party.size()):
		var member = GameManager.party[i]
		# Use member's base stats + equipment bonus
		var base_stam = member.get("base_stamina", 100)
		var base_regen = member.get("base_stamina_regen", 1.0)

		# get_member_effective_stat adds equipment stats to a given base value
		# Note: get_member_effective_stat logic in GameManager handles summing bonus.
		# But here we pass 0 as base because we want ONLY the bonus,
		# OR we pass base_stam and let it add?
		# Looking at GameManager: `val = base_value ... val += stats[name]`.
		# So we pass base_stam.

		var total_stam = GameManager.get_member_effective_stat(i, "stamina", base_stam)
		var total_regen = GameManager.get_member_effective_stat(i, "stamina_regen", base_regen)

		party_max_stamina.append(total_stam)
		party_stamina_regen.append(total_regen)

	# Player alias
	player_max_stamina = party_max_stamina[0]
	player_stamina_regen = party_stamina_regen[0]

func _build_ui():
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Top Bar: Player Stamina
	var top_bar = HBoxContainer.new()
	root.add_child(top_bar)

	var stam_label = Label.new()
	stam_label.text = "Player Stamina:"
	top_bar.add_child(stam_label)

	stamina_bar = ProgressBar.new()
	stamina_bar.max_value = player_max_stamina
	stamina_bar.custom_minimum_size = Vector2(200, 20)
	top_bar.add_child(stamina_bar)

	input_feedback = Label.new()
	input_feedback.text = "Input: "
	top_bar.add_child(input_feedback)

	var battle_ground = HBoxContainer.new()
	battle_ground.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(battle_ground)

	party_container = VBoxContainer.new()
	party_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_container.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_ground.add_child(party_container)

	enemy_container = VBoxContainer.new()
	enemy_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_container.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_ground.add_child(enemy_container)

	log_label = Label.new()
	log_label.text = "Battle Started!"
	root.add_child(log_label)

func _load_party():
	_refresh_party_ui()

func _refresh_party_ui():
	for child in party_container.get_children():
		child.queue_free()

	for i in range(GameManager.party.size()):
		var member = GameManager.party[i]
		var panel = PanelContainer.new()
		party_container.add_child(panel)

		var vbox = VBoxContainer.new()
		panel.add_child(vbox)

		# Stats
		var bonus_hp = GameManager.get_member_effective_stat(i, "hp", 0) # Only bonus
		var total_max_hp = member["max_hp"] + bonus_hp # max_hp in member is base from growth

		var name_lbl = Label.new()
		name_lbl.text = member["name"] + " (Lvl " + str(member["level"]) + ")"
		vbox.add_child(name_lbl)

		# HP Bar
		var hp_bar = ProgressBar.new()
		hp_bar.max_value = total_max_hp
		hp_bar.value = member["hp"]
		hp_bar.custom_minimum_size = Vector2(100, 10)
		vbox.add_child(hp_bar)

		var hp_text = Label.new()
		hp_text.text = str(member["hp"]) + "/" + str(total_max_hp)
		vbox.add_child(hp_text)

		# Stamina Bar
		var s_lbl = Label.new()
		s_lbl.text = "Stamina"
		s_lbl.add_theme_font_size_override("font_size", 10)
		vbox.add_child(s_lbl)

		var s_bar = ProgressBar.new()
		s_bar.max_value = party_max_stamina[i]
		s_bar.value = party_stamina[i]
		s_bar.custom_minimum_size = Vector2(100, 8)
		vbox.add_child(s_bar)

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

	# Regen Party Stamina
	for i in range(party_stamina.size()):
		if GameManager.party[i]["hp"] > 0:
			party_stamina[i] = min(party_stamina[i] + party_stamina_regen[i] * delta, party_max_stamina[i])

			if i > 0 and party_stamina[i] >= AI_ACTION_COST:
				_ai_companion_act(i)

	player_stamina = party_stamina[0]
	stamina_bar.value = player_stamina

	_update_party_bars_only()

	# Process Enemies
	for i in range(enemies_data.size()):
		if enemies_data[i]["hp"] > 0:
			var speed = enemies_data[i].get("speed", 10.0)
			enemy_atb_gauges[i] += speed * delta
			if enemy_atb_gauges[i] >= 100.0:
				enemy_atb_gauges[i] = 0.0
				_enemy_attack(i)

func _update_party_bars_only():
	var children = party_container.get_children()
	for i in range(children.size()):
		if i >= party_stamina.size(): break
		var panel = children[i]
		var vbox = panel.get_child(0)
		if vbox.get_child_count() >= 5:
			var hp_bar = vbox.get_child(1)
			var hp_text = vbox.get_child(2)
			var s_bar = vbox.get_child(4)

			var member = GameManager.party[i]
			var bonus_hp = GameManager.get_member_effective_stat(i, "hp", 0)
			var max_hp = member["max_hp"] + bonus_hp

			hp_bar.max_value = max_hp
			hp_bar.value = member["hp"]
			hp_text.text = str(member["hp"]) + "/" + str(max_hp)

			s_bar.max_value = party_max_stamina[i]
			s_bar.value = party_stamina[i]

func _ai_companion_act(member_idx):
	party_stamina[member_idx] -= AI_ACTION_COST

	var needs_heal = false
	for m in GameManager.party:
		if m["hp"] > 0 and m["hp"] < (m["max_hp"] * 0.5):
			needs_heal = true
			break

	var action = "attack"
	if needs_heal and randf() < 0.3:
		action = "heal"

	if action == "heal":
		var heal_amt = 5
		GameManager.heal_party(heal_amt)
		log_label.text = GameManager.party[member_idx]["name"] + " heals party for " + str(heal_amt)
	else:
		# Attack
		# Use member base damage + equipment bonus
		var base_dmg = GameManager.party[member_idx].get("base_damage", 2)
		var total_dmg = GameManager.get_member_effective_stat(member_idx, "damage", base_dmg)

		var targets = []
		for e_idx in range(enemies_data.size()):
			if enemies_data[e_idx]["hp"] > 0:
				targets.append(e_idx)

		if targets.size() > 0:
			var t = targets.pick_random()
			enemies_data[t]["hp"] -= total_dmg
			log_label.text = GameManager.party[member_idx]["name"] + " hits " + enemies_data[t]["name"] + " for " + str(total_dmg)
			_refresh_enemy_ui()
			_check_win_condition()

func _enemy_attack(enemy_idx):
	var ai_type = enemies_data[enemy_idx].get("ai_type", "random")
	var target_idx = -1

	var alive_indices = []
	for i in range(GameManager.party.size()):
		if GameManager.party[i]["hp"] > 0:
			alive_indices.append(i)

	if alive_indices.size() == 0:
		return

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
	else:
		target_idx = alive_indices.pick_random()

	if target_idx != -1:
		var dmg = enemies_data[enemy_idx].get("damage", 2)
		GameManager.damage_party_member(target_idx, dmg)
		log_label.text = enemies_data[enemy_idx]["name"] + " hits " + GameManager.party[target_idx]["name"] + " for " + str(dmg)
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
			if party_stamina[0] >= BASE_STAMINA_COST:
				party_stamina[0] -= BASE_STAMINA_COST
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

	var log_text = "Player Combo: "

	# Heal
	if w > 0:
		var heal_base = w * 1
		GameManager.heal_party(heal_base)
		log_text += "Heal party " + str(heal_base) + ". "

	# Damage
	# Player Base Damage + Bonus
	var base_dmg_stat = GameManager.party[0].get("base_damage", 2)
	var dmg_bonus = GameManager.get_member_effective_stat(0, "damage", base_dmg_stat) # Total Damage Stat

	# But wait, logic was: (q*1 + e*2) + bonus.
	# Now we have a 'base_damage' stat. Should that replace the (1 or 2)?
	# The prompt says: "diccionario de crecimiento... hp, attack...".
	# So 'attack' (base_damage) should probably scale the damage.
	# Let's interpret: Damage = (Combo Multiplier * Attack Stat).
	# Q = 1x Attack, E = 2x Attack?
	# Previous logic: (q*1) + (e*2) + bonus.
	# New Logic suggestion: (q * 1 * Attack) + (e * 2 * Attack)? Or just Attack + Combo?
	# Let's keep it additive to be safe with low numbers: (q*1 + e*2) + TotalAttackStat.

	var combo_dmg = (q * 1) + (e * 2)
	var total_dmg = combo_dmg + dmg_bonus

	if combo_dmg > 0:
		if selected_enemy_index != -1 and selected_enemy_index < enemies_data.size() and enemies_data[selected_enemy_index]["hp"] > 0:
			enemies_data[selected_enemy_index]["hp"] -= total_dmg
			log_text += "Hit enemy for " + str(total_dmg) + "."
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
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
