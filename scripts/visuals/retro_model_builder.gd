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
				if y == 2 or y == 29 or x == 2 or x == 29:
					v *= 0.82
				elif (x == 4 or x == 27) and (y % 8 == 4):
					v = 1.12
				else:
					v *= 0.96 + 0.06 * sin(float(y) * 0.4)
			elif pattern == "cloth":
				v *= 0.94 + 0.08 * sin(float(x) * 0.65)
			elif pattern == "fur":
				var streak: float = sin(float(x) * 1.25 + sin(float(y) * 0.4) * 1.6)
				v *= 0.86 + 0.16 * streak
				if (x + y * 3) % 11 == 0:
					v *= 0.78
			elif pattern == "scales":
				var row: int = y / 4
				var sx: int = (x + (row % 2) * 3) % 6
				if y % 4 == 0 or sx == 0:
					v *= 0.76
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


# Создаёт низкополигональную объёмную деталь по набору сечений (rings по возрастанию y) с запечённой вертексной тенью
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


# Шаровой/овальный сустав для плотных стыков без щелей при сгибах
static func _make_joint_cap(rxz: float, ry: float, mat: Material, pos: Vector3 = Vector3.ZERO, name_str: String = "JointCap") -> MeshInstance3D:
	return _make_lofted_mesh([
		{"y": -ry, "rx": rxz * 0.45, "rz": rxz * 0.45, "shade": 0.72},
		{"y": -ry * 0.40, "rx": rxz * 0.94, "rz": rxz * 0.94, "shade": 0.88},
		{"y": ry * 0.35, "rx": rxz, "rz": rxz, "shade": 1.00},
		{"y": ry, "rx": rxz * 0.45, "rz": rxz * 0.45, "shade": 1.06},
	], 8, mat, pos, Vector3.ZERO, name_str)


# Заострённая прядь меха / гривы / хвоста
static func _make_fur_tuft(mat: Material, length: float, width: float, pos: Vector3, rot_deg: Vector3, name_str: String = "FurTuft") -> MeshInstance3D:
	return _make_lofted_mesh([
		{"y": 0.0, "rx": width, "rz": width * 0.72, "shade": 0.72},
		{"y": length * 0.52, "rx": width * 0.62, "rz": width * 0.46, "oz": length * 0.05, "shade": 0.96},
		{"y": length, "rx": 0.008, "rz": 0.008, "oz": length * 0.14, "shade": 1.15},
	], 4, mat, pos, rot_deg, name_str)


# Загнутый коготь (вперёд по -Z в локальном пространстве родителя, с изгибом кончика вниз)
static func _make_claw(mat_claw: Material, length: float, thickness: float, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, name_str: String = "Claw") -> Node3D:
	var holder := Node3D.new()
	holder.name = name_str
	holder.position = pos
	if rot_deg != Vector3.ZERO:
		holder.rotation_degrees = rot_deg
	holder.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": thickness, "rz": thickness * 1.15, "shade": 0.78},
		{"y": length * 0.55, "rx": thickness * 0.60, "rz": thickness * 0.65, "oz": -length * 0.05, "shade": 0.96},
		{"y": length, "rx": 0.004, "rz": 0.004, "oz": -length * 0.18, "shade": 1.15},
	], 4, mat_claw, Vector3.ZERO, Vector3(-90, 0, 0), "ClawSpike"))
	return holder


# Суставчатая кисть с ладонью, большим пальцем, фалангами и (для зверолюдей) когтями/перепонками
static func _make_hand_with_fingers(mat_skin: Material, mat_claw: Material, mat_trim: Material, is_beast: bool, is_webbed: bool, is_armored: bool, side_sign: float, grip_pose: bool, name_str: String = "HandGroup") -> Node3D:
	var grp := Node3D.new()
	grp.name = name_str

	# Ладонь перекрывается с манжетом выше (y = +0.025)
	grp.add_child(_make_lofted_mesh([
		{"y": -0.075, "rx": 0.068, "rz": 0.044, "oz": -0.01, "shade": 0.84},
		{"y": -0.025, "rx": 0.074, "rz": 0.050, "shade": 0.96},
		{"y": 0.025, "rx": 0.064, "rz": 0.054, "shade": 1.04},
	], 6, mat_skin, Vector3.ZERO, Vector3.ZERO, "Palm"))

	if is_armored:
		grp.add_child(_make_box_mesh(Vector3(0.115, 0.048, 0.045), mat_trim, Vector3(0.0, -0.032, 0.022), Vector3.ZERO, "KnuckleGuard"))

	# Большой палец с фалангой (внутренняя сторона кисти)
	var thumb_pivot := Node3D.new()
	thumb_pivot.name = "Thumb"
	thumb_pivot.position = Vector3(-side_sign * 0.056, -0.024, -0.024)
	thumb_pivot.rotation_degrees = Vector3(28.0 if grip_pose else 12.0, -side_sign * 22.0, -side_sign * 34.0)
	grp.add_child(thumb_pivot)
	thumb_pivot.add_child(_make_lofted_mesh([
		{"y": -0.044, "rx": 0.019, "rz": 0.019, "shade": 0.85},
		{"y": 0.008, "rx": 0.022, "rz": 0.022, "shade": 1.0},
	], 5, mat_skin, Vector3.ZERO, Vector3.ZERO, "ThumbProx"))
	var thumb_dist := Node3D.new()
	thumb_dist.position = Vector3(0.0, -0.040, 0.0)
	thumb_dist.rotation_degrees = Vector3(36.0 if grip_pose else 16.0, 0.0, 0.0)
	thumb_pivot.add_child(thumb_dist)
	thumb_dist.add_child(_make_lofted_mesh([
		{"y": -0.032, "rx": 0.016, "rz": 0.016, "shade": 0.88},
		{"y": 0.004, "rx": 0.018, "rz": 0.018, "shade": 1.0},
	], 5, mat_skin, Vector3.ZERO, Vector3.ZERO, "ThumbDist"))
	if is_beast:
		thumb_dist.add_child(_make_claw(mat_claw, 0.048, 0.012, Vector3(0, -0.030, -0.004), Vector3(-70, 0, 0), "ThumbClaw"))

	# Основные пальцы с двумя фалангами (+ когти и перепонки)
	var finger_xs: Array = [-0.040, 0.0, 0.040] if is_beast else [-0.044, -0.015, 0.015, 0.044]
	var spread_deg: float = 13.0 if is_beast else 4.0
	for fi in range(finger_xs.size()):
		var fx: float = float(finger_xs[fi])
		var fan_idx: float = float(fi) - float(finger_xs.size() - 1) * 0.5
		var prox_len: float = 0.048 if is_beast else (0.042 if fi in [1, 2] else 0.036)
		var dist_len: float = 0.040 if is_beast else (0.034 if fi in [1, 2] else 0.028)
		var r_f: float = 0.017 if is_beast else 0.014

		var f_pivot := Node3D.new()
		f_pivot.name = "Finger_%d" % fi
		f_pivot.position = Vector3(fx, -0.068, -0.008)
		var flex1: float = (44.0 if grip_pose else 16.0) + absf(fan_idx) * 3.0
		f_pivot.rotation_degrees = Vector3(flex1, 0.0, -fan_idx * spread_deg)
		grp.add_child(f_pivot)

		f_pivot.add_child(_make_lofted_mesh([
			{"y": -prox_len, "rx": r_f * 0.88, "rz": r_f * 0.88, "shade": 0.82},
			{"y": 0.008, "rx": r_f, "rz": r_f, "shade": 1.0},
		], 5, mat_skin, Vector3.ZERO, Vector3.ZERO, "Phalanx1"))

		var dist_piv := Node3D.new()
		dist_piv.position = Vector3(0.0, -prox_len + 0.004, 0.0)
		dist_piv.rotation_degrees = Vector3(52.0 if grip_pose else 22.0, 0.0, 0.0)
		f_pivot.add_child(dist_piv)

		dist_piv.add_child(_make_lofted_mesh([
			{"y": -dist_len, "rx": r_f * 0.72, "rz": r_f * 0.72, "shade": 0.85},
			{"y": 0.005, "rx": r_f * 0.88, "rz": r_f * 0.88, "shade": 1.0},
		], 5, mat_skin, Vector3.ZERO, Vector3.ZERO, "Phalanx2"))

		if is_beast:
			dist_piv.add_child(_make_claw(mat_claw, 0.056, r_f * 0.72, Vector3(0.0, -dist_len + 0.004, 0.0), Vector3(-72, 0, 0), "Claw"))

	if is_webbed:
		grp.add_child(_make_box_mesh(Vector3(0.098, 0.052, 0.012), mat_trim, Vector3(0.0, -0.094, -0.022), Vector3(14, 0, 0), "HandWeb"))

	return grp


# Звериная / амфибийная лапа на ноге с тремя фаланговыми пальцами и когтями
static func _make_beast_foot_with_claws(mat_foot: Material, mat_claw: Material, mat_web: Material, is_webbed: bool, paw_scale: float, name_str: String = "PawGroup") -> Node3D:
	var grp := Node3D.new()
	grp.name = name_str

	# Плюсна / подушечка лапы на уровне 0..0.08 над землёй
	grp.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": 0.088 * paw_scale, "rz": 0.115 * paw_scale, "oz": -0.02 * paw_scale, "shade": 0.74},
		{"y": 0.055 * paw_scale, "rx": 0.078 * paw_scale, "rz": 0.095 * paw_scale, "oz": -0.01 * paw_scale, "shade": 0.94},
		{"y": 0.105 * paw_scale, "rx": 0.068 * paw_scale, "rz": 0.072 * paw_scale, "shade": 1.02},
	], 6, mat_foot, Vector3.ZERO, Vector3.ZERO, "PawPad"))

	var toe_yaws: Array = [-24.0, 0.0, 24.0] if is_webbed else [-18.0, 0.0, 18.0]
	for ti in range(3):
		var yaw_deg: float = float(toe_yaws[ti])
		var is_mid: bool = (ti == 1)
		var toe_len: float = (0.105 if is_mid else 0.090) * paw_scale
		var toe_piv := Node3D.new()
		toe_piv.name = "Toe_%d" % ti
		toe_piv.position = Vector3(sin(deg_to_rad(-yaw_deg)) * 0.040 * paw_scale, 0.026 * paw_scale, -0.065 * paw_scale)
		toe_piv.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
		grp.add_child(toe_piv)

		# 1-я фаланга пальца лапы
		toe_piv.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.026 * paw_scale, "rz": 0.022 * paw_scale, "shade": 0.82},
			{"y": toe_len * 0.58, "rx": 0.023 * paw_scale, "rz": 0.020 * paw_scale, "oz": -0.008 * paw_scale, "shade": 0.98},
		], 5, mat_foot, Vector3.ZERO, Vector3(-80, 0, 0), "ToeProx"))

		# 2-я фаланга пальца лапы + коготь на конце
		var dist_z: float = -toe_len * 0.56
		var dist_y: float = -0.006 * paw_scale
		toe_piv.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.022 * paw_scale, "rz": 0.019 * paw_scale, "shade": 0.88},
			{"y": toe_len * 0.45, "rx": 0.019 * paw_scale, "rz": 0.016 * paw_scale, "shade": 1.02},
		], 5, mat_foot, Vector3(0.0, dist_y, dist_z), Vector3(-92, 0, 0), "ToeDist"))

		toe_piv.add_child(_make_claw(mat_claw, 0.068 * paw_scale, 0.015 * paw_scale, Vector3(0.0, dist_y - 0.004 * paw_scale, dist_z - toe_len * 0.42), Vector3.ZERO, "ToeClaw"))

	if is_webbed:
		grp.add_child(_make_box_mesh(Vector3(0.185 * paw_scale, 0.012 * paw_scale, 0.115 * paw_scale), mat_web, Vector3(0.0, 0.014 * paw_scale, -0.105 * paw_scale), Vector3(6, 0, 0), "FootWeb"))

	return grp


static func _make_pauldron(mat_main: Material, mat_trim: Material, side_sign: float, name_str: String, spiked: bool = false) -> Node3D:
	var p := Node3D.new()
	p.name = name_str
	p.add_child(_make_lofted_mesh([
		{"y": -0.09, "rx": 0.155, "rz": 0.175, "ox": side_sign * 0.025, "shade": 0.78},
		{"y": 0.02, "rx": 0.165, "rz": 0.185, "ox": side_sign * 0.01, "shade": 1.0},
		{"y": 0.11, "rx": 0.115, "rz": 0.135, "ox": -side_sign * 0.02, "shade": 1.08},
	], 8, mat_main, Vector3.ZERO, Vector3(0, 0, -side_sign * 18.0), "Dome"))
	p.add_child(_make_lofted_mesh([
		{"y": -0.11, "rx": 0.168, "rz": 0.188, "ox": side_sign * 0.03, "shade": 0.85},
		{"y": -0.05, "rx": 0.172, "rz": 0.192, "ox": side_sign * 0.02, "shade": 1.08},
	], 8, mat_trim, Vector3.ZERO, Vector3(0, 0, -side_sign * 18.0), "Rim"))
	if spiked:
		p.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.042, "rz": 0.042, "shade": 0.82},
			{"y": 0.18, "rx": 0.008, "rz": 0.008, "shade": 1.15},
		], 5, mat_trim, Vector3(side_sign * 0.04, 0.08, 0.0), Vector3(0, 0, -side_sign * 26.0), "Spike"))
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
	var armor_tier: int = int(config.get("armor_tier", 0))

	var is_kobold: bool = (archetype == "kobold")
	var is_murloc: bool = (archetype == "murloc")
	var is_beast: bool = is_kobold or is_murloc
	var is_boss: bool = is_kobold and scale_factor >= 1.30

	var armor_pat: String = "scales" if is_murloc else ("cloth" if archetype in ["mage", "rogue", "bandit"] else "armor")
	var mat_armor := make_retro_material(armor_color, 0.68 if armor_pat == "armor" else 0.88, 0.32 if armor_pat == "armor" else 0.06, Color.BLACK, 0.0, armor_pat)
	var mat_accent := make_retro_material(accent_color, 0.45, 0.55, Color.BLACK, 0.0, "armor")
	var mat_skin := make_retro_material(skin_color, 0.84, 0.02, Color.BLACK, 0.0, "scales" if is_murloc else ("fur" if is_kobold else ""))
	var mat_pants := make_retro_material(pants_color, 0.88, 0.05, Color.BLACK, 0.0, "scales" if is_murloc else "cloth")
	var mat_boots := make_retro_material(pants_color.darkened(0.25), 0.76, 0.15)
	var mat_cape := make_retro_material(cape_color, 0.90, 0.0, Color.BLACK, 0.0, "cloth")
	var mat_hair := make_retro_material(hair_color, 0.90, 0.05, Color.BLACK, 0.0, "fur")
	var mat_eye := make_retro_material(eye_color, 0.35, 0.0, eye_color if eye_color.v > 0.55 else Color.BLACK, 1.5 if eye_color.v > 0.55 else 0.0)
	var mat_steel := make_retro_material(Color(0.74, 0.78, 0.84), 0.32, 0.78)
	var mat_wood := make_retro_material(Color(0.42, 0.26, 0.13), 0.90, 0.02, Color.BLACK, 0.0, "wood")
	var mat_claw := make_retro_material(Color(0.86, 0.80, 0.68) if is_murloc else Color(0.24, 0.20, 0.18), 0.55, 0.08)
	var mat_tooth := make_retro_material(Color(0.95, 0.93, 0.86), 0.42, 0.05)
	var mat_web := make_retro_material(skin_color.lightened(0.18), 0.76, 0.05)

	var rig := Node3D.new()
	rig.name = "HumanoidRig"
	rig.scale = Vector3.ONE * scale_factor

	var root_pivot := Node3D.new()
	root_pivot.name = "RootPivot"
	rig.add_child(root_pivot)

	# Двухсоставные ноги со сферическими суставами (без разрывов при ходьбе)
	for leg_side in [
		{"name": "LegLPivot", "knee": "KneeLPivot", "x": -0.145, "sign": -1.0},
		{"name": "LegRPivot", "knee": "KneeRPivot", "x": 0.145, "sign": 1.0},
	]:
		var leg := Node3D.new()
		leg.name = leg_side["name"]
		leg.position = Vector3(float(leg_side["x"]), 0.78, 0.0)
		root_pivot.add_child(leg)

		# Тазобедренный сустав входит внутрь таза (исключает щели)
		leg.add_child(_make_joint_cap(0.125, 0.095, mat_pants, Vector3(0.0, 0.02, 0.0), "HipJoint"))
		leg.add_child(_make_lofted_mesh([
			{"y": -0.41, "rx": 0.092, "rz": 0.102, "shade": 0.78},
			{"y": -0.18, "rx": 0.118, "rz": 0.125, "shade": 0.94},
			{"y": 0.06, "rx": 0.128, "rz": 0.135, "shade": 1.0},
		], 8, mat_pants, Vector3.ZERO, Vector3.ZERO, "Thigh"))

		var knee := Node3D.new()
		knee.name = leg_side["knee"]
		knee.position = Vector3(0.0, -0.37, 0.0)
		leg.add_child(knee)

		# Коленный шарнир-перехлёст + наколенник
		knee.add_child(_make_joint_cap(0.098, 0.085, mat_skin if is_beast else mat_pants, Vector3.ZERO, "KneeJoint"))
		if not is_murloc:
			knee.add_child(_make_lofted_mesh([
				{"y": -0.01, "rx": 0.098, "rz": 0.108, "oz": -0.01, "shade": 0.85},
				{"y": 0.08, "rx": 0.106, "rz": 0.116, "oz": -0.025, "shade": 1.06},
			], 6, mat_accent, Vector3.ZERO, Vector3.ZERO, "KneePad"))

		if is_beast:
			# Голень зверя/мурлока + когтистая лапа с фалангами
			var mat_shin: Material = mat_skin if is_murloc else mat_pants
			knee.add_child(_make_lofted_mesh([
				{"y": -0.34, "rx": 0.068, "rz": 0.075, "shade": 0.78},
				{"y": -0.18, "rx": 0.086, "rz": 0.095, "shade": 0.94},
				{"y": 0.04, "rx": 0.102, "rz": 0.110, "shade": 1.02},
			], 8, mat_shin, Vector3.ZERO, Vector3.ZERO, "Shin"))
			var foot_node := _make_beast_foot_with_claws(mat_skin, mat_claw, mat_web, is_murloc, 1.0, "BeastFoot")
			foot_node.position = Vector3(0.0, -0.41, 0.0)
			knee.add_child(foot_node)
		else:
			# Сапог с меховым/золотым отворотом и носком
			knee.add_child(_make_lofted_mesh([
				{"y": -0.41, "rx": 0.115, "rz": 0.155, "oz": -0.04, "shade": 0.72},
				{"y": -0.28, "rx": 0.095, "rz": 0.115, "oz": -0.01, "shade": 0.88},
				{"y": -0.04, "rx": 0.120, "rz": 0.130, "shade": 1.02},
				{"y": 0.04, "rx": 0.105, "rz": 0.115, "shade": 1.04},
			], 8, mat_boots, Vector3.ZERO, Vector3.ZERO, "Boot"))
			knee.add_child(_make_lofted_mesh([
				{"y": -0.10, "rx": 0.128, "rz": 0.138, "shade": 0.88},
				{"y": -0.03, "rx": 0.132, "rz": 0.142, "shade": 1.08},
			], 8, mat_accent, Vector3.ZERO, Vector3.ZERO, "BootCuff"))

	# V-образный мускулистый торс + опущенный пояс-юбка (полное перекрытие таза!)
	var torso_pivot := Node3D.new()
	torso_pivot.name = "TorsoPivot"
	torso_pivot.position = Vector3(0.0, 0.76, 0.0)
	root_pivot.add_child(torso_pivot)

	# Таз и широкий ремень
	torso_pivot.add_child(_make_lofted_mesh([
		{"y": -0.12, "rx": 0.255, "rz": 0.175, "shade": 0.70},
		{"y": 0.0, "rx": 0.245, "rz": 0.165, "shade": 0.86},
		{"y": 0.12, "rx": 0.230, "rz": 0.155, "shade": 0.98},
	], 8, mat_boots, Vector3.ZERO, Vector3.ZERO, "PelvisBelt"))
	torso_pivot.add_child(_make_lofted_mesh([
		{"y": -0.02, "rx": 0.092, "rz": 0.032, "shade": 0.85},
		{"y": 0.09, "rx": 0.092, "rz": 0.032, "shade": 1.12},
	], 6, mat_accent, Vector3(0, 0.01, -0.155), Vector3.ZERO, "Buckle"))

	# Набедренные пластины / фалды / подол мантии (прикрывают стык бедер)
	if archetype in ["warrior", "guard"] or is_boss:
		for ts in [-1.0, 1.0]:
			torso_pivot.add_child(_make_lofted_mesh([
				{"y": -0.17, "rx": 0.035, "rz": 0.115, "shade": 0.76},
				{"y": -0.03, "rx": 0.030, "rz": 0.125, "shade": 0.96},
				{"y": 0.04, "rx": 0.025, "rz": 0.105, "shade": 1.05},
			], 6, mat_armor, Vector3(ts * 0.23, 0.0, 0.0), Vector3(0, 0, -ts * 12.0), "Tasset"))
	elif archetype == "mage":
		torso_pivot.add_child(_make_lofted_mesh([
			{"y": -0.20, "rx": 0.295, "rz": 0.225, "shade": 0.74},
			{"y": 0.02, "rx": 0.235, "rz": 0.170, "shade": 0.96},
		], 8, mat_armor, Vector3.ZERO, Vector3.ZERO, "RobeSkirt"))

	# Поясной подсумок на ремне
	torso_pivot.add_child(_make_box_mesh(Vector3(0.075, 0.11, 0.10), mat_wood, Vector3(-0.245, 0.03, -0.06), Vector3(0, 0, 8), "BeltPouch"))

	# Скульптурная грудь с плечевыми чашками
	torso_pivot.add_child(_make_lofted_mesh([
		{"y": 0.08, "rx": 0.225, "rz": 0.145, "shade": 0.78},
		{"y": 0.28, "rx": 0.275, "rz": 0.185, "oz": -0.02, "shade": 0.94},
		{"y": 0.49, "rx": 0.335, "rz": 0.205, "oz": -0.03, "shade": 1.04},
		{"y": 0.61, "rx": 0.245, "rz": 0.160, "shade": 0.98},
	], 8, mat_armor, Vector3.ZERO, Vector3.ZERO, "Chest"))

	# Воротник / горловина, принимающая шею без щели
	torso_pivot.add_child(_make_lofted_mesh([
		{"y": 0.56, "rx": 0.16, "rz": 0.15, "shade": 0.85},
		{"y": 0.64, "rx": 0.14, "rz": 0.135, "shade": 1.04},
	], 8, mat_accent if archetype in ["warrior", "guard", "mage"] else mat_boots, Vector3.ZERO, Vector3.ZERO, "Collar"))

	# Нагрудный табард или крестовая кожаная портупея (разбойники/кобольды/охотники)
	if archetype in ["bandit", "rogue", "hunter"] or is_kobold:
		torso_pivot.add_child(_make_box_mesh(Vector3(0.075, 0.58, 0.41), mat_boots, Vector3(0.0, 0.32, 0.0), Vector3(0, 0, 34), "BandolierA"))
		torso_pivot.add_child(_make_box_mesh(Vector3(0.075, 0.58, 0.41), mat_boots, Vector3(0.0, 0.32, 0.0), Vector3(0, 0, -34), "BandolierB"))
		if archetype == "hunter":
			var quiver := Node3D.new()
			quiver.name = "Quiver"
			quiver.position = Vector3(0.18, 0.38, 0.21)
			quiver.rotation_degrees = Vector3(14, 0, -18)
			torso_pivot.add_child(quiver)
			quiver.add_child(_make_prism_or_cyl(0.055, 0.042, 0.46, 6, mat_wood, Vector3.ZERO, Vector3.ZERO, "QuiverTube"))
			var mat_fletch := make_retro_material(Color(0.92, 0.90, 0.82), 0.7, 0.0)
			for qx in [-0.02, 0.02]:
				quiver.add_child(_make_box_mesh(Vector3(0.02, 0.12, 0.03), mat_fletch, Vector3(qx, 0.27, 0.0), Vector3(0, 20, 0), "ArrowFletch"))
	else:
		torso_pivot.add_child(_make_lofted_mesh([
			{"y": -0.10, "rx": 0.14, "rz": 0.025, "oz": -0.01, "shade": 0.76},
			{"y": 0.22, "rx": 0.15, "rz": 0.025, "oz": -0.02, "shade": 0.95},
			{"y": 0.48, "rx": 0.17, "rz": 0.025, "oz": -0.02, "shade": 1.05},
		], 4, mat_accent if archetype == "guard" else mat_cape, Vector3(0, 0.02, -0.188), Vector3.ZERO, "Tabard"))
	if armor_tier >= 2 and not is_kobold:
		torso_pivot.add_child(_make_prism_or_cyl(0.085, 0.085, 0.035, 6, mat_accent, Vector3(0, 0.36, -0.195), Vector3(90, 0, 0), "ChestMedallion"))

	# Спинной гребень мурлока
	if is_murloc:
		var mat_fin := make_retro_material(accent_color, 0.68, 0.05)
		for fi in range(4):
			var fy: float = 0.50 - float(fi) * 0.11
			var flen: float = 0.24 - float(fi) * 0.03
			torso_pivot.add_child(_make_fur_tuft(mat_fin, flen, 0.035, Vector3(0, fy, 0.18), Vector3(64.0 + float(fi) * 6.0, 0, 0), "BackFin_%d" % fi))

	# Двухсегментный хвост у кобольда и мурлока
	if is_beast:
		var tail_piv := Node3D.new()
		tail_piv.name = "TailPivot"
		tail_piv.position = Vector3(0.0, 0.02, 0.15)
		torso_pivot.add_child(tail_piv)
		var mat_tail: Material = make_retro_material(Color(0.68, 0.46, 0.42), 0.85, 0.02) if is_kobold else mat_skin
		tail_piv.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.045, "rz": 0.045, "shade": 0.82},
			{"y": 0.34, "rx": 0.028, "rz": 0.028, "shade": 1.0},
		], 6, mat_tail, Vector3.ZERO, Vector3(118, 0, 0), "TailBase"))
		var tail_tip := Node3D.new()
		tail_tip.name = "TailTipPivot"
		tail_tip.position = Vector3(0.0, -0.16, 0.30)
		tail_piv.add_child(tail_tip)
		tail_tip.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.028, "rz": 0.028, "shade": 0.90},
			{"y": 0.30, "rx": 0.008, "rz": 0.020 if is_murloc else 0.008, "shade": 1.08},
		], 5, mat_web if is_murloc else mat_tail, Vector3.ZERO, Vector3(95, 0, 0), "TailTip"))

	# Двухсегментный трапециевидный плащ
	if has_cape:
		var cape_pivot := Node3D.new()
		cape_pivot.name = "CapePivot"
		cape_pivot.position = Vector3(0, 0.56, 0.175)
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

	# Скульптурная голова с шеей без зазора
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, 0.60, 0.0)
	torso_pivot.add_child(head_pivot)

	# Шея глубоко входит в воротник (до y = -0.09)
	head_pivot.add_child(_make_lofted_mesh([
		{"y": -0.09, "rx": 0.115, "rz": 0.115, "shade": 0.72},
		{"y": 0.06, "rx": 0.105, "rz": 0.105, "shade": 0.90},
	], 8, mat_skin, Vector3.ZERO, Vector3.ZERO, "Neck"))

	head_pivot.add_child(_make_lofted_mesh([
		{"y": 0.02, "rx": 0.105, "rz": 0.105, "shade": 0.76},
		{"y": 0.09, "rx": 0.148, "rz": 0.158, "oz": -0.02, "shade": 0.88},
		{"y": 0.23, "rx": 0.175, "rz": 0.185, "oz": -0.01, "shade": 1.00},
		{"y": 0.34, "rx": 0.155, "rz": 0.165, "oz": 0.01, "shade": 1.04},
		{"y": 0.40, "rx": 0.085, "rz": 0.095, "oz": 0.02, "shade": 1.06},
	], 8, mat_skin, Vector3.ZERO, Vector3.ZERO, "Head"))

	# Глаза и рельефный нос
	head_pivot.add_child(_make_box_mesh(Vector3(0.055, 0.04, 0.045), mat_eye, Vector3(-0.075, 0.23, -0.165), Vector3.ZERO, "EyeL"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.055, 0.04, 0.045), mat_eye, Vector3(0.075, 0.23, -0.165), Vector3.ZERO, "EyeR"))

	if is_kobold:
		var mat_ear := make_retro_material(skin_color.darkened(0.14), 0.85, 0.02)
		var mat_pink := make_retro_material(Color(0.78, 0.48, 0.46), 0.75, 0.02)
		# Длинная крысиная морда + розовый носик + два торчащих резца
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.088, "rz": 0.075, "shade": 0.86},
			{"y": 0.20, "rx": 0.042, "rz": 0.036, "shade": 1.02},
		], 6, mat_skin, Vector3(0, 0.15, -0.12), Vector3(-94, 0, 0), "Snout"))
		head_pivot.add_child(_make_box_mesh(Vector3(0.05, 0.042, 0.045), mat_pink, Vector3(0, 0.14, -0.32), Vector3.ZERO, "RatNose"))
		head_pivot.add_child(_make_box_mesh(Vector3(0.024, 0.048, 0.022), mat_tooth, Vector3(-0.024, 0.095, -0.27), Vector3(12, 0, 0), "ToothL"))
		head_pivot.add_child(_make_box_mesh(Vector3(0.024, 0.048, 0.022), mat_tooth, Vector3(0.024, 0.095, -0.27), Vector3(12, 0, 0), "ToothR"))
		for es in [-1.0, 1.0]:
			head_pivot.add_child(_make_lofted_mesh([
				{"y": 0.0, "rx": 0.062, "rz": 0.032, "shade": 0.82},
				{"y": 0.20, "rx": 0.015, "rz": 0.015, "shade": 1.05},
			], 5, mat_ear, Vector3(es * 0.155, 0.24, 0.02), Vector3(0, 0, -es * 36), "Ear"))
			head_pivot.add_child(_make_box_mesh(Vector3(0.04, 0.09, 0.015), mat_pink, Vector3(es * 0.18, 0.28, 0.0), Vector3(0, 0, -es * 36), "EarInner"))
		if is_boss:
			for hs in [-1.0, 1.0]:
				head_pivot.add_child(_make_lofted_mesh([
					{"y": 0.0, "rx": 0.042, "rz": 0.042, "shade": 0.80},
					{"y": 0.18, "rx": 0.014, "rz": 0.014, "ox": hs * 0.04, "shade": 1.12},
				], 5, mat_claw, Vector3(hs * 0.14, 0.34, -0.02), Vector3(12, 0, -hs * 28), "BossHorn"))
	elif is_murloc:
		var mat_fin := make_retro_material(accent_color, 0.68, 0.05)
		# Выпуклая челюсть с острыми белыми зубами, жабрами и усами
		head_pivot.add_child(_make_lofted_mesh([
			{"y": 0.06, "rx": 0.215, "rz": 0.205, "oz": -0.05, "shade": 0.84},
			{"y": 0.19, "rx": 0.190, "rz": 0.180, "oz": -0.04, "shade": 1.02},
		], 8, mat_skin, Vector3.ZERO, Vector3.ZERO, "MurlocJaw"))
		for tx in [-0.09, -0.045, 0.0, 0.045, 0.09]:
			head_pivot.add_child(_make_box_mesh(Vector3(0.022, 0.036, 0.020), mat_tooth, Vector3(tx, 0.125, -0.245), Vector3(10, 0, 0), "Tooth"))
		for gs in [-1.0, 1.0]:
			head_pivot.add_child(_make_box_mesh(Vector3(0.035, 0.12, 0.065), mat_fin, Vector3(gs * 0.19, 0.15, 0.01), Vector3(12, 0, -gs * 15), "Gills"))
			head_pivot.add_child(_make_lofted_mesh([
				{"y": 0.0, "rx": 0.016, "rz": 0.016, "shade": 0.85},
				{"y": 0.18, "rx": 0.005, "rz": 0.005, "oz": 0.03, "shade": 1.05},
			], 4, mat_fin, Vector3(gs * 0.16, 0.10, -0.18), Vector3(65, 0, -gs * 48), "Barbel"))
		# Зубчатый гребень на голове
		for hi in range(3):
			head_pivot.add_child(_make_fur_tuft(mat_fin, 0.22 - float(hi) * 0.03, 0.035, Vector3(0, 0.35 - float(hi) * 0.05, 0.02 + float(hi) * 0.07), Vector3(26.0 + float(hi) * 18.0, 0, 0), "HeadCrest_%d" % hi))
	else:
		# Человеческий нос и надбровье
		head_pivot.add_child(_make_box_mesh(Vector3(0.042, 0.055, 0.045), mat_skin, Vector3(0.0, 0.18, -0.18), Vector3.ZERO, "Nose"))
		if archetype == "mage":
			var mat_hat := make_retro_material(armor_color.darkened(0.16), 0.84, 0.05, Color.BLACK, 0.0, "cloth")
			head_pivot.add_child(_make_lofted_mesh([
				{"y": 0.31, "rx": 0.32, "rz": 0.32, "shade": 0.82},
				{"y": 0.35, "rx": 0.29, "rz": 0.29, "shade": 0.98},
				{"y": 0.56, "rx": 0.14, "rz": 0.14, "oz": 0.03, "shade": 1.04},
				{"y": 0.82, "rx": 0.02, "rz": 0.02, "oz": 0.09, "shade": 1.08},
			], 8, mat_hat, Vector3.ZERO, Vector3.ZERO, "WizardHat"))
			head_pivot.add_child(_make_lofted_mesh([
				{"y": 0.35, "rx": 0.215, "rz": 0.215, "shade": 0.90},
				{"y": 0.41, "rx": 0.20, "rz": 0.20, "shade": 1.10},
			], 8, mat_accent, Vector3.ZERO, Vector3.ZERO, "HatBand"))
			head_pivot.add_child(_make_lofted_mesh([
				{"y": 0.05, "rx": 0.16, "rz": 0.10, "shade": 0.78},
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
		elif archetype == "hunter":
			var mat_hood := make_retro_material(armor_color.darkened(0.14), 0.86, 0.04, Color.BLACK, 0.0, "cloth")
			head_pivot.add_child(_make_lofted_mesh([
				{"y": 0.22, "rx": 0.195, "rz": 0.21, "oz": 0.03, "shade": 0.82},
				{"y": 0.36, "rx": 0.185, "rz": 0.21, "oz": 0.02, "shade": 1.0},
				{"y": 0.44, "rx": 0.09, "rz": 0.14, "oz": 0.06, "shade": 1.06},
			], 8, mat_hood, Vector3.ZERO, Vector3.ZERO, "RangerHood"))
			head_pivot.add_child(_make_lofted_mesh([
				{"y": 0.05, "rx": 0.15, "rz": 0.09, "shade": 0.78},
				{"y": 0.25, "rx": 0.18, "rz": 0.10, "shade": 1.0},
			], 6, mat_hair, Vector3(0, 0, 0.10), Vector3.ZERO, "HairBack"))
		elif archetype == "guard":
			head_pivot.add_child(_make_lofted_mesh([
				{"y": 0.22, "rx": 0.19, "rz": 0.20, "shade": 0.84},
				{"y": 0.36, "rx": 0.17, "rz": 0.18, "shade": 1.02},
				{"y": 0.43, "rx": 0.09, "rz": 0.10, "shade": 1.08},
			], 8, mat_steel, Vector3.ZERO, Vector3.ZERO, "Helm"))
			head_pivot.add_child(_make_box_mesh(Vector3(0.03, 0.13, 0.03), mat_steel, Vector3(0, 0.24, -0.195), Vector3.ZERO, "NasalGuard"))
			head_pivot.add_child(_make_box_mesh(Vector3(0.04, 0.14, 0.12), mat_steel, Vector3(-0.165, 0.16, -0.04), Vector3.ZERO, "CheekL"))
			head_pivot.add_child(_make_box_mesh(Vector3(0.04, 0.14, 0.12), mat_steel, Vector3(0.165, 0.16, -0.04), Vector3.ZERO, "CheekR"))
			head_pivot.add_child(_make_lofted_mesh([
				{"y": 0.36, "rx": 0.035, "rz": 0.22, "shade": 0.88},
				{"y": 0.50, "rx": 0.02, "rz": 0.18, "oz": 0.03, "shade": 1.12},
			], 4, mat_accent, Vector3.ZERO, Vector3.ZERO, "HelmCrest"))
		else:
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
		head_pivot.add_child(_make_prism_or_cyl(0.085, 0.095, 0.025, 6, mat_accent, Vector3(0, 0.39, 0), Vector3.ZERO, "CandleHolder"))
		head_pivot.add_child(_make_prism_or_cyl(0.058, 0.072, 0.24, 6, mat_wax, Vector3(0, 0.50, 0), Vector3.ZERO, "CandleWax"))
		head_pivot.add_child(_make_prism_or_cyl(0.005, 0.048, 0.14, 5, mat_flame, Vector3(0, 0.67, 0), Vector3.ZERO, "CandleFlame"))

	# Двухсоставные руки: плечо глубоко в торсе (x = ±0.295), шаровой сустав, локтевой сустав и кисть с пальцами!
	var pauldron_mat: Material = mat_accent if not is_kobold else mat_armor
	var arm_armored: bool = archetype in ["warrior", "guard"] or is_boss
	for arm_side in [
		{"name": "ArmLPivot", "elbow": "ElbowLPivot", "x": -0.295, "sign": -1.0},
		{"name": "ArmRPivot", "elbow": "ElbowRPivot", "x": 0.295, "sign": 1.0},
	]:
		var s: float = float(arm_side["sign"])
		var arm := Node3D.new()
		arm.name = arm_side["name"]
		arm.position = Vector3(float(arm_side["x"]), 0.50, 0.0)
		torso_pivot.add_child(arm)

		# Плечевой сустав + рука входят внутрь грудной клетки без просвета
		arm.add_child(_make_joint_cap(0.112, 0.088, mat_armor, Vector3(-s * 0.025, 0.0, 0.0), "ShoulderJoint"))
		arm.add_child(_make_pauldron(pauldron_mat, mat_armor if not is_kobold else mat_accent, s, "Pauldron", is_boss or armor_tier >= 2))
		arm.add_child(_make_lofted_mesh([
			{"y": -0.30, "rx": 0.078, "rz": 0.082, "shade": 0.78},
			{"y": 0.03, "rx": 0.098, "rz": 0.102, "shade": 1.0},
		], 8, mat_armor, Vector3(s * 0.02, 0.0, 0.0), Vector3.ZERO, "UpperArm"))

		var elbow := Node3D.new()
		elbow.name = arm_side["elbow"]
		elbow.position = Vector3(s * 0.02, -0.26, 0.0)
		arm.add_child(elbow)

		# Локтевой шаровой шарнир (перекрывает и плечо, и предплечье)
		elbow.add_child(_make_joint_cap(0.088, 0.075, mat_skin if is_beast else mat_boots, Vector3.ZERO, "ElbowJoint"))
		# Наруч / перчатка (верх заходит на сустав y = +0.03)
		elbow.add_child(_make_lofted_mesh([
			{"y": -0.24, "rx": 0.074, "rz": 0.078, "shade": 0.76},
			{"y": -0.10, "rx": 0.092, "rz": 0.096, "shade": 0.96},
			{"y": 0.03, "rx": 0.102, "rz": 0.106, "shade": 1.06},
		], 8, mat_boots if arm_armored else mat_armor, Vector3.ZERO, Vector3.ZERO, "Gauntlet"))

		var has_item_in_hand: bool = (s > 0.0) or (s < 0.0 and has_offhand_dagger)
		var hand_mat: Material = mat_boots if arm_armored else mat_skin
		var hand_node := _make_hand_with_fingers(hand_mat, mat_claw, mat_web if is_murloc else mat_accent, is_beast, is_murloc, arm_armored, s, has_item_in_hand, "Hand")
		hand_node.position = Vector3(0.0, -0.24, -0.01)
		elbow.add_child(hand_node)

		if s < 0.0:
			if has_shield:
				var shield_grp := Node3D.new()
				shield_grp.name = "ShieldMesh"
				shield_grp.position = Vector3(-0.125, -0.14, -0.04)
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
				off_dagger.position = Vector3(0.0, -0.29, -0.05)
				elbow.add_child(off_dagger)
		else:
			var weapon_node := _build_weapon(weapon_type, mat_steel, mat_accent, mat_wood)
			weapon_node.name = "WeaponMesh"
			weapon_node.position = Vector3(0.0, -0.29, -0.05)
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
	elif weapon_type == "bow":
		var mat_string := make_retro_material(Color(0.86, 0.84, 0.78), 0.7, 0.0)
		w.add_child(_make_lofted_mesh([
			{"y": -0.10, "rx": 0.026, "rz": 0.026, "shade": 0.85},
			{"y": 0.10, "rx": 0.026, "rz": 0.026, "shade": 1.02},
		], 6, mat_accent, Vector3(0, 0, -0.02), Vector3.ZERO, "BowGrip"))
		w.add_child(_make_lofted_mesh([
			{"y": 0.0, "rx": 0.024, "rz": 0.028, "shade": 0.85},
			{"y": 0.24, "rx": 0.020, "rz": 0.024, "oz": 0.06, "shade": 0.98},
			{"y": 0.44, "rx": 0.012, "rz": 0.015, "oz": 0.18, "shade": 1.08},
		], 5, mat_wood, Vector3(0, 0.09, -0.02), Vector3.ZERO, "UpperLimb"))
		w.add_child(_make_lofted_mesh([
			{"y": -0.44, "rx": 0.012, "rz": 0.015, "oz": 0.18, "shade": 0.82},
			{"y": -0.24, "rx": 0.020, "rz": 0.024, "oz": 0.06, "shade": 0.94},
			{"y": 0.0, "rx": 0.024, "rz": 0.028, "shade": 1.02},
		], 5, mat_wood, Vector3(0, -0.09, -0.02), Vector3.ZERO, "LowerLimb"))
		w.add_child(_make_box_mesh(Vector3(0.010, 1.04, 0.010), mat_string, Vector3(0, 0.0, 0.16), Vector3.ZERO, "BowString"))
		w.add_child(_make_prism_or_cyl(0.012, 0.012, 0.62, 5, mat_wood, Vector3(0.02, 0.02, -0.10), Vector3(-90, 0, 0), "NockedArrow"))
		w.add_child(_make_prism_or_cyl(0.002, 0.026, 0.10, 4, mat_steel, Vector3(0.02, 0.02, -0.44), Vector3(-90, 0, 0), "ArrowHead"))
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
		], 4, mat_steel, Vector3(0, 0, -0.66), Vector3.ZERO, "PickHead"))
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
	var mat_mane := make_retro_material(fur_color.darkened(0.24), 0.95, 0.0, Color.BLACK, 0.0, "fur")
	var mat_snout := make_retro_material(fur_color.lightened(0.08), 0.92, 0.0, Color.BLACK, 0.0, "fur")
	var mat_belly := make_retro_material(belly_color, 0.92, 0.0, Color.BLACK, 0.0, "fur")
	var mat_eye := make_retro_material(eye_color, 0.3, 0.0, eye_color, 1.6)
	var mat_nose := make_retro_material(Color(0.08, 0.08, 0.09), 0.5, 0.1)
	var mat_claw := make_retro_material(Color(0.18, 0.16, 0.15), 0.52, 0.1)
	var mat_tooth := make_retro_material(Color(0.95, 0.93, 0.86), 0.4, 0.05)

	var rig := Node3D.new()
	rig.name = "WolfRig"
	rig.scale = Vector3.ONE * scale_factor

	var root_pivot := Node3D.new()
	root_pivot.name = "RootPivot"
	rig.add_child(root_pivot)

	var body_pivot := Node3D.new()
	body_pivot.name = "BodyPivot"
	body_pivot.position = Vector3(0, 0.65, 0)
	root_pivot.add_child(body_pivot)

	# Скульптурное тело волка (широкая грудь, талия, круп, мощная шея)
	body_pivot.add_child(_make_lofted_mesh([
		{"y": -0.50, "rx": 0.185, "rz": 0.195, "shade": 0.80},
		{"y": -0.15, "rx": 0.175, "rz": 0.175, "oz": 0.02, "shade": 0.92},
		{"y": 0.22, "rx": 0.245, "rz": 0.245, "shade": 1.02},
		{"y": 0.49, "rx": 0.205, "rz": 0.215, "oz": -0.02, "shade": 0.96},
	], 8, mat_fur, Vector3.ZERO, Vector3(-90, 0, 0), "Torso"))
	body_pivot.add_child(_make_lofted_mesh([
		{"y": -0.16, "rx": 0.235, "rz": 0.245, "shade": 0.84},
		{"y": 0.18, "rx": 0.225, "rz": 0.235, "oz": -0.04, "shade": 1.04},
	], 8, mat_mane, Vector3(0, 0.08, -0.34), Vector3(-68, 0, 0), "NeckBridge"))
	body_pivot.add_child(_make_box_mesh(Vector3(0.24, 0.08, 0.72), mat_belly, Vector3(0, -0.17, 0), Vector3.ZERO, "Belly"))

	# Пышный мех: густая причёсанная назад волчья грива на загривке, холке и хребте
	for mi in range(7):
		var frac: float = float(mi) / 6.0 - 0.5
		var ang_y: float = frac * 115.0
		var rad_y: float = deg_to_rad(ang_y)
		var tuft_pos := Vector3(sin(rad_y) * 0.22, 0.16 - absf(frac) * 0.16, -0.32 + absf(frac) * 0.10)
		var tuft_mat: Material = mat_mane if (mi % 2 == 0) else mat_fur
		body_pivot.add_child(_make_fur_tuft(tuft_mat, 0.25 - absf(frac) * 0.04, 0.078, tuft_pos, Vector3(76, ang_y * 0.45, 0), "ManeTuftA_%d" % mi))
	for mi in range(5):
		var frac: float = float(mi) / 4.0 - 0.5
		var ang_y: float = frac * 90.0
		var rad_y: float = deg_to_rad(ang_y)
		var tuft_pos := Vector3(sin(rad_y) * 0.19, 0.20 - absf(frac) * 0.12, -0.17 + absf(frac) * 0.07)
		body_pivot.add_child(_make_fur_tuft(mat_mane, 0.22, 0.072, tuft_pos, Vector3(78, ang_y * 0.40, 0), "ManeTuftB_%d" % mi))
	for bi in range(4):
		var bz: float = -0.02 + float(bi) * 0.14
		body_pivot.add_child(_make_fur_tuft(mat_mane, 0.18 - float(bi) * 0.015, 0.056, Vector3(0, 0.185 - float(bi) * 0.01, bz), Vector3(76, 0, 0), "SpineFur_%d" % bi))

	# Голова, баки, пасть с нижней челюстью и клыками
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0, 0.20, -0.47)
	body_pivot.add_child(head_pivot)
	head_pivot.add_child(_make_lofted_mesh([
		{"y": -0.14, "rx": 0.16, "rz": 0.16, "shade": 0.84},
		{"y": 0.14, "rx": 0.18, "rz": 0.17, "shade": 1.02},
		{"y": 0.24, "rx": 0.10, "rz": 0.10, "shade": 1.06},
	], 8, mat_fur, Vector3(0, 0.06, -0.08), Vector3(-72, 0, 0), "Skull"))
	# Меховые баки на скулах
	for cs in [-1.0, 1.0]:
		head_pivot.add_child(_make_fur_tuft(mat_mane, 0.16, 0.045, Vector3(cs * 0.15, 0.03, -0.07), Vector3(72, cs * 55, 0), "CheekFur"))
		head_pivot.add_child(_make_fur_tuft(mat_mane, 0.13, 0.038, Vector3(cs * 0.13, 0.10, -0.04), Vector3(65, cs * 42, 0), "CheekFurTop"))

	# Верхняя морда + нос + верхние клыки
	head_pivot.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": 0.098, "rz": 0.072, "shade": 0.88},
		{"y": 0.26, "rx": 0.052, "rz": 0.042, "shade": 1.02},
	], 6, mat_snout, Vector3(0, 0.025, -0.20), Vector3(-92, 0, 0), "UpperSnout"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.075, 0.052, 0.052), mat_nose, Vector3(0, 0.032, -0.465), Vector3.ZERO, "Nose"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.022, 0.042, 0.022), mat_tooth, Vector3(-0.036, -0.020, -0.415), Vector3.ZERO, "UpperFangL"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.022, 0.042, 0.022), mat_tooth, Vector3(0.036, -0.020, -0.415), Vector3.ZERO, "UpperFangR"))

	# Подвижная нижняя челюсть с клыками
	var jaw_pivot := Node3D.new()
	jaw_pivot.name = "JawPivot"
	jaw_pivot.position = Vector3(0.0, -0.032, -0.19)
	head_pivot.add_child(jaw_pivot)
	jaw_pivot.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": 0.078, "rz": 0.032, "shade": 0.80},
		{"y": 0.22, "rx": 0.044, "rz": 0.025, "shade": 0.96},
	], 6, mat_belly, Vector3.ZERO, Vector3(-90, 0, 0), "LowerJaw"))
	jaw_pivot.add_child(_make_box_mesh(Vector3(0.018, 0.036, 0.018), mat_tooth, Vector3(-0.028, 0.022, -0.19), Vector3.ZERO, "LowerFangL"))
	jaw_pivot.add_child(_make_box_mesh(Vector3(0.018, 0.036, 0.018), mat_tooth, Vector3(0.028, 0.022, -0.19), Vector3.ZERO, "LowerFangR"))

	head_pivot.add_child(_make_box_mesh(Vector3(0.055, 0.045, 0.045), mat_eye, Vector3(-0.09, 0.11, -0.25), Vector3.ZERO, "EyeL"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.055, 0.045, 0.045), mat_eye, Vector3(0.09, 0.11, -0.25), Vector3.ZERO, "EyeR"))
	head_pivot.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": 0.048, "rz": 0.038, "shade": 0.84},
		{"y": 0.18, "rx": 0.01, "rz": 0.01, "shade": 1.06},
	], 4, mat_mane, Vector3(-0.11, 0.18, -0.04), Vector3(0, 0, 14), "EarL"))
	head_pivot.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": 0.048, "rz": 0.038, "shade": 0.84},
		{"y": 0.18, "rx": 0.01, "rz": 0.01, "shade": 1.06},
	], 4, mat_mane, Vector3(0.11, 0.18, -0.04), Vector3(0, 0, -14), "EarR"))

	# Двухсегментный пушистый хвост с прядями меха
	var tail_pivot := Node3D.new()
	tail_pivot.name = "TailPivot"
	tail_pivot.position = Vector3(0, 0.08, 0.44)
	body_pivot.add_child(tail_pivot)
	tail_pivot.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": 0.072, "rz": 0.072, "shade": 0.85},
		{"y": 0.30, "rx": 0.095, "rz": 0.095, "shade": 1.0},
	], 6, mat_mane, Vector3.ZERO, Vector3(114, 0, 0), "TailBase"))
	tail_pivot.add_child(_make_fur_tuft(mat_fur, 0.16, 0.042, Vector3(0, -0.04, 0.18), Vector3(84, 0, 0), "TailTuftA"))
	var tail_tip := Node3D.new()
	tail_tip.name = "TailTipPivot"
	tail_tip.position = Vector3(0, -0.12, 0.27)
	tail_pivot.add_child(tail_tip)
	tail_tip.add_child(_make_lofted_mesh([
		{"y": 0.0, "rx": 0.09, "rz": 0.09, "shade": 0.90},
		{"y": 0.24, "rx": 0.065, "rz": 0.065, "shade": 1.02},
		{"y": 0.32, "rx": 0.015, "rz": 0.015, "shade": 1.12},
	], 6, mat_fur, Vector3.ZERO, Vector3(88, 0, 0), "TailTip"))

	# 4 двухсоставные лапы с крупными суставами, очесами меха, фалангами и когтями!
	var leg_offsets: Dictionary = {
		"LegFL": Vector3(-0.165, -0.08, -0.30),
		"LegFR": Vector3(0.165, -0.08, -0.30),
		"LegBL": Vector3(-0.170, -0.08, 0.29),
		"LegBR": Vector3(0.170, -0.08, 0.29),
	}
	for leg_name in leg_offsets.keys():
		var lp := Node3D.new()
		lp.name = leg_name
		lp.position = leg_offsets[leg_name]
		body_pivot.add_child(lp)
		# Плечевая/тазобедренная головка глубоко входит в бок корпуса (без щелей!)
		lp.add_child(_make_joint_cap(0.105, 0.095, mat_fur, Vector3(0, 0.02, 0), "HipCap"))
		lp.add_child(_make_lofted_mesh([
			{"y": -0.28, "rx": 0.065, "rz": 0.072, "shade": 0.80},
			{"y": 0.05, "rx": 0.095, "rz": 0.108, "shade": 1.0},
		], 6, mat_fur, Vector3.ZERO, Vector3.ZERO, "UpperLeg"))
		lp.add_child(_make_fur_tuft(mat_mane, 0.14, 0.038, Vector3(0, -0.12, 0.055), Vector3(158, 0, 0), "LegFringe"))

		var lower := Node3D.new()
		lower.name = "Lower"
		lower.position = Vector3(0, -0.27, 0)
		lp.add_child(lower)
		lower.add_child(_make_joint_cap(0.072, 0.062, mat_fur, Vector3.ZERO, "HockJoint"))
		lower.add_child(_make_lofted_mesh([
			{"y": -0.26, "rx": 0.052, "rz": 0.058, "shade": 0.78},
			{"y": 0.03, "rx": 0.062, "rz": 0.068, "shade": 0.96},
		], 6, mat_mane, Vector3.ZERO, Vector3.ZERO, "LowerLeg"))

		# Детализированная волчья лапа на земле (3 фаланговых пальца + когти)
		var paw := _make_beast_foot_with_claws(mat_fur, mat_claw, mat_fur, false, 1.04, "WolfPaw")
		paw.position = Vector3(0.0, -0.30, 0.0)
		lower.add_child(paw)

	if bool(config.get("is_pet", false)):
		var mat_collar := make_retro_material(Color(0.56, 0.14, 0.14), 0.72, 0.1)
		var mat_tag := make_retro_material(Color(0.92, 0.76, 0.22), 0.35, 0.65)
		body_pivot.add_child(_make_lofted_mesh([
			{"y": -0.05, "rx": 0.245, "rz": 0.245, "shade": 0.86},
			{"y": 0.05, "rx": 0.240, "rz": 0.240, "shade": 1.08},
		], 8, mat_collar, Vector3(0, 0.12, -0.40), Vector3(-55, 0, 0), "PetCollar"))
		body_pivot.add_child(_make_box_mesh(Vector3(0.08, 0.09, 0.03), mat_tag, Vector3(0, -0.02, -0.52), Vector3(18, 0, 0), "PetMedallion"))

	return rig


static func build_ore_vein(is_crystal: bool) -> Node3D:
	var root := Node3D.new()
	var mat_rock := make_retro_material(Color(0.28, 0.27, 0.30), 0.94, 0.02, Color.BLACK, 0.0, "stone")
	var base := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.55
	sph.height = 0.70
	sph.radial_segments = 6
	sph.rings = 3
	base.mesh = sph
	base.material_override = mat_rock
	base.position = Vector3(0, 0.25, 0)
	root.add_child(base)

	var mat_ore: StandardMaterial3D = (
		make_retro_material(Color(0.32, 0.82, 1.0), 0.22, 0.35, Color(0.25, 0.72, 1.0), 2.3)
		if is_crystal
		else make_retro_material(Color(0.84, 0.50, 0.22), 0.38, 0.55, Color(0.65, 0.35, 0.10), 0.8)
	)
	for sp in [
		{"pos": Vector3(0.0, 0.65, 0.0), "h": 0.85, "r": 0.19, "rot": Vector3(8, 10, -10)},
		{"pos": Vector3(-0.24, 0.48, 0.16), "h": 0.62, "r": 0.14, "rot": Vector3(18, 30, 26)},
		{"pos": Vector3(0.22, 0.45, -0.14), "h": 0.56, "r": 0.13, "rot": Vector3(-16, -22, -24)},
	]:
		root.add_child(_make_prism_or_cyl(0.02, sp["r"], sp["h"], 5, mat_ore, sp["pos"], sp["rot"], "OreShard"))
	return root


static func build_herb_cluster(herb_kind: String) -> Node3D:
	var root := Node3D.new()
	var is_silver: bool = (herb_kind == "silverleaf")
	var mat_stem := make_retro_material(Color(0.18, 0.42, 0.18), 0.90, 0.0)
	var mat_petal := (
		make_retro_material(Color(0.76, 0.92, 1.0), 0.35, 0.1, Color(0.50, 0.78, 1.0), 1.0)
		if is_silver
		else make_retro_material(Color(1.0, 0.82, 0.22), 0.38, 0.0, Color(0.85, 0.65, 0.12), 0.8)
	)
	for i in range(4):
		var ang: float = float(i) * TAU / 4.0 + 0.4
		var ox: float = cos(ang) * 0.16
		var oz: float = sin(ang) * 0.16
		var lean := Vector3(sin(ang) * 18.0, rad_to_deg(ang), -cos(ang) * 18.0)
		root.add_child(_make_prism_or_cyl(0.02, 0.035, 0.44, 4, mat_stem, Vector3(ox, 0.20, oz), lean, "Stem_%d" % i))
		root.add_child(_make_prism_or_cyl(0.09, 0.04, 0.12, 5, mat_petal, Vector3(ox * 1.45, 0.44, oz * 1.45), lean, "Bloom_%d" % i))
	return root


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
	var tail := torso.get_node_or_null("TailPivot") as Node3D if torso else null
	var tail_tip := tail.get_node_or_null("TailTipPivot") as Node3D if tail else null
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
	var arm_l_rot := Vector3(0.06, 0, -0.10)
	var arm_r_rot := Vector3(0.16, 0, 0.10)
	var elbow_l_rot := Vector3(0.24, 0, 0)
	var elbow_r_rot := Vector3(0.32, 0, 0)
	var cape_rot := Vector3(-0.08, 0, 0)
	var cape_low_rot := Vector3(-0.05, 0, 0)
	var tail_rot := Vector3(0.0, sin(anim_time * 3.0) * 0.18, 0.0)
	var tail_tip_rot := Vector3(0.0, sin(anim_time * 3.0 - 0.8) * 0.22, 0.0)
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
		knee_l_rot = Vector3(-maxf(0.12, (-s * 0.55 + c * 0.45) * 0.95), 0, 0)
		knee_r_rot = Vector3(-maxf(0.12, (s * 0.55 - c * 0.45) * 0.95), 0, 0)
		bob = absf(s) * 0.065 - 0.03
		torso_pitch += -0.28 if anim_state == "CHARGE" else -0.12
		torso_yaw = -s * 0.16
		arm_l_rot = Vector3(-s * 0.65, 0, -0.10)
		arm_r_rot = Vector3(s * 0.60 + 0.14, 0, 0.10)
		elbow_l_rot = Vector3(0.45 + maxf(0.0, -s) * 0.45, 0, 0)
		elbow_r_rot = Vector3(0.45 + maxf(0.0, s) * 0.45, 0, 0)
		cape_rot = Vector3(-0.46 - absf(s) * 0.12, 0, 0)
		cape_low_rot = Vector3(-0.22 - sin(phase - 0.8) * 0.16, 0, 0)
		tail_rot = Vector3(-0.18, sin(phase) * 0.28, 0.0)
		tail_tip_rot = Vector3(0.0, sin(phase - 0.7) * 0.34, 0.0)
	elif anim_state == "JUMP":
		leg_l_rot = Vector3(0.45, 0, -0.06)
		leg_r_rot = Vector3(0.12, 0, 0.06)
		knee_l_rot = Vector3(-0.78, 0, 0)
		knee_r_rot = Vector3(-0.42, 0, 0)
		arm_l_rot = Vector3(0.35, 0, -0.38)
		arm_r_rot = Vector3(0.35, 0, 0.38)
		elbow_l_rot = Vector3(0.65, 0, 0)
		elbow_r_rot = Vector3(0.65, 0, 0)
		torso_pitch += -0.14
		cape_rot = Vector3(-0.62, 0, 0)
		cape_low_rot = Vector3(-0.35, 0, 0)
	elif anim_state == "STUNNED":
		leg_l_rot = Vector3(0.15, 0, -0.08)
		leg_r_rot = Vector3(0.15, 0, 0.08)
		knee_l_rot = Vector3(-0.34, 0, 0)
		knee_r_rot = Vector3(-0.34, 0, 0)
		bob = -0.04
		torso_pitch += -0.22 + sin(anim_time * 3.5) * 0.06
		torso_yaw = sin(anim_time * 2.8) * 0.14
		head_rot = Vector3(-0.32 + sin(anim_time * 4.5) * 0.12, sin(anim_time * 3.2) * 0.28, cos(anim_time * 3.2) * 0.16)
		arm_l_rot = Vector3(0.12, 0, -0.18)
		arm_r_rot = Vector3(0.12, 0, 0.18)
	elif anim_state == "CAST":
		var pulse: float = sin(anim_time * 16.0) * 0.05
		bob = sin(anim_time * 8.0) * 0.02
		torso_pitch += 0.08
		leg_l_rot = Vector3(0.14, 0, -0.06)
		leg_r_rot = Vector3(-0.14, 0, 0.06)
		knee_l_rot = Vector3(-0.18, 0, 0)
		knee_r_rot = Vector3(-0.12, 0, 0)
		arm_l_rot = Vector3(1.25 + pulse, 0.22, -0.18)
		arm_r_rot = Vector3(1.38 - pulse, -0.22, 0.18)
		elbow_l_rot = Vector3(0.55, 0, 0)
		elbow_r_rot = Vector3(0.45, 0, 0)
		cape_rot = Vector3(-0.28 + pulse, 0, 0)
		cape_low_rot = Vector3(-0.18, 0, 0)
	else:
		var breath: float = sin(anim_time * 2.2)
		bob = breath * 0.020
		torso_pitch += breath * 0.02
		torso_yaw = sin(anim_time * 0.9) * 0.05
		knee_l_rot = Vector3(-0.08, 0, 0)
		knee_r_rot = Vector3(-0.08, 0, 0)
		arm_l_rot = Vector3(0.06 + breath * 0.03, 0, -0.10)
		arm_r_rot = Vector3(0.18 - breath * 0.03, 0, 0.10)
		elbow_l_rot = Vector3(0.26, 0, 0)
		elbow_r_rot = Vector3(0.36, 0, 0)
		head_rot = Vector3(-base_hunch * 0.4 + sin(anim_time * 1.4) * 0.035, sin(anim_time * 0.7) * 0.08, 0)
		cape_rot = Vector3(-0.09 - breath * 0.035, 0, 0)
		cape_low_rot = Vector3(-0.06 - sin(anim_time * 2.2 - 0.6) * 0.05, 0, 0)

	if anim_state == "WHIRLWIND":
		torso_pitch = base_hunch - 0.20
		knee_l_rot = Vector3(-0.35, 0, 0)
		knee_r_rot = Vector3(-0.35, 0, 0)
		arm_l_rot = Vector3(0.20, 0, -1.25)
		arm_r_rot = Vector3(1.35, 0.40, 1.05)
		elbow_l_rot = Vector3(0.25, 0, 0)
		elbow_r_rot = Vector3(0.15, 0, 0)
		cape_rot = Vector3(-0.82, 0, 0)
		cape_low_rot = Vector3(-0.38, 0, 0)
	elif attack_progress > 0.0 and bool(flags.get("bow_aim", false)):
		var bp: float = clampf(attack_progress, 0.0, 1.0)
		torso_yaw = 0.28
		arm_r_rot = Vector3(1.36, 0.22, 0.04)
		elbow_r_rot = Vector3(0.18, 0, 0)
		if bp < 0.48:
			var t: float = bp / 0.48
			arm_l_rot = Vector3(lerpf(0.8, 1.38, t), lerpf(-0.2, -0.55, t), -0.10)
			elbow_l_rot = Vector3(lerpf(0.5, 1.25, t), 0, 0)
		else:
			var t: float = (bp - 0.48) / 0.52
			arm_l_rot = Vector3(lerpf(1.38, 0.20, t), lerpf(-0.55, 0.0, t), -0.14)
			elbow_l_rot = Vector3(lerpf(1.25, 0.30, t), 0, 0)
	elif attack_progress > 0.0:
		var p: float = clampf(attack_progress, 0.0, 1.0)
		var dual: bool = bool(flags.get("dual_wield", false))
		if p < 0.28:
			var t: float = ease(p / 0.28, 0.5)
			arm_r_rot = Vector3(lerpf(0.2, 2.25, t), 0.25 * t, 0.28 * t)
			elbow_r_rot = Vector3(lerpf(0.35, 1.05, t), 0, 0)
			torso_yaw = -0.42 * t
			torso_pitch += 0.16 * t
			if dual:
				arm_l_rot = Vector3(lerpf(0.1, 1.65, t), -0.2 * t, -0.24 * t)
				elbow_l_rot = Vector3(0.95, 0, 0)
			else:
				arm_l_rot = Vector3(0.25, 0, -0.26)
				elbow_l_rot = Vector3(0.65, 0, 0)
		elif p < 0.62:
			var t: float = ease((p - 0.28) / 0.34, 2.0)
			arm_r_rot = Vector3(lerpf(2.25, -0.65, t), lerpf(0.25, -0.38, t), lerpf(0.28, -0.06, t))
			elbow_r_rot = Vector3(lerpf(1.05, 0.20, t), 0, 0)
			torso_yaw = lerpf(-0.42, 0.46, t)
			torso_pitch += lerpf(0.16, -0.28, t)
			if dual:
				arm_l_rot = Vector3(lerpf(1.65, -0.45, t), 0.3 * t, -0.12)
				elbow_l_rot = Vector3(lerpf(0.95, 0.25, t), 0, 0)
			else:
				arm_l_rot = Vector3(-0.35, 0, -0.18)
		else:
			var t: float = (p - 0.62) / 0.38
			arm_r_rot = Vector3(lerpf(-0.65, 0.20, t), lerpf(-0.38, 0.0, t), lerpf(-0.06, 0.10, t))
			elbow_r_rot = Vector3(lerpf(0.20, 0.36, t), 0, 0)
			torso_yaw = lerpf(0.46, 0.0, t)
			arm_l_rot = Vector3(lerpf(-0.35, 0.06, t), 0, -0.12)

	var atk_blend: float = 1.0 if attack_progress > 0.0 else blend
	_blend_pos(torso, Vector3(0.0, 0.76 + bob, 0.0), blend)
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
	_blend_rot(tail, tail_rot, blend)
	_blend_rot(tail_tip, tail_tip_rot, blend)


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
	var jaw := head.get_node_or_null("JawPivot") as Node3D if head else null
	var tail := body.get_node_or_null("TailPivot") as Node3D
	var tail_tip := tail.get_node_or_null("TailTipPivot") as Node3D if tail else null
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
	var jaw_open: float = -0.06 - absf(sin(anim_time * 2.2)) * 0.05

	if anim_state == "WALK":
		var p: float = anim_time * 11.5
		stride_f = sin(p) * 0.65
		stride_b = sin(p + 0.6) * 0.65
		body_bob = absf(sin(p)) * 0.055
		body_pitch = cos(p) * 0.07
		jaw_open = -0.14 - absf(sin(p)) * 0.08
	else:
		body_bob = sin(anim_time * 2.6) * 0.020

	if attack_progress > 0.0:
		var bite_curve: float = sin(clampf(attack_progress, 0.0, 1.0) * PI)
		lunge_z = -0.28 * bite_curve
		head_pitch = -0.35 * bite_curve
		body_pitch += 0.14 * bite_curve
		jaw_open = -0.52 * bite_curve

	_blend_pos(body, Vector3(0, 0.65 + body_bob, lunge_z), blend)
	_blend_rot(body, Vector3(body_pitch, 0, 0), blend)
	_blend_rot(head, Vector3(head_pitch, sin(anim_time * 1.4) * 0.08, 0), blend)
	_blend_rot(jaw, Vector3(jaw_open, 0, 0), blend)
	_blend_rot(tail, Vector3(0.16, sin(anim_time * 5.2) * 0.26, 0), blend)
	_blend_rot(tail_tip, Vector3(0.08, sin(anim_time * 5.2 - 0.8) * 0.34, 0), blend)

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
				_blend_rot(low, Vector3(-maxf(0.0, a * 0.62), 0, 0), blend)
