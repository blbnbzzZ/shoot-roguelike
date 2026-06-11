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
@export var segment_spacing: float = 3.96    ## 部位间距（原1.32的三倍）
@export var move_speed: float = 80.0        ## 与ZapRat相同
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

	## 简易撞墙检测：如果移动后速度异常（被阻挡），换方向
	if get_slide_collision_count() > 0:
		_pick_new_direction()
		_reset_direction_timer()


func _record_head_position() -> void:
	## 记录头部当前位置到历史
	_head_position = global_position
	for i in range(_history_length - 1, 0, -1):
		_position_history[i] = _position_history[i - 1]
	_position_history[0] = _head_position


func _update_segment_positions() -> void:
	## 每个部位跟随头部位置历史中的某个偏移位置
	for i in range(1, _segments.size()):
		var seg: SegmentData = _segments[i]
		if not seg.is_alive or not is_instance_valid(seg.node):
			continue

		## 该部位对应的历史位置索引（越后面的部位越久远）
		var history_idx: int = mini(i * 5, _history_length - 1)
		var target_pos: Vector3 = _position_history[history_idx]

		## 平滑移动到目标位置
		seg.node.global_position = seg.node.global_position.lerp(target_pos, 0.15)


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
	_direction_interval = randf_range(direction_change_min, direction_change_max)
	_direction_timer = _direction_interval


func _pick_new_direction() -> void:
	## 随机选方向（不与上次相同）
	var dirs := [Direction.UP, Direction.DOWN, Direction.LEFT, Direction.RIGHT]
	dirs.erase(_current_direction)
	_current_direction = dirs[randi() % dirs.size()]


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
			## 让图片底部对齐地面（不陷进地下）
			if seg_data.sprite.texture:
				seg_data.sprite.offset.y = seg_data.sprite.texture.get_height() / 2.0

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

		## 设置初始位置（沿移动方向排列）
		var offset: Vector3 = Vector3(-i * segment_spacing, 0, 0)
		seg_node.global_position = global_position + offset

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
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
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
	var box := BoxShape3D.new()
	box.size = Vector3(8, 8, 8)  ## 大两倍
	hit_shape.shape = box
	hit.add_child(hit_shape)
	node.add_child(hit)

	## HurtBox（被玩家子弹打到）
	var hurt := Area3D.new()
	hurt.name = "HurtBox"
	hurt.collision_layer = 2  ## 敌人层，让子弹能检测到
	hurt.collision_mask = 1
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.name = "CollisionShape3D"
	var hurt_box := BoxShape3D.new()
	hurt_box.size = Vector3(8, 8, 8)  ## 大两倍
	hurt_shape.shape = hurt_box
	hurt.add_child(hurt_shape)
	node.add_child(hurt)

	return node


## ── 部位受伤/死亡处理 ──
func _on_segment_died(who: Node, seg_index: int) -> void:
	if seg_index < 0 or seg_index >= _segments.size():
		return

	print("WormBoss: 部位 ", seg_index, " 被打烂！")

	var seg: SegmentData = _segments[seg_index]
	seg.is_alive = false

	## 同步总血量（扣除一整段）
	if health_comp:
		health_comp.current_health = max(health_comp.current_health - segment_hp, 0.0)
		health_changed.emit(health_comp.current_health, health_comp.max_health)

	## 如果死的是最后一个部位，整条虫死亡
	if seg_index == _segments.size() - 1:
		_remove_segment(seg_index)
		if _segments.is_empty():
			_on_whole_worm_died()
		return

	## 发射十字方向红色子弹（上下左右各一发）
	_fire_cross_burst(seg)

	## 断开：分裂成两条虫
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
		## 后面没有部位了
		_remove_segment(split_idx)
		return

	print("WormBoss: 在部位 ", split_idx, " 处断开，分裂成两条虫")

	## 先收集后半段数据（在移除死部位之前，索引还有效）
	var new_segments_data: Array[SegmentData] = []
	for i in range(split_idx + 1, _segments.size()):
		new_segments_data.append(_segments[i])

	## 移除死掉的部位（现在 split_idx 还有效）
	_remove_segment(split_idx)

	## 从本虫移除后半段（死掉的部位已删，保留 0 ~ split_idx-1）
	_segments = _segments.slice(0, split_idx)

	## 创建新虫子
	var new_worm: WormBoss = load("res://scenes/enemies/layer1/WormBoss.tscn").instantiate()
	if _original_scene_root:
		_original_scene_root.add_child(new_worm)
	else:
		get_parent().add_child(new_worm)

	new_worm.global_position = new_segments_data[0].node.global_position
	new_worm.name = "WormBoss_Split"
	new_worm._is_split_worm = true
	new_worm.head_texture = head_texture
	new_worm.body_texture = body_texture
	new_worm.move_speed = move_speed
	new_worm.segment_spacing = segment_spacing

	## 把后半段部位的节点 reparent 到新虫子（关键！）
	for seg_data in new_segments_data:
		if is_instance_valid(seg_data.node):
			seg_data.node.reparent(new_worm)

	## 新虫子的第一个部位改为头部贴图
	if new_segments_data.size() > 0:
		var new_head: SegmentData = new_segments_data[0]
		if new_head.sprite and head_texture:
			new_head.sprite.texture = head_texture
		new_head.is_head = true

	## 应用部位数据到新虫子
	new_worm._apply_segment_data(new_segments_data)

	## 新虫子初始化
	new_worm._pick_new_direction()
	new_worm._reset_direction_timer()
	new_worm.set_physics_process(true)


func _apply_segment_data(data: Array) -> void:
	## 供分裂时新虫子使用，直接接收部位数据
	_segments.clear()
	for d in data:
		_segments.append(d)
	## 重新设置 parent（节点的实际 reparent 需要在外面做）
	## 这里只接管数据引用

	## 重新初始化位置历史（防止新虫子从地图外飞入）
	if _segments.size() > 0:
		var head_pos: Vector3 = _segments[0].node.global_position
		_position_history.resize(_history_length)
		for i in range(_history_length):
			_position_history[i] = head_pos


func _remove_segment(idx: int) -> void:
	## 移除某部位（从场景和数组中都删除）
	if idx < 0 or idx >= _segments.size():
		return
	var seg: SegmentData = _segments[idx]

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
	worm_died.emit()
	queue_free()


## ── 部位HitBox碰到玩家造成伤害 ──
func _on_hit_box_entered(body: Node3D, seg_index: int) -> void:
	if body.is_in_group("player"):
		var player_hc = body.get_node_or_null("HealthComponent")
		if player_hc:
			player_hc.apply_damage(15.0, self)


## ── 入场动画 ──
func play_spawn_animation() -> void:
	set_physics_process(false)
	if _segments.size() > 0 and _segments[0].sprite:
		var spr: Sprite3D = _segments[0].sprite
		spr.modulate.a = 0.0
		spr.scale = Vector3(0.2, 0.2, 0.2)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(spr, "modulate:a", 1.0, 0.5)
		tween.tween_property(spr, "scale", Vector3.ONE, 0.5)
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
