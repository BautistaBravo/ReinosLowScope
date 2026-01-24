extends Node

const SAVE_PATH = "user://savegame.json"
const ENEMIES_DATA_PATH = "res://data/enemies.json"
const LEVELS_DATA_PATH = "res://data/levels.json"
const ITEMS_DATA_PATH = "res://data/items.json"
const GROWTH_DATA_PATH = "res://data/growth.json"

var party = []
var inventory = []
var gold = 100
var selected_level = 1
var completed_levels = [] # Array of ints

var enemy_database = {}
var level_database = {}
var item_database = {}
var growth_database = {}

func _ready():
	_load_static_data()

func _load_static_data():
	if FileAccess.file_exists(ENEMIES_DATA_PATH):
		var file = FileAccess.open(ENEMIES_DATA_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			enemy_database = json.data

	if FileAccess.file_exists(LEVELS_DATA_PATH):
		var file = FileAccess.open(LEVELS_DATA_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			level_database = json.data

	if FileAccess.file_exists(ITEMS_DATA_PATH):
		var file = FileAccess.open(ITEMS_DATA_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			item_database = json.data

	if FileAccess.file_exists(GROWTH_DATA_PATH):
		var file = FileAccess.open(GROWTH_DATA_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			growth_database = json.data

func new_game():
	_init_default_party()
	save_game()

func _init_default_party():
	party = []
	inventory = []
	gold = 100
	completed_levels = []

	var base_stats = get_stats_for_level(1)

	# Define party with specific classes and sprites
	var classes = [
		{"name": "Guerrero", "sprite": "res://sprites/warrior.png"},
		{"name": "Mago", "sprite": "res://sprites/mage.png"},
		{"name": "Picaro", "sprite": "res://sprites/rogue.png"}
	]

	for i in range(classes.size()):
		party.append({
			"name": classes[i]["name"],
			"sprite": classes[i]["sprite"],
			"level": 1,
			"xp": 0,
			"hp": base_stats["hp"],
			"max_hp": base_stats["hp"],
			"base_damage": base_stats["damage"],
			"base_stamina": base_stats["stamina"],
			"base_stamina_regen": base_stats["stamina_regen"],
			"equipment": {
				"weapon": null,
				"helmet": null,
				"chest": null,
				"pants": null,
				"boots": null
			}
		})

func get_stats_for_level(lvl):
	var s_lvl = str(lvl)
	if growth_database.has(s_lvl):
		return growth_database[s_lvl]
	else:
		return { "hp": 20, "damage": 2, "stamina": 100, "stamina_regen": 1.0, "exp_required": 100 }

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"party": party,
			"inventory": inventory,
			"gold": gold,
			"completed_levels": completed_levels
		}
		file.store_string(JSON.stringify(data))
		print("Game Saved")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			if "party" in data:
				party = data["party"]
			if "inventory" in data:
				inventory = data["inventory"]
			if "gold" in data:
				gold = int(data["gold"])
			if "completed_levels" in data:
				completed_levels = []
				for lvl in data["completed_levels"]:
					completed_levels.append(int(lvl))
			else:
				completed_levels = []
			return true
	return false

func get_level_data(level_index):
	var enemies = []
	var str_index = str(level_index)

	if level_database.has(str_index):
		var enemy_ids = level_database[str_index]
		for id in enemy_ids:
			if enemy_database.has(id):
				enemies.append(enemy_database[id].duplicate(true))
	else:
		enemies.append(enemy_database.get("slime", {
			"name": "Fallback Slime", "hp": 10, "max_hp": 10, "damage": 1, "speed": 10, "xp_reward": 5, "ai_type": "random"
		}).duplicate(true))

	return enemies

func heal_party(amount):
	for i in range(party.size()):
		var member = party[i]
		if member["hp"] > 0:
			var max_h = get_member_effective_stat(i, "hp", member["max_hp"])
			member["hp"] = min(member["hp"] + amount, max_h)

func damage_party_member(index, amount):
	if index >= 0 and index < party.size():
		var member = party[index]
		member["hp"] = max(0, member["hp"] - amount)

func gain_rewards(xp_amount, gold_amount):
	gold += gold_amount
	for i in range(party.size()):
		var member = party[i]
		if member["hp"] > 0:
			member["xp"] += xp_amount
			_check_level_up(i, member)

func _check_level_up(idx, member):
	var current_lvl = member["level"]
	var stats = get_stats_for_level(current_lvl)
	var required = stats.get("exp_required", 100)

	if member["xp"] >= required:
		member["xp"] -= required
		member["level"] += 1

		# Update base stats based on NEW level
		var new_stats = get_stats_for_level(member["level"])
		member["max_hp"] = new_stats["hp"]
		member["base_damage"] = new_stats["damage"]
		member["base_stamina"] = new_stats["stamina"]
		member["base_stamina_regen"] = new_stats["stamina_regen"]

		# Full Heal to Effective Max HP (Base + Items)
		var effective_max = get_member_effective_stat(idx, "hp", member["max_hp"])
		member["hp"] = effective_max

		# Check recursive level up (if XP was massive)
		_check_level_up(idx, member)

func mark_level_complete(level_idx):
	if not level_idx in completed_levels:
		completed_levels.append(level_idx)
		save_game()

# --- Item System ---

func buy_item(item_id):
	if item_database.has(item_id):
		var price = item_database[item_id]["price"]
		if gold >= price:
			gold -= price
			inventory.append(item_id)
			return true
	return false

func equip_item(member_idx, item_id):
	if member_idx < 0 or member_idx >= party.size(): return
	if not item_database.has(item_id): return

	var item_def = item_database[item_id]
	var slot = item_def["slot"]
	var member = party[member_idx]

	var current_equipped = member["equipment"][slot]

	if item_id in inventory:
		inventory.erase(item_id)
		if current_equipped != null:
			inventory.append(current_equipped)
		member["equipment"][slot] = item_id

func unequip_item(member_idx, slot):
	if member_idx < 0 or member_idx >= party.size(): return
	var member = party[member_idx]
	var item_id = member["equipment"][slot]

	if item_id != null:
		member["equipment"][slot] = null
		inventory.append(item_id)

func get_member_effective_stat(member_idx, stat_name, base_value):
	if member_idx < 0 or member_idx >= party.size(): return base_value
	var val = base_value
	var member = party[member_idx]

	for slot in member["equipment"]:
		var i_id = member["equipment"][slot]
		if i_id and item_database.has(i_id):
			var stats = item_database[i_id].get("stats", {})
			if stat_name in stats:
				val += stats[stat_name]
	return val

func get_party_total_stat_bonus(stat_name):
	var total = 0.0
	for m_idx in range(party.size()):
		total += get_member_effective_stat(m_idx, stat_name, 0)
	return total
