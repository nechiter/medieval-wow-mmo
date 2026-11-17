extends CanvasLayer

class MinimapRadar extends Control:
	const WORLD_SPAN := 42.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.08, 0.13, 0.09, 0.94), true)

		var center := size * 0.5
		var scale_px: float = (minf(size.x, size.y) * 0.5) / WORLD_SPAN

		var player: Node3D = GameState.player_node
		var p_pos := Vector3.ZERO
		var p_yaw := 0.0
		if is_instance_valid(player):
			p_pos = player.global_position
			p_yaw = player.rotation.y

		# Сетка радара
		draw_circle(center, minf(size.x, size.y) * 0.46, Color(0.24, 0.34, 0.24, 0.45))
		draw_line(Vector2(center.x, 4), Vector2(center.x, size.y - 4), Color(0.25, 0.32, 0.25, 0.35), 1.0)
		draw_line(Vector2(4, center.y), Vector2(size.x - 4, center.y), Color(0.25, 0.32, 0.25, 0.35), 1.0)

		# Дорога (-Z на север)
		var road_x: float = center.x + (0.0 - p_pos.x) * scale_px
		if road_x > 4 and road_x < size.x - 4:
			draw_line(Vector2(road_x, 4), Vector2(road_x, size.y - 4), Color(0.45, 0.35, 0.22, 0.55), 5.0)

		# Маркер заставы и рудника
		_draw_world_marker(center, p_pos, Vector3(-8.5, 0, 4.0), scale_px, Color(0.45, 0.65, 0.95), 4.0)
		_draw_world_marker(center, p_pos, Vector3(0.0, 0, -56.0), scale_px, Color(0.65, 0.50, 0.38), 4.5)

		# Мобы
		for node in get_tree().get_nodes_in_group("mobs"):
			var mob := node as MobEntity
			if mob == null:
				continue
			if mob.is_dead():
				if mob.has_loot():
					_draw_world_marker(center, p_pos, mob.global_position, scale_px, Color(1.0, 0.85, 0.22), 3.0)
			else:
				var col := Color(1.0, 0.48, 0.15) if mob.is_elite else Color(0.95, 0.22, 0.22)
				var rad := 4.5 if mob.is_elite else 3.0
				_draw_world_marker(center, p_pos, mob.global_position, scale_px, col, rad)

		# NPC
		for node in get_tree().get_nodes_in_group("npcs"):
			var npc := node as Node3D
			if npc != null:
				_draw_world_marker(center, p_pos, npc.global_position, scale_px, Color(0.32, 0.96, 0.40), 4.2)

		# Стрелка игрока (вперёд = -Z, в 2D на миникарте вверх = -Y)
		var fwd := Vector2(-sin(p_yaw), -cos(p_yaw)).normalized()
		var right := Vector2(-fwd.y, fwd.x)
		var tip := center + fwd * 7.5
		var left_pt := center - fwd * 5.0 - right * 4.5
		var right_pt := center - fwd * 5.0 + right * 4.5
		draw_colored_polygon(PackedVector2Array([tip, left_pt, right_pt]), Color(1.0, 0.96, 0.55))

		draw_rect(rect, Color(0.62, 0.50, 0.26, 0.95), false, 2.0)

	func _draw_world_marker(center: Vector2, p_pos: Vector3, w_pos: Vector3, scale_px: float, col: Color, rad: float) -> void:
		var rel := Vector2(w_pos.x - p_pos.x, w_pos.z - p_pos.z) * scale_px
		var pt := center + rel
		if pt.x >= 4.0 and pt.x <= size.x - 4.0 and pt.y >= 4.0 and pt.y <= size.y - 4.0:
			draw_circle(pt, rad, col)


var root_control: Control = null

# Фрейм игрока
var player_frame: PanelContainer = null
var player_level_lbl: Label = null
var player_name_lbl: Label = null
var player_hp_bar: ProgressBar = null
var player_hp_lbl: Label = null
var player_rage_bar: ProgressBar = null
var player_rage_lbl: Label = null
var combat_badge: Label = null
var buff_badge: Label = null

# Фрейм цели
var target_frame: PanelContainer = null
var target_name_lbl: Label = null
var target_level_lbl: Label = null
var target_hp_bar: ProgressBar = null
var target_hp_lbl: Label = null
var target_dist_lbl: Label = null

# Правая часть
var quest_tracker_lbl: RichTextLabel = null

# Низ: лог, панель команд, опыт
var combat_log_rtl: RichTextLabel = null
var swing_bar: ProgressBar = null
var xp_bar: ProgressBar = null
var xp_lbl: Label = null
var money_lbl: Label = null
var ability_buttons: Array[Dictionary] = []

# Всплывающие окна
var quest_window: PanelContainer = null
var quest_win_title: Label = null
var quest_win_body: RichTextLabel = null
var quest_win_accept_btn: Button = null
var quest_win_complete_btn: Button = null
var current_dialog_quest_id: String = ""

var loot_window: PanelContainer = null
var loot_win_title: Label = null
var loot_list_vbox: VBoxContainer = null
var active_loot_mob: MobEntity = null

var inventory_window: PanelContainer = null
var inv_gear_lbl: RichTextLabel = null
var inv_items_vbox: VBoxContainer = null

var help_window: PanelContainer = null
var death_banner: PanelContainer = null

# Плавающий боевой текст
var floating_layer: Control = null
var active_floaters: Array[Dictionary] = []


func _ready() -> void:
	layer = 5
	root_control = Control.new()
	root_control.name = "HUDRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	floating_layer = Control.new()
	floating_layer.name = "FloatingCombatTextLayer"
	floating_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	floating_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(floating_layer)

	_build_player_frame()
	_build_target_frame()
	_build_minimap_and_tracker()
	_build_combat_log()
	_build_action_bar_and_xp()
	_build_quest_window()
	_build_loot_window()
	_build_inventory_window()
	_build_help_window()
	_build_death_banner()

	GameState.player_stats_changed.connect(_refresh_player_frame)
	GameState.target_changed.connect(_on_target_changed)
	GameState.combat_log_added.connect(_on_combat_log_added)
	GameState.floating_text_requested.connect(_on_floating_text)
	GameState.quest_updated.connect(_refresh_quest_tracker)
	GameState.inventory_changed.connect(_refresh_inventory_window)
	GameState.loot_window_requested.connect(_open_loot_window)
	GameState.npc_dialog_requested.connect(_open_npc_dialog)

	_refresh_player_frame()
	_refresh_quest_tracker()
	_refresh_inventory_window()

	_on_combat_log_added("Добро пожаловать в Северноземье! Подойдите к Капитану Маркусу (!) и нажмите ПКМ или [F].", GameState.COLOR_LOG_SYSTEM)
	_on_combat_log_added("Управление: WASD/QE — шаг, ПКМ — поворот/атака/лут, Tab — цель, 1-5 — умения, B — сумка, H — справка.", Color(0.75, 0.85, 0.95))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.physical_keycode == KEY_B:
				_toggle_inventory()
			elif key.physical_keycode == KEY_H:
				help_window.visible = not help_window.visible
			elif key.physical_keycode == KEY_ESCAPE:
				if quest_window.visible:
					quest_window.visible = false
				elif loot_window.visible:
					loot_window.visible = false
				elif inventory_window.visible:
					inventory_window.visible = false
				elif help_window.visible:
					help_window.visible = false


func _process(delta: float) -> void:
	_update_target_frame()
	_update_action_bar()
	_update_death_banner()
	_update_floating_texts(delta)


func _make_panel_style(bg_col: Color = Color(0.08, 0.08, 0.11, 0.88), border_col: Color = Color(0.60, 0.49, 0.27, 0.95), border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _make_bar_style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(2)
	return sb


func _make_progress_bar(min_h: int, fill_col: Color, bg_col: Color = Color(0.05, 0.05, 0.06, 0.9)) -> Dictionary:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(180, min_h)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	bar.add_theme_stylebox_override("background", _make_bar_style(bg_col))
	bar.add_theme_stylebox_override("fill", _make_bar_style(fill_col))

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	bar.add_child(lbl)
	return {"bar": bar, "label": lbl}


func _build_player_frame() -> void:
	player_frame = PanelContainer.new()
	player_frame.position = Vector2(16, 16)
	player_frame.custom_minimum_size = Vector2(265, 86)
	player_frame.add_theme_stylebox_override("panel", _make_panel_style())
	root_control.add_child(player_frame)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	player_frame.add_child(hbox)

	# Портрет Воина
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.add_theme_stylebox_override("panel", _make_panel_style(Color(0.32, 0.16, 0.12, 1.0), Color(0.84, 0.68, 0.25), 2))
	hbox.add_child(portrait)

	var port_vbox := VBoxContainer.new()
	port_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait.add_child(port_vbox)

	var icon_lbl := Label.new()
	icon_lbl.text = "⚔"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 22)
	icon_lbl.modulate = Color(0.96, 0.85, 0.45)
	port_vbox.add_child(icon_lbl)

	player_level_lbl = Label.new()
	player_level_lbl.text = "Ур. 1"
	player_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_level_lbl.add_theme_font_size_override("font_size", 11)
	player_level_lbl.modulate = Color(1.0, 0.88, 0.35)
	port_vbox.add_child(player_level_lbl)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)

	player_name_lbl = Label.new()
	player_name_lbl.text = "Воитель (Воин)"
	player_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name_lbl.add_theme_font_size_override("font_size", 14)
	player_name_lbl.modulate = Color(0.98, 0.86, 0.48)
	name_row.add_child(player_name_lbl)

	combat_badge = Label.new()
	combat_badge.text = "⚔ БОЙ"
	combat_badge.add_theme_font_size_override("font_size", 12)
	combat_badge.modulate = Color(1.0, 0.28, 0.25)
	combat_badge.visible = false
	name_row.add_child(combat_badge)

	var hp_dict := _make_progress_bar(20, Color(0.16, 0.68, 0.22))
	player_hp_bar = hp_dict["bar"]
	player_hp_lbl = hp_dict["label"]
	vbox.add_child(player_hp_bar)

	var rage_dict := _make_progress_bar(16, Color(0.76, 0.14, 0.14))
	player_rage_bar = rage_dict["bar"]
	player_rage_lbl = rage_dict["label"]
	vbox.add_child(player_rage_bar)

	buff_badge = Label.new()
	buff_badge.text = "Боевой крик +25% (30с)"
	buff_badge.add_theme_font_size_override("font_size", 11)
	buff_badge.modulate = Color(1.0, 0.88, 0.35)
	buff_badge.visible = false
	vbox.add_child(buff_badge)


func _build_target_frame() -> void:
	target_frame = PanelContainer.new()
	target_frame.position = Vector2(300, 16)
	target_frame.custom_minimum_size = Vector2(250, 76)
	target_frame.add_theme_stylebox_override("panel", _make_panel_style())
	target_frame.visible = false
	root_control.add_child(target_frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	target_frame.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	target_name_lbl = Label.new()
	target_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_name_lbl.add_theme_font_size_override("font_size", 14)
	top_row.add_child(target_name_lbl)

	target_level_lbl = Label.new()
	target_level_lbl.add_theme_font_size_override("font_size", 12)
	top_row.add_child(target_level_lbl)

	var hp_dict := _make_progress_bar(20, Color(0.76, 0.18, 0.16))
	target_hp_bar = hp_dict["bar"]
	target_hp_lbl = hp_dict["label"]
	vbox.add_child(target_hp_bar)

	target_dist_lbl = Label.new()
	target_dist_lbl.add_theme_font_size_override("font_size", 12)
	target_dist_lbl.modulate = Color(0.82, 0.84, 0.88)
	vbox.add_child(target_dist_lbl)


func _build_minimap_and_tracker() -> void:
	var right_vbox := VBoxContainer.new()
	right_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_vbox.offset_left = -246
	right_vbox.offset_top = 14
	right_vbox.offset_right = -14
	right_vbox.offset_bottom = 440
	right_vbox.add_theme_constant_override("separation", 8)
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(right_vbox)

	var map_panel := PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", _make_panel_style())
	right_vbox.add_child(map_panel)

	var map_vbox := VBoxContainer.new()
	map_vbox.add_theme_constant_override("separation", 4)
	map_panel.add_child(map_vbox)

	var zone_lbl := Label.new()
	zone_lbl.text = "Северноземье — Застава"
	zone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_lbl.add_theme_font_size_override("font_size", 13)
	zone_lbl.modulate = Color(1.0, 0.86, 0.42)
	map_vbox.add_child(zone_lbl)

	var radar := MinimapRadar.new()
	radar.custom_minimum_size = Vector2(208, 152)
	map_vbox.add_child(radar)

	var tracker_panel := PanelContainer.new()
	tracker_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.06, 0.09, 0.72), Color(0.45, 0.38, 0.22, 0.85), 1))
	right_vbox.add_child(tracker_panel)

	quest_tracker_lbl = RichTextLabel.new()
	quest_tracker_lbl.bbcode_enabled = true
	quest_tracker_lbl.fit_content = true
	quest_tracker_lbl.scroll_active = false
	quest_tracker_lbl.custom_minimum_size = Vector2(208, 40)
	quest_tracker_lbl.add_theme_font_size_override("normal_font_size", 12)
	tracker_panel.add_child(quest_tracker_lbl)


func _build_combat_log() -> void:
	var log_panel := PanelContainer.new()
	log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_panel.offset_left = 14
	log_panel.offset_top = -205
	log_panel.offset_right = 418
	log_panel.offset_bottom = -16
	log_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.05, 0.07, 0.76), Color(0.45, 0.38, 0.24, 0.85), 1))
	root_control.add_child(log_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	log_panel.add_child(vbox)

	var header := Label.new()
	header.text = "Общий чат / Журнал боя"
	header.add_theme_font_size_override("font_size", 12)
	header.modulate = Color(0.95, 0.82, 0.42)
	vbox.add_child(header)

	combat_log_rtl = RichTextLabel.new()
	combat_log_rtl.bbcode_enabled = true
	combat_log_rtl.scroll_following = true
	combat_log_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_log_rtl.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(combat_log_rtl)


func _build_action_bar_and_xp() -> void:
	var bottom_center := VBoxContainer.new()
	bottom_center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_center.offset_left = 435
	bottom_center.offset_right = -180
	bottom_center.offset_top = -126
	bottom_center.offset_bottom = -10
	bottom_center.alignment = BoxContainer.ALIGNMENT_END
	bottom_center.add_theme_constant_override("separation", 4)
	bottom_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(bottom_center)

	# Таймер замаха оружия
	var swing_wrap := CenterContainer.new()
	swing_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_center.add_child(swing_wrap)

	swing_bar = ProgressBar.new()
	swing_bar.custom_minimum_size = Vector2(260, 8)
	swing_bar.show_percentage = false
	swing_bar.max_value = 1.0
	swing_bar.value = 0.0
	swing_bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.08, 0.08, 0.10, 0.8)))
	swing_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.95, 0.86, 0.42)))
	swing_wrap.add_child(swing_bar)

	# Панель способностей
	var bar_center := CenterContainer.new()
	bar_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_center.add_child(bar_center)

	var bar_panel := PanelContainer.new()
	bar_panel.add_theme_stylebox_override("panel", _make_panel_style())
	bar_center.add_child(bar_panel)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 6)
	bar_panel.add_child(btn_hbox)

	var abilities_cfg: Array[Dictionary] = [
		{
			"slot": 1,
			"key": "1",
			"title": "Атака",
			"sub": "Меч",
			"cd_key": "",
			"rage_cost": 0,
			"tip": "[1] Автоатака: вкл/выкл удары оружием. Накопление +15 Ярости за удар.",
		},
		{
			"slot": 2,
			"key": "2",
			"title": "Рывок",
			"sub": "+20 Яр",
			"cd_key": "charge",
			"rage_cost": 0,
			"tip": "[2] Рывок (4-22 м): рывок к врагу, оглушение на 2 сек и +20 Ярости. КД 8 сек.",
		},
		{
			"slot": 3,
			"key": "3",
			"title": "Героизм",
			"sub": "15 Яр",
			"cd_key": "heroic_strike",
			"rage_cost": 15,
			"tip": "[3] Героический удар (15 Ярости): мощный удар на 145% урона +7. КД 2.5 сек.",
		},
		{
			"slot": 4,
			"key": "4",
			"title": "Вихрь",
			"sub": "25 Яр",
			"cd_key": "whirlwind",
			"rage_cost": 25,
			"tip": "[4] Вихрь (25 Ярости): круговой удар по всем врагам в радиусе 5 м. КД 6 сек.",
		},
		{
			"slot": 5,
			"key": "5",
			"title": "Крик",
			"sub": "+25%/Хил",
			"cd_key": "battle_shout",
			"rage_cost": 0,
			"tip": "[5] Боевой крик: +25% к урону на 30 сек и лечение на 35% HP. КД 15 сек.",
		},
	]

	for cfg in abilities_cfg:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(78, 56)
		btn.tooltip_text = cfg["tip"]
		btn.focus_mode = Control.FOCUS_NONE
		var slot_idx: int = int(cfg["slot"])
		btn.pressed.connect(func() -> void:
			var p := GameState.player_node as PlayerController
			if p != null:
				p.trigger_ability(slot_idx)
		)

		var btn_vbox := VBoxContainer.new()
		btn_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn.add_child(btn_vbox)

		var lbl_top := Label.new()
		lbl_top.text = "[%s] %s" % [cfg["key"], cfg["title"]]
		lbl_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_top.add_theme_font_size_override("font_size", 11)
		btn_vbox.add_child(lbl_top)

		var lbl_sub := Label.new()
		lbl_sub.text = cfg["sub"]
		lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_sub.add_theme_font_size_override("font_size", 11)
		lbl_sub.modulate = Color(0.92, 0.82, 0.45)
		btn_vbox.add_child(lbl_sub)

		var cd_lbl := Label.new()
		cd_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 18)
		cd_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		cd_lbl.add_theme_constant_override("outline_size", 4)
		cd_lbl.modulate = Color(1.0, 0.92, 0.35)
		cd_lbl.visible = false
		btn.add_child(cd_lbl)

		btn_hbox.add_child(btn)
		ability_buttons.append({
			"btn": btn,
			"cd_lbl": cd_lbl,
			"sub_lbl": lbl_sub,
			"cfg": cfg,
		})

	# Полоса опыта (XP)
	var xp_dict := _make_progress_bar(16, Color(0.46, 0.22, 0.72), Color(0.06, 0.05, 0.08, 0.92))
	xp_bar = xp_dict["bar"]
	xp_lbl = xp_dict["label"]
	bottom_center.add_child(xp_bar)

	# Справа внизу: деньги, сумка [B], справка [H]
	var br_panel := PanelContainer.new()
	br_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br_panel.offset_left = -168
	br_panel.offset_top = -96
	br_panel.offset_right = -14
	br_panel.offset_bottom = -12
	br_panel.add_theme_stylebox_override("panel", _make_panel_style())
	root_control.add_child(br_panel)

	var br_vbox := VBoxContainer.new()
	br_vbox.add_theme_constant_override("separation", 5)
	br_panel.add_child(br_vbox)

	money_lbl = Label.new()
	money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_lbl.add_theme_font_size_override("font_size", 12)
	money_lbl.modulate = Color(1.0, 0.88, 0.38)
	br_vbox.add_child(money_lbl)

	var bag_btn := Button.new()
	bag_btn.text = "[B] Сумка"
	bag_btn.focus_mode = Control.FOCUS_NONE
	bag_btn.pressed.connect(_toggle_inventory)
	br_vbox.add_child(bag_btn)

	var help_btn := Button.new()
	help_btn.text = "[H] Управление"
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.pressed.connect(func() -> void: help_window.visible = not help_window.visible)
	br_vbox.add_child(help_btn)


func _build_quest_window() -> void:
	quest_window = PanelContainer.new()
	quest_window.position = Vector2(36, 128)
	quest_window.custom_minimum_size = Vector2(370, 340)
	quest_window.add_theme_stylebox_override("panel", _make_panel_style(Color(0.86, 0.78, 0.60, 0.98), Color(0.38, 0.24, 0.11, 1.0), 3))
	quest_window.visible = false
	root_control.add_child(quest_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	quest_window.add_child(vbox)

	quest_win_title = Label.new()
	quest_win_title.add_theme_font_size_override("font_size", 18)
	quest_win_title.modulate = Color(0.22, 0.12, 0.05)
	vbox.add_child(quest_win_title)

	quest_win_body = RichTextLabel.new()
	quest_win_body.bbcode_enabled = true
	quest_win_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quest_win_body.add_theme_color_override("default_color", Color(0.16, 0.10, 0.05))
	quest_win_body.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(quest_win_body)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	quest_win_accept_btn = Button.new()
	quest_win_accept_btn.text = "Принять задание"
	quest_win_accept_btn.pressed.connect(func() -> void:
		if current_dialog_quest_id != "":
			GameState.accept_quest(current_dialog_quest_id)
		quest_window.visible = false
	)
	btn_row.add_child(quest_win_accept_btn)

	quest_win_complete_btn = Button.new()
	quest_win_complete_btn.text = "Завершить задание"
	quest_win_complete_btn.pressed.connect(func() -> void:
		if current_dialog_quest_id != "":
			GameState.complete_quest(current_dialog_quest_id)
		quest_window.visible = false
	)
	btn_row.add_child(quest_win_complete_btn)

	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(func() -> void: quest_window.visible = false)
	btn_row.add_child(close_btn)


func _build_loot_window() -> void:
	loot_window = PanelContainer.new()
	loot_window.set_anchors_preset(Control.PRESET_CENTER)
	loot_window.offset_left = -140
	loot_window.offset_top = -130
	loot_window.offset_right = 140
	loot_window.offset_bottom = 130
	loot_window.add_theme_stylebox_override("panel", _make_panel_style())
	loot_window.visible = false
	root_control.add_child(loot_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	loot_window.add_child(vbox)

	loot_win_title = Label.new()
	loot_win_title.text = "Добыча"
	loot_win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_win_title.add_theme_font_size_override("font_size", 15)
	loot_win_title.modulate = Color(1.0, 0.86, 0.38)
	vbox.add_child(loot_win_title)

	loot_list_vbox = VBoxContainer.new()
	loot_list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loot_list_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(loot_list_vbox)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var take_all_btn := Button.new()
	take_all_btn.text = "Забрать всё"
	take_all_btn.pressed.connect(_take_all_loot)
	row.add_child(take_all_btn)

	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(func() -> void: loot_window.visible = false)
	row.add_child(close_btn)


func _build_inventory_window() -> void:
	inventory_window = PanelContainer.new()
	inventory_window.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	inventory_window.offset_left = -350
	inventory_window.offset_top = -440
	inventory_window.offset_right = -14
	inventory_window.offset_bottom = -108
	inventory_window.add_theme_stylebox_override("panel", _make_panel_style())
	inventory_window.visible = false
	root_control.add_child(inventory_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	inventory_window.add_child(vbox)

	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "Сумка и экипировка [B]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.modulate = Color(1.0, 0.86, 0.38)
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func() -> void: inventory_window.visible = false)
	title_row.add_child(close_btn)

	inv_gear_lbl = RichTextLabel.new()
	inv_gear_lbl.bbcode_enabled = true
	inv_gear_lbl.fit_content = true
	inv_gear_lbl.scroll_active = false
	inv_gear_lbl.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(inv_gear_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	inv_items_vbox = VBoxContainer.new()
	inv_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_items_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(inv_items_vbox)


func _build_help_window() -> void:
	help_window = PanelContainer.new()
	help_window.set_anchors_preset(Control.PRESET_CENTER)
	help_window.offset_left = -220
	help_window.offset_top = -165
	help_window.offset_right = 220
	help_window.offset_bottom = 165
	help_window.add_theme_stylebox_override("panel", _make_panel_style())
	help_window.visible = false
	root_control.add_child(help_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	help_window.add_child(vbox)

	var title := Label.new()
	title.text = "Управление в стиле WoW Classic"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(1.0, 0.86, 0.38)
	vbox.add_child(title)

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("normal_font_size", 13)
	info.text = "[b]Движение и камера:[/b]\n" + \
		"• [color=#ffd866]W / A / S / D[/color] — вперёд, поворот, назад (Q / E — шаг вбок)\n" + \
		"• [color=#ffd866]Зажать ЛКМ[/color] — вращать камеру вокруг героя\n" + \
		"• [color=#ffd866]Зажать ПКМ[/color] — поворот героя за камерой + стрейф A/D\n" + \
		"• [color=#ffd866]ЛКМ + ПКМ[/color] — бег вперёд мышью, Колесо — зум\n\n" + \
		"[b]Бой и мир:[/b]\n" + \
		"• [color=#ffd866]Tab[/color] — выбрать ближайшего врага | [color=#ffd866]ЛКМ[/color] — цель\n" + \
		"• [color=#ffd866]ПКМ по врагу[/color] — цель + автоатака\n" + \
		"• [color=#ffd866]ПКМ или [F][/color] по NPC / трупу — квест или добыча\n" + \
		"• [color=#ffd866]1 — 5[/color] — способности Воина | [color=#ffd866]B[/color] — Сумка"
	vbox.add_child(info)

	var ok_btn := Button.new()
	ok_btn.text = "Понятно [H]"
	ok_btn.pressed.connect(func() -> void: help_window.visible = false)
	vbox.add_child(ok_btn)


func _build_death_banner() -> void:
	death_banner = PanelContainer.new()
	death_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	death_banner.offset_left = -210
	death_banner.offset_top = 110
	death_banner.offset_right = 210
	death_banner.offset_bottom = 172
	death_banner.add_theme_stylebox_override("panel", _make_panel_style(Color(0.24, 0.04, 0.04, 0.92), Color(0.95, 0.25, 0.20), 2))
	death_banner.visible = false
	root_control.add_child(death_banner)

	var lbl := Label.new()
	lbl.text = "ВЫ ПОГИБЛИ!\nДух целителя воскресит вас у заставы..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.modulate = Color(1.0, 0.85, 0.82)
	death_banner.add_child(lbl)


func _refresh_player_frame() -> void:
	player_level_lbl.text = "Ур. %d" % GameState.level
	player_name_lbl.text = "%s (%s)" % [GameState.player_name, GameState.player_class_name]

	player_hp_bar.max_value = GameState.max_hp
	player_hp_bar.value = GameState.hp
	player_hp_lbl.text = "%d / %d" % [GameState.hp, GameState.max_hp]

	player_rage_bar.max_value = GameState.max_rage
	player_rage_bar.value = GameState.rage
	player_rage_lbl.text = "Ярость: %d / %d" % [GameState.rage, GameState.max_rage]

	combat_badge.visible = GameState.in_combat
	if GameState.battle_shout_timer > 0.0:
		buff_badge.visible = true
		buff_badge.text = "Боевой крик +25%% (%dс)" % int(ceil(GameState.battle_shout_timer))
	else:
		buff_badge.visible = false

	xp_bar.max_value = GameState.xp_to_next
	xp_bar.value = GameState.xp
	var pct: int = int(round((float(GameState.xp) / maxf(1.0, float(GameState.xp_to_next))) * 100.0))
	xp_lbl.text = "Опыт: %d / %d (%d%%) — Ур. %d" % [GameState.xp, GameState.xp_to_next, pct, GameState.level]

	money_lbl.text = "Золото: %s" % GameState.format_money(GameState.money_copper)


func _on_target_changed(_new_target: Node3D) -> void:
	_update_target_frame()


func _update_target_frame() -> void:
	var t: Node3D = GameState.current_target
	if not is_instance_valid(t):
		target_frame.visible = false
		return

	target_frame.visible = true
	var p: Node3D = GameState.player_node
	var dist: float = p.global_position.distance_to(t.global_position) if is_instance_valid(p) else 0.0
	target_dist_lbl.text = "Дистанция: %.1f м" % dist

	if t is MobEntity:
		var mob := t as MobEntity
		target_name_lbl.text = mob.mob_title
		target_name_lbl.modulate = Color(1.0, 0.55, 0.25) if mob.is_elite else Color(0.98, 0.42, 0.38)
		target_level_lbl.text = ("★ Элита Ур.%d" % mob.level) if mob.is_elite else ("Ур. %d" % mob.level)
		target_level_lbl.modulate = Color(1.0, 0.85, 0.30) if mob.is_elite else Color(0.9, 0.9, 0.9)
		target_hp_bar.max_value = mob.max_hp
		target_hp_bar.value = mob.hp
		target_hp_lbl.text = "Труп" if mob.is_dead() else "%d / %d" % [mob.hp, mob.max_hp]
		target_hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.45, 0.45, 0.45) if mob.is_dead() else Color(0.76, 0.18, 0.16)))
	elif t is QuestNPC:
		var npc := t as QuestNPC
		target_name_lbl.text = npc.npc_name
		target_name_lbl.modulate = Color(0.40, 0.96, 0.45)
		target_level_lbl.text = "Друг"
		target_level_lbl.modulate = Color(0.40, 0.96, 0.45)
		target_hp_bar.max_value = 100
		target_hp_bar.value = 100
		target_hp_lbl.text = "100 / 100"
		target_hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.18, 0.72, 0.24)))


func _update_action_bar() -> void:
	var p := GameState.player_node as PlayerController
	if p != null:
		swing_bar.visible = p.auto_attack_enabled
		swing_bar.value = p.get_swing_progress()
	else:
		swing_bar.visible = false

	for entry in ability_buttons:
		var btn: Button = entry["btn"]
		var cd_lbl: Label = entry["cd_lbl"]
		var sub_lbl: Label = entry["sub_lbl"]
		var cfg: Dictionary = entry["cfg"]
		var slot: int = int(cfg["slot"])
		var cd_key: String = String(cfg["cd_key"])
		var rage_cost: int = int(cfg["rage_cost"])

		if slot == 1:
			var active: bool = p != null and p.auto_attack_enabled
			btn.modulate = Color(1.15, 1.05, 0.55) if active else Color.WHITE
			sub_lbl.text = "АКТИВ." if active else "Меч"
			continue

		var cd_rem: float = float(GameState.ability_cooldowns.get(cd_key, 0.0))
		if cd_rem > 0.0:
			cd_lbl.visible = true
			cd_lbl.text = "%.1f" % cd_rem
			btn.modulate = Color(0.55, 0.55, 0.60)
		else:
			cd_lbl.visible = false
			if rage_cost > 0 and GameState.rage < rage_cost:
				btn.modulate = Color(0.65, 0.55, 0.55)
			else:
				btn.modulate = Color.WHITE


func _update_death_banner() -> void:
	death_banner.visible = GameState.is_dead


func _refresh_quest_tracker() -> void:
	var lines: Array[String] = []
	lines.append("[color=#ffd666][b]Журнал заданий:[/b][/color]")
	var has_entry: bool = false

	for q_id in GameState.quest_order:
		var q: Dictionary = GameState.quests[q_id]
		if q["state"] == "active":
			has_entry = true
			lines.append("[color=#ffe488]• %s[/color]" % q["title"])
			var objs: Dictionary = q["objectives"]
			for k in objs.keys():
				var o: Dictionary = objs[k]
				var done: bool = o["current"] >= o["required"]
				var col: String = "#77ee77" if done else "#dddddd"
				lines.append("  [color=%s]- %s: %d/%d[/color]" % [col, o["label"], o["current"], o["required"]])
		elif q["state"] == "ready_to_turn_in":
			has_entry = true
			lines.append("[color=#77ee77]• %s (Готово!)[/color]" % q["title"])
			lines.append("  [color=#ffd666]Вернитесь к %s (?)[/color]" % q["giver"])

	if not has_entry:
		var npc_status := GameState.get_npc_quest_status()
		if npc_status["mode"] == "offer":
			lines.append("[color=#cccccc]Поговорите с Капитаном Маркусом (!).[/color]")
		else:
			lines.append("[color=#77ee77]Все задания заставы выполнены![/color]")

	quest_tracker_lbl.text = "\n".join(lines)


func _on_combat_log_added(text: String, color: Color) -> void:
	if combat_log_rtl == null:
		return
	var hex: String = color.to_html(false)
	combat_log_rtl.append_text("[color=#%s]%s[/color]\n" % [hex, text])


func _on_floating_text(world_pos: Vector3, text: String, color: Color, is_crit: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24 if is_crit else 17)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.04, 0.95))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_layer.add_child(lbl)

	active_floaters.append({
		"label": lbl,
		"world_pos": world_pos,
		"age": 0.0,
		"duration": 1.25 if is_crit else 1.0,
		"rise_speed": 1.35,
	})


func _update_floating_texts(delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	for i in range(active_floaters.size() - 1, -1, -1):
		var f: Dictionary = active_floaters[i]
		f["age"] += delta
		var lbl: Label = f["label"]
		if f["age"] >= f["duration"] or not is_instance_valid(lbl):
			if is_instance_valid(lbl):
				lbl.queue_free()
			active_floaters.remove_at(i)
			continue

		f["world_pos"] = (f["world_pos"] as Vector3) + Vector3(0, f["rise_speed"] * delta, 0)
		if cam == null or cam.is_position_behind(f["world_pos"]):
			lbl.visible = false
		else:
			lbl.visible = true
			var screen_pos: Vector2 = cam.unproject_position(f["world_pos"])
			lbl.position = screen_pos - lbl.size * 0.5
			var alpha: float = clampf(1.0 - pow(f["age"] / f["duration"], 2.0), 0.0, 1.0)
			lbl.modulate.a = alpha


func _open_npc_dialog(npc_ref: Node3D) -> void:
	var status: Dictionary = GameState.get_npc_quest_status()
	var mode: String = String(status.get("mode", "none"))
	var q_id: String = String(status.get("quest_id", ""))
	current_dialog_quest_id = q_id

	var npc_name: String = "Капитан Маркус"
	if npc_ref is QuestNPC:
		npc_name = (npc_ref as QuestNPC).npc_name

	quest_win_accept_btn.visible = false
	quest_win_complete_btn.visible = false

	if mode == "offer" and GameState.quests.has(q_id):
		var q: Dictionary = GameState.quests[q_id]
		quest_win_title.text = "%s — %s" % [npc_name, q["title"]]
		var item: Dictionary = q.get("reward_item", {})
		var item_str: String = "[%s] (%s)" % [item.get("name", ""), item.get("desc", "")] if not item.is_empty() else ""
		quest_win_body.text = "%s\n\n[b]Награда:[/b]\n• %d ед. опыта\n• %s\n• %s" % [
			q["description"],
			q["reward_xp"],
			GameState.format_money(q["reward_copper"]),
			item_str,
		]
		quest_win_accept_btn.visible = true
	elif mode == "turn_in" and GameState.quests.has(q_id):
		var q: Dictionary = GameState.quests[q_id]
		quest_win_title.text = "%s — %s (Выполнено)" % [npc_name, q["title"]]
		var item: Dictionary = q.get("reward_item", {})
		var item_str: String = "[%s] (%s)" % [item.get("name", ""), item.get("desc", "")] if not item.is_empty() else ""
		quest_win_body.text = "%s\n\n[b]Вы получите:[/b]\n• %d ед. опыта\n• %s\n• %s" % [
			q["completion_text"],
			q["reward_xp"],
			GameState.format_money(q["reward_copper"]),
			item_str,
		]
		quest_win_complete_btn.visible = true
	elif mode == "in_progress" and GameState.quests.has(q_id):
		var q: Dictionary = GameState.quests[q_id]
		quest_win_title.text = "%s — %s" % [npc_name, q["title"]]
		quest_win_body.text = "Как продвигается дело с заданием «%s»?\n\nВозвращайся ко мне, как только цели будут выполнены!" % q["title"]
	else:
		quest_win_title.text = npc_name
		quest_win_body.text = "Застава в безопасности благодаря твоей стали, воин!\n\nМожешь продолжать охоту на волков и кобольдов в северной долине, чтобы закалиться в боях."

	quest_window.visible = true


func _open_loot_window(mob_ref: Node3D) -> void:
	if not (mob_ref is MobEntity):
		return
	var mob := mob_ref as MobEntity
	if not mob.has_loot():
		return
	active_loot_mob = mob
	loot_win_title.text = "Добыча: %s" % mob.mob_title
	_rebuild_loot_list()
	loot_window.visible = true


func _rebuild_loot_list() -> void:
	for child in loot_list_vbox.get_children():
		child.queue_free()

	if not is_instance_valid(active_loot_mob) or not active_loot_mob.has_loot():
		loot_window.visible = false
		return

	if active_loot_mob.loot_copper > 0:
		var money_btn := Button.new()
		money_btn.text = "Монеты: %s" % GameState.format_money(active_loot_mob.loot_copper)
		money_btn.modulate = Color(1.0, 0.88, 0.38)
		money_btn.pressed.connect(func() -> void:
			if is_instance_valid(active_loot_mob) and active_loot_mob.loot_copper > 0:
				GameState.add_money(active_loot_mob.loot_copper)
				active_loot_mob.loot_copper = 0
				active_loot_mob.refresh_loot_indicator()
				_rebuild_loot_list()
		)
		loot_list_vbox.add_child(money_btn)

	for idx in range(active_loot_mob.loot_items.size()):
		var item: Dictionary = active_loot_mob.loot_items[idx]
		var item_btn := Button.new()
		var cnt: int = int(item.get("count", 1))
		item_btn.text = "%s%s" % [item["name"], (" x%d" % cnt) if cnt > 1 else ""]
		item_btn.tooltip_text = String(item.get("desc", ""))
		item_btn.modulate = _rarity_color(String(item.get("rarity", "common")))
		var cap_idx: int = idx
		item_btn.pressed.connect(func() -> void:
			if is_instance_valid(active_loot_mob) and cap_idx < active_loot_mob.loot_items.size():
				var picked: Dictionary = active_loot_mob.loot_items[cap_idx]
				active_loot_mob.loot_items.remove_at(cap_idx)
				GameState.add_item_to_inventory(picked)
				active_loot_mob.refresh_loot_indicator()
				_rebuild_loot_list()
		)
		loot_list_vbox.add_child(item_btn)


func _take_all_loot() -> void:
	if not is_instance_valid(active_loot_mob):
		loot_window.visible = false
		return
	if active_loot_mob.loot_copper > 0:
		GameState.add_money(active_loot_mob.loot_copper)
		active_loot_mob.loot_copper = 0
	for item in active_loot_mob.loot_items:
		GameState.add_item_to_inventory(item)
	active_loot_mob.loot_items.clear()
	active_loot_mob.refresh_loot_indicator()
	loot_window.visible = false


func _toggle_inventory() -> void:
	inventory_window.visible = not inventory_window.visible
	if inventory_window.visible:
		_refresh_inventory_window()


func _refresh_inventory_window() -> void:
	if inv_gear_lbl == null or inv_items_vbox == null:
		return

	var dmg_min: int = GameState.base_damage_min + GameState.equipped_weapon_bonus
	var dmg_max: int = GameState.base_damage_max + GameState.equipped_weapon_bonus
	var wep_col: String = _rarity_color(GameState.equipped_weapon_rarity).to_html(false)
	var arm_col: String = _rarity_color(GameState.equipped_armor_rarity).to_html(false)

	inv_gear_lbl.text = "[b]Экипировка:[/b]\n" + \
		"Оружие: [color=#%s][%s][/color] (+%d ур.)\n" % [wep_col, GameState.equipped_weapon_name, GameState.equipped_weapon_bonus] + \
		"Броня: [color=#%s][%s][/color] (+%d HP)\n" % [arm_col, GameState.equipped_armor_name, GameState.equipped_armor_hp_bonus] + \
		"Урон: [color=#ffd866]%d — %d[/color] | Здоровье: [color=#66ee66]%d[/color]" % [dmg_min, dmg_max, GameState.max_hp]

	for child in inv_items_vbox.get_children():
		child.queue_free()

	if GameState.inventory.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Сумка пуста."
		empty_lbl.modulate = Color(0.65, 0.65, 0.68)
		inv_items_vbox.add_child(empty_lbl)
		return

	for i in range(GameState.inventory.size()):
		var item: Dictionary = GameState.inventory[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		inv_items_vbox.add_child(row)

		var lbl := Label.new()
		var cnt: int = int(item.get("count", 1))
		lbl.text = "%s%s" % [item["name"], (" x%d" % cnt) if cnt > 1 else ""]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.modulate = _rarity_color(String(item.get("rarity", "common")))
		lbl.tooltip_text = String(item.get("desc", ""))
		row.add_child(lbl)

		var act_btn := Button.new()
		var itype: String = String(item.get("type", "junk"))
		if itype == "potion":
			act_btn.text = "Выпить"
		elif itype == "weapon" or itype == "armor":
			act_btn.text = "Надеть"
		else:
			act_btn.text = "Продать"
		act_btn.focus_mode = Control.FOCUS_NONE
		var cap_i: int = i
		act_btn.pressed.connect(func() -> void:
			GameState.use_or_equip_item(cap_i)
		)
		row.add_child(act_btn)


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.32, 0.96, 0.35)
		"rare":
			return Color(0.32, 0.66, 1.0)
		_:
			return Color(0.95, 0.95, 0.95)
