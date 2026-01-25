extends Control

# This View constructs the UI programmatically but separates logic to the Controller
var controller
var content_area
var tabs_container
var background_rect

# UI References for updates
var gold_label
var levels_container
var shop_container
var inventory_container
var stats_container
var blacksmith_container
var log_label

# State
var current_world_page = 1

# AI Combo Input Overlay
var combo_overlay: Panel
var combo_label: Label
var combo_buffer = []
var combo_target_hero_idx = -1

# Blacksmith State
var blacksmith_selected_item = null
var blacksmith_recipes = {}

func _ready():
	# 1. Instantiate Controller
	controller = load("res://scripts/scenes/LevelSelectorController.gd").new()
	controller.name = "Controller"
	add_child(controller)

	# 2. Connect Signals
	controller.gold_updated.connect(_on_gold_updated)
	controller.shop_updated.connect(_on_shop_updated)
	controller.inventory_updated.connect(_on_inventory_updated)
	controller.stats_updated.connect(_on_stats_updated)
	controller.levels_updated.connect(_on_levels_updated)
	controller.game_won.connect(_on_game_won)
	controller.message_log.connect(_on_message_log)
	controller.blacksmith_updated.connect(_on_blacksmith_updated)

	# 3. Build Graphic UI (Node structure)
	_build_visuals()
	_build_combo_overlay()

func _build_visuals():
	# Background
	background_rect = TextureRect.new()
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Load Hub Background
	if ResourceLoader.exists("res://sprites/bg_hub.png"):
		background_rect.texture = load("res://sprites/bg_hub.png")
	else:
		var placeholder = PlaceholderTexture2D.new()
		placeholder.size = Vector2(1152, 648)
		background_rect.texture = placeholder
		background_rect.modulate = Color(0.1, 0.1, 0.2)

	add_child(background_rect)

	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)

	# Header
	var header = HBoxContainer.new()
	main_vbox.add_child(header)

	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.text = "Gold: ..."
	header.add_child(gold_label)

	# Log
	log_label = Label.new()
	log_label.modulate = Color.YELLOW
	header.add_child(log_label)

	# Tabs Buttons
	tabs_container = HBoxContainer.new()
	main_vbox.add_child(tabs_container)

	var tab_names = ["Levels", "Shop", "Inventory", "Stats", "Blacksmith"]
	for t in tab_names:
		var btn = Button.new()
		btn.text = t
		# Graphic for Tab
		btn.icon = _create_placeholder_icon(Color.WHITE)
		btn.pressed.connect(_on_tab_pressed.bind(t))
		tabs_container.add_child(btn)

	# Content Area
	content_area = MarginContainer.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_area)

	# Init Containers
	levels_container = GridContainer.new()
	levels_container.columns = 3

	shop_container = VBoxContainer.new()

	inventory_container = VBoxContainer.new()

	stats_container = HBoxContainer.new()

	blacksmith_container = VBoxContainer.new()

	# Default view
	_on_tab_pressed("Levels")

func _build_combo_overlay():
	combo_overlay = Panel.new()
	combo_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combo_overlay.visible = false
	add_child(combo_overlay)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	combo_overlay.add_child(vbox)

	var lbl = Label.new()
	lbl.text = "Press 3 keys (Q, W, E) to set AI Combo:"
	vbox.add_child(lbl)

	combo_label = Label.new()
	combo_label.text = "..."
	combo_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(combo_label)

	var cancel = Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): combo_overlay.visible = false)
	vbox.add_child(cancel)

func _input(event):
	if combo_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			var k = ""
			if event.keycode == KEY_Q: k = "q"
			elif event.keycode == KEY_W: k = "w"
			elif event.keycode == KEY_E: k = "e"

			if k != "":
				combo_buffer.append(k)
				_update_combo_label()
				if combo_buffer.size() >= 3:
					controller.set_ai_combo(combo_target_hero_idx, combo_buffer.duplicate())
					combo_overlay.visible = false

func _update_combo_label():
	var txt = ""
	for k in combo_buffer: txt += k.to_upper() + " "
	combo_label.text = txt

func _on_set_combo_pressed(hero_idx):
	combo_target_hero_idx = hero_idx
	combo_buffer = []
	_update_combo_label()
	combo_overlay.visible = true

func _create_placeholder_icon(color):
	var p = PlaceholderTexture2D.new()
	p.size = Vector2(16, 16)
	return p

func _on_tab_pressed(tab_name):
	# Clear Content
	for c in content_area.get_children():
		content_area.remove_child(c)

	if tab_name == "Levels":
		content_area.add_child(levels_container)
	elif tab_name == "Shop":
		content_area.add_child(shop_container)
	elif tab_name == "Inventory":
		content_area.add_child(inventory_container)
	elif tab_name == "Stats":
		content_area.add_child(stats_container)
	elif tab_name == "Blacksmith":
		content_area.add_child(blacksmith_container)
		_refresh_blacksmith_ui()

# --- Signal Callbacks ---

func _on_gold_updated(amount):
	gold_label.text = "Gold: " + str(amount)

func _on_levels_updated(completed_list):
	for c in levels_container.get_children():
		c.queue_free()

	var start_lvl = 1
	var end_lvl = 10
	if current_world_page == 2:
		start_lvl = 11
		end_lvl = 20

	for i in range(start_lvl, end_lvl + 1):
		# Hide level if previous not completed (except first level of world/game)
		var unlocked = false
		if i == 1:
			unlocked = true
		elif (i - 1) in completed_list:
			unlocked = true

		if not unlocked:
			continue

		var btn = Button.new()
		if i > 10:
			btn.text = "2-" + str(i - 10)
		else:
			btn.text = "Level " + str(i)

		btn.icon = _create_placeholder_icon(Color.RED) # Graphic node
		btn.custom_minimum_size = Vector2(100, 100)

		if i in completed_list:
			btn.modulate = Color.GREEN

		btn.pressed.connect(_on_level_selected.bind(i))
		levels_container.add_child(btn)

	# Navigation buttons
	if current_world_page == 1:
		var all_w1_done = true
		for l in range(1, 11):
			if not l in completed_list:
				all_w1_done = false
				break
		if all_w1_done:
			var next_btn = Button.new()
			next_btn.text = "Next World >>"
			next_btn.custom_minimum_size = Vector2(200, 50)
			next_btn.pressed.connect(func():
				current_world_page = 2
				_on_levels_updated(completed_list)
			)
			levels_container.add_child(next_btn)
	elif current_world_page == 2:
		var prev_btn = Button.new()
		prev_btn.text = "<< Prev World"
		prev_btn.custom_minimum_size = Vector2(200, 50)
		prev_btn.pressed.connect(func():
			current_world_page = 1
			_on_levels_updated(completed_list)
		)
		levels_container.add_child(prev_btn)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(func(): controller.save_game())
	levels_container.add_child(save_btn)

func _on_level_selected(idx):
	controller.select_level(idx)
	get_tree().change_scene_to_file("res://scenes/CombatAnimated.tscn")

func _on_game_won():
	var win = Label.new()
	win.text = "Ganaste, Muchas gracias por ayudar probando!!!"
	win.modulate = Color.GREEN
	win.add_theme_font_size_override("font_size", 40)
	add_child(win)
	win.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

func _on_message_log(text):
	log_label.text = text
	await get_tree().create_timer(2.0).timeout
	if log_label.text == text:
		log_label.text = ""

func _on_shop_updated(items_db):
	for c in shop_container.get_children():
		c.queue_free()

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_container.add_child(scroll)

	var list = VBoxContainer.new()
	scroll.add_child(list)

	for id in items_db:
		var item = items_db[id]
		var row = HBoxContainer.new()
		list.add_child(row)

		# Graphic Icon
		var icon = TextureRect.new()
		icon.texture = _create_placeholder_icon(Color.YELLOW)
		row.add_child(icon)

		var lbl = Label.new()
		lbl.text = item["name"] + " (" + str(item["price"]) + "g)"
		row.add_child(lbl)

		var btn = Button.new()
		btn.text = "Buy"
		btn.pressed.connect(controller.buy_item.bind(id))
		row.add_child(btn)

func _on_inventory_updated(inv_list, hero_idx):
	for c in inventory_container.get_children():
		c.queue_free()

	# Hero Selector (Sprites)
	var hero_row = HBoxContainer.new()
	inventory_container.add_child(hero_row)
	for i in range(GameManager.party.size()):
		var btn = Button.new()
		# Placeholder Sprite for Hero
		# Use real sprite path if possible, else placeholder
		if GameManager.party[i].has("sprite") and ResourceLoader.exists(GameManager.party[i]["sprite"]):
			var tex = load(GameManager.party[i]["sprite"])
			btn.icon = tex
		else:
			btn.icon = _create_placeholder_icon(Color.BLUE)

		btn.text = GameManager.party[i]["name"]
		if i == hero_idx:
			btn.modulate = Color.YELLOW
		else:
			btn.modulate = Color.WHITE
		btn.pressed.connect(controller.select_hero.bind(i))
		hero_row.add_child(btn)

	# Equipment Slots
	var equip_grid = GridContainer.new()
	equip_grid.columns = 5
	inventory_container.add_child(equip_grid)

	var hero = GameManager.party[hero_idx]
	for slot in hero["equipment"]:
		var item_id = hero["equipment"][slot]
		var btn = Button.new()
		var txt = slot
		if item_id:
			txt += ": " + item_id
			btn.modulate = Color.CYAN
		else:
			txt += ": Empty"
		btn.text = txt
		btn.pressed.connect(controller.unequip_item.bind(slot))
		equip_grid.add_child(btn)

	# Inventory List
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_container.add_child(scroll)
	var list = VBoxContainer.new()
	scroll.add_child(list)

	for i in range(inv_list.size()):
		var item_id = inv_list[i]
		var btn = Button.new()
		btn.text = "Equip " + item_id
		btn.icon = _create_placeholder_icon(Color.MAGENTA)
		btn.pressed.connect(controller.equip_item.bind(item_id))
		list.add_child(btn)

func _on_stats_updated(party_data):
	for c in stats_container.get_children():
		c.queue_free()

	for i in range(party_data.size()):
		var member = party_data[i]
		var panel = PanelContainer.new()
		stats_container.add_child(panel)
		var vbox = VBoxContainer.new()
		panel.add_child(vbox)

		# Sprite
		var sprite = TextureRect.new()
		if member.has("sprite") and ResourceLoader.exists(member["sprite"]):
			sprite.texture = load(member["sprite"])
		else:
			sprite.texture = _create_placeholder_icon(Color.WHITE)
		sprite.custom_minimum_size = Vector2(32, 32)
		vbox.add_child(sprite)

		var lbl = Label.new()
		lbl.text = member["name"] + "\nLevel: " + str(member["level"]) + "\nHP: " + str(member["hp"]) + "/" + str(member["max_hp"])
		vbox.add_child(lbl)

		# AI Combo UI
		var combo_btn = Button.new()
		combo_btn.text = "Set AI Combo"
		combo_btn.pressed.connect(_on_set_combo_pressed.bind(i))
		vbox.add_child(combo_btn)

		var combo_lbl = Label.new()
		var current_combo = member.get("ai_combo", [])
		if current_combo.is_empty():
			combo_lbl.text = "AI: Random"
		else:
			var txt = "AI: "
			for k in current_combo: txt += k.to_upper() + " "
			combo_lbl.text = txt
		vbox.add_child(combo_lbl)

func _on_blacksmith_updated(recipes):
	blacksmith_recipes = recipes
	_refresh_blacksmith_ui()

func _refresh_blacksmith_ui():
	for c in blacksmith_container.get_children():
		c.queue_free()

	var hbox = HBoxContainer.new()
	blacksmith_container.add_child(hbox)

	# Inventory Column
	var inv_col = VBoxContainer.new()
	inv_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(inv_col)

	var lbl = Label.new()
	lbl.text = "Select Item to Improve:"
	inv_col.add_child(lbl)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_col.add_child(scroll)

	var list = VBoxContainer.new()
	scroll.add_child(list)

	for i in range(GameManager.inventory.size()):
		var item_id = GameManager.inventory[i]
		var btn = Button.new()
		btn.text = item_id
		if item_id == blacksmith_selected_item:
			btn.modulate = Color.YELLOW
		btn.pressed.connect(func():
			blacksmith_selected_item = item_id
			_refresh_blacksmith_ui()
		)
		list.add_child(btn)

	# Upgrade Column
	var upg_col = VBoxContainer.new()
	upg_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(upg_col)

	var lbl2 = Label.new()
	lbl2.text = "Available Upgrades:"
	upg_col.add_child(lbl2)

	if blacksmith_selected_item:
		var found = false
		for rid in blacksmith_recipes:
			var r = blacksmith_recipes[rid]
			if r["base_item"] == blacksmith_selected_item:
				found = true
				var panel = PanelContainer.new()
				upg_col.add_child(panel)
				var vbox = VBoxContainer.new()
				panel.add_child(vbox)

				var r_lbl = Label.new()
				var txt = "Result: " + r["result_item"] + "\nCost: " + str(r.get("gold", 0)) + "g"
				var mats = r.get("materials", {})
				for m in mats:
					txt += "\n- " + m + ": " + str(mats[m])
				r_lbl.text = txt
				vbox.add_child(r_lbl)

				var btn = Button.new()
				btn.text = "Improve"
				btn.pressed.connect(func():
					controller.improve_item(blacksmith_selected_item, rid)
					blacksmith_selected_item = null # Reset selection after attempt
				)
				vbox.add_child(btn)
		if not found:
			var l = Label.new()
			l.text = "No upgrades for this item."
			upg_col.add_child(l)
	else:
		var l = Label.new()
		l.text = "Select an item from the left."
		upg_col.add_child(l)
