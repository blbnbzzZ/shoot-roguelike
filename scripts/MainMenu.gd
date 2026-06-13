## 主菜单场景
extends Control

signal start_game
signal quit_game

func _ready() -> void:
	## 连接按钮信号
	if has_node("VBox/StartButton"):
		$VBox/StartButton.pressed.connect(func(): start_game.emit())
	if has_node("VBox/QuitButton"):
		$VBox/QuitButton.pressed.connect(func(): quit_game.emit())


func show_menu() -> void:
	visible = true


func hide_menu() -> void:
	visible = false
