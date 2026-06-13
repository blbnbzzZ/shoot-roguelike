extends CharacterBody3D

signal died()
signal health_changed(current: float, max_hp: float)

const GRAVITY: float = 1100.0
const JUMP_VELOCITY: float = 320.0
const MOVE_SPEED: float = 180.0

@onready var sprite: Sprite3D = $Sprite3D
@onready var health_comp = $HealthComponent
@onready var interaction: Area3D = $Interaction

func _ready() -> void:
	add_to_group("player")
	if health_comp and health_comp.has_signal("died"):
		health_comp.died.connect(func(_w): died.emit())
	if health_comp and health_comp.has_signal("health_changed"):
		health_comp.health_changed.connect(func(c, m): health_changed.emit(c, m))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if Input.is_action_just_pressed("ui_jump"):
			velocity.y = JUMP_VELOCITY

	var x_dir: float = Input.get_axis("ui_left", "ui_right")
	var z_dir: float = Input.get_axis("ui_up", "ui_down")

	velocity.x = x_dir * MOVE_SPEED
	velocity.z = z_dir * MOVE_SPEED

	if abs(x_dir) > 0.1 and sprite:
		sprite.flip_h = (x_dir < 0)

	move_and_slide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_try_interact()


func _try_interact() -> void:
	if not interaction:
		return
	for body in interaction.get_overlapping_bodies():
		if body.has_method("interact"):
			body.interact(self)
