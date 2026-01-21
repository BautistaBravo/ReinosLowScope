extends Node

const SAVE_PATH = "user://savegame.json"
const ENEMIES_DATA_PATH = "res://data/enemies.json"
const LEVELS_DATA_PATH = "res://data/levels.json"

# Party structure: Array of Dictionaries
# { "name": String, "level": int, "xp": int, "hp": int, "max_hp": int }
var party = []
var selected_level = 1

var enemy_database = {}
var level_database = {}

func _ready():
	_load_static_data()

func _load_static_data():
	# Load Enemies
	if FileAccess.file_exists(ENEMIES_DATA_PATH):
		var file = FileAccess.open(ENEMIES_DATA_PATH, FileAccess.READ)
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK:
			enemy_database = json.data
		else:
			push_error("Failed to parse enemies.json")
	else:
		push_error("enemies.json not found")

	# Load Levels
	if FileAccess.file_exists(LEVELS_DATA_PATH):
		var file = FileAccess.open(LEVELS_DATA_PATH, FileAccess.READ)
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK:
			level_database = json.data
		else:
			push_error("Failed to parse levels.json")
	else:
		push_error("levels.json not found")

func new_game():
	_init_default_party()
	save_game()

func _init_default_party():
	party = []
	# Create 3 default members
	for i in range(3):
		party.append({
			"name": "Hero " + str(i+1),
			"level": 1,
			"xp": 0,
			"hp": 20,
			"max_hp": 20
		})

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"party": party
		}
		file.store_string(JSON.stringify(data))
		print("Game Saved")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.data
			if "party" in data:
				party = data["party"]
			return true
	return false

func get_level_data(level_index):
	var enemies = []
	var str_index = str(level_index)

	if level_database.has(str_index):
		var enemy_ids = level_database[str_index]
		for id in enemy_ids:
			if enemy_database.has(id):
				# Duplicate dictionary to avoid reference issues during combat modifications
				enemies.append(enemy_database[id].duplicate(true))
			else:
				push_warning("Enemy ID not found: " + id)
	else:
		# Fallback if level not defined
		print("Level not found in DB, using fallback.")
		enemies.append(enemy_database.get("slime", {
			"name": "Fallback Slime", "hp": 10, "max_hp": 10, "damage": 1, "speed": 10, "xp_reward": 5, "ai_type": "random"
		}).duplicate(true))

	return enemies

func heal_party(amount):
	for member in party:
		if member["hp"] > 0:
			member["hp"] = min(member["hp"] + amount, member["max_hp"])

func damage_party_member(index, amount):
	if index >= 0 and index < party.size():
		var member = party[index]
		member["hp"] = max(0, member["hp"] - amount)

func gain_party_xp(amount):
	for member in party:
		if member["hp"] > 0:
			member["xp"] += amount
			while member["xp"] >= member["level"] * 100:
				member["xp"] -= member["level"] * 100
				member["level"] += 1
				member["max_hp"] += 5
				member["hp"] = member["max_hp"]
