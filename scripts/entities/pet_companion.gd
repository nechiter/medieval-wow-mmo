class_name PetCompanion
extends CharacterBody3D

const GRAVITY := 24.0
const PET_SPEED := 7.6
const ATTACK_RANGE := 2.7
const ATTACK_INTERVAL := 1.45

var rig_node: Node3D = null
var nameplate: Label3D = null
var anim_time: float = 0.0
var attack_cooldown: float = 0.0
var attack_anim_timer: float = 0.0


func _ready() -> void:
	add_to_group("pet")
	collision_layer = 2
	collision_mask = 1
	GameState.pet_node = self

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = 1.25
	col.shape = cap
	col.position = Vector3(0, 0.65, 0)
	add_child(col)

	rig_node = RetroModelBuilder.build_wolf({
		"scale": 0.96,
		"fur_color": Color(0.52, 0.38, 0.24),
		"belly_color": Color(0.75, 0.64, 0.48),
		"eye_color": Color(0.32, 0.95, 0.48),
		"is_pet": true,
	})
	add_child(rig_node)

	nameplate = Label3D.new()
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.fixed_size = true
	nameplate.pixel_size = 0.00055
	nameplate.font_size = 26
	nameplate.visibility_range_end = 35.0
	nameplate.outline_size = 7
	nameplate.modulate = Color(0.45, 0.96, 0.55)
	nameplate.position = Vector3(0, 1.45, 0)
	add_child(nameplate)

	sync_stats(true)


func sync_stats(heal_full: bool = false) -> void:
	var bond: float = 1.0 + float(GameState.get_talent_rank("beast_bond")) * 0.20
	var new_max: int = int(round((85.0 + float(GameState.level - 1) * 24.0) * bond))
	GameState.pet_max_hp = maxi(50, new_max)
	if heal_full:
		GameState.pet_hp = GameState.pet_max_hp
		GameState.pet_dead = false
	else:
		GameState.pet_hp = mini(GameState.pet_hp, GameState.pet_max_hp)
	_refresh_nameplate()
	GameState.pet_stats_changed.emit()


func _refresh_nameplate() -> void:
	if nameplate == null:
		return
	if GameState.pet_dead:
		nameplate.text = "<Спутник>\nЛесной страж (Пал)"
		nameplate.modulate = Color(0.7, 0.7, 0.7)
	else:
		nameplate.text = "<Спутник>\nЛесной страж (%d/%d)" % [GameState.pet_hp, GameState.pet_max_hp]
		nameplate.modulate = Color(0.45, 0.96, 0.55)


func _physics_process(delta: float) -> void:
	anim_time += delta
	if attack_cooldown > 0.0:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if attack_anim_timer > 0.0:
		attack_anim_timer = maxf(0.0, attack_anim_timer - delta)

	var owner_p: Node3D = GameState.player_node
	if not is_instance_valid(owner_p):
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if GameState.pet_dead or GameState.is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		var pstate: String = "DEAD" if GameState.pet_dead else "IDLE"
		RetroModelBuilder.animate_wolf(rig_node, pstate, anim_time, 0.0, delta)
		return

	if global_position.distance_to(owner_p.global_position) > 22.0:
		global_position = owner_p.global_position + Vector3(-1.5, 0.1, 1.3)

	var target_mob: MobEntity = null
	if GameState.current_target is MobEntity:
		var cand := GameState.current_target as MobEntity
		var should_assist: bool = GameState.in_combat or bool(owner_p.get("auto_attack_enabled")) or cand.hp < cand.max_hp
		if not cand.is_dead() and should_assist and cand.global_position.distance_to(owner_p.global_position) <= 28.0:
			target_mob = cand

	if target_mob != null:
		var to_mob: Vector3 = target_mob.global_position - global_position
		to_mob.y = 0.0
		var dist: float = to_mob.length()
		if dist > ATTACK_RANGE * 0.85:
			var dir: Vector3 = to_mob.normalized()
			velocity.x = dir.x * PET_SPEED
			velocity.z = dir.z * PET_SPEED
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 11.0))
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if dist > 0.05:
				var fdir: Vector3 = to_mob.normalized()
				rotation.y = lerp_angle(rotation.y, atan2(-fdir.x, -fdir.z), minf(1.0, delta * 11.0))
			if attack_cooldown <= 0.0:
				attack_cooldown = ATTACK_INTERVAL
				attack_anim_timer = 0.50
				var bond: float = 1.0 + float(GameState.get_talent_rank("beast_bond")) * 0.20
				var frenzy: float = 1.25 if GameState.pet_frenzy_timer > 0.0 else 1.0
				var raw_dmg: int = maxi(5, int(round(randf_range(6.0, 10.0) + float(GameState.level - 1) * 2.5)))
				var dmg: int = int(round(float(raw_dmg) * bond * frenzy))
				var is_crit: bool = randf() < 0.14
				if is_crit:
					dmg = int(round(float(dmg) * 1.65))
				target_mob.take_damage(dmg, self, "Укус волка", is_crit)
	else:
		var follow_pos: Vector3 = owner_p.global_position - owner_p.global_transform.basis.x * 1.6 + owner_p.global_transform.basis.z * 1.4
		var to_follow: Vector3 = follow_pos - global_position
		to_follow.y = 0.0
		if to_follow.length() > 0.75:
			var fdir2: Vector3 = to_follow.normalized()
			var fspd: float = PET_SPEED if to_follow.length() > 4.0 else 6.2
			velocity.x = fdir2.x * fspd
			velocity.z = fdir2.z * fspd
			rotation.y = lerp_angle(rotation.y, atan2(-fdir2.x, -fdir2.z), minf(1.0, delta * 10.0))
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			rotation.y = lerp_angle(rotation.y, owner_p.rotation.y, minf(1.0, delta * 6.0))

	move_and_slide()
	var anim_st: String = "WALK" if Vector2(velocity.x, velocity.z).length() > 0.25 else "IDLE"
	var atk_prog: float = 1.0 - (attack_anim_timer / 0.50) if attack_anim_timer > 0.0 else 0.0
	RetroModelBuilder.animate_wolf(rig_node, anim_st, anim_time, atk_prog, delta)


func take_damage(amount: int, attacker_name: String) -> void:
	if GameState.pet_dead or GameState.is_dead:
		return
	GameState.pet_hp = maxi(0, GameState.pet_hp - amount)
	GameState.floating_text_requested.emit(global_position + Vector3(0, 1.25, 0), "-%d" % amount, Color(1.0, 0.55, 0.35), false)
	if GameState.pet_hp <= 0:
		GameState.pet_dead = true
		GameState.add_combat_log("Ваш спутник Лесной страж пал в бою от удара (%s)!" % attacker_name, GameState.COLOR_LOG_ERROR)
	_refresh_nameplate()
	GameState.pet_stats_changed.emit()


func heal_or_revive(pct: float = 0.55) -> void:
	var was_dead: bool = GameState.pet_dead
	sync_stats(false)
	if GameState.pet_dead:
		GameState.pet_dead = false
		GameState.pet_hp = maxi(20, int(round(float(GameState.pet_max_hp) * pct)))
		GameState.add_combat_log("Вы воскресили спутника Лесной страж!", GameState.COLOR_LOG_HEAL)
	else:
		var heal_amt: int = maxi(15, int(round(float(GameState.pet_max_hp) * pct)))
		GameState.pet_hp = mini(GameState.pet_max_hp, GameState.pet_hp + heal_amt)
		GameState.add_combat_log("Лечение зверя восстанавливает питомцу %d ед. здоровья." % heal_amt, GameState.COLOR_LOG_HEAL)
	GameState.pet_frenzy_timer = 15.0
	AudioManager.play("heal")
	GameState.floating_text_requested.emit(global_position + Vector3(0, 1.35, 0), "+ЗОВ СТАИ" if was_dead else "+ИСЦЕЛЁН", GameState.COLOR_LOG_HEAL, false)
	_refresh_nameplate()
	GameState.pet_stats_changed.emit()
