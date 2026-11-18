extends Node

signal player_stats_changed
signal target_changed(new_target: Node3D)
signal combat_log_added(text: String, color: Color)
signal floating_text_requested(world_pos: Vector3, text: String, color: Color, is_crit: bool)
signal quest_updated
signal inventory_changed
signal talents_changed
signal loot_window_requested(mob_ref: Node3D)
signal npc_dialog_requested(npc_ref: Node3D)
signal equipment_changed
signal pet_stats_changed
signal player_leveled_up
signal player_died
signal spirit_released
signal player_resurrected(at_corpse: bool)

const SAVE_PATH := "user://savegame.json"
const BAG_CAPACITY := 16

const COLOR_LOG_SYSTEM := Color(1.0, 0.85, 0.35)
const COLOR_LOG_COMBAT_PLAYER := Color(1.0, 1.0, 1.0)
const COLOR_LOG_COMBAT_ENEMY := Color(1.0, 0.45, 0.45)
const COLOR_LOG_SPELL := Color(1.0, 0.82, 0.25)
const COLOR_LOG_HEAL := Color(0.45, 1.0, 0.45)
const COLOR_LOG_XP := Color(0.76, 0.55, 1.0)
const COLOR_LOG_LOOT := Color(0.35, 0.95, 0.55)
const COLOR_LOG_ERROR := Color(1.0, 0.35, 0.35)

var player_class: String = "warrior"
var resource_type: String = "rage"
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
var combo_points: int = 0
var max_combo_points: int = 5
var combo_target: Node3D = null

var base_damage_min: int = 9
var base_damage_max: int = 15

var equipped_weapon_id: String = "starter_weapon"
var equipped_weapon_name: String = "Старый боевой меч"
var equipped_weapon_bonus: int = 0
var equipped_weapon_rarity: String = "common"

var equipped_armor_id: String = "starter_armor"
var equipped_armor_name: String = "Кожаный нагрудник новичка"
var equipped_armor_hp_bonus: int = 0
var equipped_armor_rarity: String = "common"

var battle_shout_timer: float = 0.0
var elixir_timer: float = 0.0
var pet_frenzy_timer: float = 0.0
var is_stealthed: bool = false
var money_copper: int = 25
var in_combat: bool = false
var combat_timeout: float = 0.0
var is_dead: bool = false
var is_ghost: bool = false
var corpse_position: Vector3 = Vector3.ZERO

var mining_skill: int = 1
var herbalism_skill: int = 1

var pet_node: Node3D = null
var pet_hp: int = 90
var pet_max_hp: int = 90
var pet_dead: bool = false

var talent_points: int = 0
var talents: Dictionary = {}

var current_target: Node3D = null
var player_node: Node3D = null

var has_pending_load_transform: bool = false
var pending_load_pos: Vector3 = Vector3(0.0, 0.1, 10.5)
var pending_load_yaw: float = 0.0

var _regen_accum: float = 0.0
var _rage_decay_accum: float = 0.0
var _mana_accum: float = 0.0
var _energy_accum: float = 0.0
var _buff_ui_accum: float = 0.0

var quests: Dictionary = {}
var quest_order: Array[String] = [
	"threat_at_outpost",
	"stolen_supplies",
	"crystal_lake_raiders",
	"herbs_of_elwynn",
	"crystals_of_mine",
	"pack_leader_crusher",
]
var inventory: Array[Dictionary] = []

var ability_cooldowns: Dictionary = {}
var ability_max_cooldowns: Dictionary = {
	"charge": 8.0,
	"heroic_strike": 2.5,
	"whirlwind": 6.0,
	"battle_shout": 15.0,
	"fireball": 1.95,
	"frostbolt": 1.55,
	"frost_nova": 10.0,
	"blink": 12.0,
	"sinister_strike": 1.2,
	"eviscerate": 2.0,
	"stealth": 4.0,
	"kidney_shot": 10.0,
	"arcane_shot": 4.0,
	"serpent_sting": 6.0,
	"concussive_shot": 8.0,
	"mend_pet": 10.0,
	"hearthstone": 45.0,
}


func _ready() -> void:
	reset_for_new_game("warrior")


func _process(delta: float) -> void:
	for key in ability_cooldowns.keys():
		if ability_cooldowns[key] > 0.0:
			ability_cooldowns[key] = maxf(0.0, ability_cooldowns[key] - delta)

	var buff_tick: bool = false
	if battle_shout_timer > 0.0:
		battle_shout_timer = maxf(0.0, battle_shout_timer - delta)
		buff_tick = true
		if battle_shout_timer <= 0.0:
			add_combat_log("Действие эффекта «Боевой крик» закончилось.", COLOR_LOG_SYSTEM)
	if elixir_timer > 0.0:
		elixir_timer = maxf(0.0, elixir_timer - delta)
		buff_tick = true
		if elixir_timer <= 0.0:
			_recalculate_stats(false)
			add_combat_log("Действие эффекта «Эликсир стойкости» закончилось.", COLOR_LOG_SYSTEM)
	if pet_frenzy_timer > 0.0:
		pet_frenzy_timer = maxf(0.0, pet_frenzy_timer - delta)
		buff_tick = true
		if pet_frenzy_timer <= 0.0:
			add_combat_log("Усиление питомца «Зов стаи» закончилось.", COLOR_LOG_SYSTEM)

	if buff_tick:
		_buff_ui_accum += delta
		if _buff_ui_accum >= 0.45 or (battle_shout_timer <= 0.0 and elixir_timer <= 0.0 and pet_frenzy_timer <= 0.0):
			_buff_ui_accum = 0.0
			player_stats_changed.emit()

	if in_combat:
		combat_timeout -= delta
		if combat_timeout <= 0.0:
			in_combat = false
			add_combat_log("Вы вышли из боя.", COLOR_LOG_SYSTEM)
			player_stats_changed.emit()
	elif not is_dead:
		if hp < max_hp:
			_regen_accum += delta
			if _regen_accum >= 1.5:
				_regen_accum = 0.0
				var regen_amt: int = maxi(4, int(round(max_hp * 0.06)))
				hp = mini(max_hp, hp + regen_amt)
				player_stats_changed.emit()
		else:
			_regen_accum = 0.0

		if resource_type == "rage":
			if rage > 0:
				_rage_decay_accum += delta
				if _rage_decay_accum >= 1.0:
					_rage_decay_accum = 0.0
					rage = maxi(0, rage - 2)
					player_stats_changed.emit()
			else:
				_rage_decay_accum = 0.0

	if resource_type == "mana" and not is_dead and rage < max_rage:
		_mana_accum += delta
		if _mana_accum >= 1.0:
			_mana_accum = 0.0
			var bonus_regen: int = get_talent_rank("arcane_mind") * 2
			rage = mini(max_rage, rage + (3 if in_combat else 9) + level + bonus_regen)
			player_stats_changed.emit()

	if resource_type == "energy" and not is_dead and rage < max_rage:
		_energy_accum += delta
		if _energy_accum >= 0.5:
			_energy_accum = 0.0
			rage = mini(max_rage, rage + 6)
			player_stats_changed.emit()


func reset_for_new_game(cls: String) -> void:
	level = 1
	xp = 0
	xp_to_next = 100
	equipped_weapon_id = "starter_weapon"
	equipped_weapon_bonus = 0
	equipped_weapon_rarity = "common"
	equipped_armor_id = "starter_armor"
	equipped_armor_hp_bonus = 0
	equipped_armor_rarity = "common"
	battle_shout_timer = 0.0
	elixir_timer = 0.0
	pet_frenzy_timer = 0.0
	is_stealthed = false
	money_copper = 30
	mining_skill = 1
	herbalism_skill = 1
	in_combat = false
	combat_timeout = 0.0
	is_dead = false
	is_ghost = false
	pet_dead = false
	combo_points = 0
	combo_target = null
	talent_points = 0
	talents = {}
	current_target = null
	has_pending_load_transform = false
	_reset_cooldowns()
	set_class(cls)
	_init_quests()
	_init_starting_inventory()
	_recalculate_stats(true)
	equipment_changed.emit()
	pet_stats_changed.emit()


func _reset_cooldowns() -> void:
	ability_cooldowns.clear()
	for k in ability_max_cooldowns.keys():
		ability_cooldowns[k] = 0.0


func set_class(cls: String) -> void:
	player_class = cls
	if cls == "mage":
		player_class_name = "Маг"
		player_name = "Чародей"
		resource_type = "mana"
		equipped_weapon_id = "apprentice_staff"
		equipped_weapon_name = "Посох ученика"
		equipped_armor_id = "apprentice_robe"
		equipped_armor_name = "Роба ученика"
	elif cls == "rogue":
		player_class_name = "Разбойник"
		player_name = "Тень"
		resource_type = "energy"
		equipped_weapon_id = "twin_daggers"
		equipped_weapon_name = "Парные кинжалы"
		equipped_armor_id = "leather_jerkin"
		equipped_armor_name = "Кожаная куртка"
	elif cls == "hunter":
		player_class_name = "Охотник"
		player_name = "Следопыт"
		resource_type = "mana"
		equipped_weapon_id = "short_bow"
		equipped_weapon_name = "Короткий охотничий лук"
		equipped_armor_id = "tracker_mail"
		equipped_armor_name = "Кольчуга следопыта"
	else:
		player_class = "warrior"
		player_class_name = "Воин"
		player_name = "Воитель"
		resource_type = "rage"
		equipped_weapon_id = "old_broadsword"
		equipped_weapon_name = "Старый боевой меч"
		equipped_armor_id = "novice_cuirass"
		equipped_armor_name = "Кожаный нагрудник новичка"
	_recalculate_stats(true)
	rage = max_rage if resource_type != "rage" else 0
	player_stats_changed.emit()
	equipment_changed.emit()


func _init_quests() -> void:
	var reward_weapon: Dictionary = {
		"id": "militia_blade",
		"name": "Закалённый клинок ополченца",
		"type": "weapon",
		"bonus": 6,
		"rarity": "uncommon",
		"desc": "+6 к урону оружия",
		"count": 1,
	}
	if player_class == "mage":
		reward_weapon = {
			"id": "militia_staff",
			"name": "Посох ополчения",
			"type": "weapon",
			"bonus": 6,
			"rarity": "uncommon",
			"desc": "+6 к силе заклинаний и урону",
			"count": 1,
		}
	elif player_class == "rogue":
		reward_weapon = {
			"id": "scout_daggers",
			"name": "Клинки разведчика",
			"type": "weapon",
			"bonus": 6,
			"rarity": "uncommon",
			"desc": "+6 к урону оружия",
			"count": 1,
		}
	elif player_class == "hunter":
		reward_weapon = {
			"id": "elven_bow",
			"name": "Лук стража леса",
			"type": "weapon",
			"bonus": 6,
			"rarity": "uncommon",
			"desc": "+6 к урону выстрелов",
			"count": 1,
		}

	quests = {
		"threat_at_outpost": {
			"id": "threat_at_outpost",
			"title": "Угроза у заставы",
			"giver": "Капитан Маркус",
			"state": "available",
			"prerequisite": "",
			"description": "Лесные волки осмелели и подходят к дороге, а кобольды-шахтёры спустились от северного рудника.\n\nОчисти подступы к заставе: одолей 3 лесных волков и 3 кобольдов-шахтёров, затем доложи мне.",
			"completion_text": "Доблестная работа! Застава теперь в большей безопасности. Возьми это оружие ополчения — оно пригодится тебе в шахте.",
			"objectives": {
				"wolf": {"label": "Лесной волк", "current": 0, "required": 3},
				"kobold": {"label": "Кобольд-шахтёр", "current": 0, "required": 3},
			},
			"reward_xp": 120,
			"reward_copper": 150,
			"reward_item": reward_weapon,
		},
		"stolen_supplies": {
			"id": "stolen_supplies",
			"title": "Краденые припасы",
			"giver": "Капитан Маркус",
			"state": "available",
			"prerequisite": "",
			"description": "Разбойники Братства разбили лагерь к западу от заставы и утащили наши ящики с провизией!\n\nОтправляйся на запад, разбей 3 головорезов Братства и верни 3 ящика припасов (нажми ПКМ или [F] по ящикам).",
			"completion_text": "Хвала Свету, припасы спасены! Эти зелья пригодятся тебе в следующих вылазках.",
			"objectives": {
				"bandit": {"label": "Головорез Братства", "current": 0, "required": 3},
				"supply_crate": {"label": "Ящик припасов", "current": 0, "required": 3},
			},
			"reward_xp": 140,
			"reward_copper": 180,
			"reward_item": {
				"id": "lesser_healing_potion",
				"name": "Добротное лечебное зелье",
				"type": "potion",
				"bonus": 95,
				"rarity": "uncommon",
				"desc": "Восстанавливает 95 ед. здоровья",
				"count": 2,
			},
		},
		"crystal_lake_raiders": {
			"id": "crystal_lake_raiders",
			"title": "Набег у Хрустального озера",
			"giver": "Капитан Маркус",
			"state": "available",
			"prerequisite": "",
			"description": "У Хрустального озера на востоке расплодились мурлоки! Они пугают путников и разоряют причал.\n\nСтупай на восток к озеру и одолей 4 мурлоков-охотников.",
			"completion_text": "Берега Хрустального озера снова спокойны! Прими эту крепкую броню гарнизона.",
			"objectives": {
				"murloc": {"label": "Мурлок-охотник", "current": 0, "required": 4},
			},
			"reward_xp": 160,
			"reward_copper": 220,
			"reward_item": {
				"id": "outpost_vest",
				"name": "Доспех дозорного озера",
				"type": "armor",
				"bonus": 35,
				"rarity": "uncommon",
				"desc": "+35 к максимальному здоровью",
				"count": 1,
			},
		},
		"herbs_of_elwynn": {
			"id": "herbs_of_elwynn",
			"title": "Дары Элвиннского леса",
			"giver": "Травница Лира",
			"state": "available",
			"prerequisite": "",
			"description": "Чтобы варить целебные настои для раненых стражников, мне нужны дикие травы долины.\n\nСобери 3 цветка Мироцвета (в лесу у заставы) и 2 Сребролиста (близ берега Хрустального озера).",
			"completion_text": "Замечательные свежие соцветия! Прими эти эликсиры — они укрепят здоровье и силу перед битвой.",
			"objectives": {
				"peacebloom": {"label": "Мироцвет", "current": 0, "required": 3},
				"silverleaf": {"label": "Сребролист", "current": 0, "required": 2},
			},
			"reward_xp": 130,
			"reward_copper": 160,
			"reward_item": {
				"id": "elixir_fortitude",
				"name": "Эликсир стойкости",
				"type": "elixir",
				"bonus": 25,
				"rarity": "uncommon",
				"desc": "+25 к макс. здоровью и +15% к урону на 60 сек.",
				"count": 2,
			},
		},
		"crystals_of_mine": {
			"id": "crystals_of_mine",
			"title": "Лазурные жилы рудника",
			"giver": "Травница Лира",
			"state": "available",
			"prerequisite": "",
			"description": "Сияющие кристаллы Северного рудника усиливают алхимические составы!\n\nСпустись к руднику на севере и добудь 3 Лазурных кристалла из сияющих жил (ПКМ или [F]).",
			"completion_text": "Какая чистота граней! Вот твоя награда — укреплённая кольчуга рудокопов.",
			"objectives": {
				"azure_crystal": {"label": "Лазурный кристалл", "current": 0, "required": 3},
			},
			"reward_xp": 180,
			"reward_copper": 240,
			"reward_item": {
				"id": "miners_brigandine",
				"name": "Кольчуга рудокопа",
				"type": "armor",
				"bonus": 45,
				"rarity": "uncommon",
				"desc": "+45 к максимальному здоровью",
				"count": 1,
			},
		},
		"pack_leader_crusher": {
			"id": "pack_leader_crusher",
			"title": "Глубины Северного рудника",
			"giver": "Капитан Маркус",
			"state": "locked",
			"prerequisite": "threat_at_outpost",
			"description": "Пора покончить с угрозой кобольдов! Войди в тоннель Северного рудника, разбей 2 кобольдов-геомантов и свергни их вожака — Надзирателя Дробителя (Элита, ур. 3) в глубине шахты!",
			"completion_text": "Невероятно! Ты прошёл весь Северный рудник и поверг самого Дробителя! Весь гарнизон славит твоё имя!",
			"objectives": {
				"kobold_geomancer": {"label": "Кобольд-геомант", "current": 0, "required": 2},
				"boss_crusher": {"label": "Надзиратель Дробитель", "current": 0, "required": 1},
			},
			"reward_xp": 280,
			"reward_copper": 450,
			"reward_item": {
				"id": "northwolf_chest",
				"name": "Нагрудник Северного Волка",
				"type": "armor",
				"bonus": 60,
				"rarity": "rare",
				"desc": "+60 к максимальному здоровью",
				"count": 1,
			},
		},
	}


func _init_starting_inventory() -> void:
	inventory = [
		{
			"id": "hearthstone",
			"name": "Камень возвращения",
			"type": "hearthstone",
			"bonus": 0,
			"rarity": "common",
			"desc": "Телепортирует вас обратно к заставе Северноземья (КД 45 сек).",
			"count": 1,
		},
		{
			"id": "minor_healing_potion",
			"name": "Малое лечебное зелье",
			"type": "potion",
			"bonus": 55,
			"rarity": "common",
			"desc": "Восстанавливает 55 ед. здоровья",
			"count": 3,
		},
		{
			"id": "tough_jerky",
			"name": "Дорожный паёк",
			"type": "food",
			"bonus": 45,
			"rarity": "common",
			"desc": "Вне боя восстанавливает 45% здоровья и маны",
			"count": 3,
		},
	]
	if player_class == "mage" or player_class == "hunter":
		inventory.append({
			"id": "minor_mana_potion",
			"name": "Малое зелье маны",
			"type": "mana_potion",
			"bonus": 55,
			"rarity": "common",
			"desc": "Восстанавливает 55 ед. маны",
			"count": 2,
		})
	_normalize_bag_slots()


func get_class_talents() -> Array[Dictionary]:
	if player_class == "mage":
		return [
			{"id": "fire_power", "name": "Сила магии", "max": 3, "desc": "+10% к урону всех заклинаний за ранг."},
			{"id": "ice_shatter", "name": "Ледяные осколки", "max": 3, "desc": "+4% к шансу критического удара за ранг."},
			{"id": "arcane_mind", "name": "Ясный разум", "max": 3, "desc": "+18 к макс. мане и +2 регенерации/сек за ранг."},
		]
	if player_class == "rogue":
		return [
			{"id": "malice", "name": "Злоба", "max": 3, "desc": "+10% к урону атак и приёмов за ранг."},
			{"id": "lethality", "name": "Смертоносность", "max": 3, "desc": "+5% к шансу критического удара за ранг."},
			{"id": "vigor", "name": "Живучесть", "max": 3, "desc": "+14 к макс. здоровью и +10 к макс. энергии за ранг."},
		]
	if player_class == "hunter":
		return [
			{"id": "surefooted", "name": "Верный выстрел", "max": 3, "desc": "+9% к урону выстрелов из лука за ранг."},
			{"id": "lethal_shots", "name": "Смертельный прицел", "max": 3, "desc": "+4% к шансу критического удара за ранг."},
			{"id": "beast_bond", "name": "Узы дикой природы", "max": 3, "desc": "+14 к здоровью охотника и +20% к мощи и ОЗ волка за ранг."},
		]
	return [
		{"id": "heavy_blade", "name": "Тяжёлый клинок", "max": 3, "desc": "+9% к урону атак за ранг."},
		{"id": "cruelty", "name": "Жестокость", "max": 3, "desc": "+4% к шансу критического удара за ранг."},
		{"id": "vitality", "name": "Закалка", "max": 3, "desc": "+18 к максимальному здоровью за ранг."},
	]


func get_talent_rank(talent_id: String) -> int:
	return int(talents.get(talent_id, 0))


func spend_talent_point(talent_id: String) -> bool:
	if talent_points <= 0:
		return false
	for t in get_class_talents():
		if t["id"] == talent_id:
			var cur: int = get_talent_rank(talent_id)
			if cur >= int(t["max"]):
				return false
			talents[talent_id] = cur + 1
			talent_points -= 1
			_recalculate_stats(false)
			AudioManager.play("ui_click")
			add_combat_log("Талант «%s» улучшен до %d/%d." % [t["name"], cur + 1, int(t["max"])], COLOR_LOG_SYSTEM)
			talents_changed.emit()
			return true
	return false


func _recalculate_stats(heal_full: bool = false) -> void:
	if player_class == "mage":
		base_max_hp = 85 + (level - 1) * 24
		base_damage_min = 7 + (level - 1) * 2
		base_damage_max = 11 + (level - 1) * 3
		max_rage = 100 + (level - 1) * 14 + get_talent_rank("arcane_mind") * 18
	elif player_class == "rogue":
		base_max_hp = 100 + (level - 1) * 28 + get_talent_rank("vigor") * 14
		base_damage_min = 8 + (level - 1) * 3
		base_damage_max = 13 + (level - 1) * 3
		max_rage = 100 + get_talent_rank("vigor") * 10
	elif player_class == "hunter":
		base_max_hp = 105 + (level - 1) * 28 + get_talent_rank("beast_bond") * 14
		base_damage_min = 8 + (level - 1) * 3
		base_damage_max = 13 + (level - 1) * 3
		max_rage = 100 + (level - 1) * 14
	else:
		base_max_hp = 120 + (level - 1) * 35 + get_talent_rank("vitality") * 18
		base_damage_min = 9 + (level - 1) * 3
		base_damage_max = 15 + (level - 1) * 4
		max_rage = 100
	var elixir_hp: int = 25 if elixir_timer > 0.0 else 0
	max_hp = base_max_hp + equipped_armor_hp_bonus + elixir_hp
	if heal_full:
		hp = max_hp
		if resource_type != "rage":
			rage = max_rage
	else:
		hp = mini(hp, max_hp)
		rage = mini(rage, max_rage)
	player_stats_changed.emit()


func get_character_stats() -> Dictionary:
	var crit_bonus: float = 0.0
	var dmg_talent: float = 0.0
	var s_val: int = 12 + level * 2
	var a_val: int = 10 + level * 2
	var st_val: int = 11 + level * 2
	var i_val: int = 8 + level
	var sp_val: int = 9 + level
	if player_class == "warrior":
		s_val += 8 + level * 2
		st_val += 7 + level * 2
		crit_bonus += get_talent_rank("cruelty") * 0.04
		dmg_talent += get_talent_rank("heavy_blade") * 0.09
	elif player_class == "mage":
		i_val += 12 + level * 3
		sp_val += 8 + level * 2
		crit_bonus += get_talent_rank("ice_shatter") * 0.04
		dmg_talent += get_talent_rank("fire_power") * 0.10
	elif player_class == "rogue":
		a_val += 11 + level * 3
		st_val += 3 + level
		crit_bonus += get_talent_rank("lethality") * 0.05
		dmg_talent += get_talent_rank("malice") * 0.10
	elif player_class == "hunter":
		a_val += 10 + level * 3
		i_val += 4 + level
		st_val += 4 + level
		crit_bonus += get_talent_rank("lethal_shots") * 0.04
		dmg_talent += get_talent_rank("surefooted") * 0.09

	var armor_val: int = 45 if player_class == "mage" else (85 if player_class in ["rogue", "hunter"] else 155)
	armor_val += level * 14 + equipped_armor_hp_bonus * 2
	var crit_pct: float = (0.14 + crit_bonus) * 100.0
	var dmg_min: int = base_damage_min + equipped_weapon_bonus
	var dmg_max: int = base_damage_max + equipped_weapon_bonus
	var dmg_mult: float = 1.0 + dmg_talent
	if battle_shout_timer > 0.0:
		dmg_mult *= 1.25
	if elixir_timer > 0.0:
		dmg_mult *= 1.15
	return {
		"strength": s_val,
		"agility": a_val,
		"stamina": st_val + int(equipped_armor_hp_bonus / 4),
		"intellect": i_val,
		"spirit": sp_val,
		"armor": armor_val,
		"crit_pct": crit_pct,
		"dmg_min": int(round(dmg_min * dmg_mult)),
		"dmg_max": int(round(dmg_max * dmg_mult)),
	}


func get_weapon_visual_id() -> String:
	if equipped_weapon_id == "crusher_axe_trophy":
		return "greataxe"
	if player_class == "mage":
		return "staff"
	if player_class == "rogue":
		return "dagger"
	if player_class == "hunter":
		return "bow"
	return "greatsword"


func get_armor_visual_tier() -> int:
	if equipped_armor_rarity == "rare":
		return 2
	if equipped_armor_rarity == "uncommon" or equipped_armor_hp_bonus >= 30:
		return 1
	return 0


func set_target(target: Node3D) -> void:
	if current_target == target:
		return
	current_target = target
	target_changed.emit(current_target)


func add_combo_points(amount: int, target: Node3D) -> void:
	if player_class != "rogue":
		return
	if combo_target != target:
		combo_points = 0
		combo_target = target
	combo_points = mini(max_combo_points, combo_points + amount)
	player_stats_changed.emit()


func consume_combo_points(target: Node3D) -> int:
	if player_class != "rogue" or combo_target != target:
		return 0
	var pts: int = combo_points
	combo_points = 0
	player_stats_changed.emit()
	return pts


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
	if elixir_timer > 0.0:
		dmg *= 1.15
	var dmg_talent_mult: float = 1.0
	var crit_bonus: float = 0.0
	if player_class == "mage":
		dmg_talent_mult += get_talent_rank("fire_power") * 0.10
		crit_bonus += get_talent_rank("ice_shatter") * 0.04
	elif player_class == "rogue":
		dmg_talent_mult += get_talent_rank("malice") * 0.10
		crit_bonus += get_talent_rank("lethality") * 0.05
	elif player_class == "hunter":
		dmg_talent_mult += get_talent_rank("surefooted") * 0.09
		crit_bonus += get_talent_rank("lethal_shots") * 0.04
	else:
		dmg_talent_mult += get_talent_rank("heavy_blade") * 0.09
		crit_bonus += get_talent_rank("cruelty") * 0.04

	dmg *= dmg_talent_mult
	var is_crit: bool = randf() < (0.14 + crit_bonus)
	if is_crit:
		dmg *= 1.75
	return {
		"damage": maxi(1, int(round(dmg))),
		"is_crit": is_crit,
	}


func add_rage(amount: int) -> void:
	if is_dead or resource_type != "rage":
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
		AudioManager.play("heal")
		if source_label != "":
			add_combat_log("%s восстанавливает вам %d ед. здоровья." % [source_label, healed], COLOR_LOG_HEAL)
		if is_instance_valid(player_node):
			floating_text_requested.emit(player_node.global_position + Vector3(0, 2.2, 0), "+%d" % healed, COLOR_LOG_HEAL, false)
	player_stats_changed.emit()


func damage_player(amount: int, attacker_name: String) -> void:
	if is_dead:
		return
	touch_combat()
	if is_stealthed:
		is_stealthed = false
	hp = maxi(0, hp - amount)
	add_rage(4)
	AudioManager.play("hit", -2.0)
	add_combat_log("%s наносит вам %d ед. урона." % [attacker_name, amount], COLOR_LOG_COMBAT_ENEMY)
	if is_instance_valid(player_node):
		floating_text_requested.emit(player_node.global_position + Vector3(0, 2.0, 0), "-%d" % amount, COLOR_LOG_COMBAT_ENEMY, false)
	if hp <= 0:
		is_dead = true
		in_combat = false
		rage = 0
		combo_points = 0
		is_ghost = false
		if is_instance_valid(player_node):
			corpse_position = player_node.global_position
		AudioManager.play("death")
		add_combat_log("Вы погибли! Освободите дух и вернитесь к своему телу.", COLOR_LOG_ERROR)
		player_died.emit()
	player_stats_changed.emit()


func release_spirit() -> void:
	if not is_dead or is_ghost:
		return
	is_ghost = true
	AudioManager.play("stealth")
	add_combat_log("Ваш дух освобождён. Найдите своё тело или Духа-целителя на кладбище.", COLOR_LOG_SYSTEM)
	spirit_released.emit()
	player_stats_changed.emit()


func resurrect(at_corpse: bool) -> void:
	if not is_dead or not is_ghost:
		return
	is_dead = false
	is_ghost = false
	in_combat = false
	rage = max_rage if resource_type != "rage" else 0
	hp = maxi(1, int(round(max_hp * (0.5 if at_corpse else 0.25))))
	AudioManager.play("heal")
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
		talent_points += 1
		xp_to_next = int(round(xp_to_next * 1.55))
		_recalculate_stats(true)
		AudioManager.play("level_up")
		add_combat_log("Поздравляем! Вы достигли %d-го уровня! (+1 очко талантов [T])." % level, COLOR_LOG_SYSTEM)
		if is_instance_valid(player_node):
			floating_text_requested.emit(player_node.global_position + Vector3(0, 2.7, 0), "УРОВЕНЬ %d!" % level, Color(1.0, 0.9, 0.25), true)
		player_leveled_up.emit()
		talents_changed.emit()
	player_stats_changed.emit()


func add_money(copper: int) -> void:
	if copper <= 0:
		return
	money_copper += copper
	AudioManager.play("loot")
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
	register_quest_progress(mob_id)


func register_quest_progress(target_id: String) -> void:
	var changed: bool = false
	for q_id in quest_order:
		var q: Dictionary = quests[q_id]
		if q["state"] != "active":
			continue
		var objectives: Dictionary = q["objectives"]
		if objectives.has(target_id):
			var obj: Dictionary = objectives[target_id]
			if obj["current"] < obj["required"]:
				obj["current"] += 1
				changed = true
				add_combat_log("Задание «%s»: %s (%d/%d)." % [q["title"], obj["label"], obj["current"], obj["required"]], COLOR_LOG_SYSTEM)
				if _are_objectives_complete(objectives):
					q["state"] = "ready_to_turn_in"
					AudioManager.play("quest_accept")
					add_combat_log("Задание «%s» выполнено! Вернитесь к %s." % [q["title"], q["giver"]], COLOR_LOG_SYSTEM)
	if changed:
		quest_updated.emit()


func _are_objectives_complete(objectives: Dictionary) -> bool:
	for obj_key in objectives.keys():
		var obj: Dictionary = objectives[obj_key]
		if obj["current"] < obj["required"]:
			return false
	return true


func get_npc_quest_status(giver_name: String = "") -> Dictionary:
	for q_id in quest_order:
		var q: Dictionary = quests[q_id]
		if giver_name != "" and String(q.get("giver", "")) != giver_name:
			continue
		if q["state"] == "ready_to_turn_in":
			return {"marker": "?", "color": Color(1.0, 0.85, 0.15), "quest_id": q_id, "mode": "turn_in"}
	for q_id in quest_order:
		var q: Dictionary = quests[q_id]
		if giver_name != "" and String(q.get("giver", "")) != giver_name:
			continue
		if q["state"] == "available":
			return {"marker": "!", "color": Color(1.0, 0.85, 0.15), "quest_id": q_id, "mode": "offer"}
	for q_id in quest_order:
		var q: Dictionary = quests[q_id]
		if giver_name != "" and String(q.get("giver", "")) != giver_name:
			continue
		if q["state"] == "active":
			return {"marker": "?", "color": Color(0.75, 0.75, 0.78), "quest_id": q_id, "mode": "in_progress"}
	return {"marker": "", "color": Color.WHITE, "quest_id": "", "mode": "none"}


func get_npc_quests(giver_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for q_id in quest_order:
		var q: Dictionary = quests[q_id]
		if String(q.get("giver", "")) != giver_name:
			continue
		if q["state"] in ["ready_to_turn_in", "available", "active"]:
			out.append(q)
	return out


func accept_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		return
	var q: Dictionary = quests[quest_id]
	if q["state"] == "available":
		q["state"] = "active"
		AudioManager.play("quest_accept")
		add_combat_log("Принято задание: «%s»." % q["title"], COLOR_LOG_SYSTEM)
		quest_updated.emit()


func complete_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		return
	var q: Dictionary = quests[quest_id]
	if q["state"] != "ready_to_turn_in":
		return
	q["state"] = "completed"
	AudioManager.play("quest_complete")
	add_combat_log("Задание «%s» завершено!" % q["title"], COLOR_LOG_SYSTEM)
	add_xp(q["reward_xp"])
	add_money(q["reward_copper"])
	var reward_item: Dictionary = q.get("reward_item", {})
	if not reward_item.is_empty():
		add_item_to_inventory(reward_item.duplicate(true))
	for next_id in quest_order:
		var nq: Dictionary = quests[next_id]
		if nq["state"] == "locked" and nq["prerequisite"] == quest_id:
			nq["state"] = "available"
	quest_updated.emit()


func _find_free_bag_slot() -> int:
	var used: Dictionary = {}
	for it in inventory:
		if it.has("bag_slot"):
			used[int(it["bag_slot"])] = true
	for s in range(BAG_CAPACITY):
		if not used.has(s):
			return s
	var extra: int = BAG_CAPACITY
	while used.has(extra):
		extra += 1
	return extra


func _normalize_bag_slots() -> void:
	var used: Dictionary = {}
	for it in inventory:
		var slot_v: int = int(it.get("bag_slot", -1))
		if slot_v < 0 or used.has(slot_v):
			var free_s: int = 0
			while used.has(free_s):
				free_s += 1
			it["bag_slot"] = free_s
			used[free_s] = true
		else:
			it["bag_slot"] = slot_v
			used[slot_v] = true


func get_bag_slots() -> Array[Dictionary]:
	_normalize_bag_slots()
	var out: Array[Dictionary] = []
	for _i in range(BAG_CAPACITY):
		out.append({})
	for i in range(inventory.size()):
		var it: Dictionary = inventory[i]
		var s: int = int(it.get("bag_slot", i))
		if s >= 0 and s < BAG_CAPACITY:
			out[s] = {"inv_index": i, "item": it}
	return out


func move_or_swap_bag_slot(from_slot: int, to_slot: int) -> bool:
	if from_slot == to_slot or from_slot < 0 or to_slot < 0 or from_slot >= BAG_CAPACITY or to_slot >= BAG_CAPACITY:
		return false
	_normalize_bag_slots()
	var idx_a: int = -1
	var idx_b: int = -1
	for i in range(inventory.size()):
		var s: int = int(inventory[i].get("bag_slot", -1))
		if s == from_slot:
			idx_a = i
		elif s == to_slot:
			idx_b = i
	if idx_a < 0:
		return false
	inventory[idx_a]["bag_slot"] = to_slot
	if idx_b >= 0:
		inventory[idx_b]["bag_slot"] = from_slot
	AudioManager.play("ui_click")
	inventory_changed.emit()
	return true


func sort_backpack() -> void:
	var prio: Dictionary = {
		"hearthstone": 0, "potion": 1, "mana_potion": 2, "elixir": 3,
		"bandage": 4, "food": 5, "weapon": 6, "armor": 7, "material": 8, "junk": 9,
	}
	var rar_p: Dictionary = {"rare": 0, "uncommon": 1, "common": 2, "poor": 3, "junk": 3}
	inventory.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = int(prio.get(String(a.get("type", "junk")), 9))
		var pb: int = int(prio.get(String(b.get("type", "junk")), 9))
		if pa != pb:
			return pa < pb
		var ra: int = int(rar_p.get(String(a.get("rarity", "common")), 2))
		var rb: int = int(rar_p.get(String(b.get("rarity", "common")), 2))
		if ra != rb:
			return ra < rb
		return String(a.get("name", "")) < String(b.get("name", ""))
	)
	for i in range(inventory.size()):
		inventory[i]["bag_slot"] = i
	AudioManager.play("ui_click")
	inventory_changed.emit()


func add_item_to_inventory(item: Dictionary) -> void:
	var item_type: String = item.get("type", "junk")
	var stackable: bool = item_type in ["potion", "mana_potion", "food", "junk", "material", "elixir", "bandage"]
	var add_count: int = int(item.get("count", 1))
	AudioManager.play("loot")
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
	copy["bag_slot"] = _find_free_bag_slot()
	inventory.append(copy)
	add_combat_log("Получен предмет: [%s]." % copy["name"], COLOR_LOG_LOOT)
	inventory_changed.emit()


func get_item_count(item_id: String) -> int:
	var total: int = 0
	for it in inventory:
		if it.get("id", "") == item_id:
			total += int(it.get("count", 1))
	return total


func get_item_count_by_types(types: Array) -> int:
	var total: int = 0
	for it in inventory:
		if String(it.get("type", "")) in types:
			total += int(it.get("count", 1))
	return total


func use_first_item_by_types(types: Array) -> bool:
	for idx in range(inventory.size()):
		if String(inventory[idx].get("type", "")) in types:
			use_or_equip_item(idx)
			return true
	add_combat_log("Нет подходящего предмета в сумке.", COLOR_LOG_ERROR)
	AudioManager.play("error")
	return false


func _consume_material(item_id: String, amount: int) -> bool:
	if get_item_count(item_id) < amount:
		return false
	var rem: int = amount
	for i in range(inventory.size() - 1, -1, -1):
		if inventory[i].get("id", "") == item_id:
			var take: int = mini(rem, int(inventory[i].get("count", 1)))
			inventory[i]["count"] = int(inventory[i].get("count", 1)) - take
			rem -= take
			if int(inventory[i]["count"]) <= 0:
				inventory.remove_at(i)
			if rem <= 0:
				return true
	return rem <= 0


func register_gather(node_type: String) -> void:
	if node_type == "peacebloom":
		herbalism_skill += 1
		add_item_to_inventory({
			"id": "peacebloom", "name": "Мироцвет", "type": "material",
			"value": 16, "rarity": "common", "desc": "Трава для бинтов и зелий (Травничество).", "count": 1,
		})
		register_quest_progress("peacebloom")
	elif node_type == "silverleaf":
		herbalism_skill += 1
		add_item_to_inventory({
			"id": "silverleaf", "name": "Сребролист", "type": "material",
			"value": 22, "rarity": "common", "desc": "Редкая лесная трава для алхимии.", "count": 1,
		})
		register_quest_progress("silverleaf")
	elif node_type == "azure_crystal":
		mining_skill += 1
		add_item_to_inventory({
			"id": "azure_crystal", "name": "Лазурный кристалл", "type": "material",
			"value": 34, "rarity": "uncommon", "desc": "Магический минерал Северного рудника (Горное дело).", "count": 1,
		})
		register_quest_progress("azure_crystal")
	else:
		mining_skill += 1
		add_item_to_inventory({
			"id": "copper_ore", "name": "Медная руда", "type": "material",
			"value": 20, "rarity": "common", "desc": "Добыто киркой из жилы (Горное дело).", "count": 1,
		})
	add_xp(14)
	player_stats_changed.emit()


func craft_recipe(recipe_id: String) -> bool:
	if recipe_id == "bandage":
		if get_item_count("peacebloom") < 2:
			AudioManager.play("error")
			add_combat_log("Нужно 2x Мироцвет для создания бинтов.", COLOR_LOG_ERROR)
			return false
		_consume_material("peacebloom", 2)
		add_item_to_inventory({
			"id": "linen_bandage", "name": "Травяной бинт", "type": "bandage",
			"bonus": 80, "rarity": "common", "desc": "Быстро перевязывает раны на 80 ед. здоровья.", "count": 2,
		})
		add_xp(15)
		inventory_changed.emit()
		return true
	elif recipe_id == "potion":
		if get_item_count("peacebloom") < 1 or get_item_count("silverleaf") < 1:
			AudioManager.play("error")
			add_combat_log("Нужно 1x Мироцвет и 1x Сребролист.", COLOR_LOG_ERROR)
			return false
		_consume_material("peacebloom", 1)
		_consume_material("silverleaf", 1)
		add_item_to_inventory({
			"id": "lesser_healing_potion", "name": "Добротное лечебное зелье", "type": "potion",
			"bonus": 95, "rarity": "uncommon", "desc": "Восстанавливает 95 ед. здоровья.", "count": 1,
		})
		add_xp(22)
		inventory_changed.emit()
		return true
	elif recipe_id == "elixir":
		if get_item_count("silverleaf") < 1 or get_item_count("azure_crystal") < 1:
			AudioManager.play("error")
			add_combat_log("Нужно 1x Сребролист и 1x Лазурный кристалл.", COLOR_LOG_ERROR)
			return false
		_consume_material("silverleaf", 1)
		_consume_material("azure_crystal", 1)
		add_item_to_inventory({
			"id": "elixir_fortitude", "name": "Эликсир стойкости", "type": "elixir",
			"bonus": 25, "rarity": "uncommon", "desc": "+25 к макс. здоровью и +15% к урону на 60 сек.", "count": 1,
		})
		add_xp(30)
		inventory_changed.emit()
		return true
	return false


func get_item_sell_price(item: Dictionary) -> int:
	var t: String = String(item.get("type", "junk"))
	if t == "hearthstone":
		return 0
	if item.has("value"):
		return maxi(2, int(item.get("value", 8)))
	if t == "weapon" or t == "armor":
		var b: int = int(item.get("bonus", 0))
		return maxi(15, b * 14 + (35 if String(item.get("rarity", "common")) == "rare" else 12))
	if t == "elixir":
		return 28
	return maxi(6, int(item.get("bonus", 20)) / 3)


func sell_item_at(index: int) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	var item: Dictionary = inventory[index]
	var price: int = get_item_sell_price(item)
	if price <= 0:
		AudioManager.play("error")
		add_combat_log("Этот предмет нельзя продать.", COLOR_LOG_ERROR)
		return false
	var cnt: int = int(item.get("count", 1))
	var total: int = price * cnt
	var it_name: String = String(item.get("name", "Предмет"))
	inventory.remove_at(index)
	add_money(total)
	add_combat_log("Продано [%s] x%d за %s." % [it_name, cnt, format_money(total)], COLOR_LOG_LOOT)
	inventory_changed.emit()
	return true


func use_or_equip_item(index: int) -> void:
	if index < 0 or index >= inventory.size():
		return
	var item: Dictionary = inventory[index]
	var item_type: String = item.get("type", "junk")
	if item_type == "hearthstone":
		if is_dead or in_combat:
			AudioManager.play("error")
			add_combat_log("Камень возвращения можно использовать только живым и вне боя!", COLOR_LOG_ERROR)
			return
		var cd: float = float(ability_cooldowns.get("hearthstone", 0.0))
		if cd > 0.0:
			AudioManager.play("error")
			add_combat_log("Камень возвращения перезаряжается (%.1f сек)." % cd, COLOR_LOG_ERROR)
			return
		if is_instance_valid(player_node) and player_node.has_method("start_hearthstone_cast"):
			player_node.call("start_hearthstone_cast")
		return
	if item_type == "potion" or item_type == "bandage":
		if is_dead:
			add_combat_log("Нельзя использовать, пока вы мертвы.", COLOR_LOG_ERROR)
			return
		if hp >= max_hp:
			add_combat_log("Ваше здоровье уже полное.", COLOR_LOG_SYSTEM)
			return
		heal_player(int(item["bonus"]), item["name"])
		item["count"] -= 1
		if item["count"] <= 0:
			inventory.remove_at(index)
		inventory_changed.emit()
	elif item_type == "elixir":
		if is_dead:
			add_combat_log("Нельзя выпить эликсир, пока вы мертвы.", COLOR_LOG_ERROR)
			return
		elixir_timer = 60.0
		_recalculate_stats(false)
		AudioManager.play("heal")
		add_combat_log("Вы выпили [%s]: +25 ОЗ и +15%% к урону на 60 сек!" % item["name"], COLOR_LOG_SPELL)
		if is_instance_valid(player_node):
			floating_text_requested.emit(player_node.global_position + Vector3(0, 2.3, 0), "ЭЛИКСИР!", COLOR_LOG_SPELL, true)
		item["count"] -= 1
		if item["count"] <= 0:
			inventory.remove_at(index)
		player_stats_changed.emit()
		inventory_changed.emit()
	elif item_type == "mana_potion":
		if is_dead or resource_type != "mana":
			add_combat_log("Зелье маны могут использовать только заклинатели.", COLOR_LOG_ERROR)
			return
		if rage >= max_rage:
			add_combat_log("Ваша мана уже полная.", COLOR_LOG_SYSTEM)
			return
		var prev_m: int = rage
		rage = mini(max_rage, rage + int(item["bonus"]))
		AudioManager.play("heal")
		add_combat_log("%s восстанавливает %d ед. маны." % [item["name"], rage - prev_m], Color(0.45, 0.72, 1.0))
		item["count"] -= 1
		if item["count"] <= 0:
			inventory.remove_at(index)
		player_stats_changed.emit()
		inventory_changed.emit()
	elif item_type == "food":
		if is_dead or in_combat:
			add_combat_log("Есть можно только живым и вне боя.", COLOR_LOG_ERROR)
			return
		var pct: float = float(item.get("bonus", 45)) / 100.0
		heal_player(maxi(15, int(round(max_hp * pct))), item["name"])
		if resource_type == "mana":
			rage = mini(max_rage, rage + int(round(max_rage * pct)))
			player_stats_changed.emit()
		item["count"] -= 1
		if item["count"] <= 0:
			inventory.remove_at(index)
		inventory_changed.emit()
	elif item_type == "weapon":
		var slot_keep: int = int(item.get("bag_slot", index))
		var old_weapon: Dictionary = {
			"id": equipped_weapon_id,
			"name": equipped_weapon_name,
			"type": "weapon",
			"bonus": equipped_weapon_bonus,
			"rarity": equipped_weapon_rarity,
			"desc": "+%d к урону оружия" % equipped_weapon_bonus,
			"count": 1,
			"bag_slot": slot_keep,
		}
		equipped_weapon_id = String(item.get("id", "custom_weapon"))
		equipped_weapon_name = item["name"]
		equipped_weapon_bonus = int(item["bonus"])
		equipped_weapon_rarity = item.get("rarity", "common")
		inventory.remove_at(index)
		if old_weapon["bonus"] >= 0:
			inventory.insert(index, old_weapon)
		AudioManager.play("ui_click")
		add_combat_log("Вы экипировали оружие: [%s] (+%d к урону)." % [equipped_weapon_name, equipped_weapon_bonus], COLOR_LOG_SYSTEM)
		player_stats_changed.emit()
		equipment_changed.emit()
		inventory_changed.emit()
	elif item_type == "armor":
		var slot_keep_a: int = int(item.get("bag_slot", index))
		var old_armor: Dictionary = {
			"id": equipped_armor_id,
			"name": equipped_armor_name,
			"type": "armor",
			"bonus": equipped_armor_hp_bonus,
			"rarity": equipped_armor_rarity,
			"desc": "+%d к макс. здоровью" % equipped_armor_hp_bonus,
			"count": 1,
			"bag_slot": slot_keep_a,
		}
		equipped_armor_id = String(item.get("id", "custom_armor"))
		equipped_armor_name = item["name"]
		equipped_armor_hp_bonus = int(item["bonus"])
		equipped_armor_rarity = item.get("rarity", "common")
		inventory.remove_at(index)
		inventory.insert(index, old_armor)
		_recalculate_stats(false)
		hp = mini(max_hp, hp)
		AudioManager.play("ui_click")
		add_combat_log("Вы надели броню: [%s] (+%d к макс. здоровью)." % [equipped_armor_name, equipped_armor_hp_bonus], COLOR_LOG_SYSTEM)
		player_stats_changed.emit()
		equipment_changed.emit()
		inventory_changed.emit()
	elif item_type == "junk":
		var value: int = int(item.get("value", 8)) * int(item.get("count", 1))
		inventory.remove_at(index)
		add_money(value)
		add_combat_log("Вы сдали трофей «%s» скупщику за %s." % [item["name"], format_money(value)], COLOR_LOG_LOOT)
		inventory_changed.emit()


func sell_all_junk() -> int:
	var total: int = 0
	for i in range(inventory.size() - 1, -1, -1):
		var item: Dictionary = inventory[i]
		if item.get("type", "") == "junk":
			total += int(item.get("value", 8)) * int(item.get("count", 1))
			inventory.remove_at(i)
	if total > 0:
		add_money(total)
		add_combat_log("Вы продали трофеи за %s." % format_money(total), COLOR_LOG_LOOT)
		inventory_changed.emit()
	else:
		add_combat_log("У вас нет трофеев для продажи.", COLOR_LOG_SYSTEM)
	return total


func buy_item(item: Dictionary, price: int) -> bool:
	if money_copper < price:
		AudioManager.play("error")
		add_combat_log("Недостаточно денег (нужно %s)." % format_money(price), COLOR_LOG_ERROR)
		return false
	money_copper -= price
	add_item_to_inventory(item.duplicate(true))
	add_combat_log("Куплено: [%s] за %s." % [item["name"], format_money(price)], COLOR_LOG_LOOT)
	player_stats_changed.emit()
	return true


func save_game() -> bool:
	var pos := Vector3(0.0, 0.1, 10.5)
	var yaw := 0.0
	if is_instance_valid(player_node):
		pos = player_node.global_position
		yaw = player_node.rotation.y
	var quest_save: Dictionary = {}
	for q_id in quest_order:
		var q: Dictionary = quests[q_id]
		var obj_counts: Dictionary = {}
		for ok in q["objectives"].keys():
			obj_counts[ok] = q["objectives"][ok]["current"]
		quest_save[q_id] = {"state": q["state"], "objectives": obj_counts}

	var data: Dictionary = {
		"player_class": player_class,
		"level": level,
		"xp": xp,
		"xp_to_next": xp_to_next,
		"hp": hp,
		"rage": rage,
		"money_copper": money_copper,
		"mining_skill": mining_skill,
		"herbalism_skill": herbalism_skill,
		"talent_points": talent_points,
		"talents": talents,
		"equipped_weapon_id": equipped_weapon_id,
		"equipped_weapon_name": equipped_weapon_name,
		"equipped_weapon_bonus": equipped_weapon_bonus,
		"equipped_weapon_rarity": equipped_weapon_rarity,
		"equipped_armor_id": equipped_armor_id,
		"equipped_armor_name": equipped_armor_name,
		"equipped_armor_hp_bonus": equipped_armor_hp_bonus,
		"equipped_armor_rarity": equipped_armor_rarity,
		"inventory": inventory,
		"quests": quest_save,
		"pos": [pos.x, pos.y, pos.z],
		"yaw": yaw,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	AudioManager.play("quest_accept")
	add_combat_log("Игра сохранена (Ур. %d, %s)." % [level, player_class_name], COLOR_LOG_SYSTEM)
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func get_save_summary() -> String:
	if not has_save():
		return ""
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return ""
	var d: Dictionary = parsed
	var cls: String = String(d.get("player_class", "warrior"))
	var cls_label: String = "Воин"
	if cls == "mage":
		cls_label = "Маг"
	elif cls == "rogue":
		cls_label = "Разбойник"
	elif cls == "hunter":
		cls_label = "Охотник"
	return "%s, Ур. %d" % [cls_label, int(d.get("level", 1))]


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return false
	var d: Dictionary = parsed

	reset_for_new_game(String(d.get("player_class", "warrior")))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	xp_to_next = int(d.get("xp_to_next", 100))
	money_copper = int(d.get("money_copper", 30))
	mining_skill = int(d.get("mining_skill", 1))
	herbalism_skill = int(d.get("herbalism_skill", 1))
	talent_points = int(d.get("talent_points", 0))
	if d.get("talents") is Dictionary:
		talents = (d["talents"] as Dictionary).duplicate(true)

	equipped_weapon_id = String(d.get("equipped_weapon_id", equipped_weapon_id))
	equipped_weapon_name = String(d.get("equipped_weapon_name", equipped_weapon_name))
	equipped_weapon_bonus = int(d.get("equipped_weapon_bonus", 0))
	equipped_weapon_rarity = String(d.get("equipped_weapon_rarity", "common"))
	equipped_armor_id = String(d.get("equipped_armor_id", equipped_armor_id))
	equipped_armor_name = String(d.get("equipped_armor_name", equipped_armor_name))
	equipped_armor_hp_bonus = int(d.get("equipped_armor_hp_bonus", 0))
	equipped_armor_rarity = String(d.get("equipped_armor_rarity", "common"))

	if d.get("inventory") is Array:
		inventory.clear()
		for it in d["inventory"]:
			if it is Dictionary:
				inventory.append((it as Dictionary).duplicate(true))
	_normalize_bag_slots()

	if d.get("quests") is Dictionary:
		var qd: Dictionary = d["quests"]
		for q_id in quest_order:
			if qd.has(q_id) and quests.has(q_id):
				var sq: Dictionary = qd[q_id]
				quests[q_id]["state"] = String(sq.get("state", quests[q_id]["state"]))
				var sobj: Dictionary = sq.get("objectives", {})
				for ok in sobj.keys():
					if quests[q_id]["objectives"].has(ok):
						quests[q_id]["objectives"][ok]["current"] = int(sobj[ok])

	_recalculate_stats(false)
	hp = clampi(int(d.get("hp", max_hp)), 1, max_hp)
	rage = clampi(int(d.get("rage", 0)), 0, max_rage)

	var p_arr: Variant = d.get("pos")
	if p_arr is Array and (p_arr as Array).size() == 3:
		var pa: Array = p_arr
		pending_load_pos = Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
		pending_load_yaw = float(d.get("yaw", 0.0))
		has_pending_load_transform = true

	player_stats_changed.emit()
	equipment_changed.emit()
	quest_updated.emit()
	inventory_changed.emit()
	talents_changed.emit()
	return true


func add_combat_log(text: String, color: Color = Color.WHITE) -> void:
	combat_log_added.emit(text, color)
