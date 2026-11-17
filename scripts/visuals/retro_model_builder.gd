class_name RetroModelBuilder
extends RefCounted

static var _shaded_mat_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func make_retro_material(color: Color, roughness: float = 0.85, metallic: float = 0.08, emission: Color = Color.BLACK, emission_energy: float = 0.0, pattern: String = "") -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if pattern != "":
		mat.albedo_texture = _get_pattern_texture(pattern)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


static func _get_shaded_mat(base_mat: Material) -> Material:
	if not (base_mat is StandardMaterial3D):
		return base_mat
	var std := base_mat as StandardMaterial3D
	if std.vertex_color_use_as_albedo:
		return std
	var key: int = std.get_instance_id()
	if _shaded_mat_cache.has(key):
		return _shaded_mat_cache[key]
	var dup := std.duplicate() as StandardMaterial3D
	dup.vertex_color_use_as_albedo = true
	_shaded_mat_cache[key] = dup
	return dup


static func _get_pattern_texture(pattern: String) -> ImageTexture:
	if _tex_cache.has(pattern):
		return _tex_cache[pattern]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pattern)
	for y in range(32):
		for x in range(32):
			var v: float = 0.94 + rng.randf_range(-0.06, 0.06)
			if pattern == "armor":
				# Лёгкая фактура кованой брони и заклёпок по краям
				if y == 2 or y == 29 or x == 2 or x == 29:
					v *= 0.82
				elif (x == 4 or x == 27) and (y % 8 == 4):
					v = 1.12
				else:
					v *= 0.96 + 0.06 * sin(float(y) * 0.4)
			elif pattern == "cloth":
				v *= 0.94 + 0.08 * sin(float(x) * 0.65)
			elif pattern == "fur":
				v *= 0.90 + 0.14 * sin(float(x) * 1.1 + float(y) * 0.35)
			elif pattern == "scales":
				var row: int = y / 4
				var sx: int = (x + (row % 2) * 3) % 6
				if y % 4 == 0 or sx == 0:
					v *= 0.78
			elif pattern == "stone":
				var row_s: int = y / 8
				var off: int = (row_s % 2) * 8
				if y % 8 == 0 or (x + off) % 16 == 0:
					v *= 0.72
			elif pattern == "wood":
				v *= 0.88 + 0.14 * sin(float(x) * 0.85 + sin(float(y) * 0.25))
				if x % 8 == 0:
					v *= 0.82
			elif pattern == "roof":
				var row_r: int = y / 6
				var off_r: int = (row_r % 2) * 4
				if y % 6 == 0:
					v *= 0.70
				elif (x + off_r) % 8 == 0:
					v *= 0.82
			elif pattern == "water":
				v = 0.88 + 0.14 * sin(float(x) * 0.39 + float(y) * 0.39) * cos(float(y) * 0.39)
			v = clampf(v, 0.45, 1.15)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[pattern] = tex
	return tex


static func _make_box_mesh(size: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, name_str: String = "Part") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_str
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


static func _make_prism_or_cyl(radius_top: float, radius_bot: float, height: float, sides: int, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, name_str: String = "Part") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_str
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius_top
	cyl.bottom_radius = radius_bot
	cyl.height = height
	cyl.radial_segments = sides
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = mat
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


# Создаёт низкополигональную объёмную деталь по набору сечений (колец) с запечённой вертексной тенью
static func _make_lofted_mesh(rings: Array, sides: int, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, name_str: String = "Part", cap_ends: bool = true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring_pts: Array = []
	var ring_cols: Array = []
	for r_dict in rings:
		var r: Dictionary = r_dict
		var y: float = float(r.get("y", 0.0))
		var rx: float = maxf(0.004, float(r.get("rx", 0.1)))
		var rz: float = maxf(0.004, float(r.get("rz", rx)))
		var ox: float = float(r.get("ox", 0.0))
		var oz: float = float(r.get("oz", 0.0))
		var sh: float = float(r.get("shade", 1.0))
		var pts: Array[Vector3] = []
		for i in range(sides):
			var ang: float = (float(i) / float(sides)) * TAU + (PI / float(sides))
			pts.append(Vector3(ox + cos(ang) * rx, y, oz + sin(ang) * rz))
		ring_pts.append(pts)
		ring_cols.append(Color(sh, sh, sh, 1.0))

	for ri in range(ring_pts.size() - 1):
		var b_pts: Array[Vector3] = ring_pts[ri]
		var t_pts: Array[Vector3] = ring_pts[ri + 1]
		var bc: Color = ring_cols[ri]
		var tc: Color = ring_cols[ri + 1]
		var v0_uv: float = float(ri) / float(ring_pts.size() - 1)
		var v1_uv: float = float(ri + 1) / float(ring_pts.size() - 1)
		for i in range(sides):
			var ni: int = (i + 1) % sides
			var u0: float = float(i) / float(sides)
			var u1: float = float(i + 1) / float(sides)
			var b0: Vector3 = b_pts[i]
			var b1: Vector3 = b_pts[ni]
			var t0: Vector3 = t_pts[i]
			var t1: Vector3 = t_pts[ni]
			# По часовой стрелке снаружи (проверено в Godot 4)
			st.set_color(bc); st.set_uv(Vector2(u0, v0_uv)); st.add_vertex(b0)
			st.set_color(tc); st.set_uv(Vector2(u1, v1_uv)); st.add_vertex(t1)
			st.set_color(tc); st.set_uv(Vector2(u0, v1_uv)); st.add_vertex(t0)

			st.set_color(bc); st.set_uv(Vector2(u0, v0_uv)); st.add_vertex(b0)
			st.set_color(bc); st.set_uv(Vector2(u1, v0_uv)); st.add_vertex(b1)
			st.set_color(tc); st.set_uv(Vector2(u1, v1_uv)); st.add_vertex(t1)

	if cap_ends and ring_pts.size() >= 2:
		var bot_pts: Array[Vector3] = ring_pts[0]
		var bot_r: Dictionary = rings[0]
		var bot_c := Vector3(float(bot_r.get("ox", 0.0)), float(bot_r.get("y", 0.0)), float(bot_r.get("oz", 0.0)))
		var bc0: Color = ring_cols[0]
		for i in range(sides):
			var ni: int = (i + 1) % sides
			st.set_color(bc0); st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(bot_c)
			st.set_color(bc0); st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(bot_pts[ni])
			st.set_color(bc0); st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(bot_pts[i])

		var top_pts: Array[Vector3] = ring_pts[ring_pts.size() - 1]
		var top_r: Dictionary = rings[rings.size() - 1]
		var top_c := Vector3(float(top_r.get("ox", 0.0)), float(top_r.get("y", 0.0)), float(top_r.get("oz", 0.0)))
		var tc0: Color = ring_cols[ring_cols.size() - 1]
		for i in range(sides):
			var ni: int = (i + 1) % sides
			st.set_color(tc0); st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(top_c)
			st.set_color(tc0); st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(top_pts[i])
			st.set_color(tc0); st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(top_pts[ni])

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = name_str
	mi.mesh = st.commit()
	mi.material_override = _get_shaded_mat(mat)
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


static func _make_pauldron(mat_main: Material, mat_trim: Material, side_sign: float, name_str: String) -> Node3D:
	var p := Node3D.new()
	p.name = name_str
	# Крупный многослойный наплечник в духе Warcraft 2004
	p.add_child(_make_lofted_mesh([
		{"y": -0.10, "rx": 0.16, "rz": 0.18, "ox": side_sign * 0.04, "shade": 0.78},
		{"y": 0.02, "rx": 0.17, "rz": 0.19, "ox": side_sign * 0.02, "shade": 1.0},
		{"y": 0.11, "rx": 0.12, "rz": 0.14, "ox": -side_sign * 0.02, "shade": 1.08},
	], 8, mat_main, Vector3.ZERO, Vector3(0, 0, -side_sign * 18.0), "Dome"))
	p.add_child(_make_lofted_mesh([
		{"y": -0.12, "rx": 0.175, "rz": 0.195, "ox": side_sign * 0.045, "shade": 0.85},
		{"y": -0.06, "rx": 0.178, "rz": 0.198, "ox": side_sign * 0.035, "shade": 1.08},
	], 8, mat_trim, Vector3.ZERO, Vector3(0, 0, -side_sign * 18.0), "Rim"))
	return p


static func build_humanoid(config: Dictionary) -> Node3D:
	var scale_factor: float = float(config.get("scale", 1.0))
	var archetype: String = String(config.get("archetype", "warrior"))
	var armor_color: Color = config.get("armor_color", Color(0.24, 0.34, 0.56))
	var accent_color: Color = config.get("accent_color", Color(0.76, 0.60, 0.24))
	var skin_color: Color = config.get("skin_color", Color(0.86, 0.68, 0.54))
	var pants_color: Color = config.get("pants_color", Color(0.20, 0.18, 0.17))
	var cape_color: Color = config.get("cape_color", Color(0.58, 0.12, 0.12))
	var hair_color: Color = config.get("hair_color", Color(0.24, 0.15, 0.09))
	var eye_color: Color = config.get("eye_color", Color(0.12, 0.14, 0.22))
	var weapon_type: String = String(config.get("weapon_type", "greatsword"))
	var has_cape: bool = bool(config.get("has_cape", true))
	var has_candle: bool = bool(config.get("has_candle", false))
	var has_shield: bool = bool(config.get("has_shield", false))
	var has_offhand_dagger: bool = bool(config.get("has_offhand_dagger", false))

	var armor_pat: String = "scales" if archetype == "murloc" else ("cloth" if archetype in ["mage", "rogue", "bandit"] else "armor")
	var mat_armor := make_retro_material(armor_color, 0.68 if armor_pat == "armor" else 0.88, 0.32 if armor_pat == "armor" else 0.06, Color.BLACK, 0.0, armor_pat)
	var mat_accent := make_retro_material(accent_color, 0.45, 0.55, Color.BLACK, 0.0, "armor")
	var mat_skin := make_retro_material(skin_color, 0.84, 0.02, Color.BLACK, 0.0, "scales" if archetype == "murloc" else "")
	var mat_pants := make_retro_material(pants_color, 0.88, 0.05, Color.BLACK, 0.0, "cloth")
	var mat_boots := make_retro_material(pants_color.darkened(0.25), 0.76, 0.15)
	var mat_cape := make_retro_material(cape_color, 0.90, 0.0, Color.BLACK, 0.0, "cloth")
	var mat_hair := make_retro_material(hair_color, 0.90, 0.05, Color.BLACK, 0.0, "fur")
	var mat_eye := make_retro_material(eye_color, 0.35, 0.0, eye_color if eye_color.v > 0.55 else Color.BLACK, 1.5 if eye_color.v > 0.55 else 0.0)
	var mat_steel := make_retro_material(Color(0.74, 0.78, 0.84), 0.32, 0.78)
	var mat_wood := make_retro_material(Color(0.42, 0.26, 0.13), 0.90, 0.02, Color.BLACK, 0.0, "wood")

	var rig := Node3D.new()
	rig.name = "HumanoidRig"
	rig.scale = Vector3.ONE * scale_factor

	var root_pivot := Node3D.new()
	root_pivot.name = "RootPivot"
	rig.add_child(root_pivot)

	# Двухсоставные ноги с коленом и расклешёнными сапогами в духе WoW 2004
	for leg_side in [
		{"name": "LegLPivot", "knee": "KneeLPivot", "x": -0.15},
		{"name": "LegRPivot", "knee": "KneeRPivot", "x": 0.15},
	]:
		var leg := Node3D.new()
		leg.name = leg_side["name"]
		leg.position = Vector3(float(leg_side["x"]), 0.78, 0.0)
		root_pivot.add_child(leg)
		leg.add_child(_make_lofted_mesh([
			{"y": -0.38, "rx": 0.09, "rz": 0.10, "shade": 0.78},
			{"y": -0.18, "rx": 0.115, "rz": 0.12, "shade": 0.94},
			{"y": 0.02, "rx": 0.125, "rz": 0.13, "shade": 1.0},
		], 8, mat_pants, Vector3.ZERO, Vector3.ZERO, "Thigh"))

		var knee := Node3D.new()
		knee.name = leg_side["knee"]
		knee.position = Vector3(0.0, -0.37, 0.0)
		leg.add_child(knee)
		# Наколенник
		knee.add_child(_make_lofted_mesh([
			{"y": -0.05, "rx": 0.095, "rz": 0.105, "shade": 0.85},
			{"y": 0.04, "rx": 0.105, "rz": 0.115, "oz": -0.02, "shade": 1.05},
		], 6, mat_accent, Vector3.ZERO, Vector3.ZERO, "KneePad"))
		# Сапог с отворотом и носком
		knee.add_child(_make_lofted_mesh([
			{"y": -0.41, "rx": 0.115, "rz": 0.155, "oz": -0.04, "shade": 0.72},
			{"y": -0.28, "rx": 0.095, "rz": 0.115, "oz": -0.01, "shade": 0.88},
			{"y": -0.06, "rx": 0.12, "rz": 0.13, "shade": 1.02},
		], 8, mat_boots, Vector3.ZERO, Vector3.ZERO, "Boot"))
		knee.add_child(_make_lofted_mesh([
			{"y": -0.10, "rx": 0.128, "rz": 0.138, "shade": 0.88},
			{"y": -0.04, "rx": 0.132, "rz": 0.142, "shade": 1.08},
		], 8, mat_accent, Vector3.ZERO, Vector3.ZERO, "BootCuff"))

	# V-образный мускулистый торс + талия + табард
	var torso_pivot := Node3D.new()
	torso_pivot.name = "TorsoPivot"
	torso_pivot.position = Vector3(0.0, 0.80, 0.0)
	root_pivot.add_child(torso_pivot)

	# Таз / пояс
	torso_pivot.add_child(_make_lofted_mesh([
		{"y": -0.04, "rx": 0.24, "rz": 0.16, "shade": 0.76},
		{"y": 0.10, "rx": 0.23, "rz": 0.15, "shade": 0.95},
	], 8, mat_boots, Vector3.ZERO, Vector3.ZERO, "PelvisBelt"))
	torso_pivot.add_child(_make_lofted_mesh([
		{"y": -0.01, "rx": 0.09, "rz": 0.03, "shade": 0.85},
		{"y": 0.09, "rx": 0.09, "rz": 0.03, "shade": 1.10},
	], 6, mat_accent, Vector3(0, 0.01, -0.15), Vector3.ZERO, "Buckle"))

	# Скульптурная грудь (широкие плечи, узкая талия)
	torso_pivot.add_child(_make_lofted_mesh([
		{"y": 0.08, "rx": 0.22, "rz": 0.14, "shade": 0.78},
		{"y": 0.28, "rx": 0.27, "rz": 0.18, "oz": -0.02, "shade": 0.94},
		{"y": 0.49, "rx": 0.33, "rz": 0.20, "oz": -0.03, "shade": 1.04},
		{"y": 0.60, "rx": 0.23, "rz": 0.15, "shade": 0.98},
	], 8, mat_armor, Vector3.ZERO, Vector3.ZERO, "Chest"))

	# Нагрудный табард
	torso_pivot.add_child(_make_lofted_mesh([
		{"y": -0.08, "rx": 0.14, "rz": 0.025, "oz": -0.01, "shade": 0.76},
		{"y": 0.22, "rx": 0.15, "rz": 0.025, "oz": -0.02, "shade": 0.95},
		{"y": 0.48, "rx": 0.17, "rz": 0.025, "oz": -0.02, "shade": 1.05},
	], 4, mat_accent if archetype == "guard" else mat_cape, Vector3(0, 0.02, -0.185), Vector3.ZERO, "Tabard"))

	# Двухсегментный трапециевидный плащ
	if has_cape:
		var cape_pivot := Node3D.new()
		cape_pivot.name = "CapePivot"
		cape_pivot.position = Vector3(0, 0.56, 0.17)
		torso_pivot.add_child(cape_pivot)
		cape_pivot.add_child(_make_lofted_mesh([
			{"y": -0.44, "rx": 0.26, "rz": 0.025, "oz": 0.04, "shade": 0.84},
			{"y": 0.0, "rx": 0.21, "rz": 0.025, "shade": 1.02},
		], 6, mat_cape, Vector3.ZERO, Vector3.ZERO, "CapeUpper"))
		var cape_low := Node3D.new()
		cape_low.name = "CapeLowerPivot"
		cape_low.position = Vector3(0, -0.44, 0.04)
		cape_pivot.add_child(cape_low)
		cape_low.add_child(_make_lofted_mesh([
			{"y": -0.46, "rx": 0.31, "rz": 0.022, "oz": 0.04, "shade": 0.68},
			{"y": 0.0, "rx": 0.26, "rz": 0.025, "shade": 0.86},
		], 6, mat_cape, Vector3.ZERO, Vector3.ZERO, "CapeLower"))

	# Скульптурная голова (многогранник: подбородок, скулы, лоб, макушка)
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, 0.61, 0.0)
	torso_pivot.add_child(head_pivot)

	head_pivot.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": 0.095, "rz": 0.095, "shade": 0.72},
		{"y": 0.08, "rx": 0.145, "rz": 0.155, "oz": -0.02, "shade": 0.86},
		{"y": 0.23, "rx": 0.175, "rz": 0.185, "oz": -0.01, "shade": 1.00},
		{"y": 0.34, "rx": 0.155, "rz": 0.165, "oz": 0.01, "shade": 1.04},
		{"y": 0.40, "rx": 0.085, "rz": 0.095, "oz": 0.02, "shade": 1.06},
	], 8, mat_skin, Vector3.ZERO, Vector3.ZERO, "Head"))

	# Глаза и нос
	head_pivot.add_child(_make_box_mesh(Vector3(0.055, 0.04, 0.04), mat_eye, Vector3(-0.075, 0.23, -0.165), Vector3.ZERO, "EyeL"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.055, 0.04, 0.04), mat_eye, Vector3(0.075, 0.23, -0.165), Vector3.ZERO, "EyeR"))

	if archetype == "kobold":
		var mat_ear := make_retro_material(skin_color.darkened(0.14), 0.85, 0.02)
		head_pivot.add_child(_make_lofted_mesh([
			{"y": -0.06, "rx": 0.055, "rz": 0.11, "oz": -0.08, "shade": 0.85},
			{"y": 0.06, "rx": 0.085, "rz": 0.13, "oz": -0.02, "shade": 1.0},
		], 6, mat_skin, Vector3(0, 0.15, -0.14), Vector3(12, 0, 0), "Snout"))
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.055, "rz": 0.03, "shade": 0.82},
			{"y": 0.18, "rx": 0.015, "rz": 0.015, "shade": 1.05},
		], 5, mat_ear, Vector3(-0.16, 0.25, 0.02), Vector3(0, 0, 34), "EarL"))
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.055, "rz": 0.03, "shade": 0.82},
			{"y": 0.18, "rx": 0.015, "rz": 0.015, "shade": 1.05},
		], 5, mat_ear, Vector3(0.16, 0.25, 0.02), Vector3(0, 0, -34), "EarR"))
	elif archetype == "mage":
		var mat_hat := make_retro_material(armor_color.darkened(0.16), 0.84, 0.05, Color.BLACK, 0.0, "cloth")
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.31, "rx": 0.32, "rz": 0.32, "shade": 0.82},
			{"y": 0.35, "rx": 0.29, "rz": 0.29, "shade": 0.98},
			{"y": 0.56, "rx": 0.14, "rz": 0.14, "oz": 0.03, "shade": 1.04},
			{"y": 0.82, "rx": 0.02, "rz": 0.02, "oz": 0.09, "shade": 1.08},
		], 8, mat_hat, Vector3.ZERO, Vector3.ZERO, "WizardHat"))
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.06, "rx": 0.16, "rz": 0.10, "shade": 0.78},
			{"y": 0.26, "rx": 0.18, "rz": 0.11, "shade": 1.0},
		], 6, mat_hair, Vector3(0, 0, 0.10), Vector3.ZERO, "HairBack"))
	elif archetype == "rogue" or archetype == "bandit":
		var mat_hood := make_retro_material(armor_color.darkened(0.18), 0.88, 0.02, Color.BLACK, 0.0, "cloth")
		var mat_mask := make_retro_material(cape_color, 0.88, 0.02, Color.BLACK, 0.0, "cloth")
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.16, "rx": 0.19, "rz": 0.20, "oz": 0.03, "shade": 0.80},
			{"y": 0.35, "rx": 0.18, "rz": 0.20, "oz": 0.02, "shade": 1.0},
			{"y": 0.43, "rx": 0.08, "rz": 0.12, "oz": 0.05, "shade": 1.05},
		], 8, mat_hood, Vector3.ZERO, Vector3.ZERO, "Hood"))
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.04, "rx": 0.155, "rz": 0.15, "oz": -0.03, "shade": 0.82},
			{"y": 0.17, "rx": 0.175, "rz": 0.17, "oz": -0.02, "shade": 1.0},
		], 8, mat_mask, Vector3.ZERO, Vector3.ZERO, "FaceMask"))
	elif archetype == "murloc":
		var mat_fin := make_retro_material(accent_color, 0.68, 0.05)
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.08, "rx": 0.21, "rz": 0.20, "oz": -0.05, "shade": 0.84},
			{"y": 0.20, "rx": 0.19, "rz": 0.18, "oz": -0.04, "shade": 1.02},
		], 8, mat_skin, Vector3.ZERO, Vector3.ZERO, "MurlocJaw"))
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.34, "rx": 0.03, "rz": 0.14, "oz": 0.04, "shade": 0.85},
			{"y": 0.56, "rx": 0.015, "rz": 0.08, "oz": 0.12, "shade": 1.12},
		], 4, mat_fin, Vector3.ZERO, Vector3.ZERO, "HeadFin"))
		torso_pivot.add_child(_make_lofted_mesh([
			{"y": 0.20, "rx": 0.03, "rz": 0.10, "shade": 0.82},
			{"y": 0.58, "rx": 0.02, "rz": 0.16, "oz": 0.08, "shade": 1.10},
		], 4, mat_fin, Vector3(0, 0, 0.20), Vector3(-16, 0, 0), "BackFin"))
	elif archetype == "guard":
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.22, "rx": 0.19, "rz": 0.20, "shade": 0.84},
			{"y": 0.36, "rx": 0.17, "rz": 0.18, "shade": 1.02},
			{"y": 0.43, "rx": 0.09, "rz": 0.10, "shade": 1.08},
		], 8, mat_steel, Vector3.ZERO, Vector3.ZERO, "Helm"))
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.36, "rx": 0.035, "rz": 0.22, "shade": 0.88},
			{"y": 0.50, "rx": 0.02, "rz": 0.18, "oz": 0.03, "shade": 1.12},
		], 4, mat_accent, Vector3.ZERO, Vector3.ZERO, "HelmCrest"))
	else:
		# Скульптурная причёска воина + золотая диадема
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.26, "rx": 0.185, "rz": 0.195, "oz": 0.01, "shade": 0.86},
			{"y": 0.39, "rx": 0.165, "rz": 0.175, "oz": 0.02, "shade": 1.04},
			{"y": 0.44, "rx": 0.09, "rz": 0.10, "oz": 0.02, "shade": 1.08},
		], 8, mat_hair, Vector3.ZERO, Vector3.ZERO, "HairTop"))
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.04, "rx": 0.15, "rz": 0.08, "shade": 0.78},
			{"y": 0.26, "rx": 0.18, "rz": 0.10, "shade": 1.0},
		], 6, mat_hair, Vector3(0, 0, 0.12), Vector3.ZERO, "HairBack"))

	if has_candle:
		var mat_wax := make_retro_material(Color(0.95, 0.90, 0.72), 0.7, 0.0)
		var mat_flame := make_retro_material(Color(1.0, 0.72, 0.15), 0.2, 0.0, Color(1.0, 0.62, 0.10), 2.8)
		head_pivot.add_child(_make_prism_or_cyl(0.055, 0.068, 0.22, 6, mat_wax, Vector3(0, 0.49, 0), Vector3.ZERO, "CandleWax"))
		head_pivot.add_child(_make_prism_or_cyl(0.005, 0.048, 0.13, 5, mat_flame, Vector3(0, 0.65, 0), Vector3.ZERO, "CandleFlame"))

	# Двухсоставные руки с локтевым шарниром, наплечником и расклешённой перчаткой
	var pauldron_mat: Material = mat_accent if archetype != "kobold" else mat_armor
	for arm_side in [
		{"name": "ArmLPivot", "elbow": "ElbowLPivot", "x": -0.37, "sign": -1.0},
		{"name": "ArmRPivot", "elbow": "ElbowRPivot", "x": 0.37, "sign": 1.0},
	]:
		var s: float = float(arm_side["sign"])
		var arm := Node3D.new()
		arm.name = arm_side["name"]
		arm.position = Vector3(float(arm_side["x"]), 0.52, 0.0)
		torso_pivot.add_child(arm)

		arm.add_child(_make_pauldron(pauldron_mat, mat_armor if archetype != "kobold" else mat_accent, s, "Pauldron"))
		arm.add_child(_make_lofted_mesh([
			{"y": -0.27, "rx": 0.075, "rz": 0.08, "shade": 0.78},
			{"y": 0.0, "rx": 0.095, "rz": 0.10, "shade": 1.0},
		], 8, mat_armor, Vector3(s * 0.03, 0, 0), Vector3.ZERO, "UpperArm"))

		var elbow := Node3D.new()
		elbow.name = arm_side["elbow"]
		elbow.position = Vector3(s * 0.03, -0.27, 0.0)
		arm.add_child(elbow)
		# Наруч / перчатка (расклешена у локтя как в WoW)
		elbow.add_child(_make_lofted_mesh([
			{"y": -0.24, "rx": 0.075, "rz": 0.08, "shade": 0.76},
			{"y": -0.10, "rx": 0.092, "rz": 0.098, "shade": 0.96},
			{"y": 0.0, "rx": 0.105, "rz": 0.11, "shade": 1.06},
		], 8, mat_boots if archetype in ["warrior", "guard"] else mat_armor, Vector3.ZERO, Vector3.ZERO, "Gauntlet"))
		elbow.add_child(_make_lofted_mesh([
			{"y": -0.34, "rx": 0.065, "rz": 0.07, "shade": 0.80},
			{"y": -0.24, "rx": 0.075, "rz": 0.08, "shade": 1.0},
		], 6, mat_skin, Vector3.ZERO, Vector3.ZERO, "Hand"))

		if s < 0.0:
			if has_shield:
				var shield_grp := Node3D.new()
				shield_grp.name = "ShieldMesh"
				shield_grp.position = Vector3(-0.13, -0.14, -0.05)
				elbow.add_child(shield_grp)
				shield_grp.add_child(_make_lofted_mesh([
					{"y": -0.32, "rx": 0.03, "rz": 0.12, "shade": 0.74},
					{"y": 0.0, "rx": 0.04, "rz": 0.24, "shade": 0.96},
					{"y": 0.28, "rx": 0.04, "rz": 0.25, "shade": 1.06},
				], 6, mat_armor, Vector3.ZERO, Vector3.ZERO, "ShieldBody"))
				shield_grp.add_child(_make_lofted_mesh([
					{"y": -0.12, "rx": 0.055, "rz": 0.09, "shade": 0.9},
					{"y": 0.12, "rx": 0.055, "rz": 0.09, "shade": 1.1},
				], 6, mat_accent, Vector3(-0.01, 0, 0), Vector3.ZERO, "ShieldBoss"))
			elif has_offhand_dagger:
				var off_dagger := _build_weapon("dagger", mat_steel, mat_accent, mat_wood)
				off_dagger.name = "OffhandDagger"
				off_dagger.position = Vector3(0.0, -0.30, -0.06)
				elbow.add_child(off_dagger)
		else:
			var weapon_node := _build_weapon(weapon_type, mat_steel, mat_accent, mat_wood)
			weapon_node.name = "WeaponMesh"
			weapon_node.position = Vector3(0.0, -0.30, -0.06)
			elbow.add_child(weapon_node)

	return rig


static func _build_weapon(weapon_type: String, mat_steel: Material, mat_accent: Material, mat_wood: Material) -> Node3D:
	var w := Node3D.new()
	if weapon_type == "staff":
		var mat_crystal := make_retro_material(Color(0.4, 0.78, 1.0), 0.2, 0.0, Color(0.35, 0.72, 1.0), 2.8)
		w.add_child(_make_lofted_mesh([
			{"y": -0.25, "rx": 0.03, "rz": 0.03, "shade": 0.78},
			{"y": 1.25, "rx": 0.04, "rz": 0.04, "shade": 1.05},
		], 6, mat_wood, Vector3.ZERO, Vector3(-90, 0, 0), "Shaft"))
		w.add_child(_make_lofted_mesh([
			{"y": -0.06, "rx": 0.05, "rz": 0.05, "shade": 0.85},
			{"y": 0.06, "rx": 0.09, "rz": 0.09, "shade": 1.1},
		], 6, mat_accent, Vector3(0, 0, -1.24), Vector3(-90, 0, 0), "Crown"))
		w.add_child(_make_lofted_mesh([
			{"y": -0.14, "rx": 0.01, "rz": 0.01, "shade": 0.9},
			{"y": 0.0, "rx": 0.10, "rz": 0.10, "shade": 1.1},
			{"y": 0.14, "rx": 0.01, "rz": 0.01, "shade": 1.2},
		], 6, mat_crystal, Vector3(0, 0, -1.42), Vector3(-90, 0, 0), "Crystal"))
	elif weapon_type == "fire_staff":
		var mat_ember := make_retro_material(Color(1.0, 0.45, 0.12), 0.2, 0.0, Color(1.0, 0.42, 0.08), 2.8)
		w.add_child(_make_lofted_mesh([
			{"y": -0.20, "rx": 0.03, "rz": 0.03, "shade": 0.78},
			{"y": 1.15, "rx": 0.04, "rz": 0.04, "shade": 1.05},
		], 6, mat_wood, Vector3.ZERO, Vector3(-90, 0, 0), "Shaft"))
		w.add_child(_make_lofted_mesh([
			{"y": -0.12, "rx": 0.02, "rz": 0.02, "shade": 0.9},
			{"y": 0.0, "rx": 0.11, "rz": 0.11, "shade": 1.15},
			{"y": 0.12, "rx": 0.02, "rz": 0.02, "shade": 1.2},
		], 6, mat_ember, Vector3(0, 0, -1.25), Vector3(-90, 0, 0), "Orb"))
	elif weapon_type == "dagger":
		w.add_child(_make_lofted_mesh([
			{"y": -0.12, "rx": 0.025, "rz": 0.025, "shade": 0.8},
			{"y": 0.06, "rx": 0.025, "rz": 0.025, "shade": 1.0},
		], 6, mat_wood, Vector3(0, 0, 0.02), Vector3(-90, 0, 0), "Grip"))
		w.add_child(_make_box_mesh(Vector3(0.18, 0.04, 0.04), mat_accent, Vector3(0, 0, -0.08), Vector3.ZERO, "Guard"))
		w.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.038, "rz": 0.015, "shade": 0.85},
			{"y": 0.30, "rx": 0.028, "rz": 0.012, "shade": 1.02},
			{"y": 0.46, "rx": 0.005, "rz": 0.005, "shade": 1.15},
		], 4, mat_steel, Vector3(0, 0, -0.10), Vector3(-90, 0, 0), "Blade"))
	elif weapon_type == "spear":
		w.add_child(_make_lofted_mesh([
			{"y": -0.25, "rx": 0.026, "rz": 0.026, "shade": 0.78},
			{"y": 1.20, "rx": 0.028, "rz": 0.028, "shade": 1.02},
		], 6, mat_wood, Vector3.ZERO, Vector3(-90, 0, 0), "Shaft"))
		w.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.06, "rz": 0.02, "shade": 0.85},
			{"y": 0.14, "rx": 0.075, "rz": 0.022, "shade": 1.04},
			{"y": 0.36, "rx": 0.006, "rz": 0.006, "shade": 1.18},
		], 4, mat_steel, Vector3(0, 0, -1.20), Vector3(-90, 0, 0), "SpearTip"))
	elif weapon_type == "pickaxe":
		w.add_child(_make_lofted_mesh([
			{"y": -0.10, "rx": 0.03, "rz": 0.03, "shade": 0.8},
			{"y": 0.72, "rx": 0.032, "rz": 0.032, "shade": 1.0},
		], 6, mat_wood, Vector3.ZERO, Vector3(-90, 0, 0), "Handle"))
		w.add_child(_make_lofted_mesh([
			{"y": -0.28, "rx": 0.012, "rz": 0.02, "oz": 0.05, "shade": 0.8},
			{"y": 0.0, "rx": 0.05, "rz": 0.055, "shade": 1.08},
			{"y": 0.28, "rx": 0.012, "rz": 0.02, "oz": 0.05, "shade": 0.8},
		], 4, mat_steel, Vector3(0, 0, -0.66), Vector3(0, 0, 0), "PickHead"))
	elif weapon_type == "greataxe":
		w.add_child(_make_lofted_mesh([
			{"y": -0.25, "rx": 0.04, "rz": 0.04, "shade": 0.78},
			{"y": 1.18, "rx": 0.042, "rz": 0.042, "shade": 1.05},
		], 6, mat_wood, Vector3.ZERO, Vector3(-90, 0, 0), "Handle"))
		w.add_child(_make_lofted_mesh([
			{"y": -0.22, "rx": 0.03, "rz": 0.28, "shade": 0.82},
			{"y": 0.0, "rx": 0.055, "rz": 0.16, "shade": 1.06},
			{"y": 0.22, "rx": 0.03, "rz": 0.28, "shade": 1.12},
		], 4, mat_steel, Vector3(0, 0.02, -1.04), Vector3(-90, 0, 0), "AxeBlade"))
		w.add_child(_make_box_mesh(Vector3(0.14, 0.18, 0.16), mat_accent, Vector3(0, 0.02, -1.04), Vector3.ZERO, "AxeTrim"))
	elif weapon_type == "shortsword":
		w.add_child(_make_lofted_mesh([
			{"y": -0.10, "rx": 0.028, "rz": 0.028, "shade": 0.8},
			{"y": 0.10, "rx": 0.028, "rz": 0.028, "shade": 1.0},
		], 6, mat_wood, Vector3(0, 0, 0.02), Vector3(-90, 0, 0), "Grip"))
		w.add_child(_make_box_mesh(Vector3(0.26, 0.055, 0.05), mat_accent, Vector3(0, 0, -0.10), Vector3.ZERO, "Guard"))
		w.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.055, "rz": 0.018, "shade": 0.85},
			{"y": 0.56, "rx": 0.045, "rz": 0.016, "shade": 1.05},
			{"y": 0.74, "rx": 0.008, "rz": 0.006, "shade": 1.18},
		], 4, mat_steel, Vector3(0, 0, -0.13), Vector3(-90, 0, 0), "Blade"))
	else:
		# Классический двуручный клинок воина со скошенным остриём
		w.add_child(_make_lofted_mesh([
			{"y": -0.18, "rx": 0.032, "rz": 0.032, "shade": 0.8},
			{"y": 0.14, "rx": 0.032, "rz": 0.032, "shade": 1.0},
		], 6, mat_wood, Vector3(0, 0, 0.04), Vector3(-90, 0, 0), "Grip"))
		w.add_child(_make_lofted_mesh([
			{"y": -0.05, "rx": 0.055, "rz": 0.055, "shade": 0.85},
			{"y": 0.05, "rx": 0.065, "rz": 0.065, "shade": 1.15},
		], 6, mat_accent, Vector3(0, 0, 0.22), Vector3(-90, 0, 0), "Pommel"))
		w.add_child(_make_box_mesh(Vector3(0.36, 0.075, 0.065), mat_accent, Vector3(0, 0, -0.14), Vector3.ZERO, "Crossguard"))
		w.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.072, "rz": 0.022, "shade": 0.85},
			{"y": 0.84, "rx": 0.058, "rz": 0.020, "shade": 1.04},
			{"y": 1.08, "rx": 0.008, "rz": 0.008, "shade": 1.18},
		], 4, mat_steel, Vector3(0, 0, -0.17), Vector3(-90, 0, 0), "Blade"))
	return w


static func build_wolf(config: Dictionary) -> Node3D:
	var scale_factor: float = float(config.get("scale", 1.0))
	var fur_color: Color = config.get("fur_color", Color(0.36, 0.34, 0.33))
	var belly_color: Color = config.get("belly_color", Color(0.55, 0.51, 0.46))
	var eye_color: Color = config.get("eye_color", Color(1.0, 0.75, 0.18))

	var mat_fur := make_retro_material(fur_color, 0.92, 0.0, Color.BLACK, 0.0, "fur")
	var mat_mane := make_retro_material(fur_color.darkened(0.22), 0.95, 0.0, Color.BLACK, 0.0, "fur")
	var mat_snout := make_retro_material(fur_color.lightened(0.08), 0.92, 0.0, Color.BLACK, 0.0, "fur")
	var mat_belly := make_retro_material(belly_color, 0.92, 0.0)
	var mat_eye := make_retro_material(eye_color, 0.3, 0.0, eye_color, 1.6)
	var mat_nose := make_retro_material(Color(0.08, 0.08, 0.09), 0.5, 0.1)

	var rig := Node3D.new()
	rig.name = "WolfRig"
	rig.scale = Vector3.ONE * scale_factor

	var root_pivot := Node3D.new()
	root_pivot.name = "RootPivot"
	rig.add_child(root_pivot)

	var body_pivot := Node3D.new()
	body_pivot.name = "BodyPivot"
	body_pivot.position = Vector3(0, 0.64, 0)
	root_pivot.add_child(body_pivot)

	# Скульптурное тело волка (широкая грудь, подтянутый пояс, круп)
	body_pivot.add_child(_make_lofted_mesh([
		{"y": -0.48, "rx": 0.17, "rz": 0.17, "shade": 0.80},
		{"y": -0.15, "rx": 0.16, "rz": 0.16, "oz": 0.02, "shade": 0.92},
		{"y": 0.22, "rx": 0.22, "rz": 0.22, "shade": 1.02},
		{"y": 0.48, "rx": 0.19, "rz": 0.19, "oz": -0.02, "shade": 0.96},
	], 8, mat_fur, Vector3.ZERO, Vector3(90, 0, 0), "Torso"))
	body_pivot.add_child(_make_lofted_mesh([
		{"y": -0.18, "rx": 0.23, "rz": 0.23, "shade": 0.84},
		{"y": 0.20, "rx": 0.26, "rz": 0.25, "oz": -0.03, "shade": 1.05},
	], 8, mat_mane, Vector3(0, 0.04, -0.26), Vector3(78, 0, 0), "Mane"))
	body_pivot.add_child(_make_box_mesh(Vector3(0.24, 0.08, 0.68), mat_belly, Vector3(0, -0.17, 0), Vector3.ZERO, "Belly"))

	# Голова и морда волка
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0, 0.18, -0.50)
	body_pivot.add_child(head_pivot)
	head_pivot.add_child(_make_lofted_mesh([
		{"y": -0.14, "rx": 0.15, "rz": 0.15, "shade": 0.84},
		{"y": 0.14, "rx": 0.17, "rz": 0.16, "shade": 1.02},
		{"y": 0.24, "rx": 0.10, "rz": 0.10, "shade": 1.06},
	], 8, mat_fur, Vector3(0, 0.06, -0.10), Vector3(72, 0, 0), "Skull"))
	head_pivot.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": 0.10, "rz": 0.085, "shade": 0.88},
		{"y": 0.26, "rx": 0.055, "rz": 0.045, "shade": 1.02},
	], 6, mat_snout, Vector3(0, 0.01, -0.22), Vector3(94, 0, 0), "Snout"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.075, 0.055, 0.055), mat_nose, Vector3(0, -0.01, -0.49), Vector3.ZERO, "Nose"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.055, 0.045, 0.045), mat_eye, Vector3(-0.09, 0.10, -0.27), Vector3.ZERO, "EyeL"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.055, 0.045, 0.045), mat_eye, Vector3(0.09, 0.10, -0.27), Vector3.ZERO, "EyeR"))
	head_pivot.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": 0.045, "rz": 0.035, "shade": 0.84},
		{"y": 0.17, "rx": 0.01, "rz": 0.01, "shade": 1.06},
	], 4, mat_mane, Vector3(-0.11, 0.17, -0.05), Vector3(0, 0, 14), "EarL"))
	head_pivot.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": 0.045, "rz": 0.035, "shade": 0.84},
		{"y": 0.17, "rx": 0.01, "rz": 0.01, "shade": 1.06},
	], 4, mat_mane, Vector3(0.11, 0.17, -0.05), Vector3(0, 0, -14), "EarR"))

	# Двухсегментный пушистый хвост
	var tail_pivot := Node3D.new()
	tail_pivot.name = "TailPivot"
	tail_pivot.position = Vector3(0, 0.08, 0.45)
	body_pivot.add_child(tail_pivot)
	tail_pivot.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": 0.06, "rz": 0.06, "shade": 0.85},
		{"y": 0.44, "rx": 0.075, "rz": 0.075, "shade": 1.0},
		{"y": 0.54, "rx": 0.02, "rz": 0.02, "shade": 1.08},
	], 6, mat_mane, Vector3.ZERO, Vector3(-112, 0, 0), "TailMesh"))

	# 4 двухсоставные лапы с лодыжкой и лапой
	var leg_offsets: Dictionary = {
		"LegFL": Vector3(-0.15, -0.12, -0.30),
		"LegFR": Vector3(0.15, -0.12, -0.30),
		"LegBL": Vector3(-0.15, -0.12, 0.30),
		"LegBR": Vector3(0.15, -0.12, 0.30),
	}
	for leg_name in leg_offsets.keys():
		var lp := Node3D.new()
		lp.name = leg_name
		lp.position = leg_offsets[leg_name]
		body_pivot.add_child(lp)
		lp.add_child(_make_lofted_mesh([
			{"y": -0.25, "rx": 0.06, "rz": 0.065, "shade": 0.80},
			{"y": 0.0, "rx": 0.085, "rz": 0.095, "shade": 1.0},
		], 6, mat_fur, Vector3.ZERO, Vector3.ZERO, "UpperLeg"))
		var lower := Node3D.new()
		lower.name = "Lower"
		lower.position = Vector3(0, -0.24, 0)
		lp.add_child(lower)
		lower.add_child(_make_lofted_mesh([
			{"y": -0.27, "rx": 0.055, "rz": 0.075, "oz": -0.02, "shade": 0.72},
			{"y": 0.0, "rx": 0.055, "rz": 0.06, "shade": 0.94},
		], 6, mat_mane, Vector3.ZERO, Vector3.ZERO, "LowerLeg"))

	return rig


static func _blend_rot(node: Node3D, target: Vector3, blend: float) -> void:
	if node == null:
		return
	if blend >= 0.99:
		node.rotation = target
	else:
		node.rotation = Vector3(
			lerp_angle(node.rotation.x, target.x, blend),
			lerp_angle(node.rotation.y, target.y, blend),
			lerp_angle(node.rotation.z, target.z, blend)
		)


static func _blend_pos(node: Node3D, target: Vector3, blend: float) -> void:
	if node == null:
		return
	node.position = target if blend >= 0.99 else node.position.lerp(target, blend)


static func animate_humanoid(rig: Node3D, anim_state: String, anim_time: float, attack_progress: float = 0.0, spin_angle: float = 0.0, base_hunch: float = 0.0, delta: float = 0.0, flags: Dictionary = {}) -> void:
	if not is_instance_valid(rig):
		return
	var root := rig.get_node_or_null("RootPivot") as Node3D
	if root == null:
		return
	var torso := root.get_node_or_null("TorsoPivot") as Node3D
	var head := torso.get_node_or_null("HeadPivot") as Node3D if torso else null
	var arm_l := torso.get_node_or_null("ArmLPivot") as Node3D if torso else null
	var arm_r := torso.get_node_or_null("ArmRPivot") as Node3D if torso else null
	var elbow_l := arm_l.get_node_or_null("ElbowLPivot") as Node3D if arm_l else null
	var elbow_r := arm_r.get_node_or_null("ElbowRPivot") as Node3D if arm_r else null
	var cape := torso.get_node_or_null("CapePivot") as Node3D if torso else null
	var cape_low := cape.get_node_or_null("CapeLowerPivot") as Node3D if cape else null
	var leg_l := root.get_node_or_null("LegLPivot") as Node3D
	var leg_r := root.get_node_or_null("LegRPivot") as Node3D
	var knee_l := leg_l.get_node_or_null("KneeLPivot") as Node3D if leg_l else null
	var knee_r := leg_r.get_node_or_null("KneeRPivot") as Node3D if leg_r else null

	var blend: float = 1.0 if delta <= 0.0 else minf(1.0, delta * 14.0)

	if anim_state == "DEAD":
		_blend_pos(root, Vector3(0, 0.22, 0), blend)
		_blend_rot(root, Vector3(-PI * 0.47, 0, 0.14), blend)
		_blend_rot(arm_l, Vector3(0.1, 0, -0.52), blend)
		_blend_rot(arm_r, Vector3(0.25, 0, 0.58), blend)
		_blend_rot(elbow_l, Vector3(0.35, 0, 0), blend)
		_blend_rot(elbow_r, Vector3(0.45, 0, 0), blend)
		_blend_rot(leg_l, Vector3(0.18, 0, -0.14), blend)
		_blend_rot(leg_r, Vector3(-0.08, 0, 0.18), blend)
		_blend_rot(knee_l, Vector3(-0.42, 0, 0), blend)
		_blend_rot(knee_r, Vector3(-0.18, 0, 0), blend)
		return

	_blend_pos(root, Vector3.ZERO, blend)
	if anim_state == "WHIRLWIND":
		root.rotation = Vector3(0, spin_angle, 0)
	else:
		_blend_rot(root, Vector3.ZERO, blend)

	var leg_l_rot := Vector3.ZERO
	var leg_r_rot := Vector3.ZERO
	var knee_l_rot := Vector3.ZERO
	var knee_r_rot := Vector3.ZERO
	var arm_l_rot := Vector3(0.06, 0, -0.14)
	var arm_r_rot := Vector3(0.16, 0, 0.14)
	var elbow_l_rot := Vector3(0.24, 0, 0)
	var elbow_r_rot := Vector3(0.32, 0, 0)
	var cape_rot := Vector3(-0.08, 0, 0)
	var cape_low_rot := Vector3(-0.05, 0, 0)
	var bob: float = 0.0
	var torso_pitch: float = base_hunch
	var torso_yaw: float = 0.0
	var head_rot := Vector3(-base_hunch * 0.4, 0, 0)

	if anim_state == "WALK" or anim_state == "CHARGE":
		var speed_mult: float = 13.5 if anim_state == "CHARGE" else 9.0
		var phase: float = anim_time * speed_mult
		var s: float = sin(phase)
		var c: float = cos(phase)
		var amp: float = 0.85 if anim_state == "CHARGE" else 0.72
		leg_l_rot = Vector3(s * amp, 0, 0)
		leg_r_rot = Vector3(-s * amp, 0, 0)
		# Колени сгибаются строго назад (<= 0) в фазе маха
		knee_l_rot = Vector3(-maxf(0.12, (-s * 0.55 + c * 0.45) * 0.95), 0, 0)
		knee_r_rot = Vector3(-maxf(0.12, (s * 0.55 - c * 0.45) * 0.95), 0, 0)
		bob = absf(s) * 0.075 - 0.03
		torso_pitch += -0.28 if anim_state == "CHARGE" else -0.12
		torso_yaw = -s * 0.16
		arm_l_rot = Vector3(-s * 0.65, 0, -0.14)
		arm_r_rot = Vector3(s * 0.60 + 0.14, 0, 0.14)
		elbow_l_rot = Vector3(0.45 + maxf(0.0, -s) * 0.45, 0, 0)
		elbow_r_rot = Vector3(0.45 + maxf(0.0, s) * 0.45, 0, 0)
		cape_rot = Vector3(-0.46 - absf(s) * 0.12, 0, 0)
		cape_low_rot = Vector3(-0.22 - sin(phase - 0.8) * 0.16, 0, 0)
	elif anim_state == "JUMP":
		leg_l_rot = Vector3(0.45, 0, -0.08)
		leg_r_rot = Vector3(0.12, 0, 0.08)
		knee_l_rot = Vector3(-0.78, 0, 0)
		knee_r_rot = Vector3(-0.42, 0, 0)
		arm_l_rot = Vector3(0.35, 0, -0.45)
		arm_r_rot = Vector3(0.35, 0, 0.45)
		elbow_l_rot = Vector3(0.65, 0, 0)
		elbow_r_rot = Vector3(0.65, 0, 0)
		torso_pitch += -0.14
		cape_rot = Vector3(-0.62, 0, 0)
		cape_low_rot = Vector3(-0.35, 0, 0)
	elif anim_state == "STUNNED":
		leg_l_rot = Vector3(0.15, 0, -0.10)
		leg_r_rot = Vector3(0.15, 0, 0.10)
		knee_l_rot = Vector3(-0.34, 0, 0)
		knee_r_rot = Vector3(-0.34, 0, 0)
		bob = -0.05
		torso_pitch += -0.22 + sin(anim_time * 3.5) * 0.06
		torso_yaw = sin(anim_time * 2.8) * 0.14
		head_rot = Vector3(-0.32 + sin(anim_time * 4.5) * 0.12, sin(anim_time * 3.2) * 0.28, cos(anim_time * 3.2) * 0.16)
		arm_l_rot = Vector3(0.12, 0, -0.25)
		arm_r_rot = Vector3(0.12, 0, 0.25)
	elif anim_state == "CAST":
		var pulse: float = sin(anim_time * 16.0) * 0.05
		bob = sin(anim_time * 8.0) * 0.02
		torso_pitch += 0.08
		leg_l_rot = Vector3(0.14, 0, -0.08)
		leg_r_rot = Vector3(-0.14, 0, 0.08)
		knee_l_rot = Vector3(-0.18, 0, 0)
		knee_r_rot = Vector3(-0.12, 0, 0)
		arm_l_rot = Vector3(1.25 + pulse, 0.22, -0.25)
		arm_r_rot = Vector3(1.38 - pulse, -0.22, 0.25)
		elbow_l_rot = Vector3(0.55, 0, 0)
		elbow_r_rot = Vector3(0.45, 0, 0)
		cape_rot = Vector3(-0.28 + pulse, 0, 0)
		cape_low_rot = Vector3(-0.18, 0, 0)
	else:
		# IDLE с живым дыханием и лёгким переносом веса
		var breath: float = sin(anim_time * 2.2)
		bob = breath * 0.022
		torso_pitch += breath * 0.02
		torso_yaw = sin(anim_time * 0.9) * 0.05
		knee_l_rot = Vector3(-0.08, 0, 0)
		knee_r_rot = Vector3(-0.08, 0, 0)
		arm_l_rot = Vector3(0.06 + breath * 0.03, 0, -0.15)
		arm_r_rot = Vector3(0.18 - breath * 0.03, 0, 0.15)
		elbow_l_rot = Vector3(0.26, 0, 0)
		elbow_r_rot = Vector3(0.36, 0, 0)
		head_rot = Vector3(-base_hunch * 0.4 + sin(anim_time * 1.4) * 0.035, sin(anim_time * 0.7) * 0.08, 0)
		cape_rot = Vector3(-0.09 - breath * 0.035, 0, 0)
		cape_low_rot = Vector3(-0.06 - sin(anim_time * 2.2 - 0.6) * 0.05, 0, 0)

	if anim_state == "WHIRLWIND":
		torso_pitch = base_hunch - 0.20
		knee_l_rot = Vector3(-0.35, 0, 0)
		knee_r_rot = Vector3(-0.35, 0, 0)
		arm_l_rot = Vector3(0.20, 0, -1.35)
		arm_r_rot = Vector3(1.35, 0.40, 1.15)
		elbow_l_rot = Vector3(0.25, 0, 0)
		elbow_r_rot = Vector3(0.15, 0, 0)
		cape_rot = Vector3(-0.82, 0, 0)
		cape_low_rot = Vector3(-0.38, 0, 0)
	elif attack_progress > 0.0:
		var p: float = clampf(attack_progress, 0.0, 1.0)
		var dual: bool = bool(flags.get("dual_wield", false))
		if p < 0.28:
			var t: float = ease(p / 0.28, 0.5)
			arm_r_rot = Vector3(lerpf(0.2, 2.25, t), 0.25 * t, 0.35 * t)
			elbow_r_rot = Vector3(lerpf(0.35, 1.05, t), 0, 0)
			torso_yaw = -0.42 * t
			torso_pitch += 0.16 * t
			if dual:
				arm_l_rot = Vector3(lerpf(0.1, 1.65, t), -0.2 * t, -0.3 * t)
				elbow_l_rot = Vector3(0.95, 0, 0)
			else:
				arm_l_rot = Vector3(0.25, 0, -0.35)
				elbow_l_rot = Vector3(0.65, 0, 0)
		elif p < 0.62:
			var t: float = ease((p - 0.28) / 0.34, 2.0)
			arm_r_rot = Vector3(lerpf(2.25, -0.65, t), lerpf(0.25, -0.38, t), lerpf(0.35, -0.10, t))
			elbow_r_rot = Vector3(lerpf(1.05, 0.20, t), 0, 0)
			torso_yaw = lerpf(-0.42, 0.46, t)
			torso_pitch += lerpf(0.16, -0.28, t)
			if dual:
				arm_l_rot = Vector3(lerpf(1.65, -0.45, t), 0.3 * t, -0.15)
				elbow_l_rot = Vector3(lerpf(0.95, 0.25, t), 0, 0)
			else:
				arm_l_rot = Vector3(-0.35, 0, -0.25)
		else:
			var t: float = (p - 0.62) / 0.38
			arm_r_rot = Vector3(lerpf(-0.65, 0.20, t), lerpf(-0.38, 0.0, t), lerpf(-0.10, 0.14, t))
			elbow_r_rot = Vector3(lerpf(0.20, 0.36, t), 0, 0)
			torso_yaw = lerpf(0.46, 0.0, t)
			arm_l_rot = Vector3(lerpf(-0.35, 0.06, t), 0, -0.16)

	var atk_blend: float = 1.0 if attack_progress > 0.0 else blend
	_blend_pos(torso, Vector3(0.0, 0.80 + bob, 0.0), blend)
	_blend_rot(torso, Vector3(torso_pitch, torso_yaw, 0.0), atk_blend)
	_blend_rot(head, head_rot, blend)
	_blend_rot(leg_l, leg_l_rot, blend)
	_blend_rot(leg_r, leg_r_rot, blend)
	_blend_rot(knee_l, knee_l_rot, blend)
	_blend_rot(knee_r, knee_r_rot, blend)
	_blend_rot(arm_l, arm_l_rot, atk_blend)
	_blend_rot(arm_r, arm_r_rot, atk_blend)
	_blend_rot(elbow_l, elbow_l_rot, atk_blend)
	_blend_rot(elbow_r, elbow_r_rot, atk_blend)
	_blend_rot(cape, cape_rot, blend)
	_blend_rot(cape_low, cape_low_rot, blend)


static func animate_wolf(rig: Node3D, anim_state: String, anim_time: float, attack_progress: float = 0.0, delta: float = 0.0) -> void:
	if not is_instance_valid(rig):
		return
	var root := rig.get_node_or_null("RootPivot") as Node3D
	if root == null:
		return
	var body := root.get_node_or_null("BodyPivot") as Node3D
	if body == null:
		return
	var head := body.get_node_or_null("HeadPivot") as Node3D
	var tail := body.get_node_or_null("TailPivot") as Node3D
	var leg_fl := body.get_node_or_null("LegFL") as Node3D
	var leg_fr := body.get_node_or_null("LegFR") as Node3D
	var leg_bl := body.get_node_or_null("LegBL") as Node3D
	var leg_br := body.get_node_or_null("LegBR") as Node3D

	var blend: float = 1.0 if delta <= 0.0 else minf(1.0, delta * 14.0)

	if anim_state == "DEAD":
		_blend_pos(root, Vector3(0, 0.20, 0), blend)
		_blend_rot(root, Vector3(0, 0, PI * 0.48), blend)
		return

	_blend_pos(root, Vector3.ZERO, blend)
	_blend_rot(root, Vector3.ZERO, blend)

	var stride_f: float = 0.0
	var stride_b: float = 0.0
	var body_bob: float = 0.0
	var body_pitch: float = 0.0
	var lunge_z: float = 0.0
	var head_pitch: float = 0.0

	if anim_state == "WALK":
		var p: float = anim_time * 11.5
		stride_f = sin(p) * 0.68
		stride_b = sin(p + 0.6) * 0.68
		body_bob = absf(sin(p)) * 0.06
		body_pitch = cos(p) * 0.08
	else:
		body_bob = sin(anim_time * 2.6) * 0.022

	if attack_progress > 0.0:
		var bite_curve: float = sin(clampf(attack_progress, 0.0, 1.0) * PI)
		lunge_z = -0.28 * bite_curve
		head_pitch = -0.38 * bite_curve
		body_pitch += 0.14 * bite_curve

	_blend_pos(body, Vector3(0, 0.64 + body_bob, lunge_z), blend)
	_blend_rot(body, Vector3(body_pitch, 0, 0), blend)
	_blend_rot(head, Vector3(head_pitch, sin(anim_time * 1.4) * 0.08, 0), blend)
	_blend_rot(tail, Vector3(0.18, sin(anim_time * 5.2) * 0.30, 0), blend)

	for pair in [
		{"leg": leg_fl, "ang": stride_f},
		{"leg": leg_fr, "ang": -stride_f},
		{"leg": leg_bl, "ang": -stride_b},
		{"leg": leg_br, "ang": stride_b},
	]:
		var lg: Node3D = pair["leg"]
		var a: float = float(pair["ang"])
		if lg:
			_blend_rot(lg, Vector3(a, 0, 0), blend)
			var low := lg.get_node_or_null("Lower") as Node3D
			if low:
				_blend_rot(low, Vector3(-maxf(0.0, a * 0.65), 0, 0), blend)
