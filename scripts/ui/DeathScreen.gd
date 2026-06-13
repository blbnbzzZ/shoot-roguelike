## 死亡界面场景
extends Control

signal restart_game
signal quit_to_menu

func _ready() -> void:
	## 暂停时仍能渲染和处理输入
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	if has_node("VBox/RestartButton"):
		$VBox/RestartButton.pressed.connect(func(): restart_game.emit())
	if has_node("VBox/QuitButton"):
		$VBox/QuitButton.pressed.connect(func(): quit_to_menu.emit())

func show_death() -> void:
	visible = true
	get_tree().paused = true

func hide_death() -> void:
	visible = false
	get_tree().paused = false
