# @file: game_manager.gd
# @brief: 游戏管理器脚本
# @date: 2025-04-20
# @author: ponywu

extends Node2D

# 预加载相机控制器脚本
const CameraController = preload("res://scripts/camera_controller.gd")
# 预加载资源显示场景
const ResourceDisplayScene = preload("res://scenes/ui/resource_display.tscn")

# 游戏配置
const GAME_CONFIG = {
	"camera": {
		"initial_position": Vector2(0, 0)  # 相机初始位置
	}
}

# 游戏状态
var camera: Camera2D = null
var resource_display = null

func _ready() -> void:
	print("游戏管理器初始化")

	# 设置相机
	_setup_camera()

	# 设置资源显示
	_setup_resource_display()

# 设置资源显示
func _setup_resource_display() -> void:
	# 创建资源显示实例
	resource_display = ResourceDisplayScene.instantiate()

	# 获取或创建 CanvasLayer
	var canvas_layer = _get_or_create_ui_layer()

	# 添加资源显示到 UI 层
	canvas_layer.add_child(resource_display)

	print("资源显示初始化完成")

# 获取或创建 UI 层
func _get_or_create_ui_layer() -> CanvasLayer:
	# 查找是否已存在 UI 层
	var existing_layer = get_node_or_null("UILayer")
	if existing_layer:
		return existing_layer

	# 创建新的 UI 层
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "UILayer"
	canvas_layer.layer = 100  # 确保在最上层显示
	add_child(canvas_layer)
	return canvas_layer

# 设置相机
func _setup_camera() -> void:
	# 查找场景中是否已有相机
	if get_tree().get_nodes_in_group("main_camera").size() > 0:
		# 如果找到已有相机，将其替换为独立相机
		var existing_camera = get_tree().get_nodes_in_group("main_camera")[0]

		# 记录原相机位置
		var original_position = existing_camera.global_position

		# 创建新相机
		camera = Camera2D.new()
		camera.script = CameraController
		camera.name = "MainCamera"
		camera.add_to_group("main_camera")

		# 设置相机属性和位置
		camera.global_position = original_position

		# 移除旧相机并添加新相机
		existing_camera.queue_free()
		add_child(camera)

		# 确保相机已添加到场景树后再调用make_current
		await get_tree().process_frame
		camera.make_current()

		print("替换了附加在单位上的相机")
	else:
		# 如果没有找到相机，创建新相机
		camera = Camera2D.new()
		camera.script = CameraController
		camera.name = "MainCamera"
		camera.add_to_group("main_camera")

		# 设置相机位置和属性
		camera.global_position = GAME_CONFIG.camera.initial_position

		# 添加到场景
		add_child(camera)

		# 确保相机已添加到场景树后再调用make_current
		await get_tree().process_frame
		camera.make_current()

		print("创建了新的独立相机")

		# 默认启用相机
		camera.enabled = true
