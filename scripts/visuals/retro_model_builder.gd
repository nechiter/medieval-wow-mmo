class_name RetroModelBuilder
extends RefCounted


static func make_retro_material(color: Color, roughness: float = 0.88, metallic: float = 0.08, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


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

	var mat_armor := make_retro_material(armor_color, 0.65, 0.35)
	var mat_accent := make_retro_material(accent_color, 0.48, 0.55)
	var mat_skin := make_retro_material(skin_color, 0.85, 0.02)
	var mat_pants := make_retro_material(pants_color, 0.90, 0.05)
	var mat_boots := make_retro_material(pants_color.darkened(0.25), 0.78, 0.15)
	var mat_cape := make_retro_material(cape_color, 0.92, 0.0)
	var mat_hair := make_retro_material(hair_color, 0.90, 0.05)
	var mat_eye := make_retro_material(eye_color, 0.4, 0.0, eye_color if eye_color.v > 0.6 else Color.BLACK, 1.4 if eye_color.v > 0.6 else 0.0)
	var mat_steel := make_retro_material(Color(0.72, 0.76, 0.82), 0.35, 0.75)
	var mat_wood := make_retro_material(Color(0.42, 0.26, 0.13), 0.90, 0.02)

	var rig := Node3D.new()
	rig.name = "HumanoidRig"
	rig.scale = Vector3.ONE * scale_factor

	var root_pivot := Node3D.new()
	root_pivot.name = "RootPivot"
	rig.add_child(root_pivot)

	# Ноги (шарнир у бедра на высоте 0.75)
	var leg_l := Node3D.new()
	leg_l.name = "LegLPivot"
	leg_l.position = Vector3(-0.16, 0.76, 0.0)
	root_pivot.add_child(leg_l)
	leg_l.add_child(_make_box_mesh(Vector3(0.20, 0.42, 0.22), mat_pants, Vector3(0, -0.21, 0), Vector3.ZERO, "ThighL"))
	leg_l.add_child(_make_box_mesh(Vector3(0.23, 0.34, 0.27), mat_boots, Vector3(0, -0.58, -0.02), Vector3.ZERO, "BootL"))
	leg_l.add_child(_make_box_mesh(Vector3(0.25, 0.08, 0.29), mat_accent, Vector3(0, -0.43, -0.02), Vector3.ZERO, "BootTrimL"))

	var leg_r := Node3D.new()
	leg_r.name = "LegRPivot"
	leg_r.position = Vector3(0.16, 0.76, 0.0)
	root_pivot.add_child(leg_r)
	leg_r.add_child(_make_box_mesh(Vector3(0.20, 0.42, 0.22), mat_pants, Vector3(0, -0.21, 0), Vector3.ZERO, "ThighR"))
	leg_r.add_child(_make_box_mesh(Vector3(0.23, 0.34, 0.27), mat_boots, Vector3(0, -0.58, -0.02), Vector3.ZERO, "BootR"))
	leg_r.add_child(_make_box_mesh(Vector3(0.25, 0.08, 0.29), mat_accent, Vector3(0, -0.43, -0.02), Vector3.ZERO, "BootTrimR"))

	# Торс
	var torso_pivot := Node3D.new()
	torso_pivot.name = "TorsoPivot"
	torso_pivot.position = Vector3(0.0, 0.78, 0.0)
	root_pivot.add_child(torso_pivot)

	# Сутулость для кобольдов в стиле WoW
	if archetype == "kobold":
		torso_pivot.rotation_degrees = Vector3(-16, 0, 0)

	# Пояс и бляха
	torso_pivot.add_child(_make_box_mesh(Vector3(0.50, 0.14, 0.32), mat_boots, Vector3(0, 0.06, 0), Vector3.ZERO, "Belt"))
	torso_pivot.add_child(_make_box_mesh(Vector3(0.16, 0.12, 0.05), mat_accent, Vector3(0, 0.06, -0.17), Vector3.ZERO, "Buckle"))

	# Грудь / кираса
	torso_pivot.add_child(_make_box_mesh(Vector3(0.56, 0.52, 0.34), mat_armor, Vector3(0, 0.36, 0), Vector3.ZERO, "Chest"))
	# Табард / нагрудный знак спереди
	torso_pivot.add_child(_make_box_mesh(Vector3(0.32, 0.44, 0.04), mat_accent if archetype == "guard" else mat_cape, Vector3(0, 0.32, -0.18), Vector3.ZERO, "Tabard"))

	# Плащ (шарнир на плечах)
	if has_cape:
		var cape_pivot := Node3D.new()
		cape_pivot.name = "CapePivot"
		cape_pivot.position = Vector3(0, 0.58, 0.18)
		torso_pivot.add_child(cape_pivot)
		cape_pivot.add_child(_make_box_mesh(Vector3(0.48, 0.92, 0.04), mat_cape, Vector3(0, -0.46, 0.04), Vector3(-6, 0, 0), "CapeMesh"))

	# Голова
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, 0.64, 0.0)
	torso_pivot.add_child(head_pivot)

	head_pivot.add_child(_make_box_mesh(Vector3(0.34, 0.34, 0.34), mat_skin, Vector3(0, 0.19, 0), Vector3.ZERO, "Head"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.06, 0.05, 0.04), mat_eye, Vector3(-0.08, 0.21, -0.17), Vector3.ZERO, "EyeL"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.06, 0.05, 0.04), mat_eye, Vector3(0.08, 0.21, -0.17), Vector3.ZERO, "EyeR"))

	if archetype == "kobold":
		# Крысиная мордочка и большие уши кобольда
		var mat_ear := make_retro_material(skin_color.darkened(0.12), 0.85, 0.02)
		head_pivot.add_child(_make_box_mesh(Vector3(0.16, 0.12, 0.18), mat_skin, Vector3(0, 0.14, -0.22), Vector3(10, 0, 0), "Snout"))
		head_pivot.add_child(_make_box_mesh(Vector3(0.10, 0.16, 0.06), mat_ear, Vector3(-0.20, 0.26, 0.02), Vector3(0, 0, 22), "EarL"))
		head_pivot.add_child(_make_box_mesh(Vector3(0.10, 0.16, 0.06), mat_ear, Vector3(0.20, 0.26, 0.02), Vector3(0, 0, -22), "EarR"))
	elif archetype == "mage":
		# Остроконечная шляпа мага
		var mat_hat := make_retro_material(armor_color.darkened(0.15), 0.85, 0.05)
		head_pivot.add_child(_make_box_mesh(Vector3(0.52, 0.05, 0.52), mat_hat, Vector3(0, 0.33, 0), Vector3.ZERO, "HatBrim"))
		head_pivot.add_child(_make_prism_or_cyl(0.02, 0.19, 0.46, 6, mat_hat, Vector3(0, 0.58, 0), Vector3(-6, 0, 0), "HatCone"))
		head_pivot.add_child(_make_box_mesh(Vector3(0.38, 0.12, 0.36), mat_hair, Vector3(0, 0.12, 0.10), Vector3.ZERO, "HairBack"))
	elif archetype == "guard":
		# Шлем стражника с гребнем
		head_pivot.add_child(_make_box_mesh(Vector3(0.38, 0.18, 0.38), mat_steel, Vector3(0, 0.31, 0), Vector3.ZERO, "HelmTop"))
		head_pivot.add_child(_make_box_mesh(Vector3(0.08, 0.14, 0.42), mat_accent, Vector3(0, 0.40, 0), Vector3.ZERO, "HelmCrest"))
	else:
		# Пышные волосы/причёска и лёгкий обод воина
		head_pivot.add_child(_make_box_mesh(Vector3(0.37, 0.14, 0.37), mat_hair, Vector3(0, 0.33, 0.01), Vector3.ZERO, "HairTop"))
		head_pivot.add_child(_make_box_mesh(Vector3(0.38, 0.22, 0.16), mat_hair, Vector3(0, 0.21, 0.12), Vector3.ZERO, "HairBack"))

	if has_candle:
		# Знаменитая свеча на голове у кобольдов!
		var mat_wax := make_retro_material(Color(0.95, 0.90, 0.72), 0.7, 0.0)
		var mat_flame := make_retro_material(Color(1.0, 0.72, 0.15), 0.2, 0.0, Color(1.0, 0.62, 0.10), 2.8)
		head_pivot.add_child(_make_prism_or_cyl(0.055, 0.065, 0.22, 6, mat_wax, Vector3(0, 0.46, 0), Vector3.ZERO, "CandleWax"))
		head_pivot.add_child(_make_prism_or_cyl(0.005, 0.045, 0.12, 5, mat_flame, Vector3(0, 0.62, 0), Vector3.ZERO, "CandleFlame"))

	# Левая рука + крупный наплечник в духе WoW Classic
	var arm_l := Node3D.new()
	arm_l.name = "ArmLPivot"
	arm_l.position = Vector3(-0.37, 0.54, 0.0)
	torso_pivot.add_child(arm_l)
	arm_l.add_child(_make_box_mesh(Vector3(0.28, 0.22, 0.30), mat_accent if archetype != "kobold" else mat_armor, Vector3(-0.04, 0.04, 0), Vector3(0, 0, 14), "PauldronL"))
	arm_l.add_child(_make_box_mesh(Vector3(0.18, 0.46, 0.18), mat_armor, Vector3(-0.04, -0.22, 0), Vector3.ZERO, "ArmMeshL"))
	arm_l.add_child(_make_box_mesh(Vector3(0.16, 0.14, 0.16), mat_skin, Vector3(-0.04, -0.50, 0), Vector3.ZERO, "HandL"))

	if has_shield:
		var shield_grp := Node3D.new()
		shield_grp.name = "ShieldMesh"
		shield_grp.position = Vector3(-0.16, -0.35, -0.10)
		arm_l.add_child(shield_grp)
		shield_grp.add_child(_make_box_mesh(Vector3(0.06, 0.58, 0.44), mat_armor, Vector3.ZERO, Vector3.ZERO, "ShieldBody"))
		shield_grp.add_child(_make_box_mesh(Vector3(0.08, 0.24, 0.16), mat_accent, Vector3(-0.01, 0.0, 0.0), Vector3.ZERO, "ShieldBoss"))

	# Правая рука + наплечник + оружие
	var arm_r := Node3D.new()
	arm_r.name = "ArmRPivot"
	arm_r.position = Vector3(0.37, 0.54, 0.0)
	torso_pivot.add_child(arm_r)
	arm_r.add_child(_make_box_mesh(Vector3(0.28, 0.22, 0.30), mat_accent if archetype != "kobold" else mat_armor, Vector3(0.04, 0.04, 0), Vector3(0, 0, -14), "PauldronR"))
	arm_r.add_child(_make_box_mesh(Vector3(0.18, 0.46, 0.18), mat_armor, Vector3(0.04, -0.22, 0), Vector3.ZERO, "ArmMeshR"))
	arm_r.add_child(_make_box_mesh(Vector3(0.16, 0.14, 0.16), mat_skin, Vector3(0.04, -0.50, 0), Vector3.ZERO, "HandR"))

	var weapon_node := _build_weapon(weapon_type, mat_steel, mat_accent, mat_wood)
	weapon_node.name = "WeaponMesh"
	weapon_node.position = Vector3(0.04, -0.52, -0.06)
	arm_r.add_child(weapon_node)

	return rig


static func _build_weapon(weapon_type: String, mat_steel: Material, mat_accent: Material, mat_wood: Material) -> Node3D:
	var w := Node3D.new()
	if weapon_type == "staff":
		# Посох мага с светящимся кристаллом
		var mat_crystal := make_retro_material(Color(0.4, 0.75, 1.0), 0.2, 0.0, Color(0.35, 0.7, 1.0), 2.6)
		w.add_child(_make_box_mesh(Vector3(0.06, 0.06, 1.5), mat_wood, Vector3(0, 0, -0.55), Vector3.ZERO, "Shaft"))
		w.add_child(_make_box_mesh(Vector3(0.16, 0.16, 0.16), mat_crystal, Vector3(0, 0, -1.38), Vector3(45, 45, 0), "Crystal"))
		w.add_child(_make_box_mesh(Vector3(0.12, 0.12, 0.05), mat_accent, Vector3(0, 0, -1.26), Vector3.ZERO, "Holder"))
	elif weapon_type == "pickaxe":
		# Кирка кобольда
		w.add_child(_make_box_mesh(Vector3(0.06, 0.06, 0.78), mat_wood, Vector3(0, 0, -0.28), Vector3.ZERO, "Handle"))
		w.add_child(_make_box_mesh(Vector3(0.54, 0.08, 0.09), mat_steel, Vector3(0, 0, -0.62), Vector3.ZERO, "PickHead"))
	elif weapon_type == "greataxe":
		# Гигантский двуручный топор босса Дробителя
		w.add_child(_make_box_mesh(Vector3(0.07, 0.07, 1.35), mat_wood, Vector3(0, 0, -0.52), Vector3.ZERO, "Handle"))
		w.add_child(_make_box_mesh(Vector3(0.46, 0.36, 0.09), mat_steel, Vector3(0, 0.04, -1.05), Vector3.ZERO, "AxeBlade"))
		w.add_child(_make_box_mesh(Vector3(0.18, 0.18, 0.12), mat_accent, Vector3(0, 0.04, -1.05), Vector3.ZERO, "AxeTrim"))
	elif weapon_type == "shortsword":
		# Меч стражника
		w.add_child(_make_box_mesh(Vector3(0.05, 0.05, 0.24), mat_wood, Vector3(0, 0, 0.02), Vector3.ZERO, "Grip"))
		w.add_child(_make_box_mesh(Vector3(0.24, 0.06, 0.05), mat_accent, Vector3(0, 0, -0.12), Vector3.ZERO, "Guard"))
		w.add_child(_make_box_mesh(Vector3(0.08, 0.03, 0.72), mat_steel, Vector3(0, 0, -0.50), Vector3.ZERO, "Blade"))
	else:
		# Классический двуручный меч воина (greatsword)
		w.add_child(_make_box_mesh(Vector3(0.06, 0.06, 0.32), mat_wood, Vector3(0, 0, 0.04), Vector3.ZERO, "Grip"))
		w.add_child(_make_box_mesh(Vector3(0.10, 0.10, 0.10), mat_accent, Vector3(0, 0, 0.20), Vector3.ZERO, "Pommel"))
		w.add_child(_make_box_mesh(Vector3(0.34, 0.08, 0.07), mat_accent, Vector3(0, 0, -0.14), Vector3.ZERO, "Crossguard"))
		w.add_child(_make_box_mesh(Vector3(0.11, 0.04, 1.06), mat_steel, Vector3(0, 0, -0.70), Vector3.ZERO, "Blade"))
	return w


static func build_wolf(config: Dictionary) -> Node3D:
	var scale_factor: float = float(config.get("scale", 1.0))
	var fur_color: Color = config.get("fur_color", Color(0.36, 0.34, 0.33))
	var belly_color: Color = config.get("belly_color", Color(0.55, 0.51, 0.46))
	var eye_color: Color = config.get("eye_color", Color(1.0, 0.75, 0.18))

	var mat_fur := make_retro_material(fur_color, 0.94, 0.0)
	var mat_mane := make_retro_material(fur_color.darkened(0.22), 0.96, 0.0)
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
	body_pivot.position = Vector3(0, 0.62, 0)
	root_pivot.add_child(body_pivot)

	# Туловище и грива
	body_pivot.add_child(_make_box_mesh(Vector3(0.42, 0.40, 0.95), mat_fur, Vector3(0, 0, 0), Vector3.ZERO, "Torso"))
	body_pivot.add_child(_make_box_mesh(Vector3(0.48, 0.45, 0.38), mat_mane, Vector3(0, 0.05, -0.28), Vector3.ZERO, "Mane"))
	body_pivot.add_child(_make_box_mesh(Vector3(0.32, 0.10, 0.74), mat_belly, Vector3(0, -0.18, 0), Vector3.ZERO, "Belly"))

	# Голова волка
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0, 0.18, -0.52)
	body_pivot.add_child(head_pivot)
	head_pivot.add_child(_make_box_mesh(Vector3(0.32, 0.28, 0.34), mat_fur, Vector3(0, 0.04, -0.10), Vector3.ZERO, "Skull"))
	var mat_snout := make_retro_material(fur_color.lightened(0.08), 0.94, 0.0)
	head_pivot.add_child(_make_box_mesh(Vector3(0.18, 0.16, 0.26), mat_snout, Vector3(0, -0.02, -0.34), Vector3.ZERO, "Snout"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.08, 0.06, 0.06), mat_nose, Vector3(0, 0.04, -0.47), Vector3.ZERO, "Nose"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.06, 0.05, 0.05), mat_eye, Vector3(-0.09, 0.10, -0.27), Vector3.ZERO, "EyeL"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.06, 0.05, 0.05), mat_eye, Vector3(0.09, 0.10, -0.27), Vector3.ZERO, "EyeR"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.08, 0.16, 0.08), mat_mane, Vector3(-0.11, 0.22, -0.05), Vector3(0, 0, 12), "EarL"))
	head_pivot.add_child(_make_box_mesh(Vector3(0.08, 0.16, 0.08), mat_mane, Vector3(0.11, 0.22, -0.05), Vector3(0, 0, -12), "EarR"))

	# Хвост
	var tail_pivot := Node3D.new()
	tail_pivot.name = "TailPivot"
	tail_pivot.position = Vector3(0, 0.08, 0.46)
	body_pivot.add_child(tail_pivot)
	tail_pivot.add_child(_make_box_mesh(Vector3(0.12, 0.12, 0.46), mat_mane, Vector3(0, -0.06, 0.20), Vector3(-24, 0, 0), "TailMesh"))

	# 4 лапы
	var leg_offsets: Dictionary = {
		"LegFL": Vector3(-0.15, -0.14, -0.32),
		"LegFR": Vector3(0.15, -0.14, -0.32),
		"LegBL": Vector3(-0.15, -0.14, 0.32),
		"LegBR": Vector3(0.15, -0.14, 0.32),
	}
	for leg_name in leg_offsets.keys():
		var lp := Node3D.new()
		lp.name = leg_name
		lp.position = leg_offsets[leg_name]
		body_pivot.add_child(lp)
		lp.add_child(_make_box_mesh(Vector3(0.13, 0.46, 0.14), mat_fur, Vector3(0, -0.23, 0), Vector3.ZERO, "LegMesh"))

	return rig


static func animate_humanoid(rig: Node3D, anim_state: String, anim_time: float, attack_progress: float = 0.0, spin_angle: float = 0.0, base_hunch: float = 0.0) -> void:
	if not is_instance_valid(rig):
		return
	var root := rig.get_node_or_null("RootPivot") as Node3D
	if root == null:
		return
	var torso := root.get_node_or_null("TorsoPivot") as Node3D
	var head := torso.get_node_or_null("HeadPivot") as Node3D if torso else null
	var arm_l := torso.get_node_or_null("ArmLPivot") as Node3D if torso else null
	var arm_r := torso.get_node_or_null("ArmRPivot") as Node3D if torso else null
	var cape := torso.get_node_or_null("CapePivot") as Node3D if torso else null
	var leg_l := root.get_node_or_null("LegLPivot") as Node3D
	var leg_r := root.get_node_or_null("LegRPivot") as Node3D

	if anim_state == "DEAD":
		root.position = Vector3(0, 0.22, 0)
		root.rotation = Vector3(-PI * 0.47, 0, 0.15)
		if arm_l:
			arm_l.rotation = Vector3(0, 0, -0.45)
		if arm_r:
			arm_r.rotation = Vector3(0.2, 0, 0.55)
		if leg_l:
			leg_l.rotation = Vector3(0, 0, -0.15)
		if leg_r:
			leg_r.rotation = Vector3(0, 0, 0.18)
		return

	root.position = Vector3.ZERO
	root.rotation = Vector3.ZERO

	var swing: float = 0.0
	var bob: float = 0.0
	var torso_pitch: float = base_hunch
	var torso_yaw: float = 0.0

	if anim_state == "WALK" or anim_state == "CHARGE":
		var speed_mult: float = 13.0 if anim_state == "CHARGE" else 8.5
		swing = sin(anim_time * speed_mult) * 0.72
		bob = absf(sin(anim_time * speed_mult)) * 0.07
		torso_pitch += -0.28 if anim_state == "CHARGE" else -0.10
		if cape:
			cape.rotation = Vector3(-0.42 - absf(sin(anim_time * 7.0)) * 0.14, 0, 0)
	else:
		# IDLE
		bob = sin(anim_time * 2.2) * 0.02
		if cape:
			cape.rotation = Vector3(-0.08 - sin(anim_time * 2.0) * 0.04, 0, 0)

	if leg_l:
		leg_l.rotation = Vector3(swing, 0, 0)
	if leg_r:
		leg_r.rotation = Vector3(-swing, 0, 0)

	var arm_l_rot := Vector3(-swing * 0.8, 0, -0.10)
	var arm_r_rot := Vector3(swing * 0.75 + 0.18, 0, 0.10)

	if anim_state == "WHIRLWIND":
		root.rotation.y = spin_angle
		torso_pitch = base_hunch - 0.18
		arm_l_rot = Vector3(0.2, 0, -1.35)
		arm_r_rot = Vector3(1.35, 0.4, 1.15)
		if cape:
			cape.rotation = Vector3(-0.75, 0, 0)
	elif attack_progress > 0.0:
		# Рубящий замах и удар в стиле WoW Classic
		var p: float = clampf(attack_progress, 0.0, 1.0)
		if p < 0.32:
			var t: float = p / 0.32
			arm_r_rot = Vector3(lerpf(0.2, 2.25, t), 0.25 * t, 0.35 * t)
			torso_yaw = -0.35 * t
			torso_pitch += 0.15 * t
		elif p < 0.68:
			var t: float = (p - 0.32) / 0.36
			arm_r_rot = Vector3(lerpf(2.25, -0.95, t), lerpf(0.25, -0.35, t), lerpf(0.35, -0.15, t))
			torso_yaw = lerpf(-0.35, 0.42, t)
			torso_pitch += lerpf(0.15, -0.25, t)
		else:
			var t: float = (p - 0.68) / 0.32
			arm_r_rot = Vector3(lerpf(-0.95, 0.2, t), lerpf(-0.35, 0.0, t), lerpf(-0.15, 0.10, t))
			torso_yaw = lerpf(0.42, 0.0, t)
		arm_l_rot = Vector3(-0.35, 0, -0.25)

	if torso:
		torso.position.y = 0.78 + bob
		torso.rotation = Vector3(torso_pitch, torso_yaw, 0)
	if head:
		head.rotation = Vector3(-torso_pitch * 0.4 + sin(anim_time * 1.5) * 0.03, -torso_yaw * 0.5, 0)
	if arm_l:
		arm_l.rotation = arm_l_rot
	if arm_r:
		arm_r.rotation = arm_r_rot


static func animate_wolf(rig: Node3D, anim_state: String, anim_time: float, attack_progress: float = 0.0) -> void:
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

	if anim_state == "DEAD":
		root.position = Vector3(0, 0.20, 0)
		root.rotation = Vector3(0, 0, PI * 0.48)
		return

	root.position = Vector3.ZERO
	root.rotation = Vector3.ZERO

	var stride: float = 0.0
	var body_bob: float = 0.0
	var lunge_z: float = 0.0
	var head_pitch: float = 0.0

	if anim_state == "WALK":
		stride = sin(anim_time * 11.0) * 0.65
		body_bob = absf(sin(anim_time * 11.0)) * 0.05
	else:
		body_bob = sin(anim_time * 2.5) * 0.02

	if attack_progress > 0.0:
		var bite_curve: float = sin(clampf(attack_progress, 0.0, 1.0) * PI)
		lunge_z = -0.25 * bite_curve
		head_pitch = -0.35 * bite_curve

	body.position = Vector3(0, 0.62 + body_bob, lunge_z)
	if head:
		head.rotation = Vector3(head_pitch, sin(anim_time * 1.4) * 0.08, 0)
	if tail:
		tail.rotation = Vector3(0.15, sin(anim_time * 5.0) * 0.28, 0)

	if leg_fl:
		leg_fl.rotation = Vector3(stride, 0, 0)
	if leg_fr:
		leg_fr.rotation = Vector3(-stride, 0, 0)
	if leg_bl:
		leg_bl.rotation = Vector3(-stride, 0, 0)
	if leg_br:
		leg_br.rotation = Vector3(stride, 0, 0)
