extends CanvasLayer

class WowDrawControl extends Control:
	var draw_cb: Callable

	func _init(cb: Callable = Callable()) -> void:
		draw_cb = cb
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if draw_cb.is_valid():
			draw_cb.call(self)


class MinimapRadar extends Control:
	const WORLD_SPAN := 50.0

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

		# Озеро на востоке, тоннель/зал Северного рудника и дороги
		var lake_c := center + Vector2(36.0 - p_pos.x, -20.0 - p_pos.z) * scale_px
		draw_circle(lake_c, 13.0 * scale_px, Color(0.14, 0.38, 0.58, 0.7))
		var tunnel_tl := center + Vector2(-5.0 - p_pos.x, -81.0 - p_pos.z) * scale_px
		draw_rect(Rect2(tunnel_tl, Vector2(10.0, 22.0) * scale_px), Color(0.22, 0.20, 0.25, 0.78), true)
		var hall_tl := center + Vector2(-13.0 - p_pos.x, -106.0 - p_pos.z) * scale_px
		draw_rect(Rect2(hall_tl, Vector2(26.0, 25.0) * scale_px), Color(0.22, 0.20, 0.25, 0.85), true)

		draw_circle(center, minf(size.x, size.y) * 0.46, Color(0.24, 0.34, 0.24, 0.45))
		draw_line(Vector2(center.x, 4), Vector2(center.x, size.y - 4), Color(0.25, 0.32, 0.25, 0.35), 1.0)
		draw_line(Vector2(4, center.y), Vector2(size.x - 4, center.y), Color(0.25, 0.32, 0.25, 0.35), 1.0)

		var road_x: float = center.x + (0.0 - p_pos.x) * scale_px
		if road_x > 4 and road_x < size.x - 4:
			draw_line(Vector2(road_x, 4), Vector2(road_x, size.y - 4), Color(0.45, 0.35, 0.22, 0.55), 5.0)
		var cross_y: float = center.y + (-18.0 - p_pos.z) * scale_px
		if cross_y > 4 and cross_y < size.y - 4:
			draw_line(Vector2(4, cross_y), Vector2(size.x - 4, cross_y), Color(0.45, 0.35, 0.22, 0.45), 3.0)

		# Маркер заставы, лагеря Братства и входа в рудник
		_draw_world_marker(center, p_pos, Vector3(-8.5, 0, 4.0), scale_px, Color(0.45, 0.65, 0.95), 4.0)
		_draw_world_marker(center, p_pos, Vector3(-32.0, 0, -18.0), scale_px, Color(0.75, 0.35, 0.28), 4.0)
		_draw_world_marker(center, p_pos, Vector3(0.0, 0, -59.0), scale_px, Color(0.65, 0.50, 0.38), 4.5)

		# Интерактивные объекты (ящики, сундук, руда, травы)
		for node in get_tree().get_nodes_in_group("interactables"):
			var prop := node as InteractableProp
			if prop != null and prop.is_available:
				var mcol := Color(0.35, 0.85, 1.0)
				if prop.prop_id == "ore_vein":
					mcol = Color(0.42, 0.92, 1.0) if prop.sub_kind == "azure_crystal" else Color(0.88, 0.56, 0.22)
				elif prop.prop_id == "herb_node":
					mcol = Color(0.45, 0.98, 0.45)
				else:
					mcol = Color(1.0, 0.85, 0.28)
				_draw_world_marker(center, p_pos, prop.global_position, scale_px, mcol, 2.8)

		# Питомец Охотника
		if is_instance_valid(GameState.pet_node) and not GameState.pet_dead:
			_draw_world_marker(center, p_pos, GameState.pet_node.global_position, scale_px, Color(0.42, 0.96, 0.55), 3.2)

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
				var rad := 4.5 if mob.is_elite else 2.8
				_draw_world_marker(center, p_pos, mob.global_position, scale_px, col, rad)

		# NPC
		for node in get_tree().get_nodes_in_group("npcs"):
			var npc := node as QuestNPC
			if npc != null:
				var ncol := Color(1.0, 0.85, 0.25) if npc.role == "merchant" else Color(0.32, 0.96, 0.40)
				_draw_world_marker(center, p_pos, npc.global_position, scale_px, ncol, 4.0)

		# Кладбище и труп игрока
		for sh in get_tree().get_nodes_in_group("spirit_healer"):
			_draw_world_marker(center, p_pos, (sh as Node3D).global_position, scale_px, Color(0.55, 0.82, 1.0), 4.0)
		if GameState.is_dead:
			var cp := center + Vector2(GameState.corpse_position.x - p_pos.x, GameState.corpse_position.z - p_pos.z) * scale_px
			if cp.x >= 6 and cp.x <= size.x - 6 and cp.y >= 6 and cp.y <= size.y - 6:
				draw_line(cp + Vector2(-4, -4), cp + Vector2(4, 4), Color(0.45, 0.92, 1.0), 2.0)
				draw_line(cp + Vector2(-4, 4), cp + Vector2(4, -4), Color(0.45, 0.92, 1.0), 2.0)

		# Стрелка игрока
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


class WorldMapCanvas extends Control:
	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _to_map(wx: float, wz: float) -> Vector2:
		# Долина X in [-68..68], Z in [-112..42]
		var nx: float = clampf((wx + 68.0) / 136.0, 0.04, 0.96)
		var ny: float = clampf((wz + 112.0) / 154.0, 0.04, 0.96)
		return Vector2(nx * size.x, ny * size.y)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.26, 0.16, 0.98), true)
		# Горы, дороги, озеро, шахта
		draw_line(_to_map(0, 26), _to_map(0, -60), Color(0.55, 0.42, 0.26), 10.0)
		draw_line(_to_map(-32, -18), _to_map(28, -18), Color(0.55, 0.42, 0.26), 8.0)

		var lake_p: Vector2 = _to_map(36, -20)
		draw_circle(lake_p, 48.0, Color(0.16, 0.48, 0.72, 0.85))
		var mine_tl: Vector2 = _to_map(-14, -108)
		var mine_br: Vector2 = _to_map(14, -59)
		draw_rect(Rect2(mine_tl, mine_br - mine_tl), Color(0.24, 0.22, 0.28, 0.92), true)
		draw_rect(Rect2(mine_tl, mine_br - mine_tl), Color(0.55, 0.78, 0.95, 0.8), false, 2.0)

		var out_p: Vector2 = _to_map(-3, 5)
		draw_rect(Rect2(out_p - Vector2(22, 16), Vector2(44, 32)), Color(0.45, 0.45, 0.50), true)
		var camp_p: Vector2 = _to_map(-32, -18)
		draw_circle(camp_p, 22.0, Color(0.58, 0.22, 0.18, 0.8))

		var font: Font = ThemeDB.fallback_font
		for lbl_cfg in [
			{"pos": Vector2(-3, 18), "text": "Застава Северноземья", "col": Color(1.0, 0.88, 0.42)},
			{"pos": Vector2(-34, -32), "text": "Лагерь Братства", "col": Color(1.0, 0.55, 0.45)},
			{"pos": Vector2(34, -36), "text": "Хрустальное озеро", "col": Color(0.55, 0.88, 1.0)},
			{"pos": Vector2(0, -110), "text": "Северный рудник (Дробитель)", "col": Color(0.85, 0.75, 1.0)},
			{"pos": Vector2(0, -32), "text": "Волчий лес", "col": Color(0.75, 0.95, 0.68)},
		]:
			var pt: Vector2 = _to_map((lbl_cfg["pos"] as Vector2).x, (lbl_cfg["pos"] as Vector2).y)
			draw_string(font, pt - Vector2(120, 4), String(lbl_cfg["text"]), HORIZONTAL_ALIGNMENT_CENTER, 240, 13, lbl_cfg["col"])

		for n in get_tree().get_nodes_in_group("npcs"):
			var npc := n as QuestNPC
			if npc:
				var np: Vector2 = _to_map(npc.global_position.x, npc.global_position.z)
				draw_circle(np, 5.0, Color(0.32, 0.96, 0.42) if npc.role != "merchant" else Color(1.0, 0.85, 0.25))

		for sh in get_tree().get_nodes_in_group("spirit_healer"):
			var sp: Vector2 = _to_map((sh as Node3D).global_position.x, (sh as Node3D).global_position.z)
			draw_circle(sp, 5.0, Color(0.5, 0.85, 1.0))

		if GameState.is_dead:
			var cp: Vector2 = _to_map(GameState.corpse_position.x, GameState.corpse_position.z)
			draw_line(cp + Vector2(-6, -6), cp + Vector2(6, 6), Color(0.45, 0.92, 1.0), 3.0)
			draw_line(cp + Vector2(-6, 6), cp + Vector2(6, -6), Color(0.45, 0.92, 1.0), 3.0)

		var p: Node3D = GameState.player_node
		if is_instance_valid(p):
			var pp: Vector2 = _to_map(p.global_position.x, p.global_position.z)
			var fwd := Vector2(-sin(p.rotation.y), -cos(p.rotation.y)).normalized()
			var right := Vector2(-fwd.y, fwd.x)
			draw_colored_polygon(PackedVector2Array([pp + fwd * 11.0, pp - fwd * 6.0 - right * 6.0, pp - fwd * 6.0 + right * 6.0]), Color(1.0, 0.94, 0.35))

		draw_rect(Rect2(Vector2.ZERO, size), Color(0.68, 0.56, 0.30), false, 3.0)


var root_control: Control = null

# Фрейм игрока
var player_frame: PanelContainer = null
var player_portrait_ctrl: Control = null
var player_lvl_badge: Label = null
var player_name_lbl: Label = null
var player_hp_bar: ProgressBar = null
var player_hp_lbl: Label = null
var player_rage_bar: ProgressBar = null
var player_rage_lbl: Label = null
var combat_badge: Label = null
var buff_row: HBoxContainer = null

var pet_frame: PanelContainer = null
var pet_portrait_ctrl: Control = null
var pet_hp_bar: ProgressBar = null
var pet_hp_lbl: Label = null
var pet_name_lbl: Label = null

# Фрейм цели
var target_frame: PanelContainer = null
var target_portrait_ctrl: Control = null
var target_lvl_badge: Label = null
var target_name_hdr: PanelContainer = null
var target_name_lbl: Label = null
var target_level_lbl: Label = null
var target_hp_bar: ProgressBar = null
var target_hp_lbl: Label = null
var target_cast_bar: ProgressBar = null
var target_dist_lbl: Label = null
var target_combo_lbl: Label = null

# Правая часть
var zone_lbl: Label = null
var quest_tracker_lbl: RichTextLabel = null

# Низ: лог, панель команд, опыт, рюкзак и микроменю
var combat_log_rtl: RichTextLabel = null
var swing_bar: ProgressBar = null
var cast_bar: ProgressBar = null
var xp_bar: ProgressBar = null
var xp_lbl: Label = null
var xp_ticks_ctrl: Control = null
var br_bag_btn: Button = null
var br_bag_count_lbl: Label = null
var br_coin_ctrl: Control = null
var talent_btn: Button = null
var mute_btn: Button = null
var action_btn_hbox: HBoxContainer = null
var _built_action_class: String = ""
var ability_buttons: Array[Dictionary] = []

# Всплывающие окна и WoW-подсказка
var wow_tooltip_panel: PanelContainer = null
var wow_tooltip_rtl: RichTextLabel = null
var quest_window: PanelContainer = null
var quest_win_tabs: HBoxContainer = null
var quest_win_title: Label = null
var quest_win_body: RichTextLabel = null
var quest_win_accept_btn: Button = null
var quest_win_complete_btn: Button = null
var current_dialog_quest_id: String = ""
var current_dialog_npc_name: String = ""

var loot_window: PanelContainer = null
var loot_win_title: Label = null
var loot_list_vbox: VBoxContainer = null
var active_loot_mob: MobEntity = null

var inventory_window: PanelContainer = null
var bag_title_lbl: Label = null
var bag_slots_grid: GridContainer = null
var bag_slot_entries: Array[Dictionary] = []
var bag_coin_ctrl: Control = null
var bag_pickup_hint_lbl: Label = null
var picked_bag_slot: int = -1

var char_window: PanelContainer = null
var char_doll_hero: Control = null
var char_armor_slot_panel: PanelContainer = null
var char_weapon_slot_panel: PanelContainer = null
var char_armor_icon: Control = null
var char_weapon_icon: Control = null
var char_stats_rtl: RichTextLabel = null

var questlog_window: PanelContainer = null
var questlog_rtl: RichTextLabel = null

var worldmap_window: PanelContainer = null

var talent_window: PanelContainer = null
var talent_points_lbl: Label = null
var talent_list_vbox: VBoxContainer = null

var menu_window: PanelContainer = null
var menu_load_btn: Button = null

var help_window: PanelContainer = null
var vendor_window: PanelContainer = null
var vendor_money_lbl: Label = null
var vendor_sell_vbox: VBoxContainer = null
var death_banner: PanelContainer = null
var death_lbl: Label = null
var release_btn: Button = null
var res_corpse_btn: Button = null
var res_healer_btn: Button = null
var ghost_tint: ColorRect = null

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
	_build_char_window()
	_build_questlog_window()
	_build_worldmap_window()
	_build_talent_window()
	_build_menu_window()
	_build_help_window()
	_build_vendor_window()
	_build_death_banner()
	_build_wow_tooltip()

	GameState.player_stats_changed.connect(_refresh_player_frame)
	GameState.pet_stats_changed.connect(_refresh_pet_frame)
	GameState.target_changed.connect(_on_target_changed)
	GameState.combat_log_added.connect(_on_combat_log_added)
	GameState.floating_text_requested.connect(_on_floating_text)
	GameState.quest_updated.connect(_on_quest_or_inv_changed_for_logs)
	GameState.inventory_changed.connect(_on_inventory_updated)
	GameState.talents_changed.connect(_refresh_talent_window)
	GameState.loot_window_requested.connect(_open_loot_window)
	GameState.npc_dialog_requested.connect(_open_npc_dialog)

	_refresh_player_frame()
	_refresh_pet_frame()
	_refresh_quest_tracker()
	_refresh_inventory_window()
	_refresh_talent_window()

	_on_combat_log_added("Добро пожаловать в Северноземье! Поговорите с Маркусом (!) или Лирой (!).", GameState.COLOR_LOG_SYSTEM)
	_on_combat_log_added("1–5 умения, 6–8 зелья/камень, [C] Герой, [B] Сумка, [L] Квесты, [M] Карта, [T] Таланты.", Color(0.75, 0.85, 0.95))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.physical_keycode == KEY_B:
				_toggle_inventory()
			elif key.physical_keycode == KEY_T:
				_toggle_talents()
			elif key.physical_keycode == KEY_C:
				_toggle_char_window()
			elif key.physical_keycode == KEY_L:
				_toggle_questlog()
			elif key.physical_keycode == KEY_M:
				worldmap_window.visible = not worldmap_window.visible
			elif key.physical_keycode == KEY_N:
				_toggle_mute()
			elif key.physical_keycode == KEY_F5:
				GameState.save_game()
			elif key.physical_keycode == KEY_R:
				if GameState.is_ghost:
					_try_resurrect_corpse()
			elif key.physical_keycode == KEY_H:
				help_window.visible = not help_window.visible
			elif key.physical_keycode == KEY_ESCAPE:
				if quest_window.visible:
					quest_window.visible = false
				elif vendor_window.visible:
					vendor_window.visible = false
				elif loot_window.visible:
					loot_window.visible = false
				elif inventory_window.visible:
					if picked_bag_slot >= 0:
						picked_bag_slot = -1
						_refresh_inventory_window()
					else:
						inventory_window.visible = false
					_hide_wow_tooltip()
				elif char_window.visible:
					char_window.visible = false
					_hide_wow_tooltip()
				elif questlog_window.visible:
					questlog_window.visible = false
				elif worldmap_window.visible:
					worldmap_window.visible = false
				elif talent_window.visible:
					talent_window.visible = false
				elif help_window.visible:
					help_window.visible = false
				elif menu_window.visible:
					menu_window.visible = false
				elif GameState.current_target == null:
					_toggle_menu()
				else:
					return
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_target_frame()
	_update_action_bar()
	_update_death_banner()
	_update_zone_label()
	_update_floating_texts(delta)


func _make_panel_style(bg_col: Color = Color(0.075, 0.075, 0.105, 0.92), border_col: Color = Color(0.68, 0.56, 0.28, 0.96), border_w: int = 2) -> StyleBoxFlat:
	return WowUIArt.make_wow_panel_style(bg_col, border_col, border_w, 7)


func _build_wow_tooltip() -> void:
	wow_tooltip_panel = PanelContainer.new()
	wow_tooltip_panel.visible = false
	wow_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wow_tooltip_panel.custom_minimum_size = Vector2(215, 40)
	wow_tooltip_panel.add_theme_stylebox_override("panel", WowUIArt.make_wow_tooltip_style())
	root_control.add_child(wow_tooltip_panel)

	wow_tooltip_rtl = RichTextLabel.new()
	wow_tooltip_rtl.bbcode_enabled = true
	wow_tooltip_rtl.fit_content = true
	wow_tooltip_rtl.scroll_active = false
	wow_tooltip_rtl.custom_minimum_size = Vector2(210, 20)
	wow_tooltip_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wow_tooltip_rtl.add_theme_font_size_override("normal_font_size", 12)
	wow_tooltip_panel.add_child(wow_tooltip_rtl)


func _show_wow_tooltip(bbcode: String, anchor: Control) -> void:
	if wow_tooltip_panel == null or wow_tooltip_rtl == null:
		return
	wow_tooltip_rtl.text = bbcode
	wow_tooltip_panel.visible = true
	wow_tooltip_panel.reset_size()
	var vp_sz: Vector2 = get_viewport().get_visible_rect().size
	var tip_sz: Vector2 = wow_tooltip_panel.get_combined_minimum_size()
	tip_sz.x = maxf(tip_sz.x, 232.0)
	tip_sz.y = maxf(tip_sz.y, 70.0)
	var gr: Rect2 = anchor.get_global_rect()
	var px: float = gr.position.x - tip_sz.x - 8.0
	if px < 10.0:
		px = gr.position.x + gr.size.x + 8.0
	px = clampf(px, 10.0, vp_sz.x - tip_sz.x - 10.0)
	var py: float = clampf(gr.position.y - tip_sz.y * 0.35, 10.0, vp_sz.y - tip_sz.y - 10.0)
	wow_tooltip_panel.position = Vector2(px, py)


func _hide_wow_tooltip() -> void:
	if wow_tooltip_panel:
		wow_tooltip_panel.visible = false


func _make_bar_style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(2)
	return sb


func _make_progress_bar(min_h: int, fill_col: Color, bg_col: Color = Color(0.05, 0.05, 0.06, 0.92)) -> Dictionary:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(170, min_h)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	bar.add_theme_stylebox_override("background", _make_bar_style(bg_col))
	bar.add_theme_stylebox_override("fill", _make_bar_style(fill_col))

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	bar.add_child(lbl)
	return {"bar": bar, "label": lbl}


func _build_player_frame() -> void:
	player_frame = PanelContainer.new()
	player_frame.position = Vector2(12, 12)
	player_frame.custom_minimum_size = Vector2(276, 80)
	player_frame.add_theme_stylebox_override("panel", _make_panel_style())
	root_control.add_child(player_frame)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	player_frame.add_child(hbox)

	var port_wrap := Control.new()
	port_wrap.custom_minimum_size = Vector2(62, 62)
	hbox.add_child(port_wrap)

	player_portrait_ctrl = WowDrawControl.new(func(c: Control) -> void:
		WowUIArt.draw_portrait(c, Rect2(Vector2.ZERO, c.size), "player", GameState.player_class, false, GameState.in_combat)
	)
	player_portrait_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	port_wrap.add_child(player_portrait_ctrl)

	var lvl_pill := PanelContainer.new()
	lvl_pill.position = Vector2(-2, 42)
	lvl_pill.custom_minimum_size = Vector2(22, 20)
	lvl_pill.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.12, 0.08, 0.04, 0.96), Color(0.92, 0.76, 0.28), 1, 2))
	port_wrap.add_child(lvl_pill)

	player_lvl_badge = Label.new()
	player_lvl_badge.text = "1"
	player_lvl_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_lvl_badge.add_theme_font_size_override("font_size", 11)
	player_lvl_badge.modulate = Color(1.0, 0.88, 0.35)
	lvl_pill.add_child(player_lvl_badge)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	var name_hdr := PanelContainer.new()
	name_hdr.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.14, 0.14, 0.18, 0.86), Color(0.45, 0.38, 0.22, 0.7), 1, 2))
	vbox.add_child(name_hdr)

	var name_row := HBoxContainer.new()
	name_hdr.add_child(name_row)

	player_name_lbl = Label.new()
	player_name_lbl.text = "Воитель (Воин)"
	player_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name_lbl.add_theme_font_size_override("font_size", 12)
	player_name_lbl.modulate = Color(0.98, 0.86, 0.48)
	name_row.add_child(player_name_lbl)

	combat_badge = Label.new()
	combat_badge.text = "⚔"
	combat_badge.add_theme_font_size_override("font_size", 12)
	combat_badge.modulate = Color(1.0, 0.28, 0.22)
	combat_badge.visible = false
	name_row.add_child(combat_badge)

	var hp_dict := _make_progress_bar(18, Color(0.14, 0.68, 0.20))
	player_hp_bar = hp_dict["bar"]
	player_hp_lbl = hp_dict["label"]
	vbox.add_child(player_hp_bar)

	var rage_dict := _make_progress_bar(15, Color(0.76, 0.14, 0.14))
	player_rage_bar = rage_dict["bar"]
	player_rage_lbl = rage_dict["label"]
	vbox.add_child(player_rage_bar)

	# Классическая панель баффов — в правом верхнем углу слева от миникарты (как в WoW)
	buff_row = HBoxContainer.new()
	buff_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	buff_row.offset_left = -468
	buff_row.offset_top = 14
	buff_row.offset_right = -256
	buff_row.offset_bottom = 66
	buff_row.alignment = BoxContainer.ALIGNMENT_END
	buff_row.add_theme_constant_override("separation", 6)
	root_control.add_child(buff_row)

	# Фрейм питомца-волка под портретом (для Охотника)
	pet_frame = PanelContainer.new()
	pet_frame.position = Vector2(34, 98)
	pet_frame.custom_minimum_size = Vector2(216, 42)
	pet_frame.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.07, 0.10, 0.08, 0.90), Color(0.38, 0.68, 0.36, 0.92), 2, 4))
	pet_frame.visible = false
	root_control.add_child(pet_frame)

	var pet_hbox := HBoxContainer.new()
	pet_hbox.add_theme_constant_override("separation", 6)
	pet_frame.add_child(pet_hbox)

	pet_portrait_ctrl = WowDrawControl.new(func(c: Control) -> void:
		WowUIArt.draw_portrait(c, Rect2(Vector2.ZERO, c.size), "pet", "wolf", false, GameState.in_combat)
	)
	pet_portrait_ctrl.custom_minimum_size = Vector2(32, 32)
	pet_hbox.add_child(pet_portrait_ctrl)

	var pet_vbox := VBoxContainer.new()
	pet_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_vbox.add_theme_constant_override("separation", 2)
	pet_hbox.add_child(pet_vbox)

	pet_name_lbl = Label.new()
	pet_name_lbl.text = "Лесной страж"
	pet_name_lbl.add_theme_font_size_override("font_size", 11)
	pet_name_lbl.modulate = Color(0.55, 0.96, 0.58)
	pet_vbox.add_child(pet_name_lbl)

	var pet_hp_d := _make_progress_bar(13, Color(0.22, 0.72, 0.26))
	pet_hp_d["bar"].custom_minimum_size = Vector2(145, 13)
	pet_hp_bar = pet_hp_d["bar"]
	pet_hp_lbl = pet_hp_d["label"]
	pet_vbox.add_child(pet_hp_bar)


func _build_target_frame() -> void:
	target_frame = PanelContainer.new()
	target_frame.position = Vector2(302, 12)
	target_frame.custom_minimum_size = Vector2(284, 80)
	target_frame.add_theme_stylebox_override("panel", _make_panel_style())
	target_frame.visible = false
	root_control.add_child(target_frame)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	target_frame.add_child(hbox)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	target_name_hdr = PanelContainer.new()
	target_name_hdr.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.36, 0.10, 0.10, 0.88), Color(0.48, 0.38, 0.22, 0.8), 1, 2))
	vbox.add_child(target_name_hdr)

	var top_row := HBoxContainer.new()
	target_name_hdr.add_child(top_row)

	target_name_lbl = Label.new()
	target_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_name_lbl.add_theme_font_size_override("font_size", 12)
	top_row.add_child(target_name_lbl)

	target_level_lbl = Label.new()
	target_level_lbl.add_theme_font_size_override("font_size", 11)
	top_row.add_child(target_level_lbl)

	var hp_dict := _make_progress_bar(18, Color(0.76, 0.18, 0.16))
	target_hp_bar = hp_dict["bar"]
	target_hp_lbl = hp_dict["label"]
	vbox.add_child(target_hp_bar)

	target_cast_bar = ProgressBar.new()
	target_cast_bar.custom_minimum_size = Vector2(180, 14)
	target_cast_bar.show_percentage = false
	target_cast_bar.max_value = 1.0
	target_cast_bar.visible = false
	target_cast_bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.06, 0.04, 0.05, 0.9)))
	target_cast_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.95, 0.45, 0.14)))
	var tc_lbl := Label.new()
	tc_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	tc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tc_lbl.add_theme_font_size_override("font_size", 10)
	tc_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	tc_lbl.add_theme_constant_override("outline_size", 3)
	target_cast_bar.add_child(tc_lbl)
	target_cast_bar.set_meta("label", tc_lbl)
	vbox.add_child(target_cast_bar)

	var bot_row := HBoxContainer.new()
	vbox.add_child(bot_row)

	target_dist_lbl = Label.new()
	target_dist_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_dist_lbl.add_theme_font_size_override("font_size", 11)
	target_dist_lbl.modulate = Color(0.84, 0.86, 0.90)
	bot_row.add_child(target_dist_lbl)

	target_combo_lbl = Label.new()
	target_combo_lbl.add_theme_font_size_override("font_size", 12)
	target_combo_lbl.modulate = Color(1.0, 0.85, 0.22)
	target_combo_lbl.visible = false
	bot_row.add_child(target_combo_lbl)

	# Портрет цели справа (как в WoW Classic) + золотое крыло элиты
	var t_port_wrap := Control.new()
	t_port_wrap.custom_minimum_size = Vector2(64, 64)
	hbox.add_child(t_port_wrap)

	target_portrait_ctrl = WowDrawControl.new(func(c: Control) -> void:
		var t: Node3D = GameState.current_target
		var kind := "npc"
		var sub := ""
		var elite := false
		if t is MobEntity:
			var m := t as MobEntity
			kind = "mob"
			sub = m.mob_id
			elite = m.is_elite
		elif t is PetCompanion:
			kind = "pet"
			sub = "wolf"
		elif t is InteractableProp:
			kind = "prop"
			sub = "prop"
		WowUIArt.draw_portrait(c, Rect2(Vector2.ZERO, c.size), kind, sub, elite, false)
	)
	target_portrait_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	t_port_wrap.add_child(target_portrait_ctrl)

	var tlvl_pill := PanelContainer.new()
	tlvl_pill.position = Vector2(44, 42)
	tlvl_pill.custom_minimum_size = Vector2(22, 20)
	tlvl_pill.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.12, 0.08, 0.04, 0.96), Color(0.92, 0.76, 0.28), 1, 2))
	t_port_wrap.add_child(tlvl_pill)

	target_lvl_badge = Label.new()
	target_lvl_badge.text = "?"
	target_lvl_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_lvl_badge.add_theme_font_size_override("font_size", 11)
	target_lvl_badge.modulate = Color(1.0, 0.88, 0.35)
	tlvl_pill.add_child(target_lvl_badge)


func _build_minimap_and_tracker() -> void:
	var right_vbox := VBoxContainer.new()
	right_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_vbox.offset_left = -252
	right_vbox.offset_top = 12
	right_vbox.offset_right = -12
	right_vbox.offset_bottom = 292
	right_vbox.add_theme_constant_override("separation", 6)
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(right_vbox)

	var map_panel := PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", _make_panel_style())
	right_vbox.add_child(map_panel)

	var map_vbox := VBoxContainer.new()
	map_vbox.add_theme_constant_override("separation", 4)
	map_panel.add_child(map_vbox)

	var hdr_row := HBoxContainer.new()
	map_vbox.add_child(hdr_row)

	zone_lbl = Label.new()
	zone_lbl.text = "Северноземье — Застава"
	zone_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_lbl.add_theme_font_size_override("font_size", 12)
	zone_lbl.modulate = Color(1.0, 0.86, 0.42)
	hdr_row.add_child(zone_lbl)

	var mini_map_btn := Button.new()
	mini_map_btn.text = "M"
	mini_map_btn.tooltip_text = "Открыть карту мира [M]"
	mini_map_btn.custom_minimum_size = Vector2(22, 20)
	mini_map_btn.focus_mode = Control.FOCUS_NONE
	mini_map_btn.add_theme_font_size_override("font_size", 10)
	mini_map_btn.pressed.connect(func() -> void: worldmap_window.visible = not worldmap_window.visible)
	hdr_row.add_child(mini_map_btn)

	var radar := MinimapRadar.new()
	radar.custom_minimum_size = Vector2(214, 134)
	map_vbox.add_child(radar)

	var compass_n := Label.new()
	compass_n.text = "С"
	compass_n.position = Vector2(101, 1)
	compass_n.add_theme_font_size_override("font_size", 10)
	compass_n.modulate = Color(1.0, 0.86, 0.42)
	radar.add_child(compass_n)

	var tracker_panel := PanelContainer.new()
	tracker_panel.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.05, 0.05, 0.08, 0.72), Color(0.45, 0.38, 0.22, 0.85), 1, 6))
	right_vbox.add_child(tracker_panel)

	var tracker_scroll := ScrollContainer.new()
	tracker_scroll.custom_minimum_size = Vector2(214, 74)
	tracker_panel.add_child(tracker_scroll)

	quest_tracker_lbl = RichTextLabel.new()
	quest_tracker_lbl.bbcode_enabled = true
	quest_tracker_lbl.fit_content = true
	quest_tracker_lbl.scroll_active = false
	quest_tracker_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_tracker_lbl.custom_minimum_size = Vector2(204, 34)
	quest_tracker_lbl.add_theme_font_size_override("normal_font_size", 11)
	tracker_scroll.add_child(quest_tracker_lbl)


func _build_combat_log() -> void:
	var log_panel := PanelContainer.new()
	log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_panel.offset_left = 12
	log_panel.offset_top = -188
	log_panel.offset_right = 382
	log_panel.offset_bottom = -12
	log_panel.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.045, 0.045, 0.065, 0.78), Color(0.45, 0.38, 0.24, 0.88), 1, 7))
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
	bottom_center.offset_left = 384
	bottom_center.offset_right = -266
	bottom_center.offset_top = -132
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

	var cast_wrap := CenterContainer.new()
	cast_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_center.add_child(cast_wrap)
	bottom_center.move_child(cast_wrap, 0)
	cast_bar = ProgressBar.new()
	cast_bar.custom_minimum_size = Vector2(300, 16)
	cast_bar.show_percentage = false
	cast_bar.max_value = 1.0
	cast_bar.visible = false
	cast_bar.add_theme_stylebox_override("background", _make_bar_style(Color(0.05, 0.05, 0.08, 0.9)))
	cast_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.95, 0.72, 0.2)))
	var cast_lbl := Label.new()
	cast_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	cast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cast_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cast_lbl.add_theme_font_size_override("font_size", 11)
	cast_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	cast_lbl.add_theme_constant_override("outline_size", 3)
	cast_bar.add_child(cast_lbl)
	cast_bar.set_meta("label", cast_lbl)
	cast_wrap.add_child(cast_bar)

	# Панель способностей с крыльями грифонов по краям (как в WoW Classic)
	var bar_center := CenterContainer.new()
	bar_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_center.add_child(bar_center)

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 0)
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_center.add_child(bar_row)

	var gryph_l := WowDrawControl.new(func(c: Control) -> void:
		WowUIArt.draw_gryphon_endcap(c, Rect2(Vector2.ZERO, c.size), false)
	)
	gryph_l.custom_minimum_size = Vector2(46, 54)
	bar_row.add_child(gryph_l)

	var bar_panel := PanelContainer.new()
	bar_panel.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.08, 0.075, 0.095, 0.94), Color(0.68, 0.56, 0.28, 0.96), 2, 5))
	bar_row.add_child(bar_panel)

	action_btn_hbox = HBoxContainer.new()
	action_btn_hbox.add_theme_constant_override("separation", 4)
	bar_panel.add_child(action_btn_hbox)

	_populate_action_buttons()

	var gryph_r := WowDrawControl.new(func(c: Control) -> void:
		WowUIArt.draw_gryphon_endcap(c, Rect2(Vector2.ZERO, c.size), true)
	)
	gryph_r.custom_minimum_size = Vector2(46, 54)
	bar_row.add_child(gryph_r)

	# Сегментированная полоса опыта (20 делений, как в WoW Classic)
	var xp_wrap := CenterContainer.new()
	xp_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_center.add_child(xp_wrap)

	var xp_dict := _make_progress_bar(15, Color(0.50, 0.22, 0.78), Color(0.06, 0.05, 0.08, 0.94))
	xp_bar = xp_dict["bar"]
	xp_bar.custom_minimum_size = Vector2(414, 15)
	xp_lbl = xp_dict["label"]
	xp_wrap.add_child(xp_bar)

	xp_ticks_ctrl = WowDrawControl.new(func(c: Control) -> void:
		for seg in range(1, 20):
			var tx: float = c.size.x * (float(seg) / 20.0)
			c.draw_line(Vector2(tx, 1.0), Vector2(tx, c.size.y - 1.0), Color(0.04, 0.03, 0.06, 0.82), 1.2)
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.58, 0.48, 0.24, 0.90), false, 1.2)
	)
	xp_ticks_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_bar.add_child(xp_ticks_ctrl)
	xp_bar.move_child(xp_ticks_ctrl, 0)

	# Справа внизу: компактная панель Сумки (Рюкзак + Монеты) и Микроменю WoW Classic
	var br_panel := PanelContainer.new()
	br_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br_panel.offset_left = -262
	br_panel.offset_top = -94
	br_panel.offset_right = -12
	br_panel.offset_bottom = -12
	br_panel.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.085, 0.075, 0.09, 0.94), Color(0.68, 0.56, 0.28, 0.96), 2, 6))
	root_control.add_child(br_panel)

	var br_vbox := VBoxContainer.new()
	br_vbox.add_theme_constant_override("separation", 5)
	br_panel.add_child(br_vbox)

	var bag_coin_row := HBoxContainer.new()
	bag_coin_row.add_theme_constant_override("separation", 6)
	br_vbox.add_child(bag_coin_row)

	br_bag_btn = Button.new()
	br_bag_btn.custom_minimum_size = Vector2(114, 30)
	br_bag_btn.focus_mode = Control.FOCUS_NONE
	br_bag_btn.tooltip_text = "Открыть Рюкзак [B]"
	br_bag_btn.pressed.connect(_toggle_inventory)
	bag_coin_row.add_child(br_bag_btn)

	var bag_btn_hb := HBoxContainer.new()
	bag_btn_hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	bag_btn_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_btn_hb.add_theme_constant_override("separation", 4)
	br_bag_btn.add_child(bag_btn_hb)

	var bag_emblem := WowDrawControl.new(func(c: Control) -> void:
		WowUIArt.draw_backpack_medallion(c, Rect2(Vector2.ZERO, c.size))
	)
	bag_emblem.custom_minimum_size = Vector2(24, 24)
	bag_btn_hb.add_child(bag_emblem)

	br_bag_count_lbl = Label.new()
	br_bag_count_lbl.text = "Рюкзак 0/16"
	br_bag_count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br_bag_count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	br_bag_count_lbl.add_theme_font_size_override("font_size", 11)
	br_bag_count_lbl.modulate = Color(0.98, 0.88, 0.45)
	bag_btn_hb.add_child(br_bag_count_lbl)

	br_coin_ctrl = WowDrawControl.new(func(c: Control) -> void:
		WowUIArt.draw_coin_strip(c, Rect2(Vector2.ZERO, c.size), GameState.money_copper)
	)
	br_coin_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br_coin_ctrl.custom_minimum_size = Vector2(96, 26)
	bag_coin_row.add_child(br_coin_ctrl)

	var micro_row := HBoxContainer.new()
	micro_row.add_theme_constant_override("separation", 3)
	br_vbox.add_child(micro_row)

	var micro_defs: Array[Dictionary] = [
		{"key": "C", "tip": "[C] Персонаж и экипировка", "cb": _toggle_char_window, "ref": "char"},
		{"key": "T", "tip": "[T] Древо талантов", "cb": _toggle_talents, "ref": "talent"},
		{"key": "L", "tip": "[L] Журнал заданий", "cb": _toggle_questlog, "ref": "quest"},
		{"key": "M", "tip": "[M] Карта долины", "cb": func() -> void: worldmap_window.visible = not worldmap_window.visible, "ref": "map"},
		{"key": "H", "tip": "[H] Помощь и управление", "cb": func() -> void: help_window.visible = not help_window.visible, "ref": "help"},
		{"key": "N", "tip": "[N] Вкл/выкл звук", "cb": _toggle_mute, "ref": "mute"},
		{"key": "Esc", "tip": "[Esc] Главное меню / Сохранение", "cb": _toggle_menu, "ref": "menu"},
	]
	for md in micro_defs:
		var mb := Button.new()
		mb.text = String(md["key"])
		mb.tooltip_text = String(md["tip"])
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.custom_minimum_size = Vector2(30, 26)
		mb.focus_mode = Control.FOCUS_NONE
		mb.add_theme_font_size_override("font_size", 11)
		mb.pressed.connect(md["cb"] as Callable)
		micro_row.add_child(mb)
		if String(md["ref"]) == "talent":
			talent_btn = mb
		elif String(md["ref"]) == "mute":
			mute_btn = mb


func _populate_action_buttons() -> void:
	if action_btn_hbox == null:
		return
	for c in action_btn_hbox.get_children():
		c.queue_free()
	ability_buttons.clear()
	_built_action_class = GameState.player_class

	var abilities_cfg: Array[Dictionary] = [
		{
			"slot": 1,
			"key": "1",
			"title": "Атака",
			"sub": "Меч",
			"cd_key": "",
			"rage_cost": 0,
			"tip": "[color=#ffd866][b][1] Автоатака[/b][/color]\nВкл/выкл удары оружием.\nНакопление +15 Ярости за удар.",
		},
		{
			"slot": 2,
			"key": "2",
			"title": "Рывок",
			"sub": "+20 Яр",
			"cd_key": "charge",
			"rage_cost": 0,
			"tip": "[color=#ffd866][b][2] Рывок[/b][/color]\nДистанция 4–22 м • КД 8 сек\nРывок к врагу, оглушение на 2 сек и +20 Ярости.",
		},
		{
			"slot": 3,
			"key": "3",
			"title": "Героизм",
			"sub": "15 Яр",
			"cd_key": "heroic_strike",
			"rage_cost": 15,
			"tip": "[color=#ffd866][b][3] Героический удар[/b][/color]\n15 Ярости • КД 2.5 сек\nМощный удар на 145% урона +7.",
		},
		{
			"slot": 4,
			"key": "4",
			"title": "Вихрь",
			"sub": "25 Яр",
			"cd_key": "whirlwind",
			"rage_cost": 25,
			"tip": "[color=#ffd866][b][4] Вихрь[/b][/color]\n25 Ярости • КД 6 сек\nКруговой удар по всем врагам в радиусе 5 м.",
		},
		{
			"slot": 5,
			"key": "5",
			"title": "Крик",
			"sub": "+25%/Хил",
			"cd_key": "battle_shout",
			"rage_cost": 0,
			"tip": "[color=#ffd866][b][5] Боевой крик[/b][/color]\nМгновенно • КД 15 сек\n+25% к урону на 30 сек и лечение на 35% здоровья.",
		},
	]
	var mage_cfg: Array[Dictionary] = [
		{"slot": 1, "key": "1", "title": "Атака", "sub": "Посох", "cd_key": "", "rage_cost": 0,
			"tip": "[color=#66b3ff][b][1] Атака посохом[/b][/color]\nДальний автовыстрел (22 м), мана не тратится."},
		{"slot": 2, "key": "2", "title": "Шар", "sub": "30 Мана", "cd_key": "fireball", "rage_cost": 30,
			"tip": "[color=#ff944d][b][2] Огненный шар[/b][/color]\n30 Маны • Каст 1.6 сек\nМощный огненный урон на дистанции до 30 м."},
		{"slot": 3, "key": "3", "title": "Стрела", "sub": "20 Мана", "cd_key": "frostbolt", "rage_cost": 20,
			"tip": "[color=#66d9ff][b][3] Ледяная стрела[/b][/color]\n20 Маны • Каст 1.2 сек\nУрон холодом и замедление цели на 4 сек."},
		{"slot": 4, "key": "4", "title": "Кольцо", "sub": "35 Мана", "cd_key": "frost_nova", "rage_cost": 35,
			"tip": "[color=#66d9ff][b][4] Кольцо льда[/b][/color]\n35 Маны • КД 10 сек\nЗаморозка всех врагов в радиусе 6 м на 2.5 сек."},
		{"slot": 5, "key": "5", "title": "Скачок", "sub": "15 Мана", "cd_key": "blink", "rage_cost": 15,
			"tip": "[color=#cc88ff][b][5] Скачок[/b][/color]\n15 Маны • КД 12 сек\nМгновенный телепорт на 11 м вперёд."},
	]
	var rogue_cfg: Array[Dictionary] = [
		{"slot": 1, "key": "1", "title": "Атака", "sub": "Кинжалы", "cd_key": "", "rage_cost": 0,
			"tip": "[color=#fff066][b][1] Автоатака[/b][/color]\nБыстрые удары парными кинжалами."},
		{"slot": 2, "key": "2", "title": "Удар", "sub": "35 Эн", "cd_key": "sinister_strike", "rage_cost": 35,
			"tip": "[color=#fff066][b][2] Коварный / Внезапный удар[/b][/color]\n35–40 Энергии\nДаёт +1★ (или +2★ из Незаметности с бонусом урона)."},
		{"slot": 3, "key": "3", "title": "Финишер", "sub": "30 Эн", "cd_key": "eviscerate", "rage_cost": 30,
			"tip": "[color=#ff6666][b][3] Потрошение[/b][/color]\n30 Энергии\nЗавершающий приём: расходует 1–5★ серии."},
		{"slot": 4, "key": "4", "title": "Скрытн.", "sub": "Стелс", "cd_key": "stealth", "rage_cost": 0,
			"tip": "[color=#99b3ff][b][4] Незаметность[/b][/color]\nСкрывает вас от врагов и усиливает следующий [2]."},
		{"slot": 5, "key": "5", "title": "Стан", "sub": "25 Эн", "cd_key": "kidney_shot", "rage_cost": 25,
			"tip": "[color=#ffd866][b][5] Удар по почкам[/b][/color]\n25 Энергии • Нужно ≥1★\nОглушает цель на 2 + 0.5★ сек."},
	]
	var hunter_cfg: Array[Dictionary] = [
		{"slot": 1, "key": "1", "title": "Выстр.", "sub": "Лук", "cd_key": "", "rage_cost": 0,
			"tip": "[color=#88ee66][b][1] Автострельба из лука[/b][/color]\nДальний выстрел (24 м), мана не тратится."},
		{"slot": 2, "key": "2", "title": "Аркан", "sub": "25 Мана", "cd_key": "arcane_shot", "rage_cost": 25,
			"tip": "[color=#66ccff][b][2] Чародейский выстрел[/b][/color]\n25 Маны • КД 4 сек\nМощный мгновенный выстрел."},
		{"slot": 3, "key": "3", "title": "Яд", "sub": "25 Мана", "cd_key": "serpent_sting", "rage_cost": 25,
			"tip": "[color=#66ee66][b][3] Укус змеи[/b][/color]\n25 Маны\nОтравляет цель периодическим уроном на 8 сек."},
		{"slot": 4, "key": "4", "title": "Шок", "sub": "15 Мана", "cd_key": "concussive_shot", "rage_cost": 15,
			"tip": "[color=#ffd866][b][4] Шокирующий выстрел[/b][/color]\n15 Маны\nЗамедляет врага на 4.5 сек и сбивает каст."},
		{"slot": 5, "key": "5", "title": "Зверь", "sub": "20 Мана", "cd_key": "mend_pet", "rage_cost": 20,
			"tip": "[color=#66ee66][b][5] Лечение зверя[/b][/color]\n20 Маны\nЛечит или воскрешает волка (+25% урона на 15 сек)."},
	]
	if GameState.player_class == "mage":
		abilities_cfg = mage_cfg
	elif GameState.player_class == "rogue":
		abilities_cfg = rogue_cfg
	elif GameState.player_class == "hunter":
		abilities_cfg = hunter_cfg

	var quick_items_cfg: Array[Dictionary] = [
		{"slot": 6, "key": "6", "title": "Зелье", "sub": "HP", "cd_key": "__item_hp", "rage_cost": 0,
			"tip": "[color=#1eff00][b][6] Зелье / Бинт[/b][/color]\nБыстро применяет лечебное зелье или травяной бинт из сумки."},
		{"slot": 7, "key": "7", "title": "Пай/Эл", "sub": "Бафф", "cd_key": "__item_util", "rage_cost": 0,
			"tip": "[color=#1eff00][b][7] Эликсир / Мана / Паёк[/b][/color]\nПьёт Эликсир стойкости, зелье маны или ест Дорожный паёк."},
		{"slot": 8, "key": "8", "title": "Камень", "sub": "Дом", "cd_key": "hearthstone", "rage_cost": 0,
			"tip": "[color=#66d9ff][b][8] Камень возвращения[/b][/color]\nКаст 2.5 сек • КД 45 сек\nВозвращает на Заставу Северноземья."},
	]
	abilities_cfg.append_array(quick_items_cfg)

	for cfg in abilities_cfg:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(46, 46)
		btn.focus_mode = Control.FOCUS_NONE
		var slot_idx: int = int(cfg["slot"])
		var cd_key_cap: String = String(cfg["cd_key"])
		var tip_str: String = String(cfg["tip"])
		btn.pressed.connect(func() -> void:
			if slot_idx == 6:
				GameState.use_first_item_by_types(["potion", "bandage"])
			elif slot_idx == 7:
				GameState.use_first_item_by_types(["elixir", "mana_potion", "food"])
			elif slot_idx == 8:
				GameState.use_first_item_by_types(["hearthstone"])
			else:
				var p := GameState.player_node as PlayerController
				if p != null:
					p.trigger_ability(slot_idx)
		)
		btn.mouse_entered.connect(func() -> void: _show_wow_tooltip(tip_str, btn))
		btn.mouse_exited.connect(_hide_wow_tooltip)

		var icon_art := WowDrawControl.new(func(c: Control) -> void:
			WowUIArt.draw_ability_icon(c, Rect2(Vector2.ZERO, c.size), cd_key_cap, GameState.player_class)
		)
		icon_art.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_child(icon_art)

		var lbl_key := Label.new()
		lbl_key.text = String(cfg["key"])
		lbl_key.position = Vector2(3, 1)
		lbl_key.add_theme_font_size_override("font_size", 10)
		lbl_key.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl_key.add_theme_constant_override("outline_size", 3)
		lbl_key.modulate = Color(0.95, 0.94, 0.88)
		btn.add_child(lbl_key)

		var lbl_sub := Label.new()
		lbl_sub.text = ""
		lbl_sub.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		lbl_sub.offset_left = -36
		lbl_sub.offset_top = -15
		lbl_sub.offset_right = -3
		lbl_sub.offset_bottom = -1
		lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_sub.add_theme_font_size_override("font_size", 10)
		lbl_sub.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl_sub.add_theme_constant_override("outline_size", 3)
		lbl_sub.modulate = Color(1.0, 0.94, 0.45)
		btn.add_child(lbl_sub)

		var cd_dim := ColorRect.new()
		cd_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd_dim.color = Color(0.03, 0.03, 0.05, 0.84)
		cd_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_dim.visible = false
		btn.add_child(cd_dim)

		var cd_lbl := Label.new()
		cd_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 14)
		cd_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		cd_lbl.add_theme_constant_override("outline_size", 4)
		cd_lbl.modulate = Color(1.0, 0.92, 0.35)
		cd_lbl.visible = false
		btn.add_child(cd_lbl)

		action_btn_hbox.add_child(btn)
		ability_buttons.append({
			"btn": btn,
			"icon_art": icon_art,
			"cd_dim": cd_dim,
			"cd_lbl": cd_lbl,
			"sub_lbl": lbl_sub,
			"cfg": cfg,
		})


func _build_quest_window() -> void:
	quest_window = PanelContainer.new()
	quest_window.position = Vector2(14, 150)
	quest_window.custom_minimum_size = Vector2(356, 315)
	quest_window.add_theme_stylebox_override("panel", _make_panel_style(Color(0.86, 0.78, 0.60, 0.98), Color(0.38, 0.24, 0.11, 1.0), 3))
	quest_window.visible = false
	root_control.add_child(quest_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	quest_window.add_child(vbox)

	quest_win_tabs = HBoxContainer.new()
	quest_win_tabs.add_theme_constant_override("separation", 4)
	vbox.add_child(quest_win_tabs)

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
	loot_window.offset_left = -135
	loot_window.offset_top = -140
	loot_window.offset_right = 135
	loot_window.offset_bottom = 140
	loot_window.add_theme_stylebox_override("panel", _make_panel_style())
	loot_window.visible = false
	root_control.add_child(loot_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	loot_window.add_child(vbox)

	loot_win_title = Label.new()
	loot_win_title.text = "Добыча"
	loot_win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_win_title.add_theme_font_size_override("font_size", 14)
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
	inventory_window.offset_left = -262
	inventory_window.offset_top = -434
	inventory_window.offset_right = -12
	inventory_window.offset_bottom = -98
	inventory_window.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.11, 0.095, 0.085, 0.96), Color(0.70, 0.58, 0.30, 0.98), 2, 7))
	inventory_window.visible = false
	root_control.add_child(inventory_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	inventory_window.add_child(vbox)

	# Шапка в точности как в WoW Classic: медальон рюкзака + заголовок + сортировка + X
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	vbox.add_child(title_row)

	var emblem := WowDrawControl.new(func(c: Control) -> void:
		WowUIArt.draw_backpack_medallion(c, Rect2(Vector2.ZERO, c.size))
	)
	emblem.custom_minimum_size = Vector2(28, 28)
	title_row.add_child(emblem)

	bag_title_lbl = Label.new()
	bag_title_lbl.text = "Рюкзак (0/16)"
	bag_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bag_title_lbl.add_theme_font_size_override("font_size", 13)
	bag_title_lbl.modulate = Color(1.0, 0.86, 0.38)
	title_row.add_child(bag_title_lbl)

	var sort_btn := Button.new()
	sort_btn.text = "Сорт"
	sort_btn.tooltip_text = "Упорядочить предметы в рюкзаке"
	sort_btn.focus_mode = Control.FOCUS_NONE
	sort_btn.add_theme_font_size_override("font_size", 10)
	sort_btn.pressed.connect(func() -> void:
		picked_bag_slot = -1
		GameState.sort_backpack()
	)
	title_row.add_child(sort_btn)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(func() -> void:
		picked_bag_slot = -1
		inventory_window.visible = false
		_hide_wow_tooltip()
	)
	title_row.add_child(close_btn)

	bag_pickup_hint_lbl = Label.new()
	bag_pickup_hint_lbl.text = "Выберите ячейку (ПКМ отмена)"
	bag_pickup_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag_pickup_hint_lbl.add_theme_font_size_override("font_size", 10)
	bag_pickup_hint_lbl.modulate = Color(1.0, 0.90, 0.35)
	bag_pickup_hint_lbl.visible = false
	vbox.add_child(bag_pickup_hint_lbl)

	# Сетка 4x4 (16 классических ячеек рюкзака WoW)
	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid_center)

	bag_slots_grid = GridContainer.new()
	bag_slots_grid.columns = 4
	bag_slots_grid.add_theme_constant_override("h_separation", 4)
	bag_slots_grid.add_theme_constant_override("v_separation", 4)
	grid_center.add_child(bag_slots_grid)

	bag_slot_entries.clear()
	for slot_i in range(GameState.BAG_CAPACITY):
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(50, 50)
		slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_panel.add_theme_stylebox_override("panel", WowUIArt.make_slot_box_style("common", true, false, false))
		bag_slots_grid.add_child(slot_panel)

		var entry: Dictionary = {
			"slot": slot_i,
			"panel": slot_panel,
			"item": {},
			"inv_index": -1,
			"hovered": false,
		}

		var icon_c := WowDrawControl.new(func(c: Control) -> void:
			var it: Dictionary = entry["item"]
			if not it.is_empty():
				WowUIArt.draw_item_icon(c, Rect2(Vector2.ZERO, c.size), it, GameState.player_class)
		)
		icon_c.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot_panel.add_child(icon_c)
		entry["icon_ctrl"] = icon_c

		var cnt_lbl := Label.new()
		cnt_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		cnt_lbl.offset_left = -28
		cnt_lbl.offset_top = -16
		cnt_lbl.offset_right = -3
		cnt_lbl.offset_bottom = -1
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt_lbl.add_theme_font_size_override("font_size", 11)
		cnt_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		cnt_lbl.add_theme_constant_override("outline_size", 3)
		cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(cnt_lbl)
		entry["count_lbl"] = cnt_lbl

		var cd_dim := ColorRect.new()
		cd_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd_dim.color = Color(0.03, 0.03, 0.05, 0.78)
		cd_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_dim.visible = false
		slot_panel.add_child(cd_dim)
		entry["cd_dim"] = cd_dim

		var cd_lbl := Label.new()
		cd_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 12)
		cd_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		cd_lbl.add_theme_constant_override("outline_size", 3)
		cd_lbl.modulate = Color(1.0, 0.90, 0.35)
		cd_lbl.visible = false
		slot_panel.add_child(cd_lbl)
		entry["cd_lbl"] = cd_lbl

		var cap_slot: int = slot_i
		slot_panel.mouse_entered.connect(func() -> void: _on_bag_slot_hover(cap_slot, true))
		slot_panel.mouse_exited.connect(func() -> void: _on_bag_slot_hover(cap_slot, false))
		slot_panel.gui_input.connect(func(ev: InputEvent) -> void: _on_bag_slot_gui_input(cap_slot, ev))

		bag_slot_entries.append(entry)

	# Компактная полоса быстрого ремесла (Первая помощь / Алхимия)
	var sep := HSeparator.new()
	vbox.add_child(sep)

	var craft_row := HBoxContainer.new()
	craft_row.add_theme_constant_override("separation", 4)
	vbox.add_child(craft_row)

	for rec in [
		{"id": "bandage", "label": "Бинт", "tip": "[color=#1eff00][b]Рецепт: Травяной бинт x2[/b][/color]\nТребуется: 2x Мироцвет\nВосстанавливает 80 ед. здоровья."},
		{"id": "potion", "label": "Зелье", "tip": "[color=#1eff00][b]Рецепт: Добротное зелье[/b][/color]\nТребуется: 1x Мироцвет + 1x Сребролист\nВосстанавливает 95 ед. здоровья."},
		{"id": "elixir", "label": "Эликсир", "tip": "[color=#1eff00][b]Рецепт: Эликсир стойкости[/b][/color]\nТребуется: 1x Сребролист + 1x Лазурный кристалл\n+25 макс. здоровья и +15% к урону на 60 сек."},
	]:
		var cb := Button.new()
		cb.text = String(rec["label"])
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.custom_minimum_size = Vector2(0, 24)
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override("font_size", 11)
		var rid: String = String(rec["id"])
		var rtip: String = String(rec["tip"])
		cb.pressed.connect(func() -> void: GameState.craft_recipe(rid))
		cb.mouse_entered.connect(func() -> void: _show_wow_tooltip(rtip, cb))
		cb.mouse_exited.connect(_hide_wow_tooltip)
		craft_row.add_child(cb)

	# Классическая нижняя полоса монет с золотыми, серебряными и медными кружками
	var coin_panel := PanelContainer.new()
	coin_panel.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.06, 0.055, 0.05, 0.96), Color(0.42, 0.35, 0.22, 0.92), 1, 2))
	vbox.add_child(coin_panel)

	bag_coin_ctrl = WowDrawControl.new(func(c: Control) -> void:
		WowUIArt.draw_coin_strip(c, Rect2(Vector2.ZERO, c.size), GameState.money_copper)
	)
	bag_coin_ctrl.custom_minimum_size = Vector2(214, 22)
	coin_panel.add_child(bag_coin_ctrl)


func _build_char_window() -> void:
	char_window = PanelContainer.new()
	char_window.position = Vector2(14, 150)
	char_window.custom_minimum_size = Vector2(346, 368)
	char_window.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.09, 0.085, 0.11, 0.96), Color(0.70, 0.58, 0.30, 0.98), 2, 8))
	char_window.visible = false
	root_control.add_child(char_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	char_window.add_child(vbox)

	var trow := HBoxContainer.new()
	vbox.add_child(trow)
	var title := Label.new()
	title.text = "Персонаж [C]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.modulate = Color(1.0, 0.86, 0.38)
	trow.add_child(title)
	var xbtn := Button.new()
	xbtn.text = "X"
	xbtn.focus_mode = Control.FOCUS_NONE
	xbtn.pressed.connect(func() -> void:
		char_window.visible = false
		_hide_wow_tooltip()
	)
	trow.add_child(xbtn)

	# Бумажная кукла (Paperdoll) со слотами Брони и Оружия слева и справа (как в WoW)
	var doll_row := HBoxContainer.new()
	doll_row.add_theme_constant_override("separation", 10)
	doll_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(doll_row)

	var left_col := VBoxContainer.new()
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_theme_constant_override("separation", 4)
	doll_row.add_child(left_col)

	char_armor_slot_panel = PanelContainer.new()
	char_armor_slot_panel.custom_minimum_size = Vector2(50, 50)
	char_armor_slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	left_col.add_child(char_armor_slot_panel)
	char_armor_icon = WowDrawControl.new(func(c: Control) -> void:
		WowUIArt.draw_item_icon(c, Rect2(Vector2.ZERO, c.size), {
			"id": GameState.equipped_armor_id, "type": "armor", "rarity": GameState.equipped_armor_rarity
		}, GameState.player_class)
	)
	char_armor_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	char_armor_slot_panel.add_child(char_armor_icon)
	char_armor_slot_panel.mouse_entered.connect(func() -> void:
		_show_wow_tooltip(WowUIArt.format_item_tooltip({
			"id": GameState.equipped_armor_id, "name": GameState.equipped_armor_name,
			"type": "armor", "bonus": GameState.equipped_armor_hp_bonus, "rarity": GameState.equipped_armor_rarity,
		}, 0, false, false), char_armor_slot_panel)
	)
	char_armor_slot_panel.mouse_exited.connect(_hide_wow_tooltip)

	var arm_lbl := Label.new()
	arm_lbl.text = "Доспех"
	arm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arm_lbl.add_theme_font_size_override("font_size", 10)
	arm_lbl.modulate = Color(0.78, 0.80, 0.86)
	left_col.add_child(arm_lbl)

	char_doll_hero = WowDrawControl.new(func(c: Control) -> void:
		WowUIArt.draw_paperdoll_hero(c, Rect2(Vector2.ZERO, c.size), GameState.player_class, GameState.get_armor_visual_tier(), GameState.get_weapon_visual_id())
	)
	char_doll_hero.custom_minimum_size = Vector2(148, 120)
	doll_row.add_child(char_doll_hero)

	var right_col := VBoxContainer.new()
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.add_theme_constant_override("separation", 4)
	doll_row.add_child(right_col)

	char_weapon_slot_panel = PanelContainer.new()
	char_weapon_slot_panel.custom_minimum_size = Vector2(50, 50)
	char_weapon_slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	right_col.add_child(char_weapon_slot_panel)
	char_weapon_icon = WowDrawControl.new(func(c: Control) -> void:
		WowUIArt.draw_item_icon(c, Rect2(Vector2.ZERO, c.size), {
			"id": GameState.equipped_weapon_id, "type": "weapon", "rarity": GameState.equipped_weapon_rarity
		}, GameState.player_class)
	)
	char_weapon_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	char_weapon_slot_panel.add_child(char_weapon_icon)
	char_weapon_slot_panel.mouse_entered.connect(func() -> void:
		_show_wow_tooltip(WowUIArt.format_item_tooltip({
			"id": GameState.equipped_weapon_id, "name": GameState.equipped_weapon_name,
			"type": "weapon", "bonus": GameState.equipped_weapon_bonus, "rarity": GameState.equipped_weapon_rarity,
		}, 0, false, false), char_weapon_slot_panel)
	)
	char_weapon_slot_panel.mouse_exited.connect(_hide_wow_tooltip)

	var wep_lbl := Label.new()
	wep_lbl.text = "Оружие"
	wep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wep_lbl.add_theme_font_size_override("font_size", 10)
	wep_lbl.modulate = Color(0.78, 0.80, 0.86)
	right_col.add_child(wep_lbl)

	var stats_box := PanelContainer.new()
	stats_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_box.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.055, 0.055, 0.075, 0.92), Color(0.45, 0.38, 0.22, 0.85), 1, 6))
	vbox.add_child(stats_box)

	char_stats_rtl = RichTextLabel.new()
	char_stats_rtl.bbcode_enabled = true
	char_stats_rtl.fit_content = false
	char_stats_rtl.scroll_active = false
	char_stats_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	char_stats_rtl.add_theme_font_size_override("normal_font_size", 12)
	stats_box.add_child(char_stats_rtl)


func _build_questlog_window() -> void:
	questlog_window = PanelContainer.new()
	questlog_window.set_anchors_preset(Control.PRESET_CENTER)
	questlog_window.offset_left = -250
	questlog_window.offset_top = -180
	questlog_window.offset_right = 250
	questlog_window.offset_bottom = 180
	questlog_window.add_theme_stylebox_override("panel", _make_panel_style(Color(0.86, 0.78, 0.60, 0.98), Color(0.38, 0.24, 0.11, 1.0), 3))
	questlog_window.visible = false
	root_control.add_child(questlog_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	questlog_window.add_child(vbox)

	var trow := HBoxContainer.new()
	vbox.add_child(trow)
	var title := Label.new()
	title.text = "Журнал заданий [L]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(0.22, 0.12, 0.05)
	trow.add_child(title)
	var xbtn := Button.new()
	xbtn.text = "X"
	xbtn.pressed.connect(func() -> void: questlog_window.visible = false)
	trow.add_child(xbtn)

	questlog_rtl = RichTextLabel.new()
	questlog_rtl.bbcode_enabled = true
	questlog_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	questlog_rtl.add_theme_color_override("default_color", Color(0.16, 0.10, 0.05))
	questlog_rtl.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(questlog_rtl)


func _build_worldmap_window() -> void:
	worldmap_window = PanelContainer.new()
	worldmap_window.set_anchors_preset(Control.PRESET_CENTER)
	worldmap_window.offset_left = -350
	worldmap_window.offset_top = -255
	worldmap_window.offset_right = 350
	worldmap_window.offset_bottom = 255
	worldmap_window.add_theme_stylebox_override("panel", _make_panel_style())
	worldmap_window.visible = false
	root_control.add_child(worldmap_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	worldmap_window.add_child(vbox)

	var trow := HBoxContainer.new()
	vbox.add_child(trow)
	var title := Label.new()
	title.text = "Карта долины Северноземья [M]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(1.0, 0.86, 0.38)
	trow.add_child(title)
	var xbtn := Button.new()
	xbtn.text = "X"
	xbtn.pressed.connect(func() -> void: worldmap_window.visible = false)
	trow.add_child(xbtn)

	var canvas := WorldMapCanvas.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(canvas)

	var leg := Label.new()
	leg.text = "Жёлтая стрелка — Вы | Зелёный — NPC | Голубой крест — Тело | Фиолетовый — Рудник"
	leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leg.add_theme_font_size_override("font_size", 11)
	leg.modulate = Color(0.85, 0.86, 0.90)
	vbox.add_child(leg)


func _build_talent_window() -> void:
	talent_window = PanelContainer.new()
	talent_window.set_anchors_preset(Control.PRESET_CENTER)
	talent_window.offset_left = -205
	talent_window.offset_top = -145
	talent_window.offset_right = 205
	talent_window.offset_bottom = 145
	talent_window.add_theme_stylebox_override("panel", _make_panel_style())
	talent_window.visible = false
	root_control.add_child(talent_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	talent_window.add_child(vbox)

	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "Древо талантов [T]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(1.0, 0.86, 0.38)
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(func() -> void: talent_window.visible = false)
	title_row.add_child(close_btn)

	talent_points_lbl = Label.new()
	talent_points_lbl.add_theme_font_size_override("font_size", 13)
	talent_points_lbl.modulate = Color(0.55, 0.95, 0.55)
	vbox.add_child(talent_points_lbl)

	talent_list_vbox = VBoxContainer.new()
	talent_list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	talent_list_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(talent_list_vbox)


func _build_menu_window() -> void:
	menu_window = PanelContainer.new()
	menu_window.set_anchors_preset(Control.PRESET_CENTER)
	menu_window.offset_left = -150
	menu_window.offset_top = -135
	menu_window.offset_right = 150
	menu_window.offset_bottom = 135
	menu_window.add_theme_stylebox_override("panel", _make_panel_style())
	menu_window.visible = false
	root_control.add_child(menu_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	menu_window.add_child(vbox)

	var title := Label.new()
	title.text = "Игровое меню"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.modulate = Color(1.0, 0.86, 0.38)
	vbox.add_child(title)

	var save_btn := Button.new()
	save_btn.text = "Сохранить игру [F5]"
	save_btn.pressed.connect(func() -> void:
		GameState.save_game()
		menu_window.visible = false
	)
	vbox.add_child(save_btn)

	menu_load_btn = Button.new()
	menu_load_btn.text = "Загрузить сохранение"
	menu_load_btn.pressed.connect(func() -> void:
		if GameState.load_game():
			menu_window.visible = false
			get_tree().change_scene_to_file("res://scenes/main_world.tscn")
	)
	vbox.add_child(menu_load_btn)

	var char_btn := Button.new()
	char_btn.text = "Сменить класс (Главное меню)"
	char_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/class_select.tscn")
	)
	vbox.add_child(char_btn)

	var resume_btn := Button.new()
	resume_btn.text = "Вернуться в игру"
	resume_btn.pressed.connect(func() -> void: menu_window.visible = false)
	vbox.add_child(resume_btn)


func _build_help_window() -> void:
	help_window = PanelContainer.new()
	help_window.set_anchors_preset(Control.PRESET_CENTER)
	help_window.offset_left = -230
	help_window.offset_top = -175
	help_window.offset_right = 230
	help_window.offset_bottom = 175
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
		"• [color=#ffd866]ПКМ или [F][/color] по NPC / ящику / жиле / траве / трупу\n" + \
		"• [color=#ffd866]1–5[/color] — умения | [color=#ffd866]6–8[/color] — зелья/еда/Камень возвращения\n" + \
		"• [color=#ffd866]C[/color] — герой | [color=#ffd866]B[/color] — сумка | [color=#ffd866]L[/color] — квесты | [color=#ffd866]M[/color] — карта | [color=#ffd866]T[/color] — таланты | [color=#ffd866]N[/color] — звук"
	vbox.add_child(info)

	var ok_btn := Button.new()
	ok_btn.text = "Понятно [H]"
	ok_btn.pressed.connect(func() -> void: help_window.visible = false)
	vbox.add_child(ok_btn)


func _build_death_banner() -> void:
	ghost_tint = ColorRect.new()
	ghost_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	ghost_tint.color = Color(0.45, 0.6, 0.85, 0.22)
	ghost_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost_tint.visible = false
	root_control.add_child(ghost_tint)
	root_control.move_child(ghost_tint, 0)

	death_banner = PanelContainer.new()
	death_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	death_banner.offset_left = -230
	death_banner.offset_top = 110
	death_banner.offset_right = 230
	death_banner.offset_bottom = 230
	death_banner.add_theme_stylebox_override("panel", _make_panel_style(Color(0.24, 0.04, 0.04, 0.92), Color(0.95, 0.25, 0.20), 2))
	death_banner.visible = false
	root_control.add_child(death_banner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	death_banner.add_child(vbox)

	death_lbl = Label.new()
	death_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_lbl.add_theme_font_size_override("font_size", 15)
	death_lbl.modulate = Color(1.0, 0.85, 0.82)
	vbox.add_child(death_lbl)

	release_btn = Button.new()
	release_btn.text = "Освободить дух"
	release_btn.focus_mode = Control.FOCUS_NONE
	release_btn.pressed.connect(func() -> void: GameState.release_spirit())
	vbox.add_child(release_btn)

	res_corpse_btn = Button.new()
	res_corpse_btn.text = "Воскреснуть у тела [R]"
	res_corpse_btn.focus_mode = Control.FOCUS_NONE
	res_corpse_btn.pressed.connect(_try_resurrect_corpse)
	vbox.add_child(res_corpse_btn)

	res_healer_btn = Button.new()
	res_healer_btn.text = "Воскреснуть у Духа-целителя (25% здоровья)"
	res_healer_btn.focus_mode = Control.FOCUS_NONE
	res_healer_btn.pressed.connect(_try_resurrect_healer)
	vbox.add_child(res_healer_btn)


const CORPSE_RES_RADIUS := 12.0
const HEALER_RES_RADIUS := 9.0


func _corpse_distance() -> float:
	var p: Node3D = GameState.player_node
	if not is_instance_valid(p):
		return INF
	return p.global_position.distance_to(GameState.corpse_position)


func _healer_distance() -> float:
	var p: Node3D = GameState.player_node
	if not is_instance_valid(p):
		return INF
	var best: float = INF
	for n in get_tree().get_nodes_in_group("spirit_healer"):
		best = minf(best, p.global_position.distance_to((n as Node3D).global_position))
	return best


func _try_resurrect_corpse() -> void:
	if _corpse_distance() <= CORPSE_RES_RADIUS:
		GameState.resurrect(true)
	else:
		GameState.add_combat_log("Вы слишком далеко от своего тела (нужно ближе %d м)." % int(CORPSE_RES_RADIUS), GameState.COLOR_LOG_ERROR)


func _try_resurrect_healer() -> void:
	if _healer_distance() <= HEALER_RES_RADIUS:
		GameState.resurrect(false)
	else:
		GameState.add_combat_log("Подойдите ближе к Духу-целителю.", GameState.COLOR_LOG_ERROR)


func _refresh_player_frame() -> void:
	if _built_action_class != GameState.player_class:
		_populate_action_buttons()
	if player_portrait_ctrl:
		player_portrait_ctrl.queue_redraw()
	if player_lvl_badge:
		player_lvl_badge.text = "%d" % GameState.level
	player_name_lbl.text = "%s (%s)" % [GameState.player_name, GameState.player_class_name]
	_refresh_pet_frame()

	player_hp_bar.max_value = GameState.max_hp
	player_hp_bar.value = GameState.hp
	player_hp_lbl.text = "%d / %d" % [GameState.hp, GameState.max_hp]

	player_rage_bar.max_value = GameState.max_rage
	player_rage_bar.value = GameState.rage
	if GameState.resource_type == "mana":
		player_rage_lbl.text = "Мана: %d / %d" % [GameState.rage, GameState.max_rage]
		player_rage_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.18, 0.40, 0.92)))
	elif GameState.resource_type == "energy":
		player_rage_lbl.text = "Энергия: %d / %d" % [GameState.rage, GameState.max_rage]
		player_rage_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.88, 0.74, 0.14)))
	else:
		player_rage_lbl.text = "Ярость: %d / %d" % [GameState.rage, GameState.max_rage]
		player_rage_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.76, 0.14, 0.14)))

	combat_badge.visible = GameState.in_combat
	_rebuild_buff_icons()

	xp_bar.max_value = GameState.xp_to_next
	xp_bar.value = GameState.xp
	var pct: int = int(round((float(GameState.xp) / maxf(1.0, float(GameState.xp_to_next))) * 100.0))
	xp_lbl.text = "Опыт: %d / %d (%d%%) — Ур. %d" % [GameState.xp, GameState.xp_to_next, pct, GameState.level]

	if br_coin_ctrl:
		br_coin_ctrl.queue_redraw()
	if bag_coin_ctrl:
		bag_coin_ctrl.queue_redraw()
	if talent_btn:
		if GameState.talent_points > 0:
			talent_btn.text = "T+"
			talent_btn.modulate = Color(1.0, 0.92, 0.35)
		else:
			talent_btn.text = "T"
			talent_btn.modulate = Color.WHITE
	if char_window and char_window.visible:
		_refresh_char_window()


func _add_buff_icon(icon_key: String, secs: int, tip: String, border_col: Color) -> void:
	if buff_row == null:
		return
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	vb.mouse_entered.connect(func() -> void: _show_wow_tooltip(tip, vb))
	vb.mouse_exited.connect(_hide_wow_tooltip)

	var sq := PanelContainer.new()
	sq.custom_minimum_size = Vector2(28, 28)
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sq.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(Color(0.08, 0.08, 0.10, 0.96), border_col, 1, 2))
	vb.add_child(sq)

	var art := WowDrawControl.new(func(c: Control) -> void:
		WowUIArt.draw_ability_icon(c, Rect2(Vector2.ZERO, c.size), icon_key, GameState.player_class)
	)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	sq.add_child(art)

	var tm := Label.new()
	tm.text = ("%dс" % secs) if secs > 0 else "∞"
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tm.add_theme_font_size_override("font_size", 10)
	tm.add_theme_color_override("font_outline_color", Color.BLACK)
	tm.add_theme_constant_override("outline_size", 3)
	tm.modulate = Color(1.0, 0.92, 0.38)
	vb.add_child(tm)
	buff_row.add_child(vb)


func _rebuild_buff_icons() -> void:
	if buff_row == null:
		return
	for c in buff_row.get_children():
		c.queue_free()
	if GameState.battle_shout_timer > 0.0:
		_add_buff_icon("battle_shout", int(ceil(GameState.battle_shout_timer)), "[color=#ffd866][b]Боевой крик[/b][/color]\n+25% к урону оружия.", Color(0.95, 0.78, 0.24))
	if GameState.elixir_timer > 0.0:
		_add_buff_icon("__item_util", int(ceil(GameState.elixir_timer)), "[color=#1eff00][b]Эликсир стойкости[/b][/color]\n+25 к макс. здоровью и +15% к урону.", Color(0.35, 0.96, 0.42))
	if GameState.is_stealthed:
		_add_buff_icon("stealth", 0, "[color=#99b3ff][b]Незаметность[/b][/color]\nВы скрыты в тенях.", Color(0.55, 0.68, 0.98))
	if GameState.pet_frenzy_timer > 0.0 and GameState.player_class == "hunter":
		_add_buff_icon("mend_pet", int(ceil(GameState.pet_frenzy_timer)), "[color=#88ee66][b]Зов стаи[/b][/color]\nПитомец наносит +25% урона.", Color(0.45, 0.96, 0.42))


func _refresh_pet_frame() -> void:
	if pet_frame == null:
		return
	var show_pet: bool = GameState.player_class == "hunter"
	pet_frame.visible = show_pet
	if not show_pet:
		return
	if pet_portrait_ctrl:
		pet_portrait_ctrl.queue_redraw()
	pet_hp_bar.max_value = GameState.pet_max_hp
	pet_hp_bar.value = GameState.pet_hp
	if GameState.pet_dead:
		pet_name_lbl.text = "Лесной страж (Пал — [5])"
		pet_name_lbl.modulate = Color(0.78, 0.42, 0.38)
		pet_hp_lbl.text = "0 / %d" % GameState.pet_max_hp
	else:
		pet_name_lbl.text = "Лесной страж"
		pet_name_lbl.modulate = Color(0.55, 0.96, 0.58)
		pet_hp_lbl.text = "%d / %d" % [GameState.pet_hp, GameState.pet_max_hp]


func _on_target_changed(_new_target: Node3D) -> void:
	_update_target_frame()


func _update_target_frame() -> void:
	var t: Node3D = GameState.current_target
	if not is_instance_valid(t):
		target_frame.visible = false
		return

	target_frame.visible = true
	if target_portrait_ctrl:
		target_portrait_ctrl.queue_redraw()
	var p: Node3D = GameState.player_node
	var dist: float = p.global_position.distance_to(t.global_position) if is_instance_valid(p) else 0.0
	target_dist_lbl.text = "Дист: %.1f м" % dist
	target_combo_lbl.visible = false
	target_cast_bar.visible = false

	var hdr_bg := Color(0.36, 0.10, 0.10, 0.88)
	if t is MobEntity:
		var mob := t as MobEntity
		target_name_lbl.text = mob.mob_title
		target_name_lbl.modulate = Color(1.0, 0.88, 0.42) if mob.is_elite else Color(1.0, 0.92, 0.90)
		target_level_lbl.text = "★ Элита" if mob.is_elite else ""
		target_level_lbl.modulate = Color(1.0, 0.85, 0.30)
		if target_lvl_badge:
			target_lvl_badge.text = "%d" % mob.level
		target_hp_bar.max_value = mob.max_hp
		target_hp_bar.value = mob.hp
		target_hp_lbl.text = "Труп" if mob.is_dead() else "%d / %d" % [mob.hp, mob.max_hp]
		hdr_bg = Color(0.20, 0.20, 0.22, 0.85) if mob.is_dead() else Color(0.42, 0.10, 0.10, 0.92)
		target_hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.45, 0.45, 0.45) if mob.is_dead() else Color(0.76, 0.18, 0.16)))
		if not mob.is_dead() and mob.cast_display_name != "":
			target_cast_bar.visible = true
			target_cast_bar.value = mob.cast_progress
			(target_cast_bar.get_meta("label") as Label).text = mob.cast_display_name
		if GameState.player_class == "rogue" and not mob.is_dead():
			var pts: int = GameState.combo_points if GameState.combo_target == mob else 0
			target_combo_lbl.visible = true
			target_combo_lbl.text = "★".repeat(pts) + "☆".repeat(GameState.max_combo_points - pts)
	elif t is PetCompanion:
		target_name_lbl.text = "Лесной страж"
		target_name_lbl.modulate = Color(0.88, 1.0, 0.88)
		target_level_lbl.text = "Спутник"
		target_level_lbl.modulate = Color(0.55, 0.96, 0.58)
		if target_lvl_badge:
			target_lvl_badge.text = "%d" % GameState.level
		hdr_bg = Color(0.10, 0.32, 0.14, 0.90)
		target_hp_bar.max_value = GameState.pet_max_hp
		target_hp_bar.value = GameState.pet_hp
		target_hp_lbl.text = "Пал" if GameState.pet_dead else "%d / %d" % [GameState.pet_hp, GameState.pet_max_hp]
		target_hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.22, 0.72, 0.26)))
	elif t is QuestNPC:
		var npc := t as QuestNPC
		target_name_lbl.text = npc.npc_name
		target_name_lbl.modulate = Color(0.90, 1.0, 0.90)
		target_level_lbl.text = "Торговец" if npc.role == "merchant" else ("Стража" if npc.role == "patrol" else "Друг")
		target_level_lbl.modulate = Color(0.55, 0.96, 0.58)
		if target_lvl_badge:
			target_lvl_badge.text = "5"
		hdr_bg = Color(0.10, 0.34, 0.14, 0.90)
		target_hp_bar.max_value = 100
		target_hp_bar.value = 100
		target_hp_lbl.text = "100 / 100"
		target_hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.18, 0.72, 0.24)))
	elif t is InteractableProp:
		var prop := t as InteractableProp
		target_name_lbl.text = prop.prop_title
		target_name_lbl.modulate = Color(0.96, 0.94, 0.78)
		target_level_lbl.text = "Жила" if prop.prop_id == "ore_vein" else ("Трава" if prop.prop_id == "herb_node" else "Объект")
		target_level_lbl.modulate = Color(1.0, 0.88, 0.42)
		if target_lvl_badge:
			target_lvl_badge.text = "*"
		hdr_bg = Color(0.32, 0.26, 0.08, 0.90)
		target_hp_bar.max_value = 100
		target_hp_bar.value = 100
		target_hp_lbl.text = "[F / ПКМ]"
		target_hp_bar.add_theme_stylebox_override("fill", _make_bar_style(Color(0.78, 0.62, 0.20)))
	if target_name_hdr:
		target_name_hdr.add_theme_stylebox_override("panel", WowUIArt.make_wow_panel_style(hdr_bg, Color(0.48, 0.38, 0.22, 0.8), 1, 2))


func _update_action_bar() -> void:
	var p := GameState.player_node as PlayerController
	if p != null:
		swing_bar.visible = p.auto_attack_enabled
		swing_bar.value = p.get_swing_progress()
		cast_bar.visible = p.casting_slot != 0
		if cast_bar.visible:
			cast_bar.value = p.get_cast_progress()
			(cast_bar.get_meta("label") as Label).text = p.get_cast_title()
	else:
		swing_bar.visible = false
		cast_bar.visible = false

	for entry in ability_buttons:
		var btn: Button = entry["btn"]
		var cd_dim: ColorRect = entry["cd_dim"]
		var cd_lbl: Label = entry["cd_lbl"]
		var sub_lbl: Label = entry["sub_lbl"]
		var cfg: Dictionary = entry["cfg"]
		var slot: int = int(cfg["slot"])
		var cd_key: String = String(cfg["cd_key"])
		var rage_cost: int = int(cfg["rage_cost"])

		if slot == 1:
			var active: bool = p != null and p.auto_attack_enabled
			btn.modulate = Color(1.22, 1.10, 0.55) if active else Color.WHITE
			sub_lbl.text = "АКТ" if active else ""
			continue
		if slot == 6:
			var cnt_hp: int = GameState.get_item_count_by_types(["potion", "bandage"])
			sub_lbl.text = "%d" % cnt_hp
			cd_dim.visible = cnt_hp <= 0
			cd_lbl.visible = false
			btn.modulate = Color(0.55, 0.55, 0.58) if cnt_hp <= 0 else Color.WHITE
			continue
		if slot == 7:
			var cnt_util: int = GameState.get_item_count_by_types(["elixir", "mana_potion", "food"])
			sub_lbl.text = "%d" % cnt_util
			cd_dim.visible = cnt_util <= 0
			cd_lbl.visible = false
			btn.modulate = Color(0.55, 0.55, 0.58) if cnt_util <= 0 else Color.WHITE
			continue

		var cd_rem: float = float(GameState.ability_cooldowns.get(cd_key, 0.0))
		if cd_rem > 0.0:
			cd_dim.visible = true
			cd_lbl.visible = true
			cd_lbl.text = "%.1f" % cd_rem
			btn.modulate = Color(0.85, 0.85, 0.90)
		else:
			cd_dim.visible = false
			cd_lbl.visible = false
			if GameState.player_class == "rogue" and slot == 4 and GameState.is_stealthed:
				btn.modulate = Color(0.75, 0.98, 1.2)
				sub_lbl.text = "АКТ"
			else:
				sub_lbl.text = ""
				if rage_cost > 0 and GameState.rage < rage_cost:
					btn.modulate = Color(0.58, 0.52, 0.52)
				else:
					btn.modulate = Color.WHITE

	if inventory_window and inventory_window.visible:
		var hs_cd: float = float(GameState.ability_cooldowns.get("hearthstone", 0.0))
		for s_entry in bag_slot_entries:
			var it: Dictionary = s_entry["item"]
			var dim_c: ColorRect = s_entry["cd_dim"]
			var cdl: Label = s_entry["cd_lbl"]
			if not it.is_empty() and String(it.get("type", "")) == "hearthstone" and hs_cd > 0.0:
				dim_c.visible = true
				cdl.visible = true
				cdl.text = "%.0f" % ceil(hs_cd)
			else:
				dim_c.visible = false
				cdl.visible = false


func _update_zone_label() -> void:
	if zone_lbl == null or not is_instance_valid(GameState.player_node):
		return
	var pos: Vector3 = GameState.player_node.global_position
	if pos.z <= -58.0:
		zone_lbl.text = "Северный рудник (Шахта)"
	elif pos.x <= -20.0:
		zone_lbl.text = "Лагерь Братства"
	elif pos.x >= 20.0:
		zone_lbl.text = "Хрустальное озеро"
	elif pos.z <= -6.0:
		zone_lbl.text = "Волчий лес"
	else:
		zone_lbl.text = "Северноземье — Застава"


func _update_death_banner() -> void:
	var dead: bool = GameState.is_dead
	var ghost: bool = GameState.is_ghost
	death_banner.visible = dead
	ghost_tint.visible = ghost
	if not dead:
		return
	release_btn.visible = not ghost
	res_corpse_btn.visible = ghost
	res_healer_btn.visible = ghost
	if not ghost:
		death_lbl.text = "ВЫ ПОГИБЛИ!\nОсвободите дух, чтобы вернуться на кладбище."
	else:
		var cd: float = _corpse_distance()
		var hd: float = _healer_distance()
		death_lbl.text = "Вы — бесплотный дух.\nДо тела: %d м | До Духа-целителя: %d м" % [int(cd), int(hd)]
		res_corpse_btn.disabled = cd > CORPSE_RES_RADIUS
		res_healer_btn.disabled = hd > HEALER_RES_RADIUS


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
		var any_avail: bool = false
		for q_id in GameState.quest_order:
			if GameState.quests[q_id]["state"] == "available":
				any_avail = true
				break
		if any_avail:
			lines.append("[color=#cccccc]Возьмите новые задания на Заставе (!).[/color]")
		else:
			lines.append("[color=#77ee77]Все задания заставы выполнены![/color]")

	quest_tracker_lbl.text = "\n".join(lines)
	if questlog_window and questlog_window.visible:
		_refresh_questlog()


func _on_quest_or_inv_changed_for_logs() -> void:
	_refresh_quest_tracker()


func _on_inventory_updated() -> void:
	_refresh_inventory_window()
	if vendor_window and vendor_window.visible:
		_refresh_vendor_sell_list()
	if char_window and char_window.visible:
		_refresh_char_window()


func _on_combat_log_added(text: String, color: Color) -> void:
	if combat_log_rtl == null:
		return
	var hex: String = color.to_html(false)
	combat_log_rtl.append_text("[color=#%s]%s[/color]\n" % [hex, text])


func _on_floating_text(world_pos: Vector3, text: String, color: Color, is_crit: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 26 if is_crit else 17)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.04, 0.95))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_layer.add_child(lbl)

	active_floaters.append({
		"label": lbl,
		"world_pos": world_pos,
		"age": 0.0,
		"duration": 1.35 if is_crit else 1.0,
		"vx": randf_range(-34.0, 34.0),
		"vy": -88.0 if is_crit else -54.0,
		"is_crit": is_crit,
		"offset_2d": Vector2(randf_range(-12.0, 12.0), 0.0),
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

		f["vy"] = float(f["vy"]) + 65.0 * delta
		var off: Vector2 = f["offset_2d"]
		off.x += float(f["vx"]) * delta
		off.y += float(f["vy"]) * delta
		f["offset_2d"] = off

		if cam == null or cam.is_position_behind(f["world_pos"]):
			lbl.visible = false
		else:
			lbl.visible = true
			var screen_pos: Vector2 = cam.unproject_position(f["world_pos"]) + off
			lbl.position = screen_pos - lbl.size * 0.5
			var progress: float = f["age"] / f["duration"]
			if bool(f["is_crit"]) and progress < 0.18:
				var pop: float = 1.0 + sin((progress / 0.18) * PI) * 0.35
				lbl.scale = Vector2(pop, pop)
			else:
				lbl.scale = Vector2.ONE
			var alpha: float = clampf(1.0 - pow(progress, 2.2), 0.0, 1.0)
			lbl.modulate.a = alpha


const VENDOR_GOODS: Array[Dictionary] = [
	{"price": 35, "item": {"id": "tough_jerky", "name": "Дорожный паёк", "type": "food", "bonus": 45, "rarity": "common", "desc": "Вне боя восстанавливает 45% здоровья и маны", "count": 1}},
	{"price": 40, "item": {"id": "minor_healing_potion", "name": "Малое лечебное зелье", "type": "potion", "bonus": 55, "rarity": "common", "desc": "Восстанавливает 55 ед. здоровья", "count": 1}},
	{"price": 50, "item": {"id": "minor_mana_potion", "name": "Малое зелье маны", "type": "mana_potion", "bonus": 55, "rarity": "common", "desc": "Восстанавливает 55 ед. маны", "count": 1}},
	{"price": 140, "item": {"id": "lesser_healing_potion", "name": "Добротное лечебное зелье", "type": "potion", "bonus": 95, "rarity": "uncommon", "desc": "Восстанавливает 95 ед. здоровья", "count": 1}},
	{"price": 300, "item": {"id": "guard_blade", "name": "Оружие стражи", "type": "weapon", "bonus": 4, "rarity": "uncommon", "desc": "+4 к урону оружия / заклинаний", "count": 1}},
	{"price": 280, "item": {"id": "guard_armor", "name": "Кираса стражи", "type": "armor", "bonus": 30, "rarity": "uncommon", "desc": "+30 к максимальному здоровью", "count": 1}},
]


func _build_vendor_window() -> void:
	vendor_window = PanelContainer.new()
	vendor_window.set_anchors_preset(Control.PRESET_CENTER)
	vendor_window.offset_left = -260
	vendor_window.offset_top = -235
	vendor_window.offset_right = 260
	vendor_window.offset_bottom = 235
	vendor_window.add_theme_stylebox_override("panel", _make_panel_style())
	vendor_window.visible = false
	root_control.add_child(vendor_window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vendor_window.add_child(vbox)

	var title := Label.new()
	title.text = "Торговец Элрик"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(1.0, 0.86, 0.38)
	vbox.add_child(title)

	vendor_money_lbl = Label.new()
	vendor_money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vendor_money_lbl.modulate = Color(1.0, 0.88, 0.38)
	vbox.add_child(vendor_money_lbl)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(cols)

	var buy_col := VBoxContainer.new()
	buy_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_col.add_theme_constant_override("separation", 4)
	cols.add_child(buy_col)

	var buy_hdr := Label.new()
	buy_hdr.text = "Купить товары:"
	buy_hdr.modulate = Color(0.85, 0.92, 1.0)
	buy_hdr.add_theme_font_size_override("font_size", 12)
	buy_col.add_child(buy_hdr)

	for good in VENDOR_GOODS:
		var item: Dictionary = good["item"]
		var price: int = int(good["price"])
		var btn := Button.new()
		btn.text = "%s — %s" % [item["name"], GameState.format_money(price)]
		btn.tooltip_text = String(item.get("desc", ""))
		btn.modulate = _rarity_color(String(item.get("rarity", "common")))
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(func() -> void:
			GameState.buy_item(item, price)
			_refresh_vendor_money()
			_refresh_vendor_sell_list()
		)
		buy_col.add_child(btn)

	var sell_col := VBoxContainer.new()
	sell_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_col.add_theme_constant_override("separation", 4)
	cols.add_child(sell_col)

	var sell_hdr := Label.new()
	sell_hdr.text = "Продать из сумки:"
	sell_hdr.modulate = Color(1.0, 0.86, 0.45)
	sell_hdr.add_theme_font_size_override("font_size", 12)
	sell_col.add_child(sell_hdr)

	var sell_btn := Button.new()
	sell_btn.text = "Продать все трофеи (хлам)"
	sell_btn.focus_mode = Control.FOCUS_NONE
	sell_btn.add_theme_font_size_override("font_size", 11)
	sell_btn.pressed.connect(func() -> void:
		GameState.sell_all_junk()
		_refresh_vendor_money()
		_refresh_vendor_sell_list()
	)
	sell_col.add_child(sell_btn)

	var sell_scroll := ScrollContainer.new()
	sell_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_col.add_child(sell_scroll)

	vendor_sell_vbox = VBoxContainer.new()
	vendor_sell_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vendor_sell_vbox.add_theme_constant_override("separation", 3)
	sell_scroll.add_child(vendor_sell_vbox)

	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(func() -> void: vendor_window.visible = false)
	vbox.add_child(close_btn)


func _refresh_vendor_sell_list() -> void:
	if vendor_sell_vbox == null:
		return
	for c in vendor_sell_vbox.get_children():
		c.queue_free()
	for i in range(GameState.inventory.size()):
		var it: Dictionary = GameState.inventory[i]
		var sp: int = GameState.get_item_sell_price(it)
		if sp <= 0:
			continue
		var cnt: int = int(it.get("count", 1))
		var sb := Button.new()
		sb.text = "%s%s (+%s)" % [it["name"], (" x%d" % cnt) if cnt > 1 else "", GameState.format_money(sp * cnt)]
		sb.modulate = _rarity_color(String(it.get("rarity", "common")))
		sb.focus_mode = Control.FOCUS_NONE
		sb.add_theme_font_size_override("font_size", 11)
		var cap_idx: int = i
		sb.pressed.connect(func() -> void:
			GameState.sell_item_at(cap_idx)
			_refresh_vendor_money()
		)
		vendor_sell_vbox.add_child(sb)


func _refresh_vendor_money() -> void:
	if vendor_money_lbl:
		vendor_money_lbl.text = "Ваши деньги: %s" % GameState.format_money(GameState.money_copper)


func _open_npc_dialog(npc_ref: Node3D) -> void:
	if npc_ref is QuestNPC and (npc_ref as QuestNPC).role == "merchant":
		_refresh_vendor_money()
		_refresh_vendor_sell_list()
		vendor_window.visible = true
		return
	if npc_ref is QuestNPC and (npc_ref as QuestNPC).role == "patrol":
		var gnpc := npc_ref as QuestNPC
		current_dialog_quest_id = ""
		for c in quest_win_tabs.get_children():
			c.queue_free()
		quest_win_accept_btn.visible = false
		quest_win_complete_btn.visible = false
		quest_win_title.text = "%s <%s>" % [gnpc.npc_name, gnpc.npc_title]
		quest_win_body.text = "Король Вариан может спать спокойно, пока застава под охраной!\n\nБудь осторожен в Северном руднике: тамошние кобольды слушаются огромного Надзирателя Дробителя."
		quest_window.visible = true
		return

	var npc_name: String = "Капитан Маркус"
	if npc_ref is QuestNPC:
		npc_name = (npc_ref as QuestNPC).npc_name
	current_dialog_npc_name = npc_name

	for c in quest_win_tabs.get_children():
		c.queue_free()

	var npc_quests: Array[Dictionary] = GameState.get_npc_quests(npc_name)
	if npc_quests.is_empty():
		current_dialog_quest_id = ""
		quest_win_accept_btn.visible = false
		quest_win_complete_btn.visible = false
		quest_win_title.text = npc_name
		quest_win_body.text = "Застава в безопасности благодаря твоей отваге, герой!\n\nВсе мои задания уже выполнены — можешь исследовать долину и рудник дальше!"
		quest_window.visible = true
		return

	for q in npc_quests:
		var q_id: String = String(q["id"])
		var tag: String = "[?] " if q["state"] == "ready_to_turn_in" else ("[!] " if q["state"] == "available" else "• ")
		var tbtn := Button.new()
		tbtn.text = tag + String(q["title"])
		tbtn.focus_mode = Control.FOCUS_NONE
		tbtn.add_theme_font_size_override("font_size", 11)
		tbtn.pressed.connect(func() -> void: _show_npc_quest_entry(q_id))
		quest_win_tabs.add_child(tbtn)

	# Сначала показываем готовый к сдаче, затем доступный, затем в процессе
	var picked_id: String = String(npc_quests[0]["id"])
	for q in npc_quests:
		if q["state"] == "ready_to_turn_in":
			picked_id = String(q["id"])
			break
	if GameState.quests[picked_id]["state"] != "ready_to_turn_in":
		for q in npc_quests:
			if q["state"] == "available":
				picked_id = String(q["id"])
				break
	_show_npc_quest_entry(picked_id)
	quest_window.visible = true


func _show_npc_quest_entry(q_id: String) -> void:
	current_dialog_quest_id = q_id
	quest_win_accept_btn.visible = false
	quest_win_complete_btn.visible = false
	if not GameState.quests.has(q_id):
		return
	var q: Dictionary = GameState.quests[q_id]
	var st: String = String(q["state"])
	if st == "available":
		quest_win_title.text = "%s — %s" % [current_dialog_npc_name, q["title"]]
		var item: Dictionary = q.get("reward_item", {})
		var item_str: String = "[%s] (%s)" % [item.get("name", ""), item.get("desc", "")] if not item.is_empty() else ""
		quest_win_body.text = "%s\n\n[b]Награда:[/b]\n• %d ед. опыта\n• %s\n• %s" % [
			q["description"], q["reward_xp"], GameState.format_money(q["reward_copper"]), item_str
		]
		quest_win_accept_btn.visible = true
	elif st == "ready_to_turn_in":
		quest_win_title.text = "%s — %s (Выполнено)" % [current_dialog_npc_name, q["title"]]
		var item: Dictionary = q.get("reward_item", {})
		var item_str: String = "[%s] (%s)" % [item.get("name", ""), item.get("desc", "")] if not item.is_empty() else ""
		quest_win_body.text = "%s\n\n[b]Вы получите:[/b]\n• %d ед. опыта\n• %s\n• %s" % [
			q["completion_text"], q["reward_xp"], GameState.format_money(q["reward_copper"]), item_str
		]
		quest_win_complete_btn.visible = true
	else:
		quest_win_title.text = "%s — %s" % [current_dialog_npc_name, q["title"]]
		quest_win_body.text = "%s\n\nВозвращайся ко мне, как только цели будут выполнены!" % q["description"]


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
	_hide_wow_tooltip()
	for child in loot_list_vbox.get_children():
		child.queue_free()

	if not is_instance_valid(active_loot_mob) or not active_loot_mob.has_loot():
		loot_window.visible = false
		return

	if active_loot_mob.loot_copper > 0:
		var money_btn := Button.new()
		money_btn.text = "Золото / монеты: %s" % GameState.format_money(active_loot_mob.loot_copper)
		money_btn.modulate = Color(1.0, 0.88, 0.38)
		money_btn.focus_mode = Control.FOCUS_NONE
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
		var rar: String = String(item.get("rarity", "common"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		loot_list_vbox.add_child(row)

		var ic_box := PanelContainer.new()
		ic_box.custom_minimum_size = Vector2(36, 36)
		ic_box.add_theme_stylebox_override("panel", WowUIArt.make_slot_box_style(rar, false, false, false))
		row.add_child(ic_box)

		var ic_art := WowDrawControl.new(func(c: Control) -> void:
			WowUIArt.draw_item_icon(c, Rect2(Vector2.ZERO, c.size), item, GameState.player_class)
		)
		ic_art.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic_box.add_child(ic_art)

		var item_btn := Button.new()
		var cnt: int = int(item.get("count", 1))
		item_btn.text = "%s%s" % [item["name"], (" x%d" % cnt) if cnt > 1 else ""]
		item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_btn.focus_mode = Control.FOCUS_NONE
		item_btn.modulate = _rarity_color(rar)
		var cap_idx: int = idx
		var cap_item: Dictionary = item
		item_btn.pressed.connect(func() -> void:
			if is_instance_valid(active_loot_mob) and cap_idx < active_loot_mob.loot_items.size():
				var picked: Dictionary = active_loot_mob.loot_items[cap_idx]
				active_loot_mob.loot_items.remove_at(cap_idx)
				GameState.add_item_to_inventory(picked)
				active_loot_mob.refresh_loot_indicator()
				_rebuild_loot_list()
		)
		item_btn.mouse_entered.connect(func() -> void:
			_show_wow_tooltip(WowUIArt.format_item_tooltip(cap_item, GameState.get_item_sell_price(cap_item), false, false), item_btn)
		)
		item_btn.mouse_exited.connect(_hide_wow_tooltip)
		row.add_child(item_btn)


func _take_all_loot() -> void:
	_hide_wow_tooltip()
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
	picked_bag_slot = -1
	_hide_wow_tooltip()
	if inventory_window.visible:
		_refresh_inventory_window()


func _on_bag_slot_hover(slot_idx: int, inside: bool) -> void:
	if slot_idx < 0 or slot_idx >= bag_slot_entries.size():
		return
	var entry: Dictionary = bag_slot_entries[slot_idx]
	entry["hovered"] = inside
	var it: Dictionary = entry["item"]
	var p: PanelContainer = entry["panel"]
	p.add_theme_stylebox_override("panel", WowUIArt.make_slot_box_style(
		String(it.get("rarity", "common")), it.is_empty(), picked_bag_slot == slot_idx, inside
	))
	if inside and not it.is_empty():
		var v_open: bool = vendor_window != null and vendor_window.visible
		_show_wow_tooltip(WowUIArt.format_item_tooltip(it, GameState.get_item_sell_price(it), v_open, true), p)
	else:
		_hide_wow_tooltip()


func _on_bag_slot_gui_input(slot_idx: int, event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if slot_idx < 0 or slot_idx >= bag_slot_entries.size():
		return
	var entry: Dictionary = bag_slot_entries[slot_idx]
	var inv_idx: int = int(entry["inv_index"])
	var it: Dictionary = entry["item"]

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.double_click and inv_idx >= 0:
			picked_bag_slot = -1
			_hide_wow_tooltip()
			GameState.use_or_equip_item(inv_idx)
			get_viewport().set_input_as_handled()
			return
		if picked_bag_slot >= 0:
			var src: int = picked_bag_slot
			picked_bag_slot = -1
			if src != slot_idx:
				GameState.move_or_swap_bag_slot(src, slot_idx)
			else:
				_refresh_inventory_window()
		elif inv_idx >= 0:
			picked_bag_slot = slot_idx
			AudioManager.play("ui_click")
			_refresh_inventory_window()
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if picked_bag_slot >= 0:
			picked_bag_slot = -1
			_refresh_inventory_window()
		elif inv_idx >= 0:
			_hide_wow_tooltip()
			if vendor_window != null and vendor_window.visible and GameState.get_item_sell_price(it) > 0:
				GameState.sell_item_at(inv_idx)
				_refresh_vendor_money()
				_refresh_vendor_sell_list()
			else:
				GameState.use_or_equip_item(inv_idx)
		get_viewport().set_input_as_handled()


func _refresh_inventory_window() -> void:
	var slots: Array[Dictionary] = GameState.get_bag_slots()
	var used_cnt: int = mini(GameState.BAG_CAPACITY, GameState.inventory.size())
	if bag_title_lbl:
		bag_title_lbl.text = "Рюкзак (%d/%d)" % [used_cnt, GameState.BAG_CAPACITY]
	if br_bag_count_lbl:
		br_bag_count_lbl.text = "Рюкзак %d/%d" % [used_cnt, GameState.BAG_CAPACITY]
	if bag_pickup_hint_lbl:
		bag_pickup_hint_lbl.visible = picked_bag_slot >= 0
	if bag_coin_ctrl:
		bag_coin_ctrl.queue_redraw()
	if br_coin_ctrl:
		br_coin_ctrl.queue_redraw()

	if bag_slot_entries.size() < GameState.BAG_CAPACITY:
		return
	for slot_i in range(GameState.BAG_CAPACITY):
		var entry: Dictionary = bag_slot_entries[slot_i]
		var slot_data: Dictionary = slots[slot_i]
		var it: Dictionary = slot_data.get("item", {}) if not slot_data.is_empty() else {}
		entry["item"] = it
		entry["inv_index"] = int(slot_data.get("inv_index", -1)) if not slot_data.is_empty() else -1
		var p: PanelContainer = entry["panel"]
		var ic: Control = entry["icon_ctrl"]
		var clbl: Label = entry["count_lbl"]
		var hov: bool = bool(entry.get("hovered", false))
		p.add_theme_stylebox_override("panel", WowUIArt.make_slot_box_style(
			String(it.get("rarity", "common")), it.is_empty(), picked_bag_slot == slot_i, hov
		))
		ic.queue_redraw()
		var cnt: int = int(it.get("count", 1))
		clbl.text = str(cnt) if (not it.is_empty() and cnt > 1) else ""



func _toggle_talents() -> void:
	talent_window.visible = not talent_window.visible
	if talent_window.visible:
		_refresh_talent_window()


func _refresh_talent_window() -> void:
	if talent_points_lbl == null or talent_list_vbox == null:
		return
	talent_points_lbl.text = "Свободных очков талантов: %d (получаете по +1 с 2-го ур.)" % GameState.talent_points
	for child in talent_list_vbox.get_children():
		child.queue_free()

	for t in GameState.get_class_talents():
		var tid: String = String(t["id"])
		var cur: int = GameState.get_talent_rank(tid)
		var max_r: int = int(t["max"])

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		talent_list_vbox.add_child(row)

		var info_v := VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_v)

		var name_lbl := Label.new()
		name_lbl.text = "%s (%d/%d)" % [t["name"], cur, max_r]
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.modulate = Color(0.55, 0.95, 0.55) if cur > 0 else Color(0.95, 0.88, 0.55)
		info_v.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = String(t["desc"])
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.modulate = Color(0.82, 0.84, 0.88)
		info_v.add_child(desc_lbl)

		var add_btn := Button.new()
		add_btn.text = "+1"
		add_btn.custom_minimum_size = Vector2(44, 36)
		add_btn.disabled = GameState.talent_points <= 0 or cur >= max_r
		add_btn.focus_mode = Control.FOCUS_NONE
		add_btn.pressed.connect(func() -> void:
			GameState.spend_talent_point(tid)
		)
		row.add_child(add_btn)


func _toggle_menu() -> void:
	menu_window.visible = not menu_window.visible
	if menu_window.visible and menu_load_btn:
		var has_sv: bool = GameState.has_save()
		menu_load_btn.disabled = not has_sv
		menu_load_btn.text = ("Загрузить (%s)" % GameState.get_save_summary()) if has_sv else "Загрузить (нет сохр.)"


func _toggle_char_window() -> void:
	char_window.visible = not char_window.visible
	if char_window.visible:
		_refresh_char_window()


func _refresh_char_window() -> void:
	if char_armor_slot_panel:
		char_armor_slot_panel.add_theme_stylebox_override("panel", WowUIArt.make_slot_box_style(GameState.equipped_armor_rarity, false, false, false))
	if char_weapon_slot_panel:
		char_weapon_slot_panel.add_theme_stylebox_override("panel", WowUIArt.make_slot_box_style(GameState.equipped_weapon_rarity, false, false, false))
	if char_armor_icon:
		char_armor_icon.queue_redraw()
	if char_weapon_icon:
		char_weapon_icon.queue_redraw()
	if char_doll_hero:
		char_doll_hero.queue_redraw()
	if char_stats_rtl == null:
		return
	var st: Dictionary = GameState.get_character_stats()
	var wep_col: String = _rarity_color(GameState.equipped_weapon_rarity).to_html(false)
	var arm_col: String = _rarity_color(GameState.equipped_armor_rarity).to_html(false)
	char_stats_rtl.text = "[color=#ffd866][b]%s — %s (%d ур.)[/b][/color]  |  ОЗ: [color=#66ee66]%d/%d[/color]\n" % [GameState.player_name, GameState.player_class_name, GameState.level, GameState.hp, GameState.max_hp] + \
		"• Сила: [color=#ffe488]%d[/color]   • Ловкость: [color=#ffe488]%d[/color]\n" % [int(st["strength"]), int(st["agility"])] + \
		"• Вынос.: [color=#ffe488]%d[/color]   • Интелл.: [color=#ffe488]%d[/color]\n" % [int(st["stamina"]), int(st["intellect"])] + \
		"• Дух: [color=#ffe488]%d[/color]   • Броня: [color=#aaccff]%d[/color]\n" % [int(st["spirit"]), int(st["armor"])] + \
		"• Урон: [color=#ffd866]%d–%d[/color]   • Крит: [color=#ff9955]%.1f%%[/color]\n" % [int(st["dmg_min"]), int(st["dmg_max"]), float(st["crit_pct"])] + \
		"• Горн. дело: [color=#66d9ff]%d[/color]   • Травнич.: [color=#77ee77]%d[/color]\n" % [GameState.mining_skill, GameState.herbalism_skill] + \
		"Оружие: [color=#%s][%s][/color]\nДоспех: [color=#%s][%s][/color]" % [wep_col, GameState.equipped_weapon_name, arm_col, GameState.equipped_armor_name]


func _toggle_questlog() -> void:
	questlog_window.visible = not questlog_window.visible
	if questlog_window.visible:
		_refresh_questlog()


func _refresh_questlog() -> void:
	if questlog_rtl == null:
		return
	var out: Array[String] = []
	for q_id in GameState.quest_order:
		var q: Dictionary = GameState.quests[q_id]
		var st: String = String(q["state"])
		if st == "locked":
			continue
		var col: String = "#116611" if st == "completed" else ("#884400" if st == "ready_to_turn_in" else "#222244")
		var badge: String = "[Завершено]" if st == "completed" else ("[Готово!]" if st == "ready_to_turn_in" else ("[В процессе]" if st == "active" else "[Доступно]"))
		out.append("[color=%s][b]%s[/b] %s — от: %s[/color]" % [col, q["title"], badge, q["giver"]])
		if st in ["active", "ready_to_turn_in"]:
			var objs: Dictionary = q["objectives"]
			for k in objs.keys():
				var o: Dictionary = objs[k]
				out.append("   • %s: %d/%d" % [o["label"], o["current"], o["required"]])
		elif st == "available":
			out.append("   [i]Подойдите к %s, чтобы взять задание.[/i]" % q["giver"])
	questlog_rtl.text = "\n".join(out)


func _toggle_mute() -> void:
	var m: bool = AudioManager.toggle_mute()
	if mute_btn:
		mute_btn.text = "N×" if m else "N"
		mute_btn.modulate = Color(0.62, 0.62, 0.66) if m else Color.WHITE


func _rarity_color(rarity: String) -> Color:
	return WowUIArt.get_rarity_color(rarity)
