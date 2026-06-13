extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var player: CharacterBody3D = $Player
@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var interact_prompt: Label = $CanvasLayer/UI/InteractPrompt
@onready var dungeon_entrance: Area3D = $DungeonEntrance

var _near_house: Area3D = null

## 平台配置：[节点名, mesh_size(Vector3), col_shape_size(Vector3)]
const PLATFORM_CONFIGS: Array = [
	["Ground",     Vector3(50, 1, 30),   Vector3(50, 1, 30)],
	["PlatformLow", Vector3(8, 0.6, 5),   Vector3(8, 0.6, 5)],
	["PlatformMid", Vector3(10, 0.6, 5),  Vector3(10, 0.6, 5)],
	["PlatformHigh", Vector3(8, 0.6, 5),  Vector3(8, 0.6, 5)],
	["PlatformRoad", Vector3(35, 0.6, 6),  Vector3(35, 0.6, 6)],
	["PlatformConnect1", Vector3(4, 0.6, 4), Vector3(4, 0.6, 4)],
	["PlatformConnect2", Vector3(4, 0.6, 4), Vector3(4, 0.6, 4)],
]

const TREE_CONFIGS: Array = [
	["Tree1", Vector3(2, 6, 2), Vector3(2, 6, 2)],
	["Tree2", Vector3(2, 6, 2), Vector3(2, 6, 2)],
	["Tree3", Vector3(2, 6, 2), Vector3(2, 6, 2)],
]

const HOUSE_CONFIGS: Array = [
	["HouseLow",  Vector3(3, 4, 3)],
	["HouseMid",  Vector3(3, 4, 3)],
	["HouseHigh", Vector3(3, 4, 3)],
]

func _ready() -> void:
	camera.make_current()
	get_tree().paused = false
	_setup_platforms()
	_setup_trees()
	_setup_houses()
	_setup_dungeon_entrance()
	_connect_signals()


func _setup_platforms() -> void:
	for cfg in PLATFORM_CONFIGS:
		var node_name: String = cfg[0]
		var mesh_size: Vector3 = cfg[1]
		var col_size: Vector3 = cfg[2]
		var node := get_node_or_null(node_name)
		if not node:
			continue
		## 添加可视化网格
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		mesh.mesh = _box_mesh(mesh_size)
		node.add_child(mesh)
		## 添加碰撞体
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = _box_shape(col_size)
		node.add_child(col)


func _setup_trees() -> void:
	for cfg in TREE_CONFIGS:
		var node_name: String = cfg[0]
		var mesh_size: Vector3 = cfg[1]
		var col_size: Vector3 = cfg[2]
		var node := get_node_or_null(node_name)
		if not node:
			continue
		var mesh := MeshInstance3D.new()
		mesh.name = "Mesh"
		mesh.mesh = _box_mesh(mesh_size)
		node.add_child(mesh)
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = _box_shape(col_size)
		node.add_child(col)


func _setup_houses() -> void:
	for cfg in HOUSE_CONFIGS:
		var node_name: String = cfg[0]
		var col_size: Vector3 = cfg[1]
		var node := get_node_or_null(node_name)
		if not node:
			continue
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = _box_shape(col_size)
		node.add_child(col)


func _setup_dungeon_entrance() -> void:
	if not dungeon_entrance:
		return
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = _box_mesh(Vector3(4, 5, 3))
	dungeon_entrance.add_child(mesh)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = _box_shape(Vector3(4, 5, 3))
	dungeon_entrance.add_child(col)


func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s


func _connect_signals() -> void:
	if pause_menu:
		pause_menu.game_started = true
		if not pause_menu.resume_game.is_connected(_on_resume):
			pause_menu.resume_game.connect(_on_resume)
		if not pause_menu.quit_to_menu.is_connected(_on_quit_to_menu):
			pause_menu.quit_to_menu.connect(_on_quit_to_menu)

	if interact_prompt:
		interact_prompt.visible = false

	for child in get_children():
		if child is Area3D and child.name.begins_with("House"):
			if not child.body_entered.is_connected(_on_house_entered):
				child.body_entered.connect(_on_house_entered.bind(child))
			if not child.body_exited.is_connected(_on_house_exited):
				child.body_exited.connect(_on_house_exited.bind(child))

	if dungeon_entrance:
		if not dungeon_entrance.body_entered.is_connected(_on_dungeon_entered):
			dungeon_entrance.body_entered.connect(_on_dungeon_entered)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_menu:
			pause_menu.toggle_pause()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_accept"):
		_try_interact()


func _try_interact() -> void:
	if not player:
		return
	var ia: Area3D = player.get_node_or_null("Interaction")
	if not ia:
		return
	for body in ia.get_overlapping_bodies():
		if body.has_method("interact"):
			body.interact(player)


func _on_house_entered(body: Node3D, house: Area3D) -> void:
	if body.is_in_group("player"):
		_near_house = house
		if interact_prompt:
			interact_prompt.visible = true


func _on_house_exited(_body: Node3D, _house: Area3D) -> void:
	_near_house = null
	if interact_prompt:
		interact_prompt.visible = false


func _on_dungeon_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var gm := get_node_or_null("/root/GameManager")
		if gm:
			gm.skip_menu = true
		get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_resume() -> void:
	if pause_menu:
		pause_menu.hide_menu()


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
