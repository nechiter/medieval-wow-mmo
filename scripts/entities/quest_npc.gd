class_name QuestNPC
extends StaticBody3D

@export var npc_name: String = "Капитан Маркус"
@export var npc_title: String = "Командир заставы"

var rig_node: Node3D = null
var nameplate: Label3D = null
var quest_marker: Label3D = null
var anim_time: float = 0.0
var base_yaw: float = 0.0


func _ready() -> void:
	add_to_group("npcs")
	collision_layer = 2
	collision_mask = 1
	base_yaw = rotation.y

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 2.0
	col.shape = cap
	col.position = Vector3(0, 1.0, 0)
	add_child(col)

	rig_node = RetroModelBuilder.build_humanoid({
		"scale": 1.08,
		"archetype": "guard",
		"armor_color": Color(0.24, 0.34, 0.56),
		"accent_color": Color(0.84, 0.68, 0.24),
		"skin_color": Color(0.86, 0.69, 0.55),
		"pants_color": Color(0.20, 0.22, 0.28),
		"cape_color": Color(0.14, 0.28, 0.62),
		"eye_color": Color(0.15, 0.25, 0.45),
		"weapon_type": "shortsword",
		"has_cape": true,
		"has_shield": true,
	})
	add_child(rig_node)

	nameplate = Label3D.new()
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.pixel_size = 0.0085
	nameplate.font_size = 34
	nameplate.outline_size = 8
	nameplate.outline_modulate = Color(0.03, 0.08, 0.03, 0.95)
	nameplate.modulate = Color(0.36, 0.96, 0.42)
	nameplate.text = "<%s>\n%s" % [npc_title, npc_name]
	nameplate.position = Vector3(0, 2.45, 0)
	add_child(nameplate)

	quest_marker = Label3D.new()
	quest_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	quest_marker.pixel_size = 0.015
	quest_marker.font_size = 64
	quest_marker.outline_size = 12
	quest_marker.outline_modulate = Color(0.10, 0.06, 0.02, 0.98)
	quest_marker.position = Vector3(0, 3.15, 0)
	add_child(quest_marker)

	GameState.quest_updated.connect(_refresh_quest_marker)
	_refresh_quest_marker()


func _process(delta: float) -> void:
	anim_time += delta
	if rig_node:
		RetroModelBuilder.animate_humanoid(rig_node, "IDLE", anim_time)
	if quest_marker and quest_marker.visible:
		quest_marker.position.y = 3.15 + sin(anim_time * 3.2) * 0.12

	var player: Node3D = GameState.player_node
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= 6.5:
		var to_p: Vector3 = player.global_position - global_position
		to_p.y = 0.0
		if to_p.length_squared() > 0.01:
			var target_yaw: float = atan2(-to_p.x, -to_p.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 5.0))
	else:
		rotation.y = lerp_angle(rotation.y, base_yaw, minf(1.0, delta * 3.0))


func _refresh_quest_marker() -> void:
	if quest_marker == null:
		return
	var status: Dictionary = GameState.get_npc_quest_status()
	var marker: String = String(status.get("marker", ""))
	if marker == "":
		quest_marker.visible = false
	else:
		quest_marker.visible = true
		quest_marker.text = marker
		quest_marker.modulate = status.get("color", Color.YELLOW)


func interact() -> void:
	GameState.npc_dialog_requested.emit(self)
