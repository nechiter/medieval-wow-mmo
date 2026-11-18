extends Node3D

var campfire_light: OmniLight3D = null
var water_mat: StandardMaterial3D = null
var torch_lights: Array[OmniLight3D] = []
var _time_accum: float = 0.0


func _ready() -> void:
	_setup_environment()
	_build_terrain_and_roads()
	_build_watchtower(Vector3(-8.5, 0.0, 4.0))
	_build_campfire(Vector3(1.6, 0.0, 5.2))
	_build_fences_and_props()
	_build_forest_and_rocks()
	_build_bandit_camp(Vector3(-32.0, 0.0, -18.0))
	_build_crystal_lake(Vector3(36.0, 0.0, -20.0))
	_build_mine_entrance(Vector3(0.0, 0.0, -59.0))
	_build_grass_tufts()
	_spawn_entities()


func _process(delta: float) -> void:
	_time_accum += delta
	if campfire_light:
		campfire_light.light_energy = 2.25 + sin(_time_accum * 11.0) * 0.28 + cos(_time_accum * 17.0) * 0.16
	for i in range(torch_lights.size()):
		var tl: OmniLight3D = torch_lights[i]
		if is_instance_valid(tl):
			var phase: float = float(i) * 1.85
			tl.light_energy = 1.9 + sin(_time_accum * 9.5 + phase) * 0.22 + cos(_time_accum * 15.0 + phase) * 0.12
	if water_mat:
		water_mat.uv1_offset = Vector3(_time_accum * 0.045, _time_accum * 0.030, 0.0)


func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.20, 0.45, 0.78)
	sky_mat.sky_horizon_color = Color(0.68, 0.79, 0.88)
	sky_mat.ground_bottom_color = Color(0.18, 0.25, 0.15)
	sky_mat.ground_horizon_color = Color(0.55, 0.65, 0.56)
	sky_mat.sun_angle_max = 22.0
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.60, 0.72, 0.80)
	env.fog_density = 0.0052
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.14
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.45
	sun.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _triplanar_retro_material(color: Color, pattern: String, tri_scale: float = 0.45, roughness: float = 0.90, metallic: float = 0.04) -> StandardMaterial3D:
	var mat := RetroModelBuilder.make_retro_material(color, roughness, metallic, Color.BLACK, 0.0, pattern)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * tri_scale
	return mat


func _make_static_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, with_collision: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)

	if with_collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		mi.add_child(body)
	return mi


func _noise_material(base: Color, uv_scale: float, contrast: float = 0.35) -> StandardMaterial3D:
	var mat := RetroModelBuilder.make_retro_material(base, 0.96, 0.0)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.045
	noise.seed = int(base.r * 1000.0) + 7
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0 - contrast, 1.0 - contrast, 1.0 - contrast))
	grad.set_color(1, Color(1, 1, 1))
	tex.color_ramp = grad
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * uv_scale
	return mat


func _build_terrain_and_roads() -> void:
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	add_child(terrain)

	var mat_grass := _noise_material(Color(0.26, 0.45, 0.20), 0.35)
	var mat_grass_dark := _noise_material(Color(0.20, 0.37, 0.17), 0.25)
	var mat_dirt := _noise_material(Color(0.50, 0.39, 0.26), 0.5, 0.25)
	var mat_cobble := _noise_material(Color(0.48, 0.48, 0.50), 1.0, 0.45)

	# Основная земля с коллизией
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundBody"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 1
	terrain.add_child(ground_body)

	var ground_col := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(260.0, 2.0, 260.0)
	ground_col.shape = ground_shape
	ground_col.position = Vector3(0.0, -1.0, -40.0)
	ground_body.add_child(ground_col)

	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(260.0, 260.0)
	ground_mesh.mesh = plane
	ground_mesh.material_override = mat_grass
	ground_mesh.position = Vector3(0.0, 0.0, -40.0)
	terrain.add_child(ground_mesh)

	# Грунтовые дороги (север в рудник, запад к лагерю Братства, восток к озеру)
	var road_segments: Array[Dictionary] = [
		{"size": Vector3(5.8, 0.05, 22.0), "pos": Vector3(0.0, 0.02, 2.0), "rot": Vector3.ZERO},
		{"size": Vector3(5.4, 0.05, 26.0), "pos": Vector3(0.3, 0.02, -20.0), "rot": Vector3(0, -3, 0)},
		{"size": Vector3(6.2, 0.05, 28.0), "pos": Vector3(0.1, 0.02, -45.0), "rot": Vector3(0, 2, 0)},
		{"size": Vector3(26.0, 0.05, 4.4), "pos": Vector3(-14.0, 0.02, -18.0), "rot": Vector3(0, 4, 0)},
		{"size": Vector3(22.0, 0.05, 4.4), "pos": Vector3(13.0, 0.02, -18.5), "rot": Vector3(0, -4, 0)},
	]
	for seg in road_segments:
		_make_static_box(terrain, seg["size"], seg["pos"], mat_dirt, seg["rot"], false)

	# Площадь из брусчатки у заставы
	_make_static_box(terrain, Vector3(14.0, 0.07, 13.0), Vector3(-2.5, 0.03, 5.5), mat_cobble, Vector3.ZERO, false)

	# Низкополигональные холмы и хребты по внешнему периметру долины
	var mat_ridge_rock := _noise_material(Color(0.38, 0.36, 0.39), 0.20, 0.48)
	var peaks: Array[Dictionary] = [
		# Западный хребет
		{"pos": Vector3(-70, 0, -5), "top": 4.2, "bot": 20.0, "h": 16.0, "mat": mat_grass_dark, "rot": 15.0},
		{"pos": Vector3(-72, 0, -28), "top": 3.5, "bot": 22.0, "h": 19.0, "mat": mat_grass_dark, "rot": 40.0},
		{"pos": Vector3(-68, 0, -52), "top": 3.0, "bot": 19.0, "h": 17.5, "mat": mat_ridge_rock, "rot": 22.0},
		{"pos": Vector3(-66, 0, 18), "top": 4.5, "bot": 18.0, "h": 13.0, "mat": mat_grass_dark, "rot": 5.0},
		# Восточный хребет
		{"pos": Vector3(70, 0, -6), "top": 4.0, "bot": 20.0, "h": 15.5, "mat": mat_grass_dark, "rot": 12.0},
		{"pos": Vector3(72, 0, -30), "top": 3.4, "bot": 22.0, "h": 19.5, "mat": mat_grass_dark, "rot": 32.0},
		{"pos": Vector3(68, 0, -54), "top": 3.2, "bot": 19.0, "h": 18.0, "mat": mat_ridge_rock, "rot": 50.0},
		{"pos": Vector3(66, 0, 18), "top": 4.6, "bot": 18.0, "h": 13.0, "mat": mat_grass_dark, "rot": 18.0},
		# Северные горы за рудником (с отступом от подземного зала x in [-15,15], z in [-59,-109])
		{"pos": Vector3(-42, 0, -78), "top": 3.6, "bot": 20.0, "h": 21.0, "mat": mat_ridge_rock, "rot": 8.0},
		{"pos": Vector3(-37, 0, -102), "top": 3.0, "bot": 18.0, "h": 23.0, "mat": mat_ridge_rock, "rot": 28.0},
		{"pos": Vector3(0, 0, -138), "top": 4.2, "bot": 25.0, "h": 26.0, "mat": mat_ridge_rock, "rot": 10.0},
		{"pos": Vector3(37, 0, -102), "top": 3.0, "bot": 18.0, "h": 22.0, "mat": mat_ridge_rock, "rot": 44.0},
		{"pos": Vector3(42, 0, -78), "top": 3.6, "bot": 20.0, "h": 20.0, "mat": mat_ridge_rock, "rot": 16.0},
		# Южные холмы за заставой
		{"pos": Vector3(-34, 0, 44), "top": 5.0, "bot": 22.0, "h": 13.0, "mat": mat_grass_dark, "rot": 20.0},
		{"pos": Vector3(0, 0, 48), "top": 6.0, "bot": 25.0, "h": 12.0, "mat": mat_grass_dark, "rot": 35.0},
		{"pos": Vector3(34, 0, 44), "top": 5.0, "bot": 22.0, "h": 13.5, "mat": mat_grass_dark, "rot": 50.0},
	]
	for pk in peaks:
		var m_mesh := CylinderMesh.new()
		m_mesh.top_radius = pk["top"]
		m_mesh.bottom_radius = pk["bot"]
		m_mesh.height = pk["h"]
		m_mesh.radial_segments = 7
		var m_mi := MeshInstance3D.new()
		m_mi.mesh = m_mesh
		m_mi.material_override = pk["mat"]
		m_mi.position = pk["pos"] + Vector3(0, float(pk["h"]) * 0.45, 0)
		m_mi.rotation_degrees = Vector3(0, pk["rot"], 0)
		m_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		terrain.add_child(m_mi)

	# Невидимые границы долины (чтобы нельзя было выйти за периметр гор)
	var border_body := StaticBody3D.new()
	border_body.name = "ValleyBounds"
	border_body.collision_layer = 1
	border_body.collision_mask = 1
	terrain.add_child(border_body)
	var bounds: Array[Dictionary] = [
		{"size": Vector3(6, 16, 150), "pos": Vector3(-60, 8, -32)},
		{"size": Vector3(6, 16, 150), "pos": Vector3(60, 8, -32)},
		{"size": Vector3(130, 16, 6), "pos": Vector3(0, 8, 36)},
		{"size": Vector3(44, 16, 6), "pos": Vector3(-38, 8, -76)},
		{"size": Vector3(44, 16, 6), "pos": Vector3(38, 8, -76)},
	]
	for b in bounds:
		var bc := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b["size"]
		bc.shape = bs
		bc.position = b["pos"]
		border_body.add_child(bc)


func _build_watchtower(origin: Vector3) -> void:
	var tower := Node3D.new()
	tower.name = "Watchtower"
	tower.position = origin
	add_child(tower)

	var mat_stone := _triplanar_retro_material(Color(0.54, 0.54, 0.58), "stone", 0.42, 0.90, 0.05)
	var mat_wood := _triplanar_retro_material(Color(0.42, 0.27, 0.14), "wood", 0.55, 0.90, 0.02)
	var mat_roof := _triplanar_retro_material(Color(0.18, 0.31, 0.60), "roof", 0.55, 0.72, 0.12)
	var mat_gold := RetroModelBuilder.make_retro_material(Color(0.86, 0.70, 0.24), 0.40, 0.55)

	# Каменное основание башни и угловые контрфорсы
	_make_static_box(tower, Vector3(5.6, 5.4, 5.6), Vector3(0, 2.7, 0), mat_stone)
	for cx in [-2.75, 2.75]:
		for cz in [-2.75, 2.75]:
			_make_static_box(tower, Vector3(0.95, 2.8, 0.95), Vector3(cx, 1.4, cz), mat_stone, Vector3.ZERO, false)

	# Дверной проём и козырёк со стороны площади
	_make_static_box(tower, Vector3(0.28, 2.8, 1.8), Vector3(2.82, 1.4, 0), mat_wood, Vector3.ZERO, false)
	_make_static_box(tower, Vector3(0.9, 0.32, 2.3), Vector3(3.15, 2.95, 0), mat_wood, Vector3(0, 0, -14), false)

	# Деревянный верхний ярус и зубцы
	_make_static_box(tower, Vector3(6.4, 0.55, 6.4), Vector3(0, 5.65, 0), mat_wood)
	for bz in [-2.85, -1.0, 1.0, 2.85]:
		_make_static_box(tower, Vector3(0.45, 0.75, 0.85), Vector3(3.0, 6.25, bz), mat_stone, Vector3.ZERO, false)
		_make_static_box(tower, Vector3(0.45, 0.75, 0.85), Vector3(-3.0, 6.25, bz), mat_stone, Vector3.ZERO, false)
	_make_static_box(tower, Vector3(4.8, 3.0, 4.8), Vector3(0, 7.4, 0), mat_stone)

	# Угловые столбы крыши
	for sx in [-2.6, 2.6]:
		for sz in [-2.6, 2.6]:
			_make_static_box(tower, Vector3(0.45, 3.4, 0.45), Vector3(sx, 7.6, sz), mat_wood, Vector3.ZERO, false)

	# Синяя штормградская крыша-пирамида (в стиле 2004 года) со шпилем
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.15
	cone.bottom_radius = 4.6
	cone.height = 3.6
	cone.radial_segments = 4
	roof.mesh = cone
	roof.material_override = mat_roof
	roof.position = Vector3(0, 10.6, 0)
	roof.rotation_degrees = Vector3(0, 45, 0)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	tower.add_child(roof)

	var finial := MeshInstance3D.new()
	var fin_cone := CylinderMesh.new()
	fin_cone.top_radius = 0.02
	fin_cone.bottom_radius = 0.22
	fin_cone.height = 0.9
	fin_cone.radial_segments = 6
	finial.mesh = fin_cone
	finial.material_override = mat_gold
	finial.position = Vector3(0, 12.75, 0)
	tower.add_child(finial)

	# Штандарты заставы
	_make_static_box(tower, Vector3(0.12, 2.6, 1.1), Vector3(2.92, 4.2, -1.8), mat_roof, Vector3.ZERO, false)
	_make_static_box(tower, Vector3(0.14, 0.45, 0.45), Vector3(2.94, 4.5, -1.8), mat_gold, Vector3.ZERO, false)
	_make_static_box(tower, Vector3(0.12, 2.6, 1.1), Vector3(2.92, 4.2, 1.8), mat_roof, Vector3.ZERO, false)
	_make_static_box(tower, Vector3(0.14, 0.45, 0.45), Vector3(2.94, 4.5, 1.8), mat_gold, Vector3.ZERO, false)


func _build_campfire(origin: Vector3) -> void:
	var camp := Node3D.new()
	camp.name = "Campfire"
	camp.position = origin
	add_child(camp)

	var mat_stone := _triplanar_retro_material(Color(0.42, 0.42, 0.44), "stone", 1.1, 0.94, 0.0)
	var mat_wood := _triplanar_retro_material(Color(0.32, 0.19, 0.09), "wood", 1.0, 0.95, 0.0)
	var mat_ember := RetroModelBuilder.make_retro_material(Color(1.0, 0.48, 0.10), 0.3, 0.0, Color(1.0, 0.42, 0.05), 3.0)

	for i in range(8):
		var ang: float = (float(i) / 8.0) * TAU
		_make_static_box(camp, Vector3(0.34, 0.24, 0.34), Vector3(cos(ang) * 0.75, 0.12, sin(ang) * 0.75), mat_stone, Vector3(0, rad_to_deg(ang), 0), false)

	_make_static_box(camp, Vector3(0.18, 0.16, 1.1), Vector3(0, 0.14, 0), mat_wood, Vector3(0, 32, 12), false)
	_make_static_box(camp, Vector3(0.18, 0.16, 1.1), Vector3(0, 0.14, 0), mat_wood, Vector3(0, -36, -10), false)
	_make_static_box(camp, Vector3(0.45, 0.16, 0.45), Vector3(0, 0.08, 0), mat_ember, Vector3.ZERO, false)

	campfire_light = OmniLight3D.new()
	campfire_light.light_color = Color(1.0, 0.56, 0.20)
	campfire_light.light_energy = 2.2
	campfire_light.omni_range = 11.0
	campfire_light.position = Vector3(0, 0.75, 0)
	camp.add_child(campfire_light)

	var sparks := CPUParticles3D.new()
	sparks.position = Vector3(0, 0.25, 0)
	sparks.amount = 16
	sparks.lifetime = 1.25
	sparks.emitting = true
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 20.0
	sparks.initial_velocity_min = 1.1
	sparks.initial_velocity_max = 2.2
	sparks.gravity = Vector3(0, 0.3, 0)
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.14, 0.14, 0.14)
	spark_mesh.material = mat_ember
	sparks.mesh = spark_mesh
	camp.add_child(sparks)


func _build_fences_and_props() -> void:
	var props := Node3D.new()
	props.name = "OutpostProps"
	add_child(props)

	var mat_wood := _triplanar_retro_material(Color(0.44, 0.28, 0.14), "wood", 0.65, 0.90, 0.0)
	var mat_sign := _triplanar_retro_material(Color(0.62, 0.46, 0.25), "wood", 0.9, 0.88, 0.0)
	var mat_iron := RetroModelBuilder.make_retro_material(Color(0.28, 0.29, 0.32), 0.5, 0.65)

	# Ограда вдоль дороги у заставы
	for x_side in [-4.5, 5.2]:
		for z_pos in [11.0, 6.0, 1.0, -4.0]:
			_make_static_box(props, Vector3(0.24, 1.15, 0.24), Vector3(x_side, 0.57, z_pos), mat_wood)
		_make_static_box(props, Vector3(0.14, 0.16, 15.2), Vector3(x_side, 0.86, 3.5), mat_wood, Vector3.ZERO, false)
		_make_static_box(props, Vector3(0.14, 0.16, 15.2), Vector3(x_side, 0.44, 3.5), mat_wood, Vector3.ZERO, false)

	# Бочки и ящики припасов у стены башни
	for bx_pos in [Vector3(-4.7, 0.42, 6.0), Vector3(-5.0, 0.42, 7.1)]:
		var barrel := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.36
		bm.bottom_radius = 0.38
		bm.height = 0.84
		bm.radial_segments = 8
		barrel.mesh = bm
		barrel.material_override = mat_wood
		barrel.position = bx_pos
		barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		props.add_child(barrel)
		var ring := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.39
		rm.bottom_radius = 0.39
		rm.height = 0.08
		rm.radial_segments = 8
		ring.mesh = rm
		ring.material_override = mat_iron
		ring.position = bx_pos + Vector3(0, 0.18, 0)
		props.add_child(ring)
	_make_static_box(props, Vector3(0.95, 0.75, 0.95), Vector3(-5.1, 0.37, 4.9), mat_sign, Vector3(0, 18, 0))

	# Деревянный указатель на перекрёстке
	_make_static_box(props, Vector3(0.22, 2.3, 0.22), Vector3(3.8, 1.15, -6.5), mat_wood)
	_make_static_box(props, Vector3(1.5, 0.45, 0.10), Vector3(3.3, 1.95, -6.5), mat_sign, Vector3(0, 14, 0), false)

	var sign_lbl := Label3D.new()
	sign_lbl.text = "↑ Северный рудник\n← Братство | → Озеро"
	sign_lbl.font_size = 24
	sign_lbl.pixel_size = 0.008
	sign_lbl.modulate = Color(0.16, 0.10, 0.05)
	sign_lbl.position = Vector3(3.3, 1.95, -6.42)
	sign_lbl.rotation_degrees = Vector3(0, 14, 0)
	props.add_child(sign_lbl)


func _make_boulder(parent: Node3D, pos: Vector3, size_scale: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, with_collision: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 6
	sph.rings = 3
	mi.mesh = sph
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = size_scale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)

	if with_collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size_scale * 0.78
		col.shape = shape
		body.add_child(col)
		mi.add_child(body)
	return mi


func _make_reed_cluster(parent: Node3D, pos: Vector3, mat_stem: Material, mat_tip: Material, seed_idx: int) -> void:
	var cluster := Node3D.new()
	cluster.position = pos
	cluster.rotation_degrees.y = float(seed_idx * 47 % 360)
	parent.add_child(cluster)
	for j in range(3):
		var ang: float = float(j) * 2.1
		var ox: float = cos(ang) * 0.14
		var oz: float = sin(ang) * 0.14
		var h: float = 0.85 + float((seed_idx + j) % 3) * 0.18
		_make_static_box(cluster, Vector3(0.05, h, 0.05), Vector3(ox, h * 0.5, oz), mat_stem, Vector3(sin(ang) * 7.0, 0.0, -cos(ang) * 7.0), false)
		if j < 2:
			_make_static_box(cluster, Vector3(0.11, 0.24, 0.11), Vector3(ox * 1.35, h - 0.10, oz * 1.35), mat_tip, Vector3(sin(ang) * 7.0, 0.0, -cos(ang) * 7.0), false)


func _make_crystal_cluster(parent: Node3D, pos: Vector3, mat_ore: Material, seed_idx: int) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation_degrees.y = float(seed_idx * 53 % 360)
	parent.add_child(node)
	var specs: Array = [
		{"h": 1.6, "r": 0.34, "off": Vector3(0, 0.72, 0), "rot": Vector3(8, 0, -10)},
		{"h": 1.15, "r": 0.25, "off": Vector3(-0.35, 0.50, 0.22), "rot": Vector3(18, 25, 22)},
		{"h": 0.95, "r": 0.22, "off": Vector3(0.32, 0.42, -0.18), "rot": Vector3(-16, -20, -24)},
	]
	for sp in specs:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = sp["r"]
		cm.height = sp["h"]
		cm.radial_segments = 5
		mi.mesh = cm
		mi.material_override = mat_ore
		mi.position = sp["off"]
		mi.rotation_degrees = sp["rot"]
		node.add_child(mi)


func _build_forest_and_rocks() -> void:
	var forest := Node3D.new()
	forest.name = "ForestAndRocks"
	add_child(forest)

	var mat_trunk := _triplanar_retro_material(Color(0.36, 0.23, 0.12), "wood", 0.75, 0.94, 0.0)
	var mat_leaves_1 := RetroModelBuilder.make_retro_material(Color(0.14, 0.35, 0.14), 0.92, 0.0)
	var mat_leaves_2 := RetroModelBuilder.make_retro_material(Color(0.18, 0.42, 0.16), 0.92, 0.0)
	var mat_leaves_oak := RetroModelBuilder.make_retro_material(Color(0.22, 0.46, 0.17), 0.90, 0.0)
	var mat_rock := _noise_material(Color(0.48, 0.48, 0.51), 0.8, 0.5)

	var tree_positions: Array[Vector3] = [
		Vector3(-14, 0, -4), Vector3(-20, 0, -6), Vector3(-16, 0, -29),
		Vector3(-26, 0, -35), Vector3(-18, 0, -44), Vector3(-22, 0, 8),
		Vector3(14, 0, -5), Vector3(19, 0, -6), Vector3(15, 0, -31),
		Vector3(24, 0, -38), Vector3(18, 0, -46), Vector3(16, 0, 8),
		Vector3(-12, 0, 18), Vector3(13, 0, 18), Vector3(-44, 0, -8),
		Vector3(-46, 0, -28), Vector3(50, 0, -6), Vector3(50, 0, -34),
		Vector3(-8, 0, -32), Vector3(9, 0, -30),
	]

	for i in range(tree_positions.size()):
		var tp: Vector3 = tree_positions[i]
		var tree := Node3D.new()
		tree.position = tp
		var sc: float = 0.9 + float(i % 4) * 0.18
		tree.scale = Vector3.ONE * sc
		tree.rotation_degrees.y = float(i * 41 % 360)
		forest.add_child(tree)

		var trunk_mi := MeshInstance3D.new()
		var trunk_cyl := CylinderMesh.new()
		trunk_cyl.top_radius = 0.28
		trunk_cyl.bottom_radius = 0.44
		trunk_cyl.height = 3.2
		trunk_cyl.radial_segments = 6
		trunk_mi.mesh = trunk_cyl
		trunk_mi.material_override = mat_trunk
		trunk_mi.position = Vector3(0, 1.6, 0)
		trunk_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		tree.add_child(trunk_mi)

		var t_body := StaticBody3D.new()
		t_body.collision_layer = 1
		t_body.collision_mask = 1
		var t_col := CollisionShape3D.new()
		var t_shape := BoxShape3D.new()
		t_shape.size = Vector3(0.7, 3.2, 0.7)
		t_col.shape = t_shape
		t_col.position = Vector3(0, 1.6, 0)
		t_body.add_child(t_col)
		tree.add_child(t_body)

		if i % 3 == 0:
			# Классический элвинский низкополигональный дуб
			_make_static_box(tree, Vector3(0.24, 1.4, 0.24), Vector3(-0.45, 3.4, 0.15), mat_trunk, Vector3(10, 0, 28), false)
			_make_static_box(tree, Vector3(0.24, 1.4, 0.24), Vector3(0.45, 3.4, -0.15), mat_trunk, Vector3(-10, 0, -28), false)
			for blob in [
				{"pos": Vector3(0.0, 4.9, 0.0), "r": 2.1},
				{"pos": Vector3(-1.1, 4.1, 0.4), "r": 1.45},
				{"pos": Vector3(1.05, 4.2, -0.35), "r": 1.4},
			]:
				var sph := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = blob["r"]
				sm.height = float(blob["r"]) * 1.65
				sm.radial_segments = 7
				sm.rings = 3
				sph.mesh = sm
				sph.material_override = mat_leaves_oak
				sph.position = blob["pos"]
				sph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				tree.add_child(sph)
		else:
			var leaf_mat: Material = mat_leaves_1 if (i % 2 == 0) else mat_leaves_2
			for tier in range(3):
				var cone_mi := MeshInstance3D.new()
				var cone := CylinderMesh.new()
				cone.top_radius = 0.12
				cone.bottom_radius = 2.6 - float(tier) * 0.55
				cone.height = 2.5
				cone.radial_segments = 7
				cone_mi.mesh = cone
				cone_mi.material_override = leaf_mat
				cone_mi.position = Vector3(0, 3.3 + float(tier) * 1.45, 0)
				cone_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				tree.add_child(cone_mi)

	var rock_positions: Array[Dictionary] = [
		{"pos": Vector3(-8.5, 0.5, -15.0), "size": Vector3(2.8, 1.8, 2.3), "rot": Vector3(8, 22, 0)},
		{"pos": Vector3(10.5, 0.65, -21.0), "size": Vector3(3.2, 2.2, 2.6), "rot": Vector3(-5, 45, 10)},
		{"pos": Vector3(-11.0, 0.75, -39.0), "size": Vector3(3.6, 2.6, 3.0), "rot": Vector3(4, -30, 6)},
		{"pos": Vector3(12.0, 0.6, -46.0), "size": Vector3(2.9, 2.0, 2.5), "rot": Vector3(-6, 15, -4)},
	]
	for r in rock_positions:
		_make_boulder(forest, r["pos"], r["size"], mat_rock, r["rot"], true)


func _build_bandit_camp(origin: Vector3) -> void:
	var camp := Node3D.new()
	camp.name = "BanditCamp"
	camp.position = origin
	add_child(camp)

	var mat_dirt := _noise_material(Color(0.45, 0.34, 0.22), 0.6, 0.25)
	var mat_wood := _triplanar_retro_material(Color(0.38, 0.24, 0.12), "wood", 0.75, 0.90, 0.0)
	var mat_stone := _triplanar_retro_material(Color(0.42, 0.42, 0.45), "stone", 1.1, 0.94, 0.0)
	var mat_tent := _triplanar_retro_material(Color(0.62, 0.16, 0.14), "cloth", 0.85, 0.88, 0.0)
	var mat_ember := RetroModelBuilder.make_retro_material(Color(1.0, 0.45, 0.08), 0.3, 0.0, Color(1.0, 0.42, 0.05), 2.5)

	_make_static_box(camp, Vector3(16.0, 0.05, 15.0), Vector3(0, 0.02, 0), mat_dirt, Vector3.ZERO, false)

	# Шатёр разбойников Братства
	_make_static_box(camp, Vector3(0.24, 2.8, 0.24), Vector3(-4.5, 1.4, -3.5), mat_wood)
	_make_static_box(camp, Vector3(0.24, 2.8, 0.24), Vector3(-1.0, 1.4, -3.5), mat_wood)
	_make_static_box(camp, Vector3(0.22, 1.9, 0.22), Vector3(-4.5, 0.95, -6.0), mat_wood)
	_make_static_box(camp, Vector3(0.22, 1.9, 0.22), Vector3(-1.0, 0.95, -6.0), mat_wood)
	_make_static_box(camp, Vector3(3.8, 0.18, 0.18), Vector3(-2.75, 2.8, -3.5), mat_wood, Vector3.ZERO, false)
	_make_static_box(camp, Vector3(4.2, 0.18, 3.6), Vector3(-2.75, 2.55, -4.6), mat_tent, Vector3(24, 0, 0), true)

	# Костёр лагеря с каменным кольцом
	for k in range(6):
		var ang: float = float(k) / 6.0 * TAU
		_make_static_box(camp, Vector3(0.28, 0.20, 0.28), Vector3(0.5 + cos(ang) * 0.55, 0.10, 0.5 + sin(ang) * 0.55), mat_stone, Vector3(0, rad_to_deg(ang), 0), false)
	_make_static_box(camp, Vector3(0.16, 0.14, 0.9), Vector3(0.5, 0.12, 0.5), mat_wood, Vector3(0, 35, 10), false)
	_make_static_box(camp, Vector3(0.5, 0.18, 0.5), Vector3(0.5, 0.09, 0.5), mat_ember, Vector3.ZERO, false)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.52, 0.18)
	light.light_energy = 1.9
	light.omni_range = 10.5
	light.position = Vector3(0.5, 0.85, 0.5)
	camp.add_child(light)
	torch_lights.append(light)

	# Частокол с заострёнными кольями
	for dz in [-5.5, -2.5, 2.5, 5.5]:
		_make_static_box(camp, Vector3(0.48, 1.6, 1.6), Vector3(-7.2, 0.8, dz), mat_wood, Vector3(0, 8, 0))
		for sz in [-0.45, 0.45]:
			var tip := MeshInstance3D.new()
			var tc := CylinderMesh.new()
			tc.top_radius = 0.02
			tc.bottom_radius = 0.22
			tc.height = 0.55
			tc.radial_segments = 5
			tip.mesh = tc
			tip.material_override = mat_wood
			tip.position = Vector3(-7.2, 1.85, dz + sz)
			camp.add_child(tip)

	# 3 квестовых ящика припасов
	var crate_offsets: Array[Vector3] = [
		Vector3(-2.8, 0.0, -4.8),
		Vector3(3.8, 0.0, -2.5),
		Vector3(-2.0, 0.0, 5.0),
	]
	for idx in range(crate_offsets.size()):
		var crate := InteractableProp.new()
		crate.name = "SupplyCrate_%d" % (idx + 1)
		crate.prop_id = "supply_crate"
		crate.prop_title = "Ящик припасов"
		crate.position = origin + crate_offsets[idx]
		add_child(crate)


func _build_crystal_lake(origin: Vector3) -> void:
	var lake := Node3D.new()
	lake.name = "CrystalLake"
	lake.position = origin
	add_child(lake)

	var mat_sand := _noise_material(Color(0.70, 0.62, 0.44), 0.7, 0.2)
	var mat_wood := _triplanar_retro_material(Color(0.42, 0.28, 0.15), "wood", 0.75, 0.90, 0.0)
	var mat_stone := _noise_material(Color(0.48, 0.50, 0.52), 0.85, 0.45)
	var mat_reed := RetroModelBuilder.make_retro_material(Color(0.24, 0.44, 0.16), 0.90, 0.0)
	var mat_cattail := RetroModelBuilder.make_retro_material(Color(0.32, 0.18, 0.09), 0.92, 0.0)

	var mat_water := RetroModelBuilder.make_retro_material(Color(0.18, 0.58, 0.82, 0.82), 0.14, 0.24, Color(0.08, 0.30, 0.48), 0.45, "water")
	mat_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_water.uv1_scale = Vector3(5.0, 5.0, 1.0)
	water_mat = mat_water

	# Песчаный берег и анимированная гладь воды
	_make_static_box(lake, Vector3(27.5, 0.05, 27.5), Vector3(0, 0.02, 0), mat_sand, Vector3.ZERO, false)
	var water_mi := MeshInstance3D.new()
	var wp := PlaneMesh.new()
	wp.size = Vector2(22.2, 22.2)
	water_mi.mesh = wp
	water_mi.material_override = mat_water
	water_mi.position = Vector3(1.5, 0.06, 0)
	lake.add_child(water_mi)

	# Деревянный причал и причальные тумбы
	_make_static_box(lake, Vector3(8.5, 0.22, 2.8), Vector3(-10.0, 0.22, 1.5), mat_wood, Vector3.ZERO, true)
	for px in [-13.5, -10.0, -6.5]:
		for pz in [0.4, 2.6]:
			_make_static_box(lake, Vector3(0.28, 0.85, 0.28), Vector3(px, 0.42, pz), mat_wood, Vector3.ZERO, false)

	# Береговые валуны и заросли камыша у воды
	for b_info in [
		{"pos": Vector3(-7.5, 0.35, -9.8), "sz": Vector3(2.2, 1.2, 1.8), "rot": Vector3(4, 20, 0)},
		{"pos": Vector3(9.5, 0.45, -10.8), "sz": Vector3(2.6, 1.5, 2.2), "rot": Vector3(-6, 55, 8)},
		{"pos": Vector3(11.0, 0.4, 10.5), "sz": Vector3(2.4, 1.3, 2.0), "rot": Vector3(5, -35, 4)},
		{"pos": Vector3(-6.0, 0.35, 11.2), "sz": Vector3(2.0, 1.1, 1.7), "rot": Vector3(-4, 15, -5)},
	]:
		_make_boulder(lake, b_info["pos"], b_info["sz"], mat_stone, b_info["rot"], false)

	var reed_pts: Array[Vector3] = [
		Vector3(-9.2, 0.02, -7.2), Vector3(-8.4, 0.02, -8.5), Vector3(4.0, 0.02, -11.4),
		Vector3(6.5, 0.02, -11.2), Vector3(12.2, 0.02, -5.0), Vector3(12.4, 0.02, 4.5),
		Vector3(7.0, 0.02, 11.4), Vector3(1.5, 0.02, 11.5), Vector3(-8.8, 0.02, 8.8),
		Vector3(-9.5, 0.02, 6.2),
	]
	for ri in range(reed_pts.size()):
		_make_reed_cluster(lake, reed_pts[ri], mat_reed, mat_cattail, ri)


func _build_mine_entrance(origin: Vector3) -> void:
	var mine := Node3D.new()
	mine.name = "NorthernMine"
	mine.position = origin
	add_child(mine)

	var mat_rock := _noise_material(Color(0.24, 0.22, 0.25), 0.48, 0.58)
	var mat_stone_trim := _triplanar_retro_material(Color(0.32, 0.31, 0.34), "stone", 0.38, 0.94, 0.02)
	var mat_floor := _noise_material(Color(0.18, 0.17, 0.19), 0.55, 0.45)
	var mat_timber := _triplanar_retro_material(Color(0.36, 0.22, 0.11), "wood", 0.55, 0.92, 0.0)
	var mat_crate := _triplanar_retro_material(Color(0.50, 0.34, 0.18), "wood", 0.8, 0.88, 0.0)
	var mat_torch := RetroModelBuilder.make_retro_material(Color(1.0, 0.65, 0.18), 0.3, 0.0, Color(1.0, 0.55, 0.10), 3.0)
	var mat_ore := RetroModelBuilder.make_retro_material(Color(0.35, 0.82, 1.0), 0.20, 0.35, Color(0.28, 0.72, 1.0), 2.4)

	# Входная скальная арка (проходимая! ширина проёма 9 м, высота 6 м)
	_make_static_box(mine, Vector3(11.0, 9.5, 7.0), Vector3(-10.0, 4.75, 0), mat_rock)
	_make_static_box(mine, Vector3(11.0, 9.5, 7.0), Vector3(10.0, 4.75, 0), mat_rock)
	_make_static_box(mine, Vector3(12.0, 3.6, 7.2), Vector3(0, 8.0, 0), mat_rock)
	_make_static_box(mine, Vector3(1.1, 6.2, 0.9), Vector3(-4.6, 3.1, 3.3), mat_stone_trim, Vector3.ZERO, false)
	_make_static_box(mine, Vector3(1.1, 6.2, 0.9), Vector3(4.6, 3.1, 3.3), mat_stone_trim, Vector3.ZERO, false)

	# Деревянные балки входа и раскосы
	_make_static_box(mine, Vector3(0.65, 6.2, 0.65), Vector3(-4.1, 3.1, 3.2), mat_timber)
	_make_static_box(mine, Vector3(0.65, 6.2, 0.65), Vector3(4.1, 3.1, 3.2), mat_timber)
	_make_static_box(mine, Vector3(9.4, 0.7, 0.8), Vector3(0, 6.1, 3.2), mat_timber)
	_make_static_box(mine, Vector3(0.45, 2.1, 0.45), Vector3(-3.4, 5.2, 3.2), mat_timber, Vector3(0, 0, -42), false)
	_make_static_box(mine, Vector3(0.45, 2.1, 0.45), Vector3(3.4, 5.2, 3.2), mat_timber, Vector3(0, 0, 42), false)

	# Подземный тоннель (от z=-3.5 до z=-22 в локальных координатах -> мировой Z = -62.5..-81)
	_make_static_box(mine, Vector3(10.0, 0.08, 22.0), Vector3(0, 0.03, -12.0), mat_floor, Vector3.ZERO, false)
	_make_static_box(mine, Vector3(4.0, 7.5, 22.0), Vector3(-6.5, 3.75, -12.0), mat_rock)
	_make_static_box(mine, Vector3(4.0, 7.5, 22.0), Vector3(6.5, 3.75, -12.0), mat_rock)
	_make_static_box(mine, Vector3(17.0, 1.8, 22.0), Vector3(0, 7.6, -12.0), mat_rock)

	# Большой зал рудника (от z=-22 до z=-47 -> мировой Z = -81..-106)
	_make_static_box(mine, Vector3(24.0, 0.08, 26.0), Vector3(0, 0.03, -34.0), mat_floor, Vector3.ZERO, false)
	_make_static_box(mine, Vector3(4.0, 9.0, 26.0), Vector3(-13.5, 4.5, -34.0), mat_rock)
	_make_static_box(mine, Vector3(4.0, 9.0, 26.0), Vector3(13.5, 4.5, -34.0), mat_rock)
	_make_static_box(mine, Vector3(10.0, 9.0, 4.0), Vector3(-9.0, 4.5, -22.0), mat_rock)
	_make_static_box(mine, Vector3(10.0, 9.0, 4.0), Vector3(9.0, 4.5, -22.0), mat_rock)
	_make_static_box(mine, Vector3(30.0, 9.0, 4.0), Vector3(0, 4.5, -47.0), mat_rock)
	_make_static_box(mine, Vector3(30.0, 1.8, 28.0), Vector3(0, 9.2, -34.0), mat_rock)

	# Подпорки тоннеля, факелы и кристальные жилы руды
	for tz in [3.2, -6.0, -14.0, -21.0]:
		if tz < 2.0:
			_make_static_box(mine, Vector3(0.55, 6.4, 0.55), Vector3(-4.1, 3.2, tz), mat_timber)
			_make_static_box(mine, Vector3(0.55, 6.4, 0.55), Vector3(4.1, 3.2, tz), mat_timber)
			_make_static_box(mine, Vector3(8.8, 0.55, 0.55), Vector3(0, 6.4, tz), mat_timber)
			_make_static_box(mine, Vector3(0.35, 1.6, 0.35), Vector3(-3.5, 5.7, tz), mat_timber, Vector3(0, 0, -45), false)
			_make_static_box(mine, Vector3(0.35, 1.6, 0.35), Vector3(3.5, 5.7, tz), mat_timber, Vector3(0, 0, 45), false)
		for sx in [-3.7, 3.7]:
			_make_static_box(mine, Vector3(0.24, 0.24, 0.24), Vector3(sx, 3.2, tz + 0.35), mat_torch, Vector3.ZERO, false)
			var tl := OmniLight3D.new()
			tl.light_color = Color(1.0, 0.58, 0.20)
			tl.light_energy = 1.9
			tl.omni_range = 12.0
			tl.position = Vector3(sx, 3.3, tz + 0.6)
			mine.add_child(tl)
			torch_lights.append(tl)

	# Освещение и кристаллы в глубине зала
	for pos in [Vector3(-8.5, 4.0, -31.0), Vector3(8.5, 4.0, -31.0), Vector3(0.0, 5.0, -40.0)]:
		var cl := OmniLight3D.new()
		cl.light_color = Color(0.95, 0.68, 0.32)
		cl.light_energy = 2.4
		cl.omni_range = 18.0
		cl.position = pos
		mine.add_child(cl)

	# Добываемые жилы лазурных кристаллов и меди в руднике
	var vein_defs: Array[Dictionary] = [
		{"pos": Vector3(-3.8, 0.0, -9.5), "kind": "azure_crystal", "title": "Лазурная жила"},
		{"pos": Vector3(3.8, 0.0, -17.5), "kind": "azure_crystal", "title": "Лазурная жила"},
		{"pos": Vector3(-10.5, 0.0, -30.0), "kind": "azure_crystal", "title": "Лазурная жила"},
		{"pos": Vector3(10.5, 0.0, -36.0), "kind": "azure_crystal", "title": "Лазурная жила"},
		{"pos": Vector3(-7.0, 0.0, -44.0), "kind": "azure_crystal", "title": "Лазурная жила"},
		{"pos": Vector3(-8.5, 0.0, 5.5), "kind": "copper_ore", "title": "Медная жила"},
		{"pos": Vector3(8.5, 0.0, 5.0), "kind": "copper_ore", "title": "Медная жила"},
	]
	for vi in range(vein_defs.size()):
		var vd: Dictionary = vein_defs[vi]
		var vein := InteractableProp.new()
		vein.name = "OreVein_%d" % (vi + 1)
		vein.prop_id = "ore_vein"
		vein.sub_kind = String(vd["kind"])
		vein.prop_title = String(vd["title"])
		vein.position = origin + (vd["pos"] as Vector3)
		add_child(vein)

	var herb_defs: Array[Dictionary] = [
		{"pos": Vector3(-11.5, 0.0, -7.5), "kind": "peacebloom", "title": "Мироцвет"},
		{"pos": Vector3(11.8, 0.0, -9.0), "kind": "peacebloom", "title": "Мироцвет"},
		{"pos": Vector3(-13.5, 0.0, -25.0), "kind": "peacebloom", "title": "Мироцвет"},
		{"pos": Vector3(13.0, 0.0, -34.0), "kind": "peacebloom", "title": "Мироцвет"},
		{"pos": Vector3(22.5, 0.0, -10.5), "kind": "silverleaf", "title": "Сребролист"},
		{"pos": Vector3(23.5, 0.0, -27.5), "kind": "silverleaf", "title": "Сребролист"},
		{"pos": Vector3(-20.0, 0.0, -11.0), "kind": "silverleaf", "title": "Сребролист"},
	]
	for hi in range(herb_defs.size()):
		var hd: Dictionary = herb_defs[hi]
		var herb := InteractableProp.new()
		herb.name = "HerbNode_%d" % (hi + 1)
		herb.prop_id = "herb_node"
		herb.sub_kind = String(hd["kind"])
		herb.prop_title = String(hd["title"])
		herb.position = hd["pos"]
		add_child(herb)

	# Ящики у входа и в пещере
	_make_static_box(mine, Vector3(1.3, 1.3, 1.3), Vector3(-5.8, 0.65, 5.5), mat_crate, Vector3(0, 20, 0))
	_make_static_box(mine, Vector3(1.1, 1.1, 1.1), Vector3(-7.2, 0.55, 6.2), mat_crate, Vector3(0, -12, 0))
	_make_static_box(mine, Vector3(1.4, 1.4, 1.4), Vector3(6.2, 0.7, 6.4), mat_crate, Vector3(0, 35, 0))

	# Сундук с сокровищами за спиной босса Дробителя
	var chest := InteractableProp.new()
	chest.name = "MineBossChest"
	chest.prop_id = "mine_chest"
	chest.prop_title = "Богатый сундук рудокопа"
	chest.position = origin + Vector3(0.0, 0.0, -42.5)
	add_child(chest)


func _build_grass_tufts() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_c := Color(0.52, 0.72, 0.42)
	var tip_c := Color(1.0, 1.0, 0.78)
	var n := Vector3(0.0, 1.0, 0.0)
	for b_idx in range(3):
		var rad: float = deg_to_rad(float(b_idx) * 60.0 + 15.0)
		var off := Vector3(cos(rad + 1.4) * 0.08, 0.0, sin(rad + 1.4) * 0.08)
		var dx: float = cos(rad) * 0.11
		var dz: float = sin(rad) * 0.11
		var p0 := off + Vector3(-dx, 0.0, -dz)
		var p1 := off + Vector3(dx, 0.0, dz)
		var p_tip := off + Vector3(cos(rad + 1.57) * 0.08, 0.34 + float(b_idx % 2) * 0.06, sin(rad + 1.57) * 0.08)
		st.set_normal(n)
		st.set_color(base_c); st.add_vertex(p0)
		st.set_color(tip_c); st.add_vertex(p_tip)
		st.set_color(base_c); st.add_vertex(p1)
	var tuft_mesh: ArrayMesh = st.commit()

	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.28, 0.50, 0.21)
	grass_mat.roughness = 0.90
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_mat.vertex_color_use_as_albedo = true
	grass_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tuft_mesh.surface_set_material(0, grass_mat)

	var rng := RandomNumberGenerator.new()
	rng.seed = 2004
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []

	for _attempt in range(950):
		if transforms.size() >= 380:
			break
		var x: float = rng.randf_range(-52.0, 52.0)
		var z: float = rng.randf_range(-50.0, 26.0)
		# Избегаем дорог, площади, озера, лагеря и входа в рудник
		if absf(x) < 4.4 and z > -55.0 and z < 15.0:
			continue
		if x >= -14.0 and x <= 7.0 and z >= -7.0 and z <= 14.0:
			continue
		if z >= -21.8 and z <= -14.8 and x >= -28.0 and x <= 26.0:
			continue
		if Vector2(x + 32.0, z + 18.0).length() < 9.5:
			continue
		if x >= 20.5 and x <= 51.5 and z >= -35.5 and z <= -4.5:
			continue

		var rot_y: float = rng.randf_range(0.0, TAU)
		var sc: float = rng.randf_range(0.80, 1.35)
		var basis := Basis(Vector3.UP, rot_y).scaled(Vector3(sc, sc * rng.randf_range(0.85, 1.25), sc))
		transforms.append(Transform3D(basis, Vector3(x, 0.0, z)))
		if rng.randf() < 0.09:
			colors.append(Color(1.0, 0.92, 0.48))
		else:
			var shade: float = rng.randf_range(0.85, 1.15)
			colors.append(Color(0.85 * shade, 1.0 * shade, 0.80 * shade))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tuft_mesh
	mm.instance_count = transforms.size()
	for idx in range(transforms.size()):
		mm.set_instance_transform(idx, transforms[idx])
		mm.set_instance_color(idx, colors[idx])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "MeadowGrass"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _spawn_spirit_healer(pos: Vector3) -> void:
	var healer := Node3D.new()
	healer.name = "SpiritHealer"
	healer.position = pos
	healer.rotation.y = PI * 0.15
	healer.add_to_group("spirit_healer")
	add_child(healer)

	var rig := RetroModelBuilder.build_humanoid({
		"scale": 1.15,
		"archetype": "guard",
		"armor_color": Color(0.55, 0.75, 1.0),
		"accent_color": Color(0.8, 0.92, 1.0),
		"skin_color": Color(0.7, 0.85, 1.0),
		"pants_color": Color(0.5, 0.65, 0.9),
		"cape_color": Color(0.6, 0.8, 1.0),
		"weapon_type": "shortsword",
		"has_cape": true,
	})
	healer.add_child(rig)
	RetroModelBuilder.animate_humanoid(rig, "IDLE", 0.0)
	var stack: Array[Node] = [rig]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			(n as MeshInstance3D).transparency = 0.5
		stack.append_array(n.get_children())

	var lbl := Label3D.new()
	lbl.text = "<Кладбище>\nДух-целитель"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.fixed_size = true
	lbl.pixel_size = 0.0006
	lbl.font_size = 30
	lbl.visibility_range_end = 40.0
	lbl.outline_size = 8
	lbl.modulate = Color(0.6, 0.85, 1.0)
	lbl.position = Vector3(0, 2.6, 0)
	healer.add_child(lbl)

	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.75, 1.0)
	light.light_energy = 1.2
	light.omni_range = 7.0
	light.position = Vector3(0, 1.5, 0)
	healer.add_child(light)


func _spawn_mob_group(prefix: String, cfg: Dictionary, positions: Array[Vector3]) -> void:
	for i in range(positions.size()):
		var mob := MobEntity.new()
		mob.name = "%s_%d" % [prefix, i + 1]
		mob.configure(cfg)
		mob.position = positions[i]
		add_child(mob)


func _spawn_entities() -> void:
	_spawn_spirit_healer(Vector3(5.5, 0.08, 12.5))

	var merchant := QuestNPC.new()
	merchant.name = "MerchantElric"
	merchant.npc_name = "Элрик"
	merchant.npc_title = "Торговец"
	merchant.role = "merchant"
	merchant.position = Vector3(-3.0, 0.08, 9.0)
	merchant.rotation.y = PI * 0.5
	add_child(merchant)

	var player := PlayerController.new()
	player.name = "Player"
	player.position = Vector3(0.0, 0.1, 10.5)
	add_child(player)

	var npc := QuestNPC.new()
	npc.name = "CaptainMarcus"
	npc.position = Vector3(2.8, 0.08, 3.4)
	npc.rotation.y = PI - 0.35
	add_child(npc)

	var lyr := QuestNPC.new()
	lyr.name = "HerbalistLyra"
	lyr.npc_name = "Травница Лира"
	lyr.npc_title = "Алхимик заставы"
	lyr.role = "herbalist"
	lyr.position = Vector3(3.8, 0.08, 6.8)
	lyr.rotation.y = PI * 0.78
	add_child(lyr)

	var guard := QuestNPC.new()
	guard.name = "OutpostGuard"
	guard.npc_name = "Стражник Элвинн"
	guard.npc_title = "Охрана заставы"
	guard.role = "patrol"
	guard.position = Vector3(-3.8, 0.08, 1.5)
	guard.rotation.y = 0.25
	add_child(guard)

	_spawn_mob_group("ForestWolf", {
		"mob_id": "wolf",
		"mob_title": "Лесной волк",
		"level": 1,
		"is_elite": false,
		"max_hp": 72,
		"damage_min": 5,
		"damage_max": 9,
		"aggro_radius": 8.0,
		"attack_range": 2.5,
		"attack_interval": 1.9,
		"move_speed": 4.6,
		"xp_reward": 35,
	}, [
		Vector3(-9.0, 0.1, -13.0),
		Vector3(8.5, 0.1, -15.5),
		Vector3(-6.5, 0.1, -23.0),
		Vector3(9.5, 0.1, -25.0),
	])

	_spawn_mob_group("KoboldMiner", {
		"mob_id": "kobold",
		"mob_title": "Кобольд-шахтёр",
		"level": 2,
		"is_elite": false,
		"max_hp": 92,
		"damage_min": 7,
		"damage_max": 12,
		"aggro_radius": 8.8,
		"attack_range": 2.7,
		"attack_interval": 2.1,
		"move_speed": 4.2,
		"xp_reward": 48,
	}, [
		Vector3(-8.0, 0.1, -35.0),
		Vector3(7.5, 0.1, -36.5),
		Vector3(-6.5, 0.1, -45.0),
		Vector3(8.0, 0.1, -44.5),
	])

	_spawn_mob_group("DefiasBandit", {
		"mob_id": "bandit",
		"mob_title": "Головорез Братства",
		"level": 2,
		"is_elite": false,
		"max_hp": 96,
		"damage_min": 7,
		"damage_max": 12,
		"aggro_radius": 8.5,
		"attack_range": 2.6,
		"attack_interval": 2.0,
		"move_speed": 4.4,
		"xp_reward": 52,
	}, [
		Vector3(-27.0, 0.1, -16.0),
		Vector3(-34.0, 0.1, -14.0),
		Vector3(-30.0, 0.1, -22.5),
		Vector3(-37.0, 0.1, -21.0),
	])

	_spawn_mob_group("MurlocHunter", {
		"mob_id": "murloc",
		"mob_title": "Мурлок-охотник",
		"level": 2,
		"is_elite": false,
		"max_hp": 88,
		"damage_min": 6,
		"damage_max": 11,
		"aggro_radius": 8.5,
		"attack_range": 2.6,
		"attack_interval": 1.85,
		"move_speed": 4.7,
		"xp_reward": 50,
	}, [
		Vector3(27.0, 0.1, -13.0),
		Vector3(31.0, 0.1, -27.0),
		Vector3(41.0, 0.1, -10.0),
		Vector3(44.0, 0.1, -24.0),
		Vector3(24.0, 0.1, -23.0),
	])

	_spawn_mob_group("KoboldGeomancer", {
		"mob_id": "kobold_geomancer",
		"mob_title": "Кобольд-геомант",
		"level": 3,
		"is_elite": false,
		"max_hp": 105,
		"damage_min": 9,
		"damage_max": 14,
		"aggro_radius": 11.0,
		"attack_range": 12.0,
		"attack_interval": 2.4,
		"move_speed": 4.0,
		"xp_reward": 68,
		"is_caster": true,
	}, [
		Vector3(-5.0, 0.1, -84.0),
		Vector3(5.0, 0.1, -86.0),
	])

	var boss := MobEntity.new()
	boss.name = "OverseerCrusher"
	boss.configure({
		"mob_id": "boss_crusher",
		"mob_title": "Надзиратель Дробитель",
		"level": 3,
		"is_elite": true,
		"max_hp": 235,
		"damage_min": 12,
		"damage_max": 18,
		"aggro_radius": 9.5,
		"attack_range": 3.2,
		"attack_interval": 2.2,
		"move_speed": 4.1,
		"xp_reward": 135,
	})
	boss.position = Vector3(0.0, 0.1, -94.5)
	add_child(boss)
