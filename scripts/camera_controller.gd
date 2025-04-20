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
var config = {
	"camera_mode": CameraMode.FOLLOW_MOUSE,  # 相机模式
	"mouse_follow": {
		"enabled": false,                   # 是否启用鼠标跟随 - 默认禁用，只使用边缘滚动
		"offset": Vector2.ZERO,             # 鼠标跟随偏移量
		"weight": 0.05,                     # 鼠标跟随权重（平滑度）
		"lerp_speed": 2.0,                  # 平滑过渡速度
		"screen_edge_threshold": 0.8,       # 屏幕边缘阈值（0.0-1.0），只有鼠标超过此阈值才移动
		"follow_only_at_edge": true         # 是否只在鼠标靠近边缘时才跟随移动
	},
	"keyboard": {
		"enabled": true,                    # 是否启用键盘移动
		"move_speed": 100.0                 # 键盘移动速度
	},
	"edge_scroll": {
		"enabled": true,                    # 是否启用边缘滚动
		"margin_percent": 0.02,             # 边缘滚动边距百分比（屏幕宽/高的百分比）- 降低为2%
		"min_margin": 10.0,                 # 最小边缘滚动边距（像素）
		"max_margin": 25.0,                 # 最大边缘滚动边距（像素）
		"speed": 100.0,                     # 边缘滚动速度
		"debug_draw": false                 # 是否显示边缘区域调试绘制
	},
	"zoom": {
		"enabled": true,                    # 是否启用缩放
		"min": 0.5,                         # 最小缩放值
		"max": 2.0,                         # 最大缩放值
		"step": 0.1,                        # 缩放步长
		"target": Vector2(1, 1),            # 目标缩放
		"lerp_speed": 10.0                  # 缩放平滑速度
	},
	"debug": {
		"log_frequency": 60,                # 调试日志输出频率（帧数）
		"enable_verbose_logging": true      # 是否启用详细日志
	}
}

# 内部变量
var _input_direction: Vector2 = Vector2.ZERO # 输入方向
var _follow_target = null                    # 跟随目标
var _edge_rects = []                         # 边缘矩形区域，用于调试绘制
var _frame_counter = 0                       # 帧计数器，用于控制日志输出频率

func _ready() -> void:
	# 设置相机属性
	enabled = true  # 确保相机已启用
	zoom = config.zoom.target
	make_current()

	# 添加到相机组便于查找
	add_to_group("main_camera")

func _process(delta: float) -> void:
	_frame_counter += 1

	# 处理缩放
	_handle_zoom(delta)

	# 处理相机移动
	match config.camera_mode:
		CameraMode.FIXED:
			pass  # 固定相机，不做任何处理
		CameraMode.FOLLOW_CHARACTER:
			if _follow_target != null and is_instance_valid(_follow_target):
				global_position = _follow_target.global_position
		CameraMode.FOLLOW_MOUSE:
			_handle_mouse_follow(delta)
			_handle_keyboard_move(delta)
			_handle_edge_scroll(delta)

	# 如果需要显示调试绘制，则触发重绘
	if config.edge_scroll.debug_draw:
		queue_redraw()

	# 定期输出调试信息
	if config.debug.enable_verbose_logging and _frame_counter % config.debug.log_frequency == 0:
		print("当前相机位置:", global_position)
		print("当前缩放比例:", zoom)

func _input(event: InputEvent) -> void:
	# 处理鼠标滚轮缩放
	if config.zoom.enabled and event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton

		# 鼠标滚轮向上滚动 - 放大
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			config.zoom.target -= Vector2(config.zoom.step, config.zoom.step)
			config.zoom.target = config.zoom.target.clamp(Vector2(config.zoom.min, config.zoom.min), Vector2(config.zoom.max, config.zoom.max))

		# 鼠标滚轮向下滚动 - 缩小
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			config.zoom.target += Vector2(config.zoom.step, config.zoom.step)
			config.zoom.target = config.zoom.target.clamp(Vector2(config.zoom.min, config.zoom.min), Vector2(config.zoom.max, config.zoom.max))

	# 处理键盘输入
	_handle_keyboard_input(event)

func _handle_zoom(delta: float) -> void:
	if not config.zoom.enabled:
		return

	# 设置缩放限制
	config.zoom.target.x = clamp(config.zoom.target.x, config.zoom.min, config.zoom.max)
	config.zoom.target.y = clamp(config.zoom.target.y, config.zoom.min, config.zoom.max)

	# 平滑缩放
	zoom = zoom.lerp(config.zoom.target, delta * config.zoom.lerp_speed)

func _handle_mouse_follow(delta: float) -> void:
	if not config.mouse_follow.enabled:
		return

	# 获取鼠标位置
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport_rect().size
	var viewport_center = viewport_size / 2

	# 检查鼠标是否在屏幕边缘区域
	var is_at_edge = false
	var normalized_pos = Vector2(
		mouse_pos.x / viewport_size.x,
		mouse_pos.y / viewport_size.y
	)

	# 如果鼠标接近屏幕边缘，才跟随移动
	if normalized_pos.x < (1.0 - config.mouse_follow.screen_edge_threshold) or normalized_pos.x > config.mouse_follow.screen_edge_threshold or \
	   normalized_pos.y < (1.0 - config.mouse_follow.screen_edge_threshold) or normalized_pos.y > config.mouse_follow.screen_edge_threshold:
		is_at_edge = true

	# 只在边缘时移动或总是跟随鼠标移动
	if !config.mouse_follow.follow_only_at_edge or (config.mouse_follow.follow_only_at_edge and is_at_edge):
		# 计算相机位置偏移
		var offset = (mouse_pos - viewport_center) * zoom.x * config.mouse_follow.weight

		# 加上额外偏移量
		offset += config.mouse_follow.offset

		# 移动相机（平滑过渡）- 降低移动速度
		global_position = global_position.lerp(global_position + offset, delta * config.mouse_follow.lerp_speed)

func _handle_keyboard_input(event: InputEvent) -> void:
	if not config.keyboard.enabled:
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
	if not config.keyboard.enabled or _input_direction == Vector2.ZERO:
		return

	# 应用键盘移动
	global_position += _input_direction.normalized() * config.keyboard.move_speed * delta

func _handle_edge_scroll(delta: float) -> void:
	if not config.edge_scroll.enabled:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport_rect().size
	var scroll_direction = Vector2.ZERO

	# 清除调试用的边缘矩形
	_edge_rects.clear()

	# 计算实时的边缘滚动边距，根据屏幕大小和缩放比例
	var margin_x = clamp(viewport_size.x * config.edge_scroll.margin_percent,
						config.edge_scroll.min_margin,
						config.edge_scroll.max_margin)
	var margin_y = clamp(viewport_size.y * config.edge_scroll.margin_percent,
						config.edge_scroll.min_margin,
						config.edge_scroll.max_margin)

	# 计算边缘区域的四个矩形（左、右、上、下）
	var left_rect = Rect2(0, 0, margin_x, viewport_size.y)
	var right_rect = Rect2(viewport_size.x - margin_x, 0, margin_x, viewport_size.y)
	var top_rect = Rect2(0, 0, viewport_size.x, margin_y)
	var bottom_rect = Rect2(0, viewport_size.y - margin_y, viewport_size.x, margin_y)

	# 存储边缘矩形用于调试绘制
	_edge_rects = [left_rect, right_rect, top_rect, bottom_rect]

	# 严格检查鼠标是否在边缘区域（确保矩形区域计算正确）
	# 左边缘
	if mouse_pos.x < margin_x:
		scroll_direction.x = -1
	# 右边缘
	elif mouse_pos.x > viewport_size.x - margin_x:
		scroll_direction.x = 1
	# 上边缘
	if mouse_pos.y < margin_y:
		scroll_direction.y = -1
	# 下边缘
	elif mouse_pos.y > viewport_size.y - margin_y:
		scroll_direction.y = 1

	# 应用边缘滚动
	if scroll_direction != Vector2.ZERO:
		# 使用基于时间的平滑移动
		var speed = config.edge_scroll.speed * delta
		global_position += scroll_direction.normalized() * speed * zoom.x

# 设置跟随目标
func set_follow_target(target) -> void:
	_follow_target = target

	if target != null:
		config.camera_mode = CameraMode.FOLLOW_CHARACTER
	else:
		config.camera_mode = CameraMode.FOLLOW_MOUSE

# 切换相机模式
func set_camera_mode(mode: int) -> void:
	config.camera_mode = mode

# 绘制调试可视化内容
func _draw() -> void:
	if not config.edge_scroll.debug_draw:
		return

	# 绘制边缘区域
	var edge_color = Color(1, 0, 0, 0.3)  # 半透明红色

	for rect in _edge_rects:
		draw_rect(rect, edge_color, true)  # 填充矩形
		draw_rect(rect, Color(1, 0, 0, 0.8), false, 2.0)  # 矩形边框