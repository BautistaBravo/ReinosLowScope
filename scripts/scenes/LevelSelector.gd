extends Control

var selected_hero_idx = 0
var tab_container: TabContainer
var gold_label: Label
var inventory_list_container: VBoxContainer
var equipment_grid: GridContainer
var shop_list_container: VBoxContainer
var level_buttons = []

func _ready():
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Header (Gold)
	var header = HBoxContainer.new()
	root.add_child(header)

	gold_label = Label.new()
	_update_gold_label()
	header.add_child(gold_label)

	# Tab Container
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tab_container)

	# --- TAB 1: LEVELS ---
	var levels_tab = VBoxContainer.new()
	levels_tab.name = "Levels"
	tab_container.add_child(levels_tab)

	# Check Win
	_check_all_levels_completed(levels_tab)

	var lvl_grid = GridContainer.new()
	lvl_grid.columns = 3
	levels_tab.add_child(lvl_grid)

	level_buttons = []
	for i in range(1, 6):
		var btn = Button.new()
		btn.text = "Level " + str(i)
		btn.custom_minimum_size = Vector2(100, 50)
		btn.pressed.connect(_on_level_selected.bind(i))

		# Change color if completed
		if i in GameManager.completed_levels:
			btn.modulate = Color.GREEN

		lvl_grid.add_child(btn)
		level_buttons.append(btn)

	var save_btn = Button.new()
	save_btn.text = "Save Game"
	save_btn.pressed.connect(_on_save_pressed)
	levels_tab.add_child(save_btn)

	var back_btn = Button.new()
	back_btn.text = "Back to Menu"
	back_btn.pressed.connect(_on_back_pressed)
	levels_tab.add_child(back_btn)

	# --- TAB 2: SHOP ---
	var shop_tab = ScrollContainer.new()
	shop_tab.name = "Shop"
	tab_container.add_child(shop_tab)

	shop_list_container = VBoxContainer.new()
	shop_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_tab.add_child(shop_list_container)

	_refresh_shop()

	# --- TAB 3: INVENTORY ---
	var inv_tab = VBoxContainer.new()
	inv_tab.name = "Inventory"
	tab_container.add_child(inv_tab)

	var hero_box = HBoxContainer.new()
	inv_tab.add_child(hero_box)
	for i in range(GameManager.party.size()):
		var btn = Button.new()
		btn.text = GameManager.party[i]["name"]
		btn.toggle_mode = true
		btn.button_group = ButtonGroup.new()
		btn.pressed.connect(_on_hero_selected.bind(i))
		hero_box.add_child(btn)

	var equip_lbl = Label.new()
	equip_lbl.text = "Current Equipment:"
	inv_tab.add_child(equip_lbl)

	equipment_grid = GridContainer.new()
	equipment_grid.columns = 5
	inv_tab.add_child(equipment_grid)

	var inv_lbl = Label.new()
	inv_lbl.text = "Inventory (Click to Equip):"
	inv_tab.add_child(inv_lbl)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_tab.add_child(scroll)

	inventory_list_container = VBoxContainer.new()
	inventory_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inventory_list_container)

	_refresh_inventory_tab()

func _check_all_levels_completed(parent_node):
	var all_done = true
	for i in range(1, 6):
		if not i in GameManager.completed_levels:
			all_done = false
			break

	if all_done:
		var win_lbl = Label.new()
		win_lbl.text = "GANASTE EL JUEGO!!!"
		win_lbl.add_theme_font_size_override("font_size", 24)
		win_lbl.add_theme_color_override("font_color", Color.YELLOW)
		win_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent_node.add_child(win_lbl)

		# Spacer
		var sp = Control.new()
		sp.custom_minimum_size = Vector2(0, 20)
		parent_node.add_child(sp)

func _update_gold_label():
	gold_label.text = "Gold: " + str(GameManager.gold)

func _on_level_selected(level_idx):
	GameManager.selected_level = level_idx
	get_tree().change_scene_to_file("res://scenes/Combat.tscn")

func _on_save_pressed():
	GameManager.save_game()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# --- SHOP LOGIC ---
func _refresh_shop():
	for c in shop_list_container.get_children():
		c.queue_free()

	for item_id in GameManager.item_database:
		var item = GameManager.item_database[item_id]
		var hbox = HBoxContainer.new()
		shop_list_container.add_child(hbox)

		var info = Label.new()
		info.text = item["name"] + " (" + item["slot"] + ") - Price: " + str(item["price"])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info)

		var buy_btn = Button.new()
		buy_btn.text = "Buy"
		buy_btn.pressed.connect(_on_buy_pressed.bind(item_id))
		hbox.add_child(buy_btn)

func _on_buy_pressed(item_id):
	if GameManager.buy_item(item_id):
		_update_gold_label()
		_refresh_inventory_tab()
	else:
		print("Not enough gold!")

# --- INVENTORY LOGIC ---
func _on_hero_selected(idx):
	selected_hero_idx = idx
	_refresh_inventory_tab()

func _refresh_inventory_tab():
	for c in equipment_grid.get_children():
		c.queue_free()

	var hero = GameManager.party[selected_hero_idx]
	var equip = hero.get("equipment", {})

	for slot in ["weapon", "helmet", "chest", "pants", "boots"]:
		var slot_btn = Button.new()
		var item_id = equip.get(slot)
		var txt = slot.capitalize() + ": Empty"
		if item_id:
			var item = GameManager.item_database.get(item_id)
			if item:
				txt = slot.capitalize() + ": " + item["name"]

		slot_btn.text = txt
		slot_btn.pressed.connect(_on_unequip_pressed.bind(slot))
		equipment_grid.add_child(slot_btn)

	for c in inventory_list_container.get_children():
		c.queue_free()

	for i in range(GameManager.inventory.size()):
		var item_id = GameManager.inventory[i]
		var item = GameManager.item_database.get(item_id)
		if item:
			var btn = Button.new()
			btn.text = item["name"] + " (" + item["slot"] + ") " + str(item.get("stats", {}))
			btn.pressed.connect(_on_inventory_item_pressed.bind(item_id))
			inventory_list_container.add_child(btn)

func _on_unequip_pressed(slot):
	GameManager.unequip_item(selected_hero_idx, slot)
	_refresh_inventory_tab()

func _on_inventory_item_pressed(item_id):
	GameManager.equip_item(selected_hero_idx, item_id)
	_refresh_inventory_tab()
