extends Node

# Signals for the View to listen to
signal gold_updated(amount)
signal shop_updated(items_data)
signal inventory_updated(inventory_data, hero_idx)
signal stats_updated(party_data)
signal levels_updated(completed_levels)
signal game_won
signal message_log(text)
signal blacksmith_updated(recipes_data)

var selected_hero_idx = 0
var current_tab = "Levels"

func _ready():
	SoundManager.play_music("HubTheme")
	call_deferred("refresh_all")

func refresh_all():
	emit_signal("gold_updated", GameManager.gold)
	emit_signal("levels_updated", GameManager.completed_levels)

	# Filter shop items based on level 10 completion
	var shop_items = GameManager.item_database.duplicate()
	var level_10_done = 10 in GameManager.completed_levels
	if not level_10_done:
		var filtered = {}
		for id in shop_items:
			var item = shop_items[id]
			# Filter out items > 100g if level 10 not done
			if item.get("tier", 0) <= 1:
				filtered[id] = item
		shop_items = filtered

	emit_signal("shop_updated", shop_items)
	emit_signal("inventory_updated", GameManager.inventory, selected_hero_idx)
	emit_signal("stats_updated", GameManager.party)
	emit_signal("blacksmith_updated", GameManager.recipe_database)
	_check_win()

func select_hero(idx):
	SoundManager.play_sfx("click")
	selected_hero_idx = idx
	emit_signal("inventory_updated", GameManager.inventory, selected_hero_idx)

func set_ai_combo(hero_idx, combo):
	if hero_idx >= 0 and hero_idx < GameManager.party.size():
		GameManager.party[hero_idx]["ai_combo"] = combo
		GameManager.save_game()
		emit_signal("stats_updated", GameManager.party)
		emit_signal("message_log", "AI Combo Updated")

func buy_item(item_id):
	if GameManager.buy_item(item_id):
		SoundManager.play_sfx("buy")
		emit_signal("gold_updated", GameManager.gold)
		emit_signal("inventory_updated", GameManager.inventory, selected_hero_idx)
		emit_signal("stats_updated", GameManager.party)
		emit_signal("message_log", "Bought " + str(item_id))
	else:
		SoundManager.play_sfx("click")
		emit_signal("message_log", "Not enough gold!")

func sell_item(item_id):
	if GameManager.sell_item(item_id):
		SoundManager.play_sfx("buy")
		emit_signal("gold_updated", GameManager.gold)
		emit_signal("inventory_updated", GameManager.inventory, selected_hero_idx)
		emit_signal("message_log", "Sold " + item_id)
	else:
		SoundManager.play_sfx("click")

func equip_item(item_id):
	SoundManager.play_sfx("click")
	GameManager.equip_item(selected_hero_idx, item_id)
	emit_signal("inventory_updated", GameManager.inventory, selected_hero_idx)
	emit_signal("stats_updated", GameManager.party)

func unequip_item(slot):
	SoundManager.play_sfx("click")
	GameManager.unequip_item(selected_hero_idx, slot)
	emit_signal("inventory_updated", GameManager.inventory, selected_hero_idx)
	emit_signal("stats_updated", GameManager.party)

func improve_item(base_item, recipe_id):
	if GameManager.improve_item(base_item, recipe_id):
		SoundManager.play_sfx("buy")
		emit_signal("gold_updated", GameManager.gold)
		emit_signal("inventory_updated", GameManager.inventory, selected_hero_idx)
		emit_signal("message_log", "Item Improved!")
	else:
		SoundManager.play_sfx("click")
		emit_signal("message_log", "Cannot improve item")

func select_level(lvl):
	SoundManager.play_sfx("click")
	GameManager.selected_level = lvl
	# View handles scene change

func save_game():
	SoundManager.play_sfx("click")
	GameManager.save_game()
	emit_signal("message_log", "Game Saved")

func _check_win():
	var all_done = true
	for i in range(1, 21):
		if not i in GameManager.completed_levels:
			all_done = false
			break
	if all_done:
		SoundManager.play_sfx("win_game")
		emit_signal("game_won")
