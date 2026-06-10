## 大眼怪 — Boss 敌人，大型敌人，走位+扇形弹幕+单发
## 动画：上下浮动 + 下拉时Y轴拉伸（像眼球被拉长的感觉）
class_name BigEyeBoss
extends EnemyBase

const FLOAT_AMPLITUDE: float = 8.0    ## 上下浮动幅度
const FLOAT_SPEED: float = 3.0        ## 浮动速度
const STRETCH_AMOUNT: float = 0.15    ## Y拉伸幅度

var _float_time: float = 0.0

func _ready() -> void:
	is_boss = true
	move_speed = 40.0
	contact_damage = 25.0
	boss_shoot_interval = 5.0
	boss_single_shoot_interval = 1.0
	ai_type = AiType.RANGED
	_float_time = randf_range(0.0, TAU)
	super._ready()

func _process(delta: float) -> void:
	_float_time += delta * FLOAT_SPEED
	if sprite:
		## 正弦波控制上下浮动
		var float_y: float = sin(_float_time) * FLOAT_AMPLITUDE
		sprite.position.y = 54.0 + float_y
		## 向下运动时Y轴拉伸（模拟下拉形变）
		var stretch: float = 1.0 + STRETCH_AMOUNT * max(0.0, -cos(_float_time))
		sprite.scale.y = stretch
