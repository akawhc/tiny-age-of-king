extends Control

@onready var panel = $Panel
@onready var wood_amount = $Panel/WoodAmount
@onready var gold_amount = $Panel/GoldAmount
@onready var meat_amount = $Panel/MeatAmount
@onready var wood_icon = $Panel/wood
@onready var gold_icon = $Panel/gold
@onready var meat_icon = $Panel/meat

# 基准屏幕尺寸
const BASE_SCREEN_SIZE = Vector2(1920, 1080)
# 最小和最大缩放比例
const MIN_SCALE = 0.8
const MAX_SCALE = 1.2

var camera: Camera2D = null
var current_camera_zoom = Vector2(1, 1)

func _ready():
	# 获取资源管理器实例
	var resource_manager = GlobalResourceManager.get_instance()

	# 连接信号
	resource_manager.resources_changed.connect(_on_resources_changed)

	# 初始化显示
	_update_all_resources()

	# 初始缩放
	_update_scale()

	# 监听窗口大小变化
	get_tree().root.size_changed.connect(_update_scale)

	# 获取主相机引用
	await get_tree().process_frame
	_find_main_camera()

func _find_main_camera():
	var cameras = get_tree().get_nodes_in_group("main_camera")
	if cameras.size() > 0:
		camera = cameras[0]
		current_camera_zoom = camera.zoom
		# 监听相机缩放变化
		if camera.has_signal("zoom_changed"):
			camera.zoom_changed.connect(_on_camera_zoom_changed)

func _on_camera_zoom_changed(zoom: Vector2):
	current_camera_zoom = zoom
	_update_scale()

func _update_scale():
	# 获取当前窗口大小
	var window_size = DisplayServer.window_get_size()

	# 计算基础缩放比例
	var scale_x = window_size.x / BASE_SCREEN_SIZE.x
	var scale_y = window_size.y / BASE_SCREEN_SIZE.y
	var display_scale = min(scale_x, scale_y)

	# 考虑相机缩放
	if camera != null:
		display_scale = display_scale / current_camera_zoom.x  # 相机缩小（zoom增大）时，UI要放大

	# 限制缩放范围
	display_scale = clamp(display_scale, MIN_SCALE, MAX_SCALE)

	# 应用缩放
	panel.scale = Vector2(display_scale, display_scale)

	# 更新位置（保持在左上角，考虑缩放）
	var margin = 5 * display_scale  # 边距也跟随缩放
	panel.position = Vector2(margin, margin)

func _on_resources_changed(resource_type: String, amount: int) -> void:
	match resource_type:
		"wood":
			wood_amount.text = str(amount)
		"gold":
			gold_amount.text = str(amount)
		"meat":
			meat_amount.text = str(amount)

func _update_all_resources() -> void:
	var resource_manager = GlobalResourceManager.get_instance()
	var resources = resource_manager.get_all_resources()

	wood_amount.text = str(resources["wood"])
	gold_amount.text = str(resources["gold"])
	meat_amount.text = str(resources["meat"])
