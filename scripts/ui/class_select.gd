extends Control

const CLASSES: Array[Dictionary] = [
	{
		"id": "warrior",
		"title": "ВОИН",
		"color": Color(0.82, 0.38, 0.28),
		"desc": "Закованный в сталь боец ближнего боя.\nРесурс: Ярость (копится в бою).\n\nУмения: Рывок, Героический удар,\nВихрь, Боевой крик.\n\nМного здоровья, простая и надёжная защита.",
	},
	{
		"id": "mage",
		"title": "МАГ",
		"color": Color(0.35, 0.62, 1.0),
		"desc": "Хрупкий повелитель огня и льда.\nРесурс: Мана (восстанавливается).\n\nУмения: Огненный шар, Ледяная стрела,\nКольцо льда, Скачок.\n\nБьёт издалека и замедляет врагов.",
	},
	{
		"id": "rogue",
		"title": "РАЗБОЙНИК",
		"color": Color(0.98, 0.84, 0.26),
		"desc": "Стремительный убийца в тенях.\nРесурс: Энергия + очки серии (1–5★).\n\nУмения: Коварный удар / Внезапный удар,\nПотрошение, Незаметность, Удар по почкам.\n\nКрадётся мимо врагов и наносит взрывной урон.",
	},
	{
		"id": "hunter",
		"title": "ОХОТНИК",
		"color": Color(0.56, 0.86, 0.36),
		"desc": "Меткий следопыт с ручным волком.\nРесурс: Мана + питомец Лесной страж.\n\nУмения: Выстрел из лука, Чародейский,\nУкус змеи (яд), Шокирующий, Лечение зверя.\n\nВолк танкует врагов, а вы бьёте издали.",
	},
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Северноземье"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.modulate = Color(1.0, 0.85, 0.4)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Выберите класс героя или продолжите приключение"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(0.85, 0.85, 0.9)
	vbox.add_child(sub)

	if GameState.has_save():
		var cont_center := CenterContainer.new()
		vbox.add_child(cont_center)
		var cont_btn := Button.new()
		cont_btn.text = "Продолжить сохранённую игру (%s)" % GameState.get_save_summary()
		cont_btn.custom_minimum_size = Vector2(460, 46)
		cont_btn.pressed.connect(_continue_saved)
		cont_center.add_child(cont_btn)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	for cls in CLASSES:
		row.add_child(_make_card(cls))


func _make_card(cls: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(268, 330)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.13, 0.95)
	sb.border_color = cls["color"]
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = cls["title"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.modulate = cls["color"]
	v.add_child(name_lbl)

	var desc := Label.new()
	desc.text = cls["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 14)
	v.add_child(desc)

	var btn := Button.new()
	btn.text = "Начать: %s" % String(cls["title"]).capitalize()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(func() -> void: _choose(String(cls["id"])))
	v.add_child(btn)
	return panel


func _choose(class_id: String) -> void:
	AudioManager.play("ui_click")
	GameState.reset_for_new_game(class_id)
	get_tree().change_scene_to_file("res://scenes/main_world.tscn")


func _continue_saved() -> void:
	AudioManager.play("ui_click")
	if GameState.load_game():
		get_tree().change_scene_to_file("res://scenes/main_world.tscn")
