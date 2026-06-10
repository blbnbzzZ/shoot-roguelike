## 敌人子弹 3D 版本（Area3D + Sprite3D）
extends Area3D

@export var speed: float = 200.0
@export var damage: float = 8.0

var _direction: Vector2 = Vector2.RIGHT
var _velocity: Vector3 = Vector3.ZERO

@onready var life_timer: Timer = $LifeTimer


func _ready() -> void:
	## 宽限期：刚生成时不检测碰撞，避免贴墙时子弹在墙内生成导致立即自伤
	monitoring = false

	_update_velocity()
	life_timer.timeout.connect(queue_free)
	life_timer.start(4.0)
	body_entered.connect(_on_body_hit)

	## 碰撞层：Layer 8=敌人子弹；掩码：Layer 1=玩家(1) + Layer 3=墙壁(4) + Layer 5=门阻挡(16) = 21
	collision_layer = 8
	collision_mask = 21

	## 宽限期 0.05 秒后恢复碰撞检测
	var timer := get_tree().create_timer(0.05)
	timer.timeout.connect(func(): monitoring = true)


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta


func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized()
	_update_velocity()


func set_speed(new_speed: float) -> void:
	speed = new_speed
	_update_velocity()


func _update_velocity() -> void:
	_velocity = Vector3(_direction.x, 0.0, _direction.y) * speed


func _on_body_hit(body: Node3D) -> void:
	## 忽略自己发出的子弹（如果有）
	if body == get_parent():
		return
	## 如果是墙壁或子弹阻挡墙，直接销毁子弹
	## 修复：同时检查墙壁层(4)和子弹阻挡层(16)
	if body.collision_layer & 4 != 0 or body.collision_layer & 16 != 0:
		queue_free()
		return
	## 尝试对任何有 HealthComponent 的物体造成伤害
	_try_damage(body)
	queue_free()


func _try_damage(target: Node) -> void:
	## 直接查找 HealthComponent，不依赖组
	var hc := target.get_node_or_null("HealthComponent") as HealthComponent
	if not hc:
		var parent := target.get_parent()
		if parent:
			hc = parent.get_node_or_null("HealthComponent") as HealthComponent
	if hc and not hc.invincible:
		hc.apply_damage(damage, self)
