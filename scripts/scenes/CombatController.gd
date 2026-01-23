extends Node

# Signals
signal combat_state_changed(is_active)
signal log_message(text)
signal player_stamina_updated(current, max_val)
signal party_updated(party_data, party_stamina, party_max_stamina)
signal enemy_updated(enemies_data, selected_idx)
signal targeting_mode_changed(is_targeting, combo_ready_text)
signal combat_ended(victory)

# Constants
const BASE_STAMINA_COST = 5
const AI_ACTION_COST = 30.0
const INPUT_COOLDOWN = 0.5
const START_COMBAT_DELAY = 2.0

# State
var is_combat_active = false
var is_targeting_mode = false

# Player State
var player_stamina = 100.0
var player_max_stamina = 100.0
var player_stamina_regen = 1.0
var input_buffer = []
var input_cooldown_timer = 0.0

# Party State
var party_stamina = []
var party_max_stamina = []
var party_stamina_regen = []
var party_debuffs = []

# Enemy State
var selected_enemy_index = -1
var target_cursor_index = 0
var enemies_data = []
var enemy_atb_gauges = []
var enemy_debuffs = []

func _ready():
	_init_combat()

func _init_combat():
	_calculate_party_stats()
	party_stamina = []
	party_debuffs = []
	for i in range(GameManager.party.size()):
		party_stamina.append(party_max_stamina[i])
		party_debuffs.append([])

	player_stamina = party_stamina[0]
	input_buffer = []
	is_targeting_mode = false
	input_cooldown_timer = 0.0
	is_combat_active = false
	target_cursor_index = 0

	enemies_data = GameManager.get_level_data(GameManager.selected_level)
	enemy_atb_gauges = []
	enemy_debuffs = []
	for e in enemies_data:
		enemy_atb_gauges.append(0.0)
		e["last_attacker"] = -1
		enemy_debuffs.append([])

	emit_signal("log_message", "Get Ready...")
	emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina)
	emit_signal("enemy_updated", enemies_data, selected_enemy_index)

	await get_tree().create_timer(START_COMBAT_DELAY).timeout

	is_combat_active = true
	emit_signal("combat_state_changed", true)
	emit_signal("log_message", "Battle Started!")

func _calculate_party_stats():
	party_max_stamina = []
	party_stamina_regen = []
	for i in range(GameManager.party.size()):
		var member = GameManager.party[i]
		var base_stam = member.get("base_stamina", 100)
		var base_regen = member.get("base_stamina_regen", 1.0)
		var total_stam = GameManager.get_member_effective_stat(i, "stamina", base_stam)
		var total_regen = GameManager.get_member_effective_stat(i, "stamina_regen", base_regen)
		party_max_stamina.append(total_stam)
		party_stamina_regen.append(total_regen)
	player_max_stamina = party_max_stamina[0]
	player_stamina_regen = party_stamina_regen[0]

func _process(delta):
	if not is_combat_active:
		return

	if input_cooldown_timer > 0:
		input_cooldown_timer -= delta

	_process_debuffs(delta)

	# Regen Party
	var party_changed = false
	for i in range(party_stamina.size()):
		if GameManager.party[i]["hp"] > 0:
			var multiplier = 1.0
			for d in party_debuffs[i]:
				if d["type"] == "slowed":
					multiplier *= 0.5

			var old_stam = party_stamina[i]
			party_stamina[i] = min(party_stamina[i] + (party_stamina_regen[i] * multiplier) * delta, party_max_stamina[i])

			if old_stam != party_stamina[i]:
				party_changed = true

			if i > 0 and party_stamina[i] >= AI_ACTION_COST:
				_ai_companion_act(i)
				party_changed = true

	player_stamina = party_stamina[0]

	if party_changed:
		emit_signal("player_stamina_updated", player_stamina, player_max_stamina)
		emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina)

	# Process Enemies
	for i in range(enemies_data.size()):
		if enemies_data[i]["hp"] > 0:
			var speed = enemies_data[i].get("speed", 10.0)
			enemy_atb_gauges[i] += speed * delta
			if enemy_atb_gauges[i] >= 100.0:
				enemy_atb_gauges[i] = 0.0
				_enemy_attack(i)

func _process_debuffs(delta):
	var update_party = false
	for i in range(party_debuffs.size()):
		var active_list = []
		for d in party_debuffs[i]:
			d["duration"] -= delta
			if d["type"] == "bleed":
				d["tick_timer"] -= delta
				if d["tick_timer"] <= 0:
					d["tick_timer"] = 1.0
					var dmg = d["stacks"]
					GameManager.damage_party_member(i, dmg)
					emit_signal("log_message", GameManager.party[i]["name"] + " bleeds for " + str(dmg))
					update_party = true
					_check_loss_condition()
			if d["duration"] > 0:
				active_list.append(d)
		party_debuffs[i] = active_list

	if update_party:
		emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina)

	var update_enemy = false
	for i in range(enemy_debuffs.size()):
		if enemies_data[i]["hp"] <= 0: continue
		var active_list = []
		for d in enemy_debuffs[i]:
			d["duration"] -= delta
			if d["type"] == "bleed":
				d["tick_timer"] -= delta
				if d["tick_timer"] <= 0:
					d["tick_timer"] = 1.0
					var dmg = d["stacks"]
					enemies_data[i]["hp"] -= dmg
					emit_signal("log_message", enemies_data[i]["name"] + " bleeds for " + str(dmg))
					update_enemy = true
					_check_win_condition()
			if d["duration"] > 0:
				active_list.append(d)
		enemy_debuffs[i] = active_list

	if update_enemy:
		emit_signal("enemy_updated", enemies_data, selected_enemy_index)

func apply_debuff(is_party, index, type, duration):
	var list_ref = null
	if is_party:
		if index >= 0 and index < party_debuffs.size(): list_ref = party_debuffs[index]
	else:
		if index >= 0 and index < enemy_debuffs.size(): list_ref = enemy_debuffs[index]

	if list_ref == null: return

	var existing = null
	for d in list_ref:
		if d["type"] == type:
			existing = d
			break

	if existing:
		existing["duration"] = duration
		if type == "bleed": existing["stacks"] += 1
	else:
		var new_debuff = { "type": type, "duration": duration }
		if type == "bleed":
			new_debuff["stacks"] = 1
			new_debuff["tick_timer"] = 1.0
		list_ref.append(new_debuff)

	if not is_party:
		emit_signal("enemy_updated", enemies_data, selected_enemy_index)

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
		emit_signal("log_message", GameManager.party[member_idx]["name"] + " heals party for " + str(heal_amt))
	else:
		var base_dmg = GameManager.party[member_idx].get("base_damage", 2)
		var total_dmg = GameManager.get_member_effective_stat(member_idx, "damage", base_dmg)
		var targets = []
		for e_idx in range(enemies_data.size()):
			if enemies_data[e_idx]["hp"] > 0: targets.append(e_idx)

		if targets.size() > 0:
			var t = targets.pick_random()
			enemies_data[t]["hp"] -= total_dmg
			enemies_data[t]["last_attacker"] = member_idx
			emit_signal("log_message", GameManager.party[member_idx]["name"] + " hits " + enemies_data[t]["name"] + " for " + str(total_dmg))
			emit_signal("enemy_updated", enemies_data, selected_enemy_index)
			_check_win_condition()

	emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina)

func _enemy_attack(enemy_idx):
	var ai_type = enemies_data[enemy_idx].get("ai_type", "random")
	var target_idx = -1
	var alive_indices = []
	for i in range(GameManager.party.size()):
		if GameManager.party[i]["hp"] > 0: alive_indices.append(i)

	if alive_indices.size() == 0: return

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
	elif ai_type == "twin_attack":
		var next_same = enemies_data[enemy_idx].get("twin_next_is_same", false)
		var last_target = enemies_data[enemy_idx].get("twin_last_target", -1)
		if next_same and last_target != -1 and GameManager.party[last_target]["hp"] > 0:
			target_idx = last_target
			enemies_data[enemy_idx]["twin_next_is_same"] = false
		else:
			target_idx = alive_indices.pick_random()
			enemies_data[enemy_idx]["twin_last_target"] = target_idx
			enemies_data[enemy_idx]["twin_next_is_same"] = true
	elif ai_type == "last_attacker":
		var attacker_idx = enemies_data[enemy_idx].get("last_attacker", -1)
		if attacker_idx != -1 and GameManager.party[attacker_idx]["hp"] > 0:
			target_idx = attacker_idx
		else:
			target_idx = alive_indices.pick_random()
	else:
		target_idx = alive_indices.pick_random()

	if target_idx != -1:
		var dmg = enemies_data[enemy_idx].get("damage", 2)
		GameManager.damage_party_member(target_idx, dmg)

		if enemies_data[enemy_idx]["name"] == "Skeleton":
			if randf() < 0.5:
				apply_debuff(true, target_idx, "bleed", 4.0)
				emit_signal("log_message", enemies_data[enemy_idx]["name"] + " applies Bleed!")

		emit_signal("log_message", enemies_data[enemy_idx]["name"] + " hits " + GameManager.party[target_idx]["name"] + " for " + str(dmg))
		emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina)
		_check_loss_condition()

func handle_input(event):
	if not is_combat_active: return
	if event is InputEventKey and event.pressed and not event.echo:
		if is_targeting_mode:
			if event.keycode == KEY_RIGHT: _move_cursor(1)
			elif event.keycode == KEY_LEFT: _move_cursor(-1)
			elif event.keycode == KEY_0 or event.keycode == KEY_KP_0:
				if target_cursor_index >= 0 and target_cursor_index < enemies_data.size():
					_on_enemy_confirmed(target_cursor_index)
			return

		var key = ""
		if event.keycode == KEY_Q: key = "Q"
		elif event.keycode == KEY_W: key = "W"
		elif event.keycode == KEY_E: key = "E"

		if key != "":
			if input_cooldown_timer > 0: return
			if party_stamina[0] >= BASE_STAMINA_COST:
				party_stamina[0] -= BASE_STAMINA_COST
				input_buffer.append(key)
				input_cooldown_timer = INPUT_COOLDOWN

				var txt = "Input: "
				for k in input_buffer: txt += k + " "
				emit_signal("targeting_mode_changed", false, txt)

				emit_signal("player_stamina_updated", party_stamina[0], party_max_stamina[0])
				emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina)

				if input_buffer.size() >= 3:
					is_targeting_mode = true
					emit_signal("targeting_mode_changed", true, "Combo Ready! Select with Arrows, Confirm with 0")
					_move_cursor(0)
			else:
				emit_signal("log_message", "Not enough stamina!")

func _move_cursor(direction):
	if enemies_data.size() == 0: return
	var current = target_cursor_index
	for _i in range(enemies_data.size()):
		current += direction
		if current >= enemies_data.size(): current = 0
		if current < 0: current = enemies_data.size() - 1
		if enemies_data[current]["hp"] > 0:
			target_cursor_index = current
			selected_enemy_index = current # Sync for View highlighting
			emit_signal("enemy_updated", enemies_data, selected_enemy_index)
			return

func _on_enemy_confirmed(index):
	selected_enemy_index = index
	_execute_combo()
	is_targeting_mode = false
	emit_signal("targeting_mode_changed", false, "Input: ")
	emit_signal("enemy_updated", enemies_data, selected_enemy_index)

func _execute_combo():
	var q = input_buffer.count("Q")
	var w = input_buffer.count("W")
	var e = input_buffer.count("E")

	var log_text = "Player Combo: "

	if w > 0:
		var heal_base = w * 1
		GameManager.heal_party(heal_base)
		log_text += "Heal party " + str(heal_base) + ". "
		apply_debuff(true, 0, "attack_boost", 10.0)
		log_text += " Applied Attack Boost."

	var base_dmg_stat = GameManager.party[0].get("base_damage", 2)
	var dmg_bonus = GameManager.get_member_effective_stat(0, "damage", base_dmg_stat)
	var combo_dmg = (q * 1) + (e * 2)
	var total_dmg = combo_dmg + dmg_bonus

	var dmg_multiplier = 1.0
	for d in party_debuffs[0]:
		if d["type"] == "attack_boost": dmg_multiplier += 0.20
	total_dmg *= dmg_multiplier

	if combo_dmg > 0:
		if selected_enemy_index != -1 and selected_enemy_index < enemies_data.size() and enemies_data[selected_enemy_index]["hp"] > 0:
			enemies_data[selected_enemy_index]["hp"] -= total_dmg
			enemies_data[selected_enemy_index]["last_attacker"] = 0
			log_text += "Hit enemy for " + str(total_dmg) + "."
			if q > 0:
				apply_debuff(false, selected_enemy_index, "bleed", 4.0)
				log_text += " Applied Bleed."
			if e > 0:
				apply_debuff(false, selected_enemy_index, "slowed", 5.0)
				log_text += " Applied Slowed."
			_check_win_condition()
		else:
			log_text += "Attack missed (no target)!"

	emit_signal("log_message", log_text)
	input_buffer.clear()
	emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina)
	emit_signal("enemy_updated", enemies_data, selected_enemy_index)

func _check_win_condition():
	var all_dead = true
	var total_xp = 0
	var total_gold = 0
	for e in enemies_data:
		if e["hp"] > 0:
			all_dead = false
		else:
			total_xp += e.get("xp_reward", 10)
			total_gold += e.get("gold_reward", 5)

	if all_dead:
		is_combat_active = false
		emit_signal("log_message", "Victory! gained " + str(total_xp) + " XP and " + str(total_gold) + " Gold.")
		GameManager.gain_rewards(total_xp, total_gold)
		GameManager.mark_level_complete(GameManager.selected_level)

		await get_tree().create_timer(2.0).timeout
		emit_signal("combat_ended", true)

func _check_loss_condition():
	var all_dead = true
	for m in GameManager.party:
		if m["hp"] > 0:
			all_dead = false
			break
	if all_dead:
		is_combat_active = false
		emit_signal("log_message", "Defeat...")
		await get_tree().create_timer(2.0).timeout
		emit_signal("combat_ended", false)
