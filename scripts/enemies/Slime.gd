## 史莱姆 - 漫无目的游荡，无接触伤害，不追击不攻击
## 结构完全参照 EnemyBase.gd，只保留游荡逻辑
class_name Slime
extends CharacterBody3D

signal died(who: Node)
signal slime_died()  ## 用于Room.gd检测敌人数量

@export var max_health: float = 30.0
@export var move_speed: float = 40.0
@export var stop_time_min: float = 1.0
@export var stop_time_max: float = 2.0
@export var walk_time_min: float = 2.0
@export var walk_time_max: float = 3.0

## 组件（与 EnemyBase 完全一致，从场景节点获取）
@onready var anim_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var health_comp: HealthComponent = $HealthComponent
@onready var detection: Area3D = $Detection

## 内部状态
enum State { STOPPED, WALKING }
var _state: int = State.STOPPED
var _timer: float = 0.0
var _walk_dir: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO

## 每个史莱姆独立的随机数生成器，避免所有史莱姆行为同步
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("enemy")

	## 每个史莱姆用独立的随机种子，避免行为同步
	_rng.randomize()

	## 连接HealthComponent信号（与EnemyBase一致）
	if health_comp:
		health_comp.died.connect(_on_health_depleted)
		health_comp.health_changed.connect(func(_c, _m): pass)  ## 史莱姆不需要对外发血量变化

	## 初始状态：加一点随机偏移，让每只史莱姆的计时器不同步
	_enter_stop_state()
	_timer += _rng.randf_range(0.0, 1.5)


func _physics_process(delta: float) -> void:
	_timer -= delta

	match _state:
		State.STOPPED:
			## 停止状态：带惯性减速，播放idle动画
			_velocity = _velocity.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
			velocity = _velocity
			move_and_slide()
			if anim_sprite and anim_sprite.animation != "idle":
				anim_sprite.play("idle")
			if _timer <= 0.0:
				_enter_walk_state()

		State.WALKING:
			## 行走状态：带惯性的移动
			var target_vel := _walk_dir * move_speed
			_velocity = _velocity.lerp(target_vel, 1.0 - exp(-5.0 * delta))
			velocity = _velocity
			move_and_slide()
			if anim_sprite and anim_sprite.animation != "walk":
				anim_sprite.play("walk")
			## 墙壁检测：碰到墙就换方向
			if get_slide_collision_count() > 0:
				_pick_new_direction()
			if _timer <= 0.0:
				_enter_stop_state()


## 进入停止状态
func _enter_stop_state() -> void:
	_state = State.STOPPED
	_timer = _rng.randf_range(stop_time_min, stop_time_max)


## 进入行走状态
func _enter_walk_state() -> void:
	_state = State.WALKING
	_timer = _rng.randf_range(walk_time_min, walk_time_max)
	_pick_new_direction()


## 随机选一个行走方向
func _pick_new_direction() -> void:
	var angle: float = _rng.randf_range(0.0, TAU)
	_walk_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()


## 受到伤害（与EnemyBase接口一致，供外部调用）
func take_damage(amount: float) -> void:
	if health_comp and is_instance_valid(health_comp):
		health_comp.apply_damage(amount)


## 血量耗尽回调
func _on_health_depleted(_who: Node = null) -> void:
	died.emit(self)
	slime_died.emit()
	## 击杀奖励通过 Room.gd 的 slime_killed 信号处理
	queue_free()


## 获取击杀奖励（与EnemyBase.get_drops()接口一致）
func get_drops() -> Dictionary:
	return {"coins": 1, "score": 1}


## 生成动画：淡入 + 缩放，期间无敌且不动，持续 0.7 秒（与EnemyBase一致）
func play_spawn_animation() -> void:
	set_physics_process(false)
	if health_comp:
		health_comp.invincible = true

	## 初始状态：透明 + 缩小
	anim_sprite.modulate.a = 0.0
	anim_sprite.scale = Vector3(0.2, 0.2, 0.2)

	## 动画：0.7 秒淡入并放大
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(anim_sprite, "modulate:a", 1.0, 0.7)
	tween.tween_property(anim_sprite, "scale", Vector3.ONE, 0.7)
	await tween.finished

	## 恢复：启用物理处理，取消无敌
	set_physics_process(true)
	if health_comp:
		health_comp.invincible = false
