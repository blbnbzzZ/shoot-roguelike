## 主场景控制器 3D 版本 — 多房间地牢
extends Node3D

signal game_started()

const ROOM_SCENE: PackedScene = preload("res://scenes/rooms/RoomTemplate.tscn")
const ROOM_LARGE_SCENE: PackedScene = preload("res://scenes/rooms/RoomTemplateLarge.tscn")
const ROOM_HUGE_SCENE: PackedScene = preload("res://scenes/rooms/RoomTemplateHuge.tscn")

@onready var player: Player = $Player
@onready var camera: Camera3D = $Player/Camera3D
@onready var ui_health: ProgressBar = $CanvasLayer/UI/HealthBar
@onready var ui_coins: Label = $CanvasLayer/UI/CoinLabel
@onready var ui_score: Label = $CanvasLayer/UI/ScoreLabel
@onready var ui_floor: Label = $CanvasLayer/UI/FloorLabel
@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var main_menu = $CanvasLayer/MainMenu
@onready var minimap = $CanvasLayer/Minimap
@onready var death_screen = $CanvasLayer/DeathScreen
@onready var buff_ui = $CanvasLayer/BuffUI
@onready var ui_stamina: ProgressBar = $CanvasLayer/UI/StaminaBar

## 黑色转场
var _transition_rect: ColorRect = null
var _transition_tween: Tween = null
var _hole_transition_active: bool = false  ## 防止地洞转场并发

## Boss血条UI
var ui_boss_health: ProgressBar = null
var _current_boss: Node = null

## 多房间系统
var _rooms: Array[Room] = []
var _room_grid: Dictionary = {}  ## Vector2i -> room_index
var _room_positions: Array[Vector2i] = []
var _room_connections: Array[Array] = []
var _discovered: Array[bool] = []
var _cleared: Array[bool] = []
var _room_types: Array[int] = []
var _room_occupancy: Dictionary = {}  ## room_index -> Array[Vector2i]，记录每个房间占用的网格位置
var _current_room_index: int = 0

var _floor: int = 1
var _score: int = 0
var _coins: int = 0
var _game_over: bool = false
var _changing_room: bool = false

## 多层系统（3大层 × 3层 = 共9层，通关后可选继承重玩）
const TOTAL_FLOORS: int = 9              ## 总层数
const FLOORS_PER_LAYER: int = 3           ## 每大层的层数
var _current_layer: int = 1              ## 当前大层（1-3）
var _game_cleared: bool = false          ## 是否已通关
var _is_new_game_plus: bool = false      ## 继承装备重玩模式（5倍刷怪量）

## 大层配置：房间数、奖励房数、是否在最后一层出Boss
const LAYER_CONFIG: Array[Dictionary] = [
	{
		"room_min": 10,       ## 第一大层（Floor 1-3）
		"room_max": 15,
		"reward_count": 1,    ## 每层1个奖励房
	},
	{
		"room_min": 20,       ## 第二大层（Floor 4-6）
		"room_max": 25,
		"reward_count": 2,    ## 每层2个奖励房
	},
	{
		"room_min": 30,       ## 第三大层（Floor 7-9）
		"room_max": 35,
		"reward_count": 2,    ## 每层2个奖励房
	},
]

## 通关界面相关
var _game_clear_ui: Control = null


func _ready() -> void:
	randomize()
	get_tree().paused = false
	## 创建黑色转场UI
	_create_transition_ui()
	## 连接死亡界面信号
	if death_screen and death_screen.has_method("show_death"):
		death_screen.restart_game.connect(_on_restart_game)
		death_screen.quit_to_menu.connect(_on_quit_to_menu_from_death)
	## 启动时显示主菜单，不直接进入地牢
	_show_main_menu()


func _show_main_menu() -> void:
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if main_menu:
		main_menu.show_menu()
		if not main_menu.start_game.is_connected(_on_start_game):
			main_menu.start_game.connect(_on_start_game)
		if not main_menu.quit_game.is_connected(_on_quit_game):
			main_menu.quit_game.connect(_on_quit_game)
	if pause_menu:
		if not pause_menu.resume_game.is_connected(_on_resume_game):
			pause_menu.resume_game.connect(_on_resume_game)
		if not pause_menu.quit_to_menu.is_connected(_on_quit_to_menu):
			pause_menu.quit_to_menu.connect(_on_quit_to_menu)


func _on_start_game() -> void:
	## 直接进入地牢（小镇功能暂未实现，预留接口）
	## TODO: 未来在此处可插入小镇场景切换逻辑
	## 例：get_tree().change_scene_to_file("res://scenes/town/Town.tscn")
	if main_menu:
		main_menu.hide_menu()
	_start_dungeon()


func _start_dungeon() -> void:
	## 从主城进入地牢，直接开始游戏
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
	if main_menu:
		main_menu.hide_menu()
	if pause_menu:
		pass  ## game_started 已从 PauseMenu 移除，暂停菜单现在始终响应输入
	_setup_player()
	_generate_floor()
	_connect_signals()
	_update_ui()


func _setup_player() -> void:
	player.health_changed.connect(_on_health_changed)
	player.triple_shot_activated.connect(_on_player_triple_shot_activated)
	player.smg_activated.connect(_on_player_smg_activated)
	player.dumdum_activated.connect(_on_player_dumdum_activated)
	## Camera3D 是 Player 子节点
	if camera:
		camera.rotation_degrees.x = -60.0
		camera.size = 250.0
	## 创建Boss血条UI
	_create_boss_health_bar()


func _create_boss_health_bar() -> void:
	var ui := $CanvasLayer/UI
	if not ui:
		return
	ui_boss_health = ProgressBar.new()
	ui_boss_health.name = "BossHealthBar"
	ui_boss_health.size = Vector2(400, 24)
	ui_boss_health.position = Vector2((1280 - 400) / 2, 680)  ## 画面正下方
	ui_boss_health.max_value = 300.0
	ui_boss_health.value = 300.0
	ui_boss_health.visible = false
	## 红色样式
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.9, 0.1, 0.1, 1.0)
	ui_boss_health.add_theme_stylebox_override("fill", sb)
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.2, 0.05, 0.05, 1.0)
	ui_boss_health.add_theme_stylebox_override("background", sb_bg)
	ui.add_child(ui_boss_health)


func _generate_floor() -> void:
	## 清理旧房间
	for room in _rooms:
		if is_instance_valid(room):
			room.queue_free()
	_rooms.clear()
	_room_grid.clear()
	_room_positions.clear()
	_room_connections.clear()
	_discovered.clear()
	_cleared.clear()
	_room_types.clear()
	_room_occupancy.clear()

	var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var dir_to_name := {
		Vector2i.UP:    "NorthDoor",
		Vector2i.DOWN:  "SouthDoor",
		Vector2i.LEFT:  "WestDoor",
		Vector2i.RIGHT: "EastDoor",
	}

	## 随机游走生成房间网格（支持大房间和超大房间）
	var start_pos := Vector2i(0, 0)
	_room_grid[start_pos] = 0
	_room_positions.append(start_pos)
	_room_occupancy[0] = [start_pos]
	_room_connections.append([])
	_discovered.append(false)
	_cleared.append(false)
	_room_types.append(Room.RoomType.SAFE)

	var occupied_positions: Array[Vector2i] = [start_pos]
	var idx := 1

	## 根据当前层数获取大层配置
	_current_layer = get_current_layer(_floor)
	var layer_cfg: Dictionary = LAYER_CONFIG[_current_layer - 1]
	var target_count := randi_range(layer_cfg.room_min, layer_cfg.room_max)

	while idx < target_count and occupied_positions.size() > 0:
		## 从已占用位置中随机选择一个作为扩展起点
		var shuffled_pos := occupied_positions.duplicate()
		shuffled_pos.shuffle()
		var found := false

		for expand_pos in shuffled_pos:
			var shuffled_dirs := dirs.duplicate()
			shuffled_dirs.shuffle()

			for d in shuffled_dirs:
				var next: Vector2i = expand_pos + d

				## 检查位置是否已被占用
				if _room_grid.has(next):
					continue

				## 决定房间类型和占用位置
				var room_type := Room.RoomType.NORMAL
				var occupancy: Array[Vector2i] = [next]

				## 尝试生成超大房间（5%概率，且不是前几个房间）
				if idx > 2 and randf() < 0.05:
					var right := next + Vector2i.RIGHT
					var down := next + Vector2i.DOWN
					var diag := next + Vector2i.RIGHT + Vector2i.DOWN
					if not _room_grid.has(right) and not _room_grid.has(down) and not _room_grid.has(diag):
						room_type = Room.RoomType.HUGE
						occupancy = [next, right, down, diag]
				## 尝试生成大房间（15%概率）
				elif idx > 1 and randf() < 0.15:
					var right := next + Vector2i.RIGHT
					if not _room_grid.has(right):
						room_type = Room.RoomType.LARGE
						occupancy = [next, right]

				## 标记所有占用位置
				for p in occupancy:
					_room_grid[p] = idx
					if not occupied_positions.has(p):
						occupied_positions.append(p)

				_room_positions.append(next)
				_room_occupancy[idx] = occupancy
				_room_connections.append([])
				_discovered.append(false)
				_cleared.append(false)
				_room_types.append(room_type)

				## 找到相邻已有房间并建立连接
				for p in occupancy:
					for nd in dirs:
						var np: Vector2i = p + nd
						if _room_grid.has(np) and _room_grid[np] != idx:
							var neighbor_idx: int = _room_grid[np]
							if not _room_connections[idx].has(neighbor_idx):
								_room_connections[idx].append(neighbor_idx)
							if not _room_connections[neighbor_idx].has(idx):
								_room_connections[neighbor_idx].append(idx)

				idx += 1
				found = true
				break

			if found:
				break

		if not found:
			## 无法继续扩展，提前结束
			break

	## 标记Boss房和奖励房
	## 每层都必须有Boss房（通过地洞前往下一层）
	var _boss_room_index := _find_boss_room()

	## 根据大层配置确定奖励房数量（支持多个）
	var reward_count: int = layer_cfg.reward_count
	var _reward_room_indices: Array[int] = []
	if reward_count > 0:
		_reward_room_indices = _find_reward_rooms(_boss_room_index, reward_count)
	
	## 兜底：确保奖励房数量足够
	_reward_room_indices = _ensure_reward_rooms(_reward_room_indices, _boss_room_index, reward_count)

	## 后处理：确保Boss房和所有奖励房不直接相连
	if _boss_room_index >= 0:
		for ri in _reward_room_indices:
			if _room_connections[_boss_room_index].has(ri):
				_boss_room_index = _find_boss_room_excluding(_reward_room_indices)
				break

	if _boss_room_index >= 0:
		_room_types[_boss_room_index] = Room.RoomType.BOSS
	for ri in _reward_room_indices:
		if ri >= 0 and ri < _room_types.size():
			_room_types[ri] = Room.RoomType.REWARD

	## 创建房间实例
	var room_size := Vector3(640, 0, 640)
	for i in range(_room_positions.size()):
		var room_type: int = _room_types[i]
		var room: Room

		if room_type == Room.RoomType.LARGE:
			room = ROOM_LARGE_SCENE.instantiate() as Room
			room.room_type = Room.RoomType.LARGE
			room.enemy_count = min(4 + _floor * 2, 24)
		elif room_type == Room.RoomType.HUGE:
			room = ROOM_HUGE_SCENE.instantiate() as Room
			room.room_type = Room.RoomType.HUGE
			room.enemy_count = min(6 + _floor * 3, 36)
		else:
			room = ROOM_SCENE.instantiate() as Room
			room.room_id = "room_%d" % i
			if i == 0:
				room.room_type = Room.RoomType.SAFE
				room.enemy_count = 0
				_cleared[i] = true
				## 第一层第一关的出生点显示操作提示
				if _current_layer == 1 and _floor == 1:
					room.show_help_text = true
			elif i == _boss_room_index:
				room.room_type = Room.RoomType.BOSS
				room.enemy_count = 1
			elif _reward_room_indices.has(i):
				room.room_type = Room.RoomType.REWARD
				room.enemy_count = 0
				_cleared[i] = true
			else:
				room.enemy_count = min(2 + _floor, 12)

		add_child(room)
		move_child(room, 0)
		room.global_position = Vector3(_room_positions[i].x, 0, _room_positions[i].y) * room_size
		room.visible = false
		room.process_mode = Node.PROCESS_MODE_DISABLED
		var detector := room.get_node_or_null("PlayerDetector") as Area3D
		if detector:
			detector.monitoring = false
		room.floor_number = _floor
		room.layer_number = _current_layer  ## 大层编号，决定刷哪些怪物
		## 继承重玩模式：怪量翻5倍
		if _is_new_game_plus and room.room_type in [Room.RoomType.NORMAL, Room.RoomType.LARGE, Room.RoomType.HUGE]:
			room.enemy_count = room.enemy_count * 5
		_rooms.append(room)
		_connect_room_signals(room)

	## 设置门连接（根据房间占用位置和邻居位置分配门名）
	for j in range(_room_positions.size()):
		var room := _rooms[j]
		var occupancy: Array = _room_occupancy[j]
		var main_pos: Vector2i = _room_positions[j]

		## 对每个占用位置的4个方向检查邻居
		for pos in occupancy:
			for d in dirs:
				var neighbor_pos: Vector2i = pos + d
				if _room_grid.has(neighbor_pos) and _room_grid[neighbor_pos] != j:
					var neighbor_idx: int = _room_grid[neighbor_pos]
					var door_name: String = ""

					match room.room_type:
						Room.RoomType.LARGE:
							var rel_x: int = pos.x - main_pos.x
							if d == Vector2i.UP:
								door_name = "NorthDoor1" if rel_x == 0 else "NorthDoor2"
							elif d == Vector2i.DOWN:
								door_name = "SouthDoor1" if rel_x == 0 else "SouthDoor2"
							elif d == Vector2i.LEFT:
								door_name = "WestDoor"
							elif d == Vector2i.RIGHT:
								door_name = "EastDoor"

						Room.RoomType.HUGE:
							var rel_x: int = pos.x - main_pos.x
							var rel_y: int = pos.y - main_pos.y
							if d == Vector2i.UP:
								door_name = "NorthDoor1" if rel_x == 0 else "NorthDoor2"
							elif d == Vector2i.DOWN:
								door_name = "SouthDoor1" if rel_x == 0 else "SouthDoor2"
							elif d == Vector2i.LEFT:
								door_name = "WestDoor1" if rel_y == 0 else "WestDoor2"
							elif d == Vector2i.RIGHT:
								door_name = "EastDoor1" if rel_y == 0 else "EastDoor2"

						_:
							door_name = dir_to_name.get(d, "")

					if door_name != "" and not room.neighbor_indices.has(door_name):
						room.neighbor_indices[door_name] = neighbor_idx

		## 收集邻居房间的类型
		var neighbor_type_map: Dictionary = {}
		for door_name in room.neighbor_indices.keys():
			var tidx: int = room.neighbor_indices[door_name]
			if tidx >= 0 and tidx < _rooms.size():
				neighbor_type_map[door_name] = _rooms[tidx].room_type
		if room.has_method("set_neighbor_indices"):
			room.set_neighbor_indices(room.neighbor_indices, neighbor_type_map)

	## 进入起始房间
	_current_room_index = 0
	_enter_room(0, Room.EntryDir.SOUTH)
	_update_minimap()


## 找到Boss房：优先最远的死路房间（只连普通怪物房），没有死路就选最远房间
func _find_boss_room(reward_idx: int = -1) -> int:
	var dead_ends: Array[int] = []
	for i in range(_room_connections.size()):
		if _room_connections[i].size() != 1:
			continue
		if i == 0:
			continue
		if _room_connections[i].has(0):
			continue
		## 如果已指定奖励房，排除与奖励房直接相连的
		if reward_idx >= 0 and _room_connections[i].has(reward_idx):
			continue
		## 确保唯一邻居是普通怪物房
		var neighbor: int = _room_connections[i][0]
		if _room_types[neighbor] != Room.RoomType.NORMAL:
			continue
		dead_ends.append(i)

	if dead_ends.size() > 0:
		var distances: Array = []
		for i in dead_ends:
			var pos: Vector2i = _room_positions[i]
			var dist: int = abs(pos.x) + abs(pos.y)
			distances.append({"index": i, "dist": dist})
		distances.sort_custom(func(a, b): return a.dist > b.dist)
		return distances[0].index

	## 兜底：没有死路，选最远房间（排除起点、奖励房，且邻居是普通房）
	var candidates: Array[int] = []
	for i in range(1, _room_positions.size()):
		if i == reward_idx:
			continue
		if _room_connections[i].size() == 0:
			continue
		## 确保至少有一个邻居是普通怪物房
		var has_normal_neighbor := false
		for n in _room_connections[i]:
			if _room_types[n] == Room.RoomType.NORMAL:
				has_normal_neighbor = true
				break
		if not has_normal_neighbor:
			continue
		candidates.append(i)
	if candidates.size() == 0:
		return -1
	var distances: Array = []
	for i in candidates:
		var pos: Vector2i = _room_positions[i]
		var dist: int = abs(pos.x) + abs(pos.y)
		distances.append({"index": i, "dist": dist})
	distances.sort_custom(func(a, b): return a.dist > b.dist)
	return distances[0].index


## 找到奖励房：另一个死路房间（只连普通怪物房，不连Boss房/起点房），没有死路就选最远房间
func _find_reward_room(boss_idx: int) -> int:
	var dead_ends: Array[int] = []
	for i in range(_room_connections.size()):
		if _room_connections[i].size() != 1:
			continue
		if i == 0:
			continue
		if i == boss_idx:
			continue
		## 必须是普通房间（排除大/超大房间）
		if _room_types[i] != Room.RoomType.NORMAL:
			continue
		## 排除与Boss房直接相连的房间
		if boss_idx >= 0 and _room_connections[i].has(boss_idx):
			continue
		## 排除与起点房直接相连的房间（唯一邻居不能是起点）
		if _room_connections[i].has(0):
			continue
		## 确保唯一邻居是普通怪物房
		var neighbor: int = _room_connections[i][0]
		if _room_types[neighbor] != Room.RoomType.NORMAL:
			continue
		dead_ends.append(i)

	if dead_ends.size() > 0:
		var distances: Array = []
		for i in dead_ends:
			var pos: Vector2i = _room_positions[i]
			var dist: int = abs(pos.x) + abs(pos.y)
			distances.append({"index": i, "dist": dist})
		distances.sort_custom(func(a, b): return a.dist > b.dist)
		return distances[0].index

	## 兜底：没有死路，选最远的普通房间（排除起点、Boss房、大/超大房间，且邻居是普通房）
	var candidates: Array[int] = []
	for i in range(1, _room_positions.size()):
		if i == boss_idx:
			continue
		if _room_types[i] != Room.RoomType.NORMAL:
			continue
		if _room_connections[i].has(0):
			continue
		if boss_idx >= 0 and _room_connections[i].has(boss_idx):
			continue
		## 确保至少有一个邻居是普通怪物房
		var has_normal_neighbor := false
		for n in _room_connections[i]:
			if _room_types[n] == Room.RoomType.NORMAL:
				has_normal_neighbor = true
				break
		if not has_normal_neighbor:
			continue
		candidates.append(i)
	if candidates.size() == 0:
		return -1
	var distances: Array = []
	for i in candidates:
		var pos: Vector2i = _room_positions[i]
		var dist: int = abs(pos.x) + abs(pos.y)
		distances.append({"index": i, "dist": dist})
	distances.sort_custom(func(a, b): return a.dist > b.dist)
	return distances[0].index


func _enter_room(index: int, entry_dir: int, entry_door_name: String = "") -> void:
	_changing_room = true
	
	## 离开房间时隐藏Boss血条（Boss房会在boss生成后重新显示）
	_hide_boss_health_bar()

	## 隐藏所有房间，禁用检测
	for i in range(_rooms.size()):
		var r := _rooms[i]
		if not is_instance_valid(r):
			continue
		r.visible = false
		r.process_mode = Node.PROCESS_MODE_DISABLED
		var det := r.get_node_or_null("PlayerDetector") as Area3D
		if det:
			det.call_deferred("set_monitoring", false)
		## 禁用该房间所有门的 Area3D monitoring，防止旧房间门干扰传送
		var door_container := r.get_node_or_null("Doors") as Node3D
		if door_container:
			for door in door_container.get_children():
				if door is Area3D:
					door.monitoring = false

	var source_index: int = _current_room_index
	_current_room_index = index
	var room := _rooms[index]
	room.entry_direction = entry_dir

	## 大/超大房间：根据源房间索引，反查目标房间中对应入口门的正确门名
	## （传入的 entry_door_name 是源房间的门名，目标房间需要的是自己的门名）
	if room.room_type in [Room.RoomType.LARGE, Room.RoomType.HUGE]:
		var found := false
		for door_name in room.neighbor_indices:
			if room.neighbor_indices[door_name] == source_index:
				entry_door_name = door_name
				found = true
				break
		## 防御性回退：如果没找到精确匹配，尝试用传入的门名模糊匹配
		if not found and entry_door_name != "":
			for door_name in room.neighbor_indices.keys():
				if door_name.begins_with(entry_door_name):
					entry_door_name = door_name
					break

	room.entry_door_name = entry_door_name
	room.visible = true
	room.process_mode = Node.PROCESS_MODE_INHERIT
	_discovered[index] = true

	## 启用当前房间的 PlayerDetector
	var detector := room.get_node_or_null("PlayerDetector") as Area3D
	if detector:
		detector.call_deferred("set_monitoring", true)

	## 如果房间已清空，开门；否则激活房间
	if _cleared[index]:
		room._cleared = true
		room._open_doors()
		## 揭示相邻房间（让玩家知道旁边有路）
		_reveal_adjacent(index)
	else:
		room._cleared = false
		room._close_doors()
		room.activate_room()
		print("Main: 激活房间: ", room.room_id, " 类型: ", room.room_type)

	await get_tree().process_frame
	player.global_position = room.global_position + room.get_spawn_local_position()
	_update_minimap()
	_changing_room = false


func _reveal_adjacent(index: int) -> void:
	for target_idx in _room_connections[index]:
		if not _discovered[target_idx]:
			_discovered[target_idx] = true


func _on_room_cleared() -> void:
	if _game_over:
		return
	_cleared[_current_room_index] = true
	_update_ui()  ## 保持 Floor 文字正常显示，不再覆盖为 CLEARED!
	_reveal_adjacent(_current_room_index)

	## 检查是否是Boss房 - Boss房清空后不再自动进入下一层，等待玩家进入地洞
	var current_room: Room = _rooms[_current_room_index]
	if current_room and current_room.room_type == Room.RoomType.BOSS:
		## Boss房已清空，地洞已生成，等待玩家进入地洞
		_update_minimap()
		return

	## 检查是否所有房间都清空了
	var all_cleared := true
	for c in _cleared:
		if not c:
			all_cleared = false
			break
	if all_cleared:
		await get_tree().create_timer(2.0, true).timeout
		if _game_over:
			return
		## 检查是否通关
		if _floor >= TOTAL_FLOORS and not _is_new_game_plus:
			_on_game_clear()
			return
		## 进入下一层
		_floor += 1
		_generate_floor()
		_update_ui()
	else:
		_update_minimap()


func _on_player_left_room(_exit_dir: int, target_index: int, entry_door_name: String = "") -> void:
	if _changing_room or _game_over:
		return
	if target_index < 0 or target_index >= _rooms.size():
		return
	var entry_dir: int = Room.EXIT_TO_ENTRY.get(_exit_dir, Room.EntryDir.SOUTH)
	_enter_room(target_index, entry_dir, entry_door_name)


func _create_transition_ui() -> void:
	## 创建黑色转场UI
	_transition_rect = ColorRect.new()
	_transition_rect.name = "TransitionRect"
	_transition_rect.color = Color(0, 0, 0, 0)  ## 初始透明
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.size = Vector2(1280, 720)
	_transition_rect.visible = false
	
	## 添加到CanvasLayer
	var canvas := $CanvasLayer as CanvasLayer
	if canvas:
		canvas.add_child(_transition_rect)
		## 确保在最上层
		canvas.move_child(_transition_rect, -1)


func _connect_room_signals(room: Room) -> void:
	if not room.room_cleared.is_connected(_on_room_cleared):
		room.room_cleared.connect(_on_room_cleared)
	if not room.player_left_room.is_connected(_on_player_left_room):
		room.player_left_room.connect(_on_player_left_room)
	if not room.boss_spawned.is_connected(_on_boss_spawned):
		room.boss_spawned.connect(_on_boss_spawned)
	if not room.boss_died.is_connected(_on_boss_died):
		room.boss_died.connect(_on_boss_died)
	if not room.next_floor_hole_spawned.is_connected(_on_next_floor_hole_spawned):
		room.next_floor_hole_spawned.connect(_on_next_floor_hole_spawned)
	## 连接史莱姆击杀信号
	if room.has_signal("slime_killed"):
		if not room.slime_killed.is_connected(_on_slime_killed):
			room.slime_killed.connect(_on_slime_killed)


func _on_boss_spawned(boss: Node) -> void:
	_current_boss = boss
	print("Main: Boss生成: ", boss.name)
	if ui_boss_health:
		var hc = boss.get_node_or_null("HealthComponent")
		if hc:
			ui_boss_health.max_value = hc.max_health
			ui_boss_health.value = hc.current_health
			print("Main: Boss血量: ", hc.current_health, "/", hc.max_health)
		ui_boss_health.visible = true
		print("Main: Boss血条已显示")
	if boss.has_signal("health_changed"):
		boss.health_changed.connect(_on_boss_health_changed)


func _on_boss_health_changed(current: float, max_hp: float) -> void:
	if not ui_boss_health:
		return
	
	## 如果当前Boss是WormBoss，汇总所有虫子的总血量
	if _current_boss and _current_boss.is_in_group("worm_boss"):
		var worms: Array = get_tree().get_nodes_in_group("worm_boss")
		var total_current: float = 0.0
		var total_max: float = 0.0
		for worm in worms:
			if not is_instance_valid(worm):
				continue
			var hc: Node = worm.get("health_comp")
			if hc:
				total_current += hc.current_health
				total_max += hc.max_health
		ui_boss_health.max_value = max(total_max, 1.0)
		ui_boss_health.value = max(total_current, 0.0)
	else:
		## 其他Boss（史莱姆王、大眼怪等）按常规处理
		ui_boss_health.max_value = max_hp
		ui_boss_health.value = current


func _on_boss_died() -> void:
	if ui_boss_health:
		ui_boss_health.visible = false
	_current_boss = null


## 地洞生成后的处理
func _on_next_floor_hole_spawned(hole: Node3D) -> void:
	if not hole:
		return
	## 连接地洞的player_entered信号
	if hole.has_signal("player_entered"):
		if not hole.player_entered.is_connected(_on_player_enter_hole):
			hole.player_entered.connect(_on_player_enter_hole)


## 玩家踏入地洞
func _on_player_enter_hole() -> void:
	if _game_over or _hole_transition_active:
		return
	_hole_transition_active = true
	
	if player and is_instance_valid(player):
		player.set_physics_process(false)
		player.visible = true  ## 确保可见以播放动画
	
	## 播放跳跃动画，然后转场
	await _play_hole_animation()
	
	## 黑色转场
	await _play_transition(true)
	
	## 切换到下一层
	_floor += 1
	## 检查是否通关（非继承重玩模式）
	if _floor > TOTAL_FLOORS and not _is_new_game_plus:
		await _play_transition(false)
		_hole_transition_active = false
		_on_game_clear()
		return
	_generate_floor()
	_update_ui()
	
	## 恢复玩家输入
	if player and is_instance_valid(player):
		player.set_physics_process(true)
	
	## 转场结束，淡出黑色
	await _play_transition(false)
	
	## 冻结玩家0.5秒，防止乱按立即进入门
	if player and is_instance_valid(player):
		player.freeze(0.5)
	
	_hole_transition_active = false


## 播放玩家跳跃到地洞的动画
func _play_hole_animation() -> void:
	if not player:
		return
	
	## 找到当前房间的地洞
	var hole: Node3D = null
	var current_room: Room = _rooms[_current_room_index]
	if current_room:
		for child in current_room.get_children():
			if child.is_in_group("next_floor_hole"):
				hole = child
				break
		## 如果没找到，尝试按名称查找
		if not hole:
			hole = current_room.get_node_or_null("NextFloorHole") as Node3D
	
	if not hole:
		## 如果找不到地洞，直接返回
		await get_tree().create_timer(0.5).timeout
		return
	
	## 获取地洞中心位置
	var hole_center: Vector3 = hole.global_position
	hole_center.y = 0.0
	
	## 获取玩家起始位置
	var player_start: Vector3 = player.global_position
	var player_start_y: float = player_start.y
	
	## 创建跳跃动画：向上弧线跳到地洞中心
	var jump_height: float = 40.0
	var jump_duration: float = 0.6
	
	## 使用Tween实现弧线运动
	var tween := create_tween()
	
	## 步骤1：水平移动到地洞中心（X和Z轴）
	tween.tween_property(player, "global_position:x", hole_center.x, jump_duration).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(player, "global_position:z", hole_center.z, jump_duration).set_trans(Tween.TRANS_SINE)
	
	## 步骤2：Y轴弧线运动（使用tween_method）
	var tween_y := create_tween()
	tween_y.tween_method(
		func(t: float) -> void:
			## t从0到1
			var arc_height: float = sin(t * PI) * jump_height
			player.global_position.y = player_start_y + arc_height,
		0.0, 1.0, jump_duration
	)
	
	## 等待两个Tween完成
	await tween.finished
	await tween_y.finished
	
	## 等待一小段时间，让玩家"停留"在地洞中心
	await get_tree().create_timer(0.3).timeout
	
	## 让玩家卡在地洞下方（Y<0），不弹回地面
	player.global_position.y = -10.0


## 播放黑色转场动画
func _play_transition(fade_in: bool) -> void:
	if not _transition_rect:
		return
	
	_transition_rect.visible = true
	
	## 创建转场动画
	if _transition_tween:
		_transition_tween.kill()
	
	_transition_tween = create_tween()
	
	if fade_in:
		## 淡入黑色（0.5秒）
		_transition_tween.tween_property(_transition_rect, "color:a", 1.0, 0.5)
		await _transition_tween.finished
	else:
		## 淡出黑色（0.5秒）
		_transition_tween.tween_property(_transition_rect, "color:a", 0.0, 0.5)
		await _transition_tween.finished
		_transition_rect.visible = false


func _hide_boss_health_bar() -> void:
	if ui_boss_health:
		ui_boss_health.visible = false
	if _current_boss and _current_boss.health_changed.is_connected(_on_boss_health_changed):
		_current_boss.health_changed.disconnect(_on_boss_health_changed)
	_current_boss = null


func _connect_signals() -> void:
	var ge := get_node_or_null("/root/GameEvents")
	if ge:
		if not ge.player_died.is_connected(_on_player_died):
			ge.player_died.connect(_on_player_died)
		if not ge.enemy_died.is_connected(_on_enemy_died):
			ge.enemy_died.connect(_on_enemy_died)


func _on_enemy_died(_enemy: Node) -> void:
	_score += 10
	_coins += randi_range(1, 3)
	_update_ui()


## 史莱姆击杀：1金币 + 1分
func _on_slime_killed(drops: Dictionary) -> void:
	if drops.has("score"):
		_score += drops["score"]
	if drops.has("coins"):
		_coins += drops["coins"]
	_update_ui()


func _on_player_died(_who: Node = null) -> void:
	_game_over = true
	ui_floor.text = "GAME OVER"
	set_physics_process(false)
	if death_screen and death_screen.has_method("show_death"):
		death_screen.show_death()


func _on_health_changed(current: float, max_hp: float) -> void:
	ui_health.max_value = max_hp
	ui_health.value = current


func _on_player_triple_shot_activated() -> void:
	if not buff_ui:
		return
	var icon = BuffUI.make_shotgun_icon()
	buff_ui.add_buff("triple_shot", icon, "散弹枪：每次射击发射3发子弹（-30°, 0°, +30°）")


func _on_player_smg_activated() -> void:
	if not buff_ui:
		return
	var icon = BuffUI.make_smg_icon()
	buff_ui.add_buff("smg", icon, "冲锋枪：攻速提升33%（射击间隔缩短）")


func _on_player_dumdum_activated() -> void:
	if not buff_ui:
		return
	var icon = BuffUI.make_dumdum_icon()
	buff_ui.add_buff("dumdum", icon, "达姆弹：基础伤害提升25%")


func _update_ui() -> void:
	ui_health.max_value = player.health_comp.max_health
	ui_health.value = player.health_comp.current_health
	ui_coins.text = "Coins: %d" % _coins
	ui_score.text = "Score: %d" % _score
	var layer_text: String = "Layer %d-%d" % [(_current_layer - 1) * FLOORS_PER_LAYER + 1, _current_layer * FLOORS_PER_LAYER]
	if _is_new_game_plus:
		layer_text += " [NEW GAME+]"
	ui_floor.text = "%s  Floor: %d/%d" % [layer_text, _floor, TOTAL_FLOORS]


func _input(event: InputEvent) -> void:
	## 主菜单的ESC处理保留在Main，暂停菜单的ESC由PauseMenu自行处理
	if event.is_action_pressed("ui_cancel"):
		if main_menu and main_menu.visible:
			get_tree().quit()


func _on_resume_game() -> void:
	if pause_menu:
		pause_menu.hide_menu()


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	## 清理所有房间
	for room in _rooms:
		if is_instance_valid(room):
			room.queue_free()
	_rooms.clear()
	_game_over = false
	_floor = 1
	_current_layer = 1
	_score = 0
	_coins = 0
	_game_cleared = false
	_is_new_game_plus = false
	_clean_up_game_clear_ui()
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if pause_menu:
		pass
	if main_menu:
		main_menu.show_menu()


## 根据层数获取当前大层编号（1-3）
static func get_current_layer(floor_num: int) -> int:
	return ceil(float(floor_num) / float(FLOORS_PER_LAYER))


## 查找多个奖励房（返回索引数组）
func _find_reward_rooms(boss_idx: int, count: int) -> Array[int]:
	var result: Array[int] = []
	var excluded: Array[int] = [0]  ## 排除起始房
	if boss_idx >= 0:
		excluded.append(boss_idx)

	## 收集所有候选房间（死路末端优先）
	var candidates: Array[Dictionary] = []
	for i in range(1, _room_connections.size()):
		if excluded.has(i):
			continue
		if _room_types[i] != Room.RoomType.NORMAL:
			continue
		if boss_idx >= 0 and _room_connections[i].has(boss_idx):
			continue
		if _room_connections[i].has(0):
			continue
		var neighbor_normal := false
		for n in _room_connections[i]:
			if _room_types[n] == Room.RoomType.NORMAL:
				neighbor_normal = true
				break
		if not neighbor_normal:
			continue
		var pos: Vector2i = _room_positions[i]
		candidates.append({"index": i, "dist": abs(pos.x) + pos.y})

	## 按距离排序，远的优先（让玩家走更多路才能拿到奖励）
	candidates.sort_custom(func(a, b): return a.dist > b.dist)

	## 取前count个
	for i in range(min(count, candidates.size())):
		result.append(candidates[i].index)
	return result


## 兜底：确保奖励房数量足够（强制升级普通房为奖励房）
func _ensure_reward_rooms(existing: Array[int], boss_idx: int, needed: int) -> Array[int]:
	var result: Array[int] = existing.duplicate()
	if result.size() >= needed:
		return result

	for i in range(1, _room_positions.size()):
		if result.size() >= needed:
			break
		if i == boss_idx or result.has(i):
			continue
		if _room_types[i] != Room.RoomType.NORMAL:
			continue
		result.append(i)
	return result


## 查找Boss房（排除指定房间索引列表）
func _find_boss_room_excluding(exclude_indices: Array[int]) -> int:
	var dead_ends: Array[int] = []
	for i in range(_room_connections.size()):
		if _room_connections[i].size() != 1:
			continue
		if i == 0 or exclude_indices.has(i):
			continue
		if _room_connections[i].has(0):
			continue
		var neighbor: int = _room_connections[i][0]
		if _room_types[neighbor] != Room.RoomType.NORMAL:
			continue
		dead_ends.append(i)

	if dead_ends.size() > 0:
		var distances: Array = []
		for i in dead_ends:
			var pos: Vector2i = _room_positions[i]
			distances.append({"index": i, "dist": abs(pos.x) + pos.y})
		distances.sort_custom(func(a, b): return a.dist > b.dist)
		return distances[0].index
	return -1


## 通关处理
func _on_game_clear() -> void:
	_game_cleared = true
	await _show_game_clear_screen()


## 显示通关选择界面
func _show_game_clear_screen() -> void:
	## 创建通关UI面板
	_game_clear_ui = Control.new()
	_game_clear_ui.name = "GameClearUI"
	_game_clear_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_clear_ui.mouse_filter = Control.MOUSE_FILTER_STOP

	## 半透明黑色背景
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_clear_ui.add_child(bg)

	## 标题文字
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "CONGRATULATIONS!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 160
	title.offset_left = -200
	title.offset_right = 200
	var title_font := FontFile.new()
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	_game_clear_ui.add_child(title)

	## 副标题
	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.text = "你已成功通关全部 %d 层地牢！" % TOTAL_FLOORS
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_top = 230
	subtitle.offset_left = -250
	subtitle.offset_right = 250
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_game_clear_ui.add_child(subtitle)

	## 分数显示
	var score_label := Label.new()
	score_label.text = "最终得分: %d" % _score
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	score_label.offset_top = 290
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.add_theme_color_override("font_color", Color(1, 0.75, 0.15))
	_game_clear_ui.add_child(score_label)

	## 继承重玩按钮
	var btn_ngp := Button.new()
	btn_ngp.text = "继承装备重玩 (5倍难度)"
	btn_ngp.pressed.connect(_start_new_game_plus)
	btn_ngp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	btn_ngp.offset_top = 370
	btn_ngp.offset_left = -160
	btn_ngp.offset_right = 160
	btn_ngp.min_size.y = 50
	_game_clear_ui.add_child(btn_ngp)

	## 返回主菜单按钮
	var btn_menu := Button.new()
	btn_menu.text = "返回主菜单"
	btn_menu.pressed.connect(_on_quit_to_menu_from_clear)
	btn_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	btn_menu.offset_top = 440
	btn_menu.offset_left = -120
	btn_menu.offset_right = 120
	btn_menu.min_size.y = 50
	_game_clear_ui.add_child(btn_menu)

	$CanvasLayer.add_child(_game_clear_ui)


## 开始继承重玩模式
func _start_new_game_plus() -> void:
	_is_new_game_plus = true
	_floor = 1
	_game_cleared = false
	_clean_up_game_clear_ui()
	player.health_comp.heal(player.health_comp.max_health)
	_generate_floor()
	_update_ui()


## 从通关界面退回主菜单
func _on_quit_to_menu_from_clear() -> void:
	_is_new_game_plus = false
	_game_cleared = false
	_clean_up_game_clear_ui()
	_on_quit_to_menu()


## 清理通关UI
func _clean_up_game_clear_ui() -> void:
	if _game_clear_ui and is_instance_valid(_game_clear_ui):
		_game_clear_ui.queue_free()
		_game_clear_ui = null


func _update_minimap() -> void:
	if minimap and minimap.has_method("update_map"):
		minimap.update_map(_room_positions, _room_connections, _discovered, _current_room_index, _cleared, _room_types)


## 更新体力条（显示冲刺冷却进度）
func _process(_delta: float) -> void:
	if player and ui_stamina:
		var cd_timer: Timer = player.get_node_or_null("RollCDTimer")
		if cd_timer and cd_timer.time_left > 0.0:
			## 冷却中：显示剩余时间百分比
			ui_stamina.value = 100.0 * (1.0 - cd_timer.time_left / cd_timer.wait_time)
		else:
			## 可用：满值
			ui_stamina.value = 100.0


func _on_restart_game() -> void:
	## 重新开始：隐藏死亡界面，重置游戏
	if death_screen and death_screen.has_method("hide_death"):
		death_screen.hide_death()
	_game_over = false
	_floor = 1
	_current_layer = 1
	_score = 0
	_coins = 0
	_game_cleared = false
	_is_new_game_plus = false
	_clean_up_game_clear_ui()
	player.health_comp.reset()
	player.revive()
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)
	_generate_floor()
	_update_ui()

func _on_quit_to_menu_from_death() -> void:
	## 从死亡界面退回主菜单
	if death_screen and death_screen.has_method("hide_death"):
		death_screen.hide_death()
	get_tree().paused = false
	## 清理所有房间
	for room in _rooms:
		if is_instance_valid(room):
			room.queue_free()
	_rooms.clear()
	_game_over = false
	_floor = 1
	_current_layer = 1
	_score = 0
	_coins = 0
	_game_cleared = false
	_is_new_game_plus = false
	_clean_up_game_clear_ui()
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if pause_menu:
		pass
	if main_menu:
		main_menu.show_menu()

func _on_quit_game() -> void:
	get_tree().quit()
