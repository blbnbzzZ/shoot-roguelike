## 草莓团子 — 普通近战敌人，继承 EnemyBase 的默认近战行为（追击+接触伤害）
class_name Strawberry
extends EnemyBase

## ========== 模型摆动参数（可手动调） ==========
## 上下弹跳幅度（世界单位），图片向上弹
const BOUNCE_Y_AMPLITUDE: float = 15.0
## 上下弹跳速度（弧度/秒）
const BOUNCE_Y_SPEED: float = 8.0

## ========== 包抄追踪参数（每只草莓独立） ==========
## 追踪时偏离正对玩家方向的角度（弧度），正值偏右，负值偏左
## 每只草莓随机生成不同的角度，形成包夹效果
var _flank_angle: float = 0.0
## 偏角随时间缓慢变化的速度（弧度/秒），让路径有弧线感
const FLANK_DRIFT_SPEED: float = 0.5
## 最大允许的偏移角度（弧度），约 ±40 度
const MAX_FLANK_ANGLE: float = deg_to_rad(40.0)

var _bob_time: float = 0.0

func _ready() -> void:
	## 默认值已在 EnemyBase 中定义，无需额外设置
	## 使用立绘原色，不叠加颜色滤镜
	super._ready()
	## 每只草莓随机起始相位，避免所有草莓同步跳动
	_bob_time = randf_range(0.0, TAU)
	## 每只草莓随机初始包抄方向（左或右）
	_flank_angle = randf_range(-MAX_FLANK_ANGLE, MAX_FLANK_ANGLE)


## 覆盖基类追踪逻辑：每只草莓从不同角度包抄玩家
func _process_chase(delta: float) -> void:
	if not _player:
		_enter_state(State.IDLE)
		return

	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	var dir: Vector3 = to_player.normalized()

	## 缓慢漂移偏角，让路径呈弧线而非直线
	_flank_angle += randf_range(-FLANK_DRIFT_SPEED, FLANK_DRIFT_SPEED) * delta
	_flank_angle = clamp(_flank_angle, -MAX_FLANK_ANGLE, MAX_FLANK_ANGLE)

	## 将方向向量绕 Y 轴旋转偏移角度
	dir = dir.rotated(Vector3.UP, _flank_angle)

	velocity = dir * move_speed
	if sprite:
		sprite.flip_h = dir.x < 0.0
	if dist < 15.0:
		_enter_state(State.ATTACK)


func _process(delta: float) -> void:
	## IDLE 状态下原地呆站，不做任何形变
	if _state == State.IDLE and sprite:
		_bob_time = 0.0
		sprite.position = Vector3(0, 18.0, 0)
		return

	_bob_time += delta
	if sprite:
		## 上下：position.y 偏移向上，像踩地弹跳（abs保证只往上弹）
		var oy: float = abs(sin(_bob_time * BOUNCE_Y_SPEED)) * BOUNCE_Y_AMPLITUDE
		sprite.position = Vector3(0, 18.0 + oy, 0)
