extends Control

# This View constructs the UI programmatically but separates logic to the Controller
var controller
var content_area
var tabs_container

# UI References for updates
var gold_label
var levels_container
var shop_container
var inventory_container
var stats_container
var log_label

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

	# 3. Build Graphic UI (Node structure)
	_build_visuals()

func _build_visuals():
	# Background
	var bg = TextureRect.new()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Placeholder Graphic
	var placeholder = PlaceholderTexture2D.new()
	placeholder.size = Vector2(1152, 648)
	bg.texture = placeholder
	bg.modulate = Color(0.1, 0.1, 0.2) # Dark Blue BG
	add_child(bg)

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

	var tab_names = ["Levels", "Shop", "Inventory", "Stats"]
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

	# Default view
	_on_tab_pressed("Levels")

func _create_placeholder_icon(color):
	var p = PlaceholderTexture2D.new()
	p.size = Vector2(16, 16)
	return p # Can't tint placeholder easily here without ViewportTexture, relying on Button modulate if needed

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

# --- Signal Callbacks ---

func _on_gold_updated(amount):
	gold_label.text = "Gold: " + str(amount)

func _on_levels_updated(completed_list):
	for c in levels_container.get_children():
		c.queue_free()

	for i in range(1, 6):
		var btn = Button.new()
		btn.text = "Level " + str(i)
		btn.icon = _create_placeholder_icon(Color.RED) # Graphic node
		btn.custom_minimum_size = Vector2(100, 100)

		if i in completed_list:
			btn.modulate = Color.GREEN

		btn.pressed.connect(_on_level_selected.bind(i))
		levels_container.add_child(btn)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(func(): controller.save_game())
	levels_container.add_child(save_btn)

func _on_level_selected(idx):
	controller.select_level(idx)
	get_tree().change_scene_to_file("res://scenes/Combat.tscn")

func _on_game_won():
	var win = Label.new()
	win.text = "VICTORY!"
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
		btn.pressed.connect(func(): controller.buy_item(id))
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
		btn.icon = _create_placeholder_icon(Color.BLUE)
		btn.text = GameManager.party[i]["name"]
		if i == hero_idx:
			btn.modulate = Color.YELLOW
		else:
			btn.modulate = Color.WHITE
		btn.pressed.connect(func(): controller.select_hero(i))
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
		btn.pressed.connect(func(): controller.unequip_item(slot))
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
		btn.pressed.connect(func(): controller.equip_item(item_id))
		list.add_child(btn)

func _on_stats_updated(party_data):
	for c in stats_container.get_children():
		c.queue_free()

	for member in party_data:
		var panel = PanelContainer.new()
		stats_container.add_child(panel)
		var vbox = VBoxContainer.new()
		panel.add_child(vbox)

		# Sprite
		var sprite = TextureRect.new()
		sprite.texture = _create_placeholder_icon(Color.WHITE)
		sprite.custom_minimum_size = Vector2(32, 32)
		vbox.add_child(sprite)

		var lbl = Label.new()
		lbl.text = member["name"] + "\nLevel: " + str(member["level"]) + "\nHP: " + str(member["hp"]) + "/" + str(member["max_hp"])
		vbox.add_child(lbl)
