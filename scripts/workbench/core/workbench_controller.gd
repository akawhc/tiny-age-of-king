# file: workbench_controller.gd
# author: ponywu
# date: 2025-04-12
# description: 核心控制器，负责UI渲染和交互处理

extends Node2D
class_name WorkbenchController

# 信号定义
signal button_clicked(action_id: String)
signal workbench_visibility_changed(is_visible: bool)
signal interaction_changed(interaction_type: String)

# 导出变量
@export var config: WorkbenchConfig

# 私有变量
var _interaction_type: String = "NONE"
var _is_workbench_visible: bool = true
var _buttons_container: VBoxContainer
var _background: Sprite2D
var _active_buttons: Array[Button] = []
var _last_screen_size: Vector2

func _ready() -> void:
	config = WorkbenchConfig.new()
	_background = $background
	_buttons_container = $ActionButtons

	if not _background:
		push_error("WorkbenchController: Background 节点未找到")
		return

	if not _buttons_container:
		push_error("WorkbenchController: ButtonsContainer 节点未找到")
		return

	# 记录初始屏幕尺寸
	_last_screen_size = get_viewport_rect().size

	# 设置初始状态
	_setup_workbench()
	_update_buttons()

	# 连接窗口大小变化信号
	get_tree().root.size_changed.connect(_on_window_size_changed)

func _on_window_size_changed() -> void:
	var current_screen_size = get_viewport_rect().size
	if current_screen_size != _last_screen_size:
		_last_screen_size = current_screen_size
		_update_position()

func _setup_workbench() -> void:
	# 设置背景缩放
	_background.scale = config.layout.scale

	# 设置按钮容器
	_buttons_container.custom_minimum_size = Vector2(180, 0)
	_buttons_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buttons_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 设置按钮容器的样式
	_buttons_container.add_theme_constant_override("separation", 10)
	_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# 设置初始位置
	_update_position()

func _update_position() -> void:
	# 获取屏幕尺寸
	var screen_size = get_viewport_rect().size

	# 从配置中获取边距和偏移值
	var margin_left = config.layout.margin_left
	var margin_bottom = config.layout.margin_bottom
	var position_offset = config.layout.position_offset

	# 获取缩放后背景实际尺寸
	var background_size = _get_workbench_size()

	# 设置背景位置（左下角对齐）
	_background.position = Vector2.ZERO

	# 设置按钮容器位置（与背景对齐）
	_buttons_container.position = Vector2.ZERO

	# 设置整个控制器的位置
	position = Vector2(
		margin_left + background_size.x / 2,
		screen_size.y - background_size.y / 2 - margin_bottom
	) + position_offset


func _get_workbench_size() -> Vector2:
	# 获取背景尺寸（考虑缩放）
	var width = _background.texture.get_width() * _background.scale.x
	var height = _background.texture.get_height() * _background.scale.y
	return Vector2(width, height)

func _update_buttons() -> void:
	# 清除现有按钮
	for button in _active_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_active_buttons.clear()

	# 获取当前交互类型的按钮配置
	var button_configs = config.button_configs[_interaction_type]

	# 创建新按钮
	for button_config in button_configs:
		var button = Button.new()
		button.text = button_config.text
		button.name = button_config.id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# 从配置中获取按钮样式
		var min_height = config.button_style.min_height
		var font_size = config.button_style.font_size
		var margin = config.button_style.margin

		button.custom_minimum_size = Vector2(0, min_height)
		button.add_theme_font_size_override("font_size", font_size)
		button.add_theme_constant_override("h_separation", margin.left)
		button.add_theme_constant_override("content_margin_left", margin.left)
		button.add_theme_constant_override("content_margin_right", margin.right)
		button.add_theme_constant_override("content_margin_top", margin.top)
		button.add_theme_constant_override("content_margin_bottom", margin.bottom)

		# 连接按钮点击信号
		button.pressed.connect(_on_button_pressed.bind(button_config.action))

		# 添加按钮到容器
		_buttons_container.add_child(button)
		_active_buttons.append(button)

func _on_button_pressed(action_id: String) -> void:
	button_clicked.emit(action_id)

# 公共接口
func set_interaction_type(type: String) -> void:
	if _interaction_type != type:
		_interaction_type = type
		_update_buttons()
		interaction_changed.emit(type)

func set_workbench_visible(is_workbench_visible: bool) -> void:
	if _is_workbench_visible != is_workbench_visible:
		_is_workbench_visible = is_workbench_visible
		is_workbench_visible = is_workbench_visible
		workbench_visibility_changed.emit(is_workbench_visible)

func toggle_visibility() -> void:
	set_workbench_visible(!_is_workbench_visible)

func get_interaction_type() -> String:
	return _interaction_type

func workbench_visible() -> bool:
	return _is_workbench_visible
