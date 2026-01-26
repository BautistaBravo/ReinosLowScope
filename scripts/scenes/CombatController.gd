extends Node

# Signals
signal combat_state_changed(is_active)
signal log_message(text)
signal player_stamina_updated(current, max_val)
signal party_updated(party_data, party_stamina, party_max_stamina)
signal enemy_updated(enemies_data, atb_gauges, selected_idx)
signal combat_frame_update(party_stamina, enemy_atb)
signal targeting_mode_changed(is_targeting, combo_ready_text)
signal combat_ended(victory, summary)

# Constants
const BASE_STAMINA_COST = 5
const AI_ACTION_COST = 25.0
const INPUT_COOLDOWN = 0.225
const START_COMBAT_DELAY = 2.0
const ACTION_COOLDOWN = 2.0

# State
var is_combat_active = false
var is_targeting_mode = false

# Player State
var player_stamina = 100.0
var player_max_stamina = 100.0
var player_stamina_regen = 1.0
var input_buffer = []
var input_cooldown_timer = 0.0
var controlled_hero_idx = 0 # Default to first member

# Party State
var party_stamina = []
var party_max_stamina = []
var party_stamina_regen = []
var party_debuffs = []
var party_action_cooldowns = []

# Enemy State
var selected_enemy_index = -1
var target_cursor_index = 0
var enemies_data = []
var enemy_atb_gauges = []
var enemy_debuffs = []
var enemy_action_cooldowns = []

func _ready():
	# Don't init here to avoid race condition with View connecting signals
	pass

func init_combat():
	SoundManager.play_music("BattleTheme")

	_calculate_party_stats()
	party_stamina = []
	party_debuffs = []
	party_action_cooldowns = []
	for i in range(GameManager.party.size()):
		party_stamina.append(party_max_stamina[i])
		party_debuffs.append([])
		party_action_cooldowns.append(0.0)

	controlled_hero_idx = 0
	_sync_player_stamina()

	input_buffer = []
	is_targeting_mode = false
	input_cooldown_timer = 0.0
	is_combat_active = false
	target_cursor_index = 0

	enemies_data = GameManager.get_level_data(GameManager.selected_level)
	enemy_atb_gauges = []
	enemy_debuffs = []
	enemy_action_cooldowns = []
	for e in enemies_data:
		enemy_atb_gauges.append(0.0)
		e["last_attacker"] = -1
		enemy_debuffs.append([])
		enemy_action_cooldowns.append(0.0)

	emit_signal("log_message", "Get Ready...")
	emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina)
	emit_signal("enemy_updated", enemies_data, enemy_atb_gauges, selected_enemy_index)

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

	_sync_player_stamina()

func _sync_player_stamina():
	if party_stamina.size() > controlled_hero_idx:
		player_stamina = party_stamina[controlled_hero_idx]
		player_max_stamina = party_max_stamina[controlled_hero_idx]
		player_stamina_regen = party_stamina_regen[controlled_hero_idx]
	else:
		player_stamina = 0
		player_max_stamina = 100

func _process(delta):
	if not is_combat_active:
		return

	if input_cooldown_timer > 0:
		input_cooldown_timer -= delta

	for i in range(party_action_cooldowns.size()):
		if party_action_cooldowns[i] > 0: party_action_cooldowns[i] -= delta
	for i in range(enemy_action_cooldowns.size()):
		if enemy_action_cooldowns[i] > 0: enemy_action_cooldowns[i] -= delta

	_process_debuffs(delta)

	# Regen Party
	var party_changed = false
	for i in range(party_stamina.size()):
		if GameManager.party[i]["hp"] > 0:
			var multiplier = 1.0
			for d in party_debuffs[i]:
				if d["type"] == "slowed":
					multiplier *= 0.25

			var old_stam = party_stamina[i]
			party_stamina[i] = min(party_stamina[i] + (party_stamina_regen[i] * multiplier) * delta, party_max_stamina[i])

			if old_stam != party_stamina[i]:
				party_changed = true

			# AI Act if NOT controlled
			if i != controlled_hero_idx and party_stamina[i] >= AI_ACTION_COST and party_action_cooldowns[i] <= 0:
				_ai_companion_act(i)
				party_changed = true

	_sync_player_stamina()

	# Process Enemies
	for i in range(enemies_data.size()):
		if enemies_data[i]["hp"] > 0:
			var speed = enemies_data[i].get("speed", 10.0)
			enemy_atb_gauges[i] += speed * delta
			if enemy_atb_gauges[i] >= 100.0:
				if enemy_action_cooldowns[i] <= 0:
					enemy_atb_gauges[i] = 0.0
					_enemy_attack(i)
				else:
					enemy_atb_gauges[i] = 100.0

	if party_changed:
		emit_signal("player_stamina_updated", player_stamina, player_max_stamina)
		# emit_signal("party_updated", ...) # Removed heavy update from frame loop

	# Light update for gauges
	emit_signal("combat_frame_update", party_stamina, enemy_atb_gauges)

func _process_debuffs(delta):
	var update_party = false
	for i in range(party_debuffs.size()):
		var active_list = []
		for d in party_debuffs[i]:
			d["duration"] -= delta
			if d["type"] == "bleed":
				d["tick_timer"] -= delta
				if d["tick_timer"] <= 0:
					d["tick_timer"] = 0.75
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
					d["tick_timer"] = 0.75
					var dmg = d["stacks"]
					enemies_data[i]["hp"] -= dmg
					emit_signal("log_message", enemies_data[i]["name"] + " bleeds for " + str(dmg))
					update_enemy = true
					_check_win_condition()
			if d["duration"] > 0:
				active_list.append(d)
		enemy_debuffs[i] = active_list

	if update_enemy:
		emit_signal("enemy_updated", enemies_data, enemy_atb_gauges, selected_enemy_index)

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
			new_debuff["tick_timer"] = 0.75
		list_ref.append(new_debuff)

	if not is_party:
		emit_signal("enemy_updated", enemies_data, enemy_atb_gauges, selected_enemy_index)

func _ai_companion_act(member_idx):
	party_stamina[member_idx] -= AI_ACTION_COST
	party_action_cooldowns[member_idx] = ACTION_COOLDOWN

	var member = GameManager.party[member_idx]
	var combo = member.get("ai_combo", [])

	# Determine combo to use
	var keys_to_use = []
	if combo.size() >= 3:
		keys_to_use = combo
	else:
		# Random
		for k in range(3):
			var r = randi() % 3
			if r == 0: keys_to_use.append("q")
			elif r == 1: keys_to_use.append("w")
			else: keys_to_use.append("e")

	# Execute combo logic
	var target_idx = -1
	# Pick random alive enemy
	var targets = []
	for e_idx in range(enemies_data.size()):
		if enemies_data[e_idx]["hp"] > 0: targets.append(e_idx)
	if targets.size() > 0:
		target_idx = targets.pick_random()

	var skills = member.get("skills", {})

	for key in keys_to_use:
		var skill_type = skills.get(key, "damage")
		_apply_skill_effect(skill_type, member_idx, target_idx)

	emit_signal("log_message", member["name"] + " acts!")
	emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina)
	emit_signal("enemy_updated", enemies_data, enemy_atb_gauges, selected_enemy_index)
	_check_win_condition()

func _enemy_attack(enemy_idx):
	enemy_action_cooldowns[enemy_idx] = ACTION_COOLDOWN
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
		SoundManager.play_sfx("hit")

		if enemies_data[enemy_idx]["name"] == "Skeleton":
			if randf() < 0.5:
				apply_debuff(true, target_idx, "bleed", 6.0)
				emit_signal("log_message", enemies_data[enemy_idx]["name"] + " applies Bleed!")

		emit_signal("log_message", enemies_data[enemy_idx]["name"] + " hits " + GameManager.party[target_idx]["name"] + " for " + str(dmg))
		emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina)
		_check_loss_condition()

func handle_input(event):
	if not is_combat_active: return
	if event is InputEventKey and event.pressed and not event.echo:

		# Tab Switching
		if event.keycode == KEY_TAB:
			# Find next alive member
			var start = controlled_hero_idx
			var next = controlled_hero_idx
			for i in range(GameManager.party.size()):
				next = (next + 1) % GameManager.party.size()
				if GameManager.party[next]["hp"] > 0:
					controlled_hero_idx = next
					break

			input_buffer = [] # Clear buffer on switch
			_update_input_label()
			is_targeting_mode = false
			_sync_player_stamina()
			emit_signal("log_message", "Switched to " + GameManager.party[controlled_hero_idx]["name"])
			emit_signal("player_stamina_updated", player_stamina, player_max_stamina)
			# Re-emit party update to highlight new selection (handled in View via controlled_hero_idx passed? No, View needs idx)
			# We'll pass it in signal or View can ask. Let's add it to party_updated signal or create new one?
			# Easier: overload party_updated logic in view? Or add separate signal?
			# View listens to 'party_updated', it receives (data, stam, max). We need to pass 'selected_idx'.
			# Let's emit a specific signal 'hero_selected'.
			emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina) # We need to update signal sig?
			# Actually, I can just repurpose party_updated to include selected index or add a new signal.
			# Let's add a new signal `active_hero_changed(idx)`
			# Wait, I can't add signal without updating View.
			# I'll update party_updated signal signature in next file write.
			return

		if is_targeting_mode:
			if event.keycode == KEY_RIGHT: _move_cursor(1)
			elif event.keycode == KEY_LEFT: _move_cursor(-1)
			elif event.keycode == KEY_UP: _move_cursor(-1)
			elif event.keycode == KEY_DOWN: _move_cursor(-1)
			elif event.keycode == KEY_0 or event.keycode == KEY_KP_0 or event.keycode == KEY_ENTER:
				if target_cursor_index >= 0 and target_cursor_index < enemies_data.size():
					_on_enemy_confirmed(target_cursor_index)
			return

		var key = ""
		if event.keycode == KEY_Q: key = "q"
		elif event.keycode == KEY_W: key = "w"
		elif event.keycode == KEY_E: key = "e"
		elif event.keycode == KEY_W: key = "r"
		elif event.keycode == KEY_E: key = "t"
		elif event.keycode == KEY_W: key = "y"
		elif event.keycode == KEY_E: key = "u"
		elif event.keycode == KEY_W: key = "i"
		elif event.keycode == KEY_E: key = "o"
		elif event.keycode == KEY_W: key = "p"
		elif event.keycode == KEY_E: key = "a"
		elif event.keycode == KEY_W: key = "s"
		elif event.keycode == KEY_E: key = "d"
		elif event.keycode == KEY_W: key = "f"
		elif event.keycode == KEY_E: key = "g"
		elif event.keycode == KEY_W: key = "h"
		elif event.keycode == KEY_E: key = "j"
		elif event.keycode == KEY_W: key = "k"
		elif event.keycode == KEY_E: key = "l"
		elif event.keycode == KEY_W: key = "z"
		elif event.keycode == KEY_E: key = "x"
		elif event.keycode == KEY_W: key = "c"
		elif event.keycode == KEY_E: key = "v"
		elif event.keycode == KEY_W: key = "b"
		elif event.keycode == KEY_E: key = "n"
		elif event.keycode == KEY_W: key = "m"

		if key != "":
			if input_cooldown_timer > 0: return

			# Check controlled hero stamina
			if party_stamina[controlled_hero_idx] >= BASE_STAMINA_COST:
				party_stamina[controlled_hero_idx] -= BASE_STAMINA_COST
				input_buffer.append(key)
				SoundManager.play_sfx("click")
				input_cooldown_timer = INPUT_COOLDOWN

				var txt = "Input: "
				for k in input_buffer: txt += k.to_upper() + " "
				emit_signal("targeting_mode_changed", false, txt)

				_sync_player_stamina()
				emit_signal("player_stamina_updated", player_stamina, player_max_stamina)
				emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina)

				if input_buffer.size() >= 3:
					is_targeting_mode = true
					emit_signal("targeting_mode_changed", true, "Combo Ready! Select with Arrows, Confirm with 0")
					_move_cursor(0)
			else:
				emit_signal("log_message", "Not enough stamina!")

func _update_input_label():
	if not is_targeting_mode:
		var text = "Input: "
		for k in input_buffer:
			text += k + " "
		emit_signal("targeting_mode_changed", false, text)

func _move_cursor(direction):
	if enemies_data.size() == 0: return
	var current = target_cursor_index
	for _i in range(enemies_data.size()):
		current += direction
		if current >= enemies_data.size(): current = 0
		if current < 0: current = enemies_data.size() - 1
		if enemies_data[current]["hp"] > 0:
			SoundManager.play_sfx("click")
			target_cursor_index = current
			selected_enemy_index = current
			emit_signal("enemy_updated", enemies_data, enemy_atb_gauges, selected_enemy_index)
			return

func _on_enemy_confirmed(index):
	selected_enemy_index = index
	_execute_combo()
	is_targeting_mode = false
	emit_signal("targeting_mode_changed", false, "Input: ")
	emit_signal("enemy_updated", enemies_data, enemy_atb_gauges, selected_enemy_index)

func _execute_combo():
	var player = GameManager.party[controlled_hero_idx]
	var skills = player.get("skills", {})

	var log_text = player["name"] + " Combo: "

	for key in input_buffer:
		var skill_type = skills.get(key, "damage")
		_apply_skill_effect(skill_type, controlled_hero_idx, selected_enemy_index)

	emit_signal("log_message", log_text)
	input_buffer.clear()
	emit_signal("party_updated", GameManager.party, party_stamina, party_max_stamina)
	emit_signal("enemy_updated", enemies_data, enemy_atb_gauges, selected_enemy_index)
	_check_win_condition()

func _apply_skill_effect(type, user_idx, target_idx):
	var base_dmg = GameManager.party[user_idx].get("base_damage", 2)
	var dmg_bonus = GameManager.get_member_effective_stat(user_idx, "damage", base_dmg)
	var dmg_mult = 1.0

	for d in party_debuffs[user_idx]:
		if d["type"] == "attack_boost": dmg_mult += 0.20

	var final_dmg = int(dmg_bonus * dmg_mult)

	if type == "damage":
		_deal_damage_to_enemy(target_idx, final_dmg)
	elif type == "heavy_damage":
		# Heavy damage now overflows
		_deal_damage_to_enemy(target_idx, final_dmg * 2, true)
	elif type == "damage_bleed":
		_deal_damage_to_enemy(target_idx, final_dmg)
		apply_debuff(false, target_idx, "bleed", 6.0)
	elif type == "damage_slow":
		_deal_damage_to_enemy(target_idx, final_dmg)
		apply_debuff(false, target_idx, "slowed", 5.0)
	elif type == "heal_self":
		GameManager.heal_single(user_idx, final_dmg)
	elif type == "heal_party":
		GameManager.heal_party(final_dmg / 2)
	elif type == "buff_attack":
		apply_debuff(true, user_idx, "attack_boost", 10.0)
		GameManager.heal_party(final_dmg / 2)
	elif type == "damage_aoe_all":
		for i in range(enemies_data.size()):
			if enemies_data[i]["hp"] > 0:
				_deal_damage_to_enemy(i, final_dmg)
	elif type == "damage_cleave":
		# Target and adjacent
		var targets = [target_idx]
		if target_idx - 1 >= 0: targets.append(target_idx - 1)
		if target_idx + 1 < enemies_data.size(): targets.append(target_idx + 1)
		for i in targets:
			if enemies_data[i]["hp"] > 0:
				_deal_damage_to_enemy(i, final_dmg * 0.8)
	elif type == "damage_random":
		# Spread damage randomly
		var remaining = final_dmg * 2
		while remaining > 0:
			var alive = []
			for i in range(enemies_data.size()):
				if enemies_data[i]["hp"] > 0: alive.append(i)
			if alive.size() == 0: break

			var hit_idx = alive.pick_random()
			_deal_damage_to_enemy(hit_idx, 1) # Deal 1 damage per tick
			remaining -= 1

func _find_next_alive_enemy(start_idx):
	var next = start_idx
	for i in range(enemies_data.size()):
		next = (next + 1) % enemies_data.size()
		if enemies_data[next]["hp"] > 0:
			return next
	return -1

func _deal_damage_to_enemy(idx, amount, allow_overflow = false):
	if idx < 0 or idx >= enemies_data.size(): return
	if enemies_data[idx]["hp"] > 0:
		var dmg_to_deal = min(enemies_data[idx]["hp"], amount)
		var overflow = amount - dmg_to_deal

		enemies_data[idx]["hp"] -= dmg_to_deal
		enemies_data[idx]["last_attacker"] = controlled_hero_idx
		SoundManager.play_sfx("hit")

		if enemies_data[idx]["hp"] <= 0:
			var next = _find_next_alive_enemy(idx)
			if next != -1:
				target_cursor_index = next
				selected_enemy_index = next
				emit_signal("enemy_updated", enemies_data, enemy_atb_gauges, selected_enemy_index)

				if allow_overflow and overflow > 0:
					emit_signal("log_message", "Damage Overflows!")
					_deal_damage_to_enemy(next, overflow, true)

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
		if not is_combat_active: return # Already finished
		is_combat_active = false
		SoundManager.play_sfx("victory")

		# Drop Calculation
		var drops = []
		for e in enemies_data:
			var e_id = e.get("id", "slime") # Assuming enemy data has ID or we deduce it
			# Since get_level_data duplicates, we need to ensure ID is preserved or deduce it from name/stats
			# Actually, I need to pass ID in enemies_data.
			# Let's mock drops for now or use GameManager helper if we update it.
			# The prompt says: "items droped from enemies... droptable with percentages on a file"
			var d = GameManager.get_drops_for_enemy(e.get("name", "").to_lower()) # Fallback to name-based lookup
			for item in d:
				drops.append(item)
				GameManager.inventory.append(item)

		var level_ups = GameManager.gain_rewards(total_xp, total_gold)

		var summary = {
			"gold": total_gold,
			"xp": total_xp,
			"drops": drops,
			"level_ups": level_ups
		}

		emit_signal("log_message", "Victory! gained " + str(total_xp) + " XP and " + str(total_gold) + " Gold.")

		if GameManager.selected_level == 5 or GameManager.selected_level == 9:
			if not (GameManager.selected_level in GameManager.completed_levels):
				GameManager.mark_level_complete(GameManager.selected_level)
				await get_tree().create_timer(2.0).timeout
				get_tree().change_scene_to_file("res://scenes/HeroSelection.tscn")
				return

		GameManager.mark_level_complete(GameManager.selected_level)
		GameManager.save_game()

		await get_tree().create_timer(2.0).timeout
		emit_signal("combat_ended", true, summary)

func _check_loss_condition():
	var all_dead = true
	for m in GameManager.party:
		if m["hp"] > 0:
			all_dead = false
			break
	if all_dead:
		if not is_combat_active: return # Already finished
		is_combat_active = false
		SoundManager.play_sfx("click")
		emit_signal("log_message", "Defeat...")
		await get_tree().create_timer(2.0).timeout
		emit_signal("combat_ended", false)
