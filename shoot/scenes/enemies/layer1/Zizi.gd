## 籽籽 — 第一大层第2、3小关专属敌人
## 草莓团子的远房亲戚，移动速度一样，但会周期性发射草莓籽子弹
class_name Zizi
extends EnemyBase

## ========== 模型摆动参数（和草莓团子相同） ==========
const BOUNCE_Y_AMPLITUDE: float = 15.0
const BOUNCE_Y_SPEED: float = 8.0

## ========== 包抄追踪参数（和草莓团子相同） ==========
var _flank_angle: float = 0.0
const FLANK_DRIFT_SPEED: float = 0.5
const MAX_FLANK_ANGLE: float = deg_to_rad(40.0)

## ========== 远程攻击参数 ==========
## 追击时间随机范围（每只怪物独立）
@export var shoot_interval_min: float = 2.0
@export var shoot_interval_max: float = 4.0

## 追击计时器（每只怪物独立，不共享）
var _chase_timer: float = 0.0
## 下次射击的时间间隔（随机生成）
var _next_shoot_time: float = 0.0
## 是否正在追击（用于控制计时器）
var _is_chasing: bool = false

var _bob_time: float = 0.0


func _ready() -> void:
	## 设置移动速度为和草莓团子一样
	move_speed = 80.0
	
	## 标记为远程怪物（会发射子弹）
	shoot = true
	
	## 初始化独立计时器：随机起始相位
	_bob_time = randf_range(0.0, PI * 2)
	_flank_angle = randf_range(-MAX_FLANK_ANGLE, MAX_FLANK_ANGLE)
	
	## 初始化下次射击时间（随机2-4秒，每只怪物不同）
	_reset_shoot_timer()
	
	## 调用父类 _ready()
	super._ready()


## 重置射击计时器（每只怪物独立计算）
func _reset_shoot_timer() -> void:
	_next_shoot_time = randf_range(shoot_interval_min, shoot_interval_max)
	_chase_timer = 0.0


## 覆盖基类追踪逻辑：包抄 + 周期性射击
func _process_chase(delta: float) -> void:
	if not _player:
		_enter_state(State.IDLE)
		_is_chasing = false
		return
	
	_is_chasing = true
	
	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	var dir: Vector3 = to_player.normalized()
	
	## 缓慢漂移偏角，让路径呈弧线
	_flank_angle += randf_range(-FLANK_DRIFT_SPEED, FLANK_DRIFT_SPEED) * delta
	_flank_angle = clamp(_flank_angle, -MAX_FLANK_ANGLE, MAX_FLANK_ANGLE)
	dir = dir.rotated(Vector3.UP, _flank_angle)
	
	velocity = dir * move_speed
	if sprite:
		sprite.flip_h = dir.x < 0.0
	
	## 追击计时：累计追击时间
	_chase_timer += delta
	
	## 到达射击时间间隔 → 发射子弹
	if _chase_timer >= _next_shoot_time:
		_fire_projectile()
		_reset_shoot_timer()  ## 重置计时器（随机2-4秒）
	
	## 靠近玩家后进入攻击状态
	if dist < 15.0:
		_enter_state(State.ATTACK)


## 覆盖攻击状态：继续追击 + 周期性射击
func _process_attack(delta: float) -> void:
	if not _player:
		_enter_state(State.IDLE)
		_is_chasing = false
		return
	
	_is_chasing = true
	
	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	var dir: Vector3 = to_player.normalized()
	
	## 攻击状态时停止移动（准备射击）
	velocity = Vector3.ZERO
	
	## 追击计时：累计时间
	_chase_timer += delta
	
	## 到达射击时间间隔 → 发射子弹
	if _chase_timer >= _next_shoot_time:
		_fire_projectile()
		_reset_shoot_timer()
	
	## 玩家跑远了，继续追击
	if dist > 25.0:
		_enter_state(State.CHASE)


## 发射子弹（覆盖父类方法，使用独立计时器）
func _fire_projectile() -> void:
	if not _player or not PROJECTILE_SCENE:
		return
	
	## 实例化子弹
	var proj := PROJECTILE_SCENE.instantiate() as Node3D
	var dir: Vector3 = (_player.global_position - global_position)
	dir.y = 0.0
	
	if proj.has_method("set_direction"):
		proj.set_direction(Vector2(dir.x, dir.z))
	
	## 添加到场景
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(0, 1, 0)
	
	## 播放射击动画/音效（可选）
	_play_shoot_effect()


## 射击特效（可选）
func _play_shoot_effect() -> void:
	## TODO: 添加射击动画、音效、粒子效果
	pass


## 上下弹跳动画（和草莓团子相同）
func _process(delta: float) -> void:
	## IDLE 状态下原地呆站
	if _state == State.IDLE and sprite:
		_bob_time = 0.0
		sprite.position = Vector3(0, 18.0, 0)
		_is_chasing = false
		return
	
	_bob_time += delta
	if sprite:
		var oy: float = abs(sin(_bob_time * BOUNCE_Y_SPEED)) * BOUNCE_Y_AMPLITUDE
		sprite.position = Vector3(0, 18.0 + oy, 0)
	
	## EnemyBase 没有定义 _process()，不需要调用 super


## 进入新状态时重置追逐标记
func _enter_state(new_state: int) -> void:
	super._enter_state(new_state)
	if new_state == State.IDLE:
		_is_chasing = false
		_reset_shoot_timer()  # 回到空闲时重置射击计时
