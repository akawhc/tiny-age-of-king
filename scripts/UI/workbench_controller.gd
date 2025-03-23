# file: workbench_controller.gd
# author: ponywu
# date: 2025-03-23
# description: 工作台控制器，控制工作台的显示和用户交互

extends Node2D

# 工作台配置
const WORKBENCH_CONFIG = {
	"margin_left": 5,       # 距离屏幕左边的边距
	"margin_bottom": 5,     # 距离屏幕底部的边距
	"scale_base": Vector2(0.5, 0.5),  # 基础缩放比例 - 调小了初始比例
	"min_scale": 0.2,        # 最小缩放比例 - 调小了最小比例
	"max_scale": 0.9,        # 最大缩放比例 - 调小了最大比例
	"aspect_ratio": 1.0,     # 宽高比(宽/高)
	"animation_speed": 5.0,  # 位置动画平滑速度
	"screen_width_fraction": 0.10,  # 工作台占屏幕宽度的比例
	"scale": Vector2(0.5, 0.5), # 工作台的缩放比例 - 调小以适应屏幕
	"default_visible": true,     # 默认是否可见
	"position_offset": Vector2(10, -10), # 工作台相对于屏幕左下角的偏移
}

# 交互类型对应的按钮配置
const BUTTONS_CONFIG = {
	"NONE": [],
	"WORKER": [
		{"id": "build", "text": "建造", "action": "build"},
		{"id": "repair", "text": "修理", "action": "repair"},
		{"id": "exit", "text": "退出", "action": "exit"}
	],
	"BUILDING": [
		{"id": "upgrade", "text": "升级", "action": "upgrade"},
		{"id": "demolish", "text": "拆除", "action": "demolish"},
		{"id": "produce", "text": "生产", "action": "produce"},
		{"id": "exit", "text": "退出", "action": "exit"}
	],
	"TREE": [
		{"id": "cut", "text": "派工人砍树", "action": "cut_tree"},
		{"id": "exit", "text": "退出", "action": "exit"}
	],
	"GOLD_MINE": [
		{"id": "mine", "text": "派工人采矿", "action": "mine_gold"},
		{"id": "build_mine", "text": "建造采矿场", "action": "build_mine"},
		{"id": "exit", "text": "退出", "action": "exit"}
	]
}

var target_position: Vector2 = Vector2.ZERO
var target_scale: Vector2 = WORKBENCH_CONFIG.scale_base
var initialized: bool = false
var viewport_size: Vector2 = Vector2.ZERO
var interaction_manager = null
var active_buttons = []

signal button_clicked(action_id: String)

func _ready() -> void:
	# 设置工作台位置和大小
	_setup_workbench()

	# 查找交互管理器
	find_interaction_manager()

	# 获取按钮容器
	var buttons_container = get_node_or_null("ActionButtons")
	if not buttons_container:
		push_error("找不到按钮容器节点 ActionButtons")

	# 默认不显示任何按钮
	update_buttons("NONE")

	# 设置工作台的初始可见性
	visible = WORKBENCH_CONFIG["default_visible"]

func _process(_delta: float) -> void:
	if not initialized:
		return

	_fix_workbench_position()

	# 检测按键输入
	if Input.is_action_just_pressed("toggle_workbench"):
		visible = not visible  # 切换工作台的可见性
		print("工作台可见性已切换: ", visible)

# 设置工作台位置和大小
func _setup_workbench() -> void:
	# 等待一帧确保获取正确的视口大小
	await get_tree().process_frame

	# 初始化视口大小
	viewport_size = get_viewport_rect().size

	scale = WORKBENCH_CONFIG["scale"]
	visible = WORKBENCH_CONFIG["default_visible"]
	var workbench_size = get_workbench_size()

	# 设置位置在左下角
	var screen_size = get_viewport_rect().size
	position = calculate_position(screen_size, workbench_size)

	print("工作台初始位置: ", position)
	print("工作台大小: ", workbench_size)
	print("屏幕大小: ", screen_size)

	# 标记为已初始化
	initialized = true

# 窗口拖放后确保工作台仍然那位于左下角
func _fix_workbench_position() -> void:
	# 检查视口大小是否改变
	var current_viewport_size = get_viewport_rect().size
	if current_viewport_size != viewport_size:
		viewport_size = current_viewport_size

		# 获取工作台大小
		var workbench_size = get_workbench_size()

		# 重新计算位置（左下角）
		position = calculate_position(viewport_size, workbench_size)

		print("工作台位置已更新: ", position)
		print("新屏幕大小: ", viewport_size)

# 更新按钮显示
func update_buttons(interaction_type: String) -> void:
	print("更新工作台按钮，交互类型: ", interaction_type)

	# 获取按钮容器
	var buttons_container = get_node("ActionButtons")
	if not buttons_container:
		push_error("找不到按钮容器")
		return

	# 清除所有现有按钮
	for button in active_buttons:
		if is_instance_valid(button):
			button.queue_free()
	active_buttons.clear()

	# 没有按钮配置则提前退出
	if not BUTTONS_CONFIG.has(interaction_type):
		push_error("未找到交互类型的按钮配置: " + interaction_type)
		return

	# 创建新按钮
	for button_config in BUTTONS_CONFIG[interaction_type]:
		var button = Button.new()
		button.text = button_config["text"]
		button.name = button_config["id"]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 50)  # 增加按钮高度从30到50

		# 设置更大的字体
		var font_size = 24  # 增加字体大小
		button.add_theme_font_size_override("font_size", font_size)

		# 增加内边距
		button.add_theme_constant_override("h_separation", 15)
		button.add_theme_constant_override("content_margin_left", 10)
		button.add_theme_constant_override("content_margin_right", 10)
		button.add_theme_constant_override("content_margin_top", 10)
		button.add_theme_constant_override("content_margin_bottom", 10)

		# 连接按钮点击信号
		button.pressed.connect(_on_action_button_pressed.bind(button_config["action"]))

		# 添加按钮到容器
		buttons_container.add_child(button)
		active_buttons.append(button)

	print("已更新工作台按钮，当前活动按钮数量: ", active_buttons.size())

# 按钮点击回调
func _on_action_button_pressed(action_id: String) -> void:
	print("工作台按钮点击: ", action_id)
	button_clicked.emit(action_id)

# 查找交互管理器
func find_interaction_manager() -> void:
	# 尝试不同路径查找交互管理器
	var possible_paths = [
		"/root/homeland/InteractionManager",
		"/root/InteractionManager",
		"../InteractionManager",
		"/root/TestWorkbench/InteractionManager"  # 测试场景中的路径
	]

	# 调试信息：输出当前节点的完整路径，帮助查找问题
	print("当前工作台路径: ", get_path())

	for path in possible_paths:
		interaction_manager = get_node_or_null(path)
		if interaction_manager:
			print("找到交互管理器: %s" % path)
			break

	if not interaction_manager:
		print("警告：未找到交互管理器，尝试查找父节点...")
		# 尝试向上查找任何拥有interaction_manager的节点
		var parent = get_parent()
		while parent and not interaction_manager:
			if parent.get_parent() and parent.get_parent().has_node("InteractionManager"):
				interaction_manager = parent.get_parent().get_node("InteractionManager")
				print("在父节点中找到交互管理器")
				break
			parent = parent.get_parent()
			if not parent:
				break

# 获取工作台的实际大小
func get_workbench_size() -> Vector2:
	var background = $background
	if background and background.texture:
		# 计算缩放后的大小
		var width = background.texture.get_width() * background.scale.x
		var height = background.texture.get_height() * background.scale.y

		# 考虑按钮容器的大小
		var buttons_container = get_node_or_null("ActionButtons")
		if buttons_container:
			var buttons_size = buttons_container.get_combined_minimum_size()
			width = max(width, buttons_size.x * 2)  # *2 是因为按钮是相对于中心点定位的
			height = max(height, buttons_size.y * 2)

		print("工作台计算大小: ", Vector2(width, height))

		return Vector2(width, height)

	# 默认大小
	return Vector2(320, 320)

# 计算工作台在左下角的位置
func calculate_position(screen_size: Vector2, workbench_size: Vector2) -> Vector2:
	# 距离边框的距离
	var left_margin = WORKBENCH_CONFIG["margin_left"]
	var bottom_margin = WORKBENCH_CONFIG["margin_bottom"]

	# 考虑缩放后的实际尺寸
	var scaled_width = workbench_size.x * scale.x
	var scaled_height = workbench_size.y * scale.y

	# 确保工作台完全在屏幕内的位置计算
	var pos_x = left_margin + scaled_width / 2
	var pos_y = screen_size.y - bottom_margin - scaled_height / 2

	# 调试输出
	print("缩放因子: ", scale)
	print("缩放后尺寸: ", Vector2(scaled_width, scaled_height))
	print("计算位置: ", Vector2(pos_x, pos_y))

	return Vector2(pos_x, pos_y)
