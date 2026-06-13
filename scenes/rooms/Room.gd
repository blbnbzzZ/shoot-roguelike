## Room controller - 3D version
class_name Room
extends Node3D

@export var room_size: Vector3 = Vector3(640, 1, 840)
@export var room_type: int = 0  # RoomType.NORMAL
@export var room_id: String = ""
@export var enemy_count: int = 3

signal room_cleared
signal player_left_room(exit_dir: int, target_room_index: int, entry_door_name: String)
signal boss_spawned(boss: Node)
signal boss_died()
signal next_floor_hole_spawned(hole: Node3D)
signal slime_killed(drops: Dictionary)

## Floor number (set by Main.gd)
var floor_number: int = 1
## Layer number 1-3 (set by Main.gd, determines enemy types)
var layer_number: int = 1
var _slimes_spawned: bool = false
var show_help_text: bool = false

## Neighbor room indices: door_name -> room_index
var neighbor_indices: Dictionary = {}
## Neighbor room types: door_name -> room_type
var neighbor_types: Dictionary = {}

enum EntryDir { SOUTH, NORTH, EAST, WEST }
enum RoomType { NORMAL, SAFE, REWARD, SHOP, BOSS, LARGE, HUGE }

## Exit direction to entry direction mapping
const EXIT_TO_ENTRY: Dictionary = {
	EntryDir.NORTH: EntryDir.SOUTH,
	EntryDir.SOUTH: EntryDir.NORTH,
	EntryDir.EAST:  EntryDir.WEST,
	EntryDir.WEST:  EntryDir.EAST,
}

## Current entry direction (set by Main.gd)
var entry_direction: int = EntryDir.SOUTH
## Current entry door name (for large room spawn positioning)
var entry_door_name: String = ""

var _wall_material: StandardMaterial3D = null

var ENEMY_SCENE: PackedScene = load("res://scenes/enemies/layer1/EnemyBase.tscn")
var STRAWBERRY_SCENE: PackedScene = load("res://scenes/enemies/layer1/Strawberry.tscn")
var ZAPRAT_SCENE: PackedScene = load("res://scenes/enemies/layer1/ZapRat.tscn")
var GURUGURU_SCENE: PackedScene = load("res://scenes/enemies/layer1/Guruguru.tscn")
var BIG_EYE_BOSS_SCENE: PackedScene = load("res://scenes/enemies/layer1/BigEyeBoss.tscn")
var WORM_BOSS_SCENE: PackedScene = load("res://scenes/enemies/layer1/WormBoss.tscn")
var SLIME_KING_BOSS_SCENE: PackedScene = load("res://scenes/enemies/layer1/SlimeKingBoss.tscn")
var SLIME_SCENE: PackedScene = load("res://scenes/enemies/layer1/Slime.tscn")
var ZIZI_SCENE: PackedScene = load("res://scenes/enemies/layer1/Zizi.tscn")

## Door node cache: door_name -> Area3D
var _door_nodes: Dictionary = {}
## Door blocker cache: door_name -> StaticBody3D
var _door_blockers: Dictionary = {}
## Bullet wall cache (one per door, blocks bullets not players)
var _bullet_walls: Dictionary = {}
var _cleared: bool = false
var _enemies_alive: int = 0
var _doors_opened: bool = false
var _player_inside: bool = false

@onready var player_detector: Area3D = $PlayerDetector
@onready var room_visuals: Node3D = $RoomVisuals
@onready var doors_container: Node3D = $Doors
@onready var enemies_container: Node3D = $Enemies
@onready var pickups_container: Node3D = $Pickups
@onready var floor_hole: Node3D = $FloorHole
@onready var next_floor_label: Label3D = $NextFloorLabel
@onready var boss_health_bar_node: Node3D = $BossHealthBar

## Normal room (640x640): N(z=10->60) S(z=630->580) E(x=630->580) W(x=10->60)
const ENTRY_POSITIONS: Dictionary = {
	EntryDir.SOUTH: Vector3(320, 1, 580),
	EntryDir.NORTH: Vector3(320, 1, 60),
	EntryDir.EAST:  Vector3(580, 1, 320),
	EntryDir.WEST:  Vector3(60, 1, 320),
}

## Get local spawn position (avoid accessing global_position before add_child)
func get_spawn_local_position() -> Vector3:
	if entry_door_name != "":
		if room_type == RoomType.LARGE:
			var large_door_positions := {
				"NorthDoor1": Vector3(320, 1, 120),
				"NorthDoor2": Vector3(960, 1, 120),
				"SouthDoor1": Vector3(320, 1, 520),
				"SouthDoor2": Vector3(960, 1, 520),
				"EastDoor":   Vector3(1160, 1, 320),
				"WestDoor":   Vector3(120, 1, 320),
			}
			if large_door_positions.has(entry_door_name):
				return large_door_positions[entry_door_name]
			for key in large_door_positions.keys():
				if key.begins_with(entry_door_name):
					return large_door_positions[key]
		elif room_type == RoomType.HUGE:
			var huge_door_positions := {
				"NorthDoor1": Vector3(320, 1, 120),
				"NorthDoor2": Vector3(960, 1, 120),
				"SouthDoor1": Vector3(320, 1, 1160),
				"SouthDoor2": Vector3(960, 1, 1160),
				"EastDoor1":  Vector3(1160, 1, 320),
				"EastDoor2":  Vector3(1160, 1, 960),
				"WestDoor1":  Vector3(120, 1, 320),
				"WestDoor2":  Vector3(120, 1, 960),
			}
			if huge_door_positions.has(entry_door_name):
				return huge_door_positions[entry_door_name]
			for key in huge_door_positions.keys():
				if key.begins_with(entry_door_name):
					return huge_door_positions[key]
	var pos := ENTRY_POSITIONS.get(entry_direction, Vector3(320, 1, 420))
	if entry_direction == EntryDir.NORTH and pos.z < 120:
		pos.z = 120
	elif entry_direction == EntryDir.SOUTH and pos.z > room_size.z - 120:
		pos.z = room_size.z - 120
	elif entry_direction == EntryDir.EAST and pos.x > room_size.x - 120:
		pos.x = room_size.x - 120
	elif entry_direction == EntryDir.WEST and pos.x < 120:
		pos.x = 120
	return pos


func _ready() -> void:
	player_detector.body_entered.connect(_on_player_enter)
	_doors_active(false)
	_update_door_visibility()
	if room_type == RoomType.SAFE or enemy_count == 0:
		_cleared = true
	visibility_changed.connect(_on_visibility_changed)
	var reconcile_timer: Timer = Timer.new()
	reconcile_timer.name = "ReconcileTimer"
	reconcile_timer.wait_time = 1.0
	reconcile_timer.one_shot = false
	reconcile_timer.timeout.connect(_reconcile_enemy_count)
	add_child(reconcile_timer)
	reconcile_timer.start()
	_apply_room_type()
	_create_bullet_walls()


func set_neighbor_indices(indices: Dictionary) -> void:
	neighbor_indices = indices


func set_neighbor_types(types: Dictionary) -> void:
	neighbor_types = types


func _on_visibility_changed() -> void:
	if visible and not _doors_opened and _cleared:
		_doors_active(true)
		_doors_opened = true


func _apply_room_type() -> void:
	match room_type:
		RoomType.BOSS:
			if floor_hole:
				floor_hole.visible = false
			if next_floor_label:
				next_floor_label.visible = false
		RoomType.SAFE:
			if floor_hole:
				floor_hole.visible = true
			if next_floor_label:
				next_floor_label.visible = true
		RoomType.REWARD:
			_spawn_reward_pickup()
		_:


func _create_bullet_walls() -> void:
	var door_names := _get_all_door_names()
	for door_name in door_names:
		var wall := StaticBody3D.new()
		wall.name = "BulletWall_" + door_name
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(4, 20, 100)
		collision.shape = shape
		wall.add_child(collision)
		var collision_layer_orig: int = wall.collision_layer
		var collision_mask_orig: int = wall.collision_mask
		wall.collision_layer = 0
		wall.collision_mask = 0
		add_child(wall)
		_bullet_walls[door_name] = wall
		_position_bullet_wall_at_door(door_name, wall)


func _position_bullet_wall_at_door(door_name: String, wall: StaticBody3D) -> void:
	var door_pos := _get_door_world_position(door_name)
	if door_pos == Vector3.ZERO:
		return
	var normal := Vector3.ZERO
	if "North" in door_name:
		normal = Vector3.FORWARD
		z = 10
	elif "South" in door_name:
		normal = Vector3.BACK
		z = room_size.z - 10
	elif "East" in door_name:
		normal = Vector3.RIGHT
		x = room_size.x - 10
	elif "West" in door_name:
		normal = Vector3.LEFT
		x = 10
	else:
		return
	wall.global_position = door_pos + normal * 2.0
	if "North" in door_name or "South" in door_name:
		wall.rotation.y = PI / 2
	call_deferred("_enable_bullet_wall_collision", wall, door_name)


func _enable_bullet_wall_collision(wall: StaticBody3D, door_name: String) -> void:
	if not is_instance_valid(wall) or not is_inside_tree():
		return
	wall.collision_layer = 4
	wall.collision_mask = 0


func _disable_all_bullet_walls() -> void:
	for wall in _bullet_walls.values():
		if is_instance_valid(wall):
			wall.collision_layer = 0
			wall.collision_mask = 0


func _get_door_world_position(door_name: String) -> Vector3:
	var door_node: Area3D = _door_nodes.get(door_name)
	if door_node and is_instance_valid(door_node):
		return door_node.global_position
	return Vector3.ZERO


func _get_all_door_names() -> Array:
	var names := []
	for child in doors_container.get_children():
		if child.is_in_group("door"):
			names.append(child.name)
	return names


func _doors_active(active: bool) -> void:
	for child in doors_container.get_children():
		if child.is_in_group("door"):
			child.set_process(active)
			var collider := child.get_node_or_null("CollisionShape3D") if child.has_node("CollisionShape3D") else null
			if collider:
				collider.disabled = not active
			var sprite := child.get_node_or_null("Sprite3D") if child.has_node("Sprite3D") else null
			if sprite:
				sprite.visible = active


func _update_door_visibility() -> void:
	for child in doors_container.get_children():
		if child.is_in_group("door"):
			if not neighbor_indices.has(child.name):
				child.visible = false
				var collider := child.get_node_or_null("CollisionShape3D") if child.has_node("CollisionShape3D") else null
				if collider:
					collider.disabled = true


func _spawn_enemies() -> void:
	await get_tree().process_frame
	_setup_room_dimensions()
	_enemies_alive = enemy_count
	match room_type:
		RoomType.BOSS:
			_spawn_boss()
		RoomType.LARGE:
			_spawn_large_room_enemies()
		RoomType.HUGE:
			_spawn_huge_room_enemies():
		_:
			_spawn_normal_enemies()
	if _enemies_alive <= 0:
		_on_room_cleared()


func _setup_room_dimensions() -> void:
	pass


func _spawn_normal_enemies() -> void:
	for i in range(enemy_count):
		var scene_to_use := ENEMY_SCENE
		var roll := randf()
		if floor_number >= 4 and floor_number <= 6:
			if roll < 0.25:
				scene_to_use = STRAWBERRY_SCENE
			elif roll < 0.45:
				scene_to_use = ZAPRAT_SCENE
			elif roll < 0.55:
				scene_to_use = GURUGURU_SCENE
		elif floor_number >= 7 and floor_number <= 9:
			if roll < 0.30:
				scene_to_use = STRAWBERRY_SCENE
			elif roll < 0.50:
				scene_to_use = ZAPRAT_SCENE
			elif roll < 0.65:
				scene_to_use = GURUGURU_SCENE
		elif floor_number >= 10:
			if roll < 0.35:
				scene_to_use = STRAWBERRY_SCENE
			elif roll < 0.55:
				scene_to_use = ZAPRAT_SCENE
			elif roll < 0.75:
				scene_to_use = GURUGURU_SCENE
		var enemy := _spawn_single_enemy(scene_to_use)
		if enemy and i == 0 and layer_number == 1 and floor_number in [2, 3]:
			_try_spawn_zizi_as_replacement(enemy)


func _try_spawn_zizi_as_replacement(original_enemy: Node) -> void:
	if randf() > 0.5:
		return
	var zizi := _spawn_single_enemy(ZIZI_SCENE)
	if zizi:
		original_enemy.queue_free()
		_enemies_alive = max(0, _enemies_alive)


func _spawn_large_room_enemies() -> void:
	var count := int(enemy_count * 1.8)
	for i in range(count):
		var roll := randf()
		var scene_to_use := ENEMY_SCENE
		if roll < 0.2:
			scene_to_use = STRAWBERRY_SCENE
		elif roll < 0.35:
			scene_to_use = ZAPRAT_SCENE
		_spawn_single_enemy(scene_to_use)


func _spawn_huge_room_enemies() -> void:
	var count := int(enemy_count * 2.5)
	for i in range(count):
		var roll := randf()
		var scene_to_use := ENEMY_SCENE
		if roll < 0.25:
			scene_to_use = STRAWBERRY_SCENE
		elif roll < 0.4:
			scene_to_use = ZAPRAT_SCENE
		elif roll < 0.5:
			scene_to_use = GURUGURU_SCENE
		_spawn_single_enemy(scene_to_use)


func _spawn_boss() -> void:
	var boss_scene := _get_boss_scene_for_layer()
	if not boss_scene:
		push_warning("No boss scene for layer %d, falling back to SlimeKing" % layer_number)
		boss_scene = SLIME_KING_BOSS_SCENE
	var boss: Node3D = boss_scene.instantiate()
	boss.position = Vector3(room_size.x / 2, 1, room_size.z / 2)
	enemies_container.add_child(boss)
	boss_died.connect(_on_boss_died)
	boss_spawned.emit(boss)
	if boss.has_signal("split"):
		boss.split.connect(_on_worm_split)
	_enemies_alive += 1


static var _used_bosses_layer1: Array[String] = []
static var _tracked_layer: int = 0

func _get_boss_scene_for_layer() -> PackedScene:
	var available_bosses := [
		{"name": "SlimeKing", "scene": SLIME_KING_BOSS_SCENE},
		{"name": "BigEye",    "scene": BIG_EYE_BOSS_SCENE},
		{"name": "Worm",      "scene": WORM_BOSS_SCENE},
	]
	if layer_number == 1:
		if _tracked_layer != layer_number:
			_tracked_layer = layer_number
			_used_bosses_layer1.clear()
		var unused := []
		for b in available_bosses:
			if not b.name in _used_bosses_layer1:
				unused.append(b)
		if unused.is_empty():
			_used_bosses_layer1.clear()
			unused = available_bosses.duplicate()
		var picked := unused[randi() % unused.size()]
		_used_bosses_layer1.append(picked.name)
		return picked.scene
	else:
		return available_bosses[randi() % available_bosses.size()].scene


func _spawn_single_enemy(scene: PackedScene) -> Node:
	if not scene:
		return null
	var enemy: Node3D = scene.instantiate()
	var margin := 80.0
	var x := randf_range(margin, room_size.x - margin)
	var z := randf_range(margin, room_size.z - margin)
	enemy.position = Vector3(x, 1, z)
	enemies_container.add_child(enemy)
	_connect_enemy_signals(enemy)
	return enemy


func _connect_enemy_signals(enemy: Node) -> void:
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	if enemy.has_signal("slime_killed"):
		enemy.slime_killed.connect(func(drops): slime_killed.emit(drops))


func _on_enemy_died(enemy: Node) -> void:
	_enemies_alive = max(0, _enemies_alive - 1)
	if _enemies_alive <= 0:
		_on_room_cleared()


func _on_room_cleared() -> void:
	if _cleared:
		return
	_cleared = true
	room_cleared.emit()
	_disable_all_bullet_walls()
	if room_type == RoomType.BOSS:
		_spawn_next_floor_hole()
	_doors_active(true)
	_doors_opened = true
	if room_type == RoomType.REWARD:
		_spawn_reward_pickup()


func _on_boss_died() -> void:
	pass


func _on_player_enter(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	if not _cleared:
		_spawn_enemies()


func _on_player_exit(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false


func _reconcile_enemy_count() -> void:
	if not visible or not is_inside_tree():
		return
	if enemies_container:
		var actual_count := 0
		for child in enemies_container.get_children():
			if not child.is_queued_for_deletion() and is_instance_valid(child):
				actual_count += 1
		if _enemies_alive != actual_count and actual_count >= 0:
			_enemies_alive = actual_count
			if _enemies_alive <= 0 and not _cleared:
				_on_room_cleared()


func _on_worm_split(new_worms: Array) -> void:
	for worm in new_worms:
		if is_instance_valid(worm) and worm.has_signal("died"):
			worm.died.connect(_on_enemy_died.bind(worm))
			_enemies_alive += 1
			if not worm.is_inside_tree():
				enemies_container.add_child(worm)


func _register_door(door: Area3D) -> void:
	_door_nodes[door.name] = door


func _destroy_door_blockers() -> void:
	for blocker in _door_blockers.values():
		if is_instance_valid(blocker):
			blocker.queue_free()
	_door_blockers.clear()


func _spawn_reward_pickup() -> void:
	if pickups_container.get_child_count() > 0:
		return
	var pickup_type := randi() % 3
	var pickup: Node3D = null
	match pickup_type:
		0:
			pickup = preload("res://scenes/pickups/TripleShotPickup.tscn").instantiate()
		1:
			pickup = preload("res://scenes/pickups/SMGPickup.tscn").instantiate()
		2:
			pickup = preload("res://scenes/pickups/DumDumPickup.tscn").instantiate()
	if pickup:
		pickup.position = Vector3(room_size.x / 2, 1, room_size.z / 2)
		pickups_container.add_child(pickup)


func _spawn_next_floor_hole() -> void:
	if not floor_hole or not is_inside_tree():
		return
	floor_hole.visible = true
	floor_hole.position = Vector3(room_size.x / 2, 0, room_size.z / 2)
	if next_floor_label and floor_hole:
		next_floor_label.position = floor_hole.position + Vector3(0, 3, 0)
		next_floor_label.visible = true
	var hole_body := floor_hole.get_node_or_null("Area3D")
	if hole_body and hole_body.has_signal("body_entered"):
		if not hole_body.is_connected("body_entered", _on_hole_body_entered):
			hole_body.body_entered.connect(_on_hole_body_entered)
	next_floor_hole_spawned.emit(floor_hole)


func _on_hole_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		next_floor_hole_spawned.emit(floor_hole)
