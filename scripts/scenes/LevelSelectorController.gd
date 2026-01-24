extends Node

# Signals for the View to listen to
signal gold_updated(amount)
signal shop_updated(items_data)
signal inventory_updated(inventory_data, hero_idx)
signal stats_updated(party_data)
signal levels_updated(completed_levels)
signal game_won
signal message_log(text)

var selected_hero_idx = 0

func _ready():
	SoundManager.play_music("HubTheme")
	call_deferred("refresh_all")

func refresh_all():
	emit_signal("gold_updated", GameManager.gold)
	emit_signal("levels_updated", GameManager.completed_levels)
	emit_signal("shop_updated", GameManager.item_database)
	emit_signal("inventory_updated", GameManager.inventory, selected_hero_idx)
	emit_signal("stats_updated", GameManager.party)
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
	for i in range(1, 6):
		if not i in GameManager.completed_levels:
			all_done = false
			break
	if all_done:
		SoundManager.play_sfx("win_game")
		emit_signal("game_won")
