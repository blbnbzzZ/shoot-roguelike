## 房间控制器 3D 版本
class_name Room
extends Node3D

signal room_cleared
signal player_left_room(exit_dir: int, target_room_index: int, entry_door_name: String)
signal boss_spawned(boss: EnemyBase)
signal boss_died()
signal next_floor_hole_spawned(hole: Node3D)
signal slime_killed(drops: Dictionary)  ## 史莱姆击杀奖励信号

## 当前层数（由 Main.gd 设置）
var floor_number: int = 1
## 当前大层编号（1-3，由 Main.gd 设置，决定刷哪些怪物）
var layer_number: int = 1
var _slimes_spawned: bool = false  ## 防止史莱姆重复生成
var show_help_text: bool = false  ## 是否在出生点显示操作提示

## 邻居房间索引：门名 -> 房间索引（由 Main 设置）
var neighbor_indices: Dictionary = {}
## 邻居房间类型：门名 -> 房间类型（由 Main 设置）
var neighbor_types: Dictionary = {}

## 入口方向：玩家从哪个门进入，就在对应门附近出生
enum EntryDir { SOUTH, NORTH, EAST, WEST }

## 房间类型枚举（方便后续扩展奖励房、商店房、Boss房等）
enum RoomType { NORMAL, SAFE, REWARD, SHOP, BOSS, LARGE, HUGE }

@export var room_type: int = RoomType.NORMAL

## 出口方向转入口方向（离开北门的房间，新房间从南门进入）
const EXIT_TO_ENTRY: Dictionary = {
	EntryDir.NORTH: EntryDir.SOUTH,
	EntryDir.SOUTH: EntryDir.NORTH,
	EntryDir.EAST:  EntryDir.WEST,
	EntryDir.WEST:  EntryDir.EAST,
}

@export var room_id: String = ""
@export var enemy_count: int = 3

## 当前入口方向（由 Main 设置）
var entry_direction: int = EntryDir.SOUTH
## 当前入口门名（由 Main 设置，用于大房间精确出生点）
var entry_door_name: String = ""

var _wall_material: StandardMaterial3D = null

var ENEMY_SCENE: PackedScene = load("res://scenes/enemies/layer1/EnemyBase.tscn")
## 各类型敌人独立场景（继承 EnemyBase，可独立替换建模/动画/特效）
var STRAWBERRY_SCENE: PackedScene = load("res://scenes/enemies/layer1/Strawberry.tscn")
var ZAPRAT_SCENE: PackedScene = load("res://scenes/enemies/layer1/ZapRat.tscn")
var GURUGURU_SCENE: PackedScene = load("res://scenes/enemies/layer1/Guruguru.tscn")
var BIG_EYE_BOSS_SCENE: PackedScene = load("res://scenes/enemies/layer1/BigEyeBoss.tscn")
var WORM_BOSS_SCENE: PackedScene = load("res://scenes/enemies/layer1/WormBoss.tscn")
var SLIME_KING_BOSS_SCENE: PackedScene = load("res://scenes/enemies/layer1/SlimeKing.tscn")
var SLIME_SCENE: PackedScene = load("res://scenes/enemies/layer1/Slime.tscn")
## 第一大层第2、3小关专属：籽籽
var ZIZI_SCENE: PackedScene = load("res://scenes/enemies/layer1/Zizi.tscn")
const TRIPLE_SHOT_PICKUP_SCENE: PackedScene = preload("res://scenes/pickups/TripleShotPickup.tscn")
var SMG_PICKUP_SCENE: PackedScene = load("res://scenes/pickups/SMGPickup.tscn")
const NEXT_FLOOR_HOLE_SCENE: PackedScene = preload("res://scenes/pickups/NextFloorHole.tscn")

var _enemies_alive: int = 0
var _cleared: bool = false
var _started: bool = false

@onready var enemies_container: Node3D = $Enemies
@onready var player_detector: Area3D = $PlayerDetector
@onready var doors: Node3D = $Doors

## 门物理阻挡体
var _door_blockers: Array[StaticBody3D] = []
var _door_callables: Dictionary = {}
## 无邻居门的堵墙（永久墙壁）
var _door_walls: Dictionary = {}
## 子弹阻挡墙：只挡子弹（collision_layer=4），不挡玩家和敌人（玩家/敌人mask=16）
## 永久存在于每个门口，防止子弹穿过到相邻房间
var _bullet_barriers: Array[StaticBody3D] = []

## 四个方向的玩家出生位置（相对房间原点的本地坐标）
## 基于门实际位置向房间内部偏移 50 单位：
##   普通房(640×640): N(z=10→60) S(z=630→580) E(x=630→580) W(x=10→60)，Z/X 保持门中心不变
const ENTRY_POSITIONS: Dictionary = {
	EntryDir.SOUTH: Vector3(320, 1, 580),
	EntryDir.NORTH: Vector3(320, 1, 60),
	EntryDir.EAST:  Vector3(580, 1, 320),
	EntryDir.WEST:  Vector3(60, 1, 320),
}

## 返回本地出生位置（避免在 add_child 前访问 global_position）
func get_spawn_local_position() -> Vector3:
	## 如果有具体的入口门名，优先按门名精确生成（用于大/超大房间）
	if entry_door_name != "":
		if room_type == RoomType.LARGE:
			var large_door_positions := {
				## 大房(1280×640) 门实际位置 + 向内偏移 50
				"NorthDoor1": Vector3(320, 1, 60),
				"NorthDoor2": Vector3(960, 1, 60),
				"SouthDoor1": Vector3(320, 1, 580),
				"SouthDoor2": Vector3(960, 1, 580),
				"EastDoor":   Vector3(1220, 1, 320),
				"WestDoor":   Vector3(60, 1, 320),
			}
			if large_door_positions.has(entry_door_name):
				return large_door_positions[entry_door_name]
			## 防御性模糊匹配：如 "SouthDoor" 匹配 "SouthDoor1" / "SouthDoor2"
			for key in large_door_positions.keys():
				if key.begins_with(entry_door_name):
					return large_door_positions[key]
		elif room_type == RoomType.HUGE:
			var huge_door_positions := {
				"NorthDoor1": Vector3(320, 1, 60),
				"NorthDoor2": Vector3(960, 1, 60),
				"SouthDoor1": Vector3(320, 1, 1220),
				"SouthDoor2": Vector3(960, 1, 1220),
				"EastDoor1":  Vector3(1220, 1, 320),
				"EastDoor2":  Vector3(1220, 1, 960),
				"WestDoor1":  Vector3(60, 1, 320),
				"WestDoor2":  Vector3(60, 1, 960),
			}
			if huge_door_positions.has(entry_door_name):
				return huge_door_positions[entry_door_name]
			## 防御性模糊匹配
			for key in huge_door_positions.keys():
				if key.begins_with(entry_door_name):
					return huge_door_positions[key]
	## 普通房间或回退：按方向生成
	return ENTRY_POSITIONS.get(entry_direction, Vector3(320, 1, 420))


func _ready() -> void:
	player_detector.body_entered.connect(_on_player_enter)
	_doors_active(false)
	_update_door_visibility()

	## 根据敌人数量和房间类型标记初始状态
	## 开门由 set_neighbor_indices() 或 _on_visibility_changed() 处理
	if room_type == RoomType.SAFE or enemy_count == 0:
		_cleared = true

	visibility_changed.connect(_on_visibility_changed)

	## 周期安全校验：防止 _enemies_alive 计数残留导致门卡死
	var reconcile_timer: Timer = Timer.new()
	reconcile_timer.name = "ReconcileTimer"
	reconcile_timer.wait_time = 1.0
	reconcile_timer.one_shot = false
	reconcile_timer.timeout.connect(_reconcile_enemy_count)
	add_child(reconcile_timer)
	## 只在房间激活且未清理时启动校验
	reconcile_timer.start()

	## 根据房间类型应用视觉效果
	_apply_room_type()

	## 生成子弹阻挡墙（每个门口放置隐形墙，只挡子弹不挡人）
	_spawn_bullet_barriers()

	## 奖励房：生成三发子弹拾取物
	if room_type == RoomType.REWARD and TRIPLE_SHOT_PICKUP_SCENE:
		_spawn_reward_pickup()


func _on_visibility_changed() -> void:
	## 当房间变为可见时，确保已清理的房间门是开的
	if not visible:
		return
	await get_tree().process_frame
	## 已清理的房间（如出生点）变为可见时，直接开门，不依赖 detector 检测
	if _cleared:
		_open_doors()

	## 第1层：生成史莱姆（只生成一次）
	if floor_number == 1 and not _slimes_spawned:
		_spawn_slimes()
		_slimes_spawned = true
	## 同时检测玩家是否已在房间内，触发进入逻辑
	for body in player_detector.get_overlapping_bodies():
		if body.is_in_group("player"):
			_on_player_enter(body)
			break


func activate_room() -> void:
	## 由 Main 调用，手动激活房间（生成敌人、关门）
	## 已清理的房间（安全房/已通关）每次进入都要重新开门，不受 _started 拦截
	if _started and not _cleared:
		return
	_started = true
	if _cleared:
		_open_doors()
		return
	_close_doors()
	_update_door_visibility()
	_spawn_enemies()
	## 如果没有敌人，直接标记为空清并开门
	if _enemies_alive == 0:
		_cleared = true
		_open_doors()
		return
	## 播放生成动画，动画结束后敌人才会开始移动/被攻击
	## 同时覆盖 EnemyBase 和 Slime
	for child in enemies_container.get_children():
		if child.has_method("play_spawn_animation"):
			child.play_spawn_animation()

func _update_door_visibility() -> void:
	## 根据 neighbor_indices 显示/隐藏门的 Mesh，无邻居时生成堵墙
	for door in doors.get_children():
		if door is Area3D:
			var has_neighbor: bool = neighbor_indices.has(door.name)
			## 隐藏/显示 MeshInstance3D 子节点
			for child in door.get_children():
				if child is MeshInstance3D:
					child.visible = has_neighbor
			## 无邻居时生成堵门墙，有邻居时移除
			if not has_neighbor:
				_create_door_wall(door)
			else:
				_destroy_door_wall(door.name)
			## 无邻居时不监控
			if not has_neighbor:
				door.monitoring = false


func _on_player_enter(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	## 出生点提示：仅第一次进入出生点时显示操作提示
	if show_help_text:
		_spawn_help_text()
		show_help_text = false
	## 安全网：如果玩家物理穿墙进入了一个已启动且已清理的房间（绕过了正常门传送）
	## 确保门是开的，让玩家能正常离开；否则走正常激活流程
	if _started and _cleared:
		_open_doors()
		return
	activate_room()


func _spawn_enemies() -> void:
	if not ENEMY_SCENE:
		return
	
	## Boss房：生成大型敌人
	if room_type == RoomType.BOSS:
		_spawn_boss()
		return
	
	## 根据房间类型调整生成范围
	var max_x: float = 520.0
	var max_z: float = 520.0
	if room_type == RoomType.LARGE:
		max_x = 1160.0  ## 大房间宽度1280，减去边距
		max_z = 520.0   ## 大房间深度640，减去边距
	elif room_type == RoomType.HUGE:
		max_x = 1160.0  ## 超大房间宽度1280，减去边距
		max_z = 1160.0  ## 超大房间高度1280，减去边距
	
	for i in enemy_count:
		## 根据当前大层获取对应怪物场景
		var enemy_scene: PackedScene = _get_random_enemy_scene()
		if not enemy_scene:
			continue

		var enemy := enemy_scene.instantiate() as EnemyBase
		var spawn_pos := Vector3(
			randf_range(120, max_x),
			1.0,
			randf_range(120, max_z)
		)
		enemy.position = spawn_pos
		enemy.set_physics_process(false)
		enemies_container.add_child(enemy)
		_enemies_alive += 1
		var hc := enemy.get_node_or_null("HealthComponent") as HealthComponent
		if hc:
			hc.died.connect(_on_enemy_died)


## 校正敌人计数（安全兜底）：遍历实际存活的敌人节点，修正 _enemies_alive
## 解决偶发的"杀完怪门不开"问题（死亡信号丢失导致计数残留）
func _reconcile_enemy_count() -> void:
	var actual_alive: int = 0
	for child in enemies_container.get_children():
		if not is_instance_valid(child):
			continue
		## 敌人或史莱姆且未被标记为死亡状态
		if child is EnemyBase and child._state != EnemyBase.State.DEAD:
			actual_alive += 1
		elif child is Slime and child.is_inside_tree():
			actual_alive += 1
		elif child is WormBoss and child.is_inside_tree():
			actual_alive += 1
	if actual_alive != _enemies_alive:
		_enemies_alive = actual_alive
	## 计数归零但尚未清理房间 → 强制开门
	if _enemies_alive <= 0 and not _cleared:
		_cleared = true
		_open_doors()
		room_cleared.emit()
		if room_type == RoomType.BOSS:
			boss_died.emit()
			await get_tree().create_timer(1.5).timeout
			_spawn_next_floor_hole()
			var use_smg: bool = randf() < 0.5
			if use_smg and SMG_PICKUP_SCENE:
				_spawn_boss_weapon_reward(SMG_PICKUP_SCENE)
			elif TRIPLE_SHOT_PICKUP_SCENE and not use_smg:
				_spawn_boss_weapon_reward(TRIPLE_SHOT_PICKUP_SCENE)


func _on_enemy_died(_who: Node) -> void:
	_enemies_alive -= 1
	## 只有全部敌人死光后才开门（_enemies_alive <= 0 时处理）
	if _enemies_alive <= 0:
		## 安全兜底：校正计数后再判断（防止信号丢失导致计数残留）
		_reconcile_enemy_count()
		return  ## _reconcile 内部已处理开门逻辑


## 史莱姆死亡处理
func _on_slime_died(who: Node) -> void:
	_enemies_alive -= 1
	## 发出击杀奖励信号
	if who.has_method("get_drops"):
		var drops: Dictionary = who.call("get_drops")
		slime_killed.emit(drops)
	## 只有全部敌人死光后才开门
	if _enemies_alive <= 0:
		## 安全兜底：校正计数后再判断
		_reconcile_enemy_count()
		return  ## reconcile 内部已处理开门逻辑


## 生成史莱姆（只在普通怪物房生成，不占用敌人配额）
func _spawn_slimes() -> void:
	if room_type != RoomType.NORMAL:
		return
	if not SLIME_SCENE:
		return

	## 根据房间类型决定生成数量
	var max_slimes: int = 3  ## 小房间默认0-3只
	if room_type in [RoomType.LARGE, RoomType.HUGE]:
		max_slimes = 7  ## 大房间/超大房间0-7只

	var slime_count: int = randi_range(0, max_slimes)
	if slime_count == 0:
		return

	## 根据房间类型计算边界
	var max_x: float = 520.0
	var max_z: float = 520.0
	if room_type == RoomType.LARGE:
		max_x = 1160.0
	elif room_type == RoomType.HUGE:
		max_x = 1160.0
		max_z = 1160.0

	for i in slime_count:
		var slime := SLIME_SCENE.instantiate() as Node3D
		var spawn_pos := Vector3(
			randf_range(120, max_x),
			1.0,
			randf_range(120, max_z)
		)
		slime.position = spawn_pos
		enemies_container.add_child(slime)
		_enemies_alive += 1
		## 只连接 died 信号到 _on_slime_died（负责减计数+奖励）
		## 不再重复连接 slime_died -> _on_enemy_died，避免一只史莱姆死亡触发两次减计数
		slime.died.connect(_on_slime_died)


## 在房间中心生成下一层地洞
func _spawn_next_floor_hole() -> void:
	if not NEXT_FLOOR_HOLE_SCENE:
		return
	
	## 计算房间中心位置
	var center_pos: Vector3 = Vector3(320, 0, 320)  ## 普通房间中心
	if room_type == RoomType.LARGE:
		center_pos = Vector3(640, 0, 320)
	elif room_type == RoomType.HUGE:
		center_pos = Vector3(640, 0, 640)
	
	var hole := NEXT_FLOOR_HOLE_SCENE.instantiate() as Node3D
	if not hole:
		return
	
	add_child(hole)
	hole.global_position = global_position + center_pos
	
	## 延迟启用检测，避免立即检测到玩家
	if hole.has_method("set_monitoring_delayed"):
		hole.set_monitoring_delayed(1.0)
	
	## 发出信号通知Main场景
	next_floor_hole_spawned.emit(hole)


## 获取房间中心位置（世界坐标）
func _get_room_center() -> Vector3:
	var center: Vector3 = Vector3(320, 0, 320)  ## 普通房间中心
	if room_type == RoomType.LARGE:
		center = Vector3(640, 0, 320)
	elif room_type == RoomType.HUGE:
		center = Vector3(640, 0, 640)
	return global_position + center


## Boss死亡后在地洞旁边生成冲锋枪（避免与地洞重叠）
## 根据当前大层编号随机返回一个怪物场景
## 后续每层可添加独立怪物，只需在此函数中按layer_number分支即可
func _get_random_enemy_scene() -> PackedScene:
	match layer_number:
		1:
			## 第一大层第2、3小关：加入籽籽(30%概率)
			if floor_number == 2 or floor_number == 3:
				var roll := randf()
				## 30% 概率生成籽籽
				if roll < 0.3:
					return ZIZI_SCENE
				elif roll < 0.475:  ## (0.3 + 0.175) = 47.5%
					return GURUGURU_SCENE
				elif roll < 0.65:    ## (0.475 + 0.175) = 65%
					return ZAPRAT_SCENE
				else:
					return STRAWBERRY_SCENE
			else:
				## 第一大层第1小关：原版怪物配置
				var roll := randf()
				if roll < 0.25:
					return GURUGURU_SCENE
				elif roll < 0.5:
					return ZAPRAT_SCENE
				else:
					return STRAWBERRY_SCENE
		2:
			## 第二大层：暂用第一层怪物（后续替换为第二层专属怪物）
			var roll := randf()
			if roll < 0.25:
				return GURUGURU_SCENE
			elif roll < 0.5:
				return ZAPRAT_SCENE
			else:
				return STRAWBERRY_SCENE
		3:
			## 第三大层：暂用第一层怪物（后续替换为第三层专属怪物）
			var roll := randf()
			if roll < 0.25:
				return GURUGURU_SCENE
			elif roll < 0.5:
				return ZAPRAT_SCENE
			else:
				return STRAWBERRY_SCENE
		_:
			return STRAWBERRY_SCENE


## 根据当前大层编号返回对应Boss场景
## 测试模式：暂时只生成虫子Boss，方便测试（其他两个Boss已禁用）
func _get_boss_scene() -> PackedScene:
	return WORM_BOSS_SCENE


## Boss死亡后在地洞旁边生成武器奖励（避免与地洞重叠）
func _spawn_boss_weapon_reward(pickup_scene: PackedScene) -> void:
	var pickup := pickup_scene.instantiate() as Node3D
	if not pickup:
		return
	## 偏移80单位到地洞右侧，避免重叠
	var hole_pos: Vector3 = _get_room_center()
	pickup.global_position = hole_pos + Vector3(80, 1, 0)
	add_child(pickup)


## Boss房生成大型敌人（根据大层加载不同Boss）
func _spawn_boss() -> void:
	var boss_scene: PackedScene = _get_boss_scene()
	if not boss_scene:
		return
	var boss = boss_scene.instantiate()
	if not boss:
		return

	## 根据房间类型设置Boss出生位置
	var boss_pos: Vector3 = Vector3(320, 1, 320)  ## 普通房间中心
	if room_type == RoomType.LARGE:
		boss_pos = Vector3(640, 1, 320)
	elif room_type == RoomType.HUGE:
		boss_pos = Vector3(640, 1, 640)
	boss.position = boss_pos

	## 先添加到场景树，确保 @onready 变量初始化
	boss.set_physics_process(false)
	enemies_container.add_child(boss)

	## 设置Boss血量（按大层递增）
	## 史莱姆王（第一大层）在自身脚本中已设置1600血量，这里不覆盖
	## WormBoss 也有自身血量设置，这里也不覆盖
	if boss is EnemyBase and not boss is SlimeKingBoss:
		var boss_hp: float = 2000.0
		match layer_number:
			1:  boss_hp = 2000.0
			2:  boss_hp = 3500.0
			3:  boss_hp = 5000.0
		if boss.health_comp:
			boss.health_comp.max_health = boss_hp
			boss.health_comp.current_health = boss_hp

	## 连接死亡信号（EnemyBase 和 WormBoss 都有 HealthComponent）
	var health_comp = boss.get_node_or_null("HealthComponent")
	if health_comp:
		health_comp.invincible = false
		health_comp.died.connect(_on_enemy_died)

	## 重置Boss攻击计时器（仅 EnemyBase 类型 Boss 需要）
	if boss is EnemyBase:
		boss._boss_shoot_timer = boss.boss_shoot_interval
		boss._boss_single_shoot_timer = boss.boss_single_shoot_interval

	_enemies_alive = 1
	boss_spawned.emit(boss)


func _close_doors() -> void:
	_doors_active(false)
	## 生成物理阻挡体，防止玩家直接穿过去
	_create_door_blockers()


func _open_doors() -> void:
	_doors_active(true)
	## 移除物理阻挡体
	_destroy_door_blockers()
	## 门地标根据邻居房间类型变色
	for door in doors.get_children():
		if door is Area3D and neighbor_indices.has(door.name):
			var ntype: int = neighbor_types.get(door.name, 0)
			var door_color: Color
			match ntype:
				1: door_color = Color(0.2, 0.4, 0.9, 1)   ## 安全房 = 蓝
				2: door_color = Color(0.9, 0.4, 0.7, 1)   ## 奖励房 = 粉
				4: door_color = Color(0.9, 0.15, 0.15, 1) ## Boss房 = 红
				_: door_color = Color(0.2, 0.8, 0.3, 1)   ## 普通房 = 绿
			for child in door.get_children():
				if child is MeshInstance3D:
					var mat := StandardMaterial3D.new()
					mat.albedo_color = door_color
					child.material_override = mat
				elif child is Sprite3D:
					child.modulate = door_color


func _create_door_blockers() -> void:
	## 先清理所有可能残留的旧阻挡体（名称匹配 DoorBlocker_ 前缀）
	for door in doors.get_children():
		if door is Area3D:
			for child in door.get_children():
				if child is StaticBody3D and child.name.begins_with("DoorBlocker_"):
					if is_instance_valid(child):
						child.queue_free()
	_door_blockers.clear()
	for door in doors.get_children():
		if door is Area3D:
			## 只有存在邻居房间的门才需要阻挡
			if not neighbor_indices.has(door.name):
				continue
			var blocker := StaticBody3D.new()
			blocker.name = "DoorBlocker_" + door.name
			blocker.collision_layer = 4  ## Wall layer (Layer 3)
			blocker.collision_mask = 0
			## 根据门方向设置阻挡体尺寸（覆盖整个门洞）
			var is_horizontal: bool = door.name.begins_with("North") or door.name.begins_with("South")
			var box_shape := BoxShape3D.new()
			if is_horizontal:
				box_shape.size = Vector3(80, 100, 20)
			else:
				box_shape.size = Vector3(20, 100, 80)
			var col := CollisionShape3D.new()
			col.shape = box_shape
			## 碰撞体居中于门位置（门在边缘，碰撞体也在边缘）
			col.position = Vector3(0, 50, 0)
			blocker.add_child(col)
			door.add_child(blocker)
			_door_blockers.append(blocker)


func _destroy_door_blockers() -> void:
	for blocker in _door_blockers:
		if blocker and is_instance_valid(blocker):
			## 立即将碰撞层设为0（不再阻挡任何物体），不等待 queue_free 帧末延迟
			## 这防止玩家在 queue_free 生效前的窗口期内挤压穿透阻挡体
			blocker.collision_layer = 0
			blocker.queue_free()
	_door_blockers.clear()


## 为没有邻居的门生成永久堵墙（StaticBody3D）
func _create_door_wall(door: Area3D) -> void:
	## 先清理可能残留的旧堵墙（名称匹配 DoorWall_ 前缀）
	for child in door.get_children():
		if child is StaticBody3D and child.name.begins_with("DoorWall_"):
			if is_instance_valid(child):
				child.queue_free()
	_door_walls.erase(door.name)
	## 重新创建堵墙
	var wall := StaticBody3D.new()
	wall.name = "DoorWall_" + door.name
	wall.collision_layer = 4  ## Layer 3: Wall
	wall.collision_mask = 0

	var is_horizontal: bool = door.name.begins_with("North") or door.name.begins_with("South")
	var visual_size := Vector3(80, 50, 20) if is_horizontal else Vector3(20, 50, 80)
	var collide_size := Vector3(80, 100, 20) if is_horizontal else Vector3(20, 100, 80)

	## Mesh（视觉高度 = 墙壁视觉高度 50）
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = visual_size
	mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.35, 1)
	mesh.material_override = mat
	wall.add_child(mesh)

	## Collision（碰撞高度 = 墙壁碰撞高度 100）
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = collide_size
	col.shape = box_shape
	wall.add_child(col)

	## 提升碰撞体到墙壁碰撞中心高度 (y=50 全局)
	col.position = Vector3(0, 25, 0)

	## 提升视觉 Mesh 到墙壁视觉中心高度 (y=25 全局)
	mesh.position = Vector3(0, 25, 0)

	## 堵墙节点本身放在门节点下方（门在 y=1，wall 在 y=0 局部 = y=1 全局）
	wall.position = Vector3(0, 0, 0)

	door.add_child(wall)
	_door_walls[door.name] = wall


func _destroy_door_wall(door_name: String) -> void:
	var wall := _door_walls.get(door_name, null) as Node
	if wall and is_instance_valid(wall):
		wall.queue_free()
	_door_walls.erase(door_name)


func _doors_active(active: bool) -> void:
	for door in doors.get_children():
		if door is Area3D:
			## 只有存在邻居房间的门才需要激活
			if not neighbor_indices.has(door.name):
				continue
			door.monitoring = active
			var cb: Callable = _door_callables.get(door.name, Callable())
			if cb.is_valid() and door.body_entered.is_connected(cb):
				door.body_entered.disconnect(cb)
				_door_callables.erase(door.name)
			if active:
				cb = _on_door_entered.bind(door.name)
				door.body_entered.connect(cb)
				_door_callables[door.name] = cb
				## Area3D 重新启用 monitoring 时，已在范围内的玩家不会触发 body_entered
				## 延迟一帧后手动检查，避免玩家刚好在战斗时走到门附近被误传
				_check_overlapping_player.call_deferred(door)


## 延迟检查：Area3D 重新启用 monitoring 时，手动补发已进入玩家的信号
func _check_overlapping_player(door: Area3D) -> void:
	await get_tree().process_frame
	if not door.monitoring:
		return
	for body in door.get_overlapping_bodies():
		if body.is_in_group("player"):
			_on_door_entered(body, door.name)
			break


func _on_door_entered(body: Node3D, door_name: String) -> void:
	if not body.is_in_group("player"):
		return
	if not _cleared:
		return
	var target_idx: int = neighbor_indices.get(door_name, -1)
	if target_idx < 0:
		return
	var exit_dir: int = EntryDir.SOUTH
	var entry_door_name: String = ""
	match door_name:
		"NorthDoor", "NorthDoor1", "NorthDoor2":
			exit_dir = EntryDir.NORTH
			entry_door_name = door_name.replace("North", "South")
		"SouthDoor", "SouthDoor1", "SouthDoor2":
			exit_dir = EntryDir.SOUTH
			entry_door_name = door_name.replace("South", "North")
		"EastDoor", "EastDoor1", "EastDoor2":
			exit_dir = EntryDir.EAST
			entry_door_name = door_name.replace("East", "West")
		"WestDoor", "WestDoor1", "WestDoor2":
			exit_dir = EntryDir.WEST
			entry_door_name = door_name.replace("West", "East")
	player_left_room.emit(exit_dir, target_idx, entry_door_name)

func set_neighbor_indices(indices: Dictionary, types: Dictionary = {}) -> void:
	neighbor_indices = indices
	neighbor_types = types
	_update_door_visibility()
	## 如果房间已清理（如出生点），重新开门以激活有邻居的门
	if _cleared:
		_open_doors()

## 根据房间类型应用视觉效果
func _apply_room_type() -> void:
	if room_type == RoomType.SAFE:
		_tint_walls(Color(0.2, 0.4, 0.9, 1))
	elif room_type == RoomType.BOSS:
		_tint_walls(Color(0.9, 0.15, 0.15, 1))  ## Boss房红色墙壁
	elif room_type == RoomType.REWARD:
		_tint_walls(Color(0.9, 0.3, 0.6, 1))  ## 奖励房粉色墙壁

## 给墙壁着色（安全房蓝色，普通房使用默认材质）
func _tint_walls(color: Color) -> void:
	if not _wall_material:
		_wall_material = StandardMaterial3D.new()
	_wall_material.albedo_color = color
	var walls = $Walls
	if not walls:
		return
	for wall in walls.get_children():
		if wall is StaticBody3D:
			var mesh = wall.get_node_or_null("MeshInstance3D")
			if mesh:
				mesh.material_override = _wall_material


## 在奖励房随机生成一种武器拾取物（散弹枪或冲锋枪，互斥）
func _spawn_reward_pickup() -> void:
	## 随机选择：0=散弹枪, 1=冲锋枪
	var use_smg: bool = randf() < 0.5

	if use_smg and SMG_PICKUP_SCENE:
		_spawn_smg_pickup()
	elif TRIPLE_SHOT_PICKUP_SCENE and not use_smg:
		_spawn_shotgun_pickup()


## 生成散弹枪拾取物
func _spawn_shotgun_pickup() -> void:
	var pickup := TRIPLE_SHOT_PICKUP_SCENE.instantiate() as Node3D
	if not pickup:
		return
	pickup.global_position = _get_room_center() + Vector3(0, 1, 0)
	add_child(pickup)


## 生成冲锋枪拾取物
func _spawn_smg_pickup() -> void:
	var pickup := SMG_PICKUP_SCENE.instantiate() as Node3D
	if not pickup:
		return
	pickup.global_position = _get_room_center() + Vector3(0, 1, 0)
	add_child(pickup)


## ── 子弹阻挡墙（只挡子弹，不挡玩家/敌人）──
## 每个门口放置一个不可见的 StaticBody3D（collision_layer=16=子弹阻挡层）
## 玩家子弹 mask 包含 16，敌人子弹 mask 包含 16 → 检测到后销毁
## 玩家 collision_mask=7 不包含 16 → 完全忽略此墙，不会蹭门
## 注意：Projectile.gd 和 EnemyProjectile.gd 中已修复，同时检查 &4(墙) 和 &16(子弹墙)
func _spawn_bullet_barriers() -> void:
	for door in doors.get_children():
		if not door is Area3D:
			continue
		var barrier := StaticBody3D.new()
		barrier.name = "BulletBarrier_" + door.name
		## 使用子弹阻挡层(16)，玩家和敌人不会碰撞，只有子弹检测 &16 销毁
		barrier.collision_layer = 16
		barrier.collision_mask = 0

		## 根据门方向设置碰撞体尺寸（覆盖整个门洞）
		var is_horizontal: bool = door.name.begins_with("North") or door.name.begins_with("South")
		var box_shape := BoxShape3D.new()
		if is_horizontal:
			box_shape.size = Vector3(80, 200, 10)   ## 南北门：宽80，高200（从地面到天花板），厚10
		else:
			box_shape.size = Vector3(10, 200, 80)    ## 东西门：宽10，高200，深80

		var col := CollisionShape3D.new()
		col.shape = box_shape
		## 碰撞体中心在高度100处（y=50局部偏移 + 门y=1 ≈ y=51全局）
		col.position = Vector3(0, 99, 0)
		barrier.add_child(col)

		## 放到门节点下方，继承门的精确位置
		door.add_child(barrier)
		_bullet_barriers.append(barrier)

## 在出生点地面显示操作提示（仅第一层第一关显示）
func _spawn_help_text() -> void:
	if has_node("HelpText"):
		return  # 已生成过，不再重复
	var label := Label3D.new()
	label.name = "HelpText"
	label.text = "WASD移动，空格冲刺，鼠标左键攻击"
	label.position = Vector3(0, 0.2, 0)  # 略高于地面
	label.font_size = 32
	label.modulate = Color.WHITE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # 始终面向相机
	add_child(label)
