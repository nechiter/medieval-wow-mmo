class_name MobEntity
extends CharacterBody3D

enum State {
	IDLE,
	CHASE,
	ATTACK,
	STUNNED,
	EVADE_RETURN,
	DEAD,
}

@export var mob_id: String = "wolf"
@export var mob_title: String = "Лесной волк"
@export var level: int = 1
@export var is_elite: bool = false
@export var max_hp: int = 75
@export var damage_min: int = 5
@export var damage_max: int = 9
@export var aggro_radius: float = 9.0
@export var attack_range: float = 2.6
@export var attack_interval: float = 2.0
@export var move_speed: float = 4.3
@export var xp_reward: int = 35

var hp: int = 75
var state: State = State.IDLE
var spawn_position: Vector3 = Vector3.ZERO
var wander_target: Vector3 = Vector3.ZERO
var wander_wait_timer: float = 1.5

var stun_timer: float = 0.0
var attack_cooldown: float = 0.0
var attack_anim_timer: float = 0.0
var respawn_timer: float = 0.0
var anim_time: float = 0.0
var has_shouted_aggro: bool = false

var rig_node: Node3D = null
var nameplate: Label3D = null
var loot_indicator: MeshInstance3D = null
var stun_indicator: Label3D = null
var collision_shape: CollisionShape3D = null

var loot_copper: int = 0
var loot_items: Array[Dictionary] = []

const GRAVITY := 24.0
const LEASH_DISTANCE := 28.0
const RESPAWN_DELAY := 18.0


func _ready() -> void:
	add_to_group("mobs")
	collision_layer = 2
	collision_mask = 1
	spawn_position = global_position
	wander_target = spawn_position
	hp = max_hp
	anim_time = randf() * 10.0

	_build_collision()
	_build_visuals()
	_build_indicators()
	_update_nameplate()


func configure(cfg: Dictionary) -> void:
	mob_id = String(cfg.get("mob_id", mob_id))
	mob_title = String(cfg.get("mob_title", mob_title))
	level = int(cfg.get("level", level))
	is_elite = bool(cfg.get("is_elite", is_elite))
	max_hp = int(cfg.get("max_hp", max_hp))
	hp = max_hp
	damage_min = int(cfg.get("damage_min", damage_min))
	damage_max = int(cfg.get("damage_max", damage_max))
	aggro_radius = float(cfg.get("aggro_radius", aggro_radius))
	attack_range = float(cfg.get("attack_range", attack_range))
	attack_interval = float(cfg.get("attack_interval", attack_interval))
	move_speed = float(cfg.get("move_speed", move_speed))
	xp_reward = int(cfg.get("xp_reward", xp_reward))


func _build_collision() -> void:
	collision_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	if mob_id == "wolf":
		cap.radius = 0.65
		cap.height = 1.4
		collision_shape.position = Vector3(0, 0.72, 0)
	elif mob_id == "boss_crusher":
		cap.radius = 0.82
		cap.height = 2.5
		collision_shape.position = Vector3(0, 1.25, 0)
	else:
		cap.radius = 0.55
		cap.height = 1.75
		collision_shape.position = Vector3(0, 0.88, 0)
	collision_shape.shape = cap
	add_child(collision_shape)


func _build_visuals() -> void:
	if mob_id == "wolf":
		rig_node = RetroModelBuilder.build_wolf({
			"scale": 1.08,
			"fur_color": Color(0.38, 0.35, 0.34),
			"belly_color": Color(0.58, 0.53, 0.48),
			"eye_color": Color(1.0, 0.45, 0.15),
		})
	elif mob_id == "boss_crusher":
		rig_node = RetroModelBuilder.build_humanoid({
			"scale": 1.42,
			"archetype": "kobold",
			"armor_color": Color(0.45, 0.18, 0.14),
			"accent_color": Color(0.84, 0.66, 0.22),
			"skin_color": Color(0.54, 0.42, 0.34),
			"pants_color": Color(0.22, 0.16, 0.14),
			"cape_color": Color(0.48, 0.08, 0.08),
			"eye_color": Color(1.0, 0.25, 0.15),
			"weapon_type": "greataxe",
			"has_cape": true,
			"has_candle": true,
		})
	else:
		# Кобольд-шахтёр
		rig_node = RetroModelBuilder.build_humanoid({
			"scale": 0.86,
			"archetype": "kobold",
			"armor_color": Color(0.36, 0.29, 0.22),
			"accent_color": Color(0.55, 0.42, 0.24),
			"skin_color": Color(0.60, 0.49, 0.39),
			"pants_color": Color(0.24, 0.19, 0.15),
			"cape_color": Color(0.30, 0.22, 0.16),
			"eye_color": Color(1.0, 0.78, 0.20),
			"weapon_type": "pickaxe",
			"has_cape": false,
			"has_candle": true,
		})
	add_child(rig_node)


func _build_indicators() -> void:
	nameplate = Label3D.new()
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.no_depth_test = false
	nameplate.pixel_size = 0.009
	nameplate.font_size = 34
	nameplate.outline_size = 8
	nameplate.outline_modulate = Color(0.05, 0.05, 0.05, 0.95)
	nameplate.position = Vector3(0, 2.75 if mob_id == "boss_crusher" else (1.55 if mob_id == "wolf" else 2.0), 0)
	add_child(nameplate)

	stun_indicator = Label3D.new()
	stun_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stun_indicator.pixel_size = 0.008
	stun_indicator.font_size = 30
	stun_indicator.modulate = Color(1.0, 0.92, 0.25)
	stun_indicator.outline_size = 7
	stun_indicator.text = "* ОГЛУШЁН *"
	stun_indicator.visible = false
	stun_indicator.position = nameplate.position + Vector3(0, 0.35, 0)
	add_child(stun_indicator)

	# Золотое сияние добычи над трупом (как в WoW)
	loot_indicator = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.22
	cyl.height = 0.95
	cyl.radial_segments = 6
	loot_indicator.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.25, 0.72)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.15)
	mat.emission_energy_multiplier = 2.4
	loot_indicator.material_override = mat
	loot_indicator.position = Vector3(0, 0.65, 0)
	loot_indicator.visible = false
	add_child(loot_indicator)


func _physics_process(delta: float) -> void:
	anim_time += delta
	if attack_cooldown > 0.0:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if attack_anim_timer > 0.0:
		attack_anim_timer = maxf(0.0, attack_anim_timer - delta)

	if state == State.DEAD:
		respawn_timer -= delta
		if loot_indicator and loot_indicator.visible:
			loot_indicator.rotation.y += delta * 2.4
			loot_indicator.position.y = 0.65 + sin(anim_time * 4.0) * 0.12
		if respawn_timer <= 0.0:
			_respawn()
		_update_animation()
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var player: Node3D = GameState.player_node
	var player_alive: bool = is_instance_valid(player) and not GameState.is_dead

	match state:
		State.STUNNED:
			velocity.x = 0.0
			velocity.z = 0.0
			stun_timer -= delta
			if stun_indicator:
				stun_indicator.visible = true
			if stun_timer <= 0.0:
				if stun_indicator:
					stun_indicator.visible = false
				state = State.CHASE if player_alive else State.EVADE_RETURN

		State.IDLE:
			_process_idle(delta, player, player_alive)

		State.CHASE:
			_process_chase(delta, player, player_alive)

		State.ATTACK:
			_process_attack(delta, player, player_alive)

		State.EVADE_RETURN:
			_process_evade_return(delta)

	move_and_slide()
	_update_animation()


func _process_idle(delta: float, player: Node3D, player_alive: bool) -> void:
	if player_alive:
		var dist_to_player: float = global_position.distance_to(player.global_position)
		if dist_to_player <= aggro_radius:
			_enter_aggro()
			return

	var to_wander: Vector3 = wander_target - global_position
	to_wander.y = 0.0
	if to_wander.length() > 0.35:
		var dir: Vector3 = to_wander.normalized()
		velocity.x = dir.x * (move_speed * 0.45)
		velocity.z = dir.z * (move_speed * 0.45)
		_face_direction(dir, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		wander_wait_timer -= delta
		if wander_wait_timer <= 0.0:
			wander_wait_timer = randf_range(2.2, 5.0)
			var angle: float = randf() * TAU
			var rad: float = randf_range(1.2, 4.0)
			wander_target = spawn_position + Vector3(cos(angle) * rad, 0.0, sin(angle) * rad)


func _process_chase(delta: float, player: Node3D, player_alive: bool) -> void:
	if not player_alive:
		state = State.EVADE_RETURN
		return
	if global_position.distance_to(spawn_position) > LEASH_DISTANCE:
		_trigger_evade()
		return

	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	if dist <= attack_range * 0.92:
		velocity.x = 0.0
		velocity.z = 0.0
		state = State.ATTACK
		return

	var dir: Vector3 = to_player.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	_face_direction(dir, delta)


func _process_attack(delta: float, player: Node3D, player_alive: bool) -> void:
	if not player_alive:
		state = State.EVADE_RETURN
		return
	if global_position.distance_to(spawn_position) > LEASH_DISTANCE:
		_trigger_evade()
		return

	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	if dist > attack_range * 1.15:
		state = State.CHASE
		return

	velocity.x = 0.0
	velocity.z = 0.0
	if dist > 0.05:
		_face_direction(to_player.normalized(), delta)

	if attack_cooldown <= 0.0:
		attack_cooldown = attack_interval
		attack_anim_timer = 0.55
		var dmg: int = randi_range(damage_min, damage_max)
		GameState.damage_player(dmg, mob_title)


func _process_evade_return(delta: float) -> void:
	var to_spawn: Vector3 = spawn_position - global_position
	to_spawn.y = 0.0
	if to_spawn.length() <= 0.6:
		velocity.x = 0.0
		velocity.z = 0.0
		hp = max_hp
		has_shouted_aggro = false
		state = State.IDLE
		_update_nameplate()
		return
	var dir: Vector3 = to_spawn.normalized()
	velocity.x = dir.x * (move_speed * 1.5)
	velocity.z = dir.z * (move_speed * 1.5)
	_face_direction(dir, delta)


func _enter_aggro() -> void:
	if state == State.DEAD:
		return
	state = State.CHASE
	GameState.touch_combat()
	if not has_shouted_aggro:
		has_shouted_aggro = true
		if mob_id == "kobold":
			GameState.add_combat_log("%s кричит: «Ты не забрать свеча!»" % mob_title, Color(1.0, 0.58, 0.35))
		elif mob_id == "boss_crusher":
			GameState.add_combat_log("%s ревёт: «Ты не забрать БОЛЬШАЯ свеча! РАЗДАВЛЮ!»" % mob_title, Color(1.0, 0.35, 0.25))


func _trigger_evade() -> void:
	state = State.EVADE_RETURN
	hp = max_hp
	GameState.add_combat_log("%s отступает к своему логову." % mob_title, GameState.COLOR_LOG_SYSTEM)
	_update_nameplate()


func _face_direction(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 10.0))


func take_damage(amount: int, _attacker: Node3D, ability_name: String = "Атака", is_crit: bool = false) -> void:
	if state == State.DEAD:
		return
	if state == State.EVADE_RETURN:
		GameState.floating_text_requested.emit(global_position + Vector3(0, 2.0, 0), "Мимо", Color(0.8, 0.8, 0.8), false)
		return

	hp = maxi(0, hp - amount)
	var text_col: Color = Color(1.0, 0.88, 0.22) if (is_crit or ability_name != "Автоатака") else Color.WHITE
	var text_str: String = "%d!" % amount if is_crit else "%d" % amount
	var label_y: float = 2.4 if mob_id == "boss_crusher" else 1.8
	GameState.floating_text_requested.emit(global_position + Vector3(randf_range(-0.25, 0.25), label_y, 0), text_str, text_col, is_crit)

	var crit_suffix: String = " (Крит!)" if is_crit else ""
	GameState.add_combat_log("Ваше умение «%s» наносит цели %s %d ед. урона%s." % [ability_name, mob_title, amount, crit_suffix], GameState.COLOR_LOG_COMBAT_PLAYER if ability_name == "Автоатака" else GameState.COLOR_LOG_SPELL)

	if hp <= 0:
		_die()
	else:
		if state == State.IDLE:
			_enter_aggro()
		_update_nameplate()


func apply_stun(duration: float) -> void:
	if state == State.DEAD:
		return
	state = State.STUNNED
	stun_timer = maxf(stun_timer, duration)
	if stun_indicator:
		stun_indicator.visible = true
	GameState.floating_text_requested.emit(global_position + Vector3(0, 2.3, 0), "ОГЛУШЕНИЕ", Color(1.0, 0.90, 0.25), false)


func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	respawn_timer = RESPAWN_DELAY
	if stun_indicator:
		stun_indicator.visible = false
	if collision_shape:
		collision_shape.disabled = false

	_generate_loot()
	refresh_loot_indicator()
	_update_nameplate()

	GameState.add_combat_log("%s повержен!" % mob_title, GameState.COLOR_LOG_SYSTEM)
	GameState.add_xp(xp_reward)
	GameState.register_mob_kill(mob_id)


func _respawn() -> void:
	global_position = spawn_position
	wander_target = spawn_position
	hp = max_hp
	state = State.IDLE
	has_shouted_aggro = false
	loot_copper = 0
	loot_items.clear()
	refresh_loot_indicator()
	_update_nameplate()


func _generate_loot() -> void:
	loot_items.clear()
	if mob_id == "wolf":
		loot_copper = randi_range(6, 15)
		if randf() < 0.72:
			loot_items.append({
				"id": "wolf_pelt",
				"name": "Порванная волчья шкура",
				"type": "junk",
				"value": 12,
				"rarity": "common",
				"desc": "Трофей (продаётся скупщику за 12м)",
				"count": 1,
			})
		if randf() < 0.30:
			loot_items.append({
				"id": "minor_healing_potion",
				"name": "Малое лечебное зелье",
				"type": "potion",
				"bonus": 55,
				"rarity": "common",
				"desc": "Восстанавливает 55 ед. здоровья",
				"count": 1,
			})
	elif mob_id == "kobold":
		loot_copper = randi_range(14, 28)
		if randf() < 0.75:
			loot_items.append({
				"id": "melted_candle",
				"name": "Огарок свечи кобольда",
				"type": "junk",
				"value": 18,
				"rarity": "common",
				"desc": "Трофей (продаётся скупщику за 18м)",
				"count": 1,
			})
		if randf() < 0.42:
			loot_items.append({
				"id": "minor_healing_potion",
				"name": "Малое лечебное зелье",
				"type": "potion",
				"bonus": 55,
				"rarity": "common",
				"desc": "Восстанавливает 55 ед. здоровья",
				"count": 1,
			})
	elif mob_id == "boss_crusher":
		loot_copper = randi_range(85, 130)
		loot_items.append({
			"id": "crusher_axe_trophy",
			"name": "Тяжёлый топор Дробителя",
			"type": "weapon",
			"bonus": 9,
			"rarity": "rare",
			"desc": "+9 к урону оружия",
			"count": 1,
		})
		loot_items.append({
			"id": "lesser_healing_potion",
			"name": "Добротное лечебное зелье",
			"type": "potion",
			"bonus": 95,
			"rarity": "uncommon",
			"desc": "Восстанавливает 95 ед. здоровья",
			"count": 2,
		})


func has_loot() -> bool:
	return state == State.DEAD and (loot_copper > 0 or not loot_items.is_empty())


func is_dead() -> bool:
	return state == State.DEAD


func refresh_loot_indicator() -> void:
	if loot_indicator:
		loot_indicator.visible = has_loot()
	_update_nameplate()


func _update_nameplate() -> void:
	if nameplate == null:
		return
	if state == State.DEAD:
		if has_loot():
			nameplate.text = "%s\n[Добыча]" % mob_title
			nameplate.modulate = Color(1.0, 0.85, 0.25)
		else:
			nameplate.text = "%s (Труп)" % mob_title
			nameplate.modulate = Color(0.65, 0.65, 0.65)
	else:
		var prefix: String = "★ ЭЛИТА " if is_elite else ""
		nameplate.text = "%s[Ур. %d] %s\n%d / %d" % [prefix, level, mob_title, hp, max_hp]
		nameplate.modulate = Color(1.0, 0.42, 0.25) if is_elite else Color(0.96, 0.36, 0.32)


func _update_animation() -> void:
	if rig_node == null:
		return
	var anim_state: String = "IDLE"
	if state == State.DEAD:
		anim_state = "DEAD"
	elif Vector2(velocity.x, velocity.z).length() > 0.25:
		anim_state = "WALK"

	var atk_prog: float = 0.0
	if attack_anim_timer > 0.0:
		atk_prog = 1.0 - (attack_anim_timer / 0.55)

	if mob_id == "wolf":
		RetroModelBuilder.animate_wolf(rig_node, anim_state, anim_time, atk_prog)
	else:
		RetroModelBuilder.animate_humanoid(rig_node, anim_state, anim_time, atk_prog, 0.0, -0.26)
