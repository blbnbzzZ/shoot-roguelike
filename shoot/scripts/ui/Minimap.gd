## 小地图 — 显示当前楼层房间布局
extends Control

const Room = preload("res://scenes/rooms/Room.gd")

@export var room_size: Vector2 = Vector2(20, 20)  ## 正方形格子
@export var gap: float = 6.0

var _room_positions: Array[Vector2i] = []
var _room_connections: Array[Array] = []
var _discovered: Array[bool] = []
var _current_index: int = 0
var _zoomed: bool = false
var _room_types: Array[int] = []  ## 新增：记录房间类型

## 颜色
const COLOR_CURRENT := Color(1.0, 0.85, 0.2, 1.0)
const COLOR_CLEARED := Color(0.5, 0.5, 0.5, 1.0)  ## 已清理的房间 - 灰色
const COLOR_UNCLEARED := Color(0.0, 0.0, 0.0, 1.0)  ## 未清理的房间 - 黑色
const COLOR_CONNECTION := Color(0.35, 0.35, 0.35, 1.0)
const COLOR_BG := Color(0.05, 0.05, 0.05, 0.5)  ## 背景色改浅，与缩小版一致

var _cleared: Array[bool] = []  ## 新增：记录房间是否已清理


func _ready() -> void:
	visible = true  ## 地图常亮
	modulate = Color(1, 1, 1, 0.5)  ## 默认50%透明度


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_map"):
		_zoomed = !_zoomed
		## 按M切换透明度：100%或50%
		if _zoomed:
			modulate = Color(1, 1, 1, 1.0)
		else:
			modulate = Color(1, 1, 1, 0.5)
		queue_redraw()


func update_map(
	room_positions: Array[Vector2i],
	room_connections: Array[Array],
	discovered: Array[bool],
	current_index: int,
	cleared: Array[bool] = [],
	room_types: Array[int] = []
) -> void:
	_room_positions = room_positions
	_room_connections = room_connections
	_discovered = discovered
	_current_index = current_index
	_cleared = cleared
	_room_types = room_types
	if visible:
		queue_redraw()


func _draw() -> void:
	if _room_positions.size() == 0:
		return

	var sc := 2.0 if _zoomed else 1.0
	var cs := room_size * sc
	var cg := gap * sc

	## 计算网格边界（考虑大房间和超大房间尺寸）
	var min_x := 9999
	var max_x := -9999
	var min_y := 9999
	var max_y := -9999
	for i in range(_room_positions.size()):
		var p := _room_positions[i]
		var room_w := 1
		var room_h := 1
		if i < _room_types.size():
			if _room_types[i] == Room.RoomType.LARGE:
				room_w = 2
			elif _room_types[i] == Room.RoomType.HUGE:
				room_w = 2
				room_h = 2
		min_x = mini(min_x, p.x)
		max_x = maxi(max_x, p.x + room_w - 1)
		min_y = mini(min_y, p.y)
		max_y = maxi(max_y, p.y + room_h - 1)

	var grid_w := max_x - min_x + 1
	var grid_h := max_y - min_y + 1
	var map_w := grid_w * cs.x + (grid_w - 1) * cg
	var map_h := grid_h * cs.y + (grid_h - 1) * cg

	## 右上角对齐，留边距
	var base_offset := Vector2(size.x - map_w - 16, 16)

	## 绘制背景
	draw_rect(Rect2(base_offset - Vector2(8, 8), Vector2(map_w + 16, map_h + 16)), COLOR_BG)

	## 绘制连接线
	for i in range(_room_connections.size()):
		if not _discovered[i] and i != 0:
			continue
		var p1 := _room_positions[i]
		for j in _room_connections[i]:
			if j < i:
				continue
			if not _discovered[j] and j != 0:
				continue
			var p2 := _room_positions[j]

			## 计算房间尺寸
			var p1_w := 1
			var p1_h := 1
			var p2_w := 1
			var p2_h := 1
			if i < _room_types.size():
				if _room_types[i] == Room.RoomType.LARGE:
					p1_w = 2
				elif _room_types[i] == Room.RoomType.HUGE:
					p1_w = 2
					p1_h = 2
			if j < _room_types.size():
				if _room_types[j] == Room.RoomType.LARGE:
					p2_w = 2
				elif _room_types[j] == Room.RoomType.HUGE:
					p2_w = 2
					p2_h = 2

			var cx1 := cs.x * p1_w * 0.5
			var cy1 := cs.y * p1_h * 0.5
			var cx2 := cs.x * p2_w * 0.5
			var cy2 := cs.y * p2_h * 0.5
			var pos1 := base_offset + Vector2(
				(p1.x - min_x) * (cs.x + cg) + cx1,
				(p1.y - min_y) * (cs.y + cg) + cy1
			)
			var pos2 := base_offset + Vector2(
				(p2.x - min_x) * (cs.x + cg) + cx2,
				(p2.y - min_y) * (cs.y + cg) + cy2
			)
			draw_line(pos1, pos2, COLOR_CONNECTION, 2.0 * sc)

	## 绘制房间方块
	for i in range(_room_positions.size()):
		if not _discovered[i]:
			continue
		var p := _room_positions[i]
		var room_w := 1
		var room_h := 1
		if i < _room_types.size():
			if _room_types[i] == Room.RoomType.LARGE:
				room_w = 2
			elif _room_types[i] == Room.RoomType.HUGE:
				room_w = 2
				room_h = 2

		var rect := Rect2(
			base_offset + Vector2(
				(p.x - min_x) * (cs.x + cg),
				(p.y - min_y) * (cs.y + cg)
			),
			Vector2(cs.x * room_w, cs.y * room_h)
		)

		var col := COLOR_CURRENT if i == _current_index else (COLOR_CLEARED if _cleared.has(i) and _cleared[i] else COLOR_UNCLEARED)
		draw_rect(rect, col)
