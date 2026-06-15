## 主菜单场景
extends Control

signal start_game
signal quit_game

## 视差背景节点
var _parallax_bg: Node = null


func _ready() -> void:
	## 获取视差背景节点
	_parallax_bg = get_node_or_null("ParallaxBackground")
	
	## 连接按钮信号
	if has_node("VBox/StartButton"):
		$VBox/StartButton.pressed.connect(func(): start_game.emit())
	if has_node("VBox/QuitButton"):
		$VBox/QuitButton.pressed.connect(func(): quit_game.emit())
	
	## 初始状态：显示视差背景
	if _parallax_bg and _parallax_bg.has_method("show_parallax"):
		_parallax_bg.show_parallax()


func show_menu() -> void:
	visible = true
	## 显示视差背景
	if _parallax_bg and _parallax_bg.has_method("show_parallax"):
		_parallax_bg.show_parallax()


func hide_menu() -> void:
	visible = false
	## 隐藏视差背景
	if _parallax_bg and _parallax_bg.has_method("hide_parallax"):
		_parallax_bg.hide_parallax()
