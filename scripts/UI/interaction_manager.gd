# file: interaction_manager.gd
# author: ponywu
# date: 2025-03-23
# description: 交互管理器，用于处理玩家与游戏对象的交互

extends Node

# 使用工作台交互脚本中的交互类型枚举
const InteractionType = preload("res://scripts/UI/workbench/workbench_interaction.gd").InteractionType

# 交互类型名称映射
const INTERACTION_TYPE_NAMES = {
	InteractionType.NONE: "NONE",
	InteractionType.WORKER: "WORKER",
	InteractionType.BUILDING: "BUILDING",
	InteractionType.TREE: "TREE",
	InteractionType.GOLD_MINE: "GOLD_MINE"
}

# 引用
var workbench_ui: CanvasLayer
var workbench_controller: Node2D

# 当前交互对象
var current_interaction_type = InteractionType.NONE
var current_interaction_object = null

func _ready() -> void:
	# 延迟一帧，确保场景中的所有节点都已加载
	await get_tree().process_frame

	# 查找工作台
	find_workbench()

	# 连接信号
	connect_signals()

	# 默认状态 - 不显示任何按钮
	update_workbench_buttons()

# 查找工作台UI
func find_workbench() -> void:
	# 输出当前节点路径，帮助调试
	print("交互管理器路径: ", get_path())

	# 尝试多种可能的路径查找工作台UI
	var possible_paths = [
		"/root/homeland/WorkbenchUI",  # 在主场景中的路径
		"/root/TestWorkbench/WorkbenchUI",  # 在测试场景中的路径
		"../WorkbenchUI",  # 相对路径，适用于测试场景
		"/root/WorkbenchUI"  # 全局UI
	]

	for path in possible_paths:
		workbench_ui = get_node_or_null(path)
		if workbench_ui:
			workbench_controller = workbench_ui.get_node_or_null("workbench")
			if workbench_controller:
				print("找到工作台UI和控制器: %s" % path)
				return
			else:
				print("找到工作台UI但未找到控制器: %s" % path)

	# 如果还是没找到，尝试在父节点中查找
	var parent = get_parent()
	while parent:
		if parent.has_node("WorkbenchUI"):
			workbench_ui = parent.get_node("WorkbenchUI")
			workbench_controller = workbench_ui.get_node_or_null("workbench")
			if workbench_controller:
				print("在父节点中找到工作台UI和控制器")
				return
		parent = parent.get_parent()
		if not parent:
			break

	# 如果以上都没找到，打印警告
	print("警告：未找到工作台UI，交互功能可能不可用")

# 连接信号
func connect_signals() -> void:
	if workbench_controller:
		# 连接按钮点击信号
		if workbench_controller.has_signal("button_clicked"):
			if not workbench_controller.button_clicked.is_connected(_on_workbench_action_button_clicked):
				workbench_controller.button_clicked.connect(_on_workbench_action_button_clicked)
				print("已连接工作台按钮点击信号")
			else:
				print("工作台按钮点击信号已经连接")
		else:
			push_error("工作台控制器没有button_clicked信号")

	# 连接对象点击信号（这里需要根据你的游戏实现方式添加）
	# 比如，你可能需要连接到树、金矿、工人和建筑物的点击事件

# 更新工作台显示按钮
func update_workbench_buttons() -> void:
	print("尝试更新工作台按钮，当前交互类型: ", current_interaction_type)

	if not workbench_controller:
		print("无法更新按钮：工作台控制器不存在")
		return

	print("更新前调试：工作台控制器存在，按钮更新将执行")

	# 使用交互类型名称更新按钮
	if workbench_controller.has_method("update_buttons") and INTERACTION_TYPE_NAMES.has(current_interaction_type):
		workbench_controller.update_buttons(INTERACTION_TYPE_NAMES[current_interaction_type])
	else:
		push_error("工作台控制器没有update_buttons方法或交互类型无效")

	print("工作台按钮更新完成")

# 设置当前交互对象
func set_interaction_object(object_type: int, object = null) -> void:
	print("设置交互对象，类型从 ", current_interaction_type, " 变为 ", object_type)
	current_interaction_type = InteractionType.values()[object_type]
	current_interaction_object = object

	print("交互对象已设置，准备更新工作台按钮")
	update_workbench_buttons()
	print("交互对象设置完成: ", object_type)

# 处理工作台动作按钮点击
func _on_workbench_action_button_clicked(action_id: String) -> void:
	handle_action(action_id)

# 处理动作
func handle_action(action_id: String) -> void:
	print("处理动作: ", action_id)

	match action_id:
		# 工人动作
		"build":
			print("工人: 开始建造")
			# 这里添加建造逻辑
		"repair":
			print("工人: 开始修理")
			# 这里添加修理逻辑

		# 建筑动作
		"upgrade":
			print("建筑: 开始升级")
			# 这里添加升级逻辑
		"demolish":
			print("建筑: 开始拆除")
			# 这里添加拆除逻辑
		"produce":
			print("建筑: 开始生产单位")
			# 这里添加生产单位逻辑

		# 树动作
		"cut_tree":
			print("树: 派工人砍树")
			# 这里添加派工人砍树逻辑

		# 金矿动作
		"mine_gold":
			print("金矿: 派工人采矿")
			# 这里添加派工人采矿逻辑
		"build_mine":
			print("金矿: 建造采矿场")
			# 这里添加建造采矿场逻辑

		# 通用动作
		"exit":
			print("退出当前交互")
			clear_interaction()

		_:
			print("未知动作: ", action_id)

# 清除当前交互
func clear_interaction() -> void:
	current_interaction_type = InteractionType.NONE
	current_interaction_object = null
	update_workbench_buttons()

# 用于测试的工人交互
func test_worker_interaction() -> void:
	set_interaction_object(InteractionType.WORKER)
	print("测试：显示工人交互按钮")

# 用于测试的建筑交互
func test_building_interaction() -> void:
	set_interaction_object(InteractionType.BUILDING)
	print("测试：显示建筑交互按钮")

# 用于测试的树交互
func test_tree_interaction() -> void:
	set_interaction_object(InteractionType.TREE)
	print("测试：显示树交互按钮")

# 用于测试的金矿交互
func test_gold_mine_interaction() -> void:
	set_interaction_object(InteractionType.GOLD_MINE)
	print("测试：显示金矿交互按钮")
