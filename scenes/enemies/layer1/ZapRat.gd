## 闪电鼠 — 快速近战敌人，高移速、低伤害的近战变种
class_name ZapRat
extends EnemyBase

func _ready() -> void:
	move_speed = 140.0
	contact_damage = 10.0
	super._ready()
	if sprite:
		sprite.flip_h = true
