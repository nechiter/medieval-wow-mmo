extends Node3D

var campfire_light: OmniLight3D = null
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
	_spawn_entities()


func _process(delta: float) -> void:
	_time_accum += delta
	if campfire_light:
		campfire_light.light_energy = 2.2 + sin(_time_accum * 11.0) * 0.28 + cos(_time_accum * 17.0) * 0.16


func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.48, 0.78)
	sky_mat.sky_horizon_color = Color(0.68, 0.78, 0.86)
	sky_mat.ground_bottom_color = Color(0.18, 0.24, 0.15)
	sky_mat.ground_horizon_color = Color(0.55, 0.64, 0.56)
	sky_mat.sun_angle_max = 24.0
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.64, 0.74, 0.82)
	env.fog_density = 0.0082
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.35
	sun.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


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

	# Низкополигональные холмы по внешнему периметру долины
	var hills: Array[Dictionary] = [
		{"size": Vector3(36, 14, 70), "pos": Vector3(-68, 5.0, -24), "rot": Vector3(0, 8, -10)},
		{"size": Vector3(36, 14, 70), "pos": Vector3(68, 5.0, -24), "rot": Vector3(0, -8, 10)},
		{"size": Vector3(56, 16, 36), "pos": Vector3(-38, 6.0, -82), "rot": Vector3(8, 14, 0)},
		{"size": Vector3(56, 16, 36), "pos": Vector3(38, 6.0, -82), "rot": Vector3(8, -14, 0)},
		{"size": Vector3(60, 18, 32), "pos": Vector3(0, 6.5, -122), "rot": Vector3(10, 0, 0)},
		{"size": Vector3(86, 10, 26), "pos": Vector3(0, 3.5, 46), "rot": Vector3(-10, 0, 0)},
	]
	for h in hills:
		_make_static_box(terrain, h["size"], h["pos"], mat_grass_dark, h["rot"], true)


func _build_watchtower(origin: Vector3) -> void:
	var tower := Node3D.new()
	tower.name = "Watchtower"
	tower.position = origin
	add_child(tower)

	var mat_stone := RetroModelBuilder.make_retro_material(Color(0.52, 0.53, 0.56), 0.90, 0.05)
	var mat_wood := RetroModelBuilder.make_retro_material(Color(0.42, 0.27, 0.14), 0.90, 0.02)
	var mat_roof := RetroModelBuilder.make_retro_material(Color(0.18, 0.30, 0.58), 0.72, 0.12)
	var mat_gold := RetroModelBuilder.make_retro_material(Color(0.84, 0.68, 0.22), 0.45, 0.5)

	# Каменное основание башни
	_make_static_box(tower, Vector3(5.6, 5.4, 5.6), Vector3(0, 2.7, 0), mat_stone)
	# Дверной проём (тёмная деревянная дверь со стороны площади)
	_make_static_box(tower, Vector3(0.25, 2.8, 1.8), Vector3(2.82, 1.4, 0), mat_wood, Vector3.ZERO, false)
	# Деревянный верхний ярус
	_make_static_box(tower, Vector3(6.4, 0.55, 6.4), Vector3(0, 5.65, 0), mat_wood)
	_make_static_box(tower, Vector3(4.8, 3.0, 4.8), Vector3(0, 7.4, 0), mat_stone)

	# Угловые столбы крыши
	for sx in [-2.6, 2.6]:
		for sz in [-2.6, 2.6]:
			_make_static_box(tower, Vector3(0.45, 3.4, 0.45), Vector3(sx, 7.6, sz), mat_wood, Vector3.ZERO, false)

	# Синяя штормградская крыша-пирамида (в стиле 2004 года)
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

	var mat_stone := RetroModelBuilder.make_retro_material(Color(0.42, 0.42, 0.44), 0.94, 0.0)
	var mat_wood := RetroModelBuilder.make_retro_material(Color(0.32, 0.19, 0.09), 0.95, 0.0)
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

	var mat_wood := RetroModelBuilder.make_retro_material(Color(0.44, 0.28, 0.14), 0.90, 0.0)
	var mat_sign := RetroModelBuilder.make_retro_material(Color(0.62, 0.46, 0.25), 0.88, 0.0)

	# Ограда вдоль дороги у заставы
	for x_side in [-4.5, 5.2]:
		for z_pos in [11.0, 6.0, 1.0, -4.0]:
			_make_static_box(props, Vector3(0.24, 1.15, 0.24), Vector3(x_side, 0.57, z_pos), mat_wood)
		_make_static_box(props, Vector3(0.14, 0.16, 15.2), Vector3(x_side, 0.86, 3.5), mat_wood, Vector3.ZERO, false)
		_make_static_box(props, Vector3(0.14, 0.16, 15.2), Vector3(x_side, 0.44, 3.5), mat_wood, Vector3.ZERO, false)

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


func _build_forest_and_rocks() -> void:
	var forest := Node3D.new()
	forest.name = "ForestAndRocks"
	add_child(forest)

	var mat_trunk := RetroModelBuilder.make_retro_material(Color(0.34, 0.22, 0.12), 0.94, 0.0)
	var mat_leaves_1 := RetroModelBuilder.make_retro_material(Color(0.14, 0.34, 0.14), 0.92, 0.0)
	var mat_leaves_2 := RetroModelBuilder.make_retro_material(Color(0.18, 0.40, 0.16), 0.92, 0.0)
	var mat_rock := _noise_material(Color(0.50, 0.50, 0.52), 0.8, 0.5)

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
		forest.add_child(tree)

		_make_static_box(tree, Vector3(0.7, 3.2, 0.7), Vector3(0, 1.6, 0), mat_trunk)

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
		{"pos": Vector3(-8.5, 0.6, -15.0), "size": Vector3(2.4, 1.4, 2.0), "rot": Vector3(8, 22, 0)},
		{"pos": Vector3(10.5, 0.8, -21.0), "size": Vector3(2.8, 1.8, 2.4), "rot": Vector3(-5, 45, 10)},
		{"pos": Vector3(-11.0, 0.9, -39.0), "size": Vector3(3.2, 2.1, 2.8), "rot": Vector3(4, -30, 6)},
		{"pos": Vector3(12.0, 0.7, -46.0), "size": Vector3(2.6, 1.6, 2.2), "rot": Vector3(-6, 15, -4)},
	]
	for r in rock_positions:
		_make_static_box(forest, r["size"], r["pos"], mat_rock, r["rot"], true)


func _build_bandit_camp(origin: Vector3) -> void:
	var camp := Node3D.new()
	camp.name = "BanditCamp"
	camp.position = origin
	add_child(camp)

	var mat_dirt := _noise_material(Color(0.45, 0.34, 0.22), 0.6, 0.25)
	var mat_wood := RetroModelBuilder.make_retro_material(Color(0.38, 0.24, 0.12), 0.90, 0.0)
	var mat_tent := RetroModelBuilder.make_retro_material(Color(0.60, 0.16, 0.14), 0.88, 0.0)
	var mat_ember := RetroModelBuilder.make_retro_material(Color(1.0, 0.45, 0.08), 0.3, 0.0, Color(1.0, 0.42, 0.05), 2.5)

	_make_static_box(camp, Vector3(16.0, 0.05, 15.0), Vector3(0, 0.02, 0), mat_dirt, Vector3.ZERO, false)

	# Шатёр разбойников Братства
	_make_static_box(camp, Vector3(0.24, 2.8, 0.24), Vector3(-4.5, 1.4, -3.5), mat_wood)
	_make_static_box(camp, Vector3(0.24, 2.8, 0.24), Vector3(-1.0, 1.4, -3.5), mat_wood)
	_make_static_box(camp, Vector3(4.2, 0.18, 3.6), Vector3(-2.75, 2.75, -4.6), mat_tent, Vector3(24, 0, 0), true)

	# Костёр лагеря
	_make_static_box(camp, Vector3(0.6, 0.18, 0.6), Vector3(0.5, 0.09, 0.5), mat_ember, Vector3.ZERO, false)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.52, 0.18)
	light.light_energy = 1.8
	light.omni_range = 10.0
	light.position = Vector3(0.5, 0.8, 0.5)
	camp.add_child(light)

	# Частокол
	for dz in [-5.5, -2.5, 2.5, 5.5]:
		_make_static_box(camp, Vector3(0.5, 1.6, 1.6), Vector3(-7.2, 0.8, dz), mat_wood, Vector3(0, 8, 0))

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
	var mat_wood := RetroModelBuilder.make_retro_material(Color(0.42, 0.28, 0.15), 0.90, 0.0)
	var mat_water := StandardMaterial3D.new()
	mat_water.albedo_color = Color(0.16, 0.52, 0.74, 0.80)
	mat_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_water.roughness = 0.20
	mat_water.metallic = 0.15
	mat_water.emission_enabled = true
	mat_water.emission = Color(0.08, 0.28, 0.42)
	mat_water.emission_energy_multiplier = 0.45

	# Песчаный берег и сияющая гладь воды
	_make_static_box(lake, Vector3(27.0, 0.05, 27.0), Vector3(0, 0.02, 0), mat_sand, Vector3.ZERO, false)
	var water_mi := MeshInstance3D.new()
	var wp := PlaneMesh.new()
	wp.size = Vector2(22.0, 22.0)
	water_mi.mesh = wp
	water_mi.material_override = mat_water
	water_mi.position = Vector3(1.5, 0.06, 0)
	lake.add_child(water_mi)

	# Деревянный причал
	_make_static_box(lake, Vector3(8.5, 0.22, 2.8), Vector3(-10.0, 0.22, 1.5), mat_wood, Vector3.ZERO, true)
	for px in [-13.5, -10.0, -6.5]:
		for pz in [0.4, 2.6]:
			_make_static_box(lake, Vector3(0.28, 0.7, 0.28), Vector3(px, 0.35, pz), mat_wood, Vector3.ZERO, false)


func _build_mine_entrance(origin: Vector3) -> void:
	var mine := Node3D.new()
	mine.name = "NorthernMine"
	mine.position = origin
	add_child(mine)

	var mat_rock := _noise_material(Color(0.36, 0.34, 0.37), 0.5, 0.55)
	var mat_floor := _noise_material(Color(0.28, 0.26, 0.28), 0.6, 0.4)
	var mat_timber := RetroModelBuilder.make_retro_material(Color(0.38, 0.24, 0.12), 0.92, 0.0)
	var mat_crate := RetroModelBuilder.make_retro_material(Color(0.50, 0.34, 0.18), 0.88, 0.0)
	var mat_torch := RetroModelBuilder.make_retro_material(Color(1.0, 0.65, 0.18), 0.3, 0.0, Color(1.0, 0.55, 0.10), 2.8)
	var mat_ore := RetroModelBuilder.make_retro_material(Color(0.35, 0.78, 1.0), 0.25, 0.3, Color(0.28, 0.68, 1.0), 2.2)

	# Входная скальная арка (проходимая! ширина проёма 9 м, высота 6 м)
	_make_static_box(mine, Vector3(11.0, 9.5, 7.0), Vector3(-10.0, 4.75, 0), mat_rock)
	_make_static_box(mine, Vector3(11.0, 9.5, 7.0), Vector3(10.0, 4.75, 0), mat_rock)
	_make_static_box(mine, Vector3(12.0, 3.6, 7.2), Vector3(0, 8.0, 0), mat_rock)

	# Деревянные балки входа
	_make_static_box(mine, Vector3(0.65, 6.2, 0.65), Vector3(-4.2, 3.1, 3.2), mat_timber)
	_make_static_box(mine, Vector3(0.65, 6.2, 0.65), Vector3(4.2, 3.1, 3.2), mat_timber)
	_make_static_box(mine, Vector3(9.4, 0.7, 0.8), Vector3(0, 6.1, 3.2), mat_timber)

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

	# Подпорки тоннеля, факелы и жилы руды
	for tz in [3.2, -6.0, -14.0, -21.0]:
		if tz < 2.0:
			_make_static_box(mine, Vector3(0.55, 6.4, 0.55), Vector3(-4.1, 3.2, tz), mat_timber)
			_make_static_box(mine, Vector3(0.55, 6.4, 0.55), Vector3(4.1, 3.2, tz), mat_timber)
			_make_static_box(mine, Vector3(8.8, 0.55, 0.55), Vector3(0, 6.4, tz), mat_timber)
		for sx in [-3.7, 3.7]:
			_make_static_box(mine, Vector3(0.24, 0.24, 0.24), Vector3(sx, 3.2, tz + 0.35), mat_torch, Vector3.ZERO, false)
			var tl := OmniLight3D.new()
			tl.light_color = Color(1.0, 0.58, 0.20)
			tl.light_energy = 1.9
			tl.omni_range = 12.0
			tl.position = Vector3(sx, 3.3, tz + 0.6)
			mine.add_child(tl)

	# Освещение и кристаллы в глубине зала
	for pos in [Vector3(-8.5, 4.0, -31.0), Vector3(8.5, 4.0, -31.0), Vector3(0.0, 5.0, -40.0)]:
		var cl := OmniLight3D.new()
		cl.light_color = Color(0.95, 0.68, 0.32)
		cl.light_energy = 2.4
		cl.omni_range = 18.0
		cl.position = pos
		mine.add_child(cl)

	for ore_pos in [Vector3(-11.0, 1.2, -30.0), Vector3(11.0, 1.4, -36.0), Vector3(-7.0, 1.0, -44.0), Vector3(7.0, 1.1, -44.0)]:
		_make_static_box(mine, Vector3(0.9, 1.6, 0.9), ore_pos, mat_ore, Vector3(12, 24, 10), true)

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
