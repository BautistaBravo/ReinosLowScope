extends Node

signal options_updated(heroes)
signal hero_selected(hero)

func _ready():
	_generate_options()

func _generate_options():
	var all_hero_ids = GameManager.hero_database.keys()
	var options = []

	for i in range(3):
		var id = all_hero_ids.pick_random()
		# Simple random, allow duplicates? Prompt doesn't say. Let's try unique.
		# If roster small, duplicates happen.
		var hero_def = GameManager.get_hero_data(id)
		options.append(hero_def)

	# Store keys or full defs? We need to pass data to view.
	# View needs name, sprite, rarity.
	# We also need the ID to add to party.

	# Add ID to the dictionary passed to view
	for i in range(options.size()):
		# options[i] is a dictionary ref from database? duplicate it
		var opt = options[i].duplicate()
		opt["id"] = all_hero_ids[i] # Wait, picking logic was sloppy above.
		# Let's fix picking
		pass

	options = []
	for i in range(3):
		var id = all_hero_ids.pick_random()
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
