# file: workbench_controller.gd
# author: ponywu
# date: 2025-04-12
# description: 核心控制器，负责UI渲染和交互处理

extends Node2D
class_name WorkbenchController

# 信号定义
signal button_clicked(action_id: String)
signal interaction_changed(interaction_type: String)

# 导出变量
@export var config: WorkbenchConfig

# 私有变量
var _interaction_type: String = "NONE"
var _buttons_container: VBoxContainer
var _active_buttons: Array[Button] = []
var _last_screen_size: Vector2
var _selection_manager: Node
var _selected_units: Array = []  # 存储选中的单位
var _building_manager: BuildingManager  # 建筑管理器单例
var _unit_manager: UnitManager  # 单位管理器单例
var _resource_manager: GlobalResourceManager

func _ready() -> void:
	config = WorkbenchConfig.new()
	_buttons_container = $ActionButtons
	add_to_group("workbench")

	if not _buttons_container:
		push_error("WorkbenchController: ButtonsContainer 节点未找到")
		return

	# 记录初始屏幕尺寸
	_last_screen_size = get_viewport_rect().size

	# 设置初始状态
	_setup_workbench()
	_update_buttons()
	_building_manager = BuildingManager.get_instance()
	_unit_manager = UnitManager.get_instance()
	_resource_manager = GlobalResourceManager.get_instance()

	# 连接资源变化信号
	_resource_manager.resources_changed.connect(_on_resources_changed)

	# 连接窗口大小变化信号
	get_tree().root.size_changed.connect(_on_window_size_changed)

	# 获取选择管理器并连接信号
	_selection_manager = get_tree().get_first_node_in_group("selection_manager")
	if _selection_manager:
		_selection_manager.selection_type_changed.connect(_on_selection_type_changed)

	# 添加输入事件处理器，用于截获并处理空格键
	set_process_input(true)

func _on_window_size_changed() -> void:
	var current_screen_size = get_viewport_rect().size
	if current_screen_size != _last_screen_size:
		_last_screen_size = current_screen_size
		_update_position()

func _setup_workbench() -> void:
	_buttons_container.scale = config.layout.scale

	# 设置按钮容器
	_buttons_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buttons_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_buttons_container.add_theme_constant_override("separation", 10)

	# 确保按钮容器拦截所有鼠标事件，但不拦截所有输入
	_buttons_container.mouse_filter = Control.MOUSE_FILTER_STOP

	# 添加触摸屏和鼠标输入过滤，防止在按钮上按空格键
	for child in _buttons_container.get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_CLICK
			child.mouse_filter = Control.MOUSE_FILTER_STOP

	# 设置容器的锚点为左下角
	_buttons_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)

	# 设置初始位置
	_update_position()

func _update_position() -> void:
	# 获取屏幕尺寸
	var screen_size = get_viewport_rect().size

	# 从配置中获取边距和偏移值
	var margin_left = config.layout.margin_left
	var margin_bottom = config.layout.margin_bottom
	var position_offset = config.layout.position_offset

	var button_container_size = get_button_container_size()

	# 设置整个控制器的位置
	position = Vector2(
		margin_left + button_container_size.x / 2,
		screen_size.y - margin_bottom - button_container_size.y / 2
	) + position_offset

func get_button_container_size() -> Vector2:
	var container_size = _buttons_container.get_rect().size
	container_size *= _buttons_container.scale
	return container_size

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

		# 配置按钮只响应鼠标点击，不响应空格键
		button.focus_mode = Control.FOCUS_CLICK
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		# 从配置中获取按钮样式
		var min_height = config.button_style.min_height
		var font_size = config.button_style.font_size
		var margin = config.button_style.margin

		button.custom_minimum_size = Vector2(150, min_height)  # 设置固定最小宽度
		button.add_theme_font_size_override("font_size", font_size)
		button.add_theme_constant_override("h_separation", margin.left)
		button.add_theme_constant_override("content_margin_left", margin.left)
		button.add_theme_constant_override("content_margin_right", margin.right)
		button.add_theme_constant_override("content_margin_top", margin.top)
		button.add_theme_constant_override("content_margin_bottom", margin.bottom)

		# 检查资源是否足够并设置提示
		if button_config.action != "exit":
			var requirements = get_resource_requirements(button_config.action)
			button.tooltip_text = requirements.total_cost
			if not requirements.can_afford:
				button.disabled = true
				button.tooltip_text += "\n" + requirements.missing_info

		# 连接按钮点击信号
		button.pressed.connect(_on_button_pressed.bind(button_config.action))

		# 添加按钮到容器
		_buttons_container.add_child(button)
		_active_buttons.append(button)

# 计算资源需求并返回提示信息
func get_resource_requirements(action_id: String) -> Dictionary:
	var result = {
		"can_afford": true,  # 是否有足够资源
		"total_cost": "",    # 总消耗提示
		"missing_info": ""   # 缺少资源提示
	}

	# 获取操作的资源消耗配置
	var costs = config.resource_costs.get(action_id)
	if not costs or action_id == "exit":
		return result

	# 获取当前资源
	var current_resources = _resource_manager.get_all_resources()
	var resource_names = {
		"gold": "金币",
		"wood": "木材",
		"meat": "食物"
	}

	# 计算总消耗和缺少的资源
	var total_parts = []
	var missing_parts = []

	for resource_type in costs:
		var required = costs[resource_type]
		var current = current_resources.get(resource_type, 0)
		var resource_name = resource_names.get(resource_type, resource_type)

		# 添加到总消耗提示
		total_parts.append(str(resource_name, ": ", required))

		# 如果资源不足，添加到缺少资源提示
		if current < required:
			result.can_afford = false
			missing_parts.append(str(resource_name, ": 缺少", required - current))

	# 组装提示信息
	result.total_cost = "需要: " + ", ".join(total_parts)
	if not result.can_afford:
		result.missing_info = "资源不足:\n" + "\n".join(missing_parts)

	return result

# 消耗资源
func _consume_resources(action_id: String) -> bool:
	var requirements = get_resource_requirements(action_id)
	if not requirements.can_afford:
		return false

	# 获取操作的资源消耗配置
	var costs = config.resource_costs.get(action_id)
	if not costs:
		return true

	return true

# 资源变化时更新按钮状态
func _on_resources_changed(_resource_type: String, _amount: int) -> void:
	_update_buttons()

func _on_button_pressed(action_id: String) -> void:
	# 阻止事件传播
	get_viewport().set_input_as_handled()

	# 检查并消耗资源
	if action_id != "exit" and not _consume_resources(action_id):
		print("资源不足")
		return

	# 首先检查选中的单位是否仍然有效
	var valid_units = []
	for unit in _selected_units:
		if is_instance_valid(unit):
			valid_units.append(unit)
	_selected_units = valid_units

	# 根据 action_id 分发到不同的处理函数
	match action_id:
		# 建筑相关
		"build_house", "build_tower", "build_castle", "build_mine":
			handle_build_action(action_id)
		# 城堡相关
		"produce_worker", "produce_archer", "produce_knight":
			handle_unit_production(action_id)
		"exit":
			set_interaction_type("NONE")

	button_clicked.emit(action_id)

func handle_build_action(action_id: String) -> void:
	var selected_workers = get_selected_workers()
	if selected_workers.is_empty():
		print("没有工人被选中，无法开始建造")
		return

	_building_manager.handle_preview_request(action_id, selected_workers)

func handle_unit_production(action_id: String) -> void:
	var selected_castle = get_selected_castle()
	if selected_castle.is_empty():
		print("没有城堡被选中，无法生产单位")
		return

	var castle = selected_castle[0]
	# 获取城堡的碰撞形状
	var collision_shape = castle.get_node("CollisionShape2D")
	if not collision_shape:
		print("城堡没有碰撞形状")
		return

	# 获取碰撞形状的尺寸
	var shape_size = Vector2.ZERO
	if collision_shape.shape is RectangleShape2D:
		shape_size = collision_shape.shape.size

	# 计算生成位置（在城堡右侧，距离碰撞形状一定距离）
	var spawn_offset = Vector2(shape_size.x / 2 + 50, 0)  # 在碰撞形状右侧50像素处
	var spawn_position = castle.global_position + spawn_offset

	# 根据不同单位类型生成单位
	match action_id:
		"produce_worker":
			_unit_manager.spawn_unit("Worker", spawn_position)
		"produce_archer":
			_unit_manager.spawn_unit("Archer", spawn_position)
		"produce_knight":
			_unit_manager.spawn_unit("Knight", spawn_position)

func set_interaction_type(type: String) -> void:
	if _interaction_type != type:
		_interaction_type = type
		_update_buttons()
		interaction_changed.emit(type)

func get_interaction_type() -> String:
	return _interaction_type

# 处理选择类型变化
func _on_selection_type_changed(type: String, units: Array) -> void:
	# 如果数组为空且类型为 NONE，可能是因为点击 UI 导致的
	# 忽略空选择变化，保留当前选中的单位
	if type == "NONE" and units.is_empty() and not _selected_units.is_empty():
		# 检查是否是由于点击工作台按钮导致的
		var focus_owner = get_viewport().gui_get_focus_owner()
		if focus_owner is Button and _buttons_container.is_ancestor_of(focus_owner):
			print("忽略由按钮点击引起的选择变化")
			return

	_selected_units = units  # 存储选中的单位
	set_interaction_type(type)

# 获取当前选中的单位
func get_selected_units() -> Array:
	return _selected_units

# 获取选中的工人单位
func get_selected_workers() -> Array:
	return _selected_units.filter(func(unit): return unit.is_in_group("workers"))

# 获取选中的城堡单位
func get_selected_castle() -> Array:
	return _selected_units.filter(func(unit): return unit.is_in_group("castles"))

# 添加一个新的输入处理函数，用于过滤空格键输入
func _input(event: InputEvent) -> void:
	# 检查是否是空格键按下事件
	if event.is_action_pressed("chop") or (event is InputEventKey and event.keycode == KEY_SPACE):
		# 获取当前焦点控件
		var focus_owner = get_viewport().gui_get_focus_owner()

		# 如果当前焦点在按钮上，阻止空格键事件
		if focus_owner is Button and _buttons_container.is_ancestor_of(focus_owner):
			get_viewport().set_input_as_handled()
			# 移除按钮焦点，防止空格键触发
			focus_owner.release_focus()
