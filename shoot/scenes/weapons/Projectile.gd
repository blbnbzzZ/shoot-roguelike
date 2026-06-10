## 玩家子弹 3D 版本（Area3D + Sprite3D）
## 修复：同时支持 body_entered 信号和手动碰撞检测，解决 Area3D 高速移动时检测不到的问题
extends Area3D

signal enemy_hit()

@export var speed: float = 400.0
@export var damage: float = 12.0

var _direction: Vector2 = Vector2.RIGHT
var _velocity: Vector3 = Vector3.ZERO
## 用于手动碰撞检测，记录上一帧位置
var _prev_position: Vector3 = Vector3.ZERO

@onready var life_timer: Timer = $LifeTimer
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_update_velocity()
	life_timer.timeout.connect(queue_free)
	life_timer.start(3.0)

	## 连接信号
	body_entered.connect(_on_body_hit)
	area_entered.connect(_on_area_hit)

	## 碰撞层：Layer 8=子弹层；掩码：Layer 2=敌人(2) + Layer 3=墙壁(4) + Layer 5=门阻挡(16) = 22
	collision_layer = 8   ## Layer 4: Projectile
	collision_mask = 22   ## 2 + 4 + 16 = 22

	## 碰撞体半径
	if _collision_shape and _collision_shape.shape is SphereShape3D:
		(_collision_shape.shape as SphereShape3D).radius = 5.0

	## 检测子弹是否生成在墙内，如果是则弹出到墙外
	_resolve_wall_overlap()

	monitoring = true
	monitorable = true


func _resolve_wall_overlap() -> void:
	## 检测子弹是否生成在墙壁碰撞体内，如果是则朝反方向弹出到墙外
	if not _collision_shape:
		return
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _collision_shape.shape
	query.transform = global_transform
	query.collision_mask = 4   ## 墙壁层
	var results := space_state.intersect_shape(query, 1)
	if results.size() > 0:
		## 子弹在墙内，沿发射反方向弹出 15 单位到墙外
		var push_dir := -_velocity.normalized()
		if push_dir.is_zero_approx():
			push_dir = Vector3.BACK
		global_position += push_dir * 15.0


func _physics_process(delta: float) -> void:
	_prev_position = global_position
	global_position += _velocity * delta
	
	## 使用 intersect_shape 直接查询物理服务器，更可靠地检测碰撞
	if _collision_shape and _collision_shape.shape:
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _collision_shape.shape
		query.transform = global_transform
		query.collision_mask = collision_mask
		var results := space_state.intersect_shape(query, 10)
		for result in results:
			var body := result.collider as Node3D
			if body and body != get_parent() and not body.is_queued_for_deletion():
				## 修复：同时检查墙壁层(4)和子弹阻挡层(16)，确保子弹被墙和子弹墙正确销毁
				if body.collision_layer & 4 != 0 or body.collision_layer & 16 != 0:
					queue_free()
					return
				_on_body_hit(body)
				return
	
	## 备用：射线检测防止隧道效应
	## 注意：from 点需要向前偏移，避免从 Area3D 内部出发检测到自身
	if _velocity.length() > 200.0:
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.new()
		var radius := 6.0
		if _collision_shape and _collision_shape.shape is SphereShape3D:
			radius = (_collision_shape.shape as SphereShape3D).radius + 1.0
		var offset := _velocity.normalized() * radius
		query.from = _prev_position + offset
		query.to = global_position + offset
		query.collision_mask = collision_mask
		query.collide_with_areas = true
		var result := space_state.intersect_ray(query)
		if result:
			var hit_body := result.collider as Node3D
			if hit_body and hit_body != get_parent() and hit_body != self:
				if hit_body.collision_layer & 4 != 0:
					queue_free()
					return
				_on_body_hit(hit_body)
				return


func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized()
	_update_velocity()


func _update_velocity() -> void:
	_velocity = Vector3(_direction.x, 0.0, _direction.y) * speed


func _on_body_hit(body: Node3D) -> void:
	## 忽略自己发出的子弹（如果有）
	if body == get_parent():
		print("Projectile hit parent, ignoring")
		return

	## 如果是墙壁或子弹阻挡墙，直接销毁子弹
	if body.has_method("get_collision_layer") or "collision_layer" in body:
		## 修复：同时检查墙壁层(4)和子弹阻挡层(16)
		if body.collision_layer & 4 != 0 or body.collision_layer & 16 != 0:
			print("Projectile hit wall/barrier, destroying")
			queue_free()
			return

	print("Projectile hit body: ", body.name, " class: ", body.get_class(), " groups: ", body.get_groups(), " collision_layer: ", body.get("collision_layer"))
	
	## 尝试对任何有 HealthComponent 的物体造成伤害
	_try_damage(body)
	queue_free()


func _on_area_hit(area: Area3D) -> void:
	## 处理击中 Area3D（如敌人的 HitBox）
	var parent := area.get_parent()
	if parent and parent != get_parent():
		print("Projectile hit area: ", area.name, " parent: ", parent.name)
		_try_damage(parent)
		queue_free()


func _try_damage(target: Node) -> void:
	print("Trying to damage: ", target.name, " type: ", target.get_class(), " groups: ", target.get_groups())
	
	## 方法1: 直接查找目标节点的 HealthComponent
	var hc := target.get_node_or_null("HealthComponent") as HealthComponent
	if not hc:
		hc = target.find_child("HealthComponent", true, false) as HealthComponent
	
	## 方法2: 如果 target 是 Area3D，获取其父节点再查找
	if not hc and target is Area3D:
		var parent := target.get_parent()
		if parent:
			hc = parent.get_node_or_null("HealthComponent") as HealthComponent
			if not hc:
				hc = parent.find_child("HealthComponent", true, false) as HealthComponent
	
	## 方法3: 遍历所有子节点，查找 HealthComponent
	if not hc:
		for child in target.get_children():
			if child is HealthComponent:
				hc = child as HealthComponent
				break
	
	## 方法4: 如果还是没找到，尝试在祖辈节点中查找
	if not hc:
		var current := target.get_parent()
		var depth := 0
		while current and depth < 5:
			hc = current.get_node_or_null("HealthComponent") as HealthComponent
			if hc:
				break
			hc = current.find_child("HealthComponent", true, false) as HealthComponent
			if hc:
				break
			current = current.get_parent()
			depth += 1
	
	if hc:
		print("Found HealthComponent on ", target.name, "! Applying damage: ", damage, " invincible: ", hc.invincible)
		if not hc.invincible:
			hc.apply_damage(damage, self)
			enemy_hit.emit()
			print("Damage applied successfully!")
		else:
			print("Target is invincible, no damage applied")
	else:
		print("ERROR: No HealthComponent found on ", target.name, "! Collision layer: ", target.get("collision_layer"))
		
		## 调试：打印目标节点的所有子节点
		print("Target children:")
		for child in target.get_children():
			print("  - ", child.name, " type: ", child.get_class())
