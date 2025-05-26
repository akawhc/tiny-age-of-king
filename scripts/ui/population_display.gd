extends Control

@onready var panel = $Panel
@onready var population_amount = $Panel/PopulationAmount
@onready var population_icon = $Panel/PopulationIcon

# 基准屏幕尺寸
const BASE_SCREEN_SIZE = Vector2(1920, 1080)
# 最小和最大缩放比例
const MIN_SCALE = 0.8
const MAX_SCALE = 1.2
# 边距
const MARGIN = 5

var camera: Camera2D = null
var current_camera_zoom = Vector2(1, 1)

func _ready():
	# 获取资源管理器实例
	var resource_manager = GlobalResourceManager.get_instance()

	# 连接人口变化信号
	resource_manager.population_changed.connect(_on_population_changed)

	# 初始化显示
	_update_population_display()

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

func _on_camera_zoom_changed(_zoom: Vector2):
	pass
	# current_camera_zoom = zoom
	# _update_scale()

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

	# 更新控件的位置到窗口右上角
	_update_position(window_size, display_scale)

# 更新位置到窗口右上角
func _update_position(window_size: Vector2, display_scale: float):
	# 设置Control的大小为整个窗口
	size = window_size

	# 更新锚点和布局
	set_anchors_preset(Control.PRESET_TOP_RIGHT)

	# 调整边距（与资源显示保持一致）
	var scaled_margin = MARGIN * display_scale

	# 重新定位面板
	panel.position = Vector2(-panel.size.x * panel.scale.x - scaled_margin, scaled_margin)

func _on_population_changed(current: int, max_pop: int) -> void:
	population_amount.text = str(current) + "/" + str(max_pop)

func _update_population_display() -> void:
	var resource_manager = GlobalResourceManager.get_instance()
	var resources = resource_manager.get_all_resources()

	if resources.has("population") and typeof(resources["population"]) == TYPE_DICTIONARY:
		var pop = resources["population"]
		population_amount.text = str(pop["current"]) + "/" + str(pop["max"])

# 确保在处理过程中始终保持正确位置
func _process(_delta):
	if get_viewport_rect().size != size:
		_update_scale()