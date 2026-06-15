## 视差图层数据资源（独立文件，确保正确序列化）
@icon("res://icon.svg")
extends Resource
class_name ParallaxLayerData

@export_file("*.png", "*.jpg", "*.jpeg") var texture_path: String = ""
@export var parallax_speed: float = 10.0  ## 视差移动速度（越大移动越多）
@export var scale: float = 1.0  ## 图片缩放（>1 放大防止露边）
