## 咕噜咕噜 — 远程射击敌人，原地摇摆+发射投射物
class_name Guruguru
extends EnemyBase

func _ready() -> void:
	shoot = true
	move_speed = 60.0
	ai_type = AiType.RANGED
	super._ready()
	if sprite:
		sprite.flip_h = true
