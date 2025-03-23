# file: test_workbench.gd
# author: ponywu
# date: 2025-03-23
# description: 测试工作台和交互管理器的功能

extends Node2D

# 引用
var interaction_manager: Node = null

# 使用工作台交互脚本中的交互类型枚举
const InteractionType = preload("res://scripts/UI/workbench/workbench_interaction.gd").InteractionType

func _ready() -> void:
	# 打印当前节点路径，帮助调试
	print("测试场景路径: ", get_path())

	# 确保子节点存在
	print("子节点列表: ", get_children())

	# 查找交互管理器
	interaction_manager = get_node_or_null("InteractionManager")
	if not interaction_manager:
		push_error("无法找到交互管理器")
		return
	else:
		print("成功找到交互管理器")

	# 查找并确认工作台存在
	var workbench_ui = get_node_or_null("WorkbenchUI")
	if workbench_ui:
		var workbench = workbench_ui.get_node_or_null("workbench")
		if workbench:
			print("成功找到工作台")
		else:
			push_error("找到WorkbenchUI但未找到workbench节点")
	else:
		push_error("未找到WorkbenchUI节点")

	# 连接按钮信号
	_connect_buttons()

	# 等待场景完全加载
	await get_tree().process_frame
	await get_tree().process_frame  # 再等一帧确保工作台控制器完全初始化

	print("测试场景已准备就绪")

	# 尝试手动建立连接
	_ensure_connections()

	# 默认显示工人交互测试
	_test_default_interaction()

# 连接测试按钮信号
func _connect_buttons() -> void:
	# 工人测试按钮
	var worker_button = get_node_or_null("TestButtons/TestWorkerButton")
	if worker_button:
		worker_button.pressed.connect(_on_test_worker_button_pressed)
	else:
		push_error("未找到工人测试按钮")

	# 建筑测试按钮
	var building_button = get_node_or_null("TestButtons/TestBuildingButton")
	if building_button:
		building_button.pressed.connect(_on_test_building_button_pressed)
	else:
		push_error("未找到建筑测试按钮")

	# 树木测试按钮
	var tree_button = get_node_or_null("TestButtons/TestTreeButton")
	if tree_button:
		tree_button.pressed.connect(_on_test_tree_button_pressed)
	else:
		push_error("未找到树木测试按钮")

	# 金矿测试按钮
	var mine_button = get_node_or_null("TestButtons/TestGoldMineButton")
	if mine_button:
		mine_button.pressed.connect(_on_test_gold_mine_button_pressed)
	else:
		push_error("未找到金矿测试按钮")

	# 清除交互按钮
	var clear_button = get_node_or_null("TestButtons/ClearButton")
	if clear_button:
		clear_button.pressed.connect(_on_clear_button_pressed)
	else:
		push_error("未找到清除交互按钮")

# 工人测试按钮点击
func _on_test_worker_button_pressed() -> void:
	print("\n==== 工人交互测试开始 ====")
	if interaction_manager:
		# 确保连接正确
		_ensure_connections()

		print("执行工人交互测试...")
		interaction_manager.test_worker_interaction()

		# 验证结果
		print("验证交互设置结果:")
		print(" - 设置后交互类型: ", interaction_manager.current_interaction_type)
		print(" - 期望交互类型: ", InteractionType.WORKER)
		print(" - 交互设置是否成功: ", interaction_manager.current_interaction_type == InteractionType.WORKER)

		print("测试: 工人交互按钮已点击")
	else:
		push_error("无法执行工人交互测试: 交互管理器不存在")
	print("==== 工人交互测试结束 ====\n")

# 建筑测试按钮点击
func _on_test_building_button_pressed() -> void:
	print("\n==== 建筑交互测试开始 ====")
	if interaction_manager:
		# 确保连接正确
		_ensure_connections()

		print("执行建筑交互测试...")
		interaction_manager.test_building_interaction()

		# 验证结果
		print("验证交互设置结果:")
		print(" - 设置后交互类型: ", interaction_manager.current_interaction_type)
		print(" - 期望交互类型: ", InteractionType.BUILDING)
		print(" - 交互设置是否成功: ", interaction_manager.current_interaction_type == InteractionType.BUILDING)

		print("测试: 建筑交互按钮已点击")
	else:
		push_error("无法执行建筑交互测试: 交互管理器不存在")
	print("==== 建筑交互测试结束 ====\n")

# 树木测试按钮点击
func _on_test_tree_button_pressed() -> void:
	print("\n==== 树木交互测试开始 ====")
	if interaction_manager:
		# 确保连接正确
		_ensure_connections()

		print("执行树木交互测试...")
		interaction_manager.test_tree_interaction()

		# 验证结果
		print("验证交互设置结果:")
		print(" - 设置后交互类型: ", interaction_manager.current_interaction_type)
		print(" - 期望交互类型: ", InteractionType.TREE)
		print(" - 交互设置是否成功: ", interaction_manager.current_interaction_type == InteractionType.TREE)

		print("测试: 树木交互按钮已点击")
	else:
		push_error("无法执行树木交互测试: 交互管理器不存在")
	print("==== 树木交互测试结束 ====\n")

# 金矿测试按钮点击
func _on_test_gold_mine_button_pressed() -> void:
	print("\n==== 金矿交互测试开始 ====")
	if interaction_manager:
		# 确保连接正确
		_ensure_connections()

		# 显示交互管理器当前状态
		print("交互管理器当前状态:")
		print(" - 当前交互类型: ", interaction_manager.current_interaction_type)
		print(" - 工作台UI引用: ", interaction_manager.workbench_ui != null)
		print(" - 工作台控制器引用: ", interaction_manager.workbench_controller != null)

		# 执行测试
		print("执行金矿交互测试...")
		interaction_manager.test_gold_mine_interaction()

		# 验证结果
		print("验证交互设置结果:")
		print(" - 设置后交互类型: ", interaction_manager.current_interaction_type)
		print(" - 期望交互类型: ", InteractionType.GOLD_MINE)
		print(" - 交互设置是否成功: ", interaction_manager.current_interaction_type == InteractionType.GOLD_MINE)

		print("测试: 金矿交互按钮已点击")
	else:
		push_error("无法执行金矿交互测试: 交互管理器不存在")
	print("==== 金矿交互测试结束 ====\n")

# 清除交互按钮点击
func _on_clear_button_pressed() -> void:
	if interaction_manager:
		interaction_manager.clear_interaction()
		print("测试: 已清除所有交互")

# 确保交互管理器和工作台正确连接
func _ensure_connections() -> void:
	print("开始建立交互管理器和工作台的连接...")

	if not interaction_manager:
		print("错误：交互管理器不存在，无法建立连接")
		return
	else:
		print("交互管理器存在: ", interaction_manager)

	# 手动找到工作台
	var workbench_ui = get_node_or_null("WorkbenchUI")
	if workbench_ui:
		print("找到工作台UI节点: ", workbench_ui)
		var workbench = workbench_ui.get_node_or_null("workbench")
		if workbench:
			print("找到工作台节点: ", workbench)

			# 手动设置交互管理器引用
			workbench.interaction_manager = interaction_manager
			print("手动建立了工作台与交互管理器的连接")

			# 手动设置工作台UI引用
			interaction_manager.workbench_ui = workbench_ui
			interaction_manager.workbench_controller = workbench
			print("手动建立了交互管理器与工作台的连接")

			# 连接信号
			if workbench.has_signal("button_clicked") and not workbench.button_clicked.is_connected(interaction_manager._on_workbench_action_button_clicked):
				workbench.button_clicked.connect(interaction_manager._on_workbench_action_button_clicked)
				print("手动连接了工作台按钮点击信号")
			else:
				print("工作台按钮点击信号已连接或信号不存在")

			# 确认连接是否成功
			print("连接状态检查:")
			print(" - 交互管理器中的工作台UI: ", interaction_manager.workbench_ui != null)
			print(" - 交互管理器中的工作台控制器: ", interaction_manager.workbench_controller != null)
			print(" - 工作台中的交互管理器: ", workbench.interaction_manager != null)
			print(" - 工作台按钮点击信号是否已连接: ", workbench.has_signal("button_clicked") and workbench.button_clicked.is_connected(interaction_manager._on_workbench_action_button_clicked))
		else:
			push_error("未找到工作台节点")
	else:
		push_error("未找到工作台UI节点")

	print("连接建立完成")

# 默认显示工人交互测试
func _test_default_interaction() -> void:
	if interaction_manager:
		interaction_manager.clear_interaction()  # 先清除所有交互
		await get_tree().process_frame  # 等待一帧确保清除生效
		interaction_manager.test_worker_interaction()
		print("测试: 默认显示工人交互测试")
