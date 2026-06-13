## 血包拾取物 3D 版本
extends Area3D

signal picked_up()

@export var heal_amount: float = 20.0

@onready var life_timer: Timer = $LifeTimer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	life_timer.timeout.connect(queue_free)
	life_timer.start(15.0)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var hc := body.get_node_or_null("HealthComponent") as HealthComponent
		if hc:
			hc.heal(heal_amount)
		picked_up.emit()
		queue_free()
