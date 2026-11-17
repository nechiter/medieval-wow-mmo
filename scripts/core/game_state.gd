extends Node

signal player_stats_changed
signal target_changed(new_target: Node3D)
signal combat_log_added(text: String, color: Color)
signal floating_text_requested(world_pos: Vector3, text: String, color: Color, is_crit: bool)
signal quest_updated
signal inventory_changed
signal loot_window_requested(mob_ref: Node3D)
signal npc_dialog_requested(npc_ref: Node3D)
signal player_leveled_up
signal player_died
signal spirit_released
signal player_resurrected(at_corpse: bool)

const COLOR_LOG_SYSTEM := Color(1.0, 0.85, 0.35)
const COLOR_LOG_COMBAT_PLAYER := Color(1.0, 1.0, 1.0)
const COLOR_LOG_COMBAT_ENEMY := Color(1.0, 0.45, 0.45)
const COLOR_LOG_SPELL := Color(1.0, 0.82, 0.25)
const COLOR_LOG_HEAL := Color(0.45, 1.0, 0.45)
const COLOR_LOG_XP := Color(0.76, 0.55, 1.0)
const COLOR_LOG_LOOT := Color(0.35, 0.95, 0.55)
const COLOR_LOG_ERROR := Color(1.0, 0.35, 0.35)

var player_name: String = "Воитель"
var player_class_name: String = "Воин"
var level: int = 1
var xp: int = 0
var xp_to_next: int = 100

var base_max_hp: int = 120
var max_hp: int = 120
var hp: int = 120

var rage: int = 0
var max_rage: int = 100

var base_damage_min: int = 9
var base_damage_max: int = 15

var equipped_weapon_name: String = "Старый боевой меч"
var equipped_weapon_bonus: int = 0
var equipped_weapon_rarity: String = "common"

var equipped_armor_name: String = "Кожаный нагрудник новичка"
var equipped_armor_hp_bonus: int = 0
var equipped_armor_rarity: String = "common"

var battle_shout_timer: float = 0.0
var money_copper: int = 25
var in_combat: bool = false
var combat_timeout: float = 0.0
var is_dead: bool = false
var is_ghost: bool = false
var corpse_position: Vector3 = Vector3.ZERO

var current_target: Node3D = null
var player_node: Node3D = null

var _regen_accum: float = 0.0
var _rage_decay_accum: float = 0.0
var _shout_ui_accum: float = 0.0

var quests: Dictionary = {}
var quest_order: Array[String] = ["threat_at_outpost", "pack_leader_crusher"]
var inventory: Array[Dictionary] = []

var ability_cooldowns: Dictionary = {
	"charge": 0.0,
	"heroic_strike": 0.0,
	"whirlwind": 0.0,
	"battle_shout": 0.0,
}

var ability_max_cooldowns: Dictionary = {
	"charge": 8.0,
	"heroic_strike": 2.5,
	"whirlwind": 6.0,
	"battle_shout": 15.0,
}


func _ready() -> void:
	_init_quests()
	_init_starting_inventory()
	_recalculate_stats(true)


func _process(delta: float) -> void:
	for key in ability_cooldowns.keys():
		if ability_cooldowns[key] > 0.0:
			ability_cooldowns[key] = maxf(0.0, ability_cooldowns[key] - delta)

	if battle_shout_timer > 0.0:
		battle_shout_timer = maxf(0.0, battle_shout_timer - delta)
		_shout_ui_accum += delta
		if _shout_ui_accum >= 0.5 or battle_shout_timer <= 0.0:
			_shout_ui_accum = 0.0
			if battle_shout_timer <= 0.0:
				add_combat_log("Действие эффекта «Боевой крик» закончилось.", COLOR_LOG_SYSTEM)
			player_stats_changed.emit()

	if in_combat:
		combat_timeout -= delta
		if combat_timeout <= 0.0:
			in_combat = false
			add_combat_log("Вы вышли из боя.", COLOR_LOG_SYSTEM)
			player_stats_changed.emit()
	elif not is_dead:
		# Вне боя здоровье постепенно восстанавливается, а ярость медленно угасает (как в WoW Classic)
		if hp < max_hp:
			_regen_accum += delta
			if _regen_accum >= 1.5:
				_regen_accum = 0.0
				var regen_amt: int = maxi(4, int(round(max_hp * 0.06)))
				hp = mini(max_hp, hp + regen_amt)
				player_stats_changed.emit()
		else:
			_regen_accum = 0.0

		if rage > 0:
			_rage_decay_accum += delta
			if _rage_decay_accum >= 1.0:
				_rage_decay_accum = 0.0
				rage = maxi(0, rage - 2)
				player_stats_changed.emit()
		else:
			_rage_decay_accum = 0.0


func _init_quests() -> void:
	quests = {
		"threat_at_outpost": {
			"id": "threat_at_outpost",
			"title": "Угроза у заставы",
			"giver": "Капитан Маркус",
			"state": "available",
			"prerequisite": "",
			"description": "Лесные волки осмелели и подходят к самой дороге, а кобольды-шахтёры захватили северный рудник.\n\nОчисти подступы к заставе: одолей 3 лесных волков и 3 кобольдов-шахтёров, затем доложи мне.",
			"completion_text": "Доблестная работа, воин! Застава теперь в большей безопасности. Возьми этот клинок ополчения — он пригодится тебе в глубине рудника.",
			"objectives": {
				"wolf": {"label": "Лесной волк", "current": 0, "required": 3},
				"kobold": {"label": "Кобольд-шахтёр", "current": 0, "required": 3},
			},
			"reward_xp": 120,
			"reward_copper": 150,
			"reward_item": {
				"id": "militia_blade",
				"name": "Закалённый клинок ополченца",
				"type": "weapon",
				"bonus": 6,
				"rarity": "uncommon",
				"desc": "+6 к урону оружия",
				"count": 1,
			},
		},
		"pack_leader_crusher": {
			"id": "pack_leader_crusher",
			"title": "Вожак стаи Дробитель",
			"giver": "Капитан Маркус",
			"state": "locked",
			"prerequisite": "threat_at_outpost",
			"description": "В глубине северного рудника засел огромный кобольд-надзиратель по прозвищу Дробитель. Пока он жив, кобольды будут возвращаться снова и снова.\n\nПобеди Надзирателя Дробителя (Элита, ур. 3) у входа в шахту и принеси весть о победе.",
			"completion_text": "Ты поверг самого Дробителя! О тебе заговорят во всём Северноземье. Носи этот нагрудник с честью!",
			"objectives": {
				"boss_crusher": {"label": "Надзиратель Дробитель", "current": 0, "required": 1},
			},
			"reward_xp": 240,
			"reward_copper": 350,
			"reward_item": {
				"id": "northwolf_chest",
				"name": "Нагрудник Северного Волка",
				"type": "armor",
				"bonus": 50,
				"rarity": "rare",
				"desc": "+50 к максимальному здоровью",
				"count": 1,
			},
		},
	}


func _init_starting_inventory() -> void:
	inventory = [
		{
			"id": "minor_healing_potion",
			"name": "Малое лечебное зелье",
			"type": "potion",
			"bonus": 55,
			"rarity": "common",
			"desc": "Восстанавливает 55 ед. здоровья",
			"count": 3,
		}
	]


func _recalculate_stats(heal_full: bool = false) -> void:
	base_max_hp = 120 + (level - 1) * 35
	max_hp = base_max_hp + equipped_armor_hp_bonus
	base_damage_min = 9 + (level - 1) * 3
	base_damage_max = 15 + (level - 1) * 4
	if heal_full:
		hp = max_hp
	else:
		hp = mini(hp, max_hp)
	player_stats_changed.emit()


func set_target(target: Node3D) -> void:
	if current_target == target:
		return
	current_target = target
	target_changed.emit(current_target)


func touch_combat() -> void:
	var was_in_combat: bool = in_combat
	in_combat = true
	combat_timeout = 5.5
	if not was_in_combat:
		add_combat_log("Вы вступили в бой!", COLOR_LOG_SYSTEM)
		player_stats_changed.emit()


func get_attack_damage(multiplier: float = 1.0, flat_bonus: int = 0) -> Dictionary:
	var raw: int = randi_range(base_damage_min, base_damage_max) + equipped_weapon_bonus + flat_bonus
	var dmg: float = float(raw) * multiplier
	if battle_shout_timer > 0.0:
		dmg *= 1.25
	var is_crit: bool = randf() < 0.14
	if is_crit:
		dmg *= 1.75
	return {
		"damage": maxi(1, int(round(dmg))),
		"is_crit": is_crit,
	}


func add_rage(amount: int) -> void:
	if is_dead:
		return
	rage = mini(max_rage, rage + amount)
	player_stats_changed.emit()


func spend_rage(amount: int) -> bool:
	if rage < amount:
		return false
	rage -= amount
	player_stats_changed.emit()
	return true


func heal_player(amount: int, source_label: String = "") -> void:
	if is_dead:
		return
	var prev_hp: int = hp
	hp = mini(max_hp, hp + amount)
	var healed: int = hp - prev_hp
	if healed > 0:
		if source_label != "":
			add_combat_log("%s восстанавливает вам %d ед. здоровья." % [source_label, healed], COLOR_LOG_HEAL)
		if is_instance_valid(player_node):
			floating_text_requested.emit(player_node.global_position + Vector3(0, 2.2, 0), "+%d" % healed, COLOR_LOG_HEAL, false)
	player_stats_changed.emit()


func damage_player(amount: int, attacker_name: String) -> void:
	if is_dead:
		return
	touch_combat()
	hp = maxi(0, hp - amount)
	# Воин получает немного ярости при получении удара
	add_rage(4)
	add_combat_log("%s наносит вам %d ед. урона." % [attacker_name, amount], COLOR_LOG_COMBAT_ENEMY)
	if is_instance_valid(player_node):
		floating_text_requested.emit(player_node.global_position + Vector3(0, 2.0, 0), "-%d" % amount, COLOR_LOG_COMBAT_ENEMY, false)
	if hp <= 0:
		is_dead = true
		in_combat = false
		rage = 0
		is_ghost = false
		if is_instance_valid(player_node):
			corpse_position = player_node.global_position
		add_combat_log("Вы погибли! Освободите дух и вернитесь к своему телу.", COLOR_LOG_ERROR)
		player_died.emit()
	player_stats_changed.emit()


func release_spirit() -> void:
	if not is_dead or is_ghost:
		return
	is_ghost = true
	add_combat_log("Ваш дух освобождён. Найдите своё тело или Духа-целителя на кладбище.", COLOR_LOG_SYSTEM)
	spirit_released.emit()
	player_stats_changed.emit()


# at_corpse = true: воскрешение у тела (50% HP). false: у Духа-целителя (25% HP, без штрафов к карте).
func resurrect(at_corpse: bool) -> void:
	if not is_dead or not is_ghost:
		return
	is_dead = false
	is_ghost = false
	in_combat = false
	rage = 0
	hp = maxi(1, int(round(max_hp * (0.5 if at_corpse else 0.25))))
	if at_corpse:
		add_combat_log("Вы воскресли у своего тела.", COLOR_LOG_SYSTEM)
	else:
		add_combat_log("Дух-целитель вернул вас к жизни, но вы ослаблены.", COLOR_LOG_SYSTEM)
	player_resurrected.emit(at_corpse)
	player_stats_changed.emit()


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	add_combat_log("Вы получаете %d ед. опыта." % amount, COLOR_LOG_XP)
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(round(xp_to_next * 1.55))
		_recalculate_stats(true)
		add_combat_log("Поздравляем! Вы достигли %d-го уровня! Здоровье и сила возросли." % level, COLOR_LOG_SYSTEM)
		if is_instance_valid(player_node):
			floating_text_requested.emit(player_node.global_position + Vector3(0, 2.7, 0), "УРОВЕНЬ %d!" % level, Color(1.0, 0.9, 0.25), true)
		player_leveled_up.emit()
	player_stats_changed.emit()


func add_money(copper: int) -> void:
	if copper <= 0:
		return
	money_copper += copper
	add_combat_log("Получено: %s." % format_money(copper), COLOR_LOG_LOOT)
	player_stats_changed.emit()


func format_money(copper: int) -> String:
	var gold: int = copper / 10000
	var silver: int = (copper % 10000) / 100
	var cop: int = copper % 100
	var parts: Array[String] = []
	if gold > 0:
		parts.append("%dз" % gold)
	if silver > 0 or gold > 0:
		parts.append("%dс" % silver)
	parts.append("%dм" % cop)
	return " ".join(parts)


func register_mob_kill(mob_id: String) -> void:
	var changed: bool = false
	for q_id in quest_order:
		var q: Dictionary = quests[q_id]
		if q["state"] != "active":
			continue
		var objectives: Dictionary = q["objectives"]
		if objectives.has(mob_id):
			var obj: Dictionary = objectives[mob_id]
			if obj["current"] < obj["required"]:
				obj["current"] += 1
				changed = true
				add_combat_log("Задание «%s»: %s (%d/%d)." % [q["title"], obj["label"], obj["current"], obj["required"]], COLOR_LOG_SYSTEM)
				if _are_objectives_complete(objectives):
					q["state"] = "ready_to_turn_in"
					add_combat_log("Задание «%s» выполнено! Вернитесь к %s." % [q["title"], q["giver"]], COLOR_LOG_SYSTEM)
	if changed:
		quest_updated.emit()


func _are_objectives_complete(objectives: Dictionary) -> bool:
	for obj_key in objectives.keys():
		var obj: Dictionary = objectives[obj_key]
		if obj["current"] < obj["required"]:
			return false
	return true


func get_npc_quest_status() -> Dictionary:
	# Приоритет: сначала проверяем готовый к сдаче, затем доступный, затем активный
	for q_id in quest_order:
		var q: Dictionary = quests[q_id]
		if q["state"] == "ready_to_turn_in":
			return {"marker": "?", "color": Color(1.0, 0.85, 0.15), "quest_id": q_id, "mode": "turn_in"}
	for q_id in quest_order:
		var q: Dictionary = quests[q_id]
		if q["state"] == "available":
			return {"marker": "!", "color": Color(1.0, 0.85, 0.15), "quest_id": q_id, "mode": "offer"}
	for q_id in quest_order:
		var q: Dictionary = quests[q_id]
		if q["state"] == "active":
			return {"marker": "?", "color": Color(0.75, 0.75, 0.78), "quest_id": q_id, "mode": "in_progress"}
	return {"marker": "", "color": Color.WHITE, "quest_id": "", "mode": "none"}


func accept_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		return
	var q: Dictionary = quests[quest_id]
	if q["state"] == "available":
		q["state"] = "active"
		add_combat_log("Принято задание: «%s»." % q["title"], COLOR_LOG_SYSTEM)
		quest_updated.emit()


func complete_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		return
	var q: Dictionary = quests[quest_id]
	if q["state"] != "ready_to_turn_in":
		return
	q["state"] = "completed"
	add_combat_log("Задание «%s» завершено!" % q["title"], COLOR_LOG_SYSTEM)
	add_xp(q["reward_xp"])
	add_money(q["reward_copper"])
	var reward_item: Dictionary = q.get("reward_item", {})
	if not reward_item.is_empty():
		add_item_to_inventory(reward_item.duplicate(true))
	# Разблокируем следующее задание, если оно ждало это
	for next_id in quest_order:
		var nq: Dictionary = quests[next_id]
		if nq["state"] == "locked" and nq["prerequisite"] == quest_id:
			nq["state"] = "available"
	quest_updated.emit()


func add_item_to_inventory(item: Dictionary) -> void:
	var item_type: String = item.get("type", "junk")
	var stackable: bool = item_type == "potion" or item_type == "junk"
	var add_count: int = int(item.get("count", 1))
	if stackable:
		for slot in inventory:
			if slot["id"] == item["id"]:
				slot["count"] += add_count
				add_combat_log("Получен предмет: [%s] x%d." % [item["name"], add_count], COLOR_LOG_LOOT)
				inventory_changed.emit()
				return
	var copy: Dictionary = item.duplicate(true)
	if not copy.has("count"):
		copy["count"] = 1
	inventory.append(copy)
	add_combat_log("Получен предмет: [%s]." % copy["name"], COLOR_LOG_LOOT)
	inventory_changed.emit()


func use_or_equip_item(index: int) -> void:
	if index < 0 or index >= inventory.size():
		return
	var item: Dictionary = inventory[index]
	var item_type: String = item.get("type", "junk")
	if item_type == "potion":
		if is_dead:
			add_combat_log("Нельзя использовать зелье, пока вы мертвы.", COLOR_LOG_ERROR)
			return
		if hp >= max_hp:
			add_combat_log("Ваше здоровье уже полное.", COLOR_LOG_SYSTEM)
			return
		heal_player(int(item["bonus"]), item["name"])
		item["count"] -= 1
		if item["count"] <= 0:
			inventory.remove_at(index)
		inventory_changed.emit()
	elif item_type == "weapon":
		var old_weapon: Dictionary = {
			"id": "prev_weapon_" + equipped_weapon_name,
			"name": equipped_weapon_name,
			"type": "weapon",
			"bonus": equipped_weapon_bonus,
			"rarity": equipped_weapon_rarity,
			"desc": "+%d к урону оружия" % equipped_weapon_bonus,
			"count": 1,
		}
		equipped_weapon_name = item["name"]
		equipped_weapon_bonus = int(item["bonus"])
		equipped_weapon_rarity = item.get("rarity", "common")
		inventory.remove_at(index)
		if old_weapon["bonus"] >= 0:
			inventory.insert(index, old_weapon)
		add_combat_log("Вы экипировали оружие: [%s] (+%d к урону)." % [equipped_weapon_name, equipped_weapon_bonus], COLOR_LOG_SYSTEM)
		player_stats_changed.emit()
		inventory_changed.emit()
	elif item_type == "armor":
		var old_armor: Dictionary = {
			"id": "prev_armor_" + equipped_armor_name,
			"name": equipped_armor_name,
			"type": "armor",
			"bonus": equipped_armor_hp_bonus,
			"rarity": equipped_armor_rarity,
			"desc": "+%d к макс. здоровью" % equipped_armor_hp_bonus,
			"count": 1,
		}
		equipped_armor_name = item["name"]
		equipped_armor_hp_bonus = int(item["bonus"])
		equipped_armor_rarity = item.get("rarity", "common")
		inventory.remove_at(index)
		inventory.insert(index, old_armor)
		_recalculate_stats(false)
		hp = mini(max_hp, hp + equipped_armor_hp_bonus)
		add_combat_log("Вы надели броню: [%s] (+%d к здоровью)." % [equipped_armor_name, equipped_armor_hp_bonus], COLOR_LOG_SYSTEM)
		player_stats_changed.emit()
		inventory_changed.emit()
	elif item_type == "junk":
		var value: int = int(item.get("value", 8)) * int(item.get("count", 1))
		inventory.remove_at(index)
		add_money(value)
		add_combat_log("Вы сдали трофей «%s» скупщику за %s." % [item["name"], format_money(value)], COLOR_LOG_LOOT)
		inventory_changed.emit()


func add_combat_log(text: String, color: Color = Color.WHITE) -> void:
	combat_log_added.emit(text, color)
