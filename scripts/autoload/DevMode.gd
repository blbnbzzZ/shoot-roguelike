## 开发者模式（仅我们两个知道）
## F12 开关，无提示，10倍攻速/伤害/移速，无敌
extends Node

var _dev_mode: bool = false
var _player_ref: WeakRef = null

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_debug_reload"):
		_dev_mode = !_dev_mode
		_apply_to_player()

func _apply_to_player() -> void:
	if not _player_ref:
		return
	var player = _player_ref.get_ref()
	if not player:
		return

	## 无敌
	if player.has_node("HealthComponent"):
		var hc = player.get_node("HealthComponent")
		if "invincible" in hc:
			hc.invincible = _dev_mode

	## 攻速 10x（fire_rate 除以 10）
	if "fire_rate" in player and "base_fire_rate" in player:
		player.fire_rate = player.base_fire_rate / 10.0 if _dev_mode else player.base_fire_rate

	## 移速 10x
	if "move_speed" in player:
		player.move_speed = 120.0 * 10.0 if _dev_mode else 120.0

func register_player(player: Node) -> void:
	_player_ref = weakref(player)
	_apply_to_player()

func is_dev_mode() -> bool:
	return _dev_mode

func damage_mult() -> float:
	return 10.0 if _dev_mode else 1.0
