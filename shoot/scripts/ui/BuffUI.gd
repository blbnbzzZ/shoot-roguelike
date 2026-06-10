## Buff UI — 屏幕下方增益图标显示
extends Control

class_name BuffUI

## 增益图标数据
var _buffs: Array = []

@onready var _hbox: VBoxContainer = $VBoxContainer
@onready var _tooltip: PanelContainer = $TooltipPanel
@onready var _tooltip_label: Label = $TooltipPanel/Label


func _ready() -> void:
	## 安全获取 TooltipPanel（避免场景节点缺失时报错）
	_tooltip = get_node_or_null("TooltipPanel")
	if _tooltip:
		_tooltip.visible = false
		## 脱离父节点布局影响，方便用 global_position 绝对定位
		_tooltip.top_level = true
	
	_tooltip_label = get_node_or_null("TooltipPanel/Label")
	if _tooltip_label:
		_tooltip_label.text = ""


## 添加增益
func add_buff(buff_id: String, icon: Texture2D, desc: String) -> void:
	## 去重
	for b in _buffs:
		if b.id == buff_id:
			return
	
	var tex := TextureRect.new()
	tex.texture = icon
	tex.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	tex.custom_minimum_size = Vector2(52, 52)
	tex.size = Vector2(52, 52)
	tex.mouse_filter = Control.MOUSE_FILTER_STOP
	
	## 鼠标事件
	tex.mouse_entered.connect(func(): _show_tip(tex, desc))
	tex.mouse_exited.connect(func(): _hide_tip())
	
	## 新加成插入到最上方（index 0）
	_hbox.add_child(tex)
	_hbox.move_child(tex, 0)
	_buffs.append({"id": buff_id, "node": tex})


## 移除增益
func remove_buff(buff_id: String) -> void:
	for i in range(_buffs.size() - 1, -1, -1):
		if _buffs[i].id == buff_id:
			_buffs[i].node.queue_free()
			_buffs.remove_at(i)
			return


## 显示提示
func _show_tip(icon_node: Control, text: String) -> void:
	if not _tooltip or not _tooltip_label:
		return
	_tooltip_label.text = text
	_tooltip.visible = true
	
	## 等待一帧让 tooltip 计算大小
	await get_tree().process_frame
	
	var icon_global := icon_node.global_position
	var icon_size := icon_node.size
	
	## tooltip 紧贴图标右侧，垂直居中对齐
	var tooltip_y := icon_global.y + (icon_size.y - _tooltip.size.y) * 0.5
	_tooltip.global_position = Vector2(icon_global.x + icon_size.x + 8, tooltip_y)


## 隐藏提示
func _hide_tip() -> void:
	if _tooltip:
		_tooltip.visible = false


## 生成散弹枪图标
static func make_shotgun_icon() -> ImageTexture:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	## 金色
	var col := Color(0.85, 0.65, 0.2, 1.0)
	var dark := Color(0.5, 0.35, 0.1, 1.0)
	
	## 枪管（横向）
	for x in range(10, 38):
		for y in range(21, 27):
			img.set_pixel(x, y, col)
	
	## 枪托（纵向）
	for x in range(6, 12):
		for y in range(18, 30):
			img.set_pixel(x, y, dark)
	
	## 扳机护圈
	for t in range(360):
		var rad := deg_to_rad(t)
		var px := 20 + 4 * cos(rad)
		var py := 24 + 4 * sin(rad)
		if px >= 0 and px < 48 and py >= 0 and py < 48:
			img.set_pixel(int(px), int(py), col)
	
	## 三发标示（三个小三角）
	for i: int in [-1, 0, 1]:
		var yy: int = 24 + i * 5
		for d in range(3):
			var px: int = 38 + d
			var py: int = yy - d
			if py >= 0 and py < 48:
				img.set_pixel(px, py, Color(1.0, 0.85, 0.3, 1.0))
			py = yy + d
			if py >= 0 and py < 48:
				img.set_pixel(px, py, Color(1.0, 0.85, 0.3, 1.0))
	
	## 边框
	var border := Color(0.7, 0.5, 0.15, 1.0)
	for i in range(48):
		img.set_pixel(i, 0, border)
		img.set_pixel(i, 47, border)
	for i in range(48):
		img.set_pixel(0, i, border)
		img.set_pixel(47, i, border)
	
	return ImageTexture.create_from_image(img)


## 生成冲锋枪图标（青蓝色调，紧凑造型）
static func make_smg_icon() -> ImageTexture:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	## 青蓝金属色
	var col := Color(0.3, 0.5, 0.7, 1.0)
	var dark := Color(0.18, 0.28, 0.4, 1.0)
	var accent := Color(0.2, 0.7, 0.9, 1.0)

	## 枪管（细长）
	for x in range(12, 40):
		for y in range(23, 26):
			img.set_pixel(x, y, col)

	## 机匣
	for x in range(10, 22):
		for y in range(21, 28):
			img.set_pixel(x, y, dark)

	## 枪托（短）
	for x in range(4, 11):
		for y in range(20, 29):
			img.set_pixel(x, y, dark)

	## 弹匣（下方突出）
	for x in range(14, 19):
		for y in range(27, 36):
			img.set_pixel(x, y, col)

	## 瞄具（上方小点）
	for x in range(24, 30):
		for y in range(20, 23):
			img.set_pixel(x, y, accent)

	## 提速标示（闪电符号）
	img.set_pixel(38, 22, accent)
	img.set_pixel(39, 23, accent)
	img.set_pixel(40, 24, accent)
	img.set_pixel(39, 25, accent)
	img.set_pixel(38, 26, accent)
	img.set_pixel(37, 25, accent)
	img.set_pixel(36, 24, accent)
	img.set_pixel(37, 23, accent)

	## 边框
	var border := Color(0.2, 0.35, 0.55, 1.0)
	for i in range(48):
		img.set_pixel(i, 0, border)
		img.set_pixel(i, 47, border)
	for i in range(48):
		img.set_pixel(0, i, border)
		img.set_pixel(47, i, border)

	return ImageTexture.create_from_image(img)
