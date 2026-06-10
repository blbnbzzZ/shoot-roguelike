## 生命值组件 — 可复用
class_name HealthComponent
extends Node

signal died(who: Node)
signal damaged(amount: float, source: Node)
signal health_changed(current: float, max_hp: float)

@export var max_health: float = 100.0
@export var invincible: bool = false

var current_health: float = 100.0
var _owner_node: Node = null

func _ready() -> void:
	current_health = max_health
	_owner_node = get_parent()

func apply_damage(amount: float, source: Node = null) -> void:
	if invincible or current_health <= 0:
		return
	current_health = max(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	damaged.emit(amount, source)
	if current_health <= 0:
		died.emit(_owner_node)

func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func reset() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
