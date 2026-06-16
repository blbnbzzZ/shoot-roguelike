## 主菜单场景
extends Control

signal start_game
signal quit_game

## 视差背景节点
var _parallax_bg: Node = null

## 标题漂浮动画参数
@export var title_float_speed: float = 1.5   ## 漂浮速度（周期秒数）
@export var title_float_amount: float = 8.0   ## 漂浮幅度（像素）
var _title_base_y: float = 0.0                ## 标题初始 Y 坐标
var _float_time: float = 0.0                   ## 漂浮时间累计


func _ready() -> void:
	## 获取视差背景节点
	_parallax_bg = get_node_or_null("ParallaxBackground")
	
	## 记录标题初始位置（作为漂浮基准）
	var title_node = get_node_or_null("TitleImage")
	if title_node:
		_title_base_y = title_node.position.y
	
	## 连接按钮信号
	if has_node("VBox/StartButton"):
		$VBox/StartButton.pressed.connect(func(): start_game.emit())
	if has_node("VBox/QuitButton"):
		$VBox/QuitButton.pressed.connect(func(): quit_game.emit())
	
	## 初始状态：显示视差背景
	if _parallax_bg and _parallax_bg.has_method("show_parallax"):
		_parallax_bg.show_parallax()


func _process(delta: float) -> void:
	## 标题上下漂浮动画
	_float_time += delta
	var title_node = get_node_or_null("TitleImage")
	if title_node and visible:
		var offset := sin(_float_time * TAU / title_float_speed) * title_float_amount
		title_node.position.y = _title_base_y + offset


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
