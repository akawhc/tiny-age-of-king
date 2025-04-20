# @file: game_manager.gd
# @brief: 游戏管理器脚本，负责设置相机和管理游戏状态
# @date: 2025-04-20
# @author: ponywu

extends Node2D

# 预加载相机控制器脚本
const CameraController = preload("res://scripts/camera/camera_controller.gd")

# 游戏配置
const GAME_CONFIG = {
	"camera": {
		"initial_position": Vector2(0, 0)  # 相机初始位置
	}
}

# 游戏状态
var camera: Camera2D = null

func _ready() -> void:
	print("游戏管理器初始化")

	# 设置相机
	_setup_camera()

	# 其他初始化逻辑...

# 设置相机
func _setup_camera() -> void:
	# 查找场景中是否已有相机
	if get_tree().get_nodes_in_group("main_camera").size() > 0:
		# 如果找到已有相机，将其替换为独立相机
		var existing_camera = get_tree().get_nodes_in_group("main_camera")[0]
		var parent_node = existing_camera.get_parent()

		# 记录原相机位置
		var original_position = existing_camera.global_position

		# 创建新相机
		camera = Camera2D.new()
		camera.script = CameraController
		camera.name = "MainCamera"
		camera.add_to_group("main_camera")

		# 设置相机属性和位置
		camera.global_position = original_position
		camera.make_current()

		# 移除旧相机并添加新相机
		existing_camera.queue_free()
		add_child(camera)

		print("替换了附加在单位上的相机")
	else:
		# 如果没有找到相机，创建新相机
		camera = Camera2D.new()
		camera.script = CameraController
		camera.name = "MainCamera"
		camera.add_to_group("main_camera")

		# 设置相机位置和属性
		camera.global_position = GAME_CONFIG.camera.initial_position
		camera.make_current()

		# 添加到场景
		add_child(camera)

		print("创建了新的独立相机")

# 其他游戏管理功能可以在这里添加...