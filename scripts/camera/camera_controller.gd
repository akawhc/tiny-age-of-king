# @file: camera_controller.gd
# @brief: 相机控制器，实现鼠标跟随、缩放和边缘滚动功能
# @date: 2025-04-20
# @author: ponywu

extends Camera2D

enum CameraMode {
	FIXED,            # 固定相机
	FOLLOW_CHARACTER, # 跟随角色
	FOLLOW_MOUSE      # 跟随鼠标
}

# 相机配置
@export var camera_mode: int = CameraMode.FOLLOW_MOUSE  # 相机模式
@export var follow_mouse_enabled: bool = true           # 是否启用鼠标跟随
@export var follow_mouse_offset: Vector2 = Vector2.ZERO # 鼠标跟随偏移量
@export var follow_mouse_weight: float = 0.3            # 鼠标跟随权重（平滑度）
@export var keyboard_move_enabled: bool = true          # 是否启用键盘移动
@export var keyboard_move_speed: float = 500.0          # 键盘移动速度
@export var edge_scroll_enabled: bool = true            # 是否启用边缘滚动
@export var edge_scroll_margin: float = 30.0            # 边缘滚动边距
@export var edge_scroll_speed: float = 20.0             # 边缘滚动速度
@export var zoom_enabled: bool = true                   # 是否启用缩放
@export var min_zoom: float = 0.5                       # 最小缩放值
@export var max_zoom: float = 2.0                       # 最大缩放值
@export var zoom_step: float = 0.1                      # 缩放步长
@export var target_zoom: Vector2 = Vector2(1, 1)        # 目标缩放

# 内部变量
var _input_direction: Vector2 = Vector2.ZERO # 输入方向
var _follow_target = null                    # 跟随目标

func _ready() -> void:
	# 设置相机属性
	zoom = target_zoom
	make_current()

	# 添加到相机组便于查找
	add_to_group("main_camera")

func _process(delta: float) -> void:
	# 处理缩放
	_handle_zoom(delta)

	# 处理相机移动
	match camera_mode:
		CameraMode.FIXED:
			pass  # 固定相机，不做任何处理
		CameraMode.FOLLOW_CHARACTER:
			if _follow_target != null:
				global_position = _follow_target.global_position
		CameraMode.FOLLOW_MOUSE:
			_handle_mouse_follow(delta)
			_handle_keyboard_move(delta)
			_handle_edge_scroll(delta)

func _input(event: InputEvent) -> void:
	# 处理鼠标滚轮缩放
	if zoom_enabled and event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton

		# 鼠标滚轮向上滚动 - 放大
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			target_zoom -= Vector2(zoom_step, zoom_step)
			target_zoom = target_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

		# 鼠标滚轮向下滚动 - 缩小
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			target_zoom += Vector2(zoom_step, zoom_step)
			target_zoom = target_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

	# 处理键盘输入
	_handle_keyboard_input(event)

func _handle_zoom(delta: float) -> void:
	if not zoom_enabled:
		return

	# 设置缩放限制
	target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
	target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)

	# 平滑缩放
	zoom = zoom.lerp(target_zoom, delta * 10.0)

func _handle_mouse_follow(delta: float) -> void:
	if not follow_mouse_enabled:
		return

	# 获取鼠标位置
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_center = get_viewport_rect().size / 2

	# 计算相机位置偏移
	var offset = (mouse_pos - viewport_center) * zoom.x * follow_mouse_weight

	# 加上额外偏移量
	offset += follow_mouse_offset

	# 移动相机（平滑过渡）
	global_position = global_position.lerp(global_position + offset, delta * 5.0)

func _handle_keyboard_input(event: InputEvent) -> void:
	if not keyboard_move_enabled:
		return

	if event is InputEventKey:
		var key_event = event as InputEventKey

		# 设置输入方向
		if key_event.keycode == KEY_W or key_event.keycode == KEY_UP:
			_input_direction.y = -1.0 if key_event.pressed else 0.0
		elif key_event.keycode == KEY_S or key_event.keycode == KEY_DOWN:
			_input_direction.y = 1.0 if key_event.pressed else 0.0
		elif key_event.keycode == KEY_A or key_event.keycode == KEY_LEFT:
			_input_direction.x = -1.0 if key_event.pressed else 0.0
		elif key_event.keycode == KEY_D or key_event.keycode == KEY_RIGHT:
			_input_direction.x = 1.0 if key_event.pressed else 0.0

func _handle_keyboard_move(delta: float) -> void:
	if not keyboard_move_enabled or _input_direction == Vector2.ZERO:
		return

	# 应用键盘移动
	global_position += _input_direction.normalized() * keyboard_move_speed * delta

func _handle_edge_scroll(delta: float) -> void:
	if not edge_scroll_enabled:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport_rect().size
	var scroll_direction = Vector2.ZERO

	# 计算鼠标是否在边缘区域
	if mouse_pos.x < edge_scroll_margin:
		scroll_direction.x = -1
	elif mouse_pos.x > viewport_size.x - edge_scroll_margin:
		scroll_direction.x = 1

	if mouse_pos.y < edge_scroll_margin:
		scroll_direction.y = -1
	elif mouse_pos.y > viewport_size.y - edge_scroll_margin:
		scroll_direction.y = 1

	# 应用边缘滚动
	if scroll_direction != Vector2.ZERO:
		global_position += scroll_direction.normalized() * edge_scroll_speed * delta * zoom.x

# 设置跟随目标
func set_follow_target(target) -> void:
	_follow_target = target

	if target != null:
		camera_mode = CameraMode.FOLLOW_CHARACTER
	else:
		camera_mode = CameraMode.FOLLOW_MOUSE

# 切换相机模式
func set_camera_mode(mode: int) -> void:
	camera_mode = mode