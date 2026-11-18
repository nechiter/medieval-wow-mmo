class_name PlayerController
extends CharacterBody3D

const GRAVITY := 26.0
const WALK_SPEED := 7.6
const BACKPEDAL_SPEED := 4.8
const TURN_SPEED := 2.6
const JUMP_VELOCITY := 9.2
const SWING_INTERVAL := 1.9
const DAGGER_INTERVAL := 1.3
const MELEE_RANGE := 3.9
const WAND_RANGE := 22.0
const WAND_INTERVAL := 1.7
const BOW_RANGE := 24.0
const BOW_INTERVAL := 1.45
const SPELL_RANGE := 30.0

var casting_slot: int = 0
var cast_timer: float = 0.0
var cast_total: float = 0.0
var cast_target: MobEntity = null
var gather_target_prop: InteractableProp = null
var step_accum: float = 0.0

var rig_node: Node3D = null
var camera_pivot: Node3D = null
var spring_arm: SpringArm3D = null
var camera: Camera3D = null
var target_ring: MeshInstance3D = null

var cam_yaw: float = 0.0
var cam_pitch: float = -0.34
var cam_dist: float = 8.2

var lmb_down: bool = false
var rmb_down: bool = false
var lmb_press_pos: Vector2 = Vector2.ZERO
var rmb_press_pos: Vector2 = Vector2.ZERO
var lmb_drag_dist: float = 0.0
var rmb_drag_dist: float = 0.0
var is_mouse_captured_for_drag: bool = false

var anim_time: float = 0.0
var attack_anim_timer: float = 0.0
var whirlwind_anim_timer: float = 0.0
var swing_timer: float = 0.0
var auto_attack_enabled: bool = false

var is_charging: bool = false
var charge_target: MobEntity = null
var charge_timeout: float = 0.0

var spawn_position: Vector3 = Vector3.ZERO
var corpse_node: Node3D = null
var tab_cycle_index: int = 0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1
	GameState.player_node = self
	spawn_position = global_position
	if GameState.has_pending_load_transform:
		GameState.has_pending_load_transform = false
		global_position = GameState.pending_load_pos
		rotation.y = GameState.pending_load_yaw
	cam_yaw = rotation.y

	_build_collision()
	_build_visuals()
	_build_camera()
	_build_target_ring()

	GameState.player_leveled_up.connect(_on_level_up)
	GameState.player_died.connect(_on_player_died)
	GameState.spirit_released.connect(_on_spirit_released)
	GameState.player_resurrected.connect(_on_player_resurrected)
	GameState.target_changed.connect(_on_target_changed)
	GameState.player_stats_changed.connect(_refresh_transparency)
	GameState.equipment_changed.connect(_on_equipment_changed)
	_ensure_hunter_pet()


func _build_collision() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.52
	cap.height = 1.85
	col.shape = cap
	col.position = Vector3(0, 0.92, 0)
	add_child(col)


func _visual_config() -> Dictionary:
	var tier: int = GameState.get_armor_visual_tier()
	var w_vis: String = GameState.get_weapon_visual_id()
	if GameState.player_class == "mage":
		var m_col := Color(0.28, 0.24, 0.68) if tier >= 2 else (Color(0.24, 0.34, 0.66) if tier == 1 else Color(0.22, 0.28, 0.62))
		return {
			"scale": 1.05,
			"archetype": "mage",
			"armor_color": m_col,
			"accent_color": Color(0.92, 0.78, 0.32) if tier >= 1 else Color(0.85, 0.72, 0.30),
			"skin_color": Color(0.88, 0.70, 0.56),
			"pants_color": Color(0.16, 0.18, 0.40),
			"cape_color": Color(0.36, 0.16, 0.62) if tier >= 2 else Color(0.30, 0.20, 0.58),
			"hair_color": Color(0.85, 0.85, 0.88),
			"eye_color": Color(0.35, 0.70, 1.0),
			"weapon_type": w_vis,
			"armor_tier": tier,
			"has_cape": true,
		}
	if GameState.player_class == "rogue":
		var r_col := Color(0.24, 0.16, 0.22) if tier >= 2 else (Color(0.20, 0.22, 0.26) if tier == 1 else Color(0.18, 0.19, 0.23))
		return {
			"scale": 1.02,
			"archetype": "rogue",
			"armor_color": r_col,
			"accent_color": Color(0.78, 0.22, 0.22) if tier >= 1 else Color(0.65, 0.18, 0.18),
			"skin_color": Color(0.86, 0.69, 0.55),
			"pants_color": Color(0.14, 0.14, 0.16),
			"cape_color": Color(0.28, 0.10, 0.12),
			"hair_color": Color(0.15, 0.12, 0.10),
			"eye_color": Color(0.25, 0.85, 0.45),
			"weapon_type": w_vis,
			"armor_tier": tier,
			"has_cape": true,
			"has_offhand_dagger": w_vis == "dagger",
		}
	if GameState.player_class == "hunter":
		var h_col := Color(0.18, 0.44, 0.24) if tier >= 2 else (Color(0.22, 0.40, 0.22) if tier == 1 else Color(0.24, 0.36, 0.20))
		return {
			"scale": 1.04,
			"archetype": "hunter",
			"armor_color": h_col,
			"accent_color": Color(0.82, 0.66, 0.24),
			"skin_color": Color(0.87, 0.70, 0.56),
			"pants_color": Color(0.22, 0.18, 0.14),
			"cape_color": Color(0.16, 0.34, 0.16),
			"hair_color": Color(0.42, 0.24, 0.12),
			"eye_color": Color(0.25, 0.82, 0.38),
			"weapon_type": w_vis,
			"armor_tier": tier,
			"has_cape": true,
		}
	var w_col := Color(0.38, 0.22, 0.26) if tier >= 2 else (Color(0.30, 0.40, 0.52) if tier == 1 else Color(0.28, 0.34, 0.44))
	return {
		"scale": 1.05,
		"archetype": "warrior",
		"armor_color": w_col,
		"accent_color": Color(0.88, 0.70, 0.26) if tier >= 1 else Color(0.78, 0.60, 0.22),
		"skin_color": Color(0.88, 0.70, 0.56),
		"pants_color": Color(0.20, 0.18, 0.17),
		"cape_color": Color(0.68, 0.12, 0.12),
		"hair_color": Color(0.28, 0.17, 0.10),
		"eye_color": Color(0.16, 0.36, 0.65),
		"weapon_type": w_vis,
		"armor_tier": tier,
		"has_cape": true,
		"has_shield": false,
	}


func _on_equipment_changed() -> void:
	if is_instance_valid(rig_node):
		rig_node.free()
		rig_node = null
	_build_visuals()
	_refresh_transparency()
	_ensure_hunter_pet()


func _ensure_hunter_pet() -> void:
	if GameState.player_class == "hunter":
		if not is_instance_valid(GameState.pet_node) and get_parent() != null:
			var pet := PetCompanion.new()
			pet.name = "HunterWolfPet"
			pet.position = global_position + Vector3(-1.5, 0.0, 1.4)
			get_parent().add_child.call_deferred(pet)
		elif is_instance_valid(GameState.pet_node) and GameState.pet_node.has_method("sync_stats"):
			GameState.pet_node.call("sync_stats", false)
	else:
		if is_instance_valid(GameState.pet_node):
			GameState.pet_node.queue_free()
			GameState.pet_node = null


func _build_visuals() -> void:
	rig_node = RetroModelBuilder.build_humanoid(_visual_config())
	add_child(rig_node)


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.top_level = true
	add_child(camera_pivot)
	camera_pivot.global_position = global_position + Vector3(0, 1.55, 0)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = cam_dist
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.35
	camera_pivot.add_child(spring_arm)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 62.0
	camera.far = 260.0
	camera.current = true
	spring_arm.add_child(camera)


func _build_target_ring() -> void:
	target_ring = MeshInstance3D.new()
	target_ring.name = "TargetRing"
	target_ring.top_level = true
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.02
	torus.rings = 24
	torus.ring_segments = 6
	target_ring.mesh = torus
	target_ring.scale = Vector3(1.0, 0.15, 1.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.22, 0.18, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.22, 0.18)
	mat.emission_energy_multiplier = 1.8
	target_ring.material_override = mat
	target_ring.visible = false
	add_child(target_ring)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		lmb_down = false
		rmb_down = false
		_release_drag_capture()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_dist = clampf(cam_dist - 1.0, 2.8, 18.0)
			spring_arm.spring_length = cam_dist
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_dist = clampf(cam_dist + 1.0, 2.8, 18.0)
			spring_arm.spring_length = cam_dist
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				lmb_down = true
				lmb_press_pos = mb.position
				lmb_drag_dist = 0.0
			else:
				var was_click: bool = lmb_down and lmb_drag_dist <= 6.0
				lmb_down = false
				if not rmb_down:
					_release_drag_capture()
				if was_click:
					_try_click_world(mb.position, false)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				rmb_down = true
				rmb_press_pos = mb.position
				rmb_drag_dist = 0.0
			else:
				var was_click: bool = rmb_down and rmb_drag_dist <= 6.0
				rmb_down = false
				if not lmb_down:
					_release_drag_capture()
				if was_click:
					_try_click_world(mb.position, true)

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if lmb_down or rmb_down:
			var delta_len: float = mm.relative.length()
			if lmb_down:
				lmb_drag_dist += delta_len
			if rmb_down:
				rmb_drag_dist += delta_len

			if not is_mouse_captured_for_drag and (lmb_drag_dist > 5.0 or rmb_drag_dist > 5.0):
				is_mouse_captured_for_drag = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

			if is_mouse_captured_for_drag:
				cam_yaw -= mm.relative.x * 0.0048
				cam_pitch = clampf(cam_pitch - mm.relative.y * 0.0042, -1.25, 0.25)
				if rmb_down and not GameState.is_dead:
					rotation.y = cam_yaw

	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.physical_keycode:
				KEY_TAB:
					_cycle_tab_target()
					get_viewport().set_input_as_handled()
				KEY_1:
					trigger_ability(1)
				KEY_2:
					trigger_ability(2)
				KEY_3:
					trigger_ability(3)
				KEY_4:
					trigger_ability(4)
				KEY_5:
					trigger_ability(5)
				KEY_6:
					GameState.use_first_item_by_types(["potion", "bandage"])
				KEY_7:
					GameState.use_first_item_by_types(["elixir", "mana_potion", "food"])
				KEY_8:
					GameState.use_first_item_by_types(["hearthstone"])
				KEY_F:
					_interact_nearest_or_target()
				KEY_ESCAPE:
					if GameState.current_target != null:
						GameState.set_target(null)
						auto_attack_enabled = false


func _release_drag_capture() -> void:
	if is_mouse_captured_for_drag:
		is_mouse_captured_for_drag = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	anim_time += delta
	if attack_anim_timer > 0.0:
		attack_anim_timer = maxf(0.0, attack_anim_timer - delta)
	if whirlwind_anim_timer > 0.0:
		whirlwind_anim_timer = maxf(0.0, whirlwind_anim_timer - delta)
	if swing_timer > 0.0:
		swing_timer = maxf(0.0, swing_timer - delta)

	if GameState.is_dead and not GameState.is_ghost:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		_update_camera_and_ring(delta)
		_update_animation(delta)
		return

	if is_charging:
		_process_charge(delta)
	else:
		_process_movement(delta)

	if not GameState.is_dead:
		_process_cast(delta)
		_process_auto_attack()
	_update_camera_and_ring(delta)
	_update_animation(delta)


func _process_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = JUMP_VELOCITY
	else:
		velocity.y = 0.0

	var forward_input: float = 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		forward_input += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		forward_input -= 1.0
	if lmb_down and rmb_down:
		forward_input = 1.0

	var strafe_input: float = 0.0
	if Input.is_physical_key_pressed(KEY_Q):
		strafe_input -= 1.0
	if Input.is_physical_key_pressed(KEY_E):
		strafe_input += 1.0

	var turn_input: float = 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		if rmb_down:
			strafe_input -= 1.0
		else:
			turn_input += 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		if rmb_down:
			strafe_input += 1.0
		else:
			turn_input -= 1.0

	if rmb_down:
		rotation.y = cam_yaw
	elif absf(turn_input) > 0.01:
		rotation.y += turn_input * TURN_SPEED * delta
		cam_yaw += turn_input * TURN_SPEED * delta

	var forward_dir: Vector3 = -global_transform.basis.z
	forward_dir.y = 0.0
	forward_dir = forward_dir.normalized()

	var right_dir: Vector3 = global_transform.basis.x
	right_dir.y = 0.0
	right_dir = right_dir.normalized()

	var move_vec: Vector3 = forward_dir * forward_input + right_dir * strafe_input
	if move_vec.length_squared() > 0.001:
		move_vec = move_vec.normalized()
		var speed: float = BACKPEDAL_SPEED if (forward_input < 0.0 and absf(strafe_input) < 0.1) else WALK_SPEED
		velocity.x = move_vec.x * speed
		velocity.z = move_vec.z * speed
		if is_on_floor():
			step_accum += delta
			if step_accum >= 0.38:
				step_accum = 0.0
				AudioManager.play("step", -12.0)
	else:
		step_accum = 0.25
		velocity.x = move_toward(velocity.x, 0.0, 42.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 42.0 * delta)

	move_and_slide()


func _process_charge(delta: float) -> void:
	charge_timeout -= delta
	if charge_timeout <= 0.0 or not is_instance_valid(charge_target) or charge_target.is_dead():
		is_charging = false
		charge_target = null
		return

	var to_target: Vector3 = charge_target.global_position - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()
	if dist <= 2.6:
		is_charging = false
		velocity.x = 0.0
		velocity.z = 0.0
		charge_target.apply_stun(2.0)
		_spawn_ring_fx(charge_target.global_position + Vector3(0, 0.15, 0), Color(1.0, 0.65, 0.2), 0.4, 2.3, 0.35)
		swing_timer = minf(swing_timer, 0.2)
		charge_target = null
		return

	var dir: Vector3 = to_target.normalized()
	rotation.y = atan2(-dir.x, -dir.z)
	cam_yaw = lerp_angle(cam_yaw, rotation.y, minf(1.0, delta * 8.0))
	velocity.x = dir.x * 23.0
	velocity.z = dir.z * 23.0
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()


func _process_auto_attack() -> void:
	if not auto_attack_enabled:
		return
	if casting_slot != 0:
		return
	var target: Node3D = GameState.current_target
	if not is_instance_valid(target) or not (target is MobEntity):
		auto_attack_enabled = false
		return
	var mob := target as MobEntity
	if mob.is_dead():
		auto_attack_enabled = false
		return

	var is_mage: bool = GameState.player_class == "mage"
	var is_rogue: bool = GameState.player_class == "rogue"
	var is_hunter: bool = GameState.player_class == "hunter"
	var dist: float = global_position.distance_to(mob.global_position)
	var reach: float = WAND_RANGE if is_mage else (BOW_RANGE if is_hunter else MELEE_RANGE)
	var interval: float = WAND_INTERVAL if is_mage else (BOW_INTERVAL if is_hunter else (DAGGER_INTERVAL if is_rogue else SWING_INTERVAL))
	if dist <= reach and swing_timer <= 0.0:
		swing_timer = interval
		attack_anim_timer = 0.52
		_face_target(mob.global_position)
		if GameState.is_stealthed:
			GameState.is_stealthed = false
			GameState.player_stats_changed.emit()
		if is_mage:
			var info: Dictionary = GameState.get_attack_damage(0.7, 0)
			_fire_projectile(mob, Color(0.7, 0.55, 1.0), info, "Автоатака", 0.0, 0.22)
		elif is_hunter:
			AudioManager.play("bow_shot")
			var hinfo: Dictionary = GameState.get_attack_damage(1.0, 0)
			_fire_arrow(mob, Color(0.92, 0.86, 0.52), hinfo, "Выстрел из лука", 0.0, 0)
		else:
			var dmg_info: Dictionary = GameState.get_attack_damage(0.82 if is_rogue else 1.0, 0)
			mob.take_damage(int(dmg_info["damage"]), self, "Автоатака", bool(dmg_info["is_crit"]))
			GameState.add_rage(15)
		GameState.touch_combat()


func get_cast_progress() -> float:
	if casting_slot == 0 or cast_total <= 0.0:
		return 0.0
	return clampf(1.0 - cast_timer / cast_total, 0.0, 1.0)


func get_cast_title() -> String:
	if casting_slot == 2:
		return "Огненный шар"
	if casting_slot == 3:
		return "Ледяная стрела"
	if casting_slot == 90:
		return "Сбор: %s" % (gather_target_prop.prop_title if is_instance_valid(gather_target_prop) else "ресурс")
	if casting_slot == 91:
		return "Камень возвращения"
	return "Чтение"


func start_gather_cast(prop: InteractableProp) -> void:
	if GameState.is_dead or prop == null or not prop.is_available:
		return
	if casting_slot != 0:
		return
	auto_attack_enabled = false
	_face_target(prop.global_position)
	gather_target_prop = prop
	casting_slot = 90
	cast_total = 1.4
	cast_timer = 1.4
	cast_target = null
	AudioManager.play("gather")
	GameState.add_combat_log("Вы начинаете добычу: %s..." % prop.prop_title, GameState.COLOR_LOG_SYSTEM)


func start_hearthstone_cast() -> void:
	if GameState.is_dead or GameState.in_combat:
		return
	if casting_slot != 0:
		return
	auto_attack_enabled = false
	casting_slot = 91
	cast_total = 3.2
	cast_timer = 3.2
	cast_target = null
	gather_target_prop = null
	_spawn_ring_fx(global_position + Vector3(0, 0.25, 0), Color(0.35, 0.78, 1.0), 0.4, 2.2, 1.4)
	GameState.add_combat_log("Вы активируете Камень возвращения...", Color(0.45, 0.85, 1.0))


func _begin_cast(slot: int, duration: float, mob: MobEntity) -> void:
	casting_slot = slot
	cast_total = duration
	cast_timer = duration
	cast_target = mob
	_face_target(mob.global_position)


func _cancel_cast(reason: String = "") -> void:
	if casting_slot == 0:
		return
	casting_slot = 0
	cast_target = null
	gather_target_prop = null
	if reason != "":
		GameState.add_combat_log(reason, GameState.COLOR_LOG_ERROR)


func _process_cast(delta: float) -> void:
	if casting_slot == 0:
		return
	if Vector2(velocity.x, velocity.z).length() > 0.8 or not is_on_floor():
		_cancel_cast("Действие прервано движением.")
		return
	if casting_slot == 90:
		if not is_instance_valid(gather_target_prop) or not gather_target_prop.is_available:
			_cancel_cast("Ресурс больше недоступен.")
			return
		cast_timer -= delta
		if cast_timer <= 0.0:
			var gp: InteractableProp = gather_target_prop
			casting_slot = 0
			gather_target_prop = null
			attack_anim_timer = 0.45
			gp.complete_gather()
		return
	if casting_slot == 91:
		if GameState.in_combat:
			_cancel_cast("Камень возвращения сбит вступлением в бой!")
			return
		cast_timer -= delta
		if cast_timer <= 0.0:
			casting_slot = 0
			GameState.ability_cooldowns["hearthstone"] = GameState.ability_max_cooldowns["hearthstone"]
			AudioManager.play("hearthstone")
			_spawn_ring_fx(global_position + Vector3(0, 0.3, 0), Color(0.4, 0.85, 1.0), 0.5, 2.5, 0.5)
			global_position = spawn_position
			velocity = Vector3.ZERO
			_spawn_ring_fx(global_position + Vector3(0, 0.3, 0), Color(0.4, 0.85, 1.0), 2.5, 0.5, 0.6)
			GameState.add_combat_log("Камень возвращения перенёс вас на Заставу Северноземья.", Color(0.45, 0.85, 1.0))
		return

	if not is_instance_valid(cast_target) or cast_target.is_dead():
		_cancel_cast("Цель потеряна, заклинание прервано.")
		return
	_face_target(cast_target.global_position)
	cast_timer -= delta
	if cast_timer <= 0.0:
		var slot: int = casting_slot
		var mob: MobEntity = cast_target
		casting_slot = 0
		cast_target = null
		_finish_cast(slot, mob)


func _finish_cast(slot: int, mob: MobEntity) -> void:
	attack_anim_timer = 0.5
	if slot == 2:
		AudioManager.play("cast_fire")
		var info: Dictionary = GameState.get_attack_damage(2.4, 10)
		_fire_projectile(mob, Color(1.0, 0.45, 0.12), info, "Огненный шар", 0.0, 0.32)
	elif slot == 3:
		AudioManager.play("cast_frost")
		var info2: Dictionary = GameState.get_attack_damage(1.5, 5)
		_fire_projectile(mob, Color(0.45, 0.8, 1.0), info2, "Ледяная стрела", 4.0, 0.26)
	GameState.touch_combat()


func _fire_projectile(mob: MobEntity, color: Color, info: Dictionary, ability_name: String, slow_secs: float, radius: float) -> void:
	var proj := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	proj.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	proj.material_override = mat
	get_parent().add_child(proj)
	var start: Vector3 = global_position + Vector3(0, 1.7, 0)
	proj.global_position = start
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 5.0
	proj.add_child(light)

	var end: Vector3 = mob.global_position + Vector3(0, 1.0, 0)
	var travel: float = maxf(0.12, start.distance_to(end) / 26.0)
	var tw := proj.create_tween()
	tw.tween_property(proj, "global_position", end, travel)
	var dmg: int = int(info["damage"])
	var crit: bool = bool(info["is_crit"])
	tw.tween_callback(func() -> void:
		if is_instance_valid(mob) and not mob.is_dead():
			mob.take_damage(dmg, self, ability_name, crit)
			if slow_secs > 0.0:
				mob.apply_slow(slow_secs)
		proj.queue_free()
	)


func _trigger_mage_ability(slot: int) -> void:
	if casting_slot != 0 and slot != 4 and slot != 5:
		GameState.add_combat_log("Вы уже читаете заклинание.", GameState.COLOR_LOG_ERROR)
		return
	match slot:
		1:
			if auto_attack_enabled:
				auto_attack_enabled = false
				GameState.add_combat_log("Стрельба из посоха остановлена.", GameState.COLOR_LOG_SYSTEM)
			else:
				var mob: MobEntity = _get_target_mob()
				if mob == null:
					mob = _find_nearest_living_mob(WAND_RANGE)
					if mob != null:
						GameState.set_target(mob)
				if mob == null or mob.is_dead():
					GameState.add_combat_log("Нет подходящей цели для атаки.", GameState.COLOR_LOG_ERROR)
					return
				auto_attack_enabled = true
				GameState.add_combat_log("Маг атакует цель: %s." % mob.mob_title, GameState.COLOR_LOG_SYSTEM)
		2, 3:
			var cd_key: String = "fireball" if slot == 2 else "frostbolt"
			var cost: int = 30 if slot == 2 else 20
			var cast_time: float = 1.6 if slot == 2 else 1.2
			var title: String = "Огненный шар" if slot == 2 else "Ледяная стрела"
			if GameState.ability_cooldowns[cd_key] > 0.0:
				GameState.add_combat_log("«%s» ещё перезаряжается." % title, GameState.COLOR_LOG_ERROR)
				return
			var target: MobEntity = _get_target_mob()
			if target == null or target.is_dead():
				GameState.add_combat_log("Выберите живого врага!", GameState.COLOR_LOG_ERROR)
				return
			if global_position.distance_to(target.global_position) > SPELL_RANGE:
				GameState.add_combat_log("Цель слишком далеко (макс. %d м)." % int(SPELL_RANGE), GameState.COLOR_LOG_ERROR)
				return
			if Vector2(velocity.x, velocity.z).length() > 0.8:
				GameState.add_combat_log("Остановитесь, чтобы читать заклинание.", GameState.COLOR_LOG_ERROR)
				return
			if not GameState.spend_rage(cost):
				GameState.add_combat_log("Недостаточно маны (нужно %d)." % cost, GameState.COLOR_LOG_ERROR)
				return
			GameState.ability_cooldowns[cd_key] = cast_time + 0.35
			_begin_cast(slot, cast_time, target)
			GameState.touch_combat()
		4:
			if GameState.ability_cooldowns["frost_nova"] > 0.0:
				GameState.add_combat_log("«Кольцо льда» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			if not GameState.spend_rage(35):
				GameState.add_combat_log("Недостаточно маны (нужно 35).", GameState.COLOR_LOG_ERROR)
				return
			_cancel_cast()
			GameState.ability_cooldowns["frost_nova"] = GameState.ability_max_cooldowns["frost_nova"]
			attack_anim_timer = 0.5
			AudioManager.play("cast_frost")
			GameState.touch_combat()
			_spawn_ring_fx(global_position + Vector3(0, 0.3, 0), Color(0.55, 0.85, 1.0), 0.8, 6.4, 0.5)
			var hits: int = 0
			for node in get_tree().get_nodes_in_group("mobs"):
				var mob := node as MobEntity
				if mob != null and not mob.is_dead() and global_position.distance_to(mob.global_position) <= 6.2:
					var d: Dictionary = GameState.get_attack_damage(0.9, 4)
					mob.take_damage(int(d["damage"]), self, "Кольцо льда", bool(d["is_crit"]))
					if not mob.is_dead():
						mob.apply_stun(2.5)
					hits += 1
			if hits == 0:
				GameState.add_combat_log("«Кольцо льда» никого не задело.", GameState.COLOR_LOG_SYSTEM)
		5:
			if GameState.ability_cooldowns["blink"] > 0.0:
				GameState.add_combat_log("«Скачок» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			if not GameState.spend_rage(15):
				GameState.add_combat_log("Недостаточно маны (нужно 15).", GameState.COLOR_LOG_ERROR)
				return
			_cancel_cast()
			GameState.ability_cooldowns["blink"] = GameState.ability_max_cooldowns["blink"]
			AudioManager.play("stealth")
			var fwd: Vector3 = -global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var origin: Vector3 = global_position + Vector3(0, 1.0, 0)
			var q := PhysicsRayQueryParameters3D.create(origin, origin + fwd * 11.0)
			q.collision_mask = 1
			q.exclude = [get_rid()]
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
			var dist: float = 11.0
			if not hit.is_empty():
				dist = maxf(0.0, origin.distance_to(hit["position"]) - 1.0)
			_spawn_ring_fx(global_position + Vector3(0, 0.3, 0), Color(0.7, 0.5, 1.0), 0.5, 1.8, 0.35)
			global_position += fwd * dist
			velocity = Vector3.ZERO
			_spawn_ring_fx(global_position + Vector3(0, 0.3, 0), Color(0.7, 0.5, 1.0), 1.8, 0.5, 0.35)
			GameState.add_combat_log("Вы совершаете «Скачок» вперёд.", GameState.COLOR_LOG_SPELL)


func _trigger_rogue_ability(slot: int) -> void:
	match slot:
		1:
			if auto_attack_enabled:
				auto_attack_enabled = false
				GameState.add_combat_log("Автоатака остановлена.", GameState.COLOR_LOG_SYSTEM)
			else:
				var mob: MobEntity = _get_target_mob()
				if mob == null:
					mob = _find_nearest_living_mob(10.0)
					if mob != null:
						GameState.set_target(mob)
				if mob == null or mob.is_dead():
					GameState.add_combat_log("Нет подходящей цели для атаки.", GameState.COLOR_LOG_ERROR)
					return
				auto_attack_enabled = true
				GameState.add_combat_log("Разбойник атакует цель: %s." % mob.mob_title, GameState.COLOR_LOG_SYSTEM)
		2:
			if GameState.ability_cooldowns["sinister_strike"] > 0.0:
				GameState.add_combat_log("Умение ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			var mob: MobEntity = _get_target_mob()
			if mob == null or mob.is_dead():
				GameState.add_combat_log("Выберите живого врага!", GameState.COLOR_LOG_ERROR)
				return
			if global_position.distance_to(mob.global_position) > MELEE_RANGE + 0.4:
				GameState.add_combat_log("Подойдите ближе к цели!", GameState.COLOR_LOG_ERROR)
				return
			var cost: int = 40 if GameState.is_stealthed else 35
			if not GameState.spend_rage(cost):
				GameState.add_combat_log("Недостаточно энергии (нужно %d)." % cost, GameState.COLOR_LOG_ERROR)
				return

			GameState.ability_cooldowns["sinister_strike"] = GameState.ability_max_cooldowns["sinister_strike"]
			attack_anim_timer = 0.50
			auto_attack_enabled = true
			_face_target(mob.global_position)

			if GameState.is_stealthed:
				GameState.is_stealthed = false
				GameState.player_stats_changed.emit()
				var dmg_info: Dictionary = GameState.get_attack_damage(2.25, 10)
				mob.take_damage(int(dmg_info["damage"]), self, "Внезапный удар", bool(dmg_info["is_crit"]))
				GameState.add_combo_points(2, mob)
				_spawn_ring_fx(mob.global_position + Vector3(0, 0.3, 0), Color(0.9, 0.25, 0.25), 0.2, 1.8, 0.3)
			else:
				var dmg_info: Dictionary = GameState.get_attack_damage(1.35, 5)
				mob.take_damage(int(dmg_info["damage"]), self, "Коварный удар", bool(dmg_info["is_crit"]))
				GameState.add_combo_points(1, mob)
			GameState.touch_combat()
		3:
			if GameState.ability_cooldowns["eviscerate"] > 0.0:
				GameState.add_combat_log("«Потрошение» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			var mob: MobEntity = _get_target_mob()
			if mob == null or mob.is_dead():
				GameState.add_combat_log("Выберите живого врага!", GameState.COLOR_LOG_ERROR)
				return
			if global_position.distance_to(mob.global_position) > MELEE_RANGE + 0.4:
				GameState.add_combat_log("Подойдите ближе к цели!", GameState.COLOR_LOG_ERROR)
				return
			if GameState.combo_target != mob or GameState.combo_points <= 0:
				GameState.add_combat_log("Нужно хотя бы 1 очко серии (используйте Коварный удар).", GameState.COLOR_LOG_ERROR)
				return
			if not GameState.spend_rage(30):
				GameState.add_combat_log("Недостаточно энергии (нужно 30).", GameState.COLOR_LOG_ERROR)
				return

			GameState.ability_cooldowns["eviscerate"] = GameState.ability_max_cooldowns["eviscerate"]
			var pts: int = GameState.consume_combo_points(mob)
			GameState.is_stealthed = false
			attack_anim_timer = 0.55
			auto_attack_enabled = true
			_face_target(mob.global_position)
			var dmg_info: Dictionary = GameState.get_attack_damage(0.95 + 0.46 * float(pts), 4 * pts)
			mob.take_damage(int(dmg_info["damage"]), self, "Потрошение (%d★)" % pts, bool(dmg_info["is_crit"]))
			_spawn_ring_fx(mob.global_position + Vector3(0, 0.25, 0), Color(1.0, 0.78, 0.22), 0.2, 1.9, 0.3)
			GameState.touch_combat()
		4:
			if GameState.is_stealthed:
				GameState.is_stealthed = false
				GameState.player_stats_changed.emit()
				GameState.add_combat_log("Вы вышли из незаметности.", GameState.COLOR_LOG_SYSTEM)
				return
			if GameState.in_combat:
				GameState.add_combat_log("Нельзя уйти в незаметность в бою!", GameState.COLOR_LOG_ERROR)
				return
			if GameState.ability_cooldowns["stealth"] > 0.0:
				GameState.add_combat_log("«Незаметность» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			GameState.ability_cooldowns["stealth"] = GameState.ability_max_cooldowns["stealth"]
			GameState.is_stealthed = true
			auto_attack_enabled = false
			AudioManager.play("stealth")
			GameState.player_stats_changed.emit()
			GameState.add_combat_log("Вы растворяетесь в тенях (уменьшен радиус аггро, [2] бьёт Внезапным ударом).", GameState.COLOR_LOG_SPELL)
		5:
			if GameState.ability_cooldowns["kidney_shot"] > 0.0:
				GameState.add_combat_log("«Удар по почкам» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			var mob: MobEntity = _get_target_mob()
			if mob == null or mob.is_dead():
				GameState.add_combat_log("Выберите живого врага!", GameState.COLOR_LOG_ERROR)
				return
			if global_position.distance_to(mob.global_position) > MELEE_RANGE + 0.4:
				GameState.add_combat_log("Подойдите ближе к цели!", GameState.COLOR_LOG_ERROR)
				return
			if GameState.combo_target != mob or GameState.combo_points <= 0:
				GameState.add_combat_log("Нужно хотя бы 1 очко серии (используйте Коварный удар).", GameState.COLOR_LOG_ERROR)
				return
			if not GameState.spend_rage(25):
				GameState.add_combat_log("Недостаточно энергии (нужно 25).", GameState.COLOR_LOG_ERROR)
				return

			GameState.ability_cooldowns["kidney_shot"] = GameState.ability_max_cooldowns["kidney_shot"]
			var pts: int = GameState.consume_combo_points(mob)
			var stun_dur: float = 2.0 + float(pts) * 0.5
			GameState.is_stealthed = false
			attack_anim_timer = 0.5
			_face_target(mob.global_position)
			mob.apply_stun(stun_dur)
			_spawn_ring_fx(mob.global_position + Vector3(0, 0.25, 0), Color(0.9, 0.85, 0.25), 0.2, 1.5, 0.3)
			GameState.add_combat_log("«Удар по почкам» оглушает цель %s на %.1f сек!" % [mob.mob_title, stun_dur], GameState.COLOR_LOG_SPELL)
			GameState.touch_combat()


func _fire_arrow(mob: MobEntity, color: Color, info: Dictionary, ability_name: String, slow_secs: float, dot_dmg: int) -> void:
	var arrow := Node3D.new()
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.025
	cyl.height = 0.65
	cyl.radial_segments = 5
	shaft.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	shaft.material_override = mat
	shaft.rotation_degrees = Vector3(90, 0, 0)
	arrow.add_child(shaft)
	get_parent().add_child(arrow)

	var start: Vector3 = global_position + Vector3(0, 1.45, 0)
	var end: Vector3 = mob.global_position + Vector3(0, 1.0, 0)
	arrow.global_position = start
	arrow.look_at(end, Vector3.UP)
	var travel: float = maxf(0.08, start.distance_to(end) / 34.0)
	var dmg: int = int(info["damage"])
	var crit: bool = bool(info["is_crit"])
	var tw := arrow.create_tween()
	tw.tween_property(arrow, "global_position", end, travel)
	tw.tween_callback(func() -> void:
		if is_instance_valid(mob) and not mob.is_dead():
			mob.take_damage(dmg, self, ability_name, crit)
			if slow_secs > 0.0:
				mob.apply_slow(slow_secs)
			if dot_dmg > 0:
				mob.apply_dot(dot_dmg, 8.0, "Укус змеи")
		arrow.queue_free()
	)


func _trigger_hunter_ability(slot: int) -> void:
	match slot:
		1:
			if auto_attack_enabled:
				auto_attack_enabled = false
				GameState.add_combat_log("Автострельба остановлена.", GameState.COLOR_LOG_SYSTEM)
			else:
				var mob: MobEntity = _get_target_mob()
				if mob == null:
					mob = _find_nearest_living_mob(BOW_RANGE)
					if mob != null:
						GameState.set_target(mob)
				if mob == null or mob.is_dead():
					GameState.add_combat_log("Нет подходящей цели для выстрела.", GameState.COLOR_LOG_ERROR)
					return
				auto_attack_enabled = true
				GameState.add_combat_log("Охотник берёт цель на прицел: %s." % mob.mob_title, GameState.COLOR_LOG_SYSTEM)
		2:
			if GameState.ability_cooldowns["arcane_shot"] > 0.0:
				GameState.add_combat_log("«Чародейский выстрел» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			var mob: MobEntity = _get_target_mob()
			if mob == null or mob.is_dead():
				GameState.add_combat_log("Выберите живого врага!", GameState.COLOR_LOG_ERROR)
				return
			if global_position.distance_to(mob.global_position) > BOW_RANGE + 2.0:
				GameState.add_combat_log("Цель слишком далеко (макс. %d м)." % int(BOW_RANGE + 2), GameState.COLOR_LOG_ERROR)
				return
			if not GameState.spend_rage(25):
				GameState.add_combat_log("Недостаточно маны (нужно 25).", GameState.COLOR_LOG_ERROR)
				return
			GameState.ability_cooldowns["arcane_shot"] = GameState.ability_max_cooldowns["arcane_shot"]
			attack_anim_timer = 0.50
			auto_attack_enabled = true
			_face_target(mob.global_position)
			AudioManager.play("bow_shot")
			var info: Dictionary = GameState.get_attack_damage(1.55, 6)
			_fire_arrow(mob, Color(0.55, 0.78, 1.0), info, "Чародейский выстрел", 0.0, 0)
			GameState.touch_combat()
		3:
			if GameState.ability_cooldowns["serpent_sting"] > 0.0:
				GameState.add_combat_log("«Укус змеи» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			var mob: MobEntity = _get_target_mob()
			if mob == null or mob.is_dead():
				GameState.add_combat_log("Выберите живого врага!", GameState.COLOR_LOG_ERROR)
				return
			if global_position.distance_to(mob.global_position) > BOW_RANGE + 2.0:
				GameState.add_combat_log("Цель слишком далеко!", GameState.COLOR_LOG_ERROR)
				return
			if not GameState.spend_rage(25):
				GameState.add_combat_log("Недостаточно маны (нужно 25).", GameState.COLOR_LOG_ERROR)
				return
			GameState.ability_cooldowns["serpent_sting"] = GameState.ability_max_cooldowns["serpent_sting"]
			attack_anim_timer = 0.50
			auto_attack_enabled = true
			_face_target(mob.global_position)
			AudioManager.play("bow_shot")
			var info: Dictionary = GameState.get_attack_damage(0.75, 2)
			var dot_tick: int = maxi(5, int(round(float(info["damage"]) * 0.55 + 3.0)))
			_fire_arrow(mob, Color(0.35, 0.96, 0.35), info, "Укус змеи", 0.0, dot_tick)
			GameState.touch_combat()
		4:
			if GameState.ability_cooldowns["concussive_shot"] > 0.0:
				GameState.add_combat_log("«Шокирующий выстрел» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			var mob: MobEntity = _get_target_mob()
			if mob == null or mob.is_dead():
				GameState.add_combat_log("Выберите живого врага!", GameState.COLOR_LOG_ERROR)
				return
			if global_position.distance_to(mob.global_position) > BOW_RANGE + 2.0:
				GameState.add_combat_log("Цель слишком далеко!", GameState.COLOR_LOG_ERROR)
				return
			if not GameState.spend_rage(15):
				GameState.add_combat_log("Недостаточно маны (нужно 15).", GameState.COLOR_LOG_ERROR)
				return
			GameState.ability_cooldowns["concussive_shot"] = GameState.ability_max_cooldowns["concussive_shot"]
			attack_anim_timer = 0.48
			_face_target(mob.global_position)
			AudioManager.play("bow_shot")
			var info: Dictionary = GameState.get_attack_damage(0.85, 0)
			_fire_arrow(mob, Color(1.0, 0.85, 0.25), info, "Шокирующий выстрел", 4.5, 0)
			if mob.cast_display_name != "":
				mob.apply_stun(0.6)
			GameState.touch_combat()
		5:
			if GameState.ability_cooldowns["mend_pet"] > 0.0:
				GameState.add_combat_log("«Лечение зверя» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			if not GameState.spend_rage(20):
				GameState.add_combat_log("Недостаточно маны (нужно 20).", GameState.COLOR_LOG_ERROR)
				return
			GameState.ability_cooldowns["mend_pet"] = GameState.ability_max_cooldowns["mend_pet"]
			_ensure_hunter_pet()
			if is_instance_valid(GameState.pet_node) and GameState.pet_node.has_method("heal_or_revive"):
				GameState.pet_node.call("heal_or_revive", 0.60)
				_spawn_ring_fx(GameState.pet_node.global_position + Vector3(0, 0.2, 0), Color(0.4, 0.96, 0.45), 0.3, 2.0, 0.45)


func trigger_ability(slot: int) -> void:
	if GameState.is_dead:
		GameState.add_combat_log("Вы мертвы и не можете применять способности.", GameState.COLOR_LOG_ERROR)
		return
	if GameState.player_class == "mage":
		_trigger_mage_ability(slot)
		return
	if GameState.player_class == "rogue":
		_trigger_rogue_ability(slot)
		return
	if GameState.player_class == "hunter":
		_trigger_hunter_ability(slot)
		return

	match slot:
		1:
			# Автоатака
			if auto_attack_enabled:
				auto_attack_enabled = false
				GameState.add_combat_log("Автоатака остановлена.", GameState.COLOR_LOG_SYSTEM)
			else:
				var mob: MobEntity = _get_target_mob()
				if mob == null:
					mob = _find_nearest_living_mob(10.0)
					if mob != null:
						GameState.set_target(mob)
				if mob == null or mob.is_dead():
					GameState.add_combat_log("Нет подходящей цели для атаки.", GameState.COLOR_LOG_ERROR)
					return
				auto_attack_enabled = true
				GameState.add_combat_log("Начата автоатака по цели: %s." % mob.mob_title, GameState.COLOR_LOG_SYSTEM)

		2:
			# Рывок (Charge)
			if GameState.ability_cooldowns["charge"] > 0.0:
				GameState.add_combat_log("Способность «Рывок» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			var mob: MobEntity = _get_target_mob()
			if mob == null or mob.is_dead():
				GameState.add_combat_log("Выберите живого врага для Рывка.", GameState.COLOR_LOG_ERROR)
				return
			var dist: float = global_position.distance_to(mob.global_position)
			if dist < 3.5:
				GameState.add_combat_log("Вы слишком близко к цели для Рывка.", GameState.COLOR_LOG_ERROR)
				return
			if dist > 22.0:
				GameState.add_combat_log("Цель слишком далеко для Рывка (макс. 22 м).", GameState.COLOR_LOG_ERROR)
				return

			GameState.ability_cooldowns["charge"] = GameState.ability_max_cooldowns["charge"]
			GameState.add_rage(20)
			GameState.touch_combat()
			is_charging = true
			charge_target = mob
			charge_timeout = 1.4
			auto_attack_enabled = true
			AudioManager.play("charge")
			_spawn_ring_fx(global_position + Vector3(0, 0.15, 0), Color(0.95, 0.55, 0.2), 0.3, 1.8, 0.35)
			GameState.add_combat_log("Вы совершаете «Рывок» к цели %s (+20 Ярости)!" % mob.mob_title, GameState.COLOR_LOG_SPELL)

		3:
			# Героический удар (Heroic Strike)
			if GameState.ability_cooldowns["heroic_strike"] > 0.0:
				GameState.add_combat_log("Способность «Героический удар» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			var mob: MobEntity = _get_target_mob()
			if mob == null or mob.is_dead():
				GameState.add_combat_log("Выберите живого врага!", GameState.COLOR_LOG_ERROR)
				return
			if global_position.distance_to(mob.global_position) > MELEE_RANGE + 0.4:
				GameState.add_combat_log("Подойдите ближе к цели!", GameState.COLOR_LOG_ERROR)
				return
			if not GameState.spend_rage(15):
				GameState.add_combat_log("Недостаточно ярости (нужно 15).", GameState.COLOR_LOG_ERROR)
				return

			GameState.ability_cooldowns["heroic_strike"] = GameState.ability_max_cooldowns["heroic_strike"]
			attack_anim_timer = 0.55
			auto_attack_enabled = true
			_face_target(mob.global_position)
			var dmg_info: Dictionary = GameState.get_attack_damage(1.45, 7)
			mob.take_damage(int(dmg_info["damage"]), self, "Героический удар", bool(dmg_info["is_crit"]))
			_spawn_ring_fx(mob.global_position + Vector3(0, 0.25, 0), Color(1.0, 0.85, 0.25), 0.2, 1.5, 0.28)
			GameState.touch_combat()

		4:
			# Вихрь (Whirlwind)
			if GameState.ability_cooldowns["whirlwind"] > 0.0:
				GameState.add_combat_log("Способность «Вихрь» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			if not GameState.spend_rage(25):
				GameState.add_combat_log("Недостаточно ярости (нужно 25).", GameState.COLOR_LOG_ERROR)
				return

			GameState.ability_cooldowns["whirlwind"] = GameState.ability_max_cooldowns["whirlwind"]
			whirlwind_anim_timer = 0.65
			GameState.touch_combat()
			_spawn_ring_fx(global_position + Vector3(0, 0.9, 0), Color(0.82, 0.92, 1.0), 1.0, 5.2, 0.45)

			var hit_count: int = 0
			for node in get_tree().get_nodes_in_group("mobs"):
				var mob := node as MobEntity
				if mob != null and not mob.is_dead() and global_position.distance_to(mob.global_position) <= 5.2:
					var dmg_info: Dictionary = GameState.get_attack_damage(1.25, 4)
					mob.take_damage(int(dmg_info["damage"]), self, "Вихрь", bool(dmg_info["is_crit"]))
					hit_count += 1
			if hit_count == 0:
				GameState.add_combat_log("Ваш «Вихрь» никого не задел.", GameState.COLOR_LOG_SYSTEM)

		5:
			# Боевой крик + Второе дыхание
			if GameState.ability_cooldowns["battle_shout"] > 0.0:
				GameState.add_combat_log("Способность «Боевой крик» ещё перезаряжается.", GameState.COLOR_LOG_ERROR)
				return
			GameState.ability_cooldowns["battle_shout"] = GameState.ability_max_cooldowns["battle_shout"]
			GameState.battle_shout_timer = 30.0
			var heal_amt: int = maxi(15, int(round(GameState.max_hp * 0.35)))
			GameState.heal_player(heal_amt, "Боевой крик")
			GameState.add_combat_log("Вы издаёте «Боевой крик»! Урон увеличен на 25% на 30 сек.", GameState.COLOR_LOG_SPELL)
			GameState.floating_text_requested.emit(global_position + Vector3(0, 2.5, 0), "БОЕВОЙ КРИК!", Color(1.0, 0.85, 0.2), true)
			_spawn_ring_fx(global_position + Vector3(0, 0.2, 0), Color(1.0, 0.84, 0.18), 0.5, 4.5, 0.5)


func get_swing_progress() -> float:
	if not auto_attack_enabled:
		return 0.0
	var iv: float = WAND_INTERVAL if GameState.player_class == "mage" else (BOW_INTERVAL if GameState.player_class == "hunter" else (DAGGER_INTERVAL if GameState.player_class == "rogue" else SWING_INTERVAL))
	return clampf(1.0 - (swing_timer / iv), 0.0, 1.0)


func _get_target_mob() -> MobEntity:
	if is_instance_valid(GameState.current_target) and GameState.current_target is MobEntity:
		return GameState.current_target as MobEntity
	return null


func _find_nearest_living_mob(max_dist: float) -> MobEntity:
	var best: MobEntity = null
	var best_d: float = max_dist
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as MobEntity
		if mob != null and not mob.is_dead():
			var d: float = global_position.distance_to(mob.global_position)
			if d < best_d:
				best_d = d
				best = mob
	return best


func _cycle_tab_target() -> void:
	var candidates: Array[Dictionary] = []
	var cam_fwd: Vector3 = -camera.global_transform.basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()

	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as MobEntity
		if mob != null and not mob.is_dead():
			var to_m: Vector3 = mob.global_position - global_position
			to_m.y = 0.0
			var dist: float = to_m.length()
			if dist <= 32.0:
				var dot: float = cam_fwd.dot(to_m.normalized()) if dist > 0.1 else 1.0
				var score: float = dist - (dot * 8.0)
				candidates.append({"mob": mob, "score": score})

	if candidates.is_empty():
		GameState.add_combat_log("Поблизости нет живых противников.", GameState.COLOR_LOG_SYSTEM)
		return

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) < float(b["score"])
	)

	var current_idx: int = -1
	for i in range(candidates.size()):
		if candidates[i]["mob"] == GameState.current_target:
			current_idx = i
			break

	var next_idx: int = (current_idx + 1) % candidates.size()
	GameState.set_target(candidates[next_idx]["mob"] as Node3D)


func _try_click_world(screen_pos: Vector2, is_right_click: bool) -> void:
	if camera == null:
		return
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 75.0)
	query.collision_mask = 2
	query.collide_with_bodies = true
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		if not is_right_click:
			GameState.set_target(null)
			auto_attack_enabled = false
		return

	var collider: Object = result.get("collider")
	if collider is QuestNPC:
		var npc := collider as QuestNPC
		GameState.set_target(npc)
		auto_attack_enabled = false
		if is_right_click:
			if global_position.distance_to(npc.global_position) <= 6.8:
				npc.interact()
			else:
				GameState.add_combat_log("Подойдите ближе к %s, чтобы поговорить." % npc.npc_name, GameState.COLOR_LOG_SYSTEM)
	elif collider is InteractableProp:
		var prop := collider as InteractableProp
		GameState.set_target(prop)
		auto_attack_enabled = false
		if is_right_click:
			if global_position.distance_to(prop.global_position) <= 6.8:
				prop.interact()
			else:
				GameState.add_combat_log("Подойдите ближе к объекту «%s»." % prop.prop_title, GameState.COLOR_LOG_SYSTEM)
	elif collider is MobEntity:
		var mob := collider as MobEntity
		GameState.set_target(mob)
		if is_right_click:
			if mob.is_dead():
				auto_attack_enabled = false
				if mob.has_loot():
					if global_position.distance_to(mob.global_position) <= 6.8:
						GameState.loot_window_requested.emit(mob)
					else:
						GameState.add_combat_log("Подойдите ближе к телу, чтобы осмотреть добычу.", GameState.COLOR_LOG_SYSTEM)
				else:
					GameState.add_combat_log("В этом теле больше нет добычи.", GameState.COLOR_LOG_SYSTEM)
			else:
				if not GameState.is_dead:
					auto_attack_enabled = true


func _interact_nearest_or_target() -> void:
	if GameState.is_dead:
		return
	var t: Node3D = GameState.current_target
	if is_instance_valid(t):
		if t is QuestNPC and global_position.distance_to(t.global_position) <= 7.0:
			(t as QuestNPC).interact()
			return
		if t is InteractableProp and global_position.distance_to(t.global_position) <= 7.0:
			(t as InteractableProp).interact()
			return
		if t is MobEntity and (t as MobEntity).is_dead() and (t as MobEntity).has_loot() and global_position.distance_to(t.global_position) <= 7.0:
			GameState.loot_window_requested.emit(t)
			return

	for node in get_tree().get_nodes_in_group("npcs"):
		var npc := node as QuestNPC
		if npc != null and global_position.distance_to(npc.global_position) <= 6.8:
			GameState.set_target(npc)
			npc.interact()
			return

	for node in get_tree().get_nodes_in_group("interactables"):
		var prop := node as InteractableProp
		if prop != null and prop.is_available and global_position.distance_to(prop.global_position) <= 6.8:
			GameState.set_target(prop)
			prop.interact()
			return

	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as MobEntity
		if mob != null and mob.is_dead() and mob.has_loot() and global_position.distance_to(mob.global_position) <= 6.8:
			GameState.set_target(mob)
			GameState.loot_window_requested.emit(mob)
			return


func _face_target(target_pos: Vector3) -> void:
	var to_t: Vector3 = target_pos - global_position
	to_t.y = 0.0
	if to_t.length_squared() > 0.001 and not rmb_down:
		rotation.y = atan2(-to_t.x, -to_t.z)


func _update_camera_and_ring(_delta: float) -> void:
	if camera_pivot:
		camera_pivot.global_position = global_position + Vector3(0, 1.55, 0)
		camera_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0.0)

	if target_ring:
		var t: Node3D = GameState.current_target
		if is_instance_valid(t):
			target_ring.visible = true
			target_ring.global_position = Vector3(t.global_position.x, t.global_position.y + 0.08, t.global_position.z)
			var mat := target_ring.material_override as StandardMaterial3D
			var ring_scale: float = 1.0
			if t is QuestNPC or t is PetCompanion:
				if mat:
					mat.albedo_color = Color(0.25, 0.92, 0.35, 0.85)
					mat.emission = Color(0.25, 0.92, 0.35)
				ring_scale = 1.0
			elif t is InteractableProp:
				if mat:
					mat.albedo_color = Color(1.0, 0.85, 0.25, 0.85)
					mat.emission = Color(1.0, 0.85, 0.25)
				ring_scale = 1.0
			elif t is MobEntity:
				var mob := t as MobEntity
				ring_scale = 1.45 if mob.mob_id == "boss_crusher" else (1.15 if mob.mob_id == "wolf" else 0.95)
				if mat:
					if mob.is_dead():
						mat.albedo_color = Color(1.0, 0.84, 0.22, 0.85)
						mat.emission = Color(1.0, 0.84, 0.22)
					else:
						mat.albedo_color = Color(0.95, 0.22, 0.18, 0.85)
						mat.emission = Color(0.95, 0.22, 0.18)
			target_ring.scale = Vector3(ring_scale, 0.15, ring_scale)
		else:
			target_ring.visible = false


func _update_animation(delta: float) -> void:
	if rig_node == null:
		return
	var anim_state: String = "IDLE"
	var atk_prog: float = 0.0
	var spin: float = 0.0

	if GameState.is_dead and not GameState.is_ghost:
		anim_state = "DEAD"
	elif whirlwind_anim_timer > 0.0:
		anim_state = "WHIRLWIND"
		var p: float = 1.0 - (whirlwind_anim_timer / 0.65)
		spin = p * TAU * 2.0
	elif is_charging:
		anim_state = "CHARGE"
	elif casting_slot != 0:
		anim_state = "CAST"
	elif not is_on_floor():
		anim_state = "JUMP"
	elif Vector2(velocity.x, velocity.z).length() > 0.35:
		anim_state = "WALK"

	if attack_anim_timer > 0.0:
		atk_prog = 1.0 - (attack_anim_timer / 0.55)

	RetroModelBuilder.animate_humanoid(rig_node, anim_state, anim_time, atk_prog, spin, 0.0, delta, {
		"dual_wield": GameState.player_class == "rogue",
		"bow_aim": GameState.player_class == "hunter",
	})


func _on_target_changed(new_target: Node3D) -> void:
	if new_target == null:
		auto_attack_enabled = false


func _on_player_died() -> void:
	auto_attack_enabled = false
	is_charging = false
	charge_target = null
	casting_slot = 0
	cast_target = null
	gather_target_prop = null
	_spawn_corpse()
	if rig_node:
		rig_node.visible = false


func _spawn_corpse() -> void:
	if is_instance_valid(corpse_node):
		corpse_node.queue_free()
	corpse_node = RetroModelBuilder.build_humanoid(_visual_config())
	get_parent().add_child(corpse_node)
	corpse_node.global_position = global_position
	corpse_node.rotation.y = rotation.y
	RetroModelBuilder.animate_humanoid(corpse_node, "DEAD", 0.0)

	var beacon := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.28
	cyl.height = 5.0
	cyl.radial_segments = 8
	beacon.mesh = cyl
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.45, 0.82, 1.0, 0.45)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.emission_enabled = true
	bmat.emission = Color(0.45, 0.82, 1.0)
	bmat.emission_energy_multiplier = 2.0
	beacon.material_override = bmat
	beacon.position = Vector3(0, 2.5, 0)
	corpse_node.add_child(beacon)


func _refresh_transparency() -> void:
	if rig_node == null:
		return
	if GameState.is_dead and not GameState.is_ghost:
		rig_node.visible = false
		return
	rig_node.visible = true
	var alpha: float = 0.60 if GameState.is_ghost else (0.55 if GameState.is_stealthed else 0.0)
	for child in _collect_meshes(rig_node):
		child.transparency = alpha


func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for c in node.get_children():
		result.append_array(_collect_meshes(c))
	return result


func _on_spirit_released() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	_refresh_transparency()


func _on_player_resurrected(at_corpse: bool) -> void:
	if at_corpse:
		global_position = GameState.corpse_position
	else:
		global_position = spawn_position
	velocity = Vector3.ZERO
	if is_instance_valid(corpse_node):
		corpse_node.queue_free()
		corpse_node = null
	_refresh_transparency()
	_spawn_level_up_pillar()


func _on_level_up() -> void:
	_spawn_level_up_pillar()
	if is_instance_valid(GameState.pet_node) and GameState.pet_node.has_method("sync_stats"):
		GameState.pet_node.call("sync_stats", true)


func _spawn_ring_fx(pos: Vector3, color: Color, start_rad: float, end_rad: float, duration: float) -> void:
	var fx := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.78
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	fx.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.6
	fx.material_override = mat

	get_parent().add_child(fx)
	fx.global_position = pos
	fx.scale = Vector3(start_rad, 0.12, start_rad)

	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector3(end_rad, 0.08, end_rad), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(fx.queue_free)


func _spawn_level_up_pillar() -> void:
	var fx := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.25
	cyl.bottom_radius = 0.85
	cyl.height = 7.0
	cyl.radial_segments = 16
	fx.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.90, 0.30, 0.58)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.86, 0.25)
	mat.emission_energy_multiplier = 2.5
	fx.material_override = mat

	get_parent().add_child(fx)
	fx.global_position = global_position + Vector3(0, 3.5, 0)

	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector3(1.6, 1.25, 1.6), 1.1)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.1)
	tw.chain().tween_callback(fx.queue_free)
