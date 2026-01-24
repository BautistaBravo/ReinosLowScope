extends Node

signal options_updated(heroes)
signal hero_selected(hero)

func _ready():
	_generate_options()

func _generate_options():
	var all_hero_ids = GameManager.hero_database.keys()
	var available_ids = []

	# Filter out heroes already in party to ensure uniqueness across roster (optional but good)
	# And ensure distinct options
	for id in all_hero_ids:
		var already_owned = false
		for member in GameManager.party:
			if member["id"] == id:
				already_owned = true
				break
		if not already_owned:
			available_ids.append(id)

	# If we ran out of new heroes, just fallback to all
	if available_ids.size() < 3:
		available_ids = all_hero_ids.duplicate()

	var options = []
	var selected_indices = []

	while options.size() < 3 and options.size() < available_ids.size():
		var idx = randi() % available_ids.size()
		if not idx in selected_indices:
			selected_indices.append(idx)
			var id = available_ids[idx]
			var data = GameManager.get_hero_data(id).duplicate()
			data["id"] = id
			options.append(data)

	call_deferred("emit_options", options)

func emit_options(opts):
	emit_signal("options_updated", opts)

func select_hero(hero_data):
	GameManager.add_hero_to_party(hero_data["id"])

	# Decide next scene
	# If Party size == 1, it's new game -> Level 1 (or Selector?)
	# Prompt: "when starting a new game... player can click on one... to begin"
	# Usually means go to Level Selector.

	if GameManager.party.size() == 1:
		get_tree().change_scene_to_file("res://scenes/LevelSelectorAnimated.tscn")
	else:
		# Mid-game recruit
		get_tree().change_scene_to_file("res://scenes/LevelSelectorAnimated.tscn")
