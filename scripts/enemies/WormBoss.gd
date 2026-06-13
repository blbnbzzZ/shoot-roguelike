## 虫子Boss（肉丸子）主脚本
## 管理所有身体部位的创建、移动、断开逻辑
## 移动方式：只沿X/Y轴（不斜走），定时2-5秒随机换方向，撞墙也换方向
## 断开机制：某部位HP归零时从此处断开，后面那段第一个部位变为新头部，两段独立移动

extends CharacterBody3D
class_name WormBoss

signal worm_died()
signal health_changed(current: float, max_hp: float)  ## Boss血条信号

## ── 导出参数 ──
@export var head_texture: Texture2D
@export var body_texture: Texture2D
@export var segment_count: int = 15        ## 总部位数（1头 + 14身体）
@export var segment_spacing: float = 40.0   ## 部位间距（约20%重叠）
@export var move_speed: float = 210.0       ## 削弱四分之一
@export var direction_change_min: float = 2.0
@export var direction_change_max: float = 5.0
@export var segment_hp: float = 200.0       ## 每个部位血量

## ── 子弹场景 ──
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapons/EnemyProjectile.tscn")

## ── 方向枚举（只走XY轴，不斜走）──
enum Direction { UP, DOWN, LEFT, RIGHT }

## ── 部位数据结构 ──
class SegmentData:
	var node: Node3D
	var sprite: Sprite3D
	var health_comp: HealthComponent
	var hit_box: Area3D
	var hurt_box: Area3D
	var is_head: bool
	var is_alive: bool = true
	var hp: float

## ── 内部状态 ──
var _segments: Array[SegmentData] = []
var _current_direction: int = Direction.RIGHT
var _direction_timer: float = 0.0
var _direction_interval: float = 3.0
var _head_position: Vector3 = Vector3.ZERO
var _position_history: Array[Vector3] = []  ## 头部位置历史（用于部位跟随）
var _history_length: int = 300              ## 位置历史长度
var _is_split_worm: bool = false            ## 是否是分裂出来的新虫（跳过初始创建）
var _original_scene_root: Node = null       ## 场景根节点（用于添加新分裂的虫）

## ── 碰撞引用 ──
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var health_comp: HealthComponent = $HealthComponent  ## 总血量组件（用于Boss血条）


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	add_to_group("worm_boss")  ## 添加到组，方便Room查找所有虫子
	set_physics_process(false)
	_original_scene_root = get_tree().current_scene

	## 初始化总血量（部位血量之和）
	if health_comp:
		health_comp.max_health = segment_count * segment_hp
		health_comp.current_health = segment_count * segment_hp
		health_comp.invincible = true  ## 总血量不由HealthComponent自己管理

	## 初始化位置历史
	_position_history.resize(_history_length)
	for i in range(_history_length):
		_position_history[i] = global_position

	## 创建所有部位（分裂出来的虫不重新创建）
	if not _is_split_worm:
		_create_segments()

	## 初始随机方向
	_pick_new_direction()
	_reset_direction_timer()

	## 播放入场动画
	await play_spawn_animation()
	set_physics_process(true)

	## 通知血条初始化显示
	if health_comp:
		health_changed.emit(health_comp.current_health, health_comp.max_health)


## ── 物理帧：移动 + 换方向 + 更新部位位置 ──
func _physics_process(delta: float) -> void:
	_direction_timer -= delta

	## 定时换方向
	if _direction_timer <= 0.0:
		_pick_new_direction()
		_reset_direction_timer()

	## 移动（只沿X或Y轴）
	_apply_movement(delta)

	## 更新位置历史
	_record_head_position()

	## 更新所有部位位置（跟随）
	_update_segment_positions()

	## 更新部位朝向（面向移动方向）
	_update_segment_rotations()

	## 更新图层顺序（Z-index）
	_update_draw_order()


func _apply_movement(delta: float) -> void:
	var dir_vec := Vector3.ZERO
	match _current_direction:
		Direction.UP:
			dir_vec = Vector3(0, 0, -1)
		Direction.DOWN:
			dir_vec = Vector3(0, 0, 1)
		Direction.LEFT:
			dir_vec = Vector3(-1, 0, 0)
		Direction.RIGHT:
			dir_vec = Vector3(1, 0, 0)

	velocity = dir_vec * move_speed
	move_and_slide()

	## 撞墙检测：撞到非玩家对象才换方向
	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var col := get_slide_collision(i)
			var collider := col.get_collider()
			if collider and not collider.is_in_group("player"):
				_pick_new_direction()
				break


func _record_head_position() -> void:
	## 记录头部当前位置到历史（[0]=当前，[1]=上一帧...）
	_head_position = global_position
	for i in range(_history_length - 1, 0, -1):
		_position_history[i] = _position_history[i - 1]
	_position_history[0] = _head_position


func _update_segment_positions() -> void:
	## 部位沿头部历史路径排列，形成自然曲线（解决脱节+僵硬问题）
	for i in range(1, _segments.size()):
		var seg: SegmentData = _segments[i]
		if not seg.is_alive or not is_instance_valid(seg.node):
			continue

		var target_distance := float(i) * segment_spacing
		var pos := _get_position_at_distance(target_distance)
		seg.node.global_position = pos


func _get_position_at_distance(distance: float) -> Vector3:
	## 从历史中寻找距离头部当前位置为 distance 的点
	var accumulated := 0.0
	for i in range(_position_history.size() - 1):
		var p1: Vector3 = _position_history[i]
		var p2: Vector3 = _position_history[i + 1]
		var d: float = p1.distance_to(p2)
		if accumulated + d >= distance:
			var t: float = (distance - accumulated) / d if d > 0.001 else 0.0
			return p1.lerp(p2, t)
		accumulated += d
	return _position_history[_position_history.size() - 1]


func _update_segment_rotations() -> void:
	if _segments.size() == 0:
		return

	## 头部：根据移动方向翻转（参考其他怪物的做法）
	var head: SegmentData = _segments[0]
	if head.sprite and velocity.length() > 0.01:
		var move_dir: Vector3 = velocity.normalized()
		move_dir.y = 0.0
		if move_dir.length() > 0.001:
			## 参考 EnemyBase：根据X方向决定翻转
			## 修正：面向前进方向（原逻辑是反的）
			head.sprite.flip_h = move_dir.x > 0.0

	## 身体：继承头部的朝向（或者根据前一个部位的方向）
	for i in range(1, _segments.size()):
		var seg: SegmentData = _segments[i]
		if not seg.is_alive or not is_instance_valid(seg.node) or not seg.sprite:
			continue
		## 让身体部位继承头部的flip_h（保持整体朝向一致）
		if head.sprite:
			seg.sprite.flip_h = head.sprite.flip_h


func _update_draw_order() -> void:
	## 根据移动方向设置绘制顺序（Z排序）
	## 左右下走：头在上层 → 尾部在下层
	## 上走：尾在上层 → 头在下层
	var going_up: bool = (_current_direction == Direction.UP)

	for i in range(_segments.size()):
		var seg: SegmentData = _segments[i]
		if not is_instance_valid(seg.node):
			continue
		var sprite: Sprite3D = seg.sprite
		if not sprite:
			continue
		if going_up:
			## 上走：索引越大（越靠尾）越上层
			sprite.sorting_offset = float(_segments.size() - i)
		else:
			## 左右下走：索引越小（越靠头）越上层
			sprite.sorting_offset = float(_segments.size() - i)


func _reset_direction_timer() -> void:
	_direction_interval = randf_range(3.0, 6.0)
	_direction_timer = _direction_interval


func _pick_new_direction() -> void:
	## 强制转向：上下→左右，左右→上下
	var current_is_vertical := (_current_direction == Direction.UP or _current_direction == Direction.DOWN)
	if current_is_vertical:
		_current_direction = Direction.LEFT if randf() < 0.5 else Direction.RIGHT
	else:
		_current_direction = Direction.UP if randf() < 0.5 else Direction.DOWN


## ── 创建所有部位 ──
func _create_segments() -> void:
	_segments.clear()

	for i in range(segment_count):
		var seg_data := SegmentData.new()

		## 使用动态创建（不依赖外部 .tscn）
		var seg_node: Node3D = _create_segment_node(i)
		if not seg_node:
			continue

		add_child(seg_node)
		seg_data.node = seg_node
		seg_data.is_head = (i == 0)

		## 获取子节点引用
		seg_data.sprite = seg_node.get_node_or_null("Sprite3D")
		seg_data.health_comp = seg_node.get_node_or_null("HealthComponent")
		seg_data.hit_box = seg_node.get_node_or_null("HitBox")
		seg_data.hurt_box = seg_node.get_node_or_null("HurtBox")

		## 设置贴图
		if seg_data.sprite:
			if i == 0:
				seg_data.sprite.texture = head_texture
			else:
				seg_data.sprite.texture = body_texture
			## 让图片中心对齐碰撞箱（y=30），而不是底部对齐地面
			## offset.y = 0 表示图片中心在position.y位置
			if seg_data.sprite.texture:
				seg_data.sprite.offset.y = 0

		## 设置血量
		seg_data.hp = segment_hp
		if seg_data.health_comp:
			seg_data.health_comp.max_health = segment_hp
			seg_data.health_comp.current_health = segment_hp
			seg_data.health_comp.died.connect(_on_segment_died.bind(i))
			seg_data.health_comp.damaged.connect(_on_segment_damaged.bind(i))

		## 连接HitBox（碰到玩家造成伤害）
		if seg_data.hit_box:
			seg_data.hit_box.body_entered.connect(_on_hit_box_entered.bind(i))

		## 连接HurtBox（被玩家子弹打到）
		if seg_data.hurt_box:
			seg_data.hurt_box.body_entered.connect(_on_hurt_box_entered.bind(i))
			seg_data.hurt_box.area_entered.connect(_on_hurt_box_entered.bind(i))

		## 设置初始位置：所有部位叠在头部同一个点，入场后通过历史路径自然拉开
		seg_node.global_position = global_position

		_segments.append(seg_data)

	## 初始化位置历史
	_record_head_position()


func _create_segment_node(_idx: int) -> Node3D:
	## 动态创建部位节点（备用，优先使用场景）
	var node := Node3D.new()
	node.name = "Segment" + str(_idx)

	## Sprite3D
	var sprite := Sprite3D.new()
	sprite.name = "Sprite3D"
	sprite.pixel_size = 0.04  ## 大两倍
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED  ## 开启billboard，始终面向摄像头（参考其他怪物）
	## 让精灵图中心与碰撞箱中心对齐（参考EnemyBase：Sprite3D在y=30.67）
	sprite.position = Vector3(0, 30.67, 0)
	node.add_child(sprite)

	## HealthComponent
	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	node.add_child(hc)

	## HitBox（碰到玩家造成伤害）
	var hit := Area3D.new()
	hit.name = "HitBox"
	hit.collision_layer = 2
	hit.collision_mask = 1
	var hit_shape := CollisionShape3D.new()
	hit_shape.name = "CollisionShape3D"
	var hit_box := BoxShape3D.new()
	hit_box.size = Vector3(70, 70, 70)  ## 匹配精灵图大小
	hit_shape.shape = hit_box
	## 让碰撞箱中心与精灵图中心对齐（都在y=30.67）
	hit_shape.position = Vector3(0, 30.67, 0)
	hit.add_child(hit_shape)
	node.add_child(hit)

	## HurtBox（被玩家子弹打到）
	var hurt := Area3D.new()
	hurt.name = "HurtBox"
	hurt.collision_layer = 2  ## 敌人层，让子弹能检测到
	hurt.collision_mask = 8    ## 检测Layer 8（玩家子弹）
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.name = "CollisionShape3D"
	var hurt_box := BoxShape3D.new()
	hurt_box.size = Vector3(70, 70, 70)  ## 匹配精灵图大小
	hurt_shape.shape = hurt_box
	## 让碰撞箱中心与精灵图中心对齐（都在y=30.67）
	hurt_shape.position = Vector3(0, 30.67, 0)
	hurt.add_child(hurt_shape)
	node.add_child(hurt)

	return node


## ── 部位受伤/死亡处理 ──
func _on_segment_died(_who: Node, seg_index: int) -> void:
	if seg_index < 0 or seg_index >= _segments.size():
		return

	print("WormBoss: 部位 ", seg_index, " 被打烂！")

	var seg: SegmentData = _segments[seg_index]
	seg.is_alive = false

	## 总血量已在 _on_segment_damaged 中实时同步，这里不再重复扣除
	## 确保血条显示正确（死亡瞬间刷新）
	if health_comp:
		health_changed.emit(health_comp.current_health, health_comp.max_health)

	## 如果死的是最后一个部位，整条虫死亡
	if seg_index == _segments.size() - 1:
		_remove_segment(seg_index)
		if _segments.is_empty():
			_on_whole_worm_died()
		return

	## 发射十字方向红色子弹（上下左右各一发）
	_fire_cross_burst(seg)

	## 断开：分裂成两条虫dsd
	_split_at_index(seg_index)


func _on_segment_damaged(amount: float, _source: Node, seg_index: int) -> void:
	## 边界检查（防止信号索引过时导致越界）
	if seg_index < 0 or seg_index >= _segments.size():
		return

	## 受击闪白效果
	var seg: SegmentData = _segments[seg_index]
	if seg and seg.sprite:
		var tween := create_tween()
		tween.tween_property(seg.sprite, "modulate", Color(2.5, 0.5, 0.5, 1.0), 0.05)
		tween.tween_property(seg.sprite, "modulate", Color.WHITE, 0.2)

	## 同步总血量
	if health_comp:
		health_comp.current_health = max(health_comp.current_health - amount, 0.0)
		health_changed.emit(health_comp.current_health, health_comp.max_health)


func _split_at_index(split_idx: int) -> void:
	## 在 split_idx 处断开，split_idx 及之后 → 新虫子
	## split_idx 部位已死，所以新虫子从头是 split_idx+1

	if split_idx + 1 >= _segments.size():
		_remove_segment(split_idx)
		return

	print("WormBoss: 在部位 ", split_idx, " 处断开，分裂成两条虫")

	## 1. 保存死部位节点引用（在切片之前！）
	var dead_node: Node3D = _segments[split_idx].node

	## 2. 收集后半段数据（split_idx+1 开始）
	var new_segments_data: Array[SegmentData] = []
	for i in range(split_idx + 1, _segments.size()):
		new_segments_data.append(_segments[i])

	## 3. 本虫保留前半段（0 ~ split_idx-1）
	_segments = _segments.slice(0, split_idx)

	## 4. 删除死部位节点
	if is_instance_valid(dead_node):
		dead_node.queue_free()

	## 5. 创建新虫子（先设标志再add_child，添加到和原虫相同的容器）
	var new_worm: WormBoss = load("res://scenes/enemies/layer1/WormBoss.tscn").instantiate()
	new_worm._is_split_worm = true
	if get_parent():
		get_parent().add_child(new_worm)
	elif _original_scene_root:
		_original_scene_root.add_child(new_worm)

	new_worm.global_position = new_segments_data[0].node.global_position if new_segments_data.size() > 0 else global_position
	new_worm.name = "WormBoss_Split"
	new_worm.head_texture = head_texture
	new_worm.body_texture = body_texture
	new_worm.move_speed = move_speed
	new_worm.segment_spacing = segment_spacing

	## 6. 把后半段部位的节点 reparent 到新虫子
	for seg_data in new_segments_data:
		if is_instance_valid(seg_data.node):
			seg_data.node.reparent(new_worm)

	## 7. 新虫子第一个部位改为头部贴图
	if new_segments_data.size() > 0:
		var new_head: SegmentData = new_segments_data[0]
		if new_head.sprite and head_texture:
			new_head.sprite.texture = head_texture
		new_head.is_head = true

	## 8. 应用部位数据到新虫子（接管数据 + 初始化历史 + 重连信号）
	new_worm._apply_segment_data(new_segments_data)

	## 9. 新虫子初始化
	new_worm._pick_new_direction()
	new_worm._reset_direction_timer()
	new_worm.set_physics_process(true)

	## 10. 重新计算原虫子的总血量（只保留剩余部位）
	_recalculate_total_health()

	## 11. 如果本虫没有部位了（头部死亡），移除本虫
	if _segments.size() == 0:
		print("WormBoss: 头部死亡，原虫移除")
		queue_free()


func _apply_segment_data(data: Array) -> void:
	## 供分裂时新虫子使用，直接接收部位数据
	_segments.clear()
	for d in data:
		_segments.append(d)
	## 重新设置 parent（节点的实际 reparent 需要在外面做）
	## 这里只接管数据引用

	## 重新计算总血量（根据实际接管的部位数量和剩余血量）
	_recalculate_total_health()

	## 重新初始化位置历史（用部位实际位置构建，防止黏在一起或横着排）
	if _segments.size() > 0:
		## 收集所有部位的当前位置（头部 → 尾部）
		var seg_positions: Array[Vector3] = []
		for seg: SegmentData in _segments:
			if is_instance_valid(seg.node):
				seg_positions.append(seg.node.global_position)

		_position_history.resize(_history_length)
		if seg_positions.size() > 0:
			## 沿部位排列方向填充历史路径（索引0=头部，索引大=尾部方向）
			var head_pos: Vector3 = seg_positions[0]
			var tail_pos: Vector3 = seg_positions[seg_positions.size() - 1]
			var dir: Vector3 = head_pos - tail_pos
			var total_dist: float = dir.length()
			if total_dist > 0.001:
				dir = dir.normalized()
			else:
				dir = Vector3(1, 0, 0)

			for i in range(_history_length):
				var t: float = clamp(float(i) * segment_spacing / max(total_dist, 0.001), 0.0, 1.0)
				_position_history[i] = head_pos - dir * total_dist * t
		else:
			for i in range(_history_length):
				_position_history[i] = Vector3.ZERO

	## 开启物理处理（分裂虫在_ready中跳过了set_physics_process(true)）
	set_physics_process(true)

	## 重新连接所有信号到本虫子（reparent后信号还连着旧虫子，必须重连）
	for i in range(_segments.size()):
		var seg: SegmentData = _segments[i]
		if not seg or not is_instance_valid(seg.node):
			continue

		## 断开旧信号（尝试断开，忽略错误）
		if seg.health_comp:
			seg.health_comp.died.disconnect(_on_segment_died)
			seg.health_comp.damaged.disconnect(_on_segment_damaged)
			seg.health_comp.died.connect(_on_segment_died.bind(i))
			seg.health_comp.damaged.connect(_on_segment_damaged.bind(i))

		if seg.hit_box:
			seg.hit_box.body_entered.disconnect(_on_hit_box_entered)
			seg.hit_box.body_entered.connect(_on_hit_box_entered.bind(i))

		if seg.hurt_box:
			seg.hurt_box.body_entered.disconnect(_on_hurt_box_entered)
			seg.hurt_box.area_entered.disconnect(_on_hurt_box_entered)
			seg.hurt_box.body_entered.connect(_on_hurt_box_entered.bind(i))
			seg.hurt_box.area_entered.connect(_on_hurt_box_entered.bind(i))


## 重新计算总血量（分裂后调用）
func _recalculate_total_health() -> void:
	## 重新计算总血量 = 所有存活部位的剩余血量之和
	if not health_comp:
		return
	
	var total: float = 0.0
	for seg: SegmentData in _segments:
		if seg.is_alive and seg.health_comp:
			total += seg.health_comp.current_health
	
	health_comp.max_health = max(total, 1.0)
	health_comp.current_health = total
	health_changed.emit(total, health_comp.max_health)


func _remove_segment(idx: int) -> void:
	## 移除某部位（从场景和数组中都删除）
	if idx < 0 or idx >= _segments.size():
		return
	var seg: SegmentData = _segments[idx]

	## 先隐藏建模（避免queue_free延迟导致残留）
	if seg.sprite:
		seg.sprite.visible = false

	## 断开信号（防止数组移除后信号回调使用旧索引越界）
	if seg.health_comp:
		if seg.health_comp.died.is_connected(_on_segment_died):
			seg.health_comp.died.disconnect(_on_segment_died)
		if seg.health_comp.damaged.is_connected(_on_segment_damaged):
			seg.health_comp.damaged.disconnect(_on_segment_damaged)
	if seg.hit_box and seg.hit_box.body_entered.is_connected(_on_hit_box_entered):
		seg.hit_box.body_entered.disconnect(_on_hit_box_entered)

	if is_instance_valid(seg.node):
		seg.node.queue_free()
	_segments.remove_at(idx)

	## 重新连接后续部位的信号（索引已更新，避免越界）
	for i in range(idx, _segments.size()):
		var s: SegmentData = _segments[i]
		if s.health_comp:
			if s.health_comp.died.is_connected(_on_segment_died):
				s.health_comp.died.disconnect(_on_segment_died)
			if s.health_comp.damaged.is_connected(_on_segment_damaged):
				s.health_comp.damaged.disconnect(_on_segment_damaged)
			s.health_comp.died.connect(_on_segment_died.bind(i))
			s.health_comp.damaged.connect(_on_segment_damaged.bind(i))
		if s.hit_box:
			if s.hit_box.body_entered.is_connected(_on_hit_box_entered):
				s.hit_box.body_entered.disconnect(_on_hit_box_entered)
			s.hit_box.body_entered.connect(_on_hit_box_entered.bind(i))


func _on_whole_worm_died() -> void:
	print("WormBoss: 整条虫死亡")
	if health_comp:
		health_comp.current_health = 0.0
		health_changed.emit(0.0, health_comp.max_health)
		## 手动触发 died 信号，让 Room.gd 的 _on_enemy_died 被调用（生成洞等）
		health_comp.died.emit(self)
	worm_died.emit()
	queue_free()


## ── 部位HitBox碰到玩家造成伤害 ──
func _on_hit_box_entered(body: Node3D, seg_index: int) -> void:
	if body.is_in_group("player"):
		var player_hc = body.get_node_or_null("HealthComponent")
		if player_hc:
			player_hc.apply_damage(15.0, self)


## ── 部位HurtBox被玩家子弹打到 ──
func _on_hurt_box_entered(body: Node, seg_index: int) -> void:
	## body 可能是 Node3D（body_entered）或 Area3D（area_entered）
	if body.is_in_group("player_bullet"):
		## 获取子弹伤害值
		var damage: float = 10.0
		if body.has_method("get_damage"):
			damage = body.call("get_damage")
		elif "damage" in body:
			damage = body.get("damage")

		## 对该部位造成伤害
		if seg_index >= 0 and seg_index < _segments.size():
			var seg: SegmentData = _segments[seg_index]
			if seg and seg.health_comp and seg.is_alive:
				seg.health_comp.apply_damage(damage, body)
				## 受击闪白
				if seg.sprite:
					var tween := create_tween()
					tween.tween_property(seg.sprite, "modulate", Color(2.5, 0.5, 0.5, 1.0), 0.05)
					tween.tween_property(seg.sprite, "modulate", Color.WHITE, 0.2)

		## 销毁子弹
		if body.has_method("queue_free"):
			body.queue_free()


## ── 入场动画 ──
func play_spawn_animation() -> void:
	set_physics_process(false)

	## 所有部位一起淡入缩放（从一个点展开）
	var tween := create_tween()
	tween.set_parallel(true)
	for seg: SegmentData in _segments:
		if seg.sprite:
			seg.sprite.modulate.a = 0.0
			seg.sprite.scale = Vector3(0.2, 0.2, 0.2)
			tween.tween_property(seg.sprite, "modulate:a", 1.0, 0.5)
			tween.tween_property(seg.sprite, "scale", Vector3.ONE, 0.5)
	await tween.finished

	set_physics_process(true)


## ── 十字弹幕：被打爆的部位向上下左右发射红色子弹 ──
func _fire_cross_burst(seg: SegmentData) -> void:
	if not PROJECTILE_SCENE:
		return

	var spawn_pos: Vector3 = seg.node.global_position + Vector3.UP * 2.0
	var dirs: Array[Vector2] = [
		Vector2(0, -1),  ## 上
		Vector2(0, 1),   ## 下
		Vector2(-1, 0),  ## 左
		Vector2(1, 0),   ## 右
	]

	for dir in dirs:
		var proj := PROJECTILE_SCENE.instantiate() as Area3D
		if not proj:
			continue

		get_tree().current_scene.add_child(proj)
		proj.global_position = spawn_pos

		if proj.has_method("set_direction"):
			proj.set_direction(dir)
		if proj.has_method("set_speed"):
			proj.set_speed(120.0)
