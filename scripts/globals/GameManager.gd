extends Node

const SAVE_PATH = "user://savegame.json"
const ENEMIES_DATA_PATH = "res://data/enemies.json"
const LEVELS_DATA_PATH = "res://data/levels.json"
const ITEMS_DATA_PATH = "res://data/items.json"

# Party structure: Array of Dictionaries
# {
#   "name": String, "level": int, "xp": int, "hp": int, "max_hp": int,
#   "equipment": { "weapon": null, "helmet": null, "chest": null, "pants": null, "boots": null }
# }
var party = []
var inventory = [] # Array of item IDs
var gold = 100 # Starting gold
var selected_level = 1

var enemy_database = {}
var level_database = {}
var item_database = {}

func _ready():
	_load_static_data()

func _load_static_data():
	# Load Enemies
	if FileAccess.file_exists(ENEMIES_DATA_PATH):
		var file = FileAccess.open(ENEMIES_DATA_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			enemy_database = json.data

	# Load Levels
	if FileAccess.file_exists(LEVELS_DATA_PATH):
		var file = FileAccess.open(LEVELS_DATA_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			level_database = json.data

	# Load Items
	if FileAccess.file_exists(ITEMS_DATA_PATH):
		var file = FileAccess.open(ITEMS_DATA_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			item_database = json.data

func new_game():
	_init_default_party()
	save_game()

func _init_default_party():
	party = []
	inventory = []
	gold = 100
	for i in range(3):
		party.append({
			"name": "Hero " + str(i+1),
			"level": 1,
			"xp": 0,
			"hp": 20,
			"max_hp": 20,
			"equipment": {
				"weapon": null,
				"helmet": null,
				"chest": null,
				"pants": null,
				"boots": null
			}
		})

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"party": party,
			"inventory": inventory,
			"gold": gold
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
	# Healing logic usually applies to current HP, capped by Max HP (base + stats)
	# However, simple implementation here just caps at stored max_hp for now.
	# Combat.gd will handle effective max hp? Or should we update stored max_hp?
	# Better: Combat calculates real max hp, but persistent state stores base max_hp.
	# When healing in combat, we cap at Effective Max HP.
	# When persistent state is updated, we cap at Base Max HP? No, HP can be higher if equipped.
	# Let's assume persistent `hp` is the current HP.
	# We need a helper to get Max HP including items.

	# This function is called from Combat, so it might need refactoring or Combat handles it.
	# For now, simplistic approach:
	for i in range(party.size()):
		var member = party[i]
		if member["hp"] > 0:
			var max_h = get_member_effective_stat(i, "hp", member["max_hp"])
			member["hp"] = min(member["hp"] + amount, max_h)

func damage_party_member(index, amount):
	if index >= 0 and index < party.size():
		var member = party[index]
		member["hp"] = max(0, member["hp"] - amount)

func gain_party_xp(amount):
	gold += amount # Gold reward equals XP for simplicity
	for member in party:
		if member["hp"] > 0:
			member["xp"] += amount
			while member["xp"] >= member["level"] * 100:
				member["xp"] -= member["level"] * 100
				member["level"] += 1
				member["max_hp"] += 5
				member["hp"] = member["max_hp"] # Full heal (base) on level up

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
	# item_id is in inventory
	if member_idx < 0 or member_idx >= party.size(): return
	if not item_database.has(item_id): return

	var item_def = item_database[item_id]
	var slot = item_def["slot"]
	var member = party[member_idx]

	# Check if something is equipped
	var current_equipped = member["equipment"][slot]

	# Remove new item from inventory
	if item_id in inventory:
		inventory.erase(item_id) # Erase first occurrence

		# Return old item to inventory
		if current_equipped != null:
			inventory.append(current_equipped)

		# Equip new
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
