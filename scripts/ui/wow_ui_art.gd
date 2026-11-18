class_name WowUIArt
extends RefCounted

## Процедурная ретро-графика интерфейса в стиле World of Warcraft Classic (2004):
## рамки, иконки предметов и заклинаний, портреты, грифоны, монеты и силуэты экипировки.


static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"poor", "junk":
			return Color(0.62, 0.62, 0.62)
		"uncommon":
			return Color(0.12, 1.0, 0.0)
		"rare":
			return Color(0.0, 0.44, 0.87)
		"epic":
			return Color(0.64, 0.21, 0.93)
		_:
			return Color(0.96, 0.95, 0.92)


static func make_wow_panel_style(
	bg_col: Color = Color(0.075, 0.075, 0.105, 0.93),
	border_col: Color = Color(0.68, 0.56, 0.28, 0.96),
	border_w: int = 2,
	pad: int = 8
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(1, 2)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


static func make_wow_tooltip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.045, 0.08, 0.97)
	sb.border_color = Color(0.56, 0.52, 0.44, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	sb.shadow_size = 6
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func make_slot_box_style(rarity: String = "common", empty: bool = false, selected: bool = false, hovered: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.055, 0.94) if empty else Color(0.11, 0.095, 0.085, 0.98)
	var bcol := Color(0.32, 0.27, 0.20, 0.92)
	var bw := 2
	if not empty:
		if rarity == "uncommon":
			bcol = Color(0.14, 0.95, 0.08, 0.96)
		elif rarity == "rare":
			bcol = Color(0.10, 0.56, 1.0, 0.98)
		elif rarity == "junk" or rarity == "poor":
			bcol = Color(0.46, 0.46, 0.48, 0.90)
		else:
			bcol = Color(0.56, 0.49, 0.36, 0.94)
	if selected:
		bcol = Color(1.0, 0.88, 0.22, 1.0)
		bw = 3
	elif hovered:
		bcol = bcol.lerp(Color(1.0, 0.95, 0.65), 0.55)
	sb.border_color = bcol
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(3)
	return sb


static func draw_item_icon(ctrl: Control, rect: Rect2, item: Dictionary, fallback_cls: String = "warrior") -> void:
	if item.is_empty():
		return
	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y + rect.size.y * 0.5
	var c := Vector2(cx, cy)
	var s: float = minf(rect.size.x, rect.size.y)
	var r: float = s * 0.36

	var id_str: String = String(item.get("id", ""))
	var itype: String = String(item.get("type", "junk"))
	var rar: String = String(item.get("rarity", "common"))

	# Тонкая внутренняя подсветка редкости в слоте (в духе Classic)
	if rar == "uncommon":
		ctrl.draw_rect(rect.grow(-2.0), Color(0.12, 0.85, 0.08, 0.14), true)
	elif rar == "rare":
		ctrl.draw_rect(rect.grow(-2.0), Color(0.08, 0.48, 0.96, 0.18), true)

	if itype == "hearthstone" or id_str == "hearthstone":
		# Камень возвращения со светящейся синей руной-спиралью
		ctrl.draw_circle(c + Vector2(0, 1), r * 0.92, Color(0.42, 0.46, 0.52))
		ctrl.draw_circle(c + Vector2(-r * 0.14, -r * 0.14), r * 0.72, Color(0.56, 0.60, 0.66))
		ctrl.draw_arc(c, r * 0.92, 0.0, TAU, 16, Color(0.22, 0.25, 0.30), 1.5)
		ctrl.draw_arc(c, r * 0.54, 0.2, PI * 1.65, 14, Color(0.32, 0.86, 1.0), 2.4)
		ctrl.draw_arc(c, r * 0.26, PI * 0.5, PI * 2.1, 10, Color(0.70, 0.96, 1.0), 2.0)
		ctrl.draw_circle(c, r * 0.12, Color(0.90, 0.98, 1.0))
		return

	if itype == "potion" or itype == "mana_potion" or itype == "elixir":
		var liq_col := Color(0.86, 0.14, 0.18)
		var glow_col := Color(1.0, 0.48, 0.52)
		if itype == "mana_potion":
			liq_col = Color(0.15, 0.45, 0.95)
			glow_col = Color(0.55, 0.82, 1.0)
		elif itype == "elixir":
			liq_col = Color(0.14, 0.78, 0.34)
			glow_col = Color(0.65, 1.0, 0.55)
		# Колба + пробка + блеск
		ctrl.draw_circle(c + Vector2(0, r * 0.22), r * 0.68, Color(0.75, 0.82, 0.88, 0.35))
		ctrl.draw_circle(c + Vector2(0, r * 0.26), r * 0.58, liq_col)
		ctrl.draw_arc(c + Vector2(0, r * 0.22), r * 0.68, 0.0, TAU, 16, Color(0.85, 0.92, 0.98, 0.7), 1.4)
		ctrl.draw_rect(Rect2(cx - r * 0.24, cy - r * 0.62, r * 0.48, r * 0.44), Color(0.70, 0.78, 0.84, 0.7), true)
		ctrl.draw_rect(Rect2(cx - r * 0.28, cy - r * 0.82, r * 0.56, r * 0.22), Color(0.66, 0.44, 0.22), true)
		ctrl.draw_circle(c + Vector2(-r * 0.22, r * 0.06), r * 0.16, glow_col)
		if itype == "elixir":
			ctrl.draw_rect(Rect2(cx - r * 0.32, cy - r * 0.46, r * 0.64, r * 0.14), Color(0.95, 0.80, 0.25), true)
		return

	if itype == "bandage":
		ctrl.draw_rect(Rect2(cx - r * 0.62, cy - r * 0.42, r * 1.24, r * 0.84), Color(0.88, 0.85, 0.76), true)
		ctrl.draw_rect(Rect2(cx - r * 0.62, cy - r * 0.42, r * 1.24, r * 0.84), Color(0.55, 0.50, 0.42), false, 1.4)
		ctrl.draw_rect(Rect2(cx - r * 0.12, cy - r * 0.28, r * 0.24, r * 0.56), Color(0.85, 0.16, 0.16), true)
		ctrl.draw_rect(Rect2(cx - r * 0.28, cy - r * 0.12, r * 0.56, r * 0.24), Color(0.85, 0.16, 0.16), true)
		return

	if itype == "food":
		ctrl.draw_circle(c + Vector2(r * 0.12, 0), r * 0.66, Color(0.62, 0.28, 0.14))
		ctrl.draw_circle(c + Vector2(r * 0.04, -r * 0.05), r * 0.46, Color(0.78, 0.42, 0.22))
		ctrl.draw_rect(Rect2(cx - r * 0.85, cy + r * 0.12, r * 0.52, r * 0.24), Color(0.92, 0.88, 0.78), true)
		ctrl.draw_circle(c + Vector2(-r * 0.80, r * 0.24), r * 0.16, Color(0.92, 0.88, 0.78))
		return

	if id_str == "peacebloom" or id_str == "silverleaf":
		var stem_col := Color(0.24, 0.68, 0.26)
		var petal_col := Color(0.96, 0.82, 0.22) if id_str == "peacebloom" else Color(0.74, 0.88, 0.98)
		ctrl.draw_line(c + Vector2(0, r * 0.78), c + Vector2(0, -r * 0.15), stem_col, 2.5)
		ctrl.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, r * 0.35), c + Vector2(-r * 0.55, r * 0.10), c + Vector2(-r * 0.20, r * 0.55)
		]), stem_col)
		ctrl.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, r * 0.30), c + Vector2(r * 0.55, r * 0.05), c + Vector2(r * 0.20, r * 0.52)
		]), stem_col)
		for i in range(5):
			var ang: float = float(i) * TAU / 5.0 - PI * 0.5
			ctrl.draw_circle(c + Vector2(cos(ang), sin(ang)) * (r * 0.36) - Vector2(0, r * 0.22), r * 0.23, petal_col)
		ctrl.draw_circle(c - Vector2(0, r * 0.22), r * 0.20, Color(0.96, 0.54, 0.14) if id_str == "peacebloom" else Color(0.96, 0.98, 1.0))
		return

	if id_str == "azure_crystal" or id_str == "copper_ore":
		if id_str == "azure_crystal":
			for off in [Vector2(-r * 0.35, r * 0.12), Vector2(r * 0.32, r * 0.18), Vector2(0, -r * 0.08)]:
				var h: float = r * 0.78 if off.x == 0.0 else r * 0.58
				ctrl.draw_colored_polygon(PackedVector2Array([
					c + off + Vector2(0, -h),
					c + off + Vector2(r * 0.24, 0),
					c + off + Vector2(0, r * 0.45),
					c + off + Vector2(-r * 0.24, 0),
				]), Color(0.28, 0.82, 1.0) if off.x == 0.0 else Color(0.16, 0.58, 0.88))
			ctrl.draw_circle(c + Vector2(0, -r * 0.35), r * 0.14, Color(0.82, 0.98, 1.0))
		else:
			ctrl.draw_circle(c + Vector2(0, r * 0.08), r * 0.68, Color(0.36, 0.33, 0.31))
			ctrl.draw_circle(c + Vector2(-r * 0.22, -r * 0.08), r * 0.22, Color(0.86, 0.48, 0.20))
			ctrl.draw_circle(c + Vector2(r * 0.24, r * 0.14), r * 0.20, Color(0.82, 0.44, 0.18))
			ctrl.draw_circle(c + Vector2(r * 0.05, -r * 0.28), r * 0.15, Color(0.95, 0.65, 0.32))
		return

	if itype == "weapon":
		var wtype := "sword"
		if "bow" in id_str:
			wtype = "bow"
		elif "staff" in id_str or "rod" in id_str:
			wtype = "staff"
		elif "dagger" in id_str or "blade" in id_str or "fang" in id_str:
			wtype = "dagger"
		elif "axe" in id_str or "crusher" in id_str:
			wtype = "greataxe"
		elif id_str == "starter_weapon":
			if fallback_cls == "hunter":
				wtype = "bow"
			elif fallback_cls == "mage":
				wtype = "staff"
			elif fallback_cls == "rogue":
				wtype = "dagger"
		_draw_weapon_art(ctrl, c, r, wtype, rar)
		return

	if itype == "armor":
		var plate := Color(0.42, 0.48, 0.58)
		var trim := Color(0.82, 0.68, 0.28)
		if rar == "rare":
			plate = Color(0.24, 0.42, 0.72)
			trim = Color(0.95, 0.78, 0.30)
		elif rar == "uncommon":
			plate = Color(0.26, 0.48, 0.32)
		ctrl.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-r * 0.68, -r * 0.62),
			c + Vector2(-r * 0.24, -r * 0.72),
			c + Vector2(0, -r * 0.46),
			c + Vector2(r * 0.24, -r * 0.72),
			c + Vector2(r * 0.68, -r * 0.62),
			c + Vector2(r * 0.56, r * 0.16),
			c + Vector2(r * 0.42, r * 0.72),
			c + Vector2(-r * 0.42, r * 0.72),
			c + Vector2(-r * 0.56, r * 0.16),
		]), plate)
		ctrl.draw_line(c + Vector2(-r * 0.48, -r * 0.12), c + Vector2(r * 0.48, -r * 0.12), trim, 2.0)
		ctrl.draw_circle(c + Vector2(0, -r * 0.12), r * 0.14, trim)
		return

	# Трофеи / хлам (свечи, клыки, банданы, чешуя)
	if "candle" in id_str:
		ctrl.draw_rect(Rect2(cx - r * 0.24, cy - r * 0.18, r * 0.48, r * 0.85), Color(0.92, 0.86, 0.66), true)
		ctrl.draw_circle(c + Vector2(0, -r * 0.42), r * 0.24, Color(1.0, 0.65, 0.14))
		ctrl.draw_circle(c + Vector2(0, -r * 0.46), r * 0.12, Color(1.0, 0.95, 0.55))
	elif "fang" in id_str or "pelt" in id_str:
		ctrl.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-r * 0.35, -r * 0.55), c + Vector2(r * 0.18, -r * 0.35), c + Vector2(r * 0.42, r * 0.68), c + Vector2(-r * 0.12, r * 0.05)
		]), Color(0.92, 0.88, 0.76))
	elif "bandana" in id_str:
		ctrl.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-r * 0.72, -r * 0.35), c + Vector2(r * 0.72, -r * 0.35), c + Vector2(0, r * 0.65)
		]), Color(0.76, 0.16, 0.14))
	else:
		ctrl.draw_circle(c, r * 0.56, Color(0.56, 0.48, 0.32))
		ctrl.draw_circle(c, r * 0.30, Color(0.86, 0.74, 0.38))


static func _draw_weapon_art(ctrl: Control, c: Vector2, r: float, wtype: String, rar: String) -> void:
	var steel := Color(0.74, 0.82, 0.90) if rar != "rare" else Color(0.45, 0.78, 1.0)
	if wtype == "bow":
		ctrl.draw_arc(c + Vector2(-r * 0.25, 0), r * 0.82, -PI * 0.42, PI * 0.42, 14, Color(0.68, 0.44, 0.20), 3.0)
		ctrl.draw_line(c + Vector2(-r * 0.02, -r * 0.76), c + Vector2(-r * 0.02, r * 0.76), Color(0.88, 0.86, 0.78), 1.3)
		ctrl.draw_line(c + Vector2(-r * 0.55, r * 0.20), c + Vector2(r * 0.72, -r * 0.25), steel, 2.0)
		return
	if wtype == "staff":
		ctrl.draw_line(c + Vector2(-r * 0.62, r * 0.68), c + Vector2(r * 0.42, -r * 0.38), Color(0.54, 0.34, 0.18), 3.2)
		ctrl.draw_circle(c + Vector2(r * 0.48, -r * 0.45), r * 0.30, Color(0.32, 0.72, 1.0))
		ctrl.draw_circle(c + Vector2(r * 0.44, -r * 0.50), r * 0.12, Color(0.85, 0.98, 1.0))
		return
	if wtype == "greataxe":
		ctrl.draw_line(c + Vector2(-r * 0.64, r * 0.68), c + Vector2(r * 0.56, -r * 0.56), Color(0.48, 0.30, 0.16), 3.4)
		ctrl.draw_colored_polygon(PackedVector2Array([
			c + Vector2(r * 0.05, -r * 0.15), c + Vector2(r * 0.48, -r * 0.74), c + Vector2(r * 0.78, -r * 0.18), c + Vector2(r * 0.42, r * 0.18)
		]), steel)
		return
	# Меч или кинжал
	var thick: float = 2.6 if wtype == "dagger" else 3.4
	ctrl.draw_line(c + Vector2(-r * 0.48, r * 0.48), c + Vector2(r * 0.68, -r * 0.68), steel, thick)
	ctrl.draw_line(c + Vector2(-r * 0.60, r * 0.16), c + Vector2(-r * 0.16, r * 0.60), Color(0.88, 0.70, 0.26), 2.8)
	ctrl.draw_line(c + Vector2(-r * 0.68, r * 0.68), c + Vector2(-r * 0.46, r * 0.46), Color(0.46, 0.28, 0.16), 3.2)


static func draw_ability_icon(ctrl: Control, rect: Rect2, cd_key: String, cls: String) -> void:
	var c := rect.position + rect.size * 0.5
	var r: float = minf(rect.size.x, rect.size.y) * 0.37

	# Фон под иконкой заклинания
	var bg := Color(0.14, 0.12, 0.11, 0.95)
	if cd_key in ["fireball"]:
		bg = Color(0.28, 0.10, 0.05, 0.95)
	elif cd_key in ["frostbolt", "frost_nova", "blink", "arcane_shot"]:
		bg = Color(0.08, 0.15, 0.28, 0.95)
	elif cd_key in ["serpent_sting", "mend_pet"]:
		bg = Color(0.08, 0.22, 0.10, 0.95)
	elif cd_key in ["eviscerate", "heroic_strike", "whirlwind"]:
		bg = Color(0.26, 0.09, 0.09, 0.95)
	ctrl.draw_rect(rect.grow(-2.0), bg, true)

	match cd_key:
		"":
			var w := "sword"
			if cls == "mage":
				w = "staff"
			elif cls == "rogue":
				w = "dagger"
			elif cls == "hunter":
				w = "bow"
			_draw_weapon_art(ctrl, c, r, w, "common")
		"charge":
			ctrl.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.15, -r * 0.78), c + Vector2(r * 0.45, -r * 0.05),
				c + Vector2(0, -r * 0.05), c + Vector2(r * 0.28, r * 0.78),
				c + Vector2(-r * 0.48, r * 0.05), c + Vector2(-r * 0.05, r * 0.05),
			]), Color(1.0, 0.78, 0.18))
		"heroic_strike":
			_draw_weapon_art(ctrl, c, r, "sword", "rare")
			ctrl.draw_arc(c, r * 0.78, -PI * 0.2, PI * 0.7, 12, Color(1.0, 0.55, 0.15), 2.5)
		"whirlwind":
			for a in [0.0, 2.1, 4.2]:
				ctrl.draw_arc(c, r * 0.62, a, a + 1.4, 10, Color(0.86, 0.92, 1.0), 3.0)
		"battle_shout":
			ctrl.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.65, r * 0.12), c + Vector2(r * 0.52, -r * 0.56),
				c + Vector2(r * 0.52, r * 0.58), c + Vector2(-r * 0.65, r * 0.30)
			]), Color(0.95, 0.76, 0.24))
		"fireball":
			ctrl.draw_circle(c, r * 0.62, Color(1.0, 0.38, 0.08))
			ctrl.draw_circle(c - Vector2(r * 0.12, r * 0.12), r * 0.35, Color(1.0, 0.85, 0.25))
		"frostbolt":
			ctrl.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r * 0.78), c + Vector2(r * 0.42, r * 0.10),
				c + Vector2(0, r * 0.78), c + Vector2(-r * 0.42, r * 0.10)
			]), Color(0.45, 0.86, 1.0))
		"frost_nova":
			ctrl.draw_arc(c, r * 0.66, 0.0, TAU, 16, Color(0.55, 0.92, 1.0), 3.0)
			ctrl.draw_circle(c, r * 0.22, Color(0.88, 0.98, 1.0))
		"blink":
			ctrl.draw_arc(c, r * 0.58, 0.0, TAU, 16, Color(0.75, 0.48, 1.0), 2.6)
			ctrl.draw_circle(c + Vector2(r * 0.22, -r * 0.15), r * 0.24, Color(0.92, 0.82, 1.0))
		"sinister_strike":
			_draw_weapon_art(ctrl, c, r, "dagger", "uncommon")
		"eviscerate":
			ctrl.draw_circle(c, r * 0.56, Color(0.72, 0.08, 0.12))
			ctrl.draw_line(c + Vector2(-r * 0.55, r * 0.48), c + Vector2(r * 0.55, -r * 0.52), Color(1.0, 0.32, 0.32), 3.2)
		"stealth":
			ctrl.draw_arc(c, r * 0.62, PI * 0.1, PI * 0.9, 12, Color(0.58, 0.68, 0.96), 2.6)
			ctrl.draw_arc(c, r * 0.62, PI * 1.1, PI * 1.9, 12, Color(0.58, 0.68, 0.96), 2.6)
			ctrl.draw_circle(c, r * 0.20, Color(0.75, 0.85, 1.0))
		"kidney_shot":
			ctrl.draw_circle(c, r * 0.46, Color(0.98, 0.78, 0.22))
			ctrl.draw_arc(c, r * 0.72, 0.3, PI * 1.7, 14, Color(1.0, 0.95, 0.45), 2.0)
		"arcane_shot":
			ctrl.draw_line(c + Vector2(-r * 0.65, r * 0.65), c + Vector2(r * 0.68, -r * 0.68), Color(0.55, 0.86, 1.0), 3.0)
			ctrl.draw_circle(c + Vector2(r * 0.45, -r * 0.45), r * 0.24, Color(0.82, 0.96, 1.0))
		"serpent_sting":
			ctrl.draw_line(c + Vector2(-r * 0.58, r * 0.55), c + Vector2(r * 0.58, -r * 0.55), Color(0.28, 0.96, 0.32), 2.8)
			ctrl.draw_circle(c + Vector2(r * 0.35, -r * 0.35), r * 0.25, Color(0.52, 1.0, 0.32))
		"concussive_shot":
			ctrl.draw_circle(c, r * 0.32, Color(1.0, 0.86, 0.22))
			ctrl.draw_arc(c, r * 0.68, 0.0, TAU, 14, Color(1.0, 0.68, 0.18), 2.0)
		"mend_pet":
			# Волчья лапа + зелёный крест
			ctrl.draw_circle(c + Vector2(0, r * 0.16), r * 0.34, Color(0.45, 0.96, 0.48))
			for pad in [Vector2(-r * 0.38, -r * 0.30), Vector2(0, -r * 0.46), Vector2(r * 0.38, -r * 0.30)]:
				ctrl.draw_circle(c + pad, r * 0.16, Color(0.45, 0.96, 0.48))
		"__item_hp":
			draw_item_icon(ctrl, rect, {"id": "minor_healing_potion", "type": "potion", "rarity": "common"}, cls)
		"__item_util":
			draw_item_icon(ctrl, rect, {"id": "elixir_fortitude", "type": "elixir", "rarity": "uncommon"}, cls)
		"hearthstone":
			draw_item_icon(ctrl, rect, {"id": "hearthstone", "type": "hearthstone", "rarity": "common"}, cls)


static func draw_portrait(ctrl: Control, rect: Rect2, kind: String, sub_kind: String = "", is_elite: bool = false, in_combat: bool = false) -> void:
	var c := rect.position + rect.size * 0.5
	var rad: float = minf(rect.size.x, rect.size.y) * 0.45
	ctrl.draw_circle(c, rad, Color(0.11, 0.10, 0.14))

	# Силуэт лица / бюста внутри портрета
	if kind == "pet" or sub_kind == "wolf":
		ctrl.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-rad * 0.50, rad * 0.40), c + Vector2(-rad * 0.38, -rad * 0.56),
			c + Vector2(-rad * 0.12, -rad * 0.26), c + Vector2(rad * 0.12, -rad * 0.26),
			c + Vector2(rad * 0.38, -rad * 0.56), c + Vector2(rad * 0.50, rad * 0.40),
		]), Color(0.56, 0.44, 0.30))
		ctrl.draw_circle(c + Vector2(-rad * 0.18, -rad * 0.05), rad * 0.10, Color(0.35, 0.98, 0.45) if kind == "pet" else Color(1.0, 0.65, 0.15))
		ctrl.draw_circle(c + Vector2(rad * 0.18, -rad * 0.05), rad * 0.10, Color(0.35, 0.98, 0.45) if kind == "pet" else Color(1.0, 0.65, 0.15))
	elif sub_kind in ["kobold", "kobold_geomancer", "boss_crusher"]:
		var fur := Color(0.58, 0.32, 0.18) if sub_kind != "boss_crusher" else Color(0.45, 0.18, 0.15)
		ctrl.draw_circle(c + Vector2(0, rad * 0.10), rad * 0.48, fur)
		ctrl.draw_rect(Rect2(c.x - rad * 0.12, c.y - rad * 0.66, rad * 0.24, rad * 0.40), Color(0.95, 0.90, 0.72), true)
		ctrl.draw_circle(c + Vector2(0, -rad * 0.72), rad * 0.16, Color(1.0, 0.68, 0.15))
		ctrl.draw_circle(c + Vector2(-rad * 0.18, rad * 0.04), rad * 0.10, Color(1.0, 0.22, 0.15))
		ctrl.draw_circle(c + Vector2(rad * 0.18, rad * 0.04), rad * 0.10, Color(1.0, 0.22, 0.15))
	elif sub_kind == "murloc":
		ctrl.draw_circle(c + Vector2(0, rad * 0.08), rad * 0.50, Color(0.22, 0.66, 0.54))
		ctrl.draw_circle(c + Vector2(-rad * 0.20, -rad * 0.02), rad * 0.14, Color(1.0, 0.92, 0.35))
		ctrl.draw_circle(c + Vector2(rad * 0.20, -rad * 0.02), rad * 0.14, Color(1.0, 0.92, 0.35))
	else:
		# Гуманоидный портрет с цветовой темой класса/NPC
		var armor := Color(0.32, 0.40, 0.56)
		var helm := Color(0.58, 0.62, 0.70)
		var eyes := Color(0.25, 0.65, 1.0)
		if sub_kind == "mage":
			armor = Color(0.22, 0.36, 0.76)
			helm = Color(0.18, 0.28, 0.65)
			eyes = Color(0.45, 0.92, 1.0)
		elif sub_kind == "rogue":
			armor = Color(0.28, 0.22, 0.30)
			helm = Color(0.20, 0.18, 0.24)
			eyes = Color(1.0, 0.85, 0.25)
		elif sub_kind == "hunter" or kind == "npc":
			armor = Color(0.22, 0.44, 0.24)
			helm = Color(0.18, 0.38, 0.20)
			eyes = Color(0.45, 0.95, 0.48)
		elif sub_kind == "bandit":
			armor = Color(0.48, 0.18, 0.16)
			helm = Color(0.68, 0.14, 0.14)
			eyes = Color(1.0, 0.45, 0.35)
		ctrl.draw_circle(c + Vector2(0, rad * 0.48), rad * 0.55, armor)
		ctrl.draw_circle(c + Vector2(0, -rad * 0.05), rad * 0.38, Color(0.88, 0.72, 0.58))
		ctrl.draw_arc(c + Vector2(0, -rad * 0.16), rad * 0.40, PI * 0.95, PI * 2.05, 14, helm, rad * 0.28)
		ctrl.draw_circle(c + Vector2(-rad * 0.14, -rad * 0.06), rad * 0.07, eyes)
		ctrl.draw_circle(c + Vector2(rad * 0.14, -rad * 0.06), rad * 0.07, eyes)

	# Рамка портрета (золото, красное свечение в бою, крыло дракона для Элиты)
	var rim_col := Color(0.95, 0.26, 0.20) if in_combat else Color(0.84, 0.68, 0.26)
	ctrl.draw_arc(c, rad, 0.0, TAU, 28, rim_col, 3.0)
	ctrl.draw_arc(c, rad - 2.2, 0.0, TAU, 28, Color(0.24, 0.18, 0.08), 1.2)
	if is_elite:
		ctrl.draw_arc(c, rad + 4.0, -PI * 0.72, PI * 0.72, 24, Color(1.0, 0.84, 0.20), 3.4)
		ctrl.draw_colored_polygon(PackedVector2Array([
			c + Vector2(rad + 2.0, -rad * 0.70), c + Vector2(rad + 10.0, -rad * 0.88), c + Vector2(rad + 5.0, -rad * 0.30)
		]), Color(1.0, 0.86, 0.24))


static func draw_gryphon_endcap(ctrl: Control, rect: Rect2, facing_right: bool) -> void:
	var c := rect.position + rect.size * 0.5
	var s := minf(rect.size.x, rect.size.y) * 0.46
	var dir: float = 1.0 if facing_right else -1.0
	var stone := Color(0.56, 0.58, 0.64)
	var hi := Color(0.80, 0.82, 0.88)
	var rim := Color(0.32, 0.30, 0.28)
	# Крыло + львиная/орлиная голова в стиле Classic endcaps
	ctrl.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-dir * s * 0.85, s * 0.80),
		c + Vector2(-dir * s * 0.90, -s * 0.65),
		c + Vector2(-dir * s * 0.10, -s * 0.85),
		c + Vector2(dir * s * 0.25, -s * 0.10),
		c + Vector2(dir * s * 0.55, s * 0.80),
	]), stone)
	ctrl.draw_circle(c + Vector2(dir * s * 0.22, -s * 0.24), s * 0.34, hi)
	ctrl.draw_colored_polygon(PackedVector2Array([
		c + Vector2(dir * s * 0.45, -s * 0.32),
		c + Vector2(dir * s * 0.88, -s * 0.14),
		c + Vector2(dir * s * 0.45, s * 0.02),
	]), Color(0.92, 0.78, 0.30))
	ctrl.draw_line(c + Vector2(-dir * s * 0.75, -s * 0.30), c + Vector2(-dir * s * 0.10, -s * 0.48), hi, 2.0)
	ctrl.draw_rect(Rect2(c.x - s * 0.82, c.y + s * 0.70, s * 1.64, s * 0.18), rim, true)


static func draw_coin_strip(ctrl: Control, rect: Rect2, copper_total: int) -> void:
	var gold: int = copper_total / 10000
	var silver: int = (copper_total % 10000) / 100
	var cop: int = copper_total % 100
	var font: Font = ThemeDB.fallback_font
	var groups: Array[Dictionary] = []
	if gold > 0:
		groups.append({"val": str(gold), "col": Color(0.98, 0.82, 0.18)})
	if silver > 0 or gold > 0:
		groups.append({"val": str(silver), "col": Color(0.80, 0.84, 0.90)})
	groups.append({"val": str(cop), "col": Color(0.84, 0.48, 0.24)})

	var cursor_x: float = rect.position.x + rect.size.x - 6.0
	var mid_y: float = rect.position.y + rect.size.y * 0.5
	for idx in range(groups.size() - 1, -1, -1):
		var g: Dictionary = groups[idx]
		var txt: String = String(g["val"])
		var mcol: Color = g["col"]
		cursor_x -= 7.0
		ctrl.draw_circle(Vector2(cursor_x, mid_y), 5.5, mcol)
		ctrl.draw_arc(Vector2(cursor_x, mid_y), 5.5, 0.0, TAU, 12, Color(0.18, 0.14, 0.08), 1.2)
		ctrl.draw_circle(Vector2(cursor_x - 1.5, mid_y - 1.5), 1.8, Color(1.0, 1.0, 1.0, 0.6))
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		cursor_x -= (tw + 8.0)
		ctrl.draw_string(font, Vector2(cursor_x, mid_y + 4.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.96, 0.94, 0.86))
		cursor_x -= 6.0


static func draw_backpack_medallion(ctrl: Control, rect: Rect2) -> void:
	var c := rect.position + rect.size * 0.5
	var r: float = minf(rect.size.x, rect.size.y) * 0.44
	ctrl.draw_circle(c, r, Color(0.24, 0.16, 0.09))
	ctrl.draw_rect(Rect2(c.x - r * 0.52, c.y - r * 0.25, r * 1.04, r * 0.84), Color(0.52, 0.34, 0.18), true)
	ctrl.draw_arc(c + Vector2(0, -r * 0.22), r * 0.44, PI, TAU, 10, Color(0.62, 0.42, 0.22), 2.5)
	ctrl.draw_rect(Rect2(c.x - r * 0.55, c.y - r * 0.26, r * 1.10, r * 0.34), Color(0.64, 0.44, 0.22), true)
	ctrl.draw_rect(Rect2(c.x - r * 0.14, c.y - r * 0.02, r * 0.28, r * 0.24), Color(0.92, 0.76, 0.24), true)
	ctrl.draw_arc(c, r, 0.0, TAU, 20, Color(0.84, 0.68, 0.28), 2.2)


static func draw_paperdoll_hero(ctrl: Control, rect: Rect2, cls: String, armor_tier: int, weapon_id: String) -> void:
	var c := rect.position + rect.size * 0.5
	var h: float = rect.size.y
	# Пьедестал и фоновая рамка куклы персонажа
	ctrl.draw_rect(rect.grow(-2.0), Color(0.06, 0.06, 0.09, 0.88), true)
	ctrl.draw_rect(rect.grow(-2.0), Color(0.38, 0.32, 0.20, 0.75), false, 1.5)
	ctrl.draw_circle(Vector2(c.x, c.y + h * 0.34), rect.size.x * 0.34, Color(0.22, 0.20, 0.18, 0.75))

	var body_col := Color(0.32, 0.38, 0.50)
	var accent := Color(0.82, 0.66, 0.26)
	if cls == "mage":
		body_col = Color(0.22, 0.36, 0.76)
	elif cls == "rogue":
		body_col = Color(0.28, 0.22, 0.32)
	elif cls == "hunter":
		body_col = Color(0.22, 0.44, 0.22)
	if armor_tier >= 2:
		body_col = body_col.lerp(Color(0.42, 0.20, 0.24), 0.45)
		accent = Color(0.96, 0.78, 0.26)

	# Ноги
	ctrl.draw_rect(Rect2(c.x - 14, c.y + 8, 10, 32), Color(0.20, 0.19, 0.22), true)
	ctrl.draw_rect(Rect2(c.x + 4, c.y + 8, 10, 32), Color(0.20, 0.19, 0.22), true)
	# Торс
	ctrl.draw_rect(Rect2(c.x - 17, c.y - 24, 34, 34), body_col, true)
	ctrl.draw_rect(Rect2(c.x - 17, c.y + 2, 34, 6), accent, true)
	if armor_tier >= 1:
		ctrl.draw_circle(Vector2(c.x - 20, c.y - 18), 9.0, accent)
		ctrl.draw_circle(Vector2(c.x + 20, c.y - 18), 9.0, accent)
	# Голова
	ctrl.draw_circle(Vector2(c.x, c.y - 36), 11.0, Color(0.88, 0.72, 0.58))
	ctrl.draw_arc(Vector2(c.x, c.y - 40), 11.5, PI, TAU, 12, body_col.lightened(0.18), 6.0)
	# Оружие в правой руке силуэта
	_draw_weapon_art(ctrl, Vector2(c.x + 28, c.y - 6), 18.0, weapon_id, "rare" if armor_tier >= 2 else "common")


static func format_item_tooltip(item: Dictionary, sell_price: int, vendor_open: bool, slot_hint: bool = true) -> String:
	var rar: String = String(item.get("rarity", "common"))
	var col_hex: String = get_rarity_color(rar).to_html(false)
	var itype: String = String(item.get("type", "junk"))
	var type_label := "Хлам"
	match itype:
		"hearthstone":
			type_label = "Особый предмет"
		"weapon":
			type_label = "Правая рука (Оружие)"
		"armor":
			type_label = "Грудь (Доспех)"
		"potion", "mana_potion", "elixir":
			type_label = "Зелье / Алхимия"
		"bandage":
			type_label = "Первая помощь"
		"food":
			type_label = "Еда и припасы"
		"material":
			type_label = "Ремесленный ресурс"

	var lines: Array[String] = []
	lines.append("[color=#%s][b]%s[/b][/color]" % [col_hex, String(item.get("name", "Предмет"))])
	lines.append("[color=#b8bcc8]%s[/color]" % type_label)

	var bonus: int = int(item.get("bonus", 0))
	if itype == "weapon" and bonus > 0:
		lines.append("[color=#1eff00]Если надет: +%d к урону атак и заклинаний[/color]" % bonus)
	elif itype == "armor" and bonus > 0:
		lines.append("[color=#1eff00]Если надет: +%d к макс. здоровью и +%d к броне[/color]" % [bonus, bonus * 2])

	var desc: String = String(item.get("desc", ""))
	if desc != "":
		if itype in ["potion", "mana_potion", "elixir", "bandage", "food", "hearthstone"]:
			lines.append("[color=#1eff00]Использование: %s[/color]" % desc)
		else:
			lines.append("[color=#ffd24a]%s[/color]" % desc)

	if sell_price > 0:
		var gold: int = sell_price / 10000
		var silver: int = (sell_price % 10000) / 100
		var cop: int = sell_price % 100
		var mparts: Array[String] = []
		if gold > 0:
			mparts.append("[color=#ffd700]%dз[/color]" % gold)
		if silver > 0 or gold > 0:
			mparts.append("[color=#d8dde6]%dс[/color]" % silver)
		mparts.append("[color=#dd8855]%dм[/color]" % cop)
		lines.append("Цена продажи: %s" % " ".join(mparts))

	if slot_hint:
		if vendor_open and sell_price > 0:
			lines.append("[color=#66d9ff]ПКМ: продать торговцу | ЛКМ: перенести[/color]")
		elif itype in ["potion", "mana_potion", "elixir", "bandage", "food", "hearthstone", "weapon", "armor"]:
			lines.append("[color=#66d9ff]ПКМ: применить / надеть | ЛКМ: перенести[/color]")
		else:
			lines.append("[color=#9aa0a8]ЛКМ: переставить в сумке[/color]")

	return "\n".join(lines)
