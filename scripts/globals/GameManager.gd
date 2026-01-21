extends Node

const SAVE_PATH = "user://savegame.json"

# Party structure: Array of Dictionaries
# { "name": String, "level": int, "xp": int, "hp": int, "max_hp": int }
var party = []
var selected_level = 1

func _ready():
	# If we start the game without loading, we might want a default party or empty.
	# But usually New Game triggers _init_default_party
	pass

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
	# Return enemy configuration for the level
	# Logic: Level N has N enemies (up to 5), stronger stats
	var enemies = []
	var count = clampi(level_index, 1, 5)

	for i in range(count):
		enemies.append({
			"name": "Monster Lvl " + str(level_index),
			"hp": 10 * level_index,
			"max_hp": 10 * level_index,
			"damage": 2 * level_index,
			"xp_reward": 20 * level_index
		})
	return enemies

func heal_party(amount):
	for member in party:
		if member["hp"] > 0: # Only heal alive members? Or resurrect? Assuming alive.
			member["hp"] = min(member["hp"] + amount, member["max_hp"])

func damage_party_member(index, amount):
	if index >= 0 and index < party.size():
		var member = party[index]
		member["hp"] = max(0, member["hp"] - amount)

func gain_party_xp(amount):
	for member in party:
		if member["hp"] > 0: # Only survivors gain XP? Prompt doesn't specify. giving to all.
			member["xp"] += amount
			# Level up logic: Level * 100 XP required
			while member["xp"] >= member["level"] * 100:
				member["xp"] -= member["level"] * 100
				member["level"] += 1
				member["max_hp"] += 5
				member["hp"] = member["max_hp"] # Full heal on level up
