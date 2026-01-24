extends Control

var controller
var container

func _ready():
	controller = load("res://scripts/scenes/HeroSelectionController.gd").new()
	add_child(controller)
	controller.options_updated.connect(_on_options)

	# Visuals
	var bg = TextureRect.new()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ph = PlaceholderTexture2D.new()
	ph.size = Vector2(1152, 648)
	bg.texture = ph
	bg.modulate = Color(0.1, 0.1, 0.1)
	add_child(bg)

	var label = Label.new()
	label.text = "Choose a Hero"
	label.add_theme_font_size_override("font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(label)

	container = HBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	container.add_theme_constant_override("separation", 20)
	add_child(container)

func _on_options(heroes):
	for c in container.get_children():
		c.queue_free()

	for h in heroes:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 300)

		# Rarity Color
		var color = Color.GRAY
		if h.get("rarity") == "rare": color = Color.BLUE
		if h.get("rarity") == "epic": color = Color.PURPLE

		# Background for Rarity
		var bg_color = ColorRect.new()
		bg_color.color = color
		bg_color.color.a = 0.5 # Semi-transparent
		bg_color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bg_color)

		var vbox = VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)

		var sprite = TextureRect.new()
		if h.has("sprite") and ResourceLoader.exists(h["sprite"]):
			sprite.texture = load(h["sprite"])
		else:
			var p = PlaceholderTexture2D.new()
			p.size = Vector2(64, 64)
			sprite.texture = p
		sprite.custom_minimum_size = Vector2(128, 128)
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(sprite)

		var name_lbl = Label.new()
		name_lbl.text = h["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		# Stats
		var stats_txt = "HP: " + str(h["stats"]["hp"]) + "\nDmg: " + str(h["stats"]["damage"])
		var stats_lbl = Label.new()
		stats_lbl.text = stats_txt
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stats_lbl)

		btn.pressed.connect(controller.select_hero.bind(h))
		container.add_child(btn)
