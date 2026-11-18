class_name InteractableProp
extends StaticBody3D

@export var prop_id: String = "supply_crate"
@export var prop_title: String = "Ящик припасов"
@export var sub_kind: String = ""
@export var respawn_delay: float = 22.0

var visual_root: Node3D = null
var sparkle_mesh: MeshInstance3D = null
var label_3d: Label3D = null
var col_shape: CollisionShape3D = null

var is_available: bool = true
var respawn_timer: float = 0.0
var anim_time: float = 0.0


func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 2
	collision_mask = 1
	anim_time = randf() * 5.0

	col_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.25, 1.1, 1.25)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.55, 0)
	add_child(col_shape)

	_build_visual()


func _build_visual() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)

	if prop_id == "ore_vein":
		var is_cryst: bool = (sub_kind == "azure_crystal")
		visual_root.add_child(RetroModelBuilder.build_ore_vein(is_cryst))
		sparkle_mesh = null
	elif prop_id == "herb_node":
		visual_root.add_child(RetroModelBuilder.build_herb_cluster(sub_kind))
		sparkle_mesh = null
	else:
		var mat_wood := RetroModelBuilder.make_retro_material(Color(0.52, 0.36, 0.18), 0.88, 0.02)
		var mat_gold := RetroModelBuilder.make_retro_material(Color(0.86, 0.70, 0.24), 0.45, 0.55)
		var mat_dark := RetroModelBuilder.make_retro_material(Color(0.28, 0.18, 0.09), 0.90, 0.1)

		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.1, 0.82, 0.86) if prop_id == "mine_chest" else Vector3(1.0, 0.9, 1.0)
		body.mesh = bm
		body.material_override = mat_dark if prop_id == "mine_chest" else mat_wood
		body.position = Vector3(0, bm.size.y * 0.5, 0)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		visual_root.add_child(body)

		var trim := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(bm.size.x + 0.06, 0.14, bm.size.z + 0.06)
		trim.mesh = tm
		trim.material_override = mat_gold
		trim.position = Vector3(0, bm.size.y * 0.75, 0)
		visual_root.add_child(trim)

		sparkle_mesh = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.24
		cyl.height = 1.1
		cyl.radial_segments = 6
		sparkle_mesh.mesh = cyl
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(1.0, 0.86, 0.28, 0.68)
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.emission_enabled = true
		smat.emission = Color(1.0, 0.82, 0.22)
		smat.emission_energy_multiplier = 2.4
		sparkle_mesh.material_override = smat
		sparkle_mesh.position = Vector3(0, 1.25, 0)
		visual_root.add_child(sparkle_mesh)

	label_3d = Label3D.new()
	label_3d.text = prop_title
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.fixed_size = true
	label_3d.pixel_size = 0.00055
	label_3d.font_size = 28
	label_3d.outline_size = 7
	label_3d.modulate = Color(0.55, 0.90, 1.0) if prop_id == "ore_vein" else (Color(0.55, 1.0, 0.55) if prop_id == "herb_node" else Color(1.0, 0.88, 0.35))
	label_3d.visibility_range_end = 26.0
	label_3d.position = Vector3(0, 1.45 if prop_id in ["ore_vein", "herb_node"] else 1.85, 0)
	visual_root.add_child(label_3d)


func _process(delta: float) -> void:
	anim_time += delta
	if not is_available:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			is_available = true
			visual_root.visible = true
			col_shape.disabled = false
	elif sparkle_mesh:
		sparkle_mesh.rotation.y += delta * 2.2
		sparkle_mesh.position.y = 1.25 + sin(anim_time * 3.5) * 0.10


func interact() -> void:
	if not is_available or GameState.is_dead:
		return

	if prop_id == "ore_vein" or prop_id == "herb_node":
		var p: Node3D = GameState.player_node
		if is_instance_valid(p) and p.has_method("start_gather_cast"):
			p.call("start_gather_cast", self)
		else:
			complete_gather()
		return

	if prop_id == "supply_crate":
		var q: Dictionary = GameState.quests.get("stolen_supplies", {})
		if q.get("state", "") != "active":
			GameState.add_combat_log("Это %s. Возьмите задание «Краденые припасы» у Капитана Маркуса." % prop_title, GameState.COLOR_LOG_SYSTEM)
			return
		is_available = false
		respawn_timer = respawn_delay
		visual_root.visible = false
		col_shape.disabled = true
		AudioManager.play("loot")
		GameState.floating_text_requested.emit(global_position + Vector3(0, 1.5, 0), "+1 припасы", Color(1.0, 0.88, 0.35), false)
		GameState.register_quest_progress("supply_crate")
	elif prop_id == "mine_chest":
		is_available = false
		respawn_timer = 45.0
		visual_root.visible = false
		col_shape.disabled = true
		var copper: int = randi_range(65, 110)
		GameState.add_combat_log("Вы открыли [%s]!" % prop_title, GameState.COLOR_LOG_SYSTEM)
		GameState.add_money(copper)
		GameState.add_item_to_inventory({
			"id": "lesser_healing_potion",
			"name": "Добротное лечебное зелье",
			"type": "potion",
			"bonus": 95,
			"rarity": "uncommon",
			"desc": "Восстанавливает 95 ед. здоровья",
			"count": 1,
		})
		if GameState.player_class in ["mage", "hunter"]:
			GameState.add_item_to_inventory({
				"id": "minor_mana_potion",
				"name": "Малое зелье маны",
				"type": "mana_potion",
				"bonus": 55,
				"rarity": "common",
				"desc": "Восстанавливает 55 ед. маны",
				"count": 1,
			})


func complete_gather() -> void:
	if not is_available:
		return
	is_available = false
	respawn_timer = 32.0 if prop_id == "ore_vein" else 28.0
	visual_root.visible = false
	col_shape.disabled = true
	AudioManager.play("loot")
	GameState.floating_text_requested.emit(global_position + Vector3(0, 1.35, 0), "+1 %s" % prop_title, Color(0.55, 0.95, 1.0) if prop_id == "ore_vein" else Color(0.55, 1.0, 0.55), false)
	GameState.register_gather(sub_kind)
