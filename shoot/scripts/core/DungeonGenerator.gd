## 地牢生成器 — 肉鸽房间布局生成
## 使用 BSP / 随机游走算法生成房间连接图
class_name DungeonGenerator
extends Node3D

signal generation_finished(rooms: Array[Room])
signal first_room_ready(room: Room)

const RoomScene: PackedScene = preload("res://scenes/rooms/RoomTemplate.tscn")

@export var room_size: Vector3 = Vector3(640, 0, 640)
@export var grid_width: int = 5
@export var grid_height: int = 5
@export var max_rooms: int = 12
@export var min_rooms: int = 6
@export var seed_value: int = -1

## 房间模板列表（在编辑器中指定）
@export var room_templates: Array[PackedScene] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rooms: Array[Dictionary] = []  ## [{id, grid_pos, scene, connections}]
var _room_nodes: Array[Room] = []


func _ready() -> void:
	## 由 Main.gd 显式调用 generate()，避免信号竞争
	pass


func generate() -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

	_rooms.clear()
	_room_nodes.clear()

	## 步骤1：生成房间图（随机游走）
	_generate_room_graph()
	
	## 步骤1.5：标记Boss房（最远的死路房间）
	_mark_boss_room()
	
	## 步骤2：实例化房间场景
	_instantiate_rooms()

	## 步骤3：连接房间（开门方向）
	_connect_rooms()

	generation_finished.emit(_room_nodes)

	if _room_nodes.size() > 0:
		first_room_ready.emit(_room_nodes[0])


func _generate_room_graph() -> void:
	## 从中心开始随机游走
	var center := Vector2i(grid_width / 2, grid_height / 2)
	var visited: Dictionary = {}
	var stack: Array[Vector2i] = [center]
	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	visited[center] = true
	_rooms.append({id = 0, grid_pos = center, connections = []})

	var room_count := _rng.randi_range(min_rooms, max_rooms)
	var idx := 1

	while idx < room_count and stack.size() > 0:
		var current := stack[_rng.randi_range(0, stack.size() - 1)]
		var shuffled_dirs := dirs.duplicate()
		shuffled_dirs.shuffle()

		for dir in shuffled_dirs:
			var next: Vector2i = current + dir
			if next.x < 0 or next.x >= grid_width or next.y < 0 or next.y >= grid_height:
				continue
			if visited.has(next):
				## 已访问，记录连接（用于环路）
				var existing := _find_room_by_pos(next)
				var current_room := _find_room_by_pos(current)
				if existing >= 0 and current_room >= 0:
					if not _rooms[existing].connections.has(_rooms[current_room].id):
						_rooms[existing].connections.append(_rooms[current_room].id)
						_rooms[current_room].connections.append(_rooms[existing].id)
				continue

			visited[next] = true
			stack.append(next)
			_rooms.append({id = idx, grid_pos = next, connections = [_rooms[_rooms.size()-1].id]})
			_rooms[_rooms.size()-2].connections.append(idx)
			idx += 1
			break

	## 保证连通性（如果没有生成足够房间，从已有房间扩展）
	if _rooms.size() < min_rooms:
		push_warning("DungeonGenerator: Not enough rooms generated, consider increasing grid size.")


func _find_room_by_pos(pos: Vector2i) -> int:
	for i in _rooms.size():
		if _rooms[i].grid_pos == pos:
			return i
	return -1


## 标记Boss房：最远的死路房间（只连一个房间）
func _mark_boss_room() -> void:
	## 1. 找出所有死路房间（只有1个连接）
	var dead_ends: Array[int] = []
	for i in _rooms.size():
		if _rooms[i].connections.size() == 1:
			dead_ends.append(i)
	
	if dead_ends.size() == 0:
		return
	
	## 2. 计算死路房间到起点(0)的距离，按距离排序
	var distances: Array = []
	for i in dead_ends:
		var pos: Vector2i = _rooms[i].grid_pos
		var start_pos: Vector2i = _rooms[0].grid_pos
		var dist: int = abs(pos.x - start_pos.x) + abs(pos.y - start_pos.y)
		distances.append({"index": i, "dist": dist})
	
	distances.sort_custom(func(a, b): return a.dist > b.dist)
	
	## 3. 选最远或第二远的作为Boss房（50%概率选最远）
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var boss_idx: int
	if rng.randf() < 0.5 and dead_ends.size() >= 2:
		boss_idx = distances[1].index  ## 第二远
	else:
		boss_idx = distances[0].index  ## 最远
	
	## 3. 设置Boss房类型（先清除其他可能的Boss房标记）
	for i in _rooms.size():
		if _rooms[i].has("room_type") and _rooms[i]["room_type"] == Room.RoomType.BOSS:
			_rooms[i].erase("room_type")  ## 清除之前的Boss房标记
	
	_rooms[boss_idx]["room_type"] = Room.RoomType.BOSS


func _instantiate_rooms() -> void:
	for room_data in _rooms:
		var room_scene: PackedScene = _get_random_room_template()
		if not room_scene:
			push_error("DungeonGenerator: No room template assigned!")
			return

		var room: Room = room_scene.instantiate() as Room
		if not room:
			continue

		room.room_id = "room_%d" % room_data.id
		room.global_position = Vector3(room_data.grid_pos.x, 0, room_data.grid_pos.y) * room_size
		add_child(room)
		_room_nodes.append(room)

		## 应用房间类型（Boss房等）
		if room_data.has("room_type"):
			room.room_type = room_data["room_type"]

		## 连接房间清空信号
		room.room_cleared.connect(_on_room_cleared.bind(room))


func _get_random_room_template() -> PackedScene:
	if room_templates.size() == 0:
		return RoomScene
	return room_templates[_rng.randi_range(0, room_templates.size() - 1)]


func _connect_rooms() -> void:
	## 根据 connections 设置门的状态
	for room_data in _rooms:
		var room: Room = _get_room_node_by_id(room_data.id)
		if not room or not room.has_node("Doors"):
			continue

		var doors: Node3D = room.get_node("Doors")
		## 默认关闭所有门，只打开有连接的
		for door in doors.get_children():
			if door.has_method("close"):
				door.close()

		for connected_id in room_data.connections:
			_open_door_between(room, _get_room_node_by_id(connected_id))


func _open_door_between(room_a: Room, room_b: Room) -> void:
	if not room_a or not room_b:
		return
	## 根据相对位置确定 room_a -> room_b 的门方向
	var delta: Vector3 = (room_b.global_position - room_a.global_position).normalized()
	var dir_a := ""
	if abs(delta.x) > abs(delta.z):
		dir_a = "East" if delta.x > 0 else "West"
	else:
		dir_a = "South" if delta.z > 0 else "North"
	
	## 打开 room_a 的门
	if room_a.has_node("Doors/" + dir_a):
		var door_a = room_a.get_node("Doors/" + dir_a)
		if door_a.has_method("open"):
			door_a.open()
	
	## 反向：确定 room_b -> room_a 的门方向
	var dir_b := ""
	match dir_a:
		"North": dir_b = "South"
		"South": dir_b = "North"
		"East": dir_b = "West"
		"West": dir_b = "East"
	
	## 打开 room_b 的门（精确匹配门名）
	if room_b.has_node("Doors/" + dir_b):
		var door_b = room_b.get_node("Doors/" + dir_b)
		if door_b.has_method("open"):
			door_b.open()
	else:
		## 模糊匹配：找以 dir_b 开头的门（如"NorthDoor1"）
		var doors_node = room_b.get_node_or_null("Doors")
		if doors_node:
			for door in doors_node.get_children():
				if door.name.begins_with(dir_b):
					if door.has_method("open"):
						door.open()
					break


func _get_room_node_by_id(id: int) -> Room:
	for room in _room_nodes:
		if room.room_id == "room_%d" % id:
			return room
	return null


func _on_room_cleared(room: Room) -> void:
	## 可扩展：全局房间清空计数、Boss房解锁等
	pass


func get_rooms() -> Array[Room]:
	return _room_nodes


func get_start_room() -> Room:
	if _room_nodes.size() > 0:
		return _room_nodes[0]
	return null
